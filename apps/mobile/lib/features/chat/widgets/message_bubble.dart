// ============================================================
// message_bubble.dart — فقاعات الرسائل
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/animations.dart';
import '../providers/chat_provider.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MessageEntrance(
      isUser: message.isUser,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: message.isUser
            ? _UserBubble(message: message)
            : _AssistantBubble(message: message),
      ),
    );
  }
}

// ─── User Bubble (يمين، gradient بنفسجي) ───

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 60),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [CCColors.userBubbleStart, CCColors.userBubbleEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: CCColors.userBubbleStart.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _Avatar(isUser: true),
      ],
    );
  }
}

// ─── Assistant Bubble (يسار، dark card + cyan glow) ───

class _AssistantBubble extends StatelessWidget {
  final ChatMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Avatar(isUser: false),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: CCColors.surfaceContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(color: CCColors.primaryContainer.withValues(alpha: 0.15), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: CCColors.primaryContainer.withValues(alpha: 0.05),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: message.isStreaming && message.content.isEmpty
                    ? const _StreamingDots()
                    : Text(
                        message.content,
                        style: const TextStyle(
                          color: CCColors.onSurface,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
              ),
              if (message.isStreaming)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(
                    'جارٍ الكتابة...',
                    style: TextStyle(
                      fontSize: 11,
                      color: CCColors.primaryFixedDim.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 60),
      ],
    );
  }
}

// ─── Streaming Dots ───

class _StreamingDots extends StatefulWidget {
  const _StreamingDots();
  @override
  State<_StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<_StreamingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => _Dot(controller: _controller, delay: i * 0.2)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  const _Dot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final t = ((controller.value - delay) % 1.0).clamp(0.0, 1.0);
        final opacity = (0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Opacity(
            opacity: opacity,
            child: const CircleAvatar(
              radius: 4,
              backgroundColor: CCColors.primaryFixedDim,
            ),
          ),
        );
      },
    );
  }
}

// ─── Avatar ───

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser
            ? const LinearGradient(
                colors: [CCColors.userBubbleStart, CCColors.userBubbleEnd],
              )
            : null,
        color: isUser ? null : CCColors.surfaceContainerHighest,
        border: Border.all(
          color: isUser
              ? CCColors.userBubbleStart.withValues(alpha: 0.5)
              : CCColors.primaryContainer.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
        size: 16,
        color: isUser ? Colors.white : CCColors.primaryFixedDim,
      ),
    );
  }
}


