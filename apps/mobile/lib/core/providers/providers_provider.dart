// ============================================================
// providers_provider.dart — جلب المزودين الحيين من Bridge
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import 'bridge_provider.dart';
import 'settings_provider.dart';

// ─── State ───

enum ProvidersFetchStatus { idle, loading, loaded, error }

class ProvidersState {
  final List<LiveProviderInfo> providers;
  final ProvidersFetchStatus   status;
  final String?                errorMsg;

  const ProvidersState({
    this.providers = const [],
    this.status    = ProvidersFetchStatus.idle,
    this.errorMsg,
  });

  ProvidersState copyWith({
    List<LiveProviderInfo>? providers,
    ProvidersFetchStatus?   status,
    String?                 errorMsg,
  }) => ProvidersState(
    providers: providers ?? this.providers,
    status:    status    ?? this.status,
    errorMsg:  errorMsg,
  );
}

// ─── Notifier ───

class ProvidersNotifier extends Notifier<ProvidersState> {
  StreamSubscription<BridgeMessage>? _sub;

  @override
  ProvidersState build() {
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(_setup);
    return const ProvidersState();
  }

  void _setup() {
    final bridge = ref.read(bridgeServiceProvider);

    _sub = bridge.messages.listen((msg) {
      if (msg.type == 'providers_list') {
        final raw = msg.payload['providers'] as List<dynamic>? ?? [];
        final list = raw
            .map((e) => LiveProviderInfo.fromJson(e as Map<String, dynamic>))
            .where((p) => p.id.isNotEmpty)
            .toList();
        state = state.copyWith(providers: list, status: ProvidersFetchStatus.loaded);
      }
    });

    // اطلب القائمة فور الاتصال
    if (bridge.state == ConnectionState.connected) {
      _fetchProviders(bridge);
    } else {
      bridge.connectionState.listen((s) {
        if (s == ConnectionState.connected) _fetchProviders(bridge);
      });
    }
  }

  void _fetchProviders(WebSocketService bridge) {
    state = state.copyWith(status: ProvidersFetchStatus.loading);
    bridge.sendRaw({'type': 'list_providers'});
  }

  void refresh() {
    final bridge = ref.read(bridgeServiceProvider);
    _fetchProviders(bridge);
  }
}

final liveProvidersProvider =
    NotifierProvider<ProvidersNotifier, ProvidersState>(ProvidersNotifier.new);


