// ============================================================
// translator_provider.dart — Bridge-Embedded Translator State
// ============================================================
// يُدير حالة الـ Bridge-Embedded Translator
// بديل TypeScript خالص عن Python proxy — لا uv، لا Python
// ============================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';
import '../providers/bridge_provider.dart';

// ─── State ───

enum TranslatorStatus { idle, starting, running, error }

class TranslatorState {
  final TranslatorStatus status;
  final String           baseUrl;
  final String?          error;

  const TranslatorState({
    this.status  = TranslatorStatus.idle,
    this.baseUrl = '',
    this.error,
  });

  bool get isRunning  => status == TranslatorStatus.running;
  bool get isStarting => status == TranslatorStatus.starting;

  TranslatorState copyWith({
    TranslatorStatus? status,
    String?           baseUrl,
    String?           error,
  }) => TranslatorState(
    status:  status  ?? this.status,
    baseUrl: baseUrl ?? this.baseUrl,
    error:   error,
  );
}

// ─── Config ───

class TranslatorConfig {
  final String  baseURL;
  final String  apiKey;
  final String  bigModel;
  final String? smallModel;

  const TranslatorConfig({
    required this.baseURL,
    required this.apiKey,
    required this.bigModel,
    this.smallModel,
  });

  /// NVIDIA NIM
  factory TranslatorConfig.nim({required String apiKey}) => TranslatorConfig(
        baseURL:    'https://integrate.api.nvidia.com/v1',
        apiKey:     apiKey,
        bigModel:   'meta/llama-3.3-70b-instruct',
        smallModel: 'meta/llama-3.1-8b-instruct',
      );

  /// OpenRouter (يدعم نماذج مجانية بـ :free suffix)
  factory TranslatorConfig.openRouter({
    required String apiKey,
    String model = 'google/gemini-2.5-pro-preview',
  }) =>
      TranslatorConfig(
        baseURL:  'https://openrouter.ai/api/v1',
        apiKey:   apiKey,
        bigModel: model,
      );

  /// Ollama local — لا يحتاج API key
  factory TranslatorConfig.ollama({String model = 'llama3.2'}) =>
      TranslatorConfig(
        baseURL:  'http://localhost:11434/v1',
        apiKey:   'ollama',
        bigModel: model,
      );

  Map<String, dynamic> toJson() => {
    'baseURL':    baseURL,
    'apiKey':     apiKey,
    'bigModel':   bigModel,
    if (smallModel != null) 'smallModel': smallModel,
  };
}

// ─── Notifier ───

class TranslatorNotifier extends Notifier<TranslatorState> {
  StreamSubscription<BridgeMessage>? _sub;

  @override
  TranslatorState build() {
    ref.onDispose(() => _sub?.cancel());

    // استمع لرسائل البريدج المتعلقة بالـ translator
    final bridge = ref.watch(bridgeServiceProvider);
    _sub = bridge.messages.listen(_handleMessage);

    // استفسر عن حالة الـ translator فور الاتصال
    bridge.connectionState.listen((cs) {
      if (cs == ConnectionState.connected) {
        bridge.sendMap({'type': 'translator_status'});
      }
    });

    return const TranslatorState();
  }

  void _handleMessage(BridgeMessage msg) {
    switch (msg.type) {
      case 'translator_started':
        final url = msg.payload['baseUrl'] as String? ?? '';
        state = state.copyWith(status: TranslatorStatus.running, baseUrl: url);

      case 'translator_status':
        final running = msg.payload['running'] as bool? ?? false;
        final url     = msg.payload['baseUrl']  as String? ?? '';
        state = state.copyWith(
          status:  running ? TranslatorStatus.running : TranslatorStatus.idle,
          baseUrl: url,
        );

      case 'translator_configured':
        // Noop — الإعدادات تحدّثت بدون إيقاف
        break;

      case 'translator_stopped':
        state = state.copyWith(status: TranslatorStatus.idle, baseUrl: '');

      case 'error':
        final errMsg = msg.payload['message'] as String? ?? '';
        if (errMsg.contains('translator')) {
          state = state.copyWith(status: TranslatorStatus.error, error: errMsg);
        }
    }
  }

  // ─── Public API ───

  /// يبدأ الـ Bridge-Embedded Translator
  Future<void> start(TranslatorConfig config) async {
    final bridge = ref.read(bridgeServiceProvider);
    if (bridge.state != ConnectionState.connected) {
      state = state.copyWith(
        status: TranslatorStatus.error,
        error:  'Bridge غير متصل — شغّل Bridge أولاً',
      );
      return;
    }

    state = state.copyWith(status: TranslatorStatus.starting, error: null);

    bridge.sendMap({
      'type':    'start_translator',
      'payload': config.toJson(),
    });

    // timeout: 5 ثواني كافية لأنه لا يحتاج تثبيت Python
    await Future.delayed(const Duration(seconds: 5));
    if (state.status == TranslatorStatus.starting) {
      state = state.copyWith(
        status: TranslatorStatus.error,
        error:  'انتهت المهلة — تحقق من إعدادات الـ API key',
      );
    }
  }

  /// تحديث الإعدادات فوراً (بدون إعادة تشغيل)
  void configure(TranslatorConfig config) {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.sendMap({
      'type':    'configure_translator',
      'payload': config.toJson(),
    });
  }

  /// إيقاف الـ Translator
  void stop() {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.sendMap({'type': 'stop_translator'});
    state = state.copyWith(status: TranslatorStatus.idle, baseUrl: '');
  }

  /// تحديث الحالة من Bridge
  void refresh() {
    final bridge = ref.read(bridgeServiceProvider);
    bridge.sendMap({'type': 'translator_status'});
  }
}

// ─── Provider ───

final translatorProvider = NotifierProvider<TranslatorNotifier, TranslatorState>(
  TranslatorNotifier.new,
);
