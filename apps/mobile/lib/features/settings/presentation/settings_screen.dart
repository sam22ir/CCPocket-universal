// ============================================================
// settings_screen.dart — إعدادات المزودين مع Live Data من Bridge
// يجلب المزودين الحقيقيين + يحفظ الاختيار + Model Switcher
// ============================================================

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/providers_provider.dart';
import '../../../core/providers/bridge_provider.dart';
import '../../../core/providers/proxy_provider.dart';
import '../../../core/providers/translator_provider.dart';
import '../../../core/services/websocket_service.dart' show ConnectionState;
import 'proxy_config_sheet.dart';
import 'tailscale_info_card.dart';

// ─── Icon Map للمزودين ───

const _providerIcons = <String, ({IconData icon, Color color})>{
  'nvidia-nim': (icon: Icons.memory_rounded, color: Color(0xFF76B900)),
  'openai': (icon: Icons.bolt_rounded, color: Color(0xFF10A37F)),
  'gemini': (icon: Icons.auto_awesome_rounded, color: Color(0xFF4285F4)),
  'anthropic': (icon: Icons.psychology_rounded, color: Color(0xFFD97757)),
  'ollama': (icon: Icons.computer_rounded, color: Color(0xFF7C3AED)),
};

const _fallbackProvider = (
  icon: Icons.cloud_outlined,
  color: Color(0xFF888888),
);

