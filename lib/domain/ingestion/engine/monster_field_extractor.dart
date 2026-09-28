import '../descriptors/object_descriptor.dart';
import '../models/ingestion_field.dart';
import '../models/source_block.dart';
import '../models/source_span.dart';
import 'field_extractor.dart';

/// Field extractor for 5e Monster / Creature stat blocks.
class MonsterFieldExtractor implements FieldExtractor {
  const MonsterFieldExtractor();

  static final _sizeTypeAlignmentPattern = RegExp(
    r'^(Tiny|Small|Medium|Large|Huge|Gargantuan)\s+([^,]+)(?:,\s*(.+))?$',
    caseSensitive: false,
  );
  static final _armorClassPattern = RegExp(
    r'^(?:Armor\s*Class|AC)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _hitPointsPattern = RegExp(
    r'^(?:Hit\s*Points|HP)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _speedPattern = RegExp(
    r'^Speed\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _crPattern = RegExp(
    r'^(?:Challenge|CR)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _abilityHeadersPattern = RegExp(
    r'\bSTR\b.*?\bDEX\b.*?\bCON\b.*?\bINT\b.*?\bWIS\b.*?\bCHA\b',
    caseSensitive: false,
  );
  static final _abilityScoresLinePattern = RegExp(
    r'(\d+)\s*\([+-]?\d+\)\s+(\d+)\s*\([+-]?\d+\)\s+(\d+)\s*\([+-]?\d+\)\s+(\d+)\s*\([+-]?\d+\)\s+(\d+)\s*\([+-]?\d+\)\s+(\d+)\s*\([+-]?\d+\)',
    caseSensitive: false,
  );
  static final _singleAbilityPattern = RegExp(
    r'\b(STR|DEX|CON|INT|WIS|CHA)\s*[:]?\s*(\d+)',
    caseSensitive: false,
  );

