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
  });
}
