// ============================================================
// secure_storage_service.dart — API Keys via flutter_secure_storage
// ============================================================
// يحفظ ويسترجع API Keys بأمان من Platform Keychain/Keystore
// لا تُخزَّن مطلقاً في Hive أو SharedPreferences بنص واضح
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ── Key constants ──
const _kNimKey        = 'api_key_nvidia_nim';
const _kOpenAIKey     = 'api_key_openai';
const _kGeminiKey     = 'api_key_gemini';
const _kAnthropicKey  = 'api_key_anthropic';
const _kOpenRouterKey = 'api_key_open_router';
// Custom providers: 'api_key_custom_{providerId}'

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // Android: flutter_secure_storage v11+ يدير التشفير تلقائياً
  );

  // ── حفظ API Key لمزود محدد ──
  Future<void> saveApiKey(String providerId, String apiKey) async {
    if (apiKey.trim().isEmpty) {
      await deleteApiKey(providerId);
      return;
    } else {
      await _storage.write(key: _keyFor(providerId), value: apiKey.trim());
    }
  }

  // ── قراءة API Key ──
  Future<String?> getApiKey(String providerId) async {
    return _storage.read(key: _keyFor(providerId));
  }

  // ── حذف API Key ──
  Future<void> deleteApiKey(String providerId) async {
    await _storage.delete(key: _keyFor(providerId));
  }

  // ── قراءة كل الـ Keys المحفوظة (لعرضها كـ ****) ──
  Future<Map<String, bool>> listSavedProviders() async {
    final all = await _storage.readAll();
    final result = <String, bool>{};
    for (final key in all.keys) {
      if (key.startsWith('api_key_')) {
        final providerId = key.replaceFirst('api_key_', '');
        result[providerId] = (all[key]?.isNotEmpty ?? false);
      }
    }
    return result;
  }

  // ── حذف كل الـ Keys (logout) ──
  Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith('api_key_')) {
        await _storage.delete(key: key);
      }
    }
  }

  // ── Helper: اسم الـ key في Keychain ──
  static String _keyFor(String providerId) {
    // تحويل ID إلى key آمن
    final safe = providerId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return switch (safe) {
      'nvidia_nim'  => _kNimKey,
      'openai'      => _kOpenAIKey,
      'gemini'      => _kGeminiKey,
      'anthropic'   => _kAnthropicKey,
      'open_router' => _kOpenRouterKey,
      _             => 'api_key_custom_$safe',
    };
  }
}

// ── Provider ──
final secureStorageProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(),
);
