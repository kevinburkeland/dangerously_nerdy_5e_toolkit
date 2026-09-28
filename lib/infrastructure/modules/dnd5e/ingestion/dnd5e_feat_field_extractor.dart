import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/engine/field_extractor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';

/// 5e-specific field extractor for Feats.
class Dnd5eFeatFieldExtractor implements FieldExtractor {
  const Dnd5eFeatFieldExtractor();

  static final _categoryPattern = RegExp(
    r'^(General|Origin|Fighting\s+Style|Epic\s+Boon)(?:\s+Feat)?$',
    caseSensitive: false,
  );

  static final _prerequisitePattern = RegExp(
    r'^Prerequisite\s*[:]?\s*(.+)$',
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
        label: 'Name',
        value: titleText,
        rawText: firstBlock.rawText,
        span: firstBlock.span,
        isRequired: true,
      );
      consumedBlockIds.add(firstBlock.id);
      blockIndex++;
    }

    // 2. Scan for Category and Prerequisite lines
    final descBlocks = <SourceBlock>[];
    for (int i = blockIndex; i < blocks.length; i++) {
      final block = blocks[i];
      final text = block.normalizedText;

      final catMatch = _categoryPattern.firstMatch(text);
      if (catMatch != null && !fields.containsKey('category')) {
        final cat = _normalizeCategory(catMatch.group(1)!);
        fields['category'] = IngestionField<String>.extracted(
          key: 'category',
          label: 'Category',
          value: cat,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final prereqMatch = _prerequisitePattern.firstMatch(text);
      if (prereqMatch != null && !fields.containsKey('prerequisite')) {
        final prereq = prereqMatch.group(1)!.trim();
        fields['prerequisite'] = IngestionField<String>.extracted(
          key: 'prerequisite',
          label: 'Prerequisite',
          value: prereq,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      descBlocks.add(block);
    }

    // Default category to General if not explicitly specified
    if (!fields.containsKey('category')) {
      fields['category'] = IngestionField<String>.inferred(
        key: 'category',
        label: 'Category',
        value: 'General',
        confidence: 0.9,
        evidence: 'Defaulted to General feat category in absence of specific marker.',
      );
    }

    // 3. Description
    if (descBlocks.isNotEmpty) {
      final fullDesc = descBlocks.map((b) => b.rawText).join('\n\n');
      fields['descriptionMarkdown'] = IngestionField<String>.extracted(
        key: 'descriptionMarkdown',
        label: 'Description',
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

  String _normalizeCategory(String raw) {
    final clean = raw.toLowerCase().trim();
    if (clean.contains('origin')) return 'Origin';
    if (clean.contains('fighting')) return 'Fighting Style';
    if (clean.contains('boon')) return 'Epic Boon';
    return 'General';
  }
}
