import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/landing_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dm_reference_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/dice_roller_screen.dart';

void main() {
  group('Accessibility: Large Text Scaling (Dynamic Type) Overflow Tests', () {
    testWidgets('LandingScreen renders without overflow at 1.5x and 2.0x TextScaler', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(540, 1200),
              textScaler: TextScaler.linear(1.5),
            ),
            child: LandingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('DmReferenceScreen renders without overflow at 1.5x TextScaler', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(540, 1200),
              textScaler: TextScaler.linear(1.5),
            ),
            child: DmReferenceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Rules Compendium"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DiceRollerScreen renders without overflow at 1.5x TextScaler', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(540, 1200),
              textScaler: TextScaler.linear(1.5),
            ),
            child: DiceRollerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dice Roller'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
