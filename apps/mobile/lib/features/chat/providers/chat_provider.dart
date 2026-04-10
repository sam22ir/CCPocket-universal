// ============================================================
// chat_provider.dart — Riverpod + WebSocket Bridge (مع Project Context)
// chatProvider هو family<ChatArgs> يحمل projectId + projectPath
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/providers/bridge_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/storage_service.dart';

// ─── ChatArgs — مفتاح الـ family ───
// يحمل sessionId + contextّ المشروع

class ChatArgs {
  final String sessionId;
  final String projectId; // '' = بدون مشروع
  final String projectPath; // '' = Bridge يختار cwd

  const ChatArgs({
    required this.sessionId,
    this.projectId = '',
    this.projectPath = '',
  });

  @override
  bool operator ==(Object other) =>
      other is ChatArgs &&
      other.sessionId == sessionId &&
      other.projectId == projectId &&
      other.projectPath == projectPath;

  @override
  int get hashCode => Object.hash(sessionId, projectId, projectPath);
}

// ─── Models ───

class ToolCallInfo {
  final String id;
  final String name;
  final Map<String, dynamic> args;
  final String status; // pending | approved | rejected

  const ToolCallInfo({
    required this.id,
    required this.name,
    required this.args,
    this.status = 'pending',
  });

  ToolCallInfo copyWith({String? status}) => ToolCallInfo(
    id: id,
    name: name,
    args: args,
    status: status ?? this.status,
  );
}

class ChatMessage {
  final String id;
  final bool isUser;
  final String content;
  final bool isStreaming;
  final ToolCallInfo? toolCall;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    this.isStreaming = false,
    this.toolCall,
    required this.timestamp,
  });

  bool get hasToolCall => toolCall != null;

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    ToolCallInfo? toolCall,
  }) {
    return ChatMessage(
      id: id,
      isUser: isUser,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      toolCall: toolCall ?? this.toolCall,
      timestamp: timestamp,
    );
  }
}

// ─── State ───

class ChatState {
  final String sessionId;
  final String sessionTitle;
  final String modelName;
  final String projectId;
  final String projectPath;
  final bool isConnected;
  final bool isStreaming;
  final List<ChatMessage> messages;
  final String? error;

  const ChatState({
    this.sessionId = '',
    this.sessionTitle = 'جلسة جديدة',
    this.modelName = 'Llama 3.3 70B',
    this.projectId = '',
    this.projectPath = '',
    this.isConnected = false,
    this.isStreaming = false,
    this.messages = const [],
    this.error,
  });

  // هل هذه الجلسة مرتبطة بمشروع؟
  bool get hasProject => projectId.isNotEmpty;

  ChatState copyWith({
    String? sessionId,
    String? sessionTitle,
    String? modelName,
    String? projectId,
    String? projectPath,
    bool? isConnected,
    bool? isStreaming,
    List<ChatMessage>? messages,
    String? error,
  }) {
    return ChatState(
      sessionId: sessionId ?? this.sessionId,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      modelName: modelName ?? this.modelName,
      projectId: projectId ?? this.projectId,
      projectPath: projectPath ?? this.projectPath,
      isConnected: isConnected ?? this.isConnected,
      isStreaming: isStreaming ?? this.isStreaming,
      messages: messages ?? this.messages,
      error: error,
    );
  }
}

// ─── Notifier ───

class ChatNotifier extends Notifier<ChatState> {
  late final ChatArgs _args;

  StreamSubscription<BridgeMessage>? _msgSub;
  StreamSubscription<ConnectionState>? _connSub;

  String? _bridgeSessionId;
  String? _activeStreamMsgId;
  String? _pendingAiContent;

  @override
  ChatState build() {
    ref.onDispose(() {
      _msgSub?.cancel();
      _connSub?.cancel();
    });

    final settings = ref.read(settingsProvider).value ?? const SettingsState();

    Future.microtask(_init);

    return ChatState(
      sessionId: _args.sessionId,
      projectId: _args.projectId,
      projectPath: _args.projectPath,
      modelName: settings.modelId.split('/').last,
    );
  }

  void _init() async {
    final bridge = ref.read(bridgeServiceProvider);

    _connSub = bridge.connectionState.listen((s) {
      final connected = s == ConnectionState.connected;
      state = state.copyWith(isConnected: connected);
      if (connected) _createSession(bridge);
    });

    _msgSub = bridge.messages.listen(_handleBridgeMessage);

    if (bridge.state == ConnectionState.connected) {
      state = state.copyWith(isConnected: true);
      _createSession(bridge);
    }
  }

  // ─── إنشاء الجلسة في Bridge مع projectPath ───

  void _createSession(WebSocketService bridge) {
    final settings = ref.read(settingsProvider).value ?? const SettingsState();

    // استخدم مسار المشروع الحقيقي — إذا لم يكن موجوداً يستخدم Bridge مسار افتراضي
    final effectivePath = _args.projectPath.isNotEmpty
        ? _args.projectPath
        : '.';

    bridge.createSession(
      sessionId: _args.sessionId,
      projectPath: effectivePath, // ← Project cwd للـ subprocess
      provider: settings.providerId,
      model: settings.modelId,
    );

    state = state.copyWith(modelName: settings.modelId.split('/').last);
  }

