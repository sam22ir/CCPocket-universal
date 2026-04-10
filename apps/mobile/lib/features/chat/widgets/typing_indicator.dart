// typing_indicator.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CCColors.surfaceContainerHighest,
              border: Border.all(color: CCColors.primaryContainer.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: CCColors.primaryFixedDim),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: CCColors.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: CCColors.primaryContainer.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: List.generate(3, (i) => _AnimDot(controller: _controller, delay: i * 0.25)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}

class _AnimDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  const _AnimDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final t = ((controller.value + delay) % 1.0);
        final scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: CCColors.primaryFixedDim,
              ),
            ),
          ),
        );
      },
    );
  }
}


