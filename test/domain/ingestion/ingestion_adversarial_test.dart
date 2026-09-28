import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/field_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/services/ingestion_workbench_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';

void main() {
  group('Ingestion Adversarial & Edge Case Tests', () {
    final service = IngestionWorkbenchService(capability: const Dnd5eIngestionCapability());

    test('handles reordered sections gracefully', () {
      const source = '''
### Chrono Stalker
Actions
Time Rip. The stalker strikes through the timeline for 12 force damage.
Challenge 4
Hit Points 68 (8d10 + 24)
Armor Class 15
Medium aberration, chaotic neutral
Speed 30 ft.
''';
      final result = service.parse(source);
      expect(result.candidates.length, equals(1));
      final candidate = result.candidates.first;

      expect(candidate.fields['name']?.value, equals('Chrono Stalker'));
      expect(candidate.fields['armorClass']?.value, equals(15));
      expect(candidate.fields['hitPoints']?.value, equals(68));
      expect(candidate.fields['challengeRating']?.value, equals('4'));
      expect(candidate.fields['actionsMarkdown']?.value, contains('Time Rip'));
      expect(candidate.isReadyToCommit, isTrue);
    });

    test('handles omitted optional fields without hallucinating data', () {
      const source = '''
### Simple Skeleton
Medium undead, lawful evil
Armor Class 13
Hit Points 13
Challenge 1/4
''';
      final result = service.parse(source);
      final candidate = result.candidates.first;

      // Speed was omitted
      expect(candidate.fields['speed']?.state,
          equals(IngestionFieldState.optionalNotProvided));
      expect(candidate.fields['speed']?.value, isNull);

      // Hit die formula was omitted
      expect(candidate.fields['hitDieFormula']?.state,
          equals(IngestionFieldState.optionalNotProvided));
      expect(candidate.fields['hitDieFormula']?.value, isNull);

      // Actions omitted
      expect(candidate.fields['actionsMarkdown']?.state,
          equals(IngestionFieldState.optionalNotProvided));

      // Ready to commit because only optional fields are missing
      expect(candidate.isReadyToCommit, isTrue);
    });

    test('preserves prose interspersed between stat lines as unrecognized text', () {
      const source = '''
### Swamp Hag
Medium fey, chaotic evil
Armor Class 17 (natural armor)
Note: She always bathes in rancid swamp water at midnight.
Hit Points 82 (11d8 + 33)
DMs should remember to check for disease if bitten.
Challenge 3 (700 XP)
''';
      final result = service.parse(source);
      final candidate = result.candidates.first;

      expect(candidate.fields['armorClass']?.value, equals(17));
      expect(candidate.fields['hitPoints']?.value, equals(82));
      expect(candidate.unrecognizedBlocks.length, greaterThanOrEqualTo(2));
      expect(
        candidate.unrecognizedBlocks.any((b) => b.rawText.contains('rancid swamp water')),
        isTrue,
      );
      expect(
        candidate.unrecognizedBlocks.any((b) => b.rawText.contains('check for disease')),
        isTrue,
      );
    });

    test('handles duplicate stat lines by preserving first valid and capturing later', () {
      const source = '''
### Dual Shield Golem
Large construct, unaligned
Armor Class 16
Armor Class 18 (with tower shield)
Hit Points 90
Challenge 5
''';
      final result = service.parse(source);
      final candidate = result.candidates.first;

      expect(candidate.fields['armorClass']?.value, equals(16));
      expect(candidate.fields['hitPoints']?.value, equals(90));
      // Second AC line is preserved in unrecognizedBlocks
      expect(
        candidate.unrecognizedBlocks.any((b) => b.rawText.contains('tower shield')),
        isTrue,
      );
    });

    test('detects malformed dice notation in custom validator', () {
      const desc = IngestionFieldDescriptor(
        key: 'hitDieFormula',
        label: 'Hit Dice Formula',
        valueType: FieldValueType.diceFormula,
      );

      expect(desc.validateSyntactic('2d6'), isNull);
      expect(desc.validateSyntactic('1d10 + 3'), isNull);
      expect(desc.validateSyntactic('dice'), contains('valid dice notation'));
      expect(desc.validateSyntactic('3d?'), contains('valid dice notation'));
      expect(desc.validateSyntactic('1d10+banana'), contains('valid dice notation'));
    });

    test('unknown headings are preserved into unrecognized blocks without crashing', () {
      const source = '''
### Void Sentinel
Medium construct, unaligned
Armor Class 19
Hit Points 110
Challenge 7
### Lair Ecology
The void sentinel dwells in null-gravity pockets of the astral plane.
### Ancient Creator
Constructed by the Forgotten Mages of Netheril.
''';
      final result = service.parse(source);
      final candidate = result.candidates.first;

      expect(candidate.fields['armorClass']?.value, equals(19));
      expect(candidate.unrecognizedBlocks.isNotEmpty, isTrue);
      expect(
        candidate.unrecognizedBlocks.any((b) => b.rawText.contains('Lair Ecology')),
        isTrue,
      );
      expect(
        candidate.unrecognizedBlocks.any((b) => b.rawText.contains('Forgotten Mages')),
        isTrue,
      );
    });

    test('two objects run together without divider are separated into two candidates', () {
      const source = '''
### Fire Imp
Tiny fiend, lawful evil
Armor Class 13
Hit Points 10
Challenge 1

### Ice Imp
Tiny fiend, lawful evil
Armor Class 13
Hit Points 10
Challenge 1
''';
      final result = service.parse(source);
      expect(result.candidates.length, equals(2));
      expect(result.candidates[0].displayName, equals('Fire Imp'));
      expect(result.candidates[1].displayName, equals('Ice Imp'));
    });

    test('traditional-looking prose and non-entity text remains unassigned', () {
      const source = '''
The History of the Red Dragon Wyrmling:
Red dragons are the most covetous of the true dragons.
From the moment of hatching, they desire wealth above all else.
They sleep on piles of coin and dream of conquest.
''';
      final result = service.parse(source);
      expect(result.candidates, isEmpty);
      expect(result.unassignedBlocks, isNotEmpty);
      expect(result.unassignedBlocks.first.rawText, contains('History of the Red Dragon'));
    });

    test('custom and homebrew terminology does not break parsing', () {
      const source = '''
### Psionic Mind-Flayer (Homebrew Variant)
Medium aberration (psionic-mutant), neutral evil
Armor Class 15 (mind barrier)
Hit Points 71 (13d8 + 13)
Speed 30 ft., hover 20 ft.
Challenge 7 (2,900 XP)
Actions
Tentacles. Melee Weapon Attack: +7 to hit, reach 5 ft., one creature.
''';
      final result = service.parse(source);
      expect(result.candidates.length, equals(1));
      final candidate = result.candidates.first;

      expect(candidate.displayName, contains('Psionic Mind-Flayer'));
      expect(candidate.fields['monsterType']?.value, contains('aberration'));
      expect(candidate.fields['armorClass']?.value, equals(15));
      expect(candidate.fields['hitPoints']?.value, equals(71));
      expect(candidate.fields['actionsMarkdown']?.value, contains('Tentacles'));
      expect(candidate.isReadyToCommit, isTrue);
    });
  });
}
