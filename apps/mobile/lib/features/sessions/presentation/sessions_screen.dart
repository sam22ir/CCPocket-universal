// ============================================================
// sessions_screen.dart — قائمة الجلسات (مُرشَّحة بالمشروع)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/export_service.dart';
import '../../chat/providers/chat_provider.dart';

// ─── Provider: جلسات مشروع محدد أو كل الجلسات ───

final _projectSessionsProvider = Provider.family<List<StoredSession>, String?>((ref, projectId) {
  try {
    final storage = ref.read(storageProvider);
    if (projectId != null && projectId.isNotEmpty) {
      return storage.loadSessionsByProject(projectId);
    }
    return storage.loadSessions();
  } catch (_) {
    return [];
  }
});

// ─── Screen ───

class SessionsScreen extends ConsumerWidget {
  final String? projectId;
  final String? projectName;
  final String  projectPath;   // ← مسار المشروع لتمريره لـ ChatArgs

  const SessionsScreen({
    super.key,
    this.projectId,
    this.projectName,
    this.projectPath = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions   = ref.watch(_projectSessionsProvider(projectId));
    final isFiltered = projectId != null && projectId!.isNotEmpty;
    final title      = isFiltered ? (projectName ?? 'جلسات المشروع') : 'CCPocket Universal';

    return Scaffold(
      backgroundColor: CCColors.background,
      appBar: AppBar(
        backgroundColor: CCColors.surface,
        elevation: 0,
        leading: isFiltered
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: CCColors.onSurface),
                onPressed: () => context.canPop() ? context.pop() : context.go('/projects'),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: CCColors.onSurface),
            ),
            if (isFiltered)
              const Text(
                'الجلسات',
                style: TextStyle(fontSize: 10, color: CCColors.onSurfaceVariant),
              ),
          ],
        ),
        actions: [
          if (sessions.isNotEmpty && isFiltered)
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share_rounded, color: CCColors.onSurface),
              tooltip: 'تصدير',
              onSelected: (value) async {
                final svc = ref.read(exportServiceProvider);
                try {
                  final file = value == 'md'
                      ? await svc.exportProjectMarkdown(projectId!, projectName ?? 'project')
                      : await svc.exportSessionJson(sessions.first.id);
                  if (context.mounted) ExportService.showExportSuccess(context, file);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('فشل التصدير: $e'), backgroundColor: CCColors.error),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'md',   child: Row(children: [Icon(Icons.description_outlined, size: 16), SizedBox(width: 8), Text('Markdown')])),
                const PopupMenuItem(value: 'json', child: Row(children: [Icon(Icons.data_object_rounded, size: 16), SizedBox(width: 8), Text('JSON')])),
              ],
            ),
          if (sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: CCColors.onSurface),
              tooltip: 'حذف الكل',
              onPressed: () => _confirmClearAll(context, ref),
            ),
          if (!isFiltered)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: CCColors.onSurface),
              onPressed: () => context.push('/settings'),
            ),
        ],
      ),
      body: sessions.isEmpty
          ? _EmptySessionsState(projectName: isFiltered ? projectName : null)
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(_projectSessionsProvider(projectId)),
              color: CCColors.primary,
              backgroundColor: CCColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: sessions.length,
                itemBuilder: (ctx, i) => _SessionCard(
                  session:  sessions[i],
                  onTap:    () => context.push(
                    '/chat/${sessions[i].id}',
                    // ← نمرر ChatArgs للاحتفاظ بـ project context
                    extra: ChatArgs(
                      sessionId:   sessions[i].id,
                      projectId:   sessions[i].projectId   ?? projectId   ?? '',
                      projectPath: sessions[i].projectPath ?? projectPath,
                    ),
                  ),
                  onDelete: () => _deleteSession(context, ref, sessions[i].id),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // جلسة جديدة — sessionId عشوائي + project context
          final newId = DateTime.now().millisecondsSinceEpoch.toString();
          context.push(
            '/chat/$newId',
            extra: ChatArgs(
              sessionId:   newId,
              projectId:   projectId   ?? '',
              projectPath: projectPath,
            ),
          );
        },
        backgroundColor: CCColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('جلسة جديدة', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _deleteSession(BuildContext context, WidgetRef ref, String id) {
    try {
      ref.read(storageProvider).deleteSession(id);
      ref.invalidate(_projectSessionsProvider(projectId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الجلسة'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CCColors.surfaceContainer,
        title: const Text('حذف الكل؟', style: TextStyle(color: CCColors.onSurface)),
        content: const Text(
          'سيتم حذف جميع المحادثات المحفوظة نهائياً.',
          style: TextStyle(color: CCColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(storageProvider).clearAll();
              ref.invalidate(_projectSessionsProvider(projectId));
            },
            child: const Text('حذف', style: TextStyle(color: CCColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Session Card ───

class _SessionCard extends StatelessWidget {
  final StoredSession session;
  final VoidCallback  onTap;
  final VoidCallback  onDelete;

  const _SessionCard({required this.session, required this.onTap, required this.onDelete});

  String _formatTime(int ms) {
    final dt   = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7)     return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: CCColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CCColors.error.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: CCColors.error),
            SizedBox(height: 4),
            Text('حذف', style: TextStyle(color: CCColors.error, fontSize: 11)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CCColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CCColors.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ProviderBadge(name: session.providerId),
                  const SizedBox(width: 6),
                  _ModelBadge(name: session.modelId.split('/').last),
                  const Spacer(),
                  Text(
                    _formatTime(session.updatedAt),
                    style: const TextStyle(fontSize: 11, color: CCColors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                session.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CCColors.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 12, color: CCColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    session.id.length > 12 ? session.id.substring(0, 12) : session.id,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CCColors.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (session.projectPath != null && session.projectPath!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.folder_outlined, size: 12, color: CCColors.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        session.projectPath!.split('/').last,
                        style: const TextStyle(
                          fontSize: 10,
                          color: CCColors.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: CCColors.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Badges ───

class _ProviderBadge extends StatelessWidget {
  final String name;
  const _ProviderBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CCColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: const TextStyle(fontSize: 10, color: CCColors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ModelBadge extends StatelessWidget {
  final String name;
  const _ModelBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CCColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 10,
          color: CCColors.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ─── Empty State ───

class _EmptySessionsState extends StatelessWidget {
  final String? projectName;
  const _EmptySessionsState({this.projectName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: CCColors.primaryGradient,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            projectName != null ? 'لا توجد جلسات في "$projectName"' : 'لا توجد محادثات محفوظة',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: CCColors.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'اضغط + لبدء جلسة جديدة مع\nNvidia NIM أو أي مزود آخر',
            textAlign: TextAlign.center,
            style: TextStyle(color: CCColors.onSurfaceVariant, fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }
}
