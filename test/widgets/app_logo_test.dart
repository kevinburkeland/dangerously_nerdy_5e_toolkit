import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/app_logo.dart';

void main() {
  group('AppLogo Widget Tests', () {
    testWidgets('renders properly with default parameters', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.bySemanticsLabel('DangerouslyNerdy 5e Toolkit Logo'), findsOneWidget);
    });

    testWidgets('renders at different sizes without layout overflow', (tester) async {
      for (final size in [24.0, 32.0, 48.0, 68.0, 128.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AppLogo(
                  size: size,
                  showGlow: true,
                  showRings: true,
                ),
              ),
            ),
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(AppLogo),
            matching: find.byType(SizedBox),
          ),
        );

        expect(sizedBox.width, equals(size));
        expect(sizedBox.height, equals(size));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('respects custom colors and toggles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(
              size: 40,
              primaryColor: Colors.purple,
              secondaryColor: Colors.cyan,
              showGlow: false,
              showRings: false,
            ),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('animates when animated flag is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLogo(
              size: 64,
              animated: true,
            ),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('spins and calls onTap when tapped in interactive mode', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppLogo(
              size: 48,
              interactive: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppLogo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
