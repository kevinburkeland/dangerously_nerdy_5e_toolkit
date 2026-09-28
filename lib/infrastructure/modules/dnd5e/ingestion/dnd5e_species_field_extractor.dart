import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/engine/field_extractor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/ingestion_section.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';

/// 5e-specific field extractor for Species / Races.
class Dnd5eSpeciesFieldExtractor implements FieldExtractor {
  const Dnd5eSpeciesFieldExtractor();

  static final _sizePattern = RegExp(
    r'^Size\s*[:]?\s*(Small|Medium|Tiny|Large|Small\s+or\s+Medium|Medium\s+or\s+Small)\b',
    caseSensitive: false,
  );

  static final _speedPattern = RegExp(
    r'^Speed\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _creatureTypePattern = RegExp(
    r'^Creature\s+Type\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _asiPattern = RegExp(
    r'^(?:Ability\s+Score\s+Increase|Ability\s+Scores?)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  @override
  FieldExtractionResult extract({
    required List<SourceBlock> blocks,
    required IngestionTargetDescriptor descriptor,
    SourceSpan? span,
    List<IngestionSection>? childSections,
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
        label: 'Species Name',
        value: titleText,
        rawText: firstBlock.rawText,
        span: firstBlock.span,
        isRequired: true,
      );
      consumedBlockIds.add(firstBlock.id);
      blockIndex++;
    }

    // 2. Scan for Size, Speed, Creature Type, and ASI
    final descBlocks = <SourceBlock>[];
    for (int i = blockIndex; i < blocks.length; i++) {
      final block = blocks[i];
      final text = block.normalizedText;

      final sizeMatch = _sizePattern.firstMatch(text);
      if (sizeMatch != null && !fields.containsKey('size')) {
        final size = sizeMatch.group(1)!.trim();
        fields['size'] = IngestionField<String>.extracted(
          key: 'size',
          label: 'Size',
          value: size,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final speedMatch = _speedPattern.firstMatch(text);
      if (speedMatch != null && !fields.containsKey('speed')) {
        final spd = speedMatch.group(1)!.trim();
        fields['speed'] = IngestionField<String>.extracted(
          key: 'speed',
          label: 'Speed',
          value: spd,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final ctMatch = _creatureTypePattern.firstMatch(text);
      if (ctMatch != null && !fields.containsKey('creatureType')) {
        final ct = ctMatch.group(1)!.trim();
        fields['creatureType'] = IngestionField<String>.extracted(
          key: 'creatureType',
          label: 'Creature Type',
          value: ct,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final asiMatch = _asiPattern.firstMatch(text);
      if (asiMatch != null && !fields.containsKey('abilityScoreSummary')) {
        final asi = asiMatch.group(1)!.trim();
        fields['abilityScoreSummary'] = IngestionField<String>.extracted(
          key: 'abilityScoreSummary',
          label: 'Ability Scores',
          value: asi,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      descBlocks.add(block);
    }

    // 3. Traits Markdown
    final composedTraits = <String>[];
    if (descBlocks.isNotEmpty) {
      composedTraits.add(descBlocks.map((b) => b.rawText).join('\n\n'));
    }
    if (childSections != null) {
      for (final sec in childSections) {
        if (sec.classification == 'trait' ||
            sec.classification == 'unknown' ||
            sec.classification == 'descriptiveProse') {
          final h = sec.headingText != null && sec.headingText!.trim().isNotEmpty
              ? '### ${sec.headingText!.trim()}'
              : '';
          final b = sec.blocks
              .where((bk) => bk.type != SourceBlockType.heading)
              .map((bk) => bk.rawText)
              .join('\n')
              .trim();
          if (h.isNotEmpty && b.isNotEmpty) {
            composedTraits.add('$h\n\n$b');
          } else if (h.isNotEmpty) {
            composedTraits.add(h);
          } else if (b.isNotEmpty) {
            composedTraits.add(b);
          } else if (sec.rawSource.trim().isNotEmpty) {
            composedTraits.add(sec.rawSource.trim());
          }
        }
      }
    }

    if (composedTraits.isNotEmpty) {
      final fullDesc = composedTraits.join('\n\n');
      final firstSpan = descBlocks.isNotEmpty
          ? descBlocks.first.span
          : (childSections?.firstOrNull?.span ?? const SourceSpan.empty());
      final lastSpan = childSections != null && childSections.isNotEmpty
          ? childSections.last.span
          : (descBlocks.isNotEmpty ? descBlocks.last.span : const SourceSpan.empty());

      fields['traitsMarkdown'] = IngestionField<String>.extracted(
        key: 'traitsMarkdown',
        label: 'Traits',
        value: fullDesc,
        rawText: fullDesc,
        span: SourceSpan(
          startOffset: firstSpan.startOffset,
          endOffset: lastSpan.endOffset,
          startLine: firstSpan.startLine,
          startColumn: firstSpan.startColumn,
          endLine: lastSpan.endLine,
          endColumn: lastSpan.endColumn,
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