  @override
  FieldExtractionResult extract({
    required List<SourceBlock> blocks,
    required ObjectDescriptor descriptor,
  }) {
    final fields = <String, IngestionField<dynamic>>{};
    final consumedBlockIds = <String>{};

    if (blocks.isEmpty) {
      _populateMissingFields(fields, descriptor);
      return FieldExtractionResult(fields: fields);
    }

    int blockIndex = 0;

    // 1. Name: typically the first block (heading or plain text title)
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

    // 2. Subtitle: Size, Type, Alignment
    if (blockIndex < blocks.length) {
      final subBlock = blocks[blockIndex];
      final match = _sizeTypeAlignmentPattern.firstMatch(subBlock.normalizedText);
      if (match != null) {
        final sizeStr = match.group(1)!.trim();
        final typeStr = match.group(2)!.trim();
        final alignStr = match.group(3)?.trim() ?? 'unaligned';

        fields['size'] = IngestionField<String>.extracted(
          key: 'size',
          label: 'Size',
          value: sizeStr,
          rawText: sizeStr,
          span: subBlock.span,
          isRequired: true,
        );
        fields['monsterType'] = IngestionField<String>.extracted(
          key: 'monsterType',
          label: 'Type',
          value: typeStr,
          rawText: typeStr,
          span: subBlock.span,
          isRequired: true,
        );
        fields['alignment'] = IngestionField<String>.extracted(
          key: 'alignment',
          label: 'Alignment',
          value: alignStr,
          rawText: alignStr,
          span: subBlock.span,
          isRequired: true,
        );

        consumedBlockIds.add(subBlock.id);
        blockIndex++;
      }
    }

    // 3. Scan remaining blocks for known stats (AC, HP, Speed, Abilities, CR, Actions)
    String currentSection = 'stats'; // 'stats', 'traits', 'actions', 'reactions', 'legendary'
    final sectionBuffers = <String, List<String>>{
      'traits': [],
      'actions': [],
      'reactions': [],
      'legendary': [],
    };
    final sectionSpans = <String, List<SourceSpan>>{};

    for (; blockIndex < blocks.length; blockIndex++) {
      final block = blocks[blockIndex];
      final line = block.normalizedText;

      // Section switches
      final lower = line.toLowerCase();
      if (lower == 'actions' || lower == '### actions' || lower == '## actions') {
        currentSection = 'actions';
        consumedBlockIds.add(block.id);
        continue;
      }
      if (lower == 'reactions' || lower == '### reactions' || lower == '## reactions') {
        currentSection = 'reactions';
        consumedBlockIds.add(block.id);
        continue;
      }
      if (lower.contains('legendary actions')) {
        currentSection = 'legendary';
        consumedBlockIds.add(block.id);
        continue;
      }

      // Check for Size, Type, Alignment if reordered or not yet extracted
      if (!fields.containsKey('size')) {
        final match = _sizeTypeAlignmentPattern.firstMatch(line);
        if (match != null) {
          final sizeStr = match.group(1)!.trim();
          final typeStr = match.group(2)!.trim();
          final alignStr = match.group(3)?.trim() ?? 'unaligned';

          fields['size'] = IngestionField<String>.extracted(
            key: 'size',
            label: 'Size',
            value: sizeStr,
            rawText: sizeStr,
            span: block.span,
            isRequired: true,
          );
          fields['monsterType'] = IngestionField<String>.extracted(
            key: 'monsterType',
            label: 'Type',
            value: typeStr,
            rawText: typeStr,
            span: block.span,
            isRequired: true,
          );
          fields['alignment'] = IngestionField<String>.extracted(
            key: 'alignment',
            label: 'Alignment',
            value: alignStr,
            rawText: alignStr,
            span: block.span,
            isRequired: true,
          );

          consumedBlockIds.add(block.id);
          continue;
        }
      }

      // Check for AC
      final acMatch = _armorClassPattern.firstMatch(line);
      if (acMatch != null && !fields.containsKey('armorClass')) {
        final acRaw = acMatch.group(1)!.trim();
        final digitMatch = RegExp(r'^\d+').firstMatch(acRaw);
        if (digitMatch != null) {
          fields['armorClass'] = IngestionField<int>.extracted(
            key: 'armorClass',
            label: 'Armor Class',
            value: int.parse(digitMatch.group(0)!),
            rawText: line,
            span: block.span,
            isRequired: true,
          );
        } else if (acRaw.contains('?') || acRaw.toLowerCase().contains('unknown')) {
          fields['armorClass'] = IngestionField<int>.ambiguous(
            key: 'armorClass',
            label: 'Armor Class',
            options: ['10', '12', '14', '16', '18'],
            rawText: line,
            span: block.span,
            isRequired: true,
          );
        } else {
          fields['armorClass'] = IngestionField<int>.invalid(
            key: 'armorClass',
            label: 'Armor Class',
            rawText: line,
            validationError: 'Armor Class must be an integer, got "$acRaw".',
            span: block.span,
            isRequired: true,
          );
        }
        consumedBlockIds.add(block.id);
        continue;
      }

      // Check for HP
      final hpMatch = _hitPointsPattern.firstMatch(line);
      if (hpMatch != null && !fields.containsKey('hitPoints')) {
        final hpRaw = hpMatch.group(1)!.trim();
        final digitMatch = RegExp(r'^\d+').firstMatch(hpRaw);
        if (digitMatch != null) {
          fields['hitPoints'] = IngestionField<int>.extracted(
            key: 'hitPoints',
            label: 'Hit Points',
            value: int.parse(digitMatch.group(0)!),
            rawText: line,
            span: block.span,
            isRequired: true,
          );
          // Check for hit die formula inside parentheses e.g. (16d10 + 48)
          final formulaMatch = RegExp(r'\(([^)]+)\)').firstMatch(hpRaw);
          if (formulaMatch != null) {
            fields['hitDieFormula'] = IngestionField<String>.extracted(
              key: 'hitDieFormula',
              label: 'Hit Dice Formula',
              value: formulaMatch.group(1)!.trim(),
              rawText: formulaMatch.group(0)!,
              span: block.span,
              isRequired: false,
            );
          }
        } else if (hpRaw.contains('?') || hpRaw.toLowerCase().contains('unknown')) {
          fields['hitPoints'] = IngestionField<int>.ambiguous(
            key: 'hitPoints',
            label: 'Hit Points',
            options: ['10', '25', '50', '100'],
            rawText: line,
            span: block.span,
            isRequired: true,
          );
        } else {
          fields['hitPoints'] = IngestionField<int>.invalid(
            key: 'hitPoints',
            label: 'Hit Points',
            rawText: line,
            validationError: 'Hit Points must be an integer, got "$hpRaw".',
            span: block.span,
            isRequired: true,
          );
        }
        consumedBlockIds.add(block.id);
        continue;
      }

      // Check for Speed
      final speedMatch = _speedPattern.firstMatch(line);
      if (speedMatch != null && !fields.containsKey('speed')) {
        fields['speed'] = IngestionField<String>.extracted(
          key: 'speed',
          label: 'Speed',
          value: speedMatch.group(1)!.trim(),
          rawText: line,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      // Check for Ability scores
      if (_abilityHeadersPattern.hasMatch(line)) {
        consumedBlockIds.add(block.id);
        // Look at next block for ability values
        if (blockIndex + 1 < blocks.length) {
          final nextBlock = blocks[blockIndex + 1];
          final scoresMatch = _abilityScoresLinePattern.firstMatch(nextBlock.normalizedText);
          if (scoresMatch != null) {
            _assignAbilityScore(fields, 'strength', 'Strength (STR)', scoresMatch.group(1)!, nextBlock.span);
            _assignAbilityScore(fields, 'dexterity', 'Dexterity (DEX)', scoresMatch.group(2)!, nextBlock.span);
            _assignAbilityScore(fields, 'constitution', 'Constitution (CON)', scoresMatch.group(3)!, nextBlock.span);
            _assignAbilityScore(fields, 'intelligence', 'Intelligence (INT)', scoresMatch.group(4)!, nextBlock.span);
            _assignAbilityScore(fields, 'wisdom', 'Wisdom (WIS)', scoresMatch.group(5)!, nextBlock.span);
            _assignAbilityScore(fields, 'charisma', 'Charisma (CHA)', scoresMatch.group(6)!, nextBlock.span);
            consumedBlockIds.add(nextBlock.id);
            blockIndex++;
            continue;
          }
        }
        continue;
      }

      // Check for inline ability scores e.g. "STR: 16 DEX: 14"
      if (_singleAbilityPattern.hasMatch(line) && !fields.containsKey('strength')) {
        for (final m in _singleAbilityPattern.allMatches(line)) {
          final statKey = switch (m.group(1)!.toUpperCase()) {
            'STR' => 'strength',
            'DEX' => 'dexterity',
            'CON' => 'constitution',
            'INT' => 'intelligence',
            'WIS' => 'wisdom',
            'CHA' => 'charisma',
            _ => null,
          };
          if (statKey != null) {
            _assignAbilityScore(fields, statKey, m.group(1)!, m.group(2)!, block.span);
          }
        }
        consumedBlockIds.add(block.id);
        continue;
      }

      // Check for CR / Challenge
      final crMatch = _crPattern.firstMatch(line);
      if (crMatch != null && !fields.containsKey('challengeRating')) {
        final crRaw = crMatch.group(1)!.trim();
        if (crRaw.contains('?') || crRaw.toLowerCase().contains('unknown')) {
          fields['challengeRating'] = IngestionField<String>.ambiguous(
            key: 'challengeRating',
            label: 'Challenge Rating (CR)',
            options: ['0', '1/8', '1/4', '1/2', '1', '2', '3', '5'],
            rawText: line,
            span: block.span,
            isRequired: true,
          );
        } else {
          // Extract CR token before XP if present e.g. "5 (1,800 XP)"
          final crToken = RegExp(r'^(\d+/\d+|\d+)').firstMatch(crRaw);
          fields['challengeRating'] = IngestionField<String>.extracted(
            key: 'challengeRating',
            label: 'Challenge Rating (CR)',
            value: crToken != null ? crToken.group(0)! : crRaw,
            rawText: line,
            span: block.span,
            isRequired: true,
          );
        }
        consumedBlockIds.add(block.id);
        continue;
      }

      // If in actions or reactions section, collect lines
      if (currentSection != 'stats') {
        sectionBuffers[currentSection]?.add(block.rawText);
        sectionSpans.putIfAbsent(currentSection, () => []).add(block.span);
        consumedBlockIds.add(block.id);
        continue;
      }

      // Otherwise if we have passed stats and haven't hit actions, check if it's a trait
      final isTraitLine =
          RegExp(r'^(?:\*\*[^*]+\*\*|[A-Z][a-zA-Z0-9\s-]{1,30})\.\s+')
              .hasMatch(line);
      if (fields.containsKey('armorClass') &&
          fields.containsKey('hitPoints') &&
          isTraitLine) {
        sectionBuffers['traits']?.add(block.rawText);
        sectionSpans.putIfAbsent('traits', () => []).add(block.span);
        consumedBlockIds.add(block.id);
      }
    }

    // Populate accumulated section text
    if (sectionBuffers['actions']!.isNotEmpty) {
      fields['actionsMarkdown'] = IngestionField<String>.extracted(
        key: 'actionsMarkdown',
        label: 'Actions',
        value: sectionBuffers['actions']!.join('\n\n'),
        rawText: sectionBuffers['actions']!.join('\n'),
        isRequired: false,
      );
    }
    if (sectionBuffers['traits']!.isNotEmpty) {
      fields['traitsMarkdown'] = IngestionField<String>.extracted(
        key: 'traitsMarkdown',
        label: 'Special Traits',
        value: sectionBuffers['traits']!.join('\n\n'),
        rawText: sectionBuffers['traits']!.join('\n'),
        isRequired: false,
      );
    }
    if (sectionBuffers['reactions']!.isNotEmpty) {
      fields['reactionsMarkdown'] = IngestionField<String>.extracted(
        key: 'reactionsMarkdown',
        label: 'Reactions',
        value: sectionBuffers['reactions']!.join('\n\n'),
        rawText: sectionBuffers['reactions']!.join('\n'),
        isRequired: false,
      );
    }
    if (sectionBuffers['legendary']!.isNotEmpty) {
      fields['legendaryActionsMarkdown'] = IngestionField<String>.extracted(
        key: 'legendaryActionsMarkdown',
        label: 'Legendary Actions',
        value: sectionBuffers['legendary']!.join('\n\n'),
        rawText: sectionBuffers['legendary']!.join('\n'),
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

  void _assignAbilityScore(
    Map<String, IngestionField<dynamic>> fields,
    String key,
    String label,
    String rawScore,
    SourceSpan span,
  ) {
    final parsed = int.tryParse(rawScore.trim());
    if (parsed != null) {
      fields[key] = IngestionField<int>.extracted(
        key: key,
        label: label,
        value: parsed,
        rawText: rawScore,
        span: span,
        isRequired: false,
      );
    }
  }

  void _populateMissingFields(
    Map<String, IngestionField<dynamic>> fields,
    ObjectDescriptor descriptor,
  ) {
    for (final desc in descriptor.fields) {
      if (!fields.containsKey(desc.key)) {
        if (desc.isRequired) {
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
