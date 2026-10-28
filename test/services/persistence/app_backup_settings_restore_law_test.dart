import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/debounced_storage_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/preset_service.dart';
import 'app_backup_settings_test_support.dart';

const String kExpectedDefaultExportSettingsJson =
    '{"themeMode":"dark","fantasyAccent":"paladinGold","oledPitchBlack":false,"hapticLevel":"light","wizardOrderingPreset":"classic2014","enableCritFumbleFx":true,"enableSpellParticles":true,"enable3dDiceOverlays":true,"enableGlyphAnimations":true,"performanceMode":false,"rulesEdition":"v2024","pinnedRuleIds":[],"pinnedSpellIds":[],"pinnedMonsterIds":[],"pinnedItemIds":[],"pinnedFeatIds":[],"pinnedClassIds":[],"pinnedRaceIds":[]}';

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
      jsonEncode(decoded['settings']),
      equals(kExpectedDefaultExportSettingsJson),
    );
  });

  test('SR1: Round-trip law over seeds 0..24 through AppBackupService', () async {
    for (var seed = 0; seed <= 24; seed++) {
      SharedPreferences.setMockInitialValues({});
      PresetService().clearCacheForTesting();
      HomebrewPersistenceService().invalidateAllCaches();
      await HomebrewPersistenceService().clearAllHomebrew();

      final s = randomSettings(seed);
      final opp = opposite(s);

      final provider = SettingsProvider(
        initialSettings: opp,
        autoLoad: false,
      );
      await provider.updateSettings(opp);

      final backupJson = await AppBackupService().exportFullBackupJson(s);
      final result = await AppBackupService().importFullBackupJson(backupJson);
      expect(result.success, isTrue, reason: 'seed $seed: restore failed');

      final prefs = await SharedPreferences.getInstance();
      final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
      final expected = s.copyWith(
        bypassedHomebrewSlugs: opp.bypassedHomebrewSlugs,
      );
      final diff = firstSettingsDiff(expected, hydrated);
      expect(
        diff,
        isNull,
        reason: 'seed $seed: first differing field: $diff',
      );
    }
  });

  group('SR3: Partial, missing, and malformed settings in backup', () {
    const c = kKnownNonDefaultSettings;

    Future<SharedPreferences> seedKnownPrefs() async {
      final provider = SettingsProvider(
        initialSettings: c,
        autoLoad: false,
      );
      await provider.updateSettings(c);
      return SharedPreferences.getInstance();
    }

    test('Case 1: settings: {} -> settings equal c, no skips', () async {
      final prefs = await seedKnownPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': <String, dynamic>{},
        }),
      );
      expect(result.success, isTrue);
      expect(result.skippedCount, equals(0));
      expect(result.skipReasons, isEmpty);
      final diff = firstSettingsDiff(c, SettingsProvider.hydrateFromPrefs(prefs));
      expect(diff, isNull, reason: 'unexpected settings diff: $diff');
    });

    test('Case 2: settings: {themeMode: light} only -> only themeMode changes; every other field equals c',
        () async {
      final prefs = await seedKnownPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'themeMode': 'light'},
        }),
      );
      expect(result.success, isTrue);
      expect(result.skippedCount, equals(0));
      expect(result.skipReasons, isEmpty);
      final expected = c.copyWith(themeMode: ThemeMode.light);
      final diff =
          firstSettingsDiff(expected, SettingsProvider.hydrateFromPrefs(prefs));
      expect(diff, isNull, reason: 'unexpected settings diff: $diff');
    });

    test('Case 3: fantasyAccent: neonPink -> accent equals c, one skip reason starting with settings.fantasyAccent:',
        () async {
      final prefs = await seedKnownPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'fantasyAccent': 'neonPink'},
        }),
      );
      expect(result.success, isTrue);
      expect(result.skippedCount, equals(1));
      expect(result.skipReasons, hasLength(1));
      expect(result.skipReasons.single, startsWith('settings.fantasyAccent:'));
      final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
      expect(hydrated.fantasyAccent, equals(c.fantasyAccent));
      final diff = firstSettingsDiff(c, hydrated);
      expect(diff, isNull, reason: 'unexpected settings diff: $diff');
    });

    group('Case 4: Wrong types, one case each', () {
      test('themeMode: 3 -> equals c, one skip naming settings.themeMode',
          () async {
        final prefs = await seedKnownPrefs();
        final result = await AppBackupService().importFullBackupJson(
          json.encode({
            'schemaVersion': 3,
            'exportedAt': '2026-01-01T00:00:00.000Z',
            'settings': {'themeMode': 3},
          }),
        );
        expect(result.success, isTrue);
        expect(result.skippedCount, equals(1));
        expect(result.skipReasons, hasLength(1));
        expect(result.skipReasons.single, contains('settings.themeMode'));
        final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
        expect(hydrated.themeMode, equals(c.themeMode));
      });

      test('oledPitchBlack: "true" -> equals c, one skip naming settings.oledPitchBlack',
          () async {
        final prefs = await seedKnownPrefs();
        final result = await AppBackupService().importFullBackupJson(
          json.encode({
            'schemaVersion': 3,
            'exportedAt': '2026-01-01T00:00:00.000Z',
            'settings': {'oledPitchBlack': 'true'},
          }),
        );
        expect(result.success, isTrue);
        expect(result.skippedCount, equals(1));
        expect(result.skipReasons, hasLength(1));
        expect(result.skipReasons.single, contains('settings.oledPitchBlack'));
        final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
        expect(hydrated.oledPitchBlack, equals(c.oledPitchBlack));
      });

      test('pinnedRuleIds: "rule_stealth" -> equals c, one skip naming settings.pinnedRuleIds',
          () async {
        final prefs = await seedKnownPrefs();
        final result = await AppBackupService().importFullBackupJson(
          json.encode({
            'schemaVersion': 3,
            'exportedAt': '2026-01-01T00:00:00.000Z',
            'settings': {'pinnedRuleIds': 'rule_stealth'},
          }),
        );
        expect(result.success, isTrue);
        expect(result.skippedCount, equals(1));
        expect(result.skipReasons, hasLength(1));
        expect(result.skipReasons.single, contains('settings.pinnedRuleIds'));
        final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
        expect(hydrated.pinnedRuleIds, equals(c.pinnedRuleIds));
      });

      test('pinnedSpellIds: ["ok", 7] -> equals c, one skip naming settings.pinnedSpellIds',
          () async {
        final prefs = await seedKnownPrefs();
        final result = await AppBackupService().importFullBackupJson(
          json.encode({
            'schemaVersion': 3,
            'exportedAt': '2026-01-01T00:00:00.000Z',
            'settings': {
              'pinnedSpellIds': ['ok', 7],
            },
          }),
        );
        expect(result.success, isTrue);
        expect(result.skippedCount, equals(1));
        expect(result.skipReasons, hasLength(1));
        expect(result.skipReasons.single, contains('settings.pinnedSpellIds'));
        final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
        expect(hydrated.pinnedSpellIds, equals(c.pinnedSpellIds));
      });
    });

    test('Case 5: rulesEdition: generic_tabletop -> edition equals c, one skip naming settings.rulesEdition',
        () async {
      final prefs = await seedKnownPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'rulesEdition': 'generic_tabletop'},
        }),
      );
      expect(result.success, isTrue);
      expect(result.skippedCount, equals(1));
      expect(result.skipReasons, hasLength(1));
      expect(result.skipReasons.single, contains('settings.rulesEdition'));
      final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
      expect(hydrated.rulesEdition, equals(c.rulesEdition));
    });

    test('Case 6: unknown future key (futureSetting: true) -> no change, no skip',
        () async {
      final prefs = await seedKnownPrefs();
      final result = await AppBackupService().importFullBackupJson(
        json.encode({
          'schemaVersion': 3,
          'exportedAt': '2026-01-01T00:00:00.000Z',
          'settings': {'futureSetting': true},
        }),
      );
      expect(result.success, isTrue);
      expect(result.skippedCount, equals(0));
      expect(result.skipReasons, isEmpty);
      final diff = firstSettingsDiff(c, SettingsProvider.hydrateFromPrefs(prefs));
      expect(diff, isNull, reason: 'unexpected settings diff: $diff');
    });

    test('Case 7: schemaVersion: 4 with valid different settings -> import fails and settings equal c',
        () async {
      final prefs = await seedKnownPrefs();
      final different = opposite(c);
      final exportedDifferent =
          await AppBackupService().exportFullBackupJson(different);
      final decoded = json.decode(exportedDifferent) as Map<String, dynamic>;
      decoded['schemaVersion'] = 4;

      final result =
          await AppBackupService().importFullBackupJson(json.encode(decoded));
      expect(result.success, isFalse);
      final diff = firstSettingsDiff(c, SettingsProvider.hydrateFromPrefs(prefs));
      expect(diff, isNull, reason: 'unexpected settings diff: $diff');
    });

    test('Case 8: valid backup with one malformed customSpells record and all different settings -> malformed record skipped and every setting applied',
        () async {
      final prefs = await seedKnownPrefs();
      final different = opposite(c);
      final exportedDifferent =
          await AppBackupService().exportFullBackupJson(different);
      final decoded = json.decode(exportedDifferent) as Map<String, dynamic>;
      decoded['customSpells'] = [
        {'level': 'not_an_int_and_missing_required_fields'},
      ];

      final result =
          await AppBackupService().importFullBackupJson(json.encode(decoded));
      expect(result.success, isTrue);
      expect(result.skippedCount, equals(1));
      expect(result.skipReasons.single, startsWith('customSpells[0]:'));
      final expected = different.copyWith(
        bypassedHomebrewSlugs: c.bypassedHomebrewSlugs,
      );
      final diff =
          firstSettingsDiff(expected, SettingsProvider.hydrateFromPrefs(prefs));
      expect(diff, isNull, reason: 'unexpected settings diff: $diff');
    });
  });
}