  void _handleBridgeMessage(BridgeMessage msg) {
    final sid = msg.payload['session_id'] as String?;
    if (sid != null && _bridgeSessionId != null && sid != _bridgeSessionId) {
      return;
    }

    switch (msg.type) {
      case 'session_created':
        final sessionData = msg.payload['session'] as Map<String, dynamic>?;
        _bridgeSessionId = sessionData?['id'] as String? ?? _args.sessionId;
        final title = sessionData?['title'] as String? ?? 'جلسة جديدة';
        state = state.copyWith(sessionTitle: title, isConnected: true);
        _saveSessionToStorage(title);

      case 'stream_chunk':
        final chunk = msg.payload['chunk'] as String? ?? '';
        final msgId = _activeStreamMsgId;
        if (msgId == null) return;
        _pendingAiContent = (_pendingAiContent ?? '') + chunk;
        state = state.copyWith(
          messages: state.messages.map((m) {
            if (m.id != msgId) return m;
            return m.copyWith(content: m.content + chunk);
          }).toList(),
        );

      case 'stream_done':
        final msgId = _activeStreamMsgId;
        if (msgId == null) return;
        _activeStreamMsgId = null;
        if (_pendingAiContent != null && _pendingAiContent!.isNotEmpty) {
          _saveMessageToStorage(
            id: msgId,
            isUser: false,
            content: _pendingAiContent!,
          );
          _pendingAiContent = null;
        }
        state = state.copyWith(
          messages: state.messages
              .map((m) => m.id == msgId ? m.copyWith(isStreaming: false) : m)
              .toList(),
          isStreaming: false,
        );

      case 'tool_call_request':
        final tool = msg.payload['tool'] as Map<String, dynamic>? ?? {};
        final toolId = tool['id'] as String? ?? '';
        final name = tool['name'] as String? ?? '';
        final args = (tool['args'] as Map<String, dynamic>?) ?? {};
        final tc = ToolCallInfo(id: toolId, name: name, args: args);
        final tcMsg = ChatMessage(
          id: 'tool_$toolId',
          isUser: false,
          content: name,
          toolCall: tc,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(messages: [...state.messages, tcMsg]);

      case 'error':
        final errMsg = msg.payload['message'] as String? ?? 'خطأ غير معروف';
        _activeStreamMsgId = null;
        state = state.copyWith(isStreaming: false, error: errMsg);
    }
  }

  // ─── Public API ───

  void sendMessage(String content) {
    if (content.trim().isEmpty || state.isStreaming) return;

    final bridgeSid = _bridgeSessionId;
    if (bridgeSid == null) {
      _simulateFallback(DateTime.now().millisecondsSinceEpoch.toString());
      return;
    }

    final bridge = ref.read(bridgeServiceProvider);

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      content: content,
      timestamp: DateTime.now(),
    );

    final respId = '${DateTime.now().millisecondsSinceEpoch}_resp';
    final streamingMsg = ChatMessage(
      id: respId,
      isUser: false,
      content: '',
      isStreaming: true,
      timestamp: DateTime.now(),
    );

    _activeStreamMsgId = respId;

    state = state.copyWith(
      messages: [...state.messages, userMsg, streamingMsg],
      isStreaming: true,
      error: null,
    );

    _saveMessageToStorage(id: userMsg.id, isUser: true, content: content);

    if (bridge.state == ConnectionState.connected) {
      bridge.sendMessage(sessionId: bridgeSid, text: content);
    } else {
      _simulateFallback(respId);
    }
  }

  void _simulateFallback(String msgId) async {
    const response =
        '⚠️ Bridge غير متصل. تأكد من تشغيل:\nnpm run dev\nداخل packages/bridge/';
    var accumulated = '';

    for (var i = 0; i < response.length; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      accumulated += response[i];
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == msgId ? m.copyWith(content: accumulated) : m)
            .toList(),
      );
    }

    state = state.copyWith(
      messages: state.messages
          .map((m) => m.id == msgId ? m.copyWith(isStreaming: false) : m)
          .toList(),
      isStreaming: false,
    );
  }

  void cancelStream() {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.cancelStream(sessionId: _args.sessionId);
    _activeStreamMsgId = null;
    state = state.copyWith(
      messages: state.messages
          .map((m) => m.isStreaming ? m.copyWith(isStreaming: false) : m)
          .toList(),
      isStreaming: false,
    );
  }

  void approveToolCall(String toolId) {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.sendRaw({
      'type': 'tool_approve',
      'session_id': _args.sessionId,
      'payload': {'tool_id': toolId},
    });
    _updateToolStatus(toolId, 'approved');
  }

  void rejectToolCall(String toolId) {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.sendRaw({
      'type': 'tool_reject',
      'session_id': _args.sessionId,
      'payload': {'tool_id': toolId},
    });
    _updateToolStatus(toolId, 'rejected');
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void _updateToolStatus(String toolId, String status) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.toolCall?.id != toolId) return m;
        return m.copyWith(toolCall: m.toolCall!.copyWith(status: status));
      }).toList(),
    );
  }

  // ─── Storage Helpers ───

  void _saveSessionToStorage(String title) {
    try {
      final storage = ref.read(storageProvider);
      final settings =
          ref.read(settingsProvider).value ?? const SettingsState();
      storage.saveSession(
        StoredSession(
          id: _bridgeSessionId ?? _args.sessionId,
          title: title,
          providerId: settings.providerId,
          modelId: settings.modelId,
          projectId: _args.projectId.isNotEmpty ? _args.projectId : null,
          projectPath: _args.projectPath.isNotEmpty ? _args.projectPath : null,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {}
  }

  void _saveMessageToStorage({
    required String id,
    required bool isUser,
    required String content,
  }) {
    try {
      final storage = ref.read(storageProvider);
      storage.saveMessage(
        StoredMessage(
          id: id,
          sessionId: _bridgeSessionId ?? _args.sessionId,
          isUser: isUser,
          content: content,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {}
  }
}

// ─── Provider (family by ChatArgs) ───

final chatProvider = NotifierProvider.family<ChatNotifier, ChatState, ChatArgs>(
  (args) => ChatNotifier().._args = args,
);
