import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/ingestion/compendium_json_ingestion_pipeline.dart';

/// A lightweight, robust, native Flutter widget for rendering markdown-formatted
/// text commonly found in D&D 5e traits, features, feats, and lore descriptions.
///
/// Supports:
/// - Paragraphs & line breaks (`\n\n`, `\n`)
/// - Bold (`**bold**` / `__bold__`)
/// - Italic (`*italic*` / `_italic_`)
/// - Bold-Italic (`***text***` / `___text___`)
/// - Inline code (`` `code` ``)
/// - Bullet lists (`- `, `* `, `• `)
/// - Numbered lists (`1. `, `2. `)
/// - Headings (`# `, `## `, `### `)
class FormattedMarkdownText extends StatelessWidget {
  final String markdown;
  final TextStyle? style;
  final Color? boldColor;
  final double? fontSize;
  final Color? defaultColor;
  final double paragraphSpacing;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const FormattedMarkdownText(
    this.markdown, {
    super.key,
    this.style,
    this.boldColor,
    this.fontSize,
    this.defaultColor,
    this.paragraphSpacing = 6.0,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontSize: fontSize ?? style?.fontSize ?? 12.0,
      color: defaultColor ?? style?.color ?? Colors.white70,
      height: style?.height ?? 1.4,
    );
    final effectiveOverflow =
        overflow ?? (maxLines != null ? TextOverflow.ellipsis : null);

    var rawText = markdown.trim();
    if (rawText.isEmpty) {
      return const SizedBox.shrink();
    }
    rawText = CompendiumJsonIngestionPipeline.cleanRawTags(rawText);
    rawText = _isolateMarkdownTables(rawText);

    final paragraphs = rawText.split(RegExp(r'\n\s*\n'));
    final blockWidgets = <Widget>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i].trim();
      if (para.isEmpty) continue;

      if (i > 0) {
        blockWidgets.add(SizedBox(height: paragraphSpacing));
      }

