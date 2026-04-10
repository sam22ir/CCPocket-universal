// ============================================================
// storage_service.dart — Persistent Storage via Hive CE
// يحفظ المشاريع والجلسات والرسائل محلياً
// ============================================================

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ──────────────────────────────────────────────
// Box Keys
// ──────────────────────────────────────────────

const _kProjectsBox = 'cc_projects';
const _kSessionsBox = 'cc_sessions';
const _kMessagesBox = 'cc_messages';

// ──────────────────────────────────────────────
// Models
// ──────────────────────────────────────────────

class StoredProject {
  final String  id;
  final String  name;
  final String  path;           // المسار الحقيقي على الجهاز
  final String  description;
  final String  instructions;   // محتوى CLAUDE.md
  final int     createdAt;
  final int     updatedAt;

  StoredProject({
    required this.id,
    required this.name,
    required this.path,
    this.description  = '',
    this.instructions = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id':           id,
    'name':         name,
    'path':         path,
    'description':  description,
    'instructions': instructions,
    'createdAt':    createdAt,
    'updatedAt':    updatedAt,
  };

  factory StoredProject.fromJson(Map<dynamic, dynamic> json) => StoredProject(
    id:           json['id']           as String,
    name:         json['name']         as String? ?? 'مشروع',
    path:         json['path']         as String? ?? '',
    description:  json['description']  as String? ?? '',
    instructions: json['instructions'] as String? ?? '',
    createdAt:    json['createdAt']    as int? ?? 0,
    updatedAt:    json['updatedAt']    as int? ?? 0,
  );

  StoredProject copyWith({
    String? name,
    String? description,
    String? instructions,
    int?    updatedAt,
  }) => StoredProject(
    id:           id,
    name:         name         ?? this.name,
    path:         path,
    description:  description  ?? this.description,
    instructions: instructions ?? this.instructions,
    createdAt:    createdAt,
    updatedAt:    updatedAt    ?? this.updatedAt,
  );
}

// ─────────────────────────────

class StoredSession {
  final String  id;
  final String  title;
  final String  providerId;
  final String  modelId;
  final String? projectId;      // ← ربط بالمشروع
  final String? projectPath;    // ← مسار المشروع (للعرض السريع)
  final int     createdAt;
  final int     updatedAt;

  StoredSession({
    required this.id,
    required this.title,
    required this.providerId,
    required this.modelId,
    this.projectId,
    this.projectPath,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id':          id,
    'title':       title,
    'providerId':  providerId,
    'modelId':     modelId,
    'projectId':   projectId,
    'projectPath': projectPath,
    'createdAt':   createdAt,
    'updatedAt':   updatedAt,
  };

  factory StoredSession.fromJson(Map<dynamic, dynamic> json) => StoredSession(
    id:          json['id']          as String,
    title:       json['title']       as String? ?? 'محادثة',
    providerId:  json['providerId']  as String? ?? 'nvidia-nim',
    modelId:     json['modelId']     as String? ?? '',
    projectId:   json['projectId']   as String?,
    projectPath: json['projectPath'] as String?,
    createdAt:   json['createdAt']   as int? ?? 0,
    updatedAt:   json['updatedAt']   as int? ?? 0,
  );
}

// ─────────────────────────────

class StoredMessage {
  final String id;
  final String sessionId;
  final bool   isUser;
  final String content;
  final int    timestamp;

  StoredMessage({
    required this.id,
    required this.sessionId,
    required this.isUser,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id':        id,
    'sessionId': sessionId,
    'isUser':    isUser,
    'content':   content,
    'timestamp': timestamp,
  };

  factory StoredMessage.fromJson(Map<dynamic, dynamic> json) => StoredMessage(
    id:        json['id']        as String,
    sessionId: json['sessionId'] as String,
    isUser:    json['isUser']    as bool? ?? false,
    content:   json['content']   as String? ?? '',
    timestamp: json['timestamp'] as int? ?? 0,
  );
}

// ──────────────────────────────────────────────
// StorageService
// ──────────────────────────────────────────────

class StorageService {
  late Box _projectsBox;
  late Box _sessionsBox;
  late Box _messagesBox;

  // ── Init ──
  Future<void> init() async {
    await Hive.initFlutter();
    _projectsBox = await Hive.openBox(_kProjectsBox);
    _sessionsBox = await Hive.openBox(_kSessionsBox);
    _messagesBox = await Hive.openBox(_kMessagesBox);
  }

  // ──────────────────────────────────────────────
  // Projects
  // ──────────────────────────────────────────────

  Future<void> saveProject(StoredProject project) async {
    await _projectsBox.put(project.id, project.toJson());
  }

  List<StoredProject> loadProjects() {
    return _projectsBox.values
        .map((v) => StoredProject.fromJson(v as Map))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> deleteProject(String projectId) async {
    await _projectsBox.delete(projectId);
    // لا نحذف الجلسات — نبقيها بدون projectId linkage
  }

  Future<void> updateProject(StoredProject project) async {
    await _projectsBox.put(project.id, project.toJson());
  }

  StoredProject? getProject(String projectId) {
    final raw = _projectsBox.get(projectId) as Map?;
    if (raw == null) return null;
    return StoredProject.fromJson(raw);
  }

  // ──────────────────────────────────────────────
  // Sessions
  // ──────────────────────────────────────────────

  Future<void> saveSession(StoredSession session) async {
    await _sessionsBox.put(session.id, session.toJson());
  }

  /// كل الجلسات — للـ sessions screen العام
  List<StoredSession> loadSessions() {
    return _sessionsBox.values
        .map((v) => StoredSession.fromJson(v as Map))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// جلسات مشروع محدد
  List<StoredSession> loadSessionsByProject(String projectId) {
    return _sessionsBox.values
        .map((v) => StoredSession.fromJson(v as Map))
        .where((s) => s.projectId == projectId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> deleteSession(String sessionId) async {
    await _sessionsBox.delete(sessionId);
    final keys = _messagesBox.keys
        .where((k) => k.toString().startsWith('${sessionId}_'))
        .toList();
    await _messagesBox.deleteAll(keys);
  }

  Future<void> updateSessionTitle(String sessionId, String title) async {
    final raw = _sessionsBox.get(sessionId) as Map?;
    if (raw == null) return;
    raw['title']     = title;
    raw['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    await _sessionsBox.put(sessionId, raw);
  }

  // ──────────────────────────────────────────────
  // Messages
  // ──────────────────────────────────────────────

  Future<void> saveMessage(StoredMessage msg) async {
    await _messagesBox.put('${msg.sessionId}_${msg.id}', msg.toJson());
  }

  List<StoredMessage> loadMessages(String sessionId) {
    return _messagesBox.values
        .where((v) => (v as Map)['sessionId'] == sessionId)
        .map((v) => StoredMessage.fromJson(v as Map))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // ──────────────────────────────────────────────
  // Clear All
  // ──────────────────────────────────────────────

  Future<void> clearAll() async {
    await _projectsBox.clear();
    await _sessionsBox.clear();
    await _messagesBox.clear();
  }
}

// ──────────────────────────────────────────────
// Provider
// ──────────────────────────────────────────────

final storageProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('init StorageService in main.dart');
});
