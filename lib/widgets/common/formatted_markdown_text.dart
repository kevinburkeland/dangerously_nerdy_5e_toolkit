import 'package:flutter/material.dart';

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

  const FormattedMarkdownText(
    this.markdown, {
    super.key,
    this.style,
    this.boldColor,
    this.fontSize,
    this.defaultColor,
    this.paragraphSpacing = 6.0,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      fontSize: fontSize ?? style?.fontSize ?? 12.0,
      color: defaultColor ?? style?.color ?? Colors.white70,
      height: style?.height ?? 1.4,
    );

    final rawText = markdown.trim();
    if (rawText.isEmpty) {
      return const SizedBox.shrink();
    }

    final paragraphs = rawText.split(RegExp(r'\n\s*\n'));
    final blockWidgets = <Widget>[];

    for (int i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i].trim();
      if (para.isEmpty) continue;

      if (i > 0) {
        blockWidgets.add(SizedBox(height: paragraphSpacing));
      }

      // Check for headings
      if (para.startsWith('### ')) {
        blockWidgets.add(
          Text.rich(
            TextSpan(
              children: _parseInlineMarkdown(
                para.substring(4),
                effectiveStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: (effectiveStyle.fontSize ?? 12.0) + 1.5,
                  color: boldColor ?? Colors.amberAccent,
                ),
              ),
            ),
            textAlign: textAlign,
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
                  fontSize: (effectiveStyle.fontSize ?? 12.0) + 3.0,
                  color: boldColor ?? Colors.amberAccent,
                ),
              ),
            ),
            textAlign: textAlign,
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
          ),
        );
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
                    TextSpan(children: _parseInlineMarkdown(trimmedLine, effectiveStyle)),
                    textAlign: textAlign,
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
            ),
          );
        }
      }
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

    if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ')) {
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
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseInlineMarkdown(String text, TextStyle baseStyle) {
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
}
