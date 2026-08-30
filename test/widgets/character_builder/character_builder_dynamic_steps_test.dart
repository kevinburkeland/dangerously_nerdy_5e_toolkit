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
  });
}
