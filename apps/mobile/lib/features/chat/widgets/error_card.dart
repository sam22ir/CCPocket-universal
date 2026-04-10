// ============================================================
// error_card.dart — بطاقة الخطأ القابلة للتنفيذ
// ============================================================
// تعرض رسائل الخطأ مع: ماذا حدث + لماذا + ماذا تفعل
// مع أزرار إجراءات قابلة للتخصيص
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum ErrorSeverity { warning, error, fatal }

class ErrorAction {
  final String   label;
  final IconData icon;
  final VoidCallback onTap;

  const ErrorAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class ErrorCard extends StatelessWidget {
  /// ماذا حدث (العنوان)
  final String          title;
  /// لماذا حدث (التفاصيل)
  final String?         description;
  /// ماذا يفعل المستخدم (اقتراح)
  final String?         suggestion;
  /// الأزرار القابلة للتخصيص
  final List<ErrorAction> actions;
  /// مستوى الخطورة
  final ErrorSeverity   severity;
  /// هل يُظهر كـ inline أم كـ fullscreen
  final bool            compact;

  const ErrorCard({
    super.key,
    required this.title,
    this.description,
    this.suggestion,
    this.actions = const [],
    this.severity = ErrorSeverity.error,
    this.compact = false,
  });

  // ── Factory: خطأ Bridge غير متصل ──
  factory ErrorCard.bridgeDisconnected({VoidCallback? onRetry}) => ErrorCard(
        title: 'Bridge غير متصل',
        description: 'لا يمكن الاتصال بـ Bridge Server على المنفذ 8765.',
        suggestion: 'تأكد من تشغيل Bridge وأن الجهاز على نفس الشبكة.',
        severity: ErrorSeverity.warning,
        actions: [
          if (onRetry != null)
            ErrorAction(
              label: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
        ],
      );

  // ── Factory: خطأ API ──
  factory ErrorCard.apiError({
    required String message,
    VoidCallback? onRetry,
  }) =>
      ErrorCard(
        title: 'خطأ في الـ API',
        description: message,
        suggestion: 'تحقق من صحة الـ API Key ومن حالة الخدمة.',
        severity: ErrorSeverity.error,
        actions: [
          if (onRetry != null)
            ErrorAction(
              label: 'حاول مجدداً',
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
        ],
      );

  // ── Factory: خطأ عام ──
  factory ErrorCard.generic({
    required String message,
    VoidCallback? onDismiss,
  }) =>
      ErrorCard(
        title: 'حدث خطأ',
        description: message,
        severity: ErrorSeverity.error,
        actions: [
          if (onDismiss != null)
            ErrorAction(
              label: 'إغلاق',
              icon: Icons.close_rounded,
              onTap: onDismiss,
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final (iconData, iconColor, bgColor, borderColor) = switch (severity) {
      ErrorSeverity.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFFF0A500),
        const Color(0xFF2C2200),
        const Color(0xFF4A3800),
      ),
      ErrorSeverity.error => (
        Icons.error_outline_rounded,
        CCColors.error,
        CCColors.error.withValues(alpha: 0.08),
        CCColors.error.withValues(alpha: 0.25),
      ),
      ErrorSeverity.fatal => (
        Icons.dangerous_rounded,
        const Color(0xFFFF4444),
        const Color(0xFF2C0000),
        const Color(0xFF4A0000),
      ),
    };

    if (compact) {
      return _CompactErrorCard(
        title: title,
        iconData: iconData,
        iconColor: iconColor,
        bgColor: bgColor,
        borderColor: borderColor,
        actions: actions,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── العنوان + الأيقونة ──
          Row(
            children: [
              Icon(iconData, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),

          // ── الوصف ──
          if (description != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: Text(
                description!,
                style: const TextStyle(
                  fontSize: 12,
                  color: CCColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],

          // ── الاقتراح ──
          if (suggestion != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 13, color: iconColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      suggestion!,
                      style: TextStyle(
                        fontSize: 11,
                        color: iconColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── الأزرار ──
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: actions.map((a) => _ActionButton(action: a, color: iconColor)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── نسخة مضغوطة (للـ SnackBar أو inline) ──
class _CompactErrorCard extends StatelessWidget {
  final String        title;
  final IconData      iconData;
  final Color         iconColor;
  final Color         bgColor;
  final Color         borderColor;
  final List<ErrorAction> actions;

  const _CompactErrorCard({
    required this.title,
    required this.iconData,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(iconData, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 12, color: iconColor, fontWeight: FontWeight.w600),
            ),
          ),
          ...actions.map((a) => GestureDetector(
                onTap: a.onTap,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(a.icon, size: 16, color: iconColor),
                ),
              )),
        ],
      ),
    );
  }
}

// ── زر إجراء ──
class _ActionButton extends StatelessWidget {
  final ErrorAction action;
  final Color       color;
  const _ActionButton({required this.action, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
