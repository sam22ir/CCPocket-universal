// ============================================================
// websocket_service.dart — خدمة WebSocket للتواصل مع Bridge Server
// بروتوكول: JSON عبر WebSocket على ws://localhost:8765
// Auto-reconnect بـ Exponential Backoff: 2s → 4s → 8s → 16s → 30s
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionState { disconnected, connecting, connected, error }

class BridgeMessage {
  final String type;
  final Map<String, dynamic> payload;

  const BridgeMessage({required this.type, required this.payload});

  Map<String, dynamic> toJson() => {'type': type, ...payload};

  factory BridgeMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    final payload = Map<String, dynamic>.from(json)..remove('type');
    return BridgeMessage(type: type, payload: payload);
  }
}

class WebSocketService {
  static const _defaultUrl = 'ws://localhost:8765';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _retryTimer;

  final _messageController = StreamController<BridgeMessage>.broadcast();
  final _stateController   = StreamController<ConnectionState>.broadcast();

  Stream<BridgeMessage>   get messages        => _messageController.stream;
  Stream<ConnectionState> get connectionState => _stateController.stream;

  ConnectionState _state = ConnectionState.disconnected;
  ConnectionState get state => _state;

  bool   _disposed    = false;
  String _url         = _defaultUrl;
  int    _retryCount  = 0;

  // ── Exponential Backoff: 2s → 4s → 8s → 16s → 30s ──
  Duration _backoffDelay() {
    final seconds = (2 << _retryCount).clamp(2, 30);
    _retryCount   = (_retryCount + 1).clamp(0, 5);
    return Duration(seconds: seconds);
  }

  // ============================================================
  // Connect
  // ============================================================

  Future<void> connect({String url = _defaultUrl}) async {
    if (_disposed) return;
    if (_state == ConnectionState.connected ||
        _state == ConnectionState.connecting) { return; }

    _url = url;
    _setState(ConnectionState.connecting);

    try {
      final uri  = Uri.parse(url);
      _channel   = WebSocketChannel.connect(uri);

      // ready يُلقي استثناء إذا رُفض الاتصال
      await _channel!.ready;

      _setState(ConnectionState.connected);
      _retryCount = 0; // إعادة تعيين العداد عند النجاح
      debugPrint('[Bridge] ✅ متصل بـ $url');

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone:  _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      final delay = _backoffDelay();
      debugPrint('[Bridge] ❌ فشل الاتصال: $e — إعادة بعد ${delay.inSeconds}s');
      _setState(ConnectionState.error);
      _scheduleRetry(delay);
    }
  }

  void _scheduleRetry([Duration? delay]) {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay ?? _backoffDelay(), () async {
      if (!_disposed && _state != ConnectionState.connected) {
        await connect(url: _url);
      }
    });
  }

  // ============================================================
  // Message handling
  // ============================================================

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final msg  = BridgeMessage.fromJson(json);
      debugPrint('[Bridge] ← ${msg.type}');
      _messageController.add(msg);
    } catch (_) {
      // ignore malformed messages
    }
  }

  void _onError(dynamic error) {
    debugPrint('[Bridge] ⚠️ خطأ: $error');
    _setState(ConnectionState.error);
    _scheduleRetry();
  }

  void _onDone() {
    debugPrint('[Bridge] 🔌 انقطع الاتصال — إعادة المحاولة');
    _setState(ConnectionState.disconnected);
    _scheduleRetry();
  }

  // ============================================================
  // Send helpers
  // ============================================================

  void send(BridgeMessage message) {
    if (_state != ConnectionState.connected) return;
    debugPrint('[Bridge] → ${message.type}');
    _channel?.sink.add(jsonEncode(message.toJson()));
  }

  /// إرسال Map مباشرةً
  void sendMap(Map<String, dynamic> data) {
    if (_state != ConnectionState.connected) return;
    debugPrint('[Bridge] → ${data['type']}');
    _channel?.sink.add(jsonEncode(data));
  }

  void sendRaw(Map<String, dynamic> data) {
    if (_state != ConnectionState.connected) return;
    _channel?.sink.add(jsonEncode(data));
  }

  /// ينتظر أول رسالة تُطابق الـ predicate
  Future<Map<String, dynamic>?> nextMessage(
    bool Function(Map<String, dynamic>) predicate,
  ) {
    final completer = Completer<Map<String, dynamic>?>();
    StreamSubscription<BridgeMessage>? sub;
    sub = messages.listen((msg) {
      final full = {'type': msg.type, ...msg.payload};
      if (predicate(full)) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(full);
      }
    });
    return completer.future;
  }

  // ─── High-level session helpers ───

  void createSession({
    required String sessionId,
    required String projectPath,
    String? provider,
    String? model,
  }) {
    send(BridgeMessage(
      type: 'create_session',
      payload: {
        'session_id':   sessionId,
        'project_path': projectPath,
        'provider':     provider ?? 'nvidia-nim',
        'model':        model    ?? 'meta/llama-3.3-70b-instruct',
      },
    ));
  }

  void sendMessage({required String sessionId, required String text}) {
    send(BridgeMessage(
      type: 'send_message',
      payload: {'session_id': sessionId, 'text': text},
    ));
  }

  void cancelStream({required String sessionId}) {
    send(BridgeMessage(
      type: 'cancel_stream',
      payload: {'session_id': sessionId},
    ));
  }

  void ping() => send(BridgeMessage(type: 'ping', payload: {}));

  // ============================================================
  // State helpers
  // ============================================================

  void _setState(ConnectionState newState) {
    _state = newState;
    if (!_stateController.isClosed) { _stateController.add(newState); }
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _setState(ConnectionState.disconnected);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}
