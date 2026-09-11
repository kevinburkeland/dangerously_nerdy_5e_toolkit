import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_builder_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/background_step.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';

void main() {
  group('Character Builder & Level Up Search Widget Tests', () {
    testWidgets('BackgroundStep filters backgrounds by search query and restores on clear', (tester) async {
      final controller = CharacterBuilderController();
      String selectedBg = 'acolyte';

      const customBgs = [
        SrdBackgroundsLibrary.acolyte,
        Background(
          id: EntityId(slug: 'criminal', ruleset: RulesetVersion.v2024),
          name: 'Criminal',
          descriptionMarkdown: 'You have a history of breaking the law.',
          skillProficiencies: ['Deception', 'Stealth'],
        ),
        Background(
          id: EntityId(slug: 'soldier', ruleset: RulesetVersion.v2024),
          name: 'Soldier',
          descriptionMarkdown: 'War has been your life for as long as you care to remember.',
          skillProficiencies: ['Athletics', 'Intimidation'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: BackgroundStep(
                    controller: controller,
                    selectedBackground: selectedBg,
                    selectedRuleset: RulesetVersion.v2024,
                    customBackgrounds: customBgs,
                    onBackgroundSelected: (slug) {
                      setState(() => selectedBg = slug);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All default backgrounds should be rendered initially
      expect(find.text('Acolyte'), findsOneWidget);
      expect(find.text('Criminal'), findsOneWidget);
      expect(find.text('Soldier'), findsOneWidget);

      // Search for 'Criminal'
      final searchField = find.widgetWithText(TextField, 'Search Backgrounds');
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'criminal');
      await tester.pumpAndSettle();

      // Only Criminal should match
      expect(find.text('Criminal'), findsOneWidget);
      expect(find.text('Acolyte'), findsNothing);
      expect(find.text('Soldier'), findsNothing);

      // Tap clear icon button
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // All backgrounds should be restored
      expect(find.text('Acolyte'), findsOneWidget);
      expect(find.text('Criminal'), findsOneWidget);
      expect(find.text('Soldier'), findsOneWidget);
    });

    testWidgets('CharacterBuilderScreen filters Species step by search query and restores on clear', (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Guided Builder
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Advance from Step 1 (Basics) to Step 2 (Species)
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);

      // Verify multiple species exist
      expect(find.text('Human'), findsOneWidget);
      expect(find.text('Elf'), findsOneWidget);

      // Search for 'Dragonborn'
      final speciesSearch = find.widgetWithText(TextField, 'Search Species / Races');
      expect(speciesSearch, findsOneWidget);
      await tester.enterText(speciesSearch, 'dragonborn');
      await tester.pumpAndSettle();

      // Dragonborn should be found, Human should not be visible
      expect(find.text('Dragonborn'), findsOneWidget);
      expect(find.text('Human'), findsNothing);
      expect(find.text('Elf'), findsNothing);

      // Clear search
      final clearBtn = find.descendant(of: speciesSearch, matching: find.byIcon(Icons.clear));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Human and Elf are back
      expect(find.text('Human'), findsOneWidget);
      expect(find.text('Elf'), findsOneWidget);
    });

    testWidgets('LevelUpWizardDialog Step 4 filters Feats by search query and restores on clear', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const alertFeat = Feat(
        id: EntityId(slug: 'alert', ruleset: RulesetVersion.v2014),
        name: 'Alert',
        category: 'General',
        descriptionMarkdown: 'Always on the lookout for danger. +5 to initiative.',
      );
      SrdFeatsLibrary.addCustomFeat(alertFeat);
      addTearDown(() => SrdFeatsLibrary.removeCustomFeat('alert'));

      const char = Character(
        id: EntityId(slug: 'fighter-hero', ruleset: RulesetVersion.v2014),
        name: 'Fighter Hero',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16, constitution: 14),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2014,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => const LevelUpWizardDialog(character: char),
                  );
                },
                child: const Text('Open Wizard'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2 -> Step 3
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3 -> Step 4 (Fighter 4 has ASI / Feat)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Switch to Feat option
      await tester.tap(find.text('Choose Feat'));
      await tester.pumpAndSettle();

      // Feat search input must be visible
      final featSearch = find.widgetWithText(TextField, 'Search Feats');
      expect(featSearch, findsOneWidget);

      // Search for 'alert'
      await tester.enterText(featSearch, 'alert');
      await tester.pumpAndSettle();

      // Dropdown label should show matching count
      expect(find.textContaining('1 matching'), findsOneWidget);

      // Clear search
      final clearBtn = find.descendant(of: featSearch, matching: find.byIcon(Icons.clear));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Select Feat'), findsOneWidget);
    });

    testWidgets('LevelUpWizardDialog Step 5 Spells search filters and clears via suffix icon', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const wizardChar = Character(
        id: EntityId(slug: 'wizard-hero', ruleset: RulesetVersion.v2024),
        name: 'Wizard Hero',
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
        baseScores: AbilityScores(intelligence: 16, constitution: 14),
        resources: CharacterResourcePool(),
        rulesEdition: DmRulesEdition.v2024,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => const LevelUpWizardDialog(character: wizardChar),
                  );
                },
                child: const Text('Open Wizard'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Wizard'));
      await tester.pumpAndSettle();

      // Advance from Step 1 to Step 5 (Spells)
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Step 5 of 6: Spells & Invocations Management'), findsOneWidget);

      // Step 4 (Spells)
      final spellSearch = find.widgetWithText(TextField, 'Search Available Class Spells');
      expect(spellSearch, findsOneWidget);

      // Enter search query
      await tester.enterText(spellSearch, 'shield');
      await tester.pumpAndSettle();

      // Clear button should be present
      final clearBtn = find.descendant(of: spellSearch, matching: find.byIcon(Icons.clear));
      expect(clearBtn, findsOneWidget);

      // Tap clear
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Search query should be cleared
      expect(find.descendant(of: spellSearch, matching: find.byIcon(Icons.clear)), findsNothing);
    });
  });
}
