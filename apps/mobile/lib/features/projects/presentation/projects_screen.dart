// ============================================================
// projects_screen.dart — شاشة المشاريع (الصفحة الرئيسية)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/bridge_provider.dart';
import '../../../core/services/storage_service.dart';
import '../providers/projects_provider.dart';
import 'create_project_sheet.dart';
import '../../../core/services/websocket_service.dart' as ws;
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/animations.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectsProvider);
    final wsAsync = ref.watch(bridgeConnectionProvider);
    final isOnline = wsAsync.value == ws.ConnectionState.connected;

    return Scaffold(
      backgroundColor: CCColors.background,
      appBar: _buildAppBar(context, ref, isOnline),
      body: _buildBody(context, ref, state),
      floatingActionButton: _buildFab(context, ref),
    );
  }

  // ── AppBar ──
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    bool isOnline,
  ) {
    return AppBar(
      backgroundColor: CCColors.surface,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: CCColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.terminal_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CCPocket Universal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CCColors.onSurface,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isOnline ? CCColors.success : CCColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnline ? 'Bridge متصل' : 'Bridge غير متصل',
                    style: TextStyle(
                      fontSize: 10,
                      color: isOnline
                          ? CCColors.success
                          : CCColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // ── Theme Toggle ──
        Consumer(
          builder: (_, ref, child) {
            final mode = ref.watch(themeProvider).value ?? ThemeMode.dark;
            final isDark = mode == ThemeMode.dark;
            return IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: CCColors.onSurface,
              ),
              onPressed: () => ref.read(themeProvider.notifier).toggle(),
              tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: CCColors.onSurface),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          tooltip: 'الإعدادات',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Body ──
  Widget _buildBody(BuildContext context, WidgetRef ref, ProjectsState state) {
    if (state.isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: 4,
        separatorBuilder: (_, child) => const SizedBox(height: 12),
        itemBuilder: (_, idx) => const ShimmerCard(height: 88),
      );
    }

    if (state.projects.isEmpty) {
      return _EmptyProjectsState(
        onCreateTap: () => _openCreateSheet(context, ref),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.read(projectsProvider.notifier).refresh(),
      color: CCColors.primary,
      backgroundColor: CCColors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: state.projects.length,
        itemBuilder: (ctx, i) => FadeSlideIn(
          delay: Duration(milliseconds: i * 55),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ScaleTap(
              child: _ProjectCard(
                project: state.projects[i],
                onTap: () => context.push(
                  '/projects/${state.projects[i].id}/sessions',
                  extra: state.projects[i],
                ),
                onDelete: () => ref
                    .read(projectsProvider.notifier)
                    .deleteProject(state.projects[i].id),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── FAB ──
  Widget _buildFab(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _openCreateSheet(context, ref),
      backgroundColor: CCColors.primary,
      foregroundColor: Colors.black,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'مشروع جديد',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateProjectSheet(ref: ref),
    );
  }
}

// ────────────────────────────────────────────────
// Project Card
// ────────────────────────────────────────────────

class _ProjectCard extends ConsumerWidget {
  final StoredProject project;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // عدد جلسات هذا المشروع
    int count = 0;
    try {
      count = ref
          .read(storageProvider)
          .loadSessionsByProject(project.id)
          .length;
    } catch (_) {}

    return Dismissible(
      key: Key(project.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: CCColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: CCColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CCColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CCColors.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: CCColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CCColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.path,
                          style: const TextStyle(
                            fontSize: 11,
                            color: CCColors.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: CCColors.onSurfaceVariant,
                  ),
                ],
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  project.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CCColors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '$count جلسة',
                  ),
                  const SizedBox(width: 8),
                  _MetaChip(
                    icon: Icons.access_time_rounded,
                    label: _relativeTime(project.updatedAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(int ms) {
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} د';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return 'منذ ${diff.inDays ~/ 30} شهر';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CCColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 11, color: CCColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: CCColors.primary),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Empty State
// ────────────────────────────────────────────────

class _EmptyProjectsState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyProjectsState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: CCColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد مشاريع بعد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: CCColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أنشئ مشروعاً جديداً أو اربط مجلداً موجوداً\nلبدء المحادثة مع الـ AI',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CCColors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add_rounded),
            label: const Text('أنشئ مشروعك الأول'),
            style: ElevatedButton.styleFrom(
              backgroundColor: CCColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
