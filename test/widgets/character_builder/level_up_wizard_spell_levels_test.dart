import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_comparison_dialog.dart';

void main() {
  group('LevelUpWizardDialog Spell Level Separation & Info Button Tests', () {
    testWidgets('Separates leveled spells into distinct sections by spell level (1st-Level, 2nd-Level)', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Level 2 Wizard leveling to Level 3 (unlocks 2nd-level spells)
      const wizard = Character(
        id: EntityId(slug: 'wizard-lvl-2', ruleset: RulesetVersion.v2024),
        name: 'Elminster Apprentice',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        backgroundRef: EntityReference(refType: EntityType.background, slug: 'sage', displayName: 'Sage'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'wizard', displayName: 'Wizard'),
              level: 2,
              hitDie: 'd6',
              isStartingClass: true,
            ),
          ],
        ),
        cantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_fire_bolt', displayName: 'Fire Bolt'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_mage_hand', displayName: 'Mage Hand'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_prestidigitation', displayName: 'Prestidigitation'),
        ],
        spellsPrepared: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_magic_missile', displayName: 'Magic Missile'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_shield', displayName: 'Shield'),
        ],
        baseScores: AbilityScores(strength: 8, dexterity: 14, constitution: 14, intelligence: 16, wisdom: 12, charisma: 10),
        resources: CharacterResourcePool(currentHp: 14, currentHitDice: {'d6': 2}),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: wizard),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance from Step 1 to Step 5 (Spells)
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Verify we are on Step 5
      expect(find.textContaining('Step 5 of 6: Spells & Invocations Management'), findsOneWidget);

      // Verify overall leveled spells header with max level
      expect(find.textContaining('Available Leveled Spells (Up to Level 2)'), findsOneWidget);

      // Verify distinct level groups exist
      expect(find.text('1st-Level Spells'), findsOneWidget);
      expect(find.text('2nd-Level Spells'), findsOneWidget);
      expect(find.text('LEVEL 1'), findsOneWidget);
      expect(find.text('LEVEL 2'), findsOneWidget);

      // Verify spell chips exist under their respective levels
      expect(find.textContaining('Burning Hands (L1)'), findsOneWidget);
      expect(find.textContaining('Misty Step (L2)'), findsOneWidget);
      expect(find.textContaining('Scorching Ray (L2)'), findsOneWidget);
    });

    testWidgets('Tapping spell info button opens SpellComparisonDialog without selecting spell', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const wizard = Character(
        id: EntityId(slug: 'wizard-lvl-2', ruleset: RulesetVersion.v2024),
        name: 'Elminster Apprentice',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'wizard', displayName: 'Wizard'),
              level: 2,
              hitDie: 'd6',
              isStartingClass: true,
            ),
          ],
        ),
        cantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_fire_bolt', displayName: 'Fire Bolt'),
        ],
        spellsPrepared: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_shield', displayName: 'Shield'),
        ],
        baseScores: AbilityScores(intelligence: 16),
        resources: CharacterResourcePool(currentHp: 14, currentHitDice: {'d6': 2}),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: wizard),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Quota for Level 3: 0/2 New Leveled Spell(s)'), findsOneWidget);

      // Find info button for Burning Hands
      final infoBtnFinder = find.byKey(const Key('spell_info_btn_spell_burning_hands'));
      await tester.ensureVisible(infoBtnFinder);
      expect(infoBtnFinder, findsOneWidget);

      // Tap info button
      await tester.tap(infoBtnFinder);
      await tester.pumpAndSettle();

      // Verify SpellComparisonDialog opened
      expect(find.byType(SpellComparisonDialog), findsOneWidget);
      expect(find.text('Burning Hands'), findsWidgets);

      // Close the modal dialog
      final closeBtnFinder = find.byTooltip('Close comparison dialog');
      expect(closeBtnFinder, findsOneWidget);
      await tester.tap(closeBtnFinder);
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.byType(SpellComparisonDialog), findsNothing);

      // Crucial: verify spell was NOT selected by tapping info button!
      expect(find.textContaining('Quota for Level 3: 0/2 New Leveled Spell(s)'), findsOneWidget);

      // Now tap the spell chip body to select Burning Hands
      await tester.ensureVisible(find.textContaining('Burning Hands (L1)').first);
      await tester.tap(find.textContaining('Burning Hands (L1)').first);
      await tester.pumpAndSettle();

      // Quota is now 1/2
      expect(find.textContaining('Quota for Level 3: 1/2 New Leveled Spell(s)'), findsOneWidget);
      // Level 1 header shows "1 selected"
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('Replaceable spell section displays info button for known spells', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const warlock = Character(
        id: EntityId(slug: 'warlock-test-swap', ruleset: RulesetVersion.v2024),
        name: 'Warlock Swapper',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        cantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_eldritch_blast', displayName: 'Eldritch Blast'),
        ],
        spellsKnown: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hellish_rebuke', displayName: 'Hellish Rebuke'),
        ],
        baseScores: AbilityScores(charisma: 16),
        resources: CharacterResourcePool(currentHp: 10, currentHitDice: {'d8': 1}),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(character: warlock),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Verify replaceable spell info button
      final infoBtnFinder = find.byKey(const Key('replaceable_spell_info_spell_hellish_rebuke'));
      expect(infoBtnFinder, findsOneWidget);

      await tester.tap(infoBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SpellComparisonDialog), findsOneWidget);
      expect(find.text('Hellish Rebuke'), findsWidgets);

      await tester.tap(find.byTooltip('Close comparison dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(SpellComparisonDialog), findsNothing);
    });
  });
}