      // Check for headings
      if (para.startsWith('###### ') || para.startsWith('##### ')) {
        final prefixLen = para.startsWith('###### ') ? 7 : 6;
        blockWidgets.add(
          Text.rich(
            TextSpan(
              children: _parseInlineMarkdown(
                para.substring(prefixLen),
                effectiveStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: effectiveStyle.fontSize ?? 12.0,
                  color: boldColor ?? Colors.amberAccent,
                ),
              ),
            ),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: effectiveOverflow,
          ),
        );
      } else if (para.startsWith('#### ')) {
        blockWidgets.add(
          Text.rich(
            TextSpan(
              children: _parseInlineMarkdown(
                para.substring(5),
                effectiveStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (effectiveStyle.fontSize ?? 12.0) + 1.0,
                  color: boldColor ?? Colors.amberAccent,
                ),
              ),
            ),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: effectiveOverflow,
          ),
        );
      } else if (para.startsWith('### ')) {
        blockWidgets.add(
          Text.rich(
            TextSpan(
              children: _parseInlineMarkdown(
                para.substring(4),
                effectiveStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (effectiveStyle.fontSize ?? 12.0) + 2.0,
                  color: boldColor ?? Colors.amberAccent,
                ),
              ),
            ),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: effectiveOverflow,
          ),
        );
      } else if (para.startsWith('## ')) {
        blockWidgets.add(
          Text.rich(
            TextSpan(
              children: _parseInlineMarkdown(
                para.substring(3),
                effectiveStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (effectiveStyle.fontSize ?? 12.0) + 3.5,
                  color: boldColor ?? Colors.amberAccent,
                ),
              ),
            ),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: effectiveOverflow,
          ),
        );
      } else if (para.startsWith('# ')) {
        blockWidgets.add(
          Text.rich(
            TextSpan(
              children: _parseInlineMarkdown(
                para.substring(2),
                effectiveStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (effectiveStyle.fontSize ?? 12.0) + 5.0,
                  color: boldColor ?? Colors.amberAccent,
                ),
              ),
            ),
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: effectiveOverflow,
          ),
        );
      } else if (para.startsWith('> ')) {
        // Blockquote / Note
        final quoteText = para
            .split('\n')
            .map((l) => l.startsWith('> ') ? l.substring(2) : l)
            .join('\n');
        blockWidgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              border: const Border(
                  left: BorderSide(color: Colors.amberAccent, width: 3)),
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(4)),
            ),
            child: Text.rich(
              TextSpan(
                  children: _parseInlineMarkdown(quoteText,
                      effectiveStyle.copyWith(fontStyle: FontStyle.italic))),
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: effectiveOverflow,
            ),
          ),
        );
      } else if (_isMarkdownTable(para)) {
        blockWidgets.add(_buildMarkdownTable(para, effectiveStyle));
      } else {
        // Check for line-by-line items (bullets or line breaks inside paragraph)
        final lines = para.split('\n');
        if (lines.length > 1 && lines.any((l) => _isListLine(l.trim()))) {
          final lineWidgets = <Widget>[];
          for (final line in lines) {
            final trimmedLine = line.trim();
            if (trimmedLine.isEmpty) continue;
            if (_isListLine(trimmedLine)) {
              lineWidgets.add(_buildListRow(trimmedLine, effectiveStyle));
            } else {
              lineWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text.rich(
                    TextSpan(
                        children:
                            _parseInlineMarkdown(trimmedLine, effectiveStyle)),
                    textAlign: textAlign,
                    maxLines: maxLines,
                    overflow: effectiveOverflow,
                  ),
                ),
              );
            }
          }
          blockWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: lineWidgets,
            ),
          );
        } else if (_isListLine(para)) {
          blockWidgets.add(_buildListRow(para, effectiveStyle));
        } else {
          blockWidgets.add(
            Text.rich(
              TextSpan(children: _parseInlineMarkdown(para, effectiveStyle)),
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: effectiveOverflow,
            ),
          );
        }
      }
    }

    if (blockWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    if (maxLines != null && blockWidgets.length > 1) {
      return blockWidgets.first;
    }

    if (blockWidgets.length == 1) {
      return blockWidgets.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }

  bool _isListLine(String line) {
    return line.startsWith('- ') ||
        line.startsWith('* ') ||
        line.startsWith('• ') ||
        RegExp(r'^\d+\.\s').hasMatch(line);
  }

  Widget _buildListRow(String line, TextStyle baseStyle) {
    String bulletText = '•';
    String contentText = line;

    if (line.startsWith('- ') ||
        line.startsWith('* ') ||
        line.startsWith('• ')) {
      contentText = line.substring(2).trim();
    } else {
      final match = RegExp(r'^(\d+\.)\s*(.*)$').firstMatch(line);
      if (match != null) {
        bulletText = match.group(1) ?? '•';
        contentText = match.group(2) ?? '';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 1),
            child: Text(
              bulletText,
              style: baseStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: boldColor ?? Colors.cyanAccent,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: _parseInlineMarkdown(contentText, baseStyle)),
              textAlign: textAlign,
              maxLines: maxLines,
              overflow:
                  overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseInlineMarkdown(String text, TextStyle baseStyle) {
    return parseInlineMarkdown(text, baseStyle, boldColor: boldColor);
  }

  /// Parses inline markdown syntax (bold, italic, inline code) into [InlineSpan]s.
  static List<InlineSpan> parseInlineMarkdown(
    String text,
    TextStyle baseStyle, {
    Color? boldColor,
  }) {
    final spans = <InlineSpan>[];
    final tokenRegex = RegExp(
      r'(\*\*\*[^*]+\*\*\*|___[^_]+___|\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|`[^`]+`)',
    );

    int lastIndex = 0;
    for (final match in tokenRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final matchedStr = match.group(0)!;
      if ((matchedStr.startsWith('***') && matchedStr.endsWith('***')) ||
          (matchedStr.startsWith('___') && matchedStr.endsWith('___'))) {
        final inner = matchedStr.substring(3, matchedStr.length - 3);
        spans.add(TextSpan(
          text: inner,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: boldColor ?? Colors.white,
          ),
        ));
      } else if ((matchedStr.startsWith('**') && matchedStr.endsWith('**')) ||
          (matchedStr.startsWith('__') && matchedStr.endsWith('__'))) {
        final inner = matchedStr.substring(2, matchedStr.length - 2);
        spans.add(TextSpan(
          text: inner,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: boldColor ?? Colors.white,
          ),
        ));
      } else if ((matchedStr.startsWith('*') && matchedStr.endsWith('*')) ||
          (matchedStr.startsWith('_') && matchedStr.endsWith('_'))) {
        final inner = matchedStr.substring(1, matchedStr.length - 1);
        spans.add(TextSpan(
          text: inner,
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (matchedStr.startsWith('`') && matchedStr.endsWith('`')) {
        final inner = matchedStr.substring(1, matchedStr.length - 1);
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Text(
              inner,
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 12.0) * 0.9,
                color: Colors.cyanAccent,
              ),
            ),
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }

  static final RegExp _tableSepRegex =
      RegExp(r'^\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)+\|?$');

  /// Checks whether a given trimmed line is a markdown table column separator row.
  static bool isTableSeparator(String text) =>
      _tableSepRegex.hasMatch(text.trim());

  static String _isolateMarkdownTables(String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer();
    bool inTable = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      final isPipeLine = trimmed.contains('|');

      if (isPipeLine && !inTable) {
        // Check if this line or any of the next 2 lines has a table separator
        bool hasSep = _tableSepRegex.hasMatch(trimmed);
        if (!hasSep) {
          for (int j = i + 1; j < lines.length && j <= i + 2; j++) {
            if (_tableSepRegex.hasMatch(lines[j].trim())) {
              hasSep = true;
              break;
            }
          }
        }
        // Also recognize consecutive pipe lines (>= 2 lines with pipes) as a table
        if (!hasSep &&
            i + 1 < lines.length &&
            lines[i + 1].trim().contains('|')) {
          hasSep = true;
        }
        if (hasSep) {
          inTable = true;
          buffer.write('\n\n');
        }
      } else if (!isPipeLine && inTable) {
        inTable = false;
        buffer.write('\n\n');
      }

      buffer.writeln(line);
    }
    if (inTable) {
      buffer.write('\n\n');
    }
    return buffer.toString();
  }

  bool _isMarkdownTable(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length < 2) return false;
    final pipeLines = lines.where((l) => l.contains('|')).toList();
    if (pipeLines.length < 2) return false;
    if (lines.any((l) => _tableSepRegex.hasMatch(l))) return true;
    return pipeLines.length == lines.length;
  }

  List<String> _splitTableRow(String line) {
    var stripped = line.trim();
    if (stripped.startsWith('|')) stripped = stripped.substring(1);
    if (stripped.endsWith('|'))
      stripped = stripped.substring(0, stripped.length - 1);
    // Protect escaped pipes \|
    final protected = stripped.replaceAll(r'\|', '\u0000');
    final cells = protected
        .split('|')
        .map((c) => c.replaceAll('\u0000', '|').trim())
        .toList();
    return cells;
  }

  Widget _buildMarkdownTable(String text, TextStyle baseStyle) {
    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final tableLines =
        rawLines.where((l) => !_tableSepRegex.hasMatch(l)).toList();
    if (tableLines.isEmpty) return const SizedBox.shrink();

    final parsedRows = tableLines.map((line) => _splitTableRow(line)).toList();
    int maxCols = 0;
    for (final row in parsedRows) {
      if (row.length > maxCols) maxCols = row.length;
    }
    if (maxCols == 0) return const SizedBox.shrink();

    final normalizedRows = parsedRows.map((row) {
      if (row.length < maxCols) {
        return [...row, ...List.filled(maxCols - row.length, '')];
      }
      return row;
    }).toList();

    return ScrollableMarkdownTable(
      rows: normalizedRows,
      baseStyle: baseStyle,
      boldColor: boldColor,
    );
  }
}

/// A horizontally scrollable markdown table widget designed for cards and compact containers.
///
/// Enables smooth left-to-right scrolling with:
/// - A dedicated [ScrollController] and visible [Scrollbar] with interactive thumb dragging.
/// - Pointer support across Touch, Mouse (drag-to-scroll on desktop/web), Trackpad, and Stylus.
/// - Clean rounded bounds via [ClipRRect] that prevent cards from overflowing or breaking layout.
/// - Stable column widths preventing cell contents from wrapping prematurely into vertical slivers.
class ScrollableMarkdownTable extends StatefulWidget {
  final List<List<String>> rows;
  final TextStyle baseStyle;
  final Color? boldColor;

  const ScrollableMarkdownTable({
    super.key,
    required this.rows,
    required this.baseStyle,
    this.boldColor,
  });

  @override
  State<ScrollableMarkdownTable> createState() =>
      _ScrollableMarkdownTableState();
}

class _ScrollableMarkdownTableState extends State<ScrollableMarkdownTable> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.boldColor ??
        (isDark ? Colors.amberAccent : theme.colorScheme.primary);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
            },
            scrollbars: false,
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            thickness: 4.0,
            radius: const Radius.circular(3),
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 6),
              child: Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: widget.rows.asMap().entries.map((entry) {
                  final rowIndex = entry.key;
                  final cells = entry.value;
                  final isHeader = rowIndex == 0;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isHeader
                          ? accent.withValues(alpha: 0.12)
                          : (rowIndex % 2 == 1
                              ? (isDark
                                  ? Colors.white.withValues(alpha: 0.02)
                                  : Colors.black.withValues(alpha: 0.02))
                              : Colors.transparent),
                    ),
                    children: cells.map((cell) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Text.rich(
                          TextSpan(
                            children: FormattedMarkdownText.parseInlineMarkdown(
                              cell,
                              widget.baseStyle.copyWith(
                                fontWeight: isHeader
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color:
                                    isHeader ? accent : widget.baseStyle.color,
                              ),
                              boldColor: widget.boldColor,
                            ),
                          ),
                          softWrap: false,
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
