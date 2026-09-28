import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/engine/field_extractor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';

/// 5e-specific field extractor for Subclasses / Archetypes.
class Dnd5eSubclassFieldExtractor implements FieldExtractor {
  const Dnd5eSubclassFieldExtractor();

  static final _parentClassSubtitlePattern = RegExp(
    r'^(Barbarian|Bard|Cleric|Druid|Fighter|Monk|Paladin|Ranger|Rogue|Sorcerer|Warlock|Wizard)\s+(?:Archetype|Subclass|Domain|Circle|College|Path|Tradition|Patron|Sacred\s+Oath|Oath|Origin)$',
    caseSensitive: false,
  );

  static final _explicitClassPattern = RegExp(
    r'^(?:Subclass\s+for|Archetype\s+for|Class)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  @override
  FieldExtractionResult extract({
    required List<SourceBlock> blocks,
    required IngestionTargetDescriptor descriptor,
    SourceSpan? span,
  }) {
    final fields = <String, IngestionField<dynamic>>{};
    final consumedBlockIds = <String>{};

    if (blocks.isEmpty) {
      _populateMissingFields(fields, descriptor);
      return FieldExtractionResult(fields: fields);
    }

    int blockIndex = 0;

    // 1. Name: First block
    final firstBlock = blocks[0];
    final titleText = firstBlock.headingText ?? firstBlock.normalizedText;
    if (titleText.isNotEmpty) {
      fields['name'] = IngestionField<String>.extracted(
        key: 'name',
        label: 'Subclass Name',
        value: titleText,
        rawText: firstBlock.rawText,
        span: firstBlock.span,
        isRequired: true,
      );
      consumedBlockIds.add(firstBlock.id);
      blockIndex++;
    }

    // 2. Scan for Parent Class in subtitle or explicit line
    final descBlocks = <SourceBlock>[];
    for (int i = blockIndex; i < blocks.length; i++) {
      final block = blocks[i];
      final text = block.normalizedText;

      final subMatch = _parentClassSubtitlePattern.firstMatch(text);
      if (subMatch != null && !fields.containsKey('classSlug')) {
        final parent = subMatch.group(1)!.toLowerCase().trim();
        fields['classSlug'] = IngestionField<String>.extracted(
          key: 'classSlug',
          label: 'Parent Class',
          value: parent,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final expMatch = _explicitClassPattern.firstMatch(text);
      if (expMatch != null && !fields.containsKey('classSlug')) {
        final parent = expMatch.group(1)!.toLowerCase().trim();
        fields['classSlug'] = IngestionField<String>.extracted(
          key: 'classSlug',
          label: 'Parent Class',
          value: parent,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      descBlocks.add(block);
    }

    // 3. Features Markdown
    if (descBlocks.isNotEmpty) {
      final fullDesc = descBlocks.map((b) => b.rawText).join('\n\n');
      fields['featuresMarkdown'] = IngestionField<String>.extracted(
        key: 'featuresMarkdown',
        label: 'Features',
        value: fullDesc,
        rawText: fullDesc,
        span: SourceSpan(
          startOffset: descBlocks.first.span.startOffset,
          endOffset: descBlocks.last.span.endOffset,
          startLine: descBlocks.first.span.startLine,
          startColumn: descBlocks.first.span.startColumn,
          endLine: descBlocks.last.span.endLine,
          endColumn: descBlocks.last.span.endColumn,
          text: fullDesc,
        ),
        isRequired: true,
      );
      for (final b in descBlocks) {
        consumedBlockIds.add(b.id);
      }
    }

    _populateMissingFields(fields, descriptor);
    return FieldExtractionResult(fields: fields);
  }

  void _populateMissingFields(
    Map<String, IngestionField<dynamic>> fields,
    IngestionTargetDescriptor descriptor,
  ) {
    for (final fd in descriptor.fields) {
      if (!fields.containsKey(fd.key)) {
        fields[fd.key] = IngestionField<dynamic>(
          key: fd.key,
          label: fd.label,
          state: IngestionFieldState.missing,
          value: null,
          isRequired: fd.expectation == SourceFieldExpectation.requiredForRecognition,
        );
      }
    }
  }
}
