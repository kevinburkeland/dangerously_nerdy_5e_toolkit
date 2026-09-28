import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/engine/field_extractor.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/ingestion_section.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';

/// 5e-specific field extractor for Spells.
class Dnd5eSpellFieldExtractor implements FieldExtractor {
  const Dnd5eSpellFieldExtractor();

  static final _levelSchoolPattern1 = RegExp(
    r'^(\d+)(?:st|nd|rd|th)[- ]level\s+(\w+)(?:\s*\(([^)]+)\))?$',
    caseSensitive: false,
  );
  static final _levelSchoolPattern2 = RegExp(
    r'^(\w+)\s+cantrip(?:\s*\(([^)]+)\))?$',
    caseSensitive: false,
  );
  static final _levelSchoolPattern3 = RegExp(
    r'^cantrip\s+(\w+)(?:\s*\(([^)]+)\))?$',
    caseSensitive: false,
  );

  static final _castingTimePattern = RegExp(
    r'^Casting\s*Time\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _rangePattern = RegExp(
    r'^Range\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _componentsPattern = RegExp(
    r'^Components\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _durationPattern = RegExp(
    r'^Duration\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _higherLevelsHeaderPattern = RegExp(
    r'^(?:###\s*)?(?:At\s+Higher\s+Levels|Higher\s+Levels)\.?$',
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

    // 1. Name: first block
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

    // 2. Subtitle: Level & School
    if (blockIndex < blocks.length) {
      final subBlock = blocks[blockIndex];
      final line = subBlock.normalizedText;

      final m1 = _levelSchoolPattern1.firstMatch(line);
      final m2 = _levelSchoolPattern2.firstMatch(line);
      final m3 = _levelSchoolPattern3.firstMatch(line);

      if (m1 != null) {
        final level = int.tryParse(m1.group(1)!);
        final school = m1.group(2)!.trim();

        if (level != null) {
          fields['level'] = IngestionField<int>.extracted(
            key: 'level',
            label: 'Spell Level',
            value: level,
            rawText: m1.group(1)!,
            span: subBlock.span,
            isRequired: true,
          );
        }
        fields['school'] = IngestionField<String>.extracted(
          key: 'school',
          label: 'School of Magic',
          value: school[0].toUpperCase() + school.substring(1).toLowerCase(),
          rawText: school,
          span: subBlock.span,
          isRequired: true,
        );
        consumedBlockIds.add(subBlock.id);
        blockIndex++;
      } else if (m2 != null || m3 != null) {
        final school = (m2 != null ? m2.group(1) : m3!.group(1))!.trim();
        fields['level'] = IngestionField<int>.extracted(
          key: 'level',
          label: 'Spell Level',
          value: 0,
          rawText: 'cantrip',
          span: subBlock.span,
          isRequired: true,
        );
        fields['school'] = IngestionField<String>.extracted(
          key: 'school',
          label: 'School of Magic',
          value: school[0].toUpperCase() + school.substring(1).toLowerCase(),
          rawText: school,
          span: subBlock.span,
          isRequired: true,
        );
        consumedBlockIds.add(subBlock.id);
        blockIndex++;
      } else if (line.toLowerCase().contains('level') || line.toLowerCase().contains('cantrip')) {
        // Ambiguous level/school line
        fields['level'] = IngestionField<int>.ambiguous(
          key: 'level',
          label: 'Spell Level',
          options: ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'],
          rawText: line,
          span: subBlock.span,
          isRequired: true,
        );
        consumedBlockIds.add(subBlock.id);
        blockIndex++;
      }
    }

    // 3. Scan parameters (Casting Time, Range, Components, Duration) and Description
    final descBlocks = <String>[];
    final higherLevelBlocks = <String>[];
    bool inHigherLevels = false;

    for (; blockIndex < blocks.length; blockIndex++) {
      final block = blocks[blockIndex];
      final line = block.normalizedText;

      final ctMatch = _castingTimePattern.firstMatch(line);
      if (ctMatch != null && !fields.containsKey('castingTime')) {
        fields['castingTime'] = IngestionField<String>.extracted(
          key: 'castingTime',
          label: 'Casting Time',
          value: ctMatch.group(1)!.trim(),
          rawText: line,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final rangeMatch = _rangePattern.firstMatch(line);
      if (rangeMatch != null && !fields.containsKey('range')) {
        fields['range'] = IngestionField<String>.extracted(
          key: 'range',
          label: 'Range',
          value: rangeMatch.group(1)!.trim(),
          rawText: line,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final compMatch = _componentsPattern.firstMatch(line);
      if (compMatch != null && !fields.containsKey('components')) {
        fields['components'] = IngestionField<String>.extracted(
          key: 'components',
          label: 'Components',
          value: compMatch.group(1)!.trim(),
          rawText: line,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final durMatch = _durationPattern.firstMatch(line);
      if (durMatch != null && !fields.containsKey('duration')) {
        fields['duration'] = IngestionField<String>.extracted(
          key: 'duration',
          label: 'Duration',
          value: durMatch.group(1)!.trim(),
          rawText: line,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      if (_higherLevelsHeaderPattern.hasMatch(line)) {
        inHigherLevels = true;
        consumedBlockIds.add(block.id);
        continue;
      }

      if (inHigherLevels) {
        higherLevelBlocks.add(block.rawText);
        consumedBlockIds.add(block.id);
      } else {
        descBlocks.add(block.rawText);
        consumedBlockIds.add(block.id);
      }
    }

    if (descBlocks.isNotEmpty) {
      fields['descriptionMarkdown'] = IngestionField<String>.extracted(
        key: 'descriptionMarkdown',
        label: 'Description',
        value: descBlocks.join('\n\n'),
        rawText: descBlocks.join('\n'),
        isRequired: true,
      );
    }

    if (higherLevelBlocks.isNotEmpty) {
      fields['higherLevelsMarkdown'] = IngestionField<String>.extracted(
        key: 'higherLevelsMarkdown',
        label: 'At Higher Levels',
        value: higherLevelBlocks.join('\n\n'),
        rawText: higherLevelBlocks.join('\n'),
        isRequired: false,
      );
    }

    _populateMissingFields(fields, descriptor);

    final unrecognized =
        blocks.where((b) => !consumedBlockIds.contains(b.id)).toList();

    return FieldExtractionResult(
      fields: fields,
      unrecognizedBlocks: unrecognized,
    );
  }

  void _populateMissingFields(
    Map<String, IngestionField<dynamic>> fields,
    IngestionTargetDescriptor descriptor,
  ) {
    for (final desc in descriptor.fields) {
      if (!fields.containsKey(desc.key)) {
        if (desc.isRequiredForRecognition) {
          fields[desc.key] = IngestionField<dynamic>.missing(
            key: desc.key,
            label: desc.label,
            isRequired: true,
          );
        } else {
          fields[desc.key] = IngestionField<dynamic>.optionalNotProvided(
            key: desc.key,
            label: desc.label,
          );
        }
      }
    }
  }
}
