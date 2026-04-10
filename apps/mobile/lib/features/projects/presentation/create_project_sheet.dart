// ============================================================
// create_project_sheet.dart — Bottom Sheet إنشاء مشروع
// 3 أوضاع: تلقائي (مجلد جديد) / ربط موجود / يدوي
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../providers/projects_provider.dart';

// ─── enum لأوضاع الإنشاء ───
enum _ProjectMode { auto, link, manual }

class CreateProjectSheet extends StatefulWidget {
  final WidgetRef ref;
  const CreateProjectSheet({super.key, required this.ref});

  @override
  State<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<CreateProjectSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _slideAnim;

  _ProjectMode _mode = _ProjectMode.auto;
  bool         _isCreating = false;

  final _nameCtrl         = TextEditingController();
  final _pathCtrl         = TextEditingController();
  final _descCtrl         = TextEditingController();
  final _instructionsCtrl = TextEditingController(
    text: '# اسم مشروعك\n\nاكتب هنا التعليمات التي تريد أن يعرفها الـ AI عن هذا المشروع.\n',
  );

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _pathCtrl.dispose();
    _descCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(_slideAnim),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPadding),
        decoration: const BoxDecoration(
          color: CCColors.surfaceContainer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CCColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              const Text(
                'مشروع جديد',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CCColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'اختر طريقة إنشاء المشروع',
                style: TextStyle(fontSize: 13, color: CCColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // Mode selector
              _ModeSelector(
                selected: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 20),

              // Name field (دائماً)
              _buildField(
                controller: _nameCtrl,
                label: 'اسم المشروع',
                hint: 'my-awesome-project',
                icon: Icons.drive_file_rename_outline_rounded,
              ),
              const SizedBox(height: 14),

              // Path (حسب الوضع)
              AnimatedCrossFade(
                firstChild: _buildAutoPathHint(),
                secondChild: _buildPathField(),
                crossFadeState: _mode == _ProjectMode.auto
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 250),
              ),
              const SizedBox(height: 14),

              // Description
              _buildField(
                controller: _descCtrl,
                label: 'الوصف (اختياري)',
                hint: 'تطبيق Flutter بـ Firebase...',
                icon: Icons.description_outlined,
              ),
              const SizedBox(height: 14),

              // CLAUDE.md instructions
              _buildInstructionsField(),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CCColors.onSurfaceVariant,
                        side: BorderSide(color: CCColors.outlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _handleCreate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CCColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.rocket_launch_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('إنشاء المشروع', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets Helpers ──

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: CCColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: CCColors.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: CCColors.onSurfaceVariant, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: CCColors.onSurfaceVariant),
            filled: true,
            fillColor: CCColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: CCColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: CCColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CCColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoPathHint() {
    final name = _nameCtrl.text.isEmpty ? 'اسم-المشروع' : _nameCtrl.text;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CCColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CCColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: CCColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _nameCtrl,
              builder: (_, _) => Text(
                'المسار: ~/ccpocket-projects/$name',
                style: const TextStyle(
                  fontSize: 12,
                  color: CCColors.primary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathField() {
    return _buildField(
      controller: _pathCtrl,
      label: _mode == _ProjectMode.link ? 'مسار المجلد الموجود' : 'المسار المخصص',
      hint: _mode == _ProjectMode.link ? '/home/user/my-project' : 'D:/projects/my-app',
      icon: Icons.folder_outlined,
    );
  }

  Widget _buildInstructionsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'تعليمات CLAUDE.md',
              style: TextStyle(fontSize: 12, color: CCColors.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CCColors.tertiary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('اختياري', style: TextStyle(fontSize: 9, color: CCColors.tertiary)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _instructionsCtrl,
          maxLines: 5,
          style: const TextStyle(color: CCColors.onSurface, fontSize: 12, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: CCColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: CCColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: CCColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: CCColors.tertiary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'سيُكتب في CLAUDE.md — الـ AI يقرأه تلقائياً عند بدء كل جلسة',
          style: TextStyle(fontSize: 10, color: CCColors.onSurfaceVariant),
        ),
      ],
    );
  }

  // ── Create Handler ──
  Future<void> _handleCreate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال اسم المشروع')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isCreating = true);

    final notifier = widget.ref.read(projectsProvider.notifier);
    StoredProject? project;

    switch (_mode) {
      case _ProjectMode.auto:
        project = await notifier.createProject(
          name:         name,
          description:  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
        );
      case _ProjectMode.link:
        final path = _pathCtrl.text.trim();
        if (path.isEmpty) {
          setState(() => _isCreating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى إدخال مسار المجلد')),
          );
          return;
        }
        project = await notifier.linkProject(
          path:         path,
          name:         name,
          description:  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
        );
      case _ProjectMode.manual:
        final path = _pathCtrl.text.trim();
        project = await notifier.createProject(
          name:         name,
          path:         path.isEmpty ? null : path,
          description:  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          instructions: _instructionsCtrl.text.trim().isEmpty ? null : _instructionsCtrl.text.trim(),
        );
    }

    setState(() => _isCreating = false);

    if (!mounted) return;

    if (project != null) {
      Navigator.pop(context);
      // افتح sessions المشروع الجديد مباشرةً
      Navigator.pushNamed(context, '/sessions', arguments: project);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إنشاء المشروع — تحقق من الاتصال بـ Bridge')),
      );
    }
  }
}

// ────────────────────────────────────────────────
// Mode Selector
// ────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final _ProjectMode selected;
  final ValueChanged<_ProjectMode> onChanged;

  const _ModeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(
          icon: Icons.auto_fix_high_rounded,
          label: 'تلقائي',
          subtitle: 'مجلد جديد',
          isSelected: selected == _ProjectMode.auto,
          onTap: () => onChanged(_ProjectMode.auto),
        ),
        const SizedBox(width: 8),
        _ModeChip(
          icon: Icons.folder_open_rounded,
          label: 'موجود',
          subtitle: 'ربط مجلد',
          isSelected: selected == _ProjectMode.link,
          onTap: () => onChanged(_ProjectMode.link),
        ),
        const SizedBox(width: 8),
        _ModeChip(
          icon: Icons.edit_location_outlined,
          label: 'يدوي',
          subtitle: 'مسار مخصص',
          isSelected: selected == _ProjectMode.manual,
          onTap: () => onChanged(_ProjectMode.manual),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   subtitle;
  final bool     isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? CCColors.primary.withValues(alpha: 0.12) : CCColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? CCColors.primary : CCColors.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? CCColors.primary : CCColors.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? CCColors.primary : CCColors.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 9, color: CCColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
