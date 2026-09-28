import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/source_block_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/field_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_monster_descriptor.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_monster_field_extractor.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_spell_descriptor.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_spell_field_extractor.dart';

void main() {
  group('FieldExtractor Tests', () {
    const parser = SourceBlockParser();
    const monsterDesc = Dnd5eMonsterDescriptor();
    const spellDesc = Dnd5eSpellDescriptor();
    const monsterExtractor = Dnd5eMonsterFieldExtractor();
    const spellExtractor = Dnd5eSpellFieldExtractor();

    test('missing required values remain missing and are never fabricated', () {
      const source = '''
### Incomplete Monster
Medium beast, unaligned
Armor Class 13
Speed 30 ft.
Challenge 1
''';
      final doc = parser.parse(source);
      final result = monsterExtractor.extract(
        blocks: doc.blocks,
        descriptor: monsterDesc,
      );

      final hpField = result.fields['hitPoints'];
      expect(hpField, isNotNull);
      expect(hpField!.state, equals(IngestionFieldState.missing));
      expect(hpField.value, isNull);
      expect(hpField.isRequired, isTrue);

      // Verify that AC is extracted cleanly
      final acField = result.fields['armorClass'];
      expect(acField, isNotNull);
      expect(acField!.state, equals(IngestionFieldState.extracted));
      expect(acField.value, equals(13));
    });

    test('malformed values become invalid rather than disappearing', () {
      const source = '''
### Bizarre Golem
Large construct, unaligned
Armor Class lots
Hit Points 80
Challenge 3
''';
      final doc = parser.parse(source);
      final result = monsterExtractor.extract(
        blocks: doc.blocks,
        descriptor: monsterDesc,
      );

      final acField = result.fields['armorClass'];
      expect(acField, isNotNull);
      expect(acField!.state, equals(IngestionFieldState.invalid));
      expect(acField.validationError, contains('lots'));
      expect(acField.rawText, contains('lots'));
    });

    test('ambiguous values like "CR ?" track ambiguous state with options', () {
      const source = '''
### Mysterious Phantom
Medium undead, chaotic neutral
Armor Class 12
Hit Points 35
Challenge ?
''';
      final doc = parser.parse(source);
      final result = monsterExtractor.extract(
        blocks: doc.blocks,
        descriptor: monsterDesc,
      );

      final crField = result.fields['challengeRating'];
      expect(crField, isNotNull);
      expect(crField!.state, equals(IngestionFieldState.ambiguous));
      expect(crField.ambiguousOptions, isNotEmpty);
    });

    test('unrecognized blocks are preserved and not silently discarded', () {
      const source = '''
### Forest Stalker
Medium humanoid, neutral
Armor Class 14
Hit Points 22
Challenge 1/2
Unusual note: This creature was first spotted in the Whispering Caverns.
''';
      final doc = parser.parse(source);
      final result = monsterExtractor.extract(
        blocks: doc.blocks,
        descriptor: monsterDesc,
      );

      expect(result.unrecognizedBlocks, isNotEmpty);
      expect(
        result.unrecognizedBlocks.any((b) => b.rawText.contains('Whispering Caverns')),
        isTrue,
      );
    });

    test('spell extraction maps level, school, components, and description', () {
      const source = '''
### Mystic Arrow
1st-level evocation
Casting Time: 1 action
Range: 90 feet
Components: V, S, M (a feather from an owl)
Duration: Instantaneous
You shoot a shimmering arrow of green force toward a creature within range.
### At Higher Levels
When you cast this spell using a spell slot of 2nd level or higher, damage increases by 1d8.
''';
      final doc = parser.parse(source);
      final result = spellExtractor.extract(
        blocks: doc.blocks,
        descriptor: spellDesc,
      );

      expect(result.fields['name']?.value, equals('Mystic Arrow'));
      expect(result.fields['level']?.value, equals(1));
      expect(result.fields['school']?.value, equals('Evocation'));
      expect(result.fields['castingTime']?.value, equals('1 action'));
      expect(result.fields['range']?.value, equals('90 feet'));
      expect(result.fields['components']?.value, contains('owl'));
      expect(result.fields['duration']?.value, equals('Instantaneous'));
      expect(result.fields['descriptionMarkdown']?.value, contains('shimmering arrow'));
      expect(result.fields['higherLevelsMarkdown']?.value, contains('1d8'));
    });

    test('traceability spans are populated on extracted fields', () {
      const source = '''
### Dire Boar
Large beast, unaligned
Armor Class 14
Hit Points 42
Challenge 2
''';
      final doc = parser.parse(source);
      final result = monsterExtractor.extract(
        blocks: doc.blocks,
        descriptor: monsterDesc,
      );

      final acField = result.fields['armorClass'];
      expect(acField?.span, isNotNull);
      expect(acField?.span?.startLine, equals(3));
      expect(acField?.span?.text, contains('Armor Class 14'));
    });
  });
}
