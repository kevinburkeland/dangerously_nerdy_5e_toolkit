import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_sheet_tabs.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/interactive_spell_tile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Agonizing Blast & Rod of the Pact Keeper on Spells Page', () {
    testWidgets('InteractiveSpellTile displays +3 Cha damage for spell-eldritch-blast slug and boosted attack with Rod', (tester) async {
      // Create warlock with Rod of the Pact Keeper +1 equipped & attuned, and Agonizing Blast invocation
      const rodItem = InventoryItemInstance(
        instanceId: 'rod-pact-1',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'item-rod-of-the-pact-keeper-plus-1',
          displayName: 'Rod of the Pact Keeper +1',
        ),
        isEquipped: true,
        isAttuned: true,
        requiresAttunement: true,
      );

      const warlock = Character(
        id: EntityId(slug: 'warlock-agonizing-rod', ruleset: RulesetVersion.v2024),
        name: 'Warlock Master',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              level: 3, // Prof bonus = +2
              hitDie: 'd8',
              isStartingClass: true,
              selectedFeatureOptions: {
                'invocations': ['agonizing_blast'],
              },
            ),
          ],
        ),
        baseScores: AbilityScores(
          charisma: 16, // +3 mod
          dexterity: 14,
          constitution: 14,
        ),
        inventory: [rodItem],
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: warlock);

      // Spell entity matching the catalog format: slug has 'spell-eldritch-blast'
      const eldritchBlast = Spell(
        id: EntityId(slug: 'spell-eldritch-blast', ruleset: RulesetVersion.v2024),
        name: 'Eldritch Blast',
        level: 0,
        school: 'evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action, triggerCondition: '1 Action'),
        duration: SpellDuration(type: DurationType.instantaneous, rawText: 'Instantaneous'),
        range: '120 ft',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'A beam of crackling energy.',
        damageMath: [
          EvaluationMath(diceFormula: '1d10', damageType: DamageType.force),
        ],
        customProperties: {
          'isSpellAttack': true,
          'rollFormula': '1d10',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveSpellTile(
              spell: eldritchBlast,
              controller: controller,
              isCantrip: true,
            ),
          ),
        ),
      );

      // Attack bonus should be: prof (+2) + Cha (+3) + Rod (+1) = +6 Atk
      expect(find.text('Eldritch Blast'), findsOneWidget);
      expect(find.textContaining('+6 Atk'), findsOneWidget);
      // Damage should show 1d10 + 3 Force
      expect(find.textContaining('1d10 + 3 Force'), findsOneWidget);

      // Controller rollSpellDamage should also include +3
      final damageRoll = controller.rollSpellDamage(eldritchBlast);
      expect(damageRoll.formulaString, equals('1d10 + 3'));
      expect(damageRoll.total, inInclusiveRange(4, 13));
    });
  });

  group('Actions Tab Full Rework & Action Economy Tests', () {
    test('CharacterActionsResolver resolves actions, bonus actions, reactions, and magic items', () {
      const rodItem = InventoryItemInstance(
        instanceId: 'rod-pact-1',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'item-rod-of-the-pact-keeper-plus-1',
          displayName: 'Rod of the Pact Keeper +1',
        ),
        isEquipped: true,
        isAttuned: true,
        requiresAttunement: true,
      );

      const dagger = InventoryItemInstance(
        instanceId: 'dagger-1',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'dagger',
          displayName: 'Dagger',
        ),
        equippedSlot: EquipmentSlot.mainHand,
        isEquipped: true,
        customProperties: {
          'isWeapon': true,
          'damageFormula': '1d4',
          'damageType': 'piercing',
        },
      );

      const offhandDagger = InventoryItemInstance(
        instanceId: 'dagger-2',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'dagger',
          displayName: 'Offhand Dagger',
        ),
        equippedSlot: EquipmentSlot.offHand,
        isEquipped: true,
        customProperties: {
          'isWeapon': true,
          'damageFormula': '1d4',
          'damageType': 'piercing',
          'properties': ['light'],
        },
      );

      const rogueWarlock = Character(
        id: EntityId(slug: 'rogue-warlock', ruleset: RulesetVersion.v2024),
        name: 'Shadow Caster',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'rogue', displayName: 'Rogue'),
              level: 2, // Grants Cunning Action
              hitDie: 'd8',
              isStartingClass: true,
            ),
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              level: 3,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 16, // +3
          charisma: 16, // +3
          constitution: 12,
        ),
        inventory: [rodItem, dagger, offhandDagger],
        cantrips: [
          EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'spell_eldritch_blast',
            displayName: 'Eldritch Blast',
          ),
        ],
        spellsPrepared: [
          EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'spell_misty_step',
            displayName: 'Misty Step',
          ),
          EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'spell_hellish_rebuke',
            displayName: 'Hellish Rebuke',
          ),
        ],
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: rogueWarlock);
      final stats = CharacterEvaluationEngine.evaluate(rogueWarlock);
      final resolved = CharacterActionsResolver.resolve(
        character: rogueWarlock,
        stats: stats,
        controller: controller,
      );

      // Standard Actions & Attacks
      final mainActionNames = resolved.actions.map((a) => a.name).toList();
      expect(mainActionNames, contains('Dagger'));
      expect(mainActionNames, contains('Eldritch Blast'));

      // Standard Actions
      final stdActionNames = resolved.standardActions.map((a) => a.name).toList();
      expect(stdActionNames, contains('Dash'));
      expect(stdActionNames, contains('Dodge'));

      // Bonus Actions
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();
      expect(bonusActionNames, contains('Off-Hand Two-Weapon Attack'));
      expect(bonusActionNames, contains('Cunning Action'));
      expect(bonusActionNames, contains('Misty Step'));

      // Reactions
      final reactionNames = resolved.reactions.map((a) => a.name).toList();
      expect(reactionNames, contains('Opportunity Attack'));
      expect(reactionNames, contains('Hellish Rebuke'));

      // Special & Magic Items
      final specialActionNames = resolved.specialActions.map((a) => a.name).toList();
      expect(specialActionNames.any((n) => n.contains('Pact Keeper')), isTrue);
    });

    testWidgets('Actions tab UI renders Round Economy quick tracker, Filter Chips, and organized sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const warlock = Character(
        id: EntityId(slug: 'warlock-test', ruleset: RulesetVersion.v2024),
        name: 'Action Hero',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'warlock', displayName: 'Warlock'),
              level: 3,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(charisma: 16, dexterity: 14),
        inventory: [
          InventoryItemInstance(
            instanceId: 'rod-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'item-rod-of-the-pact-keeper-plus-1',
              displayName: 'Rod of the Pact Keeper +1',
            ),
            isEquipped: true,
            isAttuned: true,
            requiresAttunement: true,
          ),
        ],
        cantrips: [
          EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'spell_eldritch_blast',
            displayName: 'Eldritch Blast',
          ),
        ],
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: warlock);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterSheetTabs(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Round Economy Tracker
      expect(find.text('ROUND ECONOMY'), findsOneWidget);
      expect(find.text('Reset Turn'), findsOneWidget);
      expect(find.text('Ready'), findsNWidgets(3));

      // Verify Filter ChoiceChips exist
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Bonus Actions ('), findsOneWidget);
      expect(find.textContaining('Reactions ('), findsOneWidget);
      final specialChip = find.textContaining('Special (');
      expect(specialChip, findsOneWidget);

      // Tap on the Special filter chip to see the Magic Item action
      await tester.tap(specialChip);
      await tester.pumpAndSettle();

      // Verify Magic Item action for Rod of the Pact Keeper is shown
      expect(find.textContaining('Pact Keeper'), findsAtLeastNWidgets(1));

      // Tap on the Action economy chip to mark Action as spent
      final actionTracker = find.text('Action');
      expect(actionTracker, findsAtLeastNWidgets(1));
      await tester.tap(actionTracker.first);
      await tester.pumpAndSettle();

      // Now 1 is Spent and 2 are Ready
      expect(find.text('Spent'), findsOneWidget);
      expect(find.text('Ready'), findsNWidgets(2));

      // Tap 'Reset Turn' button to restore economy
      final resetBtn = find.text('Reset Turn');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // All 3 should be Ready again
      expect(find.text('Ready'), findsNWidgets(3));
      expect(find.text('Spent'), findsNothing);
    });
  });
}

