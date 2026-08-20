import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SettingsScreen displays RPG Micro-Interactions and Test Lab buttons', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      SettingsScope(
        notifier: settingsProvider,
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify section header and switches exist
    expect(find.text('RPG MICRO-INTERACTIONS & FX'), findsOneWidget);
    expect(find.text('Spell Particle Canvas FX'), findsOneWidget);
    expect(find.text('Critical Hit & Fumble Effects'), findsOneWidget);
    expect(find.text('Creature & Spell Glyph Animations'), findsOneWidget);

    // Verify Test Lab buttons exist
    expect(find.text('Test Nat 20'), findsOneWidget);
    expect(find.text('Test Nat 1'), findsOneWidget);
    expect(find.text('Test Spell FX'), findsOneWidget);

    // Tap Test Spell FX button
    await tester.tap(find.text('Test Spell FX'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Tap Test Nat 20 button
    await tester.tap(find.text('Test Nat 20'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Tap Test Nat 1 button
    await tester.tap(find.text('Test Nat 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });
}
