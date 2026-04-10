// ============================================================
// settings_provider.dart — إعدادات المزود والنموذج المختار
// يحفظ اختيار المستخدم في SharedPreferences
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Keys ───

const _kProvider = 'selected_provider_id';
const _kModel    = 'selected_model_id';

const _defaultProvider = 'nvidia-nim';
const _defaultModel    = 'meta/llama-3.3-70b-instruct';

// ─── Model معلومات النموذج ───

class ModelInfo {
  final String id;
  final String name;
  final int contextWindow;

  const ModelInfo({required this.id, required this.name, required this.contextWindow});
}

// ─── Model معلومات المزود القادمة من Bridge ───

class LiveProviderInfo {
  final String id;
  final String name;
  final List<ModelInfo> models;

  const LiveProviderInfo({required this.id, required this.name, required this.models});

  factory LiveProviderInfo.fromJson(Map<String, dynamic> json) {
    final rawModels = (json['models'] as List<dynamic>?) ?? [];
    return LiveProviderInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      models: rawModels.map((m) {
        final mm = m as Map<String, dynamic>;
        return ModelInfo(
          id: mm['id'] as String? ?? '',
          name: mm['name'] as String? ?? mm['id'] as String? ?? '',
          contextWindow: (mm['contextWindow'] as num?)?.toInt() ?? 8192,
        );
      }).toList(),
    );
  }
}

// ─── State ───

class SettingsState {
  final String providerId;
  final String modelId;
  final bool isLoading;

  const SettingsState({
    this.providerId = _defaultProvider,
    this.modelId    = _defaultModel,
    this.isLoading  = false,
  });

  SettingsState copyWith({String? providerId, String? modelId, bool? isLoading}) =>
      SettingsState(
        providerId: providerId ?? this.providerId,
        modelId:    modelId    ?? this.modelId,
        isLoading:  isLoading  ?? this.isLoading,
      );
}

// ─── Notifier ───

class SettingsNotifier extends AsyncNotifier<SettingsState> {

  @override
  Future<SettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsState(
      providerId: prefs.getString(_kProvider) ?? _defaultProvider,
      modelId:    prefs.getString(_kModel)    ?? _defaultModel,
    );
  }

  Future<void> selectProvider(String providerId, String firstModelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, providerId);
    await prefs.setString(_kModel, firstModelId);
    state = AsyncData(SettingsState(providerId: providerId, modelId: firstModelId));
  }

  Future<void> selectModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = state.value ?? const SettingsState();
    await prefs.setString(_kModel, modelId);
    state = AsyncData(current.copyWith(modelId: modelId));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);


