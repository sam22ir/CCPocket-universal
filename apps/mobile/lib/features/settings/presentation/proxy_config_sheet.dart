// ============================================================
// proxy_config_sheet.dart — Bottom Sheet لإعداد الـ Proxy
// يُتيح للمستخدم اختيار الـ provider + إدخال API Key + تشغيل الـ proxy
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/proxy_provider.dart';

// ─── Provider خيارات الـ Proxy ───

const _proxyProviders = [
  _ProxyProviderOption(
    id:          'nvidia_nim',
    name:        'NVIDIA NIM',
    subtitle:    '40 طلب/دقيقة — مجاناً',
    icon:        Icons.memory_rounded,
    color:       Color(0xFF76B900),
    keyLabel:    'NVIDIA NIM API Key',
    keyHint:     'nvapi-...',
    modelPrefix: 'nvidia_nim/',
    defaultModel:'nvidia_nim/meta/llama-3.3-70b-instruct',
  ),
  _ProxyProviderOption(
    id:          'open_router',
    name:        'OpenRouter',
    subtitle:    'مئات النماذج — بعضها مجاناً',
    icon:        Icons.router_rounded,
    color:       Color(0xFF7C3AED),
    keyLabel:    'OpenRouter API Key',
    keyHint:     'sk-or-...',
    modelPrefix: 'open_router/',
    defaultModel:'open_router/deepseek/deepseek-r1-0528:free',
  ),
  _ProxyProviderOption(
    id:          'lmstudio',
    name:        'LM Studio',
    subtitle:    'محلي — لا يحتاج API Key',
    icon:        Icons.computer_rounded,
    color:       Color(0xFF0EA5E9),
    keyLabel:    '',
    keyHint:     '',
    modelPrefix: 'lmstudio/',
    defaultModel:'lmstudio/unsloth/Qwen3.5-35B-A3B-GGUF',
    noKeyNeeded: true,
  ),
];

class _ProxyProviderOption {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String keyLabel;
  final String keyHint;
  final String modelPrefix;
  final String defaultModel;
  final bool noKeyNeeded;

  const _ProxyProviderOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.keyLabel,
    required this.keyHint,
    required this.modelPrefix,
    required this.defaultModel,
    this.noKeyNeeded = false,
  });
}

// ─── Sheet ───

class ProxyConfigSheet extends ConsumerStatefulWidget {
  const ProxyConfigSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ProxyConfigSheet(),
  );

  @override
  ConsumerState<ProxyConfigSheet> createState() => _ProxyConfigSheetState();
}

class _ProxyConfigSheetState extends ConsumerState<ProxyConfigSheet> {
  int    _selectedIndex = 0;
  final  _keyController   = TextEditingController();
  final  _modelController = TextEditingController();
  bool   _obscureKey      = true;

  @override
  void initState() {
    super.initState();
    _modelController.text = _proxyProviders[0].defaultModel;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  _ProxyProviderOption get _selected => _proxyProviders[_selectedIndex];

  void _onProviderChange(int index) {
    setState(() {
      _selectedIndex = index;
      _modelController.text = _proxyProviders[index].defaultModel;
    });
  }

  Future<void> _start() async {
    final p = _selected;
    if (!p.noKeyNeeded && _keyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل API Key أولاً'), backgroundColor: CCColors.error),
      );
      return;
    }

    await ref.read(proxyProvider.notifier).startProxy(
      provider: p.id,
      apiKey:   _keyController.text.trim(),
      model:    _modelController.text.trim().isEmpty ? p.defaultModel : _modelController.text.trim(),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final proxy     = ref.watch(proxyProvider);
    final isLoading = proxy.isStarting;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize:     0.95,
      minChildSize:     0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: CCColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle ──
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: CCColors.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CCColors.primary.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.hub_rounded, color: CCColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إعداد الـ Proxy', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('free-claude-code → ANTHROPIC_BASE_URL',
                            style: TextStyle(fontSize: 11, color: CCColors.outline, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            const Divider(height: 1),

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [

                  // ── Provider Selector ──
                  const Text('اختر المزود', style: TextStyle(fontSize: 12, color: CCColors.outline, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ..._proxyProviders.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final sel = i == _selectedIndex;
                    return GestureDetector(
                      onTap: () => _onProviderChange(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: sel ? p.color.withValues(alpha: 0.08) : CCColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel ? p.color.withValues(alpha: 0.5) : CCColors.outlineVariant.withValues(alpha: 0.4),
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(p.icon, color: p.color, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? p.color : null)),
                                  Text(p.subtitle, style: const TextStyle(fontSize: 11, color: CCColors.outline)),
                                ],
                              ),
                            ),
                            if (sel) Icon(Icons.check_circle_rounded, color: p.color, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // ── API Key ──
                  if (!_selected.noKeyNeeded) ...[
                    Text(_selected.keyLabel,
                        style: const TextStyle(fontSize: 12, color: CCColors.outline, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller:  _keyController,
                      obscureText: _obscureKey,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        hintText:        _selected.keyHint,
                        hintStyle:       const TextStyle(color: CCColors.outline, fontFamily: 'monospace'),
                        filled:          true,
                        fillColor:       CCColors.surfaceContainer,
                        border:          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Model ──
                  const Text('النموذج', style: TextStyle(fontSize: 12, color: CCColors.outline, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _modelController,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: InputDecoration(
                      filled:         true,
                      fillColor:      CCColors.surfaceContainer,
                      border:         OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintText:       _selected.defaultModel,
                      hintStyle:      const TextStyle(color: CCColors.outline, fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Install hint ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CCColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CCColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: CCColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تأكد من تثبيت الـ proxy:\nuv tool install git+https://github.com/Alishahryar1/free-claude-code.git',
                            style: TextStyle(fontSize: 11, color: CCColors.outline, fontFamily: 'monospace', height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Start Button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _start,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CCColors.primary,
                        foregroundColor: Colors.white,
                        padding:         const EdgeInsets.symmetric(vertical: 14),
                        shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: isLoading
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        isLoading ? 'جارٍ التشغيل...' : 'تشغيل الـ Proxy',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
