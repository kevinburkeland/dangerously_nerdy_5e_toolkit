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
  });
}
