import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';

void main() {
  group('CharacterBuilderScreen Dynamic Steps Widget Tests', () {
    testWidgets('Wizard renders dynamic Class Decisions step for Fighter', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Guided Builder tab (Tab index 1)
      final guidedTabFinder = find.text('Guided Builder');
      expect(guidedTabFinder, findsOneWidget);
      await tester.tap(guidedTabFinder);
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Human -> Next Step
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Fighter -> Next Step
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Fighter (').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4: Class Decisions step (Fighting Style) should be injected dynamically
      expect(find.text('Fighter Decisions & Specializations'), findsOneWidget);
      expect(find.text('Fighting Style'), findsWidgets);
      expect(find.text('Archery'), findsOneWidget);
      expect(find.text('Defense'), findsOneWidget);

      // Select Defense
      await tester.tap(find.text('Defense'));
      await tester.pumpAndSettle();

      // Next Step advances to Background
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      expect(find.text('Step 4: Choose Background Origin'), findsOneWidget);
    });

    testWidgets('Wizard caps cantrips and leveled spells to class quotas', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Human -> Next Step
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Wizard
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Wizard (').last);
      await tester.pumpAndSettle();

      // Advance through Class Decisions, Background, Ability Scores, Equipment until Spells
      while (!tester.any(find.textContaining('Spells & Cantrips'))) {
        if (tester.any(find.text('Soldier'))) {
          await tester.tap(find.text('Soldier'));
          await tester.pumpAndSettle();
        }
        if (tester.any(find.text('Auto-Assign'))) {
          await tester.tap(find.text('Auto-Assign'));
          await tester.pumpAndSettle();
        }
        await tester.drag(find.byType(ListView), const Offset(0, -800));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Verify spell quota headers: 3 Cantrips, 6 Spellbook Spells for Wizard
      expect(find.textContaining('/ 3 selected'), findsOneWidget);
      expect(find.textContaining('/ 6 selected'), findsOneWidget);
      expect(find.textContaining('A Level 1 Wizard must choose exactly 6 1st-level spells'), findsOneWidget);

      // Scroll up to ensure top action is visible
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();

      // Auto-fill recommended spells selects exactly 3 cantrips and 6 spells
      await tester.tap(find.text('Select Recommended Spells'));
      await tester.pumpAndSettle();

      expect(find.text('3 / 3 selected'), findsOneWidget);
      expect(find.text('6 / 6 selected'), findsOneWidget);
    });

    testWidgets('Wizard detects skill collision with background and offers compensatory picks', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterBuilderScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Human -> Next Step
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Fighter -> Next Step
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Fighter (').last);
      await tester.pumpAndSettle();

      // Deselect Acrobatics and select Athletics to test collision with Soldier
      await tester.tap(find.widgetWithText(FilterChip, 'Acrobatics').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Athletics').first);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step: Class Decisions -> Select Defense -> Next Step
      if (find.text('Defense').evaluate().isNotEmpty) {
        await tester.tap(find.text('Defense'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Step 4: Background -> Select Soldier (grants Athletics & Intimidation)
      expect(find.text('Step 4: Choose Background Origin'), findsOneWidget);
      await tester.tap(find.text('Soldier'));
      await tester.pumpAndSettle();

      // Navigate back to Class step to observe skill collision
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();
      if (find.text('Fighter Decisions & Specializations').evaluate().isNotEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Previous'));
        await tester.pumpAndSettle();
      }

      // Fighter has Athletics selected by default and Soldier also grants Athletics
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
      expect(find.textContaining('Skill Collision Detected: Athletics'), findsOneWidget);
      expect(find.textContaining('Compensatory Pick(s):'), findsOneWidget);
    });

    testWidgets('Attributes First preset under 2014 rules does not default attributes to 20', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(
          rulesEdition: DmRulesEdition.v2014,
          wizardOrderingPreset: WizardOrderingPreset.attributesFirst,
        ),
      );

      await tester.pumpWidget(
        SettingsScope(
          notifier: settingsProvider,
          child: const MaterialApp(
            home: CharacterBuilderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Ensure 2014 ruleset is selected on Basics step
      final rulesetSelector = find.text('2014 SRD (5.1 Classic)');
      if (rulesetSelector.evaluate().isNotEmpty) {
        await tester.tap(rulesetSelector);
        await tester.pumpAndSettle();
      }

      // Step 1: Basics -> Next Step (advances to Step 2: Ability Score Allocation under attributesFirst)
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Verify we are now on Ability Score Allocation
      expect(find.textContaining('Ability Score Allocation'), findsOneWidget);

      // Verify that NO stat displays 20 or a +10 bonus when species is not chosen yet
      expect(find.textContaining('+10 bonus'), findsNothing);
      expect(find.text('20'), findsNothing);

      // Tap Auto-Assign standard array: stats must be 15, 14, 13, 12, 10, 8 (not 25, 24, 23, 22, 20, 18)
      await tester.tap(find.text('Auto-Assign'));
      await tester.pumpAndSettle();

      expect(find.text('15'), findsWidgets);
      expect(find.text('14'), findsWidgets);
      expect(find.text('13'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      expect(find.text('10'), findsWidgets);
      expect(find.text('8'), findsWidgets);

      // Crucially, verify that 25 or 20 was NOT calculated as a final score
      expect(find.text('25'), findsNothing);
      expect(find.text('24'), findsNothing);
      expect(find.text('23'), findsNothing);
      expect(find.text('22'), findsNothing);
    });

    testWidgets('Attributes First preset under 2014 rules prompts for racial skills and flexible attributes on species step (Variant Human)', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(
          rulesEdition: DmRulesEdition.v2014,
          wizardOrderingPreset: WizardOrderingPreset.attributesFirst,
        ),
      );

      await tester.pumpWidget(
        SettingsScope(
          notifier: settingsProvider,
          child: const MaterialApp(
            home: CharacterBuilderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Ability Score Allocation -> Auto-assign -> Next Step
      await tester.tap(find.text('Auto-Assign'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Fighter -> Next Step
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Fighter (').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Class Decisions -> Select Defense -> Next Step
      if (find.text('Defense').evaluate().isNotEmpty) {
        await tester.tap(find.text('Defense'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Step: Species selection -> Select Human (Variant)
      expect(find.textContaining('Choose Species'), findsOneWidget);
      await tester.tap(find.text('Human (Variant)'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Verify that Species Bonus Skills prompt is now visible!
      expect(find.textContaining('Species Bonus Skills (Human (Variant)):'), findsOneWidget);
      expect(find.textContaining('skill proficiency choice'), findsOneWidget);

      // Verify that Lineage Ability Choices prompt is visible!
      expect(find.textContaining('Human (Variant) Lineage Ability Choices (+1):'), findsOneWidget);

      // Verify that Racial Attribute Modifiers and Resulting Attributes summary is visible!
      expect(find.textContaining('Racial Attribute Modifiers (Human (Variant)):'), findsOneWidget);
      expect(find.textContaining('Base Scores + Racial Bonuses = Resulting Attributes:'), findsOneWidget);

      // Tap an eligible skill chip in species bonus skills (e.g. Stealth)
      final stealthChipFinder = find.widgetWithText(FilterChip, 'Stealth');
      expect(stealthChipFinder, findsOneWidget);
      await tester.tap(stealthChipFinder);
      await tester.pumpAndSettle();

      expect(find.text('1 / 1 selected'), findsOneWidget);

      // Tap flexible ability choice chips (e.g. DEX +1 and WIS +1)
      final dexChipFinder = find.widgetWithText(FilterChip, 'DEXTERITY (+1 Bonus)');
      expect(dexChipFinder, findsOneWidget);
      await tester.tap(dexChipFinder);
      await tester.pumpAndSettle();

      // Verify updated resulting attributes reflect DEX +1
      expect(find.textContaining('DEX: 15 (+2) [+1]'), findsOneWidget);
    });

    testWidgets('Attributes First preset under 2014 rules with Custom Lineage grants +2 to only ONE attribute instead of two', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(
          rulesEdition: DmRulesEdition.v2014,
          wizardOrderingPreset: WizardOrderingPreset.attributesFirst,
        ),
      );

      await tester.pumpWidget(
        SettingsScope(
          notifier: settingsProvider,
          child: const MaterialApp(
            home: CharacterBuilderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Ability Scores -> Auto-assign (15 STR, 14 DEX, 13 CON, 12 INT, 10 WIS, 8 CHA) -> Next Step
      await tester.tap(find.text('Auto-Assign'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Fighter -> Next Step
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Fighter (').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      if (find.text('Defense').evaluate().isNotEmpty) {
        await tester.tap(find.text('Defense'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Step: Species -> Select Custom Lineage
      await tester.tap(find.text('Custom Lineage'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Verify prompt for Custom Lineage flexible ability choice (+2 to 1 score)
      expect(find.textContaining('Custom Lineage Lineage Ability Choices (+2):'), findsOneWidget);
      expect(find.textContaining('1 / 1 selected'), findsOneWidget);

      // Verify only ONE score received +2:
      // STR (15 + 2 = 17), other scores have +0 bonus
      expect(find.text('Racial Attribute Modifiers (Custom Lineage): +2 STR'), findsOneWidget);
      expect(find.textContaining('STR: 17 (+3) [+2]'), findsOneWidget);
      // DEX is base 14 without bonus
      expect(find.textContaining('DEX: 14 (+2)'), findsOneWidget);
      expect(find.textContaining('[+2]'), findsOneWidget); // Only ONE score has [+2]

      // Now switch +2 to DEX
      final dexChip = find.widgetWithText(FilterChip, 'DEXTERITY (+2 Bonus)');
      expect(dexChip, findsOneWidget);
      await tester.tap(dexChip);
      await tester.pumpAndSettle();

      // Verify only DEX now has +2 (DEX: 14 + 2 = 16), STR has no bonus (STR: 15)
      expect(find.text('Racial Attribute Modifiers (Custom Lineage): +2 DEX'), findsOneWidget);
      expect(find.textContaining('DEX: 16 (+3) [+2]'), findsOneWidget);
      expect(find.textContaining('STR: 15 (+2)'), findsOneWidget);
      expect(find.text('Racial Attribute Modifiers (Custom Lineage): +2 STR'), findsNothing);
      expect(find.textContaining('STR: 17'), findsNothing);
    });

    testWidgets('Attributes First preset under 2024 rules prompts for 2024 Human Skillful racial bonus skill', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settingsProvider = SettingsProvider(
        initialSettings: const AppSettings(
          rulesEdition: DmRulesEdition.v2024,
          wizardOrderingPreset: WizardOrderingPreset.attributesFirst,
        ),
      );

      await tester.pumpWidget(
        SettingsScope(
          notifier: settingsProvider,
          child: const MaterialApp(
            home: CharacterBuilderScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Step 1: Basics -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Ability Scores -> Auto-assign -> Next Step
      await tester.tap(find.text('Auto-Assign'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class -> Select Fighter -> Next Step
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Fighter (').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      if (find.text('Defense').evaluate().isNotEmpty) {
        await tester.tap(find.text('Defense'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Step: Species -> Select Human
      await tester.tap(find.text('Human'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Verify Species Bonus Skills prompt is visible for Human Skillful
      expect(find.textContaining('Species Bonus Skills (Human):'), findsOneWidget);
      expect(find.textContaining('0 / 1 selected'), findsOneWidget);

      // Select Arcana chip
      final arcanaChip = find.widgetWithText(FilterChip, 'Arcana');
      expect(arcanaChip, findsOneWidget);
      await tester.tap(arcanaChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('1 / 1 selected'), findsOneWidget);
    });
  });
}
