// ============================================================
// code_diff_viewer.dart — عارض الـ Diffs بتنسيق Git-style
// ============================================================
// يعرض الفروق في الكود: السطور المضافة (+) بالأخضر
// والمحذوفة (-) بالأحمر، كما في Git diff
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

// ── نوع السطر ──
enum DiffLineType { added, removed, unchanged, header }

class DiffLine {
  final DiffLineType type;
  final String       content;
  final int?         lineNumber;

  const DiffLine({
    required this.type,
    required this.content,
    this.lineNumber,
  });
}

// ── Widget رئيسي ──
class CodeDiffViewer extends StatefulWidget {
  /// النص الخام للـ diff (unified diff format)
  final String  diffText;
  /// عنوان اختياري (اسم الملف)
  final String? fileName;
  /// هل يُظهر أزرار التحكم (Copy / Collapse)
  final bool    showControls;
  /// هل يبدأ منكمشاً؟
  final bool    initiallyCollapsed;

  const CodeDiffViewer({
    super.key,
    required this.diffText,
    this.fileName,
    this.showControls = true,
    this.initiallyCollapsed = false,
  });

  /// عرض النص الجديد فقط (بدون diff format)
  factory CodeDiffViewer.fromNewContent({
    Key?    key,
    required String content,
    String? fileName,
    bool    showControls = true,
  }) {
    // حوّل النص العادي إلى diff format (كل سطر مضاف)
    final lines = content.split('\n').map((l) => '+$l').join('\n');
    return CodeDiffViewer(
      key: key,
      diffText: lines,
      fileName: fileName,
      showControls: showControls,
    );
  }

  @override
  State<CodeDiffViewer> createState() => _CodeDiffViewerState();
}

class _CodeDiffViewerState extends State<CodeDiffViewer>
    with SingleTickerProviderStateMixin {
  late bool _collapsed;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.initiallyCollapsed;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _collapsed ? 0 : 1,
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() => _collapsed = !_collapsed);
    if (_collapsed) {
      _animCtrl.reverse();
    } else {
      _animCtrl.forward();
    }
  }

  void _copyToClipboard(BuildContext context) {
    // نسخ النص الأصلي (بإزالة +/- prefixes)
    final clean = widget.diffText
        .split('\n')
        .where((l) => !l.startsWith('-') && !l.startsWith('@@'))
        .map((l) => l.startsWith('+') ? l.substring(1) : l)
        .join('\n');

    Clipboard.setData(ClipboardData(text: clean));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('تم نسخ الكود', style: TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: CCColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = parseDiff(widget.diffText);
    final addedCount   = lines.where((l) => l.type == DiffLineType.added).length;
    final removedCount = lines.where((l) => l.type == DiffLineType.removed).length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          _buildHeader(context, addedCount, removedCount),

          // ── Content ──
          SizeTransition(
            sizeFactor: _expandAnim,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in lines) _DiffLineWidget(line: line),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int addedCount,
    int removedCount,
  ) {
    return GestureDetector(
      onTap: widget.showControls ? _toggleCollapse : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFF161B22),
        child: Row(
          children: [
            // Icon
            const Icon(
              Icons.code_rounded,
              size: 14,
              color: Color(0xFF8B949E),
            ),
            const SizedBox(width: 8),

            // اسم الملف
            Expanded(
              child: Text(
                widget.fileName ?? 'diff',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8B949E),
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // إحصائيات
            if (addedCount > 0) ...[
              Text(
                '+$addedCount',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF3FB950),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (removedCount > 0) ...[
              Text(
                '-$removedCount',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFF85149),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
            ],

            if (widget.showControls) ...[
              // Copy button
              GestureDetector(
                onTap: () => _copyToClipboard(context),
                child: const Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: Color(0xFF8B949E),
                ),
              ),
              const SizedBox(width: 10),

              // Collapse button
              AnimatedRotation(
                turns: _collapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.expand_more_rounded,
                  size: 16,
                  color: Color(0xFF8B949E),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── تحليل الـ diff text ──
  static List<DiffLine> parseDiff(String diffText) {
    final result = <DiffLine>[];
    int lineNum = 1;

    for (final raw in diffText.split('\n')) {
      if (raw.startsWith('@@')) {
        // استخرج رقم السطر من @@ -X,Y +A,B @@
        final match = RegExp(r'\+(\d+)').firstMatch(raw);
        if (match != null) lineNum = int.tryParse(match.group(1)!) ?? lineNum;
        result.add(DiffLine(type: DiffLineType.header, content: raw));
      } else if (raw.startsWith('+')) {
        result.add(DiffLine(
          type: DiffLineType.added,
          content: raw.length > 1 ? raw.substring(1) : '',
          lineNumber: lineNum++,
        ));
      } else if (raw.startsWith('-')) {
        result.add(DiffLine(
          type: DiffLineType.removed,
          content: raw.length > 1 ? raw.substring(1) : '',
        ));
      } else {
        result.add(DiffLine(
          type: DiffLineType.unchanged,
          content: raw.startsWith(' ') && raw.length > 1 ? raw.substring(1) : raw,
          lineNumber: lineNum++,
        ));
      }
    }

    return result;
  }
}

// ── سطر diff واحد ──
class _DiffLineWidget extends StatelessWidget {
  final DiffLine line;
  const _DiffLineWidget({required this.line});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, prefix) = switch (line.type) {
      DiffLineType.added     => (const Color(0xFF1A2C1A), const Color(0xFF3FB950), '+'),
      DiffLineType.removed   => (const Color(0xFF2C1A1A), const Color(0xFFF85149), '-'),
      DiffLineType.header    => (const Color(0xFF1A2030), const Color(0xFF58A6FF), ''),
      DiffLineType.unchanged => (Colors.transparent, const Color(0xFFE6EDF3), ' '),
    };

    if (line.type == DiffLineType.header) {
      return Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Text(
          line.content,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: fg,
          ),
        ),
      );
    }

    return Container(
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رقم السطر
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            color: const Color(0xFF0D1117),
            child: Text(
              line.lineNumber != null ? '${line.lineNumber}' : '',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFF484F58),
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // بريفيكس +/-
          Container(
            width: 20,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            child: Text(
              prefix,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // محتوى السطر
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                line.content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: line.type == DiffLineType.unchanged
                      ? const Color(0xFFE6EDF3)
                      : fg,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
