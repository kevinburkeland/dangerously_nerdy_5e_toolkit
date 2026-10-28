import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
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
