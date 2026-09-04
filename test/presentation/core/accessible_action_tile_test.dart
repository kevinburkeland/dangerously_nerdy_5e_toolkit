import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/core/accessible_action_tile.dart';

void main() {
  group('AccessibleActionTile', () {
    testWidgets('exposes proper Semantics node and narrative speech', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccessibleActionTile(
              title: 'Longsword Attack',
              mathematicalFormula: '1d8+3',
              narrativeSpeech: 'One eight-sided die plus three slashing damage',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      // Verify Semantics
      expect(
        tester.getSemantics(find.byType(AccessibleActionTile)),
        matchesSemantics(
          label: 'Longsword Attack. One eight-sided die plus three slashing damage',
          isButton: true,
          hasTapAction: true,
        ),
      );

      // Verify interaction
      await tester.tap(find.byType(AccessibleActionTile));
      expect(tapped, isTrue);
    });

    testWidgets('ensures minimum touch target dimensions >= 48x48dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AccessibleActionTile(
                title: 'A',
                mathematicalFormula: '1',
                narrativeSpeech: 'one',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(find.byType(AccessibleActionTile));
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('renders without overflow under 2.0x dynamic type scaling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
              size: Size(320, 480), // narrow viewport constraint
            ),
            child: Scaffold(
              body: AccessibleActionTile(
                title: 'Massive Smite Attack With Multi-Class Advantage',
                mathematicalFormula: '2d6+4 + 3d8 (radiant) + 1d4 (bless)',
                narrativeSpeech: 'Large formula with long description',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Pump and check there are no exceptions or RenderFlex overflows thrown
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('respects disableAnimations for reduced motion preferences', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: true,
            ),
            child: Scaffold(
              body: AccessibleActionTile(
                title: 'Dagger Throw',
                mathematicalFormula: '1d4+2',
                narrativeSpeech: 'One four sided die plus two',
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      final singleChildScrollView = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(singleChildScrollView.physics, isA<NeverScrollableScrollPhysics>());
    });
  });
}
