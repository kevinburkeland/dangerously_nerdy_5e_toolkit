import 'dart:math' as math;
import '../models/source_block.dart';
import '../models/source_document.dart';
import '../models/source_span.dart';
import '../models/ingestion_section.dart';

/// Syntactic and structural parser that segments a [SourceDocument] into a hierarchy
/// of [IngestionSection]s preserving heading nesting, tables, stat block boundaries,
/// and source span containment.
///
/// This parser is 100% ruleset-agnostic and performs structural decomposition
/// without semantic guessing or ruleset-specific domain interpretations.
class DocumentStructureParser {
  const DocumentStructureParser();

  /// Parses [doc] into top-level [IngestionSection]s with nested children.
  List<IngestionSection> parseSections(SourceDocument doc) {
    if (doc.blocks.isEmpty) return const [];

    final rootNodes = <_SectionNode>[];
    final stack = <_SectionNode>[];
    int sectionCounter = 1;

    int i = 0;
    while (i < doc.blocks.length) {
      final block = doc.blocks[i];

      // 1. Divider handling (---, ***)
      if (block.type == SourceBlockType.divider) {
        // Dividers act as clear structural breaks: pop back to root
        stack.clear();
        i++;
        continue;
      }

      // 2. Table handling (consecutive SourceBlockType.table lines)
      if (block.type == SourceBlockType.table) {
        final tableBlocks = <SourceBlock>[];
        while (i < doc.blocks.length && doc.blocks[i].type == SourceBlockType.table) {
          tableBlocks.add(doc.blocks[i]);
          i++;
        }

        final tableMeta = _parseTableMetadata(tableBlocks);

        // If the current section in stack was just started by a heading with no other content,
        // attach table directly to it; otherwise create a nested table section.
        if (stack.isNotEmpty && stack.last.blocks.length <= 1) {
          stack.last.blocks.addAll(tableBlocks);
          stack.last.metadata.addAll(tableMeta);
          stack.last.classification = 'progressionTable';
        } else {
          final parent = stack.isNotEmpty ? stack.last : null;
          final depth = parent != null ? parent.headingLevel + 1 : 1;
          final tableNode = _SectionNode(
            id: 'sec_${sectionCounter++}',
            headingText: tableMeta['tableTitle'] as String?,
            headingLevel: depth,
            classification: 'progressionTable',
            parent: parent,
          );
          tableNode.blocks.addAll(tableBlocks);
          tableNode.metadata.addAll(tableMeta);

          if (parent != null) {
            parent.children.add(tableNode);
          } else {
            rootNodes.add(tableNode);
          }
        }
        continue;
      }

      // 3. Heading handling
      if (block.type == SourceBlockType.heading) {
        final level = block.headingLevel > 0 ? block.headingLevel : 1;
        final headingText = block.headingText ?? block.normalizedText;

        final node = _SectionNode(
          id: 'sec_${sectionCounter++}',
          headingText: headingText,
          headingLevel: level,
        );
        node.blocks.add(block);

        // Adjust stack for heading depth
        while (stack.isNotEmpty && stack.last.headingLevel >= level) {
          stack.removeLast();
        }

        if (stack.isNotEmpty) {
          final parent = stack.last;
          node.parent = parent;
          parent.children.add(node);
        } else {
          rootNodes.add(node);
        }

        stack.add(node);
        i++;
        continue;
      }

      // 4. Standalone bold title or plain-text heading check
      if (_looksLikePlainHeading(block, i, doc.blocks)) {
        final level = stack.isNotEmpty ? math.max(2, stack.last.headingLevel + 1) : 1;
        final titleText = _stripMarkdownFormatting(block.normalizedText);

        final node = _SectionNode(
          id: 'sec_${sectionCounter++}',
          headingText: titleText,
          headingLevel: level,
        );
        node.blocks.add(block);

        while (stack.isNotEmpty && stack.last.headingLevel >= level) {
          stack.removeLast();
        }

        if (stack.isNotEmpty) {
          final parent = stack.last;
          node.parent = parent;
          parent.children.add(node);
        } else {
          rootNodes.add(node);
        }

        stack.add(node);
        i++;
        continue;
      }

      // 5. Normal block (statLine, paragraph, list)
      if (stack.isNotEmpty) {
        stack.last.blocks.add(block);
      } else {
        // Preamble before any heading
        final preamble = _SectionNode(
          id: 'sec_${sectionCounter++}',
          headingText: null,
          headingLevel: 0,
          classification: 'descriptiveProse',
        );
        preamble.blocks.add(block);
        rootNodes.add(preamble);
        stack.add(preamble);
      }

      i++;
    }

    return rootNodes.map((n) => n.toImmutable(doc)).toList();
  }

