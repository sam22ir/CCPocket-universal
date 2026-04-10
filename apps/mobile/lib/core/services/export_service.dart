// ============================================================
// export_service.dart — Export Sessions to Markdown / JSON
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';

class ExportService {
  final StorageService _storage;
  ExportService(this._storage);

  // ── Export جلسة واحدة → Markdown ──
  Future<File> exportSessionMarkdown(String sessionId) async {
    final session  = _storage.loadSessions().firstWhere((s) => s.id == sessionId);
    final messages = _storage.loadMessages(sessionId);

    final buf = StringBuffer();
    buf.writeln('# ${session.title}');
    buf.writeln();
    buf.writeln('- **المزود:** ${session.providerId}');
    buf.writeln('- **النموذج:** ${session.modelId}');
    buf.writeln('- **التاريخ:** ${_formatDate(session.createdAt)}');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    for (final msg in messages) {
      if (msg.isUser) {
        buf.writeln('## 👤 المستخدم');
      } else {
        buf.writeln('## 🤖 المساعد');
      }
      buf.writeln();
      buf.writeln(msg.content);
      buf.writeln();
    }

    return _saveFile('session_${sessionId.substring(0, 8)}.md', buf.toString());
  }

  // ── Export جلسة واحدة → JSON ──
  Future<File> exportSessionJson(String sessionId) async {
    final session  = _storage.loadSessions().firstWhere((s) => s.id == sessionId);
    final messages = _storage.loadMessages(sessionId);

    final data = {
      'session': session.toJson(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    return _saveFile(
      'session_${sessionId.substring(0, 8)}.json',
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  // ── Export كل جلسات مشروع → Markdown ──
  Future<File> exportProjectMarkdown(String projectId, String projectName) async {
    final sessions = _storage.loadSessionsByProject(projectId);
    final buf = StringBuffer();

    buf.writeln('# مشروع: $projectName');
    buf.writeln('- **تاريخ التصدير:** ${_formatDate(DateTime.now().millisecondsSinceEpoch)}');
    buf.writeln('- **عدد الجلسات:** ${sessions.length}');
    buf.writeln();

    for (final session in sessions) {
      buf.writeln('---');
      buf.writeln();
      buf.writeln('## جلسة: ${session.title}');
      buf.writeln('المزود: ${session.providerId} | النموذج: ${session.modelId}');
      buf.writeln();

      final messages = _storage.loadMessages(session.id);
      for (final msg in messages) {
        buf.writeln(msg.isUser ? '**👤:**' : '**🤖:**');
        buf.writeln(msg.content);
        buf.writeln();
      }
    }

    final safeName = projectName.replaceAll(RegExp(r'[^\w\s-]'), '_');
    return _saveFile('project_$safeName.md', buf.toString());
  }

  // ── مشاركة الملف (Snackbar مع المسار) ──
  static void showExportSuccess(BuildContext context, File file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم التصدير: ${file.path.split(Platform.pathSeparator).last}',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Helpers ──

  Future<File> _saveFile(String name, String content) async {
    final dir  = await getApplicationDocumentsDirectory();
    final path = '${dir.path}${Platform.pathSeparator}ccpocket_exports';
    await Directory(path).create(recursive: true);
    final file = File('$path${Platform.pathSeparator}$name');
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  static String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService(ref.read(storageProvider));
});
