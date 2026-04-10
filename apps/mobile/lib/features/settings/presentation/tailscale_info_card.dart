// ============================================================
// tailscale_info_card.dart — بطاقة حالة Tailscale في الإعدادات
// ============================================================
// تُعرض في Settings Screen وتُظهر:
//  - هل Tailscale مُفعَّل؟
//  - عنوان الاتصال عن بُعد (ws://...)
//  - نسخ العنوان بنقرة واحدة
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/tailscale_provider.dart';

class TailscaleInfoCard extends ConsumerWidget {
  const TailscaleInfoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = ref.watch(tailscaleProvider);

    if (ts.loading && !ts.enabled) {
      return const _SkeletonCard();
    }

    if (!ts.enabled) {
      return _DisabledCard(onRefresh: () => ref.read(tailscaleProvider.notifier).refresh());
    }

    return _ActiveCard(
      wsUrl: ts.wsUrl!,
      ip:    ts.tailscaleIp!,
      port:  ts.port ?? 8765,
      onRefresh: () => ref.read(tailscaleProvider.notifier).refresh(),
    );
  }
}

// ── نشط ──
class _ActiveCard extends StatelessWidget {
  final String wsUrl;
  final String ip;
  final int    port;
  final VoidCallback onRefresh;

  const _ActiveCard({
    required this.wsUrl,
    required this.ip,
    required this.port,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF003322),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00C853),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Tailscale نشط', style: TextStyle(
                color: Color(0xFF00C853),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF00C853)),
                onPressed: onRefresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('عنوان الاتصال عن بُعد:', style: TextStyle(
            fontSize: 11, color: CCColors.onSurfaceVariant,
          )),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: wsUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('تم نسخ العنوان ✓'),
                  backgroundColor: const Color(0xFF00C853),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x1500C853),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00C853).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_tethering_rounded, size: 14, color: Color(0xFF00C853)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(wsUrl, style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF00E676),
                    )),
                  ),
                  const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF00C853)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('IP: $ip  |  Port: $port', style: const TextStyle(
            fontSize: 10,
            color: CCColors.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}

// ── غير نشط ──
class _DisabledCard extends StatelessWidget {
  final VoidCallback onRefresh;
  const _DisabledCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CCColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: CCColors.onSurfaceVariant),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tailscale غير مُفعَّل', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: CCColors.onSurface,
                )),
                Text('عيّن TAILSCALE_IP في بيئة Bridge للوصول عن بُعد', style: TextStyle(
                  fontSize: 10, color: CCColors.onSurfaceVariant,
                )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 16, color: CCColors.onSurfaceVariant),
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton Loading ──
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      height: 60,
      decoration: BoxDecoration(
        color: CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: CCColors.primary),
        ),
      ),
    );
  }
}
