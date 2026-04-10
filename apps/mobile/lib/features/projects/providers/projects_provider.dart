// ============================================================
// projects_provider.dart — Projects State Management
// يدير قائمة المشاريع: إنشاء / ربط / حذف / تحديث
// يتواصل مع Bridge لإنشاء المجلدات + CLAUDE.md
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/websocket_service.dart';
import '../../../core/providers/bridge_provider.dart';

// ──────────────────────────────────────────────
// State
// ──────────────────────────────────────────────

class ProjectsState {
  final List<StoredProject> projects;
  final bool                isLoading;
  final String?             error;

  const ProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectsState copyWith({
    List<StoredProject>? projects,
    bool?                isLoading,
    String?              error,
  }) => ProjectsState(
    projects:  projects  ?? this.projects,
    isLoading: isLoading ?? this.isLoading,
    error:     error,
  );
}

// ──────────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────────

class ProjectsNotifier extends Notifier<ProjectsState> {
  @override
  ProjectsState build() {
    // تحميل المشاريع من Hive عند البناء
    Future.microtask(() => _loadFromStorage());
    return const ProjectsState(isLoading: true);
  }

  StorageService   get _storage => ref.read(storageProvider);
  WebSocketService get _ws      => ref.read(bridgeServiceProvider);

  // ── تحميل من Hive ──
  void _loadFromStorage() {
    final projects = _storage.loadProjects();
    state = state.copyWith(projects: projects, isLoading: false);
  }

  // ── إنشاء مشروع جديد عبر Bridge ──
  Future<StoredProject?> createProject({
    required String name,
    String?         path,
    String?         description,
    String?         instructions,
  }) async {
    state = state.copyWith(isLoading: true);

    // أرسل للـ Bridge
    _ws.sendMap({
      'type':         'create_project',
      'name':         name,
      'path':         path,
      'description':  description,
      'instructions': instructions,
    }..removeWhere((_, v) => v == null));

    // استمع للرد
    final completer = _awaitResponse('project_created', 'project_linked');

    try {
      final data = await completer.timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      if (data == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'انتهى وقت الاتصال بـ Bridge',
        );
        return null;
      }

      final projectData = data['project'] as Map<String, dynamic>? ?? {};
      final project = StoredProject(
        id:           projectData['id']           as String? ?? _uuid(),
        name:         projectData['name']         as String? ?? name,
        path:         projectData['path']         as String? ?? path ?? '',
        description:  projectData['description']  as String? ?? description ?? '',
        instructions: projectData['instructions'] as String? ?? instructions ?? '',
        createdAt:    projectData['createdAt']    as int?    ?? _now(),
        updatedAt:    projectData['updatedAt']    as int?    ?? _now(),
      );

      await _storage.saveProject(project);
      _loadFromStorage();
      return project;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // ── ربط مجلد موجود ──
  Future<StoredProject?> linkProject({
    required String path,
    required String name,
    String?         description,
    String?         instructions,
  }) async {
    state = state.copyWith(isLoading: true);

    _ws.sendMap({
      'type':  'link_project',
      'path':  path,
      'name':  name,
      'description':  description,
      'instructions': instructions,
    }..removeWhere((_, v) => v == null));

    final completer = _awaitResponse('project_linked', 'project_created');

    try {
      final data = await completer.timeout(const Duration(seconds: 5));
      if (data == null) return null;

      final projectData = data['project'] as Map<String, dynamic>? ?? {};
      final project = StoredProject(
        id:           projectData['id']           as String? ?? _uuid(),
        name:         projectData['name']         as String? ?? name,
        path:         projectData['path']         as String? ?? path,
        description:  description ?? '',
        instructions: projectData['instructions'] as String? ?? '',
        createdAt:    _now(),
        updatedAt:    _now(),
      );

      await _storage.saveProject(project);
      _loadFromStorage();
      return project;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  // ── إضافة مشروع محلياً (بدون Bridge) ──
  Future<StoredProject> addProjectLocally({
    required String name,
    required String path,
    String?         description,
    String?         instructions,
  }) async {
    final project = StoredProject(
      id:           _uuid(),
      name:         name,
      path:         path,
      description:  description ?? '',
      instructions: instructions ?? '# $name\n\nتعليمات المشروع.\n',
      createdAt:    _now(),
      updatedAt:    _now(),
    );
    await _storage.saveProject(project);
    _loadFromStorage();
    return project;
  }

  // ── حذف مشروع ──
  Future<void> deleteProject(String projectId) async {
    // أرسل للـ Bridge (لا يحذف الملفات)
    _ws.sendMap({
      'type':       'delete_project',
      'project_id': projectId,
    });

    await _storage.deleteProject(projectId);
    _loadFromStorage();
  }

  // ── تحديث تعليمات المشروع ──
  Future<void> updateInstructions(String projectId, String instructions) async {
    _ws.sendMap({
      'type':         'update_project_instructions',
      'project_id':   projectId,
      'instructions': instructions,
    });

    final project = _storage.getProject(projectId);
    if (project == null) return;
    await _storage.updateProject(
      project.copyWith(
        instructions: instructions,
        updatedAt:    _now(),
      ),
    );
    _loadFromStorage();
  }

  // ── Refresh ──
  void refresh() => _loadFromStorage();

  // ─── Helpers ───

  /// ينتظر رسالة WebSocket بنوع محدد
  Future<Map<String, dynamic>?> _awaitResponse(String type1, [String? type2]) {
    return _ws.nextMessage((msg) {
      final t = msg['type'] as String?;
      return t == type1 || (type2 != null && t == type2);
    });
  }
}

int    _now()  => DateTime.now().millisecondsSinceEpoch;
String _uuid() {
  const chars = 'abcdef0123456789';
  final r = StringBuffer();
  for (var i = 0; i < 32; i++) {
    if (i == 8 || i == 12 || i == 16 || i == 20) r.write('-');
    r.write(chars[(DateTime.now().microsecondsSinceEpoch >> (i % 8)) % chars.length]);
  }
  return r.toString();
}

// ──────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────

final projectsProvider = NotifierProvider<ProjectsNotifier, ProjectsState>(
  ProjectsNotifier.new,
);
