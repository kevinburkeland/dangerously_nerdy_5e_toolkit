import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/source_block_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/candidate_identification.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_candidate.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/services/ingestion_workbench_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';

void main() {
  group('Dnd5eIngestionCapability Tests', () {
    const parser = SourceBlockParser();
    const capability = Dnd5eIngestionCapability();
    final service = IngestionWorkbenchService(capability: capability);

    test('unresolved candidate cannot be converted or committed', () {
      final candidate = IngestionCandidate(
        id: 'unresolved_1',
        span: const SourceBlockParser().parse('Some random notes').blocks.first.span,
        rawSource: 'Some random notes',
        normalizedSource: 'Some random notes',
        blocks: const SourceBlockParser().parse('Some random notes').blocks,
        identification: const CandidateIdentification.unknown(),
        targetTypeKey: null, // Unresolved!
        fields: const {},
      );

      final validation = capability.validateCandidate(candidate);
      expect(validation.isValid, isFalse);
      expect(
        validation.blockingErrors.any((e) => e.contains('unresolved')),
        isTrue,
      );

      final conversion = capability.convertCandidate(candidate);
      expect(conversion.isSuccess, isFalse);
      expect(conversion.entity, isNull);
    });

    test('missing required monster values cause conversion failure without fabricated defaults', () {
      const source = '''
### Incomplete Troll
Large giant, chaotic evil
Armor Class lots
Speed 30 ft.
Challenge 5
''';
      final doc = parser.parse(source);
      final fields = capability.extractFields(
        targetTypeKey: 'monster',
        blocks: doc.blocks,
      );

      final candidate = IngestionCandidate(
        id: 'test_incomplete',
        span: doc.blocks.first.span,
        rawSource: source,
        normalizedSource: source,
        blocks: doc.blocks,
        identification: const CandidateIdentification(
          identifiedTypeKey: 'monster',
          confidence: 0.9,
          evidence: [],
        ),
        targetTypeKey: 'monster',
        fields: fields,
      );

      final validation = capability.validateCandidate(candidate);
      expect(validation.isValid, isFalse);
      expect(
        validation.blockingErrors.any((e) => e.contains('Hit Points')),
        isTrue,
        reason: 'Hit Points is missing',
      );
      expect(
        validation.blockingErrors.any((e) => e.contains('Armor Class')),
        isTrue,
        reason: 'Armor Class is invalid string "lots"',
      );

      // Conversion must fail loudly and NOT fabricate HP=10 or AC=10!
      final conversion = capability.convertCandidate(candidate);
      expect(conversion.isSuccess, isFalse);
      expect(conversion.entity, isNull);
    });

    test('missing required spell values cause conversion failure without fabricated defaults', () {
      const source = '''
### Mystery Spell
Casting Time: 1 action
Range: 60 feet
''';
      final doc = parser.parse(source);
      final fields = capability.extractFields(
        targetTypeKey: 'spell',
        blocks: doc.blocks,
      );

      final candidate = IngestionCandidate(
        id: 'test_spell_inc',
        span: doc.blocks.first.span,
        rawSource: source,
        normalizedSource: source,
        blocks: doc.blocks,
        identification: const CandidateIdentification(
          identifiedTypeKey: 'spell',
          confidence: 0.8,
          evidence: [],
        ),
        targetTypeKey: 'spell',
        fields: fields,
      );

      final validation = capability.validateCandidate(candidate);
      expect(validation.isValid, isFalse);
      expect(
        validation.blockingErrors.any((e) => e.contains('Spell Level')),
        isTrue,
        reason: 'Level is missing',
      );
      expect(
        validation.blockingErrors.any((e) => e.contains('School of Magic')),
        isTrue,
        reason: 'School is missing',
      );
      expect(
        validation.blockingErrors.any((e) => e.contains('Duration')),
        isTrue,
        reason: 'Duration is missing',
      );

      // Must NOT fabricate "Evocation", level 0, or "Instantaneous"!
      final conversion = capability.convertCandidate(candidate);
      expect(conversion.isSuccess, isFalse);
      expect(conversion.entity, isNull);
    });

    test('valid corrected monster draft converts to authentic Monster entity', () {
      const source = '''
### Adult Topaz Dragon
Huge dragon, chaotic neutral
Armor Class 19 (natural armor)
Hit Points 210 (20d12 + 80)
Speed 40 ft., fly 80 ft., swim 40 ft.
STR DEX CON INT WIS CHA
20 (+5) 12 (+1) 19 (+4) 16 (+3) 15 (+2) 18 (+4)
Challenge 13 (10,000 XP)
Actions
Multiattack. The dragon makes one Bite attack and two Claw attacks.
''';
      final result = service.parse(source);
      expect(result.candidates.length, equals(1));
      final candidate = result.candidates.first;
      expect(candidate.targetTypeKey, equals('monster'));

      final validation = capability.validateCandidate(candidate);
      expect(validation.isValid, isTrue, reason: validation.blockingErrors.join('; '));

      final conversion = capability.convertCandidate(candidate);
      expect(conversion.isSuccess, isTrue);
      expect(conversion.entity, isA<Monster>());

      final monster = conversion.entity as Monster;
      expect(monster.name, equals('Adult Topaz Dragon'));
      expect(monster.size, equals('Huge'));
      expect(monster.monsterType, equals('dragon'));
      expect(monster.alignment, equals('chaotic neutral'));
      expect(monster.armorClass, equals(19));
      expect(monster.hitPoints, equals(210));
      expect(monster.hitDieFormula, equals('20d12 + 80'));
      expect(monster.challengeRating, equals('13'));
      expect(monster.actionsMarkdown, contains('Multiattack'));
      expect(monster.customProperties['strength'], equals(20));
      expect(monster.customProperties['speed'], equals('40 ft., fly 80 ft., swim 40 ft.'));
      expect(monster.id.ruleset, equals(RulesetVersion.v2024));
    });

    test('valid spell converts to authentic Spell entity and respects 2014 edition', () {
      const source = '''
### Sunbeam
6th-level evocation
Casting Time: 1 action
Range: Self (60-foot line)
Components: V, S, M (a magnifying glass)
Duration: Concentration, up to 1 minute
A beam of brilliant light flashes out.
''';
      const cap2014 = Dnd5eIngestionCapability(edition: DmRulesEdition.v2014);
      final s2014 = IngestionWorkbenchService(capability: cap2014);

      final result = s2014.parse(source);
      expect(result.candidates.length, equals(1));
      final candidate = result.candidates.first;
      expect(candidate.targetTypeKey, equals('spell'));

      final conversion = cap2014.convertCandidate(candidate);
      expect(conversion.isSuccess, isTrue);
      expect(conversion.entity, isA<Spell>());

      final spell = conversion.entity as Spell;
      expect(spell.name, equals('Sunbeam'));
      expect(spell.level, equals(6));
      expect(spell.school.toLowerCase(), equals('evocation'));
      expect(spell.castingTime.actionType, equals(ActionType.action));
      expect(spell.range, equals('Self (60-foot line)'));
      expect(spell.components.v, isTrue);
      expect(spell.components.s, isTrue);
      expect(spell.components.m, isTrue);
      expect(spell.duration.requiresConcentration, isTrue);
      expect(spell.descriptionMarkdown, contains('A beam of brilliant light'));
      expect(spell.id.ruleset, equals(RulesetVersion.v2014));
    });

    test('user edits resolve missing fields and enable successful conversion', () {
      const source = '''
### Mystery Drake
Armor Class 15
Speed 30 ft.
''';
      final result = service.parse(source);
      var candidate = result.candidates.first;

      // Manually assign type if needed, or if monster
      if (candidate.targetTypeKey == null) {
        candidate = service.changeCandidateType(candidate, 'monster');
      }

      // Initial validation fails due to missing HP, size, type, alignment, CR
      expect(capability.validateCandidate(candidate).isValid, isFalse);

      // User supplies missing fields
      candidate = service.updateCandidateField(candidate, 'hitPoints', 65);
      candidate = service.updateCandidateField(candidate, 'size', 'Medium');
      candidate = service.updateCandidateField(candidate, 'monsterType', 'Dragon');
      candidate = service.updateCandidateField(candidate, 'alignment', 'neutral');
      candidate = service.updateCandidateField(candidate, 'challengeRating', '3');

      final validation = capability.validateCandidate(candidate);
      expect(validation.isValid, isTrue, reason: validation.blockingErrors.join('; '));

      final conversion = capability.convertCandidate(candidate);
      expect(conversion.isSuccess, isTrue);
      final monster = conversion.entity as Monster;
      expect(monster.name, equals('Mystery Drake'));
      expect(monster.hitPoints, equals(65));
      expect(monster.size, equals('Medium'));
    });
  });
}
