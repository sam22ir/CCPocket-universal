// ============================================================
// bridge_provider.dart — Riverpod Provider للـ WebSocket
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';

// Singleton service — auto-connects on first use
final bridgeServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();

  // Connect in background
  Future.microtask(() => service.connect());

  // Cleanup on dispose
  ref.onDispose(service.dispose);

  return service;
});

// Connection state stream
final bridgeConnectionProvider = StreamProvider<ConnectionState>((ref) {
  final service = ref.watch(bridgeServiceProvider);
  return service.connectionState;
});

// Messages stream (broadcast)
final bridgeMessagesProvider = StreamProvider<BridgeMessage>((ref) {
  final service = ref.watch(bridgeServiceProvider);
  return service.messages;
});


