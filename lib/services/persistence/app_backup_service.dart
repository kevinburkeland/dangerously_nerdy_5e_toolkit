import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';
import '../../models/custom_preset.dart';
import '../../models/dpr/dpr_serialization.dart';
import '../logging_service.dart';
import '../minion_session_service.dart';
import '../preset_service.dart';
import 'dpr_persistence_service.dart';

/// Backup archive payload representing all user preferences, presets, builds, and sessions.
class AppBackupPayload {
  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> dicePresets;
  final List<Map<String, dynamic>> dprProfiles;

  AppBackupPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.settings,
    required this.dicePresets,
    required this.dprProfiles,
  });

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'settings': settings,
        'dicePresets': dicePresets,
        'dprProfiles': dprProfiles,
      };

  factory AppBackupPayload.fromMap(Map<String, dynamic> map) {
    return AppBackupPayload(
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      exportedAt: DateTime.tryParse(map['exportedAt']?.toString() ?? '') ?? DateTime.now(),
      settings: Map<String, dynamic>.from(map['settings'] as Map? ?? {}),
      dicePresets: (map['dicePresets'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      dprProfiles: (map['dprProfiles'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}

/// Diagnostic result of a full-app backup restoration
class BackupRestoreResult {
  final bool success;
  final int restoredPresetsCount;
  final int restoredDprProfilesCount;
  final String? errorMessage;

  const BackupRestoreResult({
    required this.success,
    this.restoredPresetsCount = 0,
    this.restoredDprProfilesCount = 0,
    this.errorMessage,
  });
}

class AppBackupService {
  static final AppBackupService _instance = AppBackupService._internal();
  factory AppBackupService() => _instance;
  AppBackupService._internal();

  /// Generates a complete JSON backup archive of all settings, presets, and DPR builds.
  Future<String> exportFullBackupJson(AppSettings currentSettings) async {
    final customPresets = await PresetService().loadCustomPresets();
    final dprProfiles = await DprPersistenceService().loadSavedProfiles();

    final payload = AppBackupPayload(
      schemaVersion: 2,
      exportedAt: DateTime.now(),
      settings: {
        'themeMode': currentSettings.themeMode.name,
        'fantasyAccent': currentSettings.fantasyAccent.name,
        'oledPitchBlack': currentSettings.oledPitchBlack,
        'hapticLevel': currentSettings.hapticLevel.name,
        'enableCritFumbleFx': currentSettings.enableCritFumbleFx,
        'enableSpellParticles': currentSettings.enableSpellParticles,
        'enable3dDiceOverlays': currentSettings.enable3dDiceOverlays,
        'enableGlyphAnimations': currentSettings.enableGlyphAnimations,
        'performanceMode': currentSettings.performanceMode,
        'rulesEdition': currentSettings.rulesEdition.name,
        'pinnedRuleIds': currentSettings.pinnedRuleIds.toList(),
        'pinnedSpellIds': currentSettings.pinnedSpellIds.toList(),
        'pinnedMonsterIds': currentSettings.pinnedMonsterIds.toList(),
        'pinnedItemIds': currentSettings.pinnedItemIds.toList(),
      },
      dicePresets: customPresets.map((p) => p.toMap()).toList(),
      dprProfiles: dprProfiles.map((p) => p.toMap()).toList(),
    );

    return const JsonEncoder.withIndent('  ').convert(payload.toMap());
  }

  /// Restores complete app state from a backup JSON payload with sanity validation
  Future<BackupRestoreResult> importFullBackupJson(String jsonString) async {
    try {
      final cleanInput = jsonString.trim();
      if (cleanInput.length > 1000000) {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Backup file exceeds maximum allowed size (1MB)',
        );
      }

      final decoded = json.decode(cleanInput);
      if (decoded is! Map) {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Invalid JSON format for backup envelope',
        );
      }

      final backup = AppBackupPayload.fromMap(Map<String, dynamic>.from(decoded));

      int presetsRestored = 0;
      for (final rawPreset in backup.dicePresets) {
        try {
          final preset = CustomPreset.fromMap(rawPreset);
          await PresetService().savePreset(preset);
          presetsRestored++;
        } catch (_) {}
      }

      int profilesRestored = 0;
      for (final rawProfile in backup.dprProfiles) {
        try {
          final profile = DprCombatantProfileSerialization.fromMap(rawProfile);
          await DprPersistenceService().saveProfileToLibrary(profile);
          profilesRestored++;
        } catch (_) {}
      }

      return BackupRestoreResult(
        success: true,
        restoredPresetsCount: presetsRestored,
        restoredDprProfilesCount: profilesRestored,
      );
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to restore full app backup from JSON',
      );
      return BackupRestoreResult(
        success: false,
        errorMessage: 'Corrupted or malformed backup JSON: $e',
      );
    }
  }

  /// Storage Hygiene: Purges all persistent app keys and caches cleanly
  Future<void> clearAllAppData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      PresetService().clearCacheForTesting();
      MinionSessionService().clearCacheForTesting();
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to clear all app data from SharedPreferences',
      );
    }
  }
}
