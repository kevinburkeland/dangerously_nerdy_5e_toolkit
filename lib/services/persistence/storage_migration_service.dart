import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';
import '../../models/dm_screen_data.dart';
import '../logging_service.dart';

/// Centralized migration engine for local persistent storage.
///
/// Ensures backward compatibility across app updates, schema changes,
/// and converts legacy integer index enums to deterministic string tokens.
class StorageMigrationService {
  static const int currentSchemaVersion = 2;
  static const String _kSchemaVersionKey = 'app_storage_schema_version';

  static final StorageMigrationService _instance = StorageMigrationService._internal();
  factory StorageMigrationService() => _instance;
  StorageMigrationService._internal();

  /// Runs all pending migrations sequentially upon startup.
  Future<void> runMigrations(SharedPreferences prefs) async {
    final int storedVersion = prefs.getInt(_kSchemaVersionKey) ?? 1;

    if (storedVersion >= currentSchemaVersion) {
      return;
    }

    LoggingService().logInfo(
      'Running storage migrations from v$storedVersion to v$currentSchemaVersion',
    );

    try {
      if (storedVersion < 2) {
        await _migrateV1ToV2(prefs);
      }
      // Future migration hooks can be chained here:
      // if (storedVersion < 3) { await _migrateV2ToV3(prefs); }

      await prefs.setInt(_kSchemaVersionKey, currentSchemaVersion);
      LoggingService().logInfo(
        'Storage successfully migrated to schema v$currentSchemaVersion',
      );
    } catch (e, stackTrace) {
      LoggingService().logFatal(
        e,
        stackTrace,
        reason: 'Critical failure during storage schema migration from v$storedVersion',
      );
    }
  }

  /// Migration v1 -> v2:
  /// Converts legacy integer enum indices to robust canonical string names.
  Future<void> _migrateV1ToV2(SharedPreferences prefs) async {
    // 1. Migrate ThemeMode
    final oldTheme = prefs.getInt('setting_theme_mode');
    if (oldTheme != null && oldTheme >= 0 && oldTheme < ThemeMode.values.length) {
      await prefs.setString('setting_theme_mode_v2', ThemeMode.values[oldTheme].name);
      await prefs.remove('setting_theme_mode');
    }

    // 2. Migrate FantasyAccent
    final oldAccent = prefs.getInt('setting_fantasy_accent');
    if (oldAccent != null && oldAccent >= 0 && oldAccent < FantasyAccent.values.length) {
      await prefs.setString('setting_fantasy_accent_v2', FantasyAccent.values[oldAccent].name);
      await prefs.remove('setting_fantasy_accent');
    }

    // 3. Migrate HapticFeedbackLevel
    final oldHaptic = prefs.getInt('setting_haptic_level');
    if (oldHaptic != null && oldHaptic >= 0 && oldHaptic < HapticFeedbackLevel.values.length) {
      await prefs.setString('setting_haptic_level_v2', HapticFeedbackLevel.values[oldHaptic].name);
      await prefs.remove('setting_haptic_level');
    }

    // 4. Migrate DmRulesEdition
    final oldEdition = prefs.getInt('setting_rules_edition');
    if (oldEdition != null && oldEdition >= 0 && oldEdition < DmRulesEdition.values.length) {
      await prefs.setString('setting_rules_edition_v2', DmRulesEdition.values[oldEdition].name);
      await prefs.remove('setting_rules_edition');
    }
  }
}
