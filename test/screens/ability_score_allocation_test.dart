import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> advanceToAbilityScores(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      if (find.textContaining('Ability Score Allocation').evaluate().isNotEmpty) {
        break;
      }
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
    }
  }

  group('Character Builder Ability Score Generation & Lineage Bonus Tests', () {
    testWidgets('supports switching to Dice Roll mode and rolling stats', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Advance to Ability Scores step
      await advanceToAbilityScores(tester);

      expect(find.textContaining('Ability Score Allocation'), findsOneWidget);

      // Tap 'Dice Roll' segment
      await tester.tap(find.text('Dice Roll'));
      await tester.pumpAndSettle();

      expect(find.text('Dice Rolling Method'), findsOneWidget);
      expect(find.text('Roll / Re-roll Dice'), findsOneWidget);

      // Roll stats
      await tester.tap(find.text('Roll / Re-roll Dice'));
      await tester.pumpAndSettle();

      expect(find.textContaining('FINAL STARTING ATTRIBUTES PREVIEW'), findsOneWidget);
    });

    testWidgets('supports Enter Own manual score input', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Advance to Ability Scores step
      await advanceToAbilityScores(tester);

      // Tap 'Enter Own' segment
      await tester.tap(find.text('Enter Own'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your own custom attributes (3 to 30):'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
      expect(find.byIcon(Icons.remove_circle_outline), findsWidgets);
    });

    testWidgets('Variant Human in 2014 mode shows +1 to two scores selection chips', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Switch ruleset to 2014
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Select Variant Human
      await tester.tap(find.text('Human (Variant)'));
      await tester.pumpAndSettle();

      // Advance to Ability Scores
      await advanceToAbilityScores(tester);

      expect(find.text('Human (Variant) Lineage Bonus (+1 to 2 Scores)'), findsOneWidget);
      expect(find.text('STRENGTH (+1 Bonus)'), findsOneWidget);
      expect(find.text('DEXTERITY (+1 Bonus)'), findsOneWidget);
      expect(find.text('CONSTITUTION (+1 Bonus)'), findsOneWidget);
      expect(find.text('INTELLIGENCE (+1 Bonus)'), findsOneWidget);
      expect(find.text('WISDOM (+1 Bonus)'), findsOneWidget);
      expect(find.text('CHARISMA (+1 Bonus)'), findsOneWidget);

      // Select WISDOM chip
      await tester.tap(find.text('WISDOM (+1 Bonus)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('FINAL STARTING ATTRIBUTES PREVIEW'), findsOneWidget);
    });

    testWidgets('Custom Lineage in 2014 mode grants +2 to chosen score and includes bonus feat step', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Switch ruleset to 2014
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Select Custom Lineage
      await tester.tap(find.text('Custom Lineage'));
      await tester.pumpAndSettle();

      // Advance to Ability Scores
      await advanceToAbilityScores(tester);

      // Should show Custom Lineage Bonus (+2 to 1 Score)
      expect(find.text('Custom Lineage Lineage Bonus (+2 to 1 Score)'), findsOneWidget);
      expect(find.text('STRENGTH (+2 Bonus)'), findsOneWidget);
      expect(find.text('CHARISMA (+2 Bonus)'), findsOneWidget);

      // Select CHARISMA (+2 Bonus)
      await tester.tap(find.text('CHARISMA (+2 Bonus)'));
      await tester.pumpAndSettle();

      // Allocate ability score pool
      await tester.tap(find.text('Auto-Assign'));
      await tester.pumpAndSettle();

      // Advance to Custom Lineage Bonus Feat step
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Custom Lineage Bonus Feat'), findsOneWidget);
      expect(find.textContaining('As a Custom Lineage, choose your 1st-level bonus feat'), findsOneWidget);
    });

    testWidgets('Dynamic Homebrew race with flexible ability bonus choices and bonus feat pipeline', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Register a homebrew race
      final homebrewRace = Race(
        id: const EntityId(slug: 'homebrew-astral-elf', ruleset: RulesetVersion.v2014),
        name: 'Astral Elf (Homebrew)',
        size: 'Medium',
        speed: '30 ft.',
        abilityScoreSummary: '+1 to Three Scores, 1 Bonus Feat',
        traitsMarkdown: 'Astral step and radiant starlight.',
        customProperties: const {
          'abilityChoiceCount': 3,
          'abilityChoiceBonus': 1,
          'bonusFeatCount': 1,
        },
      );
      await HomebrewPersistenceService().saveCustomRace(homebrewRace);
      addTearDown(() => HomebrewPersistenceService().deleteCustomRace('homebrew-astral-elf'));

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Switch to 2014 ruleset
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (Species)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Select homebrew race
      await tester.tap(find.text('Astral Elf (Homebrew)'));
      await tester.pumpAndSettle();

      // Advance to Ability Scores
      await advanceToAbilityScores(tester);

      expect(find.text('Astral Elf (Homebrew) Lineage Bonus (+1 to 3 Scores)'), findsOneWidget);
      expect(find.text('Select 3 different ability scores to receive a +1 bonus:'), findsOneWidget);

      // Select 3 chips: STR, DEX, INT
      await tester.tap(find.text('STRENGTH (+1 Bonus)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEXTERITY (+1 Bonus)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('INTELLIGENCE (+1 Bonus)'));
      await tester.pumpAndSettle();

      // Allocate ability score pool
      await tester.tap(find.text('Auto-Assign'));
      await tester.pumpAndSettle();

      // Advance to Feats step
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Astral Elf (Homebrew) Bonus Feat'), findsOneWidget);
      expect(find.textContaining('As a Astral Elf (Homebrew), choose your 1st-level bonus feat'), findsOneWidget);
    });
  });
}
