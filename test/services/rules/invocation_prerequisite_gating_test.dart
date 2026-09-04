import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';

void main() {
  group('Eldritch Invocation & Feature Prerequisite Tests', () {
    test('Correctly extracts prerequisites from SRD descriptionMarkdown regex', () {
      // Level only
      const oneWithShadows = FeatureOption(
        id: 'one_with_shadows',
        name: 'One with Shadows',
        descriptionMarkdown:
            'Prerequisite: 5th level. When you are in an area of dim light or darkness...',
      );
      final prereqLvl = oneWithShadows.prerequisite;
      expect(prereqLvl.minLevel, equals(5));
      expect(prereqLvl.requiredPact, isNull);
      expect(prereqLvl.requiredSpell, isNull);

      // Spell only
      const agonizingBlast = FeatureOption(
        id: 'agonizing_blast',
        name: 'Agonizing Blast',
        descriptionMarkdown:
            'Prerequisite: Eldritch Blast cantrip. When you cast Eldritch Blast, add your Charisma modifier...',
      );
      final prereqSpell = agonizingBlast.prerequisite;
      expect(prereqSpell.minLevel, isNull);
      expect(prereqSpell.requiredSpell, equals('eldritch blast'));
      expect(prereqSpell.requiredPact, isNull);

      // Pact only
      const bookOfSecrets = FeatureOption(
        id: 'book_of_ancient_secrets',
        name: 'Book of Ancient Secrets',
        descriptionMarkdown:
            'Prerequisite: Pact of the Tome feature. You can now inscribe magical rituals in your Book of Shadows...',
      );
      final prereqPact = bookOfSecrets.prerequisite;
      expect(prereqPact.minLevel, isNull);
      expect(prereqPact.requiredPact, equals('tome'));

      // Level + Pact (Blade)
      const thirstingBlade = FeatureOption(
        id: 'thirsting_blade',
        name: 'Thirsting Blade',
        descriptionMarkdown:
            'Prerequisite: 5th level, Pact of the Blade feature. You can attack with your pact weapon twice...',
      );
      final prereqBlade = thirstingBlade.prerequisite;
      expect(prereqBlade.minLevel, equals(5));
      expect(prereqBlade.requiredPact, equals('blade'));

      // Level 12 + Pact (Blade)
      const lifedrinker = FeatureOption(
        id: 'lifedrinker',
        name: 'Lifedrinker',
        descriptionMarkdown:
            'Prerequisite: 12th level, Pact of the Blade feature. When you hit a creature with your pact weapon...',
      );
      expect(lifedrinker.prerequisite.minLevel, equals(12));
      expect(lifedrinker.prerequisite.requiredPact, equals('blade'));

      // Level 12 + Pact of the Talisman
      const bondOfTalisman = FeatureOption(
        id: 'bond_of_the_talisman',
        name: 'Bond of the Talisman',
        descriptionMarkdown:
            'Prerequisite: 12th level, Pact of the Talisman. You can teleport to the wearer of your talisman...',
      );
      expect(bondOfTalisman.prerequisite.minLevel, equals(12));
      expect(bondOfTalisman.prerequisite.requiredPact, equals('talisman'));
    });

    test('Correctly extracts prerequisites from 5etools structured JSON customProperties', () {
      const jsonEntry = FeatureOption(
        id: 'bond-of-the-talisman',
        name: 'Bond of the Talisman',
        descriptionMarkdown: 'Teleport to talisman wearer.',
        customProperties: {
          'prerequisite': [
            {
              'level': {'level': 12, 'class': {'name': 'Warlock'}},
              'pact': 'Talisman',
            }
          ]
        },
      );
      final prereq = jsonEntry.prerequisite;
      expect(prereq.minLevel, equals(12));
      expect(prereq.requiredPact, equals('talisman'));

      const jsonSpellEntry = FeatureOption(
        id: 'lance-of-lethargy',
        name: 'Lance of Lethargy',
        descriptionMarkdown: 'Slow target with blast.',
        customProperties: {
          'prerequisite': [
            {'spell': ['eldritch blast#c']}
          ]
        },
      );
      expect(jsonSpellEntry.prerequisite.requiredSpell, equals('eldritch blast'));
    });

    test('FeaturePrerequisite.evaluate correctly evaluates level, pact, and spell requirements', () {
      const agonizingBlast = FeatureOption(
        id: 'agonizing_blast',
        name: 'Agonizing Blast',
        descriptionMarkdown: 'Prerequisite: Eldritch Blast cantrip.',
      );
      const thirstingBlade = FeatureOption(
        id: 'thirsting_blade',
        name: 'Thirsting Blade',
        descriptionMarkdown: 'Prerequisite: 5th level, Pact of the Blade feature.',
      );
      const lifedrinker = FeatureOption(
        id: 'lifedrinker',
        name: 'Lifedrinker',
        descriptionMarkdown: 'Prerequisite: 12th level, Pact of the Blade feature.',
      );
      const bookOfSecrets = FeatureOption(
        id: 'book_of_ancient_secrets',
        name: 'Book of Ancient Secrets',
        descriptionMarkdown: 'Prerequisite: Pact of the Tome feature.',
      );

      // Case 1: Level 2 Warlock with NO eldritch blast and NO pact
      final evalAgonizing1 = agonizingBlast.prerequisite.evaluate(
        classLevel: 2,
        selectedPacts: {},
        knownSpellSlugs: {'chill-touch', 'prestidigitation'},
      );
      expect(evalAgonizing1.isMet, isFalse);
      expect(evalAgonizing1.unmetReasons.first, contains('Requires Eldritch Blast'));

      final evalThirsting1 = thirstingBlade.prerequisite.evaluate(
        classLevel: 2,
        selectedPacts: {},
        knownSpellSlugs: {'eldritch-blast'},
      );
      expect(evalThirsting1.isMet, isFalse);
      expect(evalThirsting1.unmetReasons, contains('Requires Level 5 (Current: 2)'));
      expect(evalThirsting1.unmetReasons, contains('Requires Pact of the Blade'));

      // Case 2: Level 5 Warlock with Eldritch Blast and Pact of the Blade
      final evalAgonizing2 = agonizingBlast.prerequisite.evaluate(
        classLevel: 5,
        selectedPacts: {'blade'},
        knownSpellSlugs: {'eldritch-blast'},
      );
      expect(evalAgonizing2.isMet, isTrue);

      final evalThirsting2 = thirstingBlade.prerequisite.evaluate(
        classLevel: 5,
        selectedPacts: {'pact_of_the_blade'},
        knownSpellSlugs: {'eldritch-blast'},
      );
      expect(evalThirsting2.isMet, isTrue);

      // Lifedrinker requires level 12
      final evalLifedrinker2 = lifedrinker.prerequisite.evaluate(
        classLevel: 5,
        selectedPacts: {'blade'},
      );
      expect(evalLifedrinker2.isMet, isFalse);
      expect(evalLifedrinker2.unmetReasons, contains('Requires Level 12 (Current: 5)'));

      // Book of Secrets requires Tome
      final evalBook2 = bookOfSecrets.prerequisite.evaluate(
        classLevel: 5,
        selectedPacts: {'blade'},
      );
      expect(evalBook2.isMet, isFalse);
      expect(evalBook2.unmetReasons, contains('Requires Pact of the Tome'));

      // Case 3: Level 12 Warlock with Pact of the Blade
      final evalLifedrinker3 = lifedrinker.prerequisite.evaluate(
        classLevel: 12,
        selectedPacts: {'blade'},
      );
      expect(evalLifedrinker3.isMet, isTrue);
    });

    test('Pact Boons and Invocations are separated in SrdFeatureOptions', () {
      final invocations = SrdFeatureOptions.warlockInvocations;
      final pactBoons = SrdFeatureOptions.warlockPactBoons;

      // Invocations must NOT contain pact boons
      expect(invocations.any((i) => i.id == 'pact_of_the_blade'), isFalse);
      expect(invocations.any((i) => i.id == 'pact_of_the_tome'), isFalse);
      expect(invocations.any((i) => i.id == 'pact_of_the_chain'), isFalse);
      expect(invocations.any((i) => i.id == 'pact_of_the_talisman'), isFalse);

      // Pact Boons must contain all 4 pacts
      final pactIds = pactBoons.map((p) => p.id).toSet();
      expect(pactIds.contains('pact_of_the_blade'), isTrue);
      expect(pactIds.contains('pact_of_the_chain'), isTrue);
      expect(pactIds.contains('pact_of_the_tome'), isTrue);
      expect(pactIds.contains('pact_of_the_talisman'), isTrue);
    });

    test('2014 Warlock progression strictly separates Invocations (Lvl 2) and Pact Boon (Lvl 3)', () {
      final warlock = SrdClassesLibrary.warlock;

      // Level 2 decisions for 2014 ruleset
      final lvl2Decisions = warlock.getDecisionsForLevel(2, ruleset: RulesetVersion.v2014);
      expect(lvl2Decisions.length, equals(1));
      final lvl2Invocations = lvl2Decisions.first;
      expect(lvl2Invocations.type, equals(FeatureChoiceType.invocations));
      expect(lvl2Invocations.availableOptions.any((o) => o.id.startsWith('pact_of_the_')), isFalse);

      // Level 3 decisions for 2014 ruleset
      final lvl3Decisions = warlock.getDecisionsForLevel(3, ruleset: RulesetVersion.v2014);
      final pactBoonDecision = lvl3Decisions.firstWhere((d) => d.type == FeatureChoiceType.pactBoon);
      expect(pactBoonDecision.levelRequired, equals(3));
      final pactIds = pactBoonDecision.availableOptions.map((o) => o.id).toSet();
      expect(pactIds, containsAll(['pact_of_the_blade', 'pact_of_the_chain', 'pact_of_the_tome', 'pact_of_the_talisman']));
    });
  });

  group('LevelUpWizardDialog Gating Widget Tests', () {
    testWidgets('Gated invocations display lock indicator and are non-selectable', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Create a Level 1 Warlock leveling up to Level 2 without Eldritch Blast
      const character = Character(
        id: EntityId(slug: 'test-warlock', ruleset: RulesetVersion.v2014),
        name: 'Test Warlock',
        speciesRef: EntityReference(slug: 'human', displayName: 'Human', refType: EntityType.species),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(slug: 'warlock', displayName: 'Warlock', refType: EntityType.classDefinition),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 10, dexterity: 14, constitution: 14, intelligence: 10, wisdom: 12, charisma: 16),
        cantrips: [
          EntityReference<Spell>(slug: 'chill-touch', displayName: 'Chill Touch', refType: EntityType.spell),
        ],
        resources: CharacterResourcePool(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => LevelUpWizardDialog(
                      character: character,
                      onLevelUpApplied: (_) {},
                    ),
                  );
                },
                child: const Text('Open Wizard'),
              ),
            ),
          ),
        ),
      );

      // Open wizard
      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Step 1: Target Class -> Tap Next Step
      expect(find.text('Step 1 of 6: Target Class & Multiclass Rules'), findsOneWidget);
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: HP -> Tap Next Step
      expect(find.text('Step 2 of 6: Hit Points & Hit Die Scaling'), findsOneWidget);
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class Features & Subclass Archetype (Level 2 Warlock decisions)
      expect(find.text('Step 3 of 6: Class Features & Subclass Archetype'), findsOneWidget);
      expect(find.text('Eldritch Invocations'), findsWidgets);

      // Verify that Pact of the Blade is NOT shown as an invocation choice
      expect(find.text('Pact of the Blade'), findsNothing);
      expect(find.text('Pact of the Tome'), findsNothing);
      expect(find.text('Pact of the Talisman'), findsNothing);

      // Verify One with Shadows is shown as gated (requires Level 5, character is Level 2)
      expect(find.text('One with Shadows'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);

      // Tapping a gated invocation should trigger warning snackbar and NOT select it
      await tester.ensureVisible(find.text('One with Shadows'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('One with Shadows'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cannot select One with Shadows: Requires Level 5'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Agonizing blast requires Eldritch Blast, which this character does not have
      await tester.ensureVisible(find.text('Agonizing Blast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agonizing Blast'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cannot select Agonizing Blast: Requires Eldritch Blast'), findsOneWidget);

      // An ungated invocation like Armor of Shadows CAN be selected
      await tester.ensureVisible(find.text('Armor of Shadows'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Armor of Shadows'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected: 1 / 2'), findsOneWidget);
    });
  });
}
