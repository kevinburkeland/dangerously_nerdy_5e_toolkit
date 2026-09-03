import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/interactive_spell_tile.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/features_traits_section.dart';

void main() {
  group('Feature Grant Combat Injection & CharacterSheetController Tests', () {
    late Character warlockWithAgonizing;
    late Character warlockWithoutAgonizing;
    late Spell eldritchBlast;

    setUp(() {
      eldritchBlast = const Spell(
        id: EntityId(slug: 'eldritch-blast', ruleset: RulesetVersion.v2024),
        name: 'Eldritch Blast',
        level: 0,
        school: 'evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action, triggerCondition: '1 Action'),
        duration: SpellDuration(type: DurationType.instantaneous, rawText: 'Instantaneous'),
        range: '120 ft',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Make a ranged spell attack against the target. On a hit, the target takes 1d10 force damage.',
        damageMath: [
          EvaluationMath(diceFormula: '1d10', damageType: DamageType.force),
        ],
        customProperties: {
          'isSpellAttack': true,
          'rollFormula': '1d10',
        },
      );

      warlockWithAgonizing = const Character(
        id: EntityId(slug: 'warlock-agonizing', ruleset: RulesetVersion.v2024),
        name: 'Malakor',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        backgroundRef: EntityReference<DomainEntity>(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
              selectedFeatureOptions: {
                'invocations': ['agonizing_blast'],
              },
            ),
          ],
        ),
        baseScores: AbilityScores(
          charisma: 16, // Modifier +3
          constitution: 14,
          dexterity: 12,
        ),
        feats: [
          EntityReference<DomainEntity>(
            refType: EntityType.feat,
            slug: 'alert',
            displayName: 'Alert',
          ),
        ],
      );

      warlockWithoutAgonizing = const Character(
        id: EntityId(slug: 'warlock-plain', ruleset: RulesetVersion.v2024),
        name: 'Novice Warlock',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
              selectedFeatureOptions: {},
            ),
          ],
        ),
        baseScores: AbilityScores(
          charisma: 16, // Modifier +3
        ),
      );
    });

    test('Evaluates capability flags accurately from selected feature options', () {
      final ctrlWith = CharacterSheetController(character: warlockWithAgonizing);
      final ctrlWithout = CharacterSheetController(character: warlockWithoutAgonizing);

      expect(ctrlWith.hasCapabilityFlag('eldritchBlastChaDamage'), isTrue);
      expect(ctrlWithout.hasCapabilityFlag('eldritchBlastChaDamage'), isFalse);
      expect(ctrlWith.hasCapabilityFlag('non_existent_flag'), isFalse);
    });

    test('Injects Charisma modifier into Eldritch Blast damage roll when Agonizing Blast is active', () {
      final ctrlWith = CharacterSheetController(character: warlockWithAgonizing);
      final ctrlWithout = CharacterSheetController(character: warlockWithoutAgonizing);

      // Level 2 Warlock with Cha 16 (+3 mod) & Agonizing Blast: 1d10 + 3
      final rollWith = ctrlWith.rollSpellDamage(eldritchBlast);
      expect(rollWith.formulaString, equals('1d10 + 3'));
      expect(rollWith.total, inInclusiveRange(4, 13));

      // Level 2 Warlock without Agonizing Blast: 1d10
      final rollWithout = ctrlWithout.rollSpellDamage(eldritchBlast);
      expect(rollWithout.formulaString, equals('1d10'));
      expect(rollWithout.total, inInclusiveRange(1, 10));
    });

    test('Calculates spell attack roll using character evaluated spellAttackBonus', () {
      final ctrlWith = CharacterSheetController(character: warlockWithAgonizing);
      // Level 2 (prof +2) + Cha 16 (+3) = +5 spell attack bonus
      expect(ctrlWith.stats.spellAttackBonus, equals(5));

      final atkRoll = ctrlWith.rollSpellAttack(eldritchBlast);
      expect(atkRoll.formulaString, equals('1d20 + 5'));
      expect(atkRoll.total, inInclusiveRange(6, 25));
    });
  });

  group('InteractiveSpellTile Widget Tests', () {
    late Character warlock;
    late CharacterSheetController controller;
    late Spell eldritchBlast;

    setUp(() {
      eldritchBlast = const Spell(
        id: EntityId(slug: 'eldritch-blast', ruleset: RulesetVersion.v2024),
        name: 'Eldritch Blast',
        level: 0,
        school: 'evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action, triggerCondition: '1 Action'),
        duration: SpellDuration(type: DurationType.instantaneous, rawText: 'Instantaneous'),
        range: '120 ft',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'A beam of crackling energy streaks toward a creature within range.',
        damageMath: [
          EvaluationMath(diceFormula: '1d10', damageType: DamageType.force),
        ],
        customProperties: {
          'isSpellAttack': true,
          'rollFormula': '1d10',
        },
      );

      warlock = const Character(
        id: EntityId(slug: 'warlock-hero', ruleset: RulesetVersion.v2024),
        name: 'Malakor',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
              selectedFeatureOptions: {
                'invocations': ['agonizing_blast'],
              },
            ),
          ],
        ),
        baseScores: AbilityScores(
          charisma: 16,
        ),
      );

      controller = CharacterSheetController(character: warlock);
    });

    testWidgets('Renders spell title, +Atk bonus, formula with Cha bonus, and minimum touch target size', (tester) async {
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

      expect(find.text('Eldritch Blast'), findsOneWidget);
      expect(find.textContaining('+5 Atk'), findsOneWidget);
      expect(find.textContaining('1d10 + 3'), findsOneWidget);
      expect(find.text('ROLL'), findsOneWidget);

      // Verify minimum touch target for the reference modal button
      final infoFinder = find.byTooltip('Spell Details');
      expect(infoFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(infoFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Tapping spell tile executes attack and damage rolls, displaying SnackBar', (tester) async {
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

      // Tap on the tile to execute spell roll
      await tester.tap(find.text('Eldritch Blast'));
      await tester.pump();

      // Expect a SnackBar showing Attack and Damage results
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Eldritch Blast: Attack'), findsOneWidget);
      expect(find.textContaining('Damage'), findsOneWidget);
    });

    testWidgets('Tapping details info button opens modal bottom sheet with semantics header and description', (tester) async {
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

      // Tap info icon button
      await tester.tap(find.byTooltip('Spell Details'));
      await tester.pumpAndSettle();

      // Check modal bottom sheet contents
      expect(find.text('Eldritch Blast'), findsAtLeastNWidgets(1));
      expect(find.text('Cantrip • EVOCATION'), findsOneWidget);
      expect(find.text('1 Action'), findsOneWidget);
      expect(find.text('120 ft'), findsOneWidget);
      expect(find.text('Instantaneous'), findsOneWidget);
      expect(find.textContaining('A beam of crackling energy'), findsOneWidget);

      // Check action button in modal
      final actionButtonFinder = find.text('Roll Eldritch Blast');
      expect(actionButtonFinder, findsOneWidget);

      // Tap roll button from inside the modal sheet
      await tester.tap(actionButtonFinder);
      await tester.pumpAndSettle();

      // Verify modal dismissed and SnackBar shown
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('FeaturesTraitsSection Widget Tests', () {
    late Character character;
    late CharacterSheetController controller;

    setUp(() {
      character = const Character(
        id: EntityId(slug: 'warlock-traits', ruleset: RulesetVersion.v2024),
        name: 'Malakor',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        backgroundRef: EntityReference<DomainEntity>(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        ),
        resources: CharacterResourcePool(),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
              selectedFeatureOptions: {
                'invocations': ['agonizing_blast'],
              },
            ),
          ],
        ),
        baseScores: AbilityScores(charisma: 16),
        feats: [
          EntityReference<DomainEntity>(
            refType: EntityType.feat,
            slug: 'alert',
            displayName: 'Alert',
          ),
        ],
      );

      controller = CharacterSheetController(character: character);
    });

    testWidgets('Renders all feature categories with 48x48 touch targets and opens detail modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeaturesTraitsSection(controller: controller),
            ),
          ),
        ),
      );

      // Verify identity chips
      expect(find.text('Elf Traits'), findsOneWidget);
      expect(find.text('Acolyte'), findsOneWidget);

      // Verify class features and selected options
      expect(find.text('Warlock Features (Lvl 2)'), findsOneWidget);
      expect(find.text('Agonizing Blast'), findsOneWidget);

      // Verify feat
      expect(find.text('Alert'), findsOneWidget);

      // Tap on Agonizing Blast chip to open reference modal
      await tester.tap(find.text('Agonizing Blast'));
      await tester.pumpAndSettle();

      // Check modal bottom sheet header and contents
      expect(find.text('Agonizing Blast'), findsAtLeastNWidgets(2));
      expect(find.textContaining('add your Charisma modifier to the damage'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Tap on Alert feat chip
      await tester.tap(find.text('Alert'));
      await tester.pumpAndSettle();

      expect(find.text('Alert'), findsAtLeastNWidgets(2));
      expect(find.textContaining('Initiative'), findsAtLeastNWidgets(1));
    });

    testWidgets('Visual stress test: 2.0x Text Scale renders without RenderFlex overflow', (tester) async {
      final binding = tester.binding;
      binding.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(binding.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 700,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FeaturesTraitsSection(controller: controller),
                    InteractiveSpellTile(
                      spell: const Spell(
                        id: EntityId(slug: 'eldritch-blast', ruleset: RulesetVersion.v2024),
                        name: 'Eldritch Blast',
                        level: 0,
                        school: 'evocation',
                        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
                        duration: SpellDuration(type: DurationType.instantaneous),
                        range: '120 ft',
                        components: SpellComponents(v: true, s: true),
                        descriptionMarkdown: 'A beam of crackling energy.',
                        damageMath: [
                          EvaluationMath(diceFormula: '1d10', damageType: DamageType.force),
                        ],
                      ),
                      controller: controller,
                      isCantrip: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that no Flutter errors / overflow exceptions were thrown
      expect(tester.takeException(), isNull);
    });
  });
}
