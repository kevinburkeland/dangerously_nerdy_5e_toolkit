import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

      // Step 2: Species -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class (default is Fighter) -> Next Step
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
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

      // Step 2: Species -> Next Step
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

      // Step 2: Species -> Next Step
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class (Fighter default has Athletics selected, default Soldier background also has Athletics)
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
      expect(find.textContaining('Skill Collision Detected: Athletics'), findsOneWidget);
      expect(find.textContaining('Compensatory Pick(s):'), findsOneWidget);
    });
  });
}
