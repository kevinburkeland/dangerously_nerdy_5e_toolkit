import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_header_banner.dart';

void main() {
  group('LevelUpWizardDialog & Sheet Integration Widget Tests', () {
    late Character testFighter;

    setUp(() {
      testFighter = const Character(
        id: EntityId(slug: 'hero-1', ruleset: RulesetVersion.v2024),
        name: 'Galahad',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 1,
            hitDie: 'd10',
            isStartingClass: true,
          ),
        ]),
        baseScores: AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        resources: CharacterResourcePool(
          currentHp: 12,
          currentHitDice: {'d10': 1},
        ),
      );
    });

    testWidgets('Header banner contains Level Up button and launches Wizard dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = CharacterSheetController(character: testFighter);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterHeaderBanner(controller: controller),
          ),
        ),
      );

      expect(find.text('Galahad'), findsOneWidget);
      expect(find.text('Level 1'), findsOneWidget);
      expect(find.byKey(const Key('character_sheet_level_up_button')), findsOneWidget);

      // Tap level up button
      await tester.tap(find.byKey(const Key('character_sheet_level_up_button')));
      await tester.pumpAndSettle();

      // Wizard dialog should be open
      expect(find.textContaining('Level Up Hero: Galahad'), findsOneWidget);
      expect(find.text('Step 1 of 6: Target Class & Multiclass Rules'), findsOneWidget);
    });

    testWidgets('Wizard steps navigation and confirmation updates character level', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Character? upgradedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  LevelUpWizardDialog.show(
                    context,
                    character: testFighter,
                    onLevelUpApplied: (upgraded) {
                      upgradedResult = upgraded;
                    },
                  );
                },
                child: const Text('Open Wizard'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 6: Target Class & Multiclass Rules'), findsOneWidget);

      // Advance through Steps 1 to 5
      for (int i = 0; i < 5; i++) {
        final nextBtn = find.text('Next Step');
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        await tester.pumpAndSettle();
      }

      // Step 6: Review & Final Confirmation
      expect(find.text('Step 6 of 6: Review & Final Confirmation'), findsOneWidget);
      expect(find.text('CONFIRM LEVEL UP'), findsOneWidget);

      // Tap Confirm Level Up
      await tester.tap(find.text('CONFIRM LEVEL UP'));
      await tester.pumpAndSettle();

      // Verify upgraded character
      expect(upgradedResult, isNotNull);
      expect(upgradedResult!.totalLevel, equals(2));
      expect(upgradedResult!.resources.currentHitDice['d10'], equals(2));
      expect(upgradedResult!.resources.currentHp, equals(20)); // 12 base + 8 (6 avg + 2 con)
    });

    testWidgets('Level 4: Choosing Feat Resilient prompts for ability chips and applies save proficiency', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final level3Fighter = testFighter.copyWith(
        progression: const CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
              refType: EntityType.classDefinition,
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 3,
            hitDie: 'd10',
            isStartingClass: true,
          ),
        ]),
        resources: testFighter.resources.copyWith(
          currentHitDice: {'d10': 3},
          currentHp: 28,
        ),
      );

      Character? upgradedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  LevelUpWizardDialog.show(
                    context,
                    character: level3Fighter,
                    onLevelUpApplied: (upgraded) {
                      upgradedResult = upgraded;
                    },
                  );
                },
                child: const Text('Open Wizard'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Advance Steps 1, 2, 3 to reach Step 4 (ASI / Feat)
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Step 4 of 6: Ability Score Improvement or Feat
      expect(find.text('Step 4 of 6: Ability Score Improvement or Feat'), findsOneWidget);

      // Select "Choose Feat"
      await tester.tap(find.text('Choose Feat'));
      await tester.pumpAndSettle();

      // Open feat dropdown
      final featDropdown = find.byType(DropdownButtonFormField<String>);
      expect(featDropdown, findsOneWidget);
      await tester.tap(featDropdown);
      await tester.pumpAndSettle();

      // Select "Resilient"
      await tester.tap(find.text('Resilient').last);
      await tester.pumpAndSettle();

      // Verify choice chips for abilities are rendered
      expect(find.byKey(const Key('feat_ability_chip_constitution')), findsOneWidget);
      expect(find.byKey(const Key('feat_ability_chip_wisdom')), findsOneWidget);

      // Tap CON choice chip
      await tester.tap(find.byKey(const Key('feat_ability_chip_constitution')));
      await tester.pumpAndSettle();

      // Check saving throw proficiency indicator
      expect(find.text('Grants Proficiency: CON Saving Throws'), findsOneWidget);

      // Advance Step 4 to 5 (Spells) and 5 to 6 (Review)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // In Review:
      expect(find.text('Step 6 of 6: Review & Final Confirmation'), findsOneWidget);
      expect(find.text('+1 CON'), findsOneWidget);
      expect(find.text('CON Save Proficiency'), findsOneWidget);

      // Confirm Level Up
      await tester.tap(find.text('CONFIRM LEVEL UP'));
      await tester.pumpAndSettle();

      expect(upgradedResult, isNotNull);
      expect(upgradedResult!.totalLevel, equals(4));
      expect(upgradedResult!.bonusScores.constitution, equals(1));
      expect(upgradedResult!.savingThrowProficiencies, contains(AbilityType.constitution));
      expect(upgradedResult!.feats.any((f) => f.slug == 'resilient'), isTrue);
    });
  });
}
