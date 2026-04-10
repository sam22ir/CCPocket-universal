// ============================================================
// provider_drawer.dart — درج اختيار المزود والنموذج (Bottom Sheet)
// ============================================================
// يُعرض من Chat Screen للتبديل السريع بين المزودين
// يستخدم: liveProvidersProvider + settingsProvider
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/providers_provider.dart';

// ── أيقونات المزودين ──
const _icons = <String, ({IconData icon, Color color})>{
  'nvidia-nim': (icon: Icons.memory_rounded,       color: Color(0xFF76B900)),
  'openai':     (icon: Icons.bolt_rounded,          color: Color(0xFF10A37F)),
  'gemini':     (icon: Icons.auto_awesome_rounded,  color: Color(0xFF4285F4)),
  'anthropic':  (icon: Icons.psychology_rounded,    color: Color(0xFFD97757)),
  'ollama':     (icon: Icons.computer_rounded,      color: Color(0xFF7C3AED)),
};
const _fallback = (icon: Icons.cloud_outlined, color: Color(0xFF888888));

/// حوّل ID إلى اسم عرض
String _displayName(String id) {
  const names = {
    'nvidia-nim': 'NVIDIA NIM',
    'openai':     'OpenAI',
    'gemini':     'Google Gemini',
    'anthropic':  'Anthropic',
    'ollama':     'Ollama (Local)',
  };
  return names[id] ?? id;
}

// ============================================================
// showProviderDrawer — helper
// ============================================================

void showProviderDrawer(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ProviderDrawer(),
  );
}

// ============================================================
// ProviderDrawer
// ============================================================

class ProviderDrawer extends ConsumerStatefulWidget {
  const ProviderDrawer({super.key});

  @override
  ConsumerState<ProviderDrawer> createState() => _ProviderDrawerState();
}

class _ProviderDrawerState extends ConsumerState<ProviderDrawer> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final settingsAsync  = ref.watch(settingsProvider);
    final liveState      = ref.watch(liveProvidersProvider);

    final activeProvider = settingsAsync.value?.providerId ?? 'nvidia-nim';
    final activeModel    = settingsAsync.value?.modelId    ?? '';

    // استخدم المزودين من Bridge إن وُجدوا، وإلا fallbacks
    final providers = liveState.providers.isNotEmpty
        ? liveState.providers
        : _fallbackProviders;

    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: CCColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _Handle(),
            _Header(onClose: () => Navigator.pop(context)),
            const Divider(height: 1, color: CCColors.outlineVariant),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  for (final p in providers)
                    _ProviderTile(
                      info:       p,
                      isActive:   p.id == activeProvider,
                      isExpanded: _expandedId == p.id,
                      activeModel: activeModel,
                      onSelect:   (modelId) async {
                        await ref.read(settingsProvider.notifier)
                            .selectProvider(p.id, modelId ?? p.models.firstOrNull?.id ?? '');
                        if (context.mounted) Navigator.pop(context);
                      },
                      onExpand:   () => setState(() {
                        _expandedId = _expandedId == p.id ? null : p.id;
                      }),
                    ),

                  const SizedBox(height: 4),
                  const Divider(height: 1, color: CCColors.outlineVariant),

                  _AddCustomTile(onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fallback providers حين يكون Bridge غير متصل
  static const _fallbackProviders = [
    LiveProviderInfo(id: 'nvidia-nim', name: 'NVIDIA NIM',     models: []),
    LiveProviderInfo(id: 'openai',     name: 'OpenAI',          models: []),
    LiveProviderInfo(id: 'gemini',     name: 'Google Gemini',   models: []),
    LiveProviderInfo(id: 'anthropic',  name: 'Anthropic',       models: []),
    LiveProviderInfo(id: 'ollama',     name: 'Ollama (Local)',   models: []),
  ];
}

// ── Handle ──
class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: CCColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

// ── Header ──
class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: CCColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.cloud_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختر المزود', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: CCColors.onSurface,
                )),
                Text('مزود الذكاء الاصطناعي والنموذج', style: TextStyle(
                  fontSize: 11, color: CCColors.onSurfaceVariant,
                )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: CCColors.onSurfaceVariant),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ── Provider Tile ──
class _ProviderTile extends ConsumerWidget {
  final LiveProviderInfo info;
  final bool             isActive;
  final bool             isExpanded;
  final String           activeModel;
  final void Function(String? modelId) onSelect;
  final VoidCallback     onExpand;

  const _ProviderTile({
    required this.info,
    required this.isActive,
    required this.isExpanded,
    required this.activeModel,
    required this.onSelect,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = _icons[info.id] ?? _fallback;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? CCColors.primary.withValues(alpha: 0.08)
            : CCColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? CCColors.primary.withValues(alpha: 0.4) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: info.models.isEmpty ? () => onSelect(null) : onExpand,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // أيقونة
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(meta.icon, size: 18, color: meta.color),
                  ),
                  const SizedBox(width: 12),

                  // الاسم
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName(info.id),
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600,
                            color: isActive ? CCColors.primary : CCColors.onSurface,
                          ),
                        ),
                        if (info.models.isNotEmpty)
                          Text('${info.models.length} نموذج',
                            style: const TextStyle(fontSize: 11, color: CCColors.onSurfaceVariant)),
                      ],
                    ),
                  ),

                  // Active chip
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CCColors.primary, borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('نشط', style: TextStyle(
                        fontSize: 10, color: Colors.black, fontWeight: FontWeight.w700,
                      )),
                    ),

                  // Expand arrow
                  if (info.models.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: CCColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Model list ──
          if (isExpanded && info.models.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  const Divider(height: 1, indent: 14, endIndent: 14, color: CCColors.outlineVariant),
                  for (final model in info.models)
                    _ModelItem(
                      model:       model,
                      isActive:    model.id == activeModel,
                      onTap:       () => onSelect(model.id),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Model Item ──
class _ModelItem extends StatelessWidget {
  final ModelInfo    model;
  final bool         isActive;
  final VoidCallback onTap;

  const _ModelItem({required this.model, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isActive ? CCColors.primary : CCColors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                model.name.isNotEmpty ? model.name : model.id,
                style: TextStyle(
                  fontSize: 12, fontFamily: 'monospace',
                  color: isActive ? CCColors.primary : CCColors.onSurface,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── إضافة مزود مخصص ──
class _AddCustomTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCustomTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CCColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CCColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.add_rounded, size: 18, color: CCColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('إضافة مزود مخصص', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: CCColors.primary,
                  )),
                  Text('أي مزود OpenAI-compatible', style: TextStyle(
                    fontSize: 11, color: CCColors.onSurfaceVariant,
                  )),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: CCColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
