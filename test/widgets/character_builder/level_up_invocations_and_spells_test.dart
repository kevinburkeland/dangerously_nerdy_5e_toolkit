import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';

void main() {
  group('Level Up Invocations, Spells, and Patron Tests', () {
    test('SubclassSpellsLibrary identifies Warlock Fiend expanded spells', () {
      final burningHands = SpellbookLibrary.getSpellById('spell_burning_hands')!;
      final fireball = SpellbookLibrary.getSpellById('spell_fireball')!;
      final cureWounds = SpellbookLibrary.getSpellById('spell_cure_wounds')!;

      expect(SubclassSpellsLibrary.isExpandedSpell('warlock', 'fiend-patron', burningHands, DmRulesEdition.v2024), isTrue);
      expect(SubclassSpellsLibrary.isExpandedSpell('warlock', 'the_fiend', fireball, DmRulesEdition.v2024), isTrue);
      expect(SubclassSpellsLibrary.isExpandedSpell('warlock', 'the_fiend', cureWounds, DmRulesEdition.v2024), isFalse);
    });

    testWidgets('LevelUpWizardDialog shows Eldritch Invocations when leveling Warlock to Level 2', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final character = Character(
        id: const EntityId(slug: 'test-warlock', ruleset: RulesetVersion.v2024),
        name: 'Warlock Hero',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'soldier', displayName: 'Soldier'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 16,
        ),
        resources: const CharacterResourcePool(
          currentHp: 10,
          currentHitDice: {'d8': 1},
        ),
      );

      Character? leveledCharacter;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(
              character: character,
              onLevelUpApplied: (c) => leveledCharacter = c,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Class Selection (Already Warlock)
      expect(find.textContaining('Step 1 of 6'), findsOneWidget);
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Hit Points
      expect(find.textContaining('Step 2 of 6'), findsOneWidget);
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class Features & Specializations (Eldritch Invocations)
      expect(find.textContaining('Step 3 of 6'), findsOneWidget);
      expect(find.textContaining('Choose 2 Eldritch Invocations'), findsOneWidget);
      expect(find.text('Agonizing Blast'), findsOneWidget);

      // Select Agonizing Blast and Repelling Blast
      await tester.tap(find.text('Agonizing Blast'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Repelling Blast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repelling Blast'));
      await tester.pumpAndSettle();

      // Step 4: ASI / Feat (Level 2 has no ASI)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No ASI / Feat Milestone'), findsOneWidget);

      // Step 5: Spells
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step 5 of 6'), findsOneWidget);
      expect(find.textContaining('Max Spell Level: 1'), findsOneWidget);

      // Step 6: Review & Final Confirmation
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step 6 of 6'), findsOneWidget);

      // Confirm Level Up
      await tester.tap(find.text('CONFIRM LEVEL UP'));
      await tester.pumpAndSettle();

      expect(leveledCharacter, isNotNull);
      expect(leveledCharacter!.totalLevel, equals(2));
      final warlockProgression = leveledCharacter!.progression.classes.first;
      expect(warlockProgression.level, equals(2));
      expect(warlockProgression.selectedFeatureOptions['warlock-invocations-2'], contains('agonizing_blast'));
      expect(warlockProgression.selectedFeatureOptions['warlock-invocations-2'], contains('repelling_blast'));
    });

    testWidgets('LevelUpWizardDialog shows Fiend Patron expanded spells (Burning Hands, Command) in Spells step', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final character = Character(
        id: const EntityId(slug: 'test-fiend-warlock', ruleset: RulesetVersion.v2024),
        name: 'Fiend Warlock',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'sage', displayName: 'Sage'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'fiend-patron', displayName: 'The Fiend'),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 8, dexterity: 14, constitution: 14, intelligence: 12, wisdom: 10, charisma: 16),
        resources: const CharacterResourcePool(currentHp: 10, currentHitDice: {'d8': 1}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: character),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Step 5 (Spells)
      await tester.tap(find.text('Next Step')); // Step 2
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 3
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 4
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 5 (Spells)
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 5 of 6'), findsOneWidget);
      // Burning Hands and Command should be in the selectable spells list because Fiend patron grants them
      expect(find.textContaining('Burning Hands'), findsOneWidget);
      expect(find.textContaining('Command'), findsOneWidget);
    });

    testWidgets('LevelUpWizardDialog shows No Spellcasting Advancement for Barbarian', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final barbarian = Character(
        id: const EntityId(slug: 'test-barbarian', ruleset: RulesetVersion.v2024),
        name: 'Barbarian',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'orc', displayName: 'Orc'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'soldier', displayName: 'Soldier'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'barbarian', displayName: 'Barbarian'),
              level: 1,
              hitDie: 'd12',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 16, dexterity: 14, constitution: 16, intelligence: 8, wisdom: 10, charisma: 8),
        resources: const CharacterResourcePool(currentHp: 15, currentHitDice: {'d12': 1}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: barbarian),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to Step 5 (Spells)
      await tester.tap(find.text('Next Step')); // Step 2
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 3
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 4
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 5 (Spells)
      await tester.pumpAndSettle();

      expect(find.textContaining('No Spellcasting Advancement at Level 2'), findsOneWidget);
    });

    testWidgets('LevelUpWizardDialog shows Magical Secrets chip and spell list switcher for Bard leveling to 10', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bard = Character(
        id: const EntityId(slug: 'test-bard', ruleset: RulesetVersion.v2024),
        name: 'Elven Minstrel',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'entertainer', displayName: 'Entertainer'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'bard', displayName: 'Bard'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'college_of_lore', displayName: 'College of Lore'),
              level: 9,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 8, dexterity: 14, constitution: 12, intelligence: 12, wisdom: 12, charisma: 18),
        resources: const CharacterResourcePool(currentHp: 55, currentHitDice: {'d8': 9}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: bard),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Step 5 (Spells)
      await tester.tap(find.text('Next Step')); // Step 2 (HP)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 3 (Features)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 4 (ASI/Feat)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 5 (Spells)
      await tester.pumpAndSettle();

      expect(find.text('MAGICAL SECRETS'), findsOneWidget);
      expect(find.text('Bard List'), findsOneWidget);
      expect(find.text('Wizard'), findsOneWidget);
      expect(find.text('Cleric'), findsOneWidget);
      expect(find.text('Druid'), findsOneWidget);

      // Switch to Wizard list
      await tester.tap(find.text('Wizard'));
      await tester.pumpAndSettle();
    });

    testWidgets('LevelUpWizardDialog shows Mystic Arcanum banner for Warlock leveling to 11', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final warlock = Character(
        id: const EntityId(slug: 'test-warlock-10', ruleset: RulesetVersion.v2024),
        name: 'High Warlock',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'sage', displayName: 'Sage'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'the_fiend', displayName: 'The Fiend'),
              level: 10,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 8, dexterity: 14, constitution: 14, intelligence: 10, wisdom: 12, charisma: 18),
        resources: const CharacterResourcePool(currentHp: 65, currentHitDice: {'d8': 10}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: warlock),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Step 5 (Spells)
      await tester.tap(find.text('Next Step')); // Step 2 (HP)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 3 (Features)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 4 (ASI/Feat)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 5 (Spells)
      await tester.pumpAndSettle();

      expect(find.textContaining('Mystic Arcanum Milestone (Level 6 Spell)'), findsOneWidget);
    });

    testWidgets('LevelUpWizardDialog displays Subclass Granted Spells for Cleric', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final cleric = Character(
        id: const EntityId(slug: 'test-cleric', ruleset: RulesetVersion.v2024),
        name: 'Life Cleric',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'acolyte', displayName: 'Acolyte'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'cleric', displayName: 'Cleric'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'life_domain', displayName: 'Life Domain'),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 14, dexterity: 10, constitution: 14, intelligence: 10, wisdom: 16, charisma: 12),
        resources: const CharacterResourcePool(currentHp: 18, currentHitDice: {'d8': 2}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: cleric),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Step 5 (Spells)
      await tester.tap(find.text('Next Step')); // Step 2 (HP)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 3 (Features)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 4 (ASI/Feat)
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step')); // Step 5 (Spells)
      await tester.pumpAndSettle();

      expect(find.textContaining('Subclass Granted Spells (Always Prepared, Free Quota)'), findsOneWidget);
      expect(find.textContaining('Bless'), findsWidgets);
      expect(find.textContaining('Cure Wounds'), findsWidgets);
    });

    testWidgets('LevelUpWizardDialog shows Eldritch Invocations for 2014 Warlock leveling to Level 2', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final warlock2014 = Character(
        id: const EntityId(slug: 'test-warlock-2014', ruleset: RulesetVersion.v2014),
        name: 'Classic Warlock',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'sage', displayName: 'Sage'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'the_fiend', displayName: 'The Fiend'),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 8, dexterity: 14, constitution: 14, intelligence: 10, wisdom: 12, charisma: 16),
        resources: const CharacterResourcePool(currentHp: 10, currentHitDice: {'d8': 1}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: warlock2014),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3 (Features & Decisions)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Eldritch Invocations'), findsWidgets);
      expect(find.textContaining('Choose 2 Eldritch Invocations'), findsOneWidget);
      expect(find.text('Agonizing Blast'), findsOneWidget);
      expect(find.text('Armor of Shadows'), findsOneWidget);
    });

    testWidgets('LevelUpWizardDialog unlocks Spellcasting and Fighting Style for 2014 Paladin leveling to Level 2', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final paladin2014 = Character(
        id: const EntityId(slug: 'test-paladin-2014', ruleset: RulesetVersion.v2014),
        name: 'Classic Paladin',
        speciesRef: const EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        backgroundRef: const EntityReference(refType: EntityType.background, slug: 'noble', displayName: 'Noble'),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'paladin', displayName: 'Paladin'),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 16, dexterity: 10, constitution: 14, intelligence: 8, wisdom: 10, charisma: 16),
        resources: const CharacterResourcePool(currentHp: 12, currentHitDice: {'d10': 1}),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: paladin2014),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (HP)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3 (Features & Decisions)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify Fighting Style decision appears at Level 2 for 2014 Paladin
      expect(find.text('Fighting Style'), findsWidgets);
      expect(find.text('Defense'), findsOneWidget);

      // Select Defense style
      await tester.tap(find.text('Defense'));
      await tester.pumpAndSettle();

      // Step 3 -> Step 4 (ASI / Feats)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4 -> Step 5 (Spells)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify 2014 Paladin has Spellcasting Advancement at Level 2 (1st-level spells)
      expect(find.textContaining('No Spellcasting Advancement'), findsNothing);
      expect(find.text('Spells & Cantrips Advancement'), findsOneWidget);
      expect(find.textContaining('Available Leveled Spells (Up to Level 1)'), findsOneWidget);
      expect(find.textContaining('Bless (L1)'), findsOneWidget);
    });
  });
}



