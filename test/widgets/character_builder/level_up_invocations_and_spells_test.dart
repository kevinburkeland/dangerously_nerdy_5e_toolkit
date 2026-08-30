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
  });
}
