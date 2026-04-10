// ============================================================
// chat_input_bar.dart — شريط الإدخال السفلي
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final bool isStreaming;
  final void Function(String) onSend;
  final VoidCallback onStop;

  const ChatInputBar({
    super.key,
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _hasText = _controller.text.trim().isNotEmpty));
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CCColors.surface,
        border: Border(
          top: BorderSide(color: CCColors.outlineVariant.withValues(alpha: 0.5), width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16, right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: CCColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _hasText
                      ? CCColors.primaryContainer.withValues(alpha: 0.3)
                      : CCColors.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: CCColors.onSurface, fontSize: 15),
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        hintStyle: TextStyle(color: CCColors.outline),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // زر إرسال أو إيقاف
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.isStreaming
                ? _StopButton(onTap: widget.onStop)
                : _SendButton(enabled: _hasText, onTap: _send),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(
                  colors: [CCColors.primaryFixedDim, CCColors.primaryContainer],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : CCColors.surfaceContainerHigh,
          boxShadow: enabled
              ? [BoxShadow(color: CCColors.primaryContainer.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 1)]
              : null,
        ),
        child: Icon(
          Icons.send_rounded,
          size: 18,
          color: enabled ? Colors.black : CCColors.outline,
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CCColors.error.withValues(alpha: 0.15),
          border: Border.all(color: CCColors.error.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [BoxShadow(color: CCColors.error.withValues(alpha: 0.2), blurRadius: 10)],
        ),
        child: const Icon(Icons.stop_rounded, size: 20, color: CCColors.error),
      ),
    );
  }
}