  static bool _looksLikePlainHeading(SourceBlock block, int index, List<SourceBlock> all) {
    if (block.type == SourceBlockType.statLine ||
        block.type == SourceBlockType.list ||
        block.type == SourceBlockType.table ||
        block.type == SourceBlockType.divider) {
      return false;
    }

    final text = block.normalizedText.trim();
    if (text.isEmpty || text.length > 55) return false;

    // Check for bold wrapper: **Title**
    if (text.startsWith('**') && text.endsWith('**') && text.length > 4) {
      return true;
    }

    // Key-value lines with a colon are stat lines, not headings (e.g. "Hit Die: 1d10", "Prerequisite: ...")
    final colonIndex = text.indexOf(':');
    if (colonIndex > 0 && colonIndex < 35 && colonIndex < text.length - 1) {
      return false;
    }

    // Line ending in colon can be a section label (e.g. "Features:", "Proficiencies:")
    if (text.endsWith(':') && text.length <= 25 && _isSectionKeyword(text)) {
      return true;
    }

    // Section keywords in ALL-CAPS (e.g. "ACTIONS", "TRAITS")
    if (text == text.toUpperCase() &&
        text.length >= 3 &&
        text.length <= 30 &&
        RegExp(r'^[A-Z\s]+$').hasMatch(text)) {
      return true;
    }

    // Check for Markdown underline header style (Setext)
    if (index + 1 < all.length) {
      final next = all[index + 1].normalizedText.trim();
      if (RegExp(r'^={3,}|-{3,}$').hasMatch(next)) {
        return true;
      }
    }

    return false;
  }

  static bool _isSectionKeyword(String text) {
    final lower = text.substring(0, text.length - 1).trim().toLowerCase();
    return lower == 'features' ||
        lower == 'class features' ||
        lower == 'subclass features' ||
        lower == 'actions' ||
        lower == 'bonus actions' ||
        lower == 'reactions' ||
        lower == 'traits' ||
        lower == 'racial traits' ||
        lower == 'proficiencies' ||
        lower == 'equipment' ||
        lower == 'starting equipment' ||
        lower == 'overview' ||
        lower == 'description';
  }

  static String _stripMarkdownFormatting(String text) {
    var clean = text.trim();
    if (clean.startsWith('**') && clean.endsWith('**') && clean.length > 4) {
      clean = clean.substring(2, clean.length - 2).trim();
    }
    if (clean.startsWith('*') && clean.endsWith('*') && clean.length > 2) {
      clean = clean.substring(1, clean.length - 1).trim();
    }
    return clean;
  }

  static Map<String, dynamic> _parseTableMetadata(List<SourceBlock> tableBlocks) {
    final headers = <String>[];
    final rows = <List<String>>[];

    for (final b in tableBlocks) {
      final line = b.normalizedText;
      final cells = line
          .split('|')
          .map((c) => c.trim())
          .toList();

      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();

      // Check if separator row (e.g. ---, :---:)
      final isSeparator = cells.isNotEmpty &&
          cells.every((c) => RegExp(r'^\s*:?-+:?\s*$').hasMatch(c));
      if (isSeparator) continue;

      if (headers.isEmpty) {
        headers.addAll(cells);
      } else {
        rows.add(cells);
      }
    }

    final rawTable = tableBlocks.map((b) => b.rawText).join('\n');

    return {
      'isTable': true,
      'tableHeaders': headers,
      'tableRows': rows,
      'rawTable': rawTable,
    };
  }
}

class _SectionNode {
  final String id;
  final String? headingText;
  final int headingLevel;
  final List<SourceBlock> blocks = [];
  final List<_SectionNode> children = [];
  final Map<String, dynamic> metadata = {};
  _SectionNode? parent;
  String classification;

  _SectionNode({
    required this.id,
    this.headingText,
    required this.headingLevel,
    this.parent,
    this.classification = 'unknown',
  });

  IngestionSection toImmutable(SourceDocument doc, {int depth = 0}) {
    final builtChildren = children.map((c) => c.toImmutable(doc, depth: depth + 1)).toList();

    // Compute span: encompassing all blocks of this section and its children
    int minOffset = 999999999;
    int maxOffset = 0;
    int startLine = 1;
    int startCol = 1;
    int endLine = 1;
    int endCol = 1;

    void trackSpan(SourceSpan s) {
      if (s.isEmpty) return;
      if (s.startOffset < minOffset) {
        minOffset = s.startOffset;
        startLine = s.startLine;
        startCol = s.startColumn;
      }
      if (s.endOffset > maxOffset) {
        maxOffset = s.endOffset;
        endLine = s.endLine;
        endCol = s.endColumn;
      }
    }

    for (final b in blocks) {
      trackSpan(b.span);
    }
    for (final c in builtChildren) {
      trackSpan(c.span);
    }

    SourceSpan span;
    String rawSource;

    if (minOffset <= maxOffset && minOffset < doc.rawText.length) {
      final safeEnd = math.min(maxOffset, doc.rawText.length);
      rawSource = doc.rawText.substring(minOffset, safeEnd);
      span = SourceSpan(
        startOffset: minOffset,
        endOffset: safeEnd,
        startLine: startLine,
        startColumn: startCol,
        endLine: endLine,
        endColumn: endCol,
        text: rawSource,
      );
    } else if (blocks.isNotEmpty) {
      span = blocks.first.span;
      rawSource = blocks.map((b) => b.rawText).join('\n');
    } else {
      span = const SourceSpan.empty();
      rawSource = '';
    }

    return IngestionSection(
      id: id,
      span: span,
      rawSource: rawSource,
      headingText: headingText,
      headingLevel: headingLevel,
      structuralDepth: depth,
      parentSectionId: parent?.id,
      childSectionIds: builtChildren.map((c) => c.id).toList(),
      children: builtChildren,
      blocks: List.unmodifiable(blocks),
      classification: classification,
      metadata: Map.unmodifiable(metadata),
    );
  }
}
