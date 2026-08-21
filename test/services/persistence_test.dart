import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/debounced_storage_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/storage_migration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageMigrationService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Migrates legacy v1 integer enum indices to v2 string names', () async {
      SharedPreferences.setMockInitialValues({
        'setting_theme_mode': 2, // dark (0=system, 1=light, 2=dark)
        'setting_fantasy_accent': 2, // rangerEmerald
        'setting_haptic_level': 2, // heavy
        'setting_rules_edition': 0, // v2014
      });

      final prefs = await SharedPreferences.getInstance();
      await StorageMigrationService().runMigrations(prefs);

      expect(prefs.getInt('app_storage_schema_version'), 2);
      expect(prefs.getString('setting_theme_mode_v2'), 'dark');
      expect(prefs.getString('setting_fantasy_accent_v2'), 'rangerEmerald');
      expect(prefs.getString('setting_haptic_level_v2'), 'heavy');
      expect(prefs.getString('setting_rules_edition_v2'), 'v2014');

      // Old keys should be cleaned up
      expect(prefs.getInt('setting_theme_mode'), isNull);
      expect(prefs.getInt('setting_fantasy_accent'), isNull);
    });
  });

  group('SettingsProvider Pre-Hydration Tests', () {
    test('hydrateFromPrefs restores all settings correctly from v2 string keys', () async {
      SharedPreferences.setMockInitialValues({
        'setting_theme_mode_v2': 'light',
        'setting_fantasy_accent_v2': 'dragonfireCrimson',
        'setting_oled_pitch_black': true,
        'setting_haptic_level_v2': 'off',
        'setting_crit_fumble_fx': false,
        'setting_rules_edition_v2': 'v2024',
        'setting_pinned_rule_ids': ['rule_grapple', 'rule_shove'],
      });

      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider.hydrateFromPrefs(prefs);

      expect(settings.themeMode, ThemeMode.light);
      expect(settings.fantasyAccent, FantasyAccent.dragonfireCrimson);
      expect(settings.oledPitchBlack, true);
      expect(settings.hapticLevel, HapticFeedbackLevel.off);
      expect(settings.enableCritFumbleFx, false);
      expect(settings.rulesEdition, DmRulesEdition.v2024);
      expect(settings.pinnedRuleIds, containsAll(['rule_grapple', 'rule_shove']));
    });

    test('hydrateFromPrefs gracefully falls back on corrupt or missing values', () async {
      SharedPreferences.setMockInitialValues({
        'setting_theme_mode_v2': 'invalid_theme_value',
        'setting_fantasy_accent_v2': 'non_existent_accent',
      });

      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider.hydrateFromPrefs(prefs);

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.fantasyAccent, FantasyAccent.paladinGold);
    });
  });

  group('DebouncedStorageService Tests', () {
    tearDown(() {
      DebouncedStorageService().cancelAllForTesting();
    });

    test('Batches multiple rapid writes and executes only the last one', () async {
      final debouncer = DebouncedStorageService();
      int executionCount = 0;
      String lastValue = '';

      debouncer.scheduleWrite('test_key', () async {
        executionCount++;
        lastValue = 'A';
      }, duration: const Duration(milliseconds: 50));

      debouncer.scheduleWrite('test_key', () async {
        executionCount++;
        lastValue = 'B';
      }, duration: const Duration(milliseconds: 50));

      debouncer.scheduleWrite('test_key', () async {
        executionCount++;
        lastValue = 'C';
      }, duration: const Duration(milliseconds: 50));

      expect(debouncer.hasPendingTasks, isTrue);

      await Future.delayed(const Duration(milliseconds: 80));

      expect(executionCount, 1);
      expect(lastValue, 'C');
      expect(debouncer.hasPendingTasks, isFalse);
    });

    test('flushAll flushes all pending tasks immediately', () async {
      final debouncer = DebouncedStorageService();
      final executed = <String>[];

      debouncer.scheduleWrite('task_1', () async {
        executed.add('task_1');
      }, duration: const Duration(seconds: 10));

      debouncer.scheduleWrite('task_2', () async {
        executed.add('task_2');
      }, duration: const Duration(seconds: 10));

      await debouncer.flushAll();

      expect(executed, containsAll(['task_1', 'task_2']));
      expect(debouncer.hasPendingTasks, isFalse);
    });
  });

  group('AppBackupService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Full export and restore preserves data integrity', () async {
      const initialSettings = AppSettings(
        themeMode: ThemeMode.light,
        fantasyAccent: FantasyAccent.arcaneSapphire,
        oledPitchBlack: false,
        rulesEdition: DmRulesEdition.v2014,
        pinnedRuleIds: {'rule_stealth'},
      );

      final backupJson = await AppBackupService().exportFullBackupJson(initialSettings);
      expect(backupJson, contains('"schemaVersion": 2'));
      expect(backupJson, contains('"arcaneSapphire"'));

      final restoreResult = await AppBackupService().importFullBackupJson(backupJson);
      expect(restoreResult.success, isTrue);
    });

    test('Gracefully rejects corrupted JSON in backup import', () async {
      final restoreResult = await AppBackupService().importFullBackupJson('invalid { [ json');
      expect(restoreResult.success, isFalse);
      expect(restoreResult.errorMessage, isNotNull);
    });
  });
}
