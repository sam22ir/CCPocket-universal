// ============================================================
// tool_call_card.dart — بطاقة طلب الأداة (مع ربط حقيقي بـ Bridge)
// الحالات: pending → approved / rejected + animation
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'code_diff_viewer.dart';
import '../providers/chat_provider.dart';

class ToolCallCard extends ConsumerStatefulWidget {
  final ChatMessage message;
  final ChatArgs args; // ← ChatArgs بدلاً من sessionId

  const ToolCallCard({super.key, required this.message, required this.args});

  @override
  ConsumerState<ToolCallCard> createState() => _ToolCallCardState();
}

class _ToolCallCardState extends ConsumerState<ToolCallCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(bool approve) async {
    if (_isActing) return;
    setState(() => _isActing = true);

    // Animation + haptic feedback
    HapticFeedback.mediumImpact();
    await _animController.forward();
    await _animController.reverse();

    final notifier = ref.read(chatProvider(widget.args).notifier);
    final toolId = widget.message.toolCall!.id;

    if (approve) {
      notifier.approveToolCall(toolId);
    } else {
      notifier.rejectToolCall(toolId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = widget.message.toolCall!;
    final status = tool.status; // pending | approved | rejected

    final isPending = status == 'pending';
    final isApproved = status == 'approved';

    return ScaleTransition(
      scale: _scaleAnim,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bgColor(status).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _bgColor(status).withValues(alpha: isPending ? 0.4 : 0.7),
              width: isPending ? 1.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _bgColor(status).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _bgColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconFor(status),
                      size: 18,
                      color: _bgColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _labelFor(status),
                          style: TextStyle(
                            fontSize: 11,
                            color: _bgColor(status),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tool.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CCColors.onSurface,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _StatusBadge(status: status, key: ValueKey(status)),
                  ),
                ],
              ),

              // ── Args ──
              if (tool.args.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ArgsBlock(args: tool.args),
              ],

              // ── Buttons (فقط عند pending) ──
              if (isPending) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'رفض',
                        icon: Icons.close_rounded,
                        isApprove: false,
                        isLoading: _isActing,
                        onTap: () => _handleAction(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _ActionButton(
                        label: 'تشغيل الأداة',
                        icon: Icons.play_arrow_rounded,
                        isApprove: true,
                        isLoading: _isActing,
                        onTap: () => _handleAction(true),
                      ),
                    ),
                  ],
                ),
              ],

              // ── Result message (بعد الإجراء) ──
              if (!isPending) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      isApproved
                          ? Icons.check_circle_outline_rounded
                          : Icons.cancel_outlined,
                      size: 14,
                      color: _bgColor(status).withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isApproved
                          ? 'تمت الموافقة — جارٍ التنفيذ...'
                          : 'تم الرفض — الأداة لن تُشغَّل',
                      style: TextStyle(
                        fontSize: 12,
                        color: _bgColor(status).withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _bgColor(String status) {
    switch (status) {
      case 'approved':
        return CCColors.success;
      case 'rejected':
        return CCColors.error;
      default:
        return CCColors.tertiary;
    }
  }

  IconData _iconFor(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  String _labelFor(String status) {
    switch (status) {
      case 'approved':
        return 'أداة مُوافق عليها';
      case 'rejected':
        return 'أداة مرفوضة';
      default:
        return 'طلب تشغيل أداة';
    }
  }
}

// ─── Args Block ───

class _ArgsBlock extends StatefulWidget {
  final Map<String, dynamic> args;
  const _ArgsBlock({required this.args});

  @override
  State<_ArgsBlock> createState() => _ArgsBlockState();
}

class _ArgsBlockState extends State<_ArgsBlock> {
  bool _expanded = false;

  String? _stringArg(String key) {
    final value = widget.args[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final fileName =
        _stringArg('path') ?? _stringArg('file_path') ?? _stringArg('filePath');
    final diffText = _stringArg('diff');
    final newContent = _stringArg('content') ?? _stringArg('new_string');
    final previewableKeys = {'diff', 'content', 'new_string'};
    final text = widget.args.entries
        .where((e) => !previewableKeys.contains(e.key))
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
    final lines = text.split('\n');
    final preview = lines.take(3).join('\n');
    final hasMore = text.isNotEmpty && lines.length > 3;

    return GestureDetector(
      onTap: hasMore ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CCColors.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: CCColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (diffText != null) ...[
              CodeDiffViewer(
                diffText: diffText,
                fileName: fileName,
                initiallyCollapsed: true,
              ),
              if (text.isNotEmpty) const SizedBox(height: 10),
            ] else if (newContent != null && newContent.contains('\n')) ...[
              CodeDiffViewer.fromNewContent(
                content: newContent,
                fileName: fileName,
              ),
              if (text.isNotEmpty) const SizedBox(height: 10),
            ],
            if (text.isNotEmpty)
              Text(
                _expanded ? text : preview,
                style: const TextStyle(
                  fontSize: 12,
                  color: CCColors.onSurfaceVariant,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            if (hasMore) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 14,
                    color: CCColors.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _expanded
                        ? 'عرض أقل'
                        : 'عرض المزيد (${lines.length - 3} سطر)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: CCColors.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ───

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('مُنفَّذ ✓', CCColors.success),
      'rejected' => ('مرفوض ✗', CCColors.error),
      _ => ('في الانتظار', CCColors.tertiary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Action Button ───

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isApprove;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isApprove,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isApprove ? CCColors.success : CCColors.error;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isApprove
              ? color.withValues(alpha: isLoading ? 0.06 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isLoading ? 0.2 : 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isLoading
              ? [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  ),
                ]
              : [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}
