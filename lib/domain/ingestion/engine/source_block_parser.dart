import '../models/source_block.dart';
import '../models/source_document.dart';
import '../models/source_span.dart';

/// Syntactic block parser that segments raw text into typed SourceBlocks
/// while tracking character offsets, line numbers, and column positions.
class SourceBlockParser {
  const SourceBlockParser();

  static final _headingPattern = RegExp(r'^(#{1,6})\s+(.+)$');
  static final _dividerPattern = RegExp(r'^(\*{3,}|-{3,}|_{3,})$');
  static final _listPattern = RegExp(r'^(\s*[-*+]|\s*\d+\.)\s+(.+)$');

  /// Parses raw text into a [SourceDocument] containing ordered, non-overlapping [SourceBlock]s.
  SourceDocument parse(String rawText) {
    if (rawText.isEmpty) {
      return const SourceDocument.empty();
    }

    // Normalize Windows/old Mac line endings to standard Unix \n
    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    final blocks = <SourceBlock>[];
    int currentOffset = 0;
    int blockIdCounter = 1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineNum = i + 1;
      final lineLength = line.length;
      final endOffset = currentOffset + lineLength;

      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        // Advance offset past the newline
        currentOffset = endOffset + 1;
        continue;
      }

      final span = SourceSpan(
        startOffset: currentOffset,
        endOffset: endOffset,
        startLine: lineNum,
        startColumn: 1,
        endLine: lineNum,
        endColumn: lineLength + 1,
        text: line,
      );

      SourceBlockType type = SourceBlockType.paragraph;
      String? headingText;
      int headingLevel = 0;

      final headingMatch = _headingPattern.firstMatch(trimmed);
      if (headingMatch != null) {
        type = SourceBlockType.heading;
        headingLevel = headingMatch.group(1)!.length;
        headingText = headingMatch.group(2)!.trim();
      } else if (_dividerPattern.hasMatch(trimmed)) {
        type = SourceBlockType.divider;
      } else if (_listPattern.hasMatch(line)) {
        type = SourceBlockType.list;
      } else if (_looksLikeStatLine(trimmed)) {
        type = SourceBlockType.statLine;
      }

      blocks.add(
        SourceBlock(
          id: 'block_$blockIdCounter',
          rawText: line,
          normalizedText: trimmed,
          span: span,
          type: type,
          headingText: headingText,
          headingLevel: headingLevel,
        ),
      );

      blockIdCounter++;
      // Advance offset past newline (unless it's the very last line)
      currentOffset = endOffset + 1;
    }

    return SourceDocument(
      rawText: rawText,
      normalizedText: normalized,
      blocks: blocks,
    );
  }

  static bool _looksLikeStatLine(String text) {
    final lower = text.toLowerCase();
    return lower.startsWith('armor class') ||
        lower.startsWith('ac ') ||
        lower.startsWith('hit points') ||
        lower.startsWith('hp ') ||
        lower.startsWith('speed ') ||
        lower.startsWith('str ') ||
        lower.startsWith('casting time') ||
        lower.startsWith('range:') ||
        lower.startsWith('components:') ||
        lower.startsWith('duration:') ||
        lower.startsWith('challenge ') ||
        lower.startsWith('cr ');
  }
}
