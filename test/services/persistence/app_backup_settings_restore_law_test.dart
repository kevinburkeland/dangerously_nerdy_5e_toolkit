import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/custom_preset.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/debounced_storage_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/preset_service.dart';
import 'app_backup_settings_test_support.dart';

int _readRestoredSettingsCount(BackupRestoreResult result) {
  try {
    return (result as dynamic).restoredSettingsCount as int;
  } on NoSuchMethodError {
    return 0;
  }
}

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

  test('SR0: Export format unchanged for const AppSettings()', () async {
    final jsonStr =
        await AppBackupService().exportFullBackupJson(const AppSettings());
    final decoded = json.decode(jsonStr) as Map<String, dynamic>;
    expect(
      decoded['settings'],
      equals(const <String, dynamic>{
        'themeMode': 'dark',
        'fantasyAccent': 'paladinGold',
        'oledPitchBlack': false,
        'hapticLevel': 'light',
        'wizardOrderingPreset': 'classic2014',
        'enableCritFumbleFx': true,
        'enableSpellParticles': true,
        'enable3dDiceOverlays': true,
        'enableGlyphAnimations': true,
        'performanceMode': false,
        'rulesEdition': 'v2024',
        'pinnedRuleIds': <dynamic>[],
        'pinnedSpellIds': <dynamic>[],
        'pinnedMonsterIds': <dynamic>[],
        'pinnedItemIds': <dynamic>[],
        'pinnedFeatIds': <dynamic>[],
        'pinnedClassIds': <dynamic>[],
        'pinnedRaceIds': <dynamic>[],
      }),
    );
  });

  test('SR1: Full 18-field round-trip and bypassedHomebrewSlugs preservation',
      () async {
    final backupJson = await AppBackupService()
        .exportFullBackupJson(kDistinctNonDefaultSettings);

    // Inject an attacker bypassedHomebrewSlugs into the backup JSON to verify it is ignored
    final map = json.decode(backupJson) as Map<String, dynamic>;
    final settingsMap = Map<String, dynamic>.from(map['settings'] as Map);
    settingsMap['bypassedHomebrewSlugs'] = ['hb_attacker'];
    map['settings'] = settingsMap;

    // Reset SharedPreferences to const AppSettings() with bypassedHomebrewSlugs: {'hb_keep_me'}
    final seedSettings =
        const AppSettings().copyWith(bypassedHomebrewSlugs: {'hb_keep_me'});
    final provider = SettingsProvider(
      initialSettings: seedSettings,
      autoLoad: false,
    );
    await provider.updateSettings(seedSettings);

    final result =
        await AppBackupService().importFullBackupJson(json.encode(map));
    expect(result.success, isTrue);
    expect(_readRestoredSettingsCount(result), equals(18));
    expect(result.skippedCount, equals(0));

    final prefs = await SharedPreferences.getInstance();
    final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
    expect(hydrated, equals(kDistinctNonDefaultSettings));
    expect(hydrated.bypassedHomebrewSlugs, equals({'hb_keep_me'}));
  });

  group('SR3: Partial, missing, and malformed settings in backup', () {
    Future<SharedPreferences> seedNonDefaultPrefs() async {
      final provider = SettingsProvider(
        initialSettings: kDistinctNonDefaultSettings,
        autoLoad: false,
      );
      await provider.updateSettings(kDistinctNonDefaultSettings);
      return SharedPreferences.getInstance();
    }

    test('Case 1: "settings" key absent from backup JSON', () async {
      final prefs = await seedNonDefaultPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(0));
      expect(result.skippedCount, equals(0));
      expect(
        SettingsProvider.hydrateFromPrefs(prefs),
        equals(kDistinctNonDefaultSettings),
      );
    });

    test('Case 2: "settings": {} empty object', () async {
      final prefs = await seedNonDefaultPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': <String, dynamic>{},
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(0));
      expect(result.skippedCount, equals(0));
      expect(
        SettingsProvider.hydrateFromPrefs(prefs),
        equals(kDistinctNonDefaultSettings),
      );
    });

    test('Case 3: "settings": "not-a-map" skips settings and still restores dicePresets', () async {
      final prefs = await seedNonDefaultPrefs();
      final preset = CustomPreset(
        id: 'preset_sr3_c3',
        name: 'SR3 Preset',
        count: 2,
        modifier: 3,
      );
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': 'not-a-map',
          'dicePresets': [preset.toMap()],
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(0));
      expect(result.skippedCount, equals(1));
      expect(result.skipReasons, contains('settings: expected object'));
      expect(result.restoredPresetsCount, equals(1));
      expect(
        SettingsProvider.hydrateFromPrefs(prefs),
        equals(kDistinctNonDefaultSettings),
      );
    });

    test('Case 4: "settings": {"themeMode": "dark"} updates only themeMode', () async {
      final prefs = await seedNonDefaultPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'themeMode': 'dark'},
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(1));
      expect(result.skippedCount, equals(0));
      expect(
        SettingsProvider.hydrateFromPrefs(prefs),
        equals(kDistinctNonDefaultSettings.copyWith(themeMode: ThemeMode.dark)),
      );
    });

    test('Case 5: unknown enum name skips bad field and applies valid field', () async {
      final base = kDistinctNonDefaultSettings.copyWith(oledPitchBlack: false);
      final provider = SettingsProvider(initialSettings: base, autoLoad: false);
      await provider.updateSettings(base);
      final prefs = await SharedPreferences.getInstance();

      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'themeMode': 'neon', 'oledPitchBlack': true},
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(1));
      expect(result.skippedCount, equals(1));
      expect(
        result.skipReasons.any((r) => r.startsWith('settings.themeMode:')),
        isTrue,
      );
      final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
      expect(hydrated.themeMode, equals(ThemeMode.light));
      expect(hydrated.oledPitchBlack, isTrue);
    });

    test('Case 6: wrong type for bool skips bad field and applies valid field', () async {
      final base = kDistinctNonDefaultSettings.copyWith(
        oledPitchBlack: false,
        performanceMode: false,
      );
      final provider = SettingsProvider(initialSettings: base, autoLoad: false);
      await provider.updateSettings(base);
      final prefs = await SharedPreferences.getInstance();

      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'oledPitchBlack': 'yes', 'performanceMode': true},
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(1));
      expect(result.skippedCount, equals(1));
      expect(
        result.skipReasons.any((r) => r.startsWith('settings.oledPitchBlack:')),
        isTrue,
      );
      final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
      expect(hydrated.oledPitchBlack, isFalse);
      expect(hydrated.performanceMode, isTrue);
    });

    test('Case 7: wrong type for list skips pinnedSpellIds', () async {
      final prefs = await seedNonDefaultPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'pinnedSpellIds': 'fireball'},
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(0));
      expect(result.skippedCount, equals(1));
      expect(
        result.skipReasons.any((r) => r.startsWith('settings.pinnedSpellIds:')),
        isTrue,
      );
      expect(
        SettingsProvider.hydrateFromPrefs(prefs).pinnedSpellIds,
        equals(kDistinctNonDefaultSettings.pinnedSpellIds),
      );
    });

    test('Case 8: non-string and empty element in list keeps valid elements and records skip', () async {
      final prefs = await seedNonDefaultPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {
            'pinnedSpellIds': ['acid_arrow', 42, ''],
          },
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(1));
      expect(result.skippedCount, equals(1));
      expect(
        result.skipReasons.any((r) => r.startsWith('settings.pinnedSpellIds:')),
        isTrue,
      );
      expect(
        SettingsProvider.hydrateFromPrefs(prefs).pinnedSpellIds,
        equals({'acid_arrow'}),
      );
    });

    test('Case 9: unknown future key is ignored without skip error', () async {
      final prefs = await seedNonDefaultPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {
            'futureSettingFrom2027': true,
            'themeMode': 'dark',
          },
        }),
      );
      expect(result.success, isTrue);
      expect(_readRestoredSettingsCount(result), equals(1));
      expect(result.skippedCount, equals(0));
      expect(
        SettingsProvider.hydrateFromPrefs(prefs).themeMode,
        equals(ThemeMode.dark),
      );
    });
  });
}
