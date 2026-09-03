import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_builder_screen.dart';

void main() {
  group('CharacterBuilderScreen Feat ASI & Rider Choice Widget Tests', () {
    testWidgets('2014 Variant Human bonus feat allows choosing Resilient, selecting CON chip, and viewing rider', (tester) async {
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

      // Open Guided Builder tab
      await tester.tap(find.text('Guided Builder'));
      await tester.pumpAndSettle();

      // Step 1: Basics -> Switch ruleset to 2014
      expect(find.text('2024 SRD (5.2 Revised)'), findsOneWidget);
      await tester.tap(find.text('2014 SRD (5.1 Classic)'));
      await tester.pumpAndSettle();

      // Scroll down and advance Step 1 -> Step 2
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Species -> Select Human (Variant)
      expect(find.text('Step 2: Choose Species / Race'), findsOneWidget);
      final variantHumanTile = find.widgetWithText(ListTile, 'Human (Variant)');
      await tester.scrollUntilVisible(variantHumanTile, 150, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(variantHumanTile);
      await tester.pumpAndSettle();

      // Advance Step 2 -> Step 3 (Class)
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Class (Fighter default) -> Step 4 (Class Decisions)
      expect(find.text('Step 3: Choose Class & Starting Skills'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4: Class Decisions (Fighting Style for Fighter) -> Step 5 (Background)
      if (find.text('Fighter Decisions & Specializations').evaluate().isNotEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle();
      }

      // Step 5: Background -> Step 6 (Scores)
      expect(find.textContaining('Choose Background'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 6: Ability Scores -> Step 7 (Feats)
      expect(find.textContaining('Ability Score Allocation'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 7: Variant Human Bonus Feat
      expect(find.textContaining('Bonus Feat'), findsOneWidget);

      // Scroll to find Resilient feat card
      final resilientFinder = find.widgetWithText(ListTile, 'Resilient');
      await tester.scrollUntilVisible(resilientFinder, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      // Select Resilient
      await tester.tap(resilientFinder);
      await tester.pumpAndSettle();

      // Verify choice chips for abilities are rendered
      expect(find.byKey(const Key('builder_feat_ability_constitution')), findsOneWidget);
      expect(find.byKey(const Key('builder_feat_ability_wisdom')), findsOneWidget);

      // Select Constitution
      await tester.tap(find.byKey(const Key('builder_feat_ability_constitution')));
      await tester.pumpAndSettle();

      // Verify saving throw badge is shown
      expect(find.text('Grants Proficiency: CON Saving Throws'), findsOneWidget);

      // Advance Feats -> Equipment
      final nextStepBtn = find.widgetWithText(ElevatedButton, 'Next Step');
      while (nextStepBtn.evaluate().isEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.tap(nextStepBtn);
      await tester.pumpAndSettle();

      // Advance Equipment -> Review & Finalize
      expect(find.textContaining('Equipment'), findsOneWidget);
      while (nextStepBtn.evaluate().isEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.tap(nextStepBtn);
      await tester.pumpAndSettle();

      // Review & Finalize
      expect(find.textContaining('Review & Finalize'), findsOneWidget);
      final reviewFinder = find.textContaining('Resilient (+1 CON, CON Save Prof)');
      while (reviewFinder.evaluate().isEmpty) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(reviewFinder, findsOneWidget);
    });
  });
}