// ─── Screen ───

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveState = ref.watch(liveProvidersProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final connAsync = ref.watch(bridgeConnectionProvider);

    final isConnected = connAsync.value == ConnectionState.connected;
    final settings = settingsAsync.value;

    return Scaffold(
      backgroundColor: CCColors.background,
      appBar: AppBar(
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (liveState.status == ProvidersFetchStatus.loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث القائمة',
              onPressed: isConnected
                  ? () => ref.read(liveProvidersProvider.notifier).refresh()
                  : null,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Bridge Status Card ──
          _BridgeStatusCard(isConnected: isConnected),
          const SizedBox(height: 12),

          // ── Tailscale Card ──
          const TailscaleInfoCard(),
          const SizedBox(height: 12),

          // ── Proxy Card ──
          _ProxyCard(isConnected: isConnected),
          const SizedBox(height: 12),

          // ── Translator Card ──
          _TranslatorCard(isConnected: isConnected),
          const SizedBox(height: 20),

          // ── Selected Provider/Model Banner ──
          if (settings != null) ...[
            _ActiveSelectionBanner(settings: settings),
            const SizedBox(height: 20),
          ],

          // ── Providers List ──
          _SectionHeader(
            label: liveState.status == ProvidersFetchStatus.loaded
                ? 'المزودون المتاحون (${liveState.providers.length})'
                : isConnected
                ? 'جارٍ التحميل...'
                : 'المزودون — Bridge غير متصل',
          ),
          const SizedBox(height: 10),

          if (liveState.providers.isEmpty &&
              liveState.status != ProvidersFetchStatus.loading) ...[
            _EmptyProvidersHint(isConnected: isConnected),
          ] else ...[
            ...liveState.providers.map((p) {
              final icons = _providerIcons[p.id] ?? _fallbackProvider;
              final isSelected = settings?.providerId == p.id;
              return _ProviderCard(
                provider: p,
                icon: icons.icon,
                color: icons.color,
                isSelected: isSelected,
                selectedModelId: isSelected ? settings?.modelId : null,
                onSelect: (modelId) {
                  ref
                      .read(settingsProvider.notifier)
                      .selectProvider(p.id, modelId);
                  _showSnack(context, 'تم اختيار ${p.name} — $modelId');
                },
                onModelChange: (modelId) {
                  ref.read(settingsProvider.notifier).selectModel(modelId);
                  _showSnack(context, 'تم تغيير النموذج إلى $modelId');
                },
              );
            }),
          ],

          const SizedBox(height: 24),

          // ── Bridge URL Setting ──
          _SectionHeader(label: 'إعدادات Bridge'),
          const SizedBox(height: 8),
          _BridgeUrlTile(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: CCColors.surfaceContainer,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── Widgets ───

class _BridgeStatusCard extends StatelessWidget {
  final bool isConnected;
  const _BridgeStatusCard({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? CCColors.success : CCColors.error;
    final label = isConnected ? 'متصل ✓' : 'غير متصل';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(30),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Icon(Icons.cable_rounded, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bridge Server',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  'ws://localhost:8765',
                  style: TextStyle(
                    fontSize: 12,
                    color: CCColors.outline,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Proxy Card ───

class _ProxyCard extends ConsumerWidget {
  final bool isConnected;
  const _ProxyCard({required this.isConnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxy = ref.watch(proxyProvider);

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (proxy.status) {
      case ProxyStatus.running:
        statusColor = CCColors.success;
        statusLabel = 'يعمل ✓';
        statusIcon = Icons.hub_rounded;
      case ProxyStatus.starting:
        statusColor = CCColors.primary;
        statusLabel = 'جارٍ التشغيل...';
        statusIcon = Icons.hourglass_top_rounded;
      case ProxyStatus.error:
        statusColor = CCColors.error;
        statusLabel = 'خطأ';
        statusIcon = Icons.error_outline_rounded;
      case ProxyStatus.idle:
        statusColor = CCColors.outline;
        statusLabel = 'متوقف';
        statusIcon = Icons.hub_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: proxy.status == ProxyStatus.starting
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      )
                    : Icon(statusIcon, size: 20, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Proxy (free-claude-code)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      proxy.isRunning
                          ? proxy.baseUrl
                          : 'ANTHROPIC_BASE_URL → NIM / OpenRouter',
                      style: const TextStyle(
                        fontSize: 11,
                        color: CCColors.outline,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // ── Error message ──
          if (proxy.status == ProxyStatus.error && proxy.error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CCColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                proxy.error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: CCColors.error,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Action Buttons ──
          Row(
            children: [
              if (!proxy.isRunning)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isConnected && !proxy.isStarting
                        ? () => ProxyConfigSheet.show(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CCColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text(
                      'تشغيل',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(proxyProvider.notifier).stopProxy(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CCColors.error,
                      side: BorderSide(
                        color: CCColors.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text(
                      'إيقاف',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => ref.read(proxyProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'تحديث',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TranslatorCard extends ConsumerWidget {
  final bool isConnected;
  const _TranslatorCard({required this.isConnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translator = ref.watch(translatorProvider);

    final Color statusColor;
    final String statusLabel;
    switch (translator.status) {
      case TranslatorStatus.running:
        statusColor = CCColors.success;
        statusLabel = 'يعمل ✓';
      case TranslatorStatus.starting:
        statusColor = CCColors.primary;
        statusLabel = 'جارٍ التشغيل...';
      case TranslatorStatus.error:
        statusColor = CCColors.error;
        statusLabel = 'خطأ';
      case TranslatorStatus.idle:
        statusColor = CCColors.outline;
        statusLabel = 'متوقف';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  Icons.compare_arrows_rounded,
                  size: 20,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bridge Translator',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      translator.baseUrl.isNotEmpty
                          ? translator.baseUrl
                          : 'Anthropic Messages API -> OpenAI-compatible',
                      style: const TextStyle(
                        fontSize: 11,
                        color: CCColors.outline,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'يشغّل endpoint محلياً لـ OpenClaude بدون Python proxy، مع ترجمة Anthropic ↔ OpenAI داخل الـ Bridge.',
            style: TextStyle(
              fontSize: 12,
              color: CCColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (translator.status == TranslatorStatus.error &&
              translator.error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CCColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                translator.error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: CCColors.error,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isConnected
                    ? () => ref.read(translatorProvider.notifier).refresh()
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('تحديث'),
              ),
              if (translator.isRunning)
                OutlinedButton.icon(
                  onPressed: () => ref.read(translatorProvider.notifier).stop(),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('إيقاف'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: isConnected
                      ? () => ref
                            .read(translatorProvider.notifier)
                            .start(TranslatorConfig.ollama())
                      : null,
                  icon: const Icon(Icons.computer_rounded, size: 18),
                  label: const Text('Ollama'),
                ),
                OutlinedButton.icon(
                  onPressed: isConnected
                      ? () => _startCloudTranslator(
                          context,
                          ref,
                          TranslatorPreset.nim,
                        )
                      : null,
                  icon: const Icon(Icons.memory_rounded, size: 18),
                  label: const Text('NIM'),
                ),
                OutlinedButton.icon(
                  onPressed: isConnected
                      ? () => _startCloudTranslator(
                          context,
                          ref,
                          TranslatorPreset.openRouter,
                        )
                      : null,
                  icon: const Icon(Icons.router_rounded, size: 18),
                  label: const Text('OpenRouter'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startCloudTranslator(
    BuildContext context,
    WidgetRef ref,
    TranslatorPreset preset,
  ) async {
    final apiKey = await _promptForApiKey(context, preset);
    if (apiKey == null || apiKey.trim().isEmpty) return;

    final notifier = ref.read(translatorProvider.notifier);
    switch (preset) {
      case TranslatorPreset.nim:
        await notifier.start(TranslatorConfig.nim(apiKey: apiKey.trim()));
      case TranslatorPreset.openRouter:
        await notifier.start(
          TranslatorConfig.openRouter(apiKey: apiKey.trim()),
        );
    }
  }

  Future<String?> _promptForApiKey(
    BuildContext context,
    TranslatorPreset preset,
  ) async {
    final controller = TextEditingController();
    final label = switch (preset) {
      TranslatorPreset.nim => 'NVIDIA NIM API Key',
      TranslatorPreset.openRouter => 'OpenRouter API Key',
    };
    final hint = switch (preset) {
      TranslatorPreset.nim => 'nvapi-...',
      TranslatorPreset.openRouter => 'sk-or-...',
    };

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CCColors.surfaceContainer,
        title: const Text('تشغيل Translator'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('تشغيل'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

enum TranslatorPreset { nim, openRouter }

class _ActiveSelectionBanner extends StatelessWidget {
  final SettingsState settings;
  const _ActiveSelectionBanner({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A3A4A), Color(0xFF3D1F5E)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CCColors.primaryContainer.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: CCColors.primaryFixedDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الإعداد الحالي',
                  style: TextStyle(
                    fontSize: 11,
                    color: CCColors.primaryFixedDim,
                  ),
                ),
                Text(
                  '${settings.providerId} • ${settings.modelId.split('/').last}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CCColors.primaryFixedDim,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final LiveProviderInfo provider;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final String? selectedModelId;
  final void Function(String modelId) onSelect;
  final void Function(String modelId) onModelChange;

  const _ProviderCard({
    required this.provider,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.selectedModelId,
    required this.onSelect,
    required this.onModelChange,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? color.withAlpha(15) : CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? color.withAlpha(120)
              : CCColors.outlineVariant.withAlpha(50),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header Row ──
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withAlpha(30),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            title: Text(
              provider.name,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isSelected ? color : null,
              ),
            ),
            subtitle: Text(
              '${provider.models.length} نموذج',
              style: const TextStyle(fontSize: 12, color: CCColors.outline),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: color, size: 22)
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: color.withAlpha(150)),
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: provider.models.isNotEmpty
                        ? () => onSelect(provider.models.first.id)
                        : null,
                    child: const Text('اختر', style: TextStyle(fontSize: 12)),
                  ),
          ),

          // ── Model Selector (إذا مختار) ──
          if (isSelected && provider.models.length > 1) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'النموذج:',
                    style: TextStyle(fontSize: 11, color: CCColors.outline),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: provider.models.map((m) {
                      final isCurrent = m.id == selectedModelId;
                      return GestureDetector(
                        onTap: () => onModelChange(m.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? color.withAlpha(40)
                                : CCColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCurrent
                                  ? color
                                  : CCColors.outlineVariant.withAlpha(80),
                            ),
                          ),
                          child: Text(
                            m.name.split('/').last,
                            style: TextStyle(
                              fontSize: 11,
                              color: isCurrent ? color : CCColors.outline,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyProvidersHint extends StatelessWidget {
  final bool isConnected;
  const _EmptyProvidersHint({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            isConnected ? Icons.cloud_off_rounded : Icons.link_off_rounded,
            size: 40,
            color: CCColors.outline,
          ),
          const SizedBox(height: 12),
          Text(
            isConnected
                ? 'لا يوجد مزودون — تحقق من bridge.config.json'
                : 'Bridge غير متصل\nشغّل: node --experimental-strip-types src/server.ts',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CCColors.outline,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BridgeUrlTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.lan_outlined, size: 20, color: CCColors.outline),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bridge URL',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2),
                Text(
                  'ws://localhost:8765',
                  style: TextStyle(
                    fontSize: 12,
                    color: CCColors.outline,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: CCColors.outline),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: CCColors.outline,
        letterSpacing: 0.8,
      ),
    );
  }
}
