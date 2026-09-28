import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/engine/field_extractor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';

/// 5e-specific field extractor for Backgrounds.
class Dnd5eBackgroundFieldExtractor implements FieldExtractor {
  const Dnd5eBackgroundFieldExtractor();

  static final _skillProficienciesPattern = RegExp(
    r'^(?:Skill\s+Proficiencies|Skills)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _toolProficienciesPattern = RegExp(
    r'^(?:Tool\s+Proficiencies|Tools)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _languagesPattern = RegExp(
    r'^Languages\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _asiPattern = RegExp(
    r'^(?:Ability\s+Scores?|Ability\s+Score\s+Increase)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _originFeatPattern = RegExp(
    r'^(?:Origin\s+Feat|Bonus\s+Feat|Feat)\s*[:]?\s*(.+)$',
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
        label: 'Background Name',
        value: titleText,
        rawText: firstBlock.rawText,
        span: firstBlock.span,
        isRequired: true,
      );
      consumedBlockIds.add(firstBlock.id);
      blockIndex++;
    }

    // 2. Scan for Stat lines
    final descBlocks = <SourceBlock>[];
    for (int i = blockIndex; i < blocks.length; i++) {
      final block = blocks[i];
      final text = block.normalizedText;

      final spMatch = _skillProficienciesPattern.firstMatch(text);
      if (spMatch != null && !fields.containsKey('skillProficiencies')) {
        final rawSkills = spMatch.group(1)!.trim();
        final skills = rawSkills
            .split(RegExp(r'[,/]|(?:\s+and\s+)'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        fields['skillProficiencies'] = IngestionField<List<String>>.extracted(
          key: 'skillProficiencies',
          label: 'Skill Proficiencies',
          value: skills,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final tpMatch = _toolProficienciesPattern.firstMatch(text);
      if (tpMatch != null && !fields.containsKey('toolProficiencies')) {
        final rawTools = tpMatch.group(1)!.trim();
        final tools = rawTools
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        fields['toolProficiencies'] = IngestionField<List<String>>.extracted(
          key: 'toolProficiencies',
          label: 'Tool Proficiencies',
          value: tools,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final langMatch = _languagesPattern.firstMatch(text);
      if (langMatch != null && !fields.containsKey('languages')) {
        final rawLang = langMatch.group(1)!.trim();
        final langs = rawLang
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        fields['languages'] = IngestionField<List<String>>.extracted(
          key: 'languages',
          label: 'Languages',
          value: langs,
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

      final featMatch = _originFeatPattern.firstMatch(text);
      if (featMatch != null && !fields.containsKey('originFeat')) {
        final feat = featMatch.group(1)!.trim();
        fields['originFeat'] = IngestionField<String>.extracted(
          key: 'originFeat',
          label: 'Origin Feat',
          value: feat,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      descBlocks.add(block);
    }

    // 3. Description & Features Markdown
    if (descBlocks.isNotEmpty) {
      final fullDesc = descBlocks.map((b) => b.rawText).join('\n\n');
      fields['descriptionMarkdown'] = IngestionField<String>.extracted(
        key: 'descriptionMarkdown',
        label: 'Description & Features',
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
