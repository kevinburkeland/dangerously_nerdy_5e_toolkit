import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';
import '../../models/custom_preset.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/dpr/dpr_serialization.dart';
import '../logging_service.dart';
import '../minion_session_service.dart';
import '../preset_service.dart';
import 'dpr_persistence_service.dart';
import 'homebrew_persistence_service.dart';

/// Backup archive payload representing all user preferences, presets, builds, and custom homebrew compendium entities.
class AppBackupPayload {
  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> dicePresets;
  final List<Map<String, dynamic>> dprProfiles;
  final List<Map<String, dynamic>> customSpells;
  final List<Map<String, dynamic>> customMonsters;
  final List<Map<String, dynamic>> customItems;

  AppBackupPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.settings,
    required this.dicePresets,
    required this.dprProfiles,
    this.customSpells = const [],
    this.customMonsters = const [],
    this.customItems = const [],
  });

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'settings': settings,
        'dicePresets': dicePresets,
        'dprProfiles': dprProfiles,
        'customSpells': customSpells,
        'customMonsters': customMonsters,
        'customItems': customItems,
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
      customSpells: (map['customSpells'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      customMonsters: (map['customMonsters'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      customItems: (map['customItems'] as List? ?? [])
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
  final int restoredHomebrewSpellsCount;
  final int restoredHomebrewMonstersCount;
  final int restoredHomebrewItemsCount;
  final String? errorMessage;

  const BackupRestoreResult({
    required this.success,
    this.restoredPresetsCount = 0,
    this.restoredDprProfilesCount = 0,
    this.restoredHomebrewSpellsCount = 0,
    this.restoredHomebrewMonstersCount = 0,
    this.restoredHomebrewItemsCount = 0,
    this.errorMessage,
  });

  int get totalRestoredEntities =>
      restoredPresetsCount +
      restoredDprProfilesCount +
      restoredHomebrewSpellsCount +
      restoredHomebrewMonstersCount +
      restoredHomebrewItemsCount;
}

class AppBackupService {
  static final AppBackupService _instance = AppBackupService._internal();
  factory AppBackupService() => _instance;
  AppBackupService._internal();

  /// Generates a complete JSON backup archive of all settings, presets, DPR builds, and homebrew compendium entities.
  Future<String> exportFullBackupJson(AppSettings currentSettings) async {
    final customPresets = await PresetService().loadCustomPresets();
    final dprProfiles = await DprPersistenceService().loadSavedProfiles();
    final customSpells = await HomebrewPersistenceService().loadCustomSpells();
    final customMonsters = await HomebrewPersistenceService().loadCustomMonsters();
    final customItems = await HomebrewPersistenceService().loadCustomItems();

    final payload = AppBackupPayload(
      schemaVersion: 3,
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
      customSpells: customSpells.map((s) => s.toMap()).toList(),
      customMonsters: customMonsters.map((m) => m.toMap()).toList(),
      customItems: customItems.map((i) => i.toMap()).toList(),
    );

    return const JsonEncoder.withIndent('  ').convert(payload.toMap());
  }

  /// Restores complete app state from a backup JSON payload with sanity validation
  Future<BackupRestoreResult> importFullBackupJson(String jsonString) async {
    try {
      final cleanInput = jsonString.trim();
      if (cleanInput.length > 2000000) {
        return const BackupRestoreResult(
          success: false,
          errorMessage: 'Backup file exceeds maximum allowed size (2MB)',
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

      int spellsRestored = 0;
      for (final rawSpell in backup.customSpells) {
        try {
          final spell = Spell.fromMap(rawSpell);
          await HomebrewPersistenceService().saveCustomSpell(spell);
          spellsRestored++;
        } catch (_) {}
      }

      int monstersRestored = 0;
      for (final rawMonster in backup.customMonsters) {
        try {
          final monster = Monster.fromMap(rawMonster);
          await HomebrewPersistenceService().saveCustomMonster(monster);
          monstersRestored++;
        } catch (_) {}
      }

      int itemsRestored = 0;
      for (final rawItem in backup.customItems) {
        try {
          final item = EquipmentItem.fromMap(rawItem);
          await HomebrewPersistenceService().saveCustomItem(item);
          itemsRestored++;
        } catch (_) {}
      }

      return BackupRestoreResult(
        success: true,
        restoredPresetsCount: presetsRestored,
        restoredDprProfilesCount: profilesRestored,
        restoredHomebrewSpellsCount: spellsRestored,
        restoredHomebrewMonstersCount: monstersRestored,
        restoredHomebrewItemsCount: itemsRestored,
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
