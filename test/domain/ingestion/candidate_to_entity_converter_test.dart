import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/conversion/candidate_to_entity_converter.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/descriptors/monster_descriptor.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/monster_field_extractor.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/source_block_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/candidate_identification.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_candidate.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/services/ingestion_workbench_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';

void main() {
  group('CandidateToEntityConverter Tests', () {
    const parser = SourceBlockParser();
    const monsterDesc = MonsterDescriptor();
    const monsterExtractor = MonsterFieldExtractor();
    const converter = CandidateToEntityConverter();
    final service = IngestionWorkbenchService();

    test('invalid draft cannot be converted to DomainEntity', () {
      const source = '''
### Incomplete Troll
Large giant, chaotic evil
Armor Class lots
Speed 30 ft.
Challenge 5
''';
      final doc = parser.parse(source);
      final extraction = monsterExtractor.extract(
        blocks: doc.blocks,
        descriptor: monsterDesc,
      );

      final candidate = IngestionCandidate(
        id: 'test_1',
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
        fields: extraction.fields,
      );

      final validation = converter.validate(candidate);
      expect(validation.isValid, isFalse);
      expect(
        validation.blockingErrors.any((e) => e.contains('Hit Points')),
        isTrue,
        reason: 'HP is missing',
      );
      expect(
        validation.blockingErrors.any((e) => e.contains('Armor Class')),
        isTrue,
        reason: 'AC is invalid',
      );

      final conversion = converter.convert(candidate);
      expect(conversion.isSuccess, isFalse);
      expect(conversion.entity, isNull);
    });

    test('valid corrected draft can be converted to intended Monster entity', () {
      const source = '''
### Cave Bear
Large beast, unaligned
Armor Class 12 (natural armor)
Hit Points 42 (5d10 + 15)
Speed 40 ft., swim 30 ft.
Challenge 2 (450 XP)
Actions
Multiattack. The bear makes two attacks: one with its bite and one with its claws.
''';
      final doc = parser.parse(source);
      final extraction = monsterExtractor.extract(
        blocks: doc.blocks,
        descriptor: monsterDesc,
      );

      final candidate = IngestionCandidate(
        id: 'test_2',
        span: doc.blocks.first.span,
        rawSource: source,
        normalizedSource: source,
        blocks: doc.blocks,
        identification: const CandidateIdentification(
          identifiedTypeKey: 'monster',
          confidence: 0.95,
          evidence: [],
        ),
        targetTypeKey: 'monster',
        fields: extraction.fields,
      );

      final validation = converter.validate(candidate);
      expect(validation.isValid, isTrue);

      final conversion = converter.convert(candidate);
      expect(conversion.isSuccess, isTrue);
      expect(conversion.entity, isA<Monster>());
      final monster = conversion.entity as Monster;
      expect(monster.name, equals('Cave Bear'));
      expect(monster.armorClass, equals(12));
      expect(monster.hitPoints, equals(42));
      expect(monster.challengeRating, equals('2'));
      expect(monster.size, equals('Large'));
      expect(monster.monsterType, equals('beast'));
      expect(monster.actionsMarkdown, contains('Multiattack'));
    });

    test('user edits resolve missing fields and enable successful conversion', () {
      const source = '''
### Mystery Golem
Large construct, unaligned
Armor Class 16
Challenge 4
''';
      final result = service.parse(source);
      expect(result.candidates.length, equals(1));
      var candidate = result.candidates.first;

      // Initially missing HP -> blocked
      expect(service.validate(candidate).isValid, isFalse);

      // User supplies missing HP in workbench editor
      candidate = service.updateCandidateField(candidate, 'hitPoints', 65);
      expect(candidate.fields['hitPoints']?.value, equals(65));
      expect(candidate.fields['hitPoints']?.isUserEdited, isTrue);

      // Now valid!
      final validation = service.validate(candidate);
      expect(validation.isValid, isTrue);

      final conversion = service.convertToDomainEntity(candidate);
      expect(conversion.isSuccess, isTrue);
      final monster = conversion.entity as Monster;
      expect(monster.hitPoints, equals(65));
    });

    test('changing candidate type updates expected fields safely', () {
      const source = '''
### Shocking Touch
Evocation cantrip
Casting Time: 1 action
Range: Touch
Components: V, S
Duration: Instantaneous
Lightning springs from your hand to deliver a shock to a creature you try to touch.
''';
      final result = service.parse(source);
      var candidate = result.candidates.first;
      expect(candidate.targetTypeKey, equals('spell'));

      // Change type to monster
      candidate = service.changeCandidateType(candidate, 'monster');
      expect(candidate.targetTypeKey, equals('monster'));
      expect(candidate.fields.containsKey('armorClass'), isTrue);
      expect(candidate.fields.containsKey('hitPoints'), isTrue);

      // Change back to spell
      candidate = service.changeCandidateType(candidate, 'spell');
      expect(candidate.targetTypeKey, equals('spell'));
      expect(candidate.fields.containsKey('castingTime'), isTrue);
      expect(candidate.fields['level']?.value, equals(0));
    });
  });
}
