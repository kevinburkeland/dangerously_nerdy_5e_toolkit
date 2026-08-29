import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';
import '../../models/custom_preset.dart';
import '../../models/domain/homebrew_extended_entities.dart';
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
  final List<Map<String, dynamic>> customClasses;
  final List<Map<String, dynamic>> customSubclasses;
  final List<Map<String, dynamic>> customRaces;
  final List<Map<String, dynamic>> customFeats;
  final List<Map<String, dynamic>> customBackgrounds;
  final List<Map<String, dynamic>> customOtherEntries;

  AppBackupPayload({
    required this.schemaVersion,
    required this.exportedAt,
    required this.settings,
    required this.dicePresets,
    required this.dprProfiles,
    this.customSpells = const [],
    this.customMonsters = const [],
    this.customItems = const [],
    this.customClasses = const [],
    this.customSubclasses = const [],
    this.customRaces = const [],
    this.customFeats = const [],
    this.customBackgrounds = const [],
    this.customOtherEntries = const [],
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
        'customClasses': customClasses,
        'customSubclasses': customSubclasses,
        'customRaces': customRaces,
        'customFeats': customFeats,
        'customBackgrounds': customBackgrounds,
        'customOtherEntries': customOtherEntries,
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
      customClasses: (map['customClasses'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      customSubclasses: (map['customSubclasses'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      customRaces: (map['customRaces'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      customFeats: (map['customFeats'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      customBackgrounds: (map['customBackgrounds'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      customOtherEntries: (map['customOtherEntries'] as List? ?? [])
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
  final int restoredHomebrewClassesCount;
  final int restoredHomebrewSubclassesCount;
  final int restoredHomebrewRacesCount;
  final int restoredHomebrewFeatsCount;
  final int restoredHomebrewBackgroundsCount;
  final int restoredHomebrewOtherCount;
  final String? errorMessage;

  const BackupRestoreResult({
    required this.success,
    this.restoredPresetsCount = 0,
    this.restoredDprProfilesCount = 0,
    this.restoredHomebrewSpellsCount = 0,
    this.restoredHomebrewMonstersCount = 0,
    this.restoredHomebrewItemsCount = 0,
    this.restoredHomebrewClassesCount = 0,
    this.restoredHomebrewSubclassesCount = 0,
    this.restoredHomebrewRacesCount = 0,
    this.restoredHomebrewFeatsCount = 0,
    this.restoredHomebrewBackgroundsCount = 0,
    this.restoredHomebrewOtherCount = 0,
    this.errorMessage,
  });

  int get totalRestoredEntities =>
      restoredPresetsCount +
      restoredDprProfilesCount +
      restoredHomebrewSpellsCount +
      restoredHomebrewMonstersCount +
      restoredHomebrewItemsCount +
      restoredHomebrewClassesCount +
      restoredHomebrewSubclassesCount +
      restoredHomebrewRacesCount +
      restoredHomebrewFeatsCount +
      restoredHomebrewBackgroundsCount +
      restoredHomebrewOtherCount;
}

class AppBackupService {
  static const int currentSchemaVersion = 3;

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
    final customClasses = await HomebrewPersistenceService().loadCustomClasses();
    final customSubclasses = await HomebrewPersistenceService().loadCustomSubclasses();
    final customRaces = await HomebrewPersistenceService().loadCustomRaces();
    final customFeats = await HomebrewPersistenceService().loadCustomFeats();
    final customBackgrounds = await HomebrewPersistenceService().loadCustomBackgrounds();
    final customOthers = await HomebrewPersistenceService().loadCustomOtherEntries();

    final payload = AppBackupPayload(
      schemaVersion: currentSchemaVersion,
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
      customClasses: customClasses.map((c) => c.toMap()).toList(),
      customSubclasses: customSubclasses.map((s) => s.toMap()).toList(),
      customRaces: customRaces.map((r) => r.toMap()).toList(),
      customFeats: customFeats.map((f) => f.toMap()).toList(),
      customBackgrounds: customBackgrounds.map((b) => b.toMap()).toList(),
      customOtherEntries: customOthers.map((o) => o.toMap()).toList(),
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

      int classesRestored = 0;
      for (final rawClass in backup.customClasses) {
        try {
          final cl = CharacterClass.fromMap(rawClass);
          await HomebrewPersistenceService().saveCustomClass(cl);
          classesRestored++;
        } catch (_) {}
      }

      int subclassesRestored = 0;
      for (final rawSub in backup.customSubclasses) {
        try {
          final sub = Subclass.fromMap(rawSub);
          await HomebrewPersistenceService().saveCustomSubclass(sub);
          subclassesRestored++;
        } catch (_) {}
      }

      int racesRestored = 0;
      for (final rawRace in backup.customRaces) {
        try {
          final race = Race.fromMap(rawRace);
          await HomebrewPersistenceService().saveCustomRace(race);
          racesRestored++;
        } catch (_) {}
      }

      int featsRestored = 0;
      for (final rawFeat in backup.customFeats) {
        try {
          final feat = Feat.fromMap(rawFeat);
          await HomebrewPersistenceService().saveCustomFeat(feat);
          featsRestored++;
        } catch (_) {}
      }

      int backgroundsRestored = 0;
      for (final rawBg in backup.customBackgrounds) {
        try {
          final bg = Background.fromMap(rawBg);
          await HomebrewPersistenceService().saveCustomBackground(bg);
          backgroundsRestored++;
        } catch (_) {}
      }

      int othersRestored = 0;
      for (final rawOther in backup.customOtherEntries) {
        try {
          final other = HomebrewCompendiumEntry.fromMap(rawOther);
          await HomebrewPersistenceService().saveCustomOtherEntry(other);
          othersRestored++;
        } catch (_) {}
      }

      return BackupRestoreResult(
        success: true,
        restoredPresetsCount: presetsRestored,
        restoredDprProfilesCount: profilesRestored,
        restoredHomebrewSpellsCount: spellsRestored,
        restoredHomebrewMonstersCount: monstersRestored,
        restoredHomebrewItemsCount: itemsRestored,
        restoredHomebrewClassesCount: classesRestored,
        restoredHomebrewSubclassesCount: subclassesRestored,
        restoredHomebrewRacesCount: racesRestored,
        restoredHomebrewFeatsCount: featsRestored,
        restoredHomebrewBackgroundsCount: backgroundsRestored,
        restoredHomebrewOtherCount: othersRestored,
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
