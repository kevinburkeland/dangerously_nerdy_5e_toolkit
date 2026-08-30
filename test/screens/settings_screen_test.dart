import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
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

  testWidgets('SettingsScreen toggles global rules edition via RulesEditionToggle', (tester) async {
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

    expect(find.text('Global Rulebook Edition'), findsOneWidget);
    expect(find.text('2014'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);

    // Tap 2014
    await tester.tap(find.text('2014'));
    await tester.pumpAndSettle();
    expect(settingsProvider.settings.rulesEdition, equals(DmRulesEdition.v2014));

    // Tap 2024
    await tester.tap(find.text('2024'));
    await tester.pumpAndSettle();
    expect(settingsProvider.settings.rulesEdition, equals(DmRulesEdition.v2024));
  });

  testWidgets('SettingsScreen updates Character Creation Step Flow preset', (tester) async {
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

    expect(find.text('Character Creation Step Flow'), findsOneWidget);
    expect(find.text('2014 Classic (Species First)'), findsOneWidget);

    // Change to 2024 Modern (Class First)
    await tester.tap(find.text('2014 Classic (Species First)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2024 Modern (Class First)').last);
    await tester.pumpAndSettle();

    expect(settingsProvider.settings.wizardOrderingPreset, equals(WizardOrderingPreset.modern2024));
  });
}
