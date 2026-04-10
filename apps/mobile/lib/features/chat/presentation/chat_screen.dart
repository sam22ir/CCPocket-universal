// ============================================================
// chat_screen.dart — شاشة المحادثة الرئيسية
// Design tokens من Stitch MCP project: 12077632945023875675
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/provider_drawer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/tool_call_card.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/error_card.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerWidget {
  final ChatArgs args;

  const ChatScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider(args));

    return Scaffold(
      backgroundColor: CCColors.background,
      appBar: _buildAppBar(context, ref, state),
      body: Column(
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ErrorCard.generic(
                message: state.error!,
                onDismiss: () =>
                    ref.read(chatProvider(args).notifier).clearError(),
              ),
            ),
          Expanded(
            child: _MessageList(state: state, args: args),
          ),
          if (state.isStreaming) const TypingIndicator(),
          ChatInputBar(
            isStreaming: state.isStreaming,
            onSend: (text) =>
                ref.read(chatProvider(args).notifier).sendMessage(text),
            onStop: () => ref.read(chatProvider(args).notifier).cancelStream(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    ChatState state,
  ) {
    return AppBar(
      backgroundColor: CCColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.sessionTitle,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CCColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _ModelBadge(label: state.modelName),
              const SizedBox(width: 8),
              _StatusDot(isActive: state.isConnected),
              // ── Project badge ──
              if (state.hasProject) ...[
                const SizedBox(width: 8),
                _ProjectBadge(name: _shortPath(state.projectPath)),
              ],
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 20),
          tooltip: 'اختيار المزود',
          onPressed: () => showProviderDrawer(context),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  /// يُظهر آخر جزء من المسار مثل: ...my-project
  String _shortPath(String path) {
    if (path.isEmpty) return '';
    final parts = path.replaceAll('\\', '/').split('/');
    return parts.last.isEmpty && parts.length > 1
        ? parts[parts.length - 2]
        : parts.last;
  }
}

class _MessageList extends StatefulWidget {
  final ChatState state;
  final ChatArgs args;

  const _MessageList({required this.state, required this.args});

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.messages.length != oldWidget.state.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.state.messages;
    if (messages.isEmpty) return const _EmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        if (msg.hasToolCall) {
          return ToolCallCard(message: msg, args: widget.args);
        }
        return MessageBubble(message: msg);
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

// ─── Model Badge ───

class _ModelBadge extends StatelessWidget {
  final String label;
  const _ModelBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: CCColors.cyanGlow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CCColors.primaryContainer.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: CCColors.primaryFixedDim,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Project Badge ───

class _ProjectBadge extends StatelessWidget {
  final String name;
  const _ProjectBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: CCColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CCColors.secondary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_rounded, size: 9, color: CCColors.secondary),
          const SizedBox(width: 3),
          Text(
            name,
            style: const TextStyle(fontSize: 9, color: CCColors.secondary),
          ),
        ],
      ),
    );
  }
}

// ─── Status Dot ───

class _StatusDot extends StatelessWidget {
  final bool isActive;
  const _StatusDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? CCColors.success : CCColors.outline,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: CCColors.success.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

// ─── Empty State ───

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CCColors.cyanGlow,
              border: Border.all(
                color: CCColors.primaryContainer.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: CCColors.primaryFixedDim,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'ابدأ محادثتك',
            style: TextStyle(
              color: CCColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'اكتب رسالتك أدناه للبدء',
            style: TextStyle(color: CCColors.outline, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
