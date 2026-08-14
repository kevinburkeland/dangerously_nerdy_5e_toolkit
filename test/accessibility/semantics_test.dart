import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_reference_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/interactive/pressable_card.dart';

void main() {
  group('Accessibility & Semantics Tests', () {
    testWidgets('PressableCard exposes configured semantics correctly', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableCard(
              onTap: () {},
              semanticLabel: 'DM Screen, 2014 & 2024. Quick lookup tool. Tap to launch.',
              excludeChildSemantics: true,
              child: const Text('Internal Unannounced Text'),
            ),
          ),
        ),
      );

      // Verify that the semantic node has the unified label and button role
      expect(
        tester.getSemantics(find.byType(PressableCard)),
        matchesSemantics(
          label: 'DM Screen, 2014 & 2024. Quick lookup tool. Tap to launch.',
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('LandingScreen has semantic headers and accessible tool cards', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: LandingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar header semantics
      final appBarTitle = find.text('DangerouslyNerdy 5e Toolkit');
      expect(appBarTitle, findsOneWidget);

      // Verify PressableCard widgets are found
      expect(find.byType(PressableCard), findsWidgets);

      handle.dispose();
    });

    testWidgets('DmReferenceScreen exposes header semantics on title and sections', (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: DmReferenceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "DM's Screen" header exists
      expect(find.text("DM's Screen"), findsOneWidget);

      // Verify quick dice button semantics
      expect(find.text('d20'), findsOneWidget);
      expect(find.text('d100'), findsOneWidget);

      handle.dispose();
    });
  });
}
