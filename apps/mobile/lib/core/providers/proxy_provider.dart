// ============================================================
// proxy_provider.dart — Riverpod StateNotifier لإدارة حالة الـ Proxy
// يتواصل مع Bridge عبر WebSocket لتشغيل free-claude-code
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../providers/bridge_provider.dart';

// ─── State ───

enum ProxyStatus { idle, starting, running, error }

class ProxyState {
  final ProxyStatus status;
  final String      baseUrl;
  final String?     error;

  const ProxyState({
    this.status  = ProxyStatus.idle,
    this.baseUrl = '',
    this.error,
  });

  bool get isRunning  => status == ProxyStatus.running;
  bool get isStarting => status == ProxyStatus.starting;

  ProxyState copyWith({
    ProxyStatus? status,
    String?      baseUrl,
    String?      error,
  }) => ProxyState(
    status:  status  ?? this.status,
    baseUrl: baseUrl ?? this.baseUrl,
    error:   error,
  );
}

// ─── Notifier ───

class ProxyNotifier extends Notifier<ProxyState> {
  StreamSubscription<BridgeMessage>? _sub;

  @override
  ProxyState build() {
    ref.onDispose(() => _sub?.cancel());

    // استمع لرسائل البريدج المتعلقة بالـ proxy
    final bridge = ref.watch(bridgeServiceProvider);
    _sub = bridge.messages.listen(_handleMessage);

    // استفسر عن حالة الـ proxy فور الاتصال
    bridge.connectionState.listen((cs) {
      if (cs == ConnectionState.connected) {
        bridge.sendMap({'type': 'proxy_status'});
      }
    });

    return const ProxyState();
  }

  void _handleMessage(BridgeMessage msg) {
    switch (msg.type) {
      case 'proxy_started':
        final url = msg.payload['baseUrl'] as String? ?? '';
        state = state.copyWith(status: ProxyStatus.running, baseUrl: url);

      case 'proxy_status':
        final running = msg.payload['running'] as bool? ?? false;
        final url     = msg.payload['baseUrl']  as String? ?? '';
        state = state.copyWith(
          status:  running ? ProxyStatus.running : ProxyStatus.idle,
          baseUrl: url,
        );

      case 'proxy_stopped':
        state = state.copyWith(status: ProxyStatus.idle, baseUrl: '');

      case 'error':
        // فقط إذا كان الـ error متعلقاً بالـ proxy
        final msg0 = msg.payload['message'] as String? ?? '';
        if (msg0.contains('proxy')) {
          state = state.copyWith(status: ProxyStatus.error, error: msg0);
        }
    }
  }

  // ─── Public API ───

  /// يبدأ الـ proxy بالإعداد المقدم
  Future<void> startProxy({
    required String provider,   // nvidia_nim | open_router | lmstudio | llamacpp
    required String apiKey,
    required String model,
    String? llamacppBaseUrl,
  }) async {
    final bridge = ref.read(bridgeServiceProvider);
    if (bridge.state != ConnectionState.connected) {
      state = state.copyWith(
        status: ProxyStatus.error,
        error: 'Bridge غير متصل — شغّل Bridge أولاً',
      );
      return;
    }

    state = state.copyWith(status: ProxyStatus.starting, error: null);

    bridge.sendMap({
      'type': 'start_proxy',
      'payload': {
        'provider':        provider,
        'apiKey':          apiKey,
        'model':           model,
        ...?( llamacppBaseUrl != null ? {'llamacppBaseUrl': llamacppBaseUrl} : null ),
      },
    });

    // timeout: إذا لم يرد Bridge في 20 ثانية
    await Future.delayed(const Duration(seconds: 20));
    if (state.status == ProxyStatus.starting) {
      state = state.copyWith(
        status: ProxyStatus.error,
        error:  'انتهت المهلة — تأكد من تثبيت free-claude-code:\nuv tool install git+https://github.com/Alishahryar1/free-claude-code.git',
      );
    }
  }

  /// يوقف الـ proxy
  void stopProxy() {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.sendMap({'type': 'stop_proxy'});
    state = state.copyWith(status: ProxyStatus.idle, baseUrl: '');
  }

  /// يُحدّث حالة الـ proxy من Bridge
  void refresh() {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.sendMap({'type': 'proxy_status'});
  }
}

// ─── Provider ───

final proxyProvider = NotifierProvider<ProxyNotifier, ProxyState>(
  ProxyNotifier.new,
);
