import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/engine/field_extractor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';

/// 5e-specific field extractor for Character Classes.
class Dnd5eClassFieldExtractor implements FieldExtractor {
  const Dnd5eClassFieldExtractor();

  static final _hitDiePattern = RegExp(
    r'^Hit\s+Die\s*[:]?\s*(?:1)?(d(?:6|8|10|12))\b',
    caseSensitive: false,
  );

  static final _primaryAbilityPattern = RegExp(
    r'^Primary\s+Ability\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _savingThrowsPattern = RegExp(
    r'^Saving\s+Throws?\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _armorProficienciesPattern = RegExp(
    r'^(?:Armor\s+Proficiencies|Armor\s+Training|Armor)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _weaponProficienciesPattern = RegExp(
    r'^(?:Weapon\s+Proficiencies|Weapon\s+Training|Weapons)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  static final _subclassLevelPattern = RegExp(
    r'^(?:Subclass\s+Level|Archetype\s+Level)\s*[:]?\s*(\d+)$',
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
        label: 'Class Name',
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

      final hdMatch = _hitDiePattern.firstMatch(text);
      if (hdMatch != null && !fields.containsKey('hitDie')) {
        final die = hdMatch.group(1)!.toLowerCase();
        fields['hitDie'] = IngestionField<String>.extracted(
          key: 'hitDie',
          label: 'Hit Die',
          value: die,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final paMatch = _primaryAbilityPattern.firstMatch(text);
      if (paMatch != null && !fields.containsKey('primaryAbility')) {
        final pa = paMatch.group(1)!.trim();
        fields['primaryAbility'] = IngestionField<String>.extracted(
          key: 'primaryAbility',
          label: 'Primary Ability',
          value: pa,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final stMatch = _savingThrowsPattern.firstMatch(text);
      if (stMatch != null && !fields.containsKey('savingThrows')) {
        final rawSt = stMatch.group(1)!.trim();
        final saves = rawSt
            .split(RegExp(r'[,/]|(?:\s+and\s+)'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        fields['savingThrows'] = IngestionField<List<String>>.extracted(
          key: 'savingThrows',
          label: 'Saving Throws',
          value: saves,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final apMatch = _armorProficienciesPattern.firstMatch(text);
      if (apMatch != null && !fields.containsKey('armorProficiencies')) {
        final rawAp = apMatch.group(1)!.trim();
        final armors = rawAp
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        fields['armorProficiencies'] = IngestionField<List<String>>.extracted(
          key: 'armorProficiencies',
          label: 'Armor Proficiencies',
          value: armors,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final wpMatch = _weaponProficienciesPattern.firstMatch(text);
      if (wpMatch != null && !fields.containsKey('weaponProficiencies')) {
        final rawWp = wpMatch.group(1)!.trim();
        final weapons = rawWp
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

        fields['weaponProficiencies'] = IngestionField<List<String>>.extracted(
          key: 'weaponProficiencies',
          label: 'Weapon Proficiencies',
          value: weapons,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final subLvlMatch = _subclassLevelPattern.firstMatch(text);
      if (subLvlMatch != null && !fields.containsKey('subclassSelectionLevel')) {
        final lvl = int.tryParse(subLvlMatch.group(1)!);
        if (lvl != null) {
          fields['subclassSelectionLevel'] = IngestionField<int>.extracted(
            key: 'subclassSelectionLevel',
            label: 'Subclass Selection Level',
            value: lvl,
            rawText: block.rawText,
            span: block.span,
            isRequired: false,
          );
          consumedBlockIds.add(block.id);
          continue;
        }
      }

      descBlocks.add(block);
    }

    // Default subclass selection level to 3 if not explicitly declared
    if (!fields.containsKey('subclassSelectionLevel')) {
      fields['subclassSelectionLevel'] = IngestionField<int>.inferred(
        key: 'subclassSelectionLevel',
        label: 'Subclass Selection Level',
        value: 3,
        confidence: 0.9,
        evidence: 'Standard 5e subclass milestone level.',
      );
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
        isRequired: false,
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
