// ============================================================
// tailscale_provider.dart — Tailscale Remote Access Status
// ============================================================
// يستعلم Bridge عن عنوان Tailscale ويُعرضه للمستخدم
// الاتصال عبر Tailnet يتيح التحكم من جهاز آخر
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import 'bridge_provider.dart';

// ── State ──

class TailscaleState {
  final bool    enabled;
  final String? tailscaleIp;
  final int?    port;
  final String? wsUrl;
  final bool    loading;
  final String? error;

  const TailscaleState({
    this.enabled     = false,
    this.tailscaleIp,
    this.port,
    this.wsUrl,
    this.loading     = false,
    this.error,
  });

  TailscaleState copyWith({
    bool?    enabled,
    String?  tailscaleIp,
    int?     port,
    String?  wsUrl,
    bool?    loading,
    String?  error,
  }) => TailscaleState(
    enabled:     enabled     ?? this.enabled,
    tailscaleIp: tailscaleIp ?? this.tailscaleIp,
    port:        port        ?? this.port,
    wsUrl:       wsUrl       ?? this.wsUrl,
    loading:     loading     ?? this.loading,
    error:       error,
  );

  bool get isActive => enabled && wsUrl != null;
}

// ── Notifier ──

class TailscaleNotifier extends Notifier<TailscaleState> {
  StreamSubscription<BridgeMessage>? _sub;

  @override
  TailscaleState build() {
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(_init);
    return const TailscaleState();
  }

  void _init() {
    final bridge = ref.read(bridgeServiceProvider);

    _sub = bridge.messages.listen((msg) {
      if (msg.type == 'tailscale_status') {
        state = state.copyWith(
          enabled:     msg.payload['enabled']     as bool?   ?? false,
          tailscaleIp: msg.payload['tailscaleIp'] as String?,
          port:        msg.payload['port']        as int?,
          wsUrl:       msg.payload['wsUrl']       as String?,
          loading:     false,
          error:       null,
        );
      }
    });

    // استعلام فوري عند الاتصال
    if (bridge.state == ConnectionState.connected) {
      _query(bridge);
    } else {
      bridge.connectionState.listen((s) {
        if (s == ConnectionState.connected) { _query(bridge); }
      });
    }
  }

  void _query(WebSocketService bridge) {
    state = state.copyWith(loading: true);
    bridge.sendRaw({'type': 'tailscale_status'});
  }

  void refresh() {
    final bridge = ref.read(bridgeServiceProvider);
    _query(bridge);
  }
}

final tailscaleProvider = NotifierProvider<TailscaleNotifier, TailscaleState>(
  TailscaleNotifier.new,
);
