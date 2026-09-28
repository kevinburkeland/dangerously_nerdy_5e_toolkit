import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/document_structure_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/source_block_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/services/ingestion_workbench_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';

void main() {
  late DocumentStructureParser structureParser;
  late IngestionWorkbenchService workbenchService;

  setUp(() {
    structureParser = const DocumentStructureParser();
    workbenchService = IngestionWorkbenchService(
      capability: const Dnd5eIngestionCapability(),
    );
  });

  group('Hierarchical Document Decomposition: Full Class Document', () {
    const fullClassDoc = '''# Fighter
Hit Die: d10
Saving Throws: Strength, Constitution
Armor: All armor, shields
Weapons: Simple weapons, martial weapons

| Level | Proficiency Bonus | Features |
| 1st | +2 | Second Wind |
| 2nd | +2 | Action Surge (one use) |
| 3rd | +2 | Martial Archetype |

## Second Wind
You have a limited well of stamina that you can draw on to protect yourself from harm. On your turn, you can use a bonus action to regain hit points equal to 1d10 + your fighter level. Once you use this feature, you must finish a short or long rest before you can use it again.

## Action Surge
Starting at 2nd level, you can push yourself beyond your normal limits for a moment. On your turn, you can take one additional action. Once you use this feature, you must finish a short or long rest before you can use it again.

## Champion
Fighter Subclass

### Improved Critical
Beginning when you choose this archetype at 3rd level, your weapon attacks score a critical hit on a roll of 19 or 20.

### Remarkable Athlete
Starting at 7th level, you can add half your proficiency bonus (round up) to any Strength, Dexterity, or Constitution check you make that doesn't already use your proficiency bonus.
''';

    test('parses hierarchical sections with correct containment and source spans', () {
      final sourceDoc = const SourceBlockParser().parse(fullClassDoc);
      final sections = structureParser.parseSections(sourceDoc);

      expect(sections.length, 1);
      final classSection = sections.first;
      expect(classSection.headingText, 'Fighter');
      expect(classSection.headingLevel, 1);
      expect(classSection.children.length, greaterThanOrEqualTo(3));

      // Second Wind, Action Surge, Champion
      final childHeadings = classSection.children.map((c) => c.headingText).toList();
      expect(childHeadings, contains('Second Wind'));
      expect(childHeadings, contains('Action Surge'));
      expect(childHeadings, contains('Champion'));

      // Champion subclass section has its own children
      final championSection = classSection.children.firstWhere(
        (c) => c.headingText == 'Champion',
      );
      expect(championSection.children.length, 2);
      expect(
        championSection.children.map((c) => c.headingText).toList(),
        ['Improved Critical', 'Remarkable Athlete'],
      );

      // Verify source spans are nested and non-empty
      expect(classSection.span.startOffset, 0);
      expect(classSection.span.endOffset, greaterThanOrEqualTo(fullClassDoc.trim().length));
      expect(championSection.span.startOffset, greaterThan(0));
      expect(championSection.span.endOffset, lessThanOrEqualTo(fullClassDoc.length));

      for (final subFeature in championSection.children) {
        expect(subFeature.span.startOffset, greaterThanOrEqualTo(championSection.span.startOffset));
        expect(subFeature.span.endOffset, lessThanOrEqualTo(championSection.span.endOffset));
      }
    });

    test('decomposes document into Class candidate, Subclass candidate, and structured subcomponents', () {
      final docResult = workbenchService.parse(fullClassDoc);

      // Should identify 2 domain candidates: 1 Class, 1 Subclass
      expect(docResult.candidates.length, 2);

      final classCandidate = docResult.candidates.firstWhere(
        (c) => c.targetTypeKey == 'class',
      );
      final subclassCandidate = docResult.candidates.firstWhere(
        (c) => c.targetTypeKey == 'subclass',
      );

      expect(classCandidate.name, 'Fighter');
      expect(subclassCandidate.name, 'Champion');
      expect(subclassCandidate.parentCandidateId, classCandidate.id);
      expect(classCandidate.childCandidateIds, contains(subclassCandidate.id));

      // Inspect sections inside document result
      final rootSection = docResult.sections.first;
      expect(rootSection.classification, 'class');

      // Verify classification of subcomponents
      final featureSections = rootSection.children
          .where((c) => c.classification == 'classFeature')
          .map((c) => c.headingText)
          .toList();
      expect(featureSections, contains('Second Wind'));
      expect(featureSections, contains('Action Surge'));

      final championSection = rootSection.children.firstWhere(
        (c) => c.headingText == 'Champion',
      );
      expect(championSection.classification, 'subclass');
      expect(
        championSection.children.map((c) => c.classification).toSet(),
        {'subclassFeature'},
      );
    });

    test('converts into existing CharacterClass and Subclass domain models without feature DomainEntity', () {
      final docResult = workbenchService.parse(fullClassDoc);
      final classCandidate = docResult.candidates.firstWhere(
        (c) => c.targetTypeKey == 'class',
      );

      final conversionResult = workbenchService.convertToDomainEntity(classCandidate);
      expect(conversionResult.isSuccess, isTrue);

      final characterClass = conversionResult.entity as CharacterClass;
      expect(characterClass.name, 'Fighter');
      expect(characterClass.hitDie.toString(), contains('10'));
      expect(characterClass.savingThrows, contains('Strength'));
      expect(characterClass.savingThrows, contains('Constitution'));

      // Class features are composed into featuresMarkdown
      expect(characterClass.featuresMarkdown, contains('Second Wind'));
      expect(characterClass.featuresMarkdown, contains('Action Surge'));

      // Subclass is converted into CharacterClass.subclasses
      expect(characterClass.subclasses.length, 1);
      final subclass = characterClass.subclasses.first;
      expect(subclass.name, 'Champion');
      expect(subclass.classSlug, 'fighter');

      // Subclass features are composed into Subclass.featuresMarkdown
      expect(subclass.featuresMarkdown, contains('Improved Critical'));
      expect(subclass.featuresMarkdown, contains('Remarkable Athlete'));
    });
  });

  group('Feature Ownership & Isolation (No Leakage)', () {
    const multiSubclassDoc = '''# Rogue
Hit Die: d8
Saving Throws: Dexterity, Intelligence

## Sneak Attack
Beginning at 1st level, you know how to strike subtly.

## Cunning Action
Starting at 2nd level, your quick thinking allows you to move and act quickly.

## Thief
Rogue Subclass

### Fast Hands
Starting at 3rd level, you can use the bonus action granted by your Cunning Action.

### Second-Story Work
When you choose this archetype at 3rd level, you gain the ability to climb faster.

## Assassin
Rogue Subclass

### Assassinate
Starting at 3rd level, you are at your deadliest when you get the drop on your enemies.
''';

    test('multi-subclass document associates each feature with its respective parent', () {
      final docResult = workbenchService.parse(multiSubclassDoc);

      // Should have 1 Class (Rogue) and 2 Subclasses (Thief, Assassin)
      expect(docResult.candidates.length, 3);
      final rogue = docResult.candidates.firstWhere((c) => c.targetTypeKey == 'class');
      final thief = docResult.candidates.firstWhere((c) => c.name == 'Thief');
      final assassin = docResult.candidates.firstWhere((c) => c.name == 'Assassin');

      expect(rogue.childCandidateIds, containsAll([thief.id, assassin.id]));
      expect(thief.parentCandidateId, rogue.id);
      expect(assassin.parentCandidateId, rogue.id);

      final commitResult = workbenchService.convertToDomainEntity(rogue);
      expect(commitResult.isSuccess, isTrue);

      final characterClass = commitResult.entity as CharacterClass;
      expect(characterClass.subclasses.length, 2);

      final cThief = characterClass.subclasses.firstWhere((s) => s.name == 'Thief');
      final cAssassin = characterClass.subclasses.firstWhere((s) => s.name == 'Assassin');

      // Assert Feature Ownership Isolation:
      // 1. Rogue features in class featuresMarkdown
      expect(characterClass.featuresMarkdown, contains('Sneak Attack'));
      expect(characterClass.featuresMarkdown, contains('Cunning Action'));
      // 2. Class features MUST NOT leak into Thief or Assassin
      expect(cThief.featuresMarkdown, isNot(contains('Sneak Attack')));
      expect(cAssassin.featuresMarkdown, isNot(contains('Sneak Attack')));
      // 3. Thief features in Thief only
      expect(cThief.featuresMarkdown, contains('Fast Hands'));
      expect(cThief.featuresMarkdown, contains('Second-Story Work'));
      expect(characterClass.featuresMarkdown, isNot(contains('Fast Hands')));
      expect(cAssassin.featuresMarkdown, isNot(contains('Fast Hands')));
      // 4. Assassin features in Assassin only
      expect(cAssassin.featuresMarkdown, contains('Assassinate'));
      expect(characterClass.featuresMarkdown, isNot(contains('Assassinate')));
      expect(cThief.featuresMarkdown, isNot(contains('Assassinate')));
    });
  });

  group('Unrecognized Content & Ambiguity Preservation', () {
    const docWithUnknownSection = '''# Fighter
Hit Die: d10
Saving Throws: Strength, Constitution

## Second Wind
You can use a bonus action to regain hit points.

## Experimental Momentum Rules
This is a homebrew momentum tracking rule that does not follow standard class features.
Whenever a fighter dashes, gain 1 Momentum point.

## Champion
Fighter Subclass

### Improved Critical
Crit on 19 or 20.
''';

    test('preserves unrecognized child sections without silently dropping or swallowing them', () {
      final docResult = workbenchService.parse(docWithUnknownSection);

      final rootSection = docResult.sections.first;
      final momentumSection = rootSection.children.firstWhere(
        (c) => c.headingText == 'Experimental Momentum Rules',
      );

      // Section classification is unknown or descriptiveProse
      expect(
        ['unknown', 'descriptiveProse'].contains(momentumSection.classification),
        isTrue,
      );

      // Class candidate still parses successfully
      final classCandidate = docResult.candidates.firstWhere(
        (c) => c.targetTypeKey == 'class',
      );
      expect(classCandidate.name, 'Fighter');

      // Unrecognized block is tracked and visible in candidate unrecognizedBlocks
      expect(
        classCandidate.unrecognizedBlocks.any(
          (b) => b.rawText.contains('Experimental Momentum Rules'),
        ),
        isTrue,
      );
    });

    test('reclassifying an unknown section to classFeature integrates it into featuresMarkdown', () {
      final docResult = workbenchService.parse(docWithUnknownSection);

      final rootSection = docResult.sections.first;
      final momentumSection = rootSection.children.firstWhere(
        (c) => c.headingText == 'Experimental Momentum Rules',
      );

      // User reclassifies section to classFeature
      final updatedDoc = workbenchService.reclassifySection(
        docResult,
        momentumSection.id,
        'classFeature',
      );

      final classCandidate = updatedDoc.candidates.firstWhere(
        (c) => c.targetTypeKey == 'class',
      );
      final commitResult = workbenchService.convertToDomainEntity(classCandidate);
      expect(commitResult.isSuccess, isTrue);

      final characterClass = commitResult.entity as CharacterClass;
      expect(characterClass.featuresMarkdown, contains('Experimental Momentum Rules'));
      expect(characterClass.featuresMarkdown, contains('Momentum point'));
    });
  });

  group('Progression Tables Handling', () {
    const docWithProgressionTable = '''# Fighter
Hit Die: d10
Saving Throws: Strength, Constitution

| Level | PB | Maneuvers Known | Superiority Dice |
| 1st | +2 | 3 | 4d8 |
| 2nd | +2 | 3 | 4d8 |

## Second Wind
Regain HP.
''';

    test('detects progression table as structural section and stores table metadata', () {
      final docResult = workbenchService.parse(docWithProgressionTable);

      // Structure has progression table
      final rootSection = docResult.sections.first;
      final tableSection = rootSection.children.firstWhere(
        (c) => c.classification == 'progressionTable' || c.blocks.any((b) => b.type == SourceBlockType.table),
      );

      expect(tableSection, isNotNull);
      expect(tableSection.rawSource, contains('Superiority Dice'));

      final classCandidate = docResult.candidates.firstWhere(
        (c) => c.targetTypeKey == 'class',
      );
      final commitResult = workbenchService.convertToDomainEntity(classCandidate);
      expect(commitResult.isSuccess, isTrue);

      final characterClass = commitResult.entity as CharacterClass;
      // Progression table should be preserved in customProperties
      expect(
        characterClass.customProperties.containsKey('progressionTable') ||
            characterClass.featuresMarkdown.contains('Superiority Dice'),
        isTrue,
      );
    });
  });

  group('Simple Existing Types Non-Fragmentation', () {
    test('monster stat block remains a single candidate without needless fragmentation', () {
      const monsterSource = '''### Cave Goblin
Small humanoid (goblinoid), neutral evil
Armor Class 15 (leather armor, shield)
Hit Points 7 (2d6)
Speed 30 ft.
STR 8 (-1) DEX 14 (+2) CON 10 (+0) INT 10 (+0) WIS 8 (-1) CHA 8 (-1)
Challenge 1/4 (50 XP)

Nimble Escape. The goblin can take the Disengage or Hide action as a bonus action on each of its turns.

Actions
Scimitar. Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage.
''';

      final docResult = workbenchService.parse(monsterSource);
      expect(docResult.candidates.length, 1);
      expect(docResult.candidates.first.targetTypeKey, 'monster');
      expect(docResult.candidates.first.name, 'Cave Goblin');

      final commit = workbenchService.convertToDomainEntity(docResult.candidates.first);
      expect(commit.isSuccess, isTrue);
      expect(commit.entity, isA<Monster>());
    });

    test('spell card remains a single candidate', () {
      const spellSource = '''### Frost Whip
2nd-level evocation
Casting Time: 1 action
Range: 30 feet
Components: V, S
Duration: Instantaneous
You lash out with a whip of pure frost. The target takes 3d6 cold damage.
''';

      final docResult = workbenchService.parse(spellSource);
      expect(docResult.candidates.length, 1);
      expect(docResult.candidates.first.targetTypeKey, 'spell');

      final commit = workbenchService.convertToDomainEntity(docResult.candidates.first);
      expect(commit.isSuccess, isTrue);
      expect(commit.entity, isA<Spell>());
    });

    test('magic item card remains a single candidate', () {
      const itemSource = '''### Cloak of Mist
Wondrous item, uncommon (requires attunement)
While wearing this cloak, you can cast Misty Step once per long rest.
''';

      final docResult = workbenchService.parse(itemSource);
      expect(docResult.candidates.length, 1);
      expect(docResult.candidates.first.targetTypeKey, 'item');

      final commit = workbenchService.convertToDomainEntity(docResult.candidates.first);
      expect(commit.isSuccess, isTrue);
      expect(commit.entity, isA<EquipmentItem>());
    });
  });
}
