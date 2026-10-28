import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/settings_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/debounced_storage_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/preset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    DebouncedStorageService().cancelAllForTesting();
    SharedPreferences.setMockInitialValues({});
    PresetService().clearCacheForTesting();
    HomebrewPersistenceService().invalidateAllCaches();
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  tearDown(() {
    DebouncedStorageService().cancelAllForTesting();
  });

  testWidgets(
      'SettingsScreen displays RPG Micro-Interactions and Test Lab buttons',
      (tester) async {
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

  testWidgets('SettingsScreen updates Character Creation Step Flow preset',
      (tester) async {
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

    expect(settingsProvider.settings.wizardOrderingPreset,
        equals(WizardOrderingPreset.modern2024));
  });

  testWidgets('SR5: Widget restore reloads SettingsProvider and shows settings in SnackBar',
      (WidgetTester tester) async {
    final settingsProvider = SettingsProvider(
      initialSettings: const AppSettings(),
      autoLoad: false,
    );
    await settingsProvider.updateSettings(const AppSettings());

    await tester.pumpWidget(
      SettingsScope(
        notifier: settingsProvider,
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(settingsProvider.settings.themeMode, equals(ThemeMode.dark));
    expect(
      settingsProvider.settings.fantasyAccent,
      equals(FantasyAccent.paladinGold),
    );

    final importBtn = find.text('Import Full Backup');
    await tester.scrollUntilVisible(
      importBtn,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(importBtn);
    await tester.pumpAndSettle();
    await tester.tap(importBtn);
    await tester.pumpAndSettle();

    final backupPayload = json.encode({
      'schemaVersion': 3,
      'exportedAt': '2026-01-01T00:00:00.000Z',
      'settings': {
        'themeMode': 'light',
        'fantasyAccent': 'arcaneSapphire',
      },
    });

    await tester.enterText(find.byType(TextField), backupPayload);
    await tester.tap(find.text('Restore Backup'));
    await tester.pumpAndSettle();

    expect(settingsProvider.settings.themeMode, equals(ThemeMode.light));
    expect(
      settingsProvider.settings.fantasyAccent,
      equals(FantasyAccent.arcaneSapphire),
    );
    expect(find.textContaining('settings'), findsOneWidget);
  });
}
