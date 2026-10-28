import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_settings.dart';
import '../../models/custom_preset.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/dpr/dpr_serialization.dart';
import '../../providers/settings_provider.dart';
import '../fluff/entity_fluff_service.dart';
import '../logging_service.dart';
import '../minion_session_service.dart';
import '../preset_service.dart';
import 'app_backup_settings_codec.dart';
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
  final List<Map<String, dynamic>> customSubraces;
  final List<Map<String, dynamic>> customFeats;
  final List<Map<String, dynamic>> customBackgrounds;
  final List<Map<String, dynamic>> customOtherEntries;
  final Map<String, dynamic> fluffData;
  final Map<String, dynamic> userNotesData;

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
    this.customSubraces = const [],
    this.customFeats = const [],
    this.customBackgrounds = const [],
    this.customOtherEntries = const [],
    this.fluffData = const {},
    this.userNotesData = const {},
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
        'customSubraces': customSubraces,
        'customFeats': customFeats,
        'customBackgrounds': customBackgrounds,
        'customOtherEntries': customOtherEntries,
        'fluffData': fluffData,
        'userNotesData': userNotesData,
      };

  factory AppBackupPayload.fromMap(Map<String, dynamic> map) {
    return AppBackupPayload(
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      exportedAt: DateTime.tryParse(map['exportedAt']?.toString() ?? '') ??
          DateTime.now(),
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
      customSubraces: (map['customSubraces'] as List? ?? [])
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
      fluffData: Map<String, dynamic>.from(map['fluffData'] as Map? ?? {}),
      userNotesData:
          Map<String, dynamic>.from(map['userNotesData'] as Map? ?? {}),
    );
  }
}

/// Diagnostic result of a full-app backup restoration
class BackupRestoreResult {
  final bool success;
  final int restoredSettingsCount;
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
  final int skippedCount;
  final List<String> skipReasons;
  final String? errorMessage;

  const BackupRestoreResult({
    required this.success,
    this.restoredSettingsCount = 0,
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
    this.skippedCount = 0,
    this.skipReasons = const [],
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
    final customMonsters =
        await HomebrewPersistenceService().loadCustomMonsters();
    final customItems = await HomebrewPersistenceService().loadCustomItems();
    final loadedClasses =
        await HomebrewPersistenceService().loadCustomClasses();
    final classesMap = <String, CharacterClass>{
      for (final c in SrdClassesLibrary.customClasses) c.id.slug: c,
      for (final c in loadedClasses) c.id.slug: c,
    };
    final customClasses = classesMap.values.toList();

    final loadedSubclasses =
        await HomebrewPersistenceService().loadCustomSubclasses();
    final subclassesMap = <String, Subclass>{
      for (final s in SrdClassesLibrary.customSubclasses) s.id.slug: s,
      for (final s in loadedSubclasses) s.id.slug: s,
      for (final c in customClasses)
        for (final s in c.subclasses) s.id.slug: s,
    };
    final customSubclasses = subclassesMap.values.toList();

    final loadedRaces = await HomebrewPersistenceService().loadCustomRaces();
    final racesMap = <String, Race>{
      for (final r in SrdSpeciesLibrary.customSpecies) r.id.slug: r,
      for (final r in loadedRaces) r.id.slug: r,
    };
    final customRaces = racesMap.values.toList();

    final standaloneSubs =
        await HomebrewPersistenceService().loadCustomSubraces();
    final subracesMap = <String, Subrace>{
      for (final s in SrdSpeciesLibrary.customSubraces) s.id.slug: s,
      for (final s in standaloneSubs) s.id.slug: s,
      for (final r in customRaces)
        for (final s in r.subraces) s.id.slug: s,
    };
    final customSubraces = subracesMap.values.toList();

    final loadedFeats = await HomebrewPersistenceService().loadCustomFeats();
    final featsMap = <String, Feat>{
      for (final f in SrdFeatsLibrary.customFeats) f.id.slug: f,
      for (final f in loadedFeats) f.id.slug: f,
    };
    final customFeats = featsMap.values.toList();

    final loadedBackgrounds =
        await HomebrewPersistenceService().loadCustomBackgrounds();
    final backgroundsMap = <String, Background>{
      for (final b in SrdBackgroundsLibrary.customBackgrounds) b.id.slug: b,
      for (final b in loadedBackgrounds) b.id.slug: b,
    };
    final customBackgrounds = backgroundsMap.values.toList();

    final customOthers =
        await HomebrewPersistenceService().loadCustomOtherEntries();

    final payload = AppBackupPayload(
      schemaVersion: currentSchemaVersion,
      exportedAt: DateTime.now(),
      settings: encodeAppBackupSettings(currentSettings),
      dicePresets: customPresets.map((p) => p.toMap()).toList(),
      dprProfiles: dprProfiles.map((p) => p.toMap()).toList(),
      customSpells: customSpells.map((s) => s.toMap()).toList(),
      customMonsters: customMonsters.map((m) => m.toMap()).toList(),
      customItems: customItems.map((i) => i.toMap()).toList(),
      customClasses: customClasses.map((c) => c.toMap()).toList(),
      customSubclasses: customSubclasses.map((s) => s.toMap()).toList(),
      customRaces: customRaces.map((r) => r.toMap()).toList(),
      customSubraces: customSubraces.map((s) => s.toMap()).toList(),
      customFeats: customFeats.map((f) => f.toMap()).toList(),
      customBackgrounds: customBackgrounds.map((b) => b.toMap()).toList(),
      customOtherEntries: customOthers.map((o) => o.toMap()).toList(),
      fluffData: EntityFluffService().exportFluffMap(),
      userNotesData: EntityFluffService().exportUserNotesMap(),
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

      final backup =
          AppBackupPayload.fromMap(Map<String, dynamic>.from(decoded));

      if (backup.schemaVersion > currentSchemaVersion) {
        return BackupRestoreResult(
          success: false,
          errorMessage:
              'Backup schema version ${backup.schemaVersion} is newer than current supported version $currentSchemaVersion.',
        );
      }

      int skippedCount = 0;
      final skipReasons = <String>[];

      int presetsRestored = 0;
      for (int i = 0; i < backup.dicePresets.length; i++) {
        final rawPreset = backup.dicePresets[i];
        try {
          final preset = CustomPreset.fromMap(rawPreset);
          await PresetService().savePreset(preset);
          presetsRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('dicePresets[$i]: $e');
        }
      }

      int profilesRestored = 0;
      for (int i = 0; i < backup.dprProfiles.length; i++) {
        final rawProfile = backup.dprProfiles[i];
        try {
          final profile = DprCombatantProfileSerialization.fromMap(rawProfile);
          await DprPersistenceService().saveProfileToLibrary(profile);
          profilesRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('dprProfiles[$i]: $e');
        }
      }

      int spellsRestored = 0;
      for (int i = 0; i < backup.customSpells.length; i++) {
        final rawSpell = backup.customSpells[i];
        try {
          final spell = Spell.fromMap(rawSpell);
          await HomebrewPersistenceService().saveCustomSpell(spell);
          spellsRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customSpells[$i]: $e');
        }
      }

      int monstersRestored = 0;
      for (int i = 0; i < backup.customMonsters.length; i++) {
        final rawMonster = backup.customMonsters[i];
        try {
          final monster = Monster.fromMap(rawMonster);
          await HomebrewPersistenceService().saveCustomMonster(monster);
          monstersRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customMonsters[$i]: $e');
        }
      }

      int itemsRestored = 0;
      for (int i = 0; i < backup.customItems.length; i++) {
        final rawItem = backup.customItems[i];
        try {
          final item = EquipmentItem.fromMap(rawItem);
          await HomebrewPersistenceService().saveCustomItem(item);
          itemsRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customItems[$i]: $e');
        }
      }

      int classesRestored = 0;
      for (int i = 0; i < backup.customClasses.length; i++) {
        final rawClass = backup.customClasses[i];
        try {
          final cl = CharacterClass.fromMap(rawClass);
          await HomebrewPersistenceService().saveCustomClass(cl);
          classesRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customClasses[$i]: $e');
        }
      }

      int subclassesRestored = 0;
      for (int i = 0; i < backup.customSubclasses.length; i++) {
        final rawSub = backup.customSubclasses[i];
        try {
          final sub = Subclass.fromMap(rawSub);
          await HomebrewPersistenceService().saveCustomSubclass(sub);
          subclassesRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customSubclasses[$i]: $e');
        }
      }

      int racesRestored = 0;
      final parsedRaces = <Race>[];
      for (int i = 0; i < backup.customRaces.length; i++) {
        final rawRace = backup.customRaces[i];
        try {
          parsedRaces.add(Race.fromMap(rawRace));
        } catch (e) {
          skippedCount++;
          skipReasons.add('customRaces[$i]: $e');
        }
      }
      if (backup.customSubraces.isNotEmpty) {
        final parsedSubraces = <Subrace>[];
        for (int i = 0; i < backup.customSubraces.length; i++) {
          final rawSub = backup.customSubraces[i];
          try {
            parsedSubraces.add(Subrace.fromMap(rawSub));
          } catch (e) {
            skippedCount++;
            skipReasons.add('customSubraces[$i]: $e');
          }
        }
        for (int i = 0; i < parsedRaces.length; i++) {
          final race = parsedRaces[i];
          final existingSubSlugs =
              race.subraces.map((s) => s.id.slug.toLowerCase()).toSet();
          final matchingSubs = parsedSubraces.where(
            (s) =>
                s.raceSlug.toLowerCase() == race.id.slug.toLowerCase() &&
                !existingSubSlugs.contains(s.id.slug.toLowerCase()),
          );
          if (matchingSubs.isNotEmpty) {
            parsedRaces[i] =
                race.copyWith(subraces: [...race.subraces, ...matchingSubs]);
          }
        }
        final knownSlugs =
            parsedRaces.map((r) => r.id.slug.toLowerCase()).toSet();
        final orphanSubsByRace = <String, List<Subrace>>{};
        for (final sub in parsedSubraces) {
          final slug = sub.raceSlug.toLowerCase();
          if (!knownSlugs.contains(slug)) {
            orphanSubsByRace.putIfAbsent(slug, () => []).add(sub);
          }
        }
        for (final entry in orphanSubsByRace.entries) {
          final raceName =
              entry.value.first.customProperties['raceName']?.toString() ??
                  entry.value.first.customProperties['race']?.toString() ??
                  entry.key
                      .split('-')
                      .map((w) => w.isNotEmpty
                          ? '${w[0].toUpperCase()}${w.substring(1)}'
                          : '')
                      .join(' ');
          parsedRaces.add(
            Race(
              id: EntityId(
                  slug: entry.key, ruleset: entry.value.first.id.ruleset),
              name: raceName.isNotEmpty ? raceName : 'Base Race',
              traitsMarkdown: '',
              subraces: entry.value,
              customProperties: const {'isShellForSubrace': true},
            ),
          );
        }
        await HomebrewPersistenceService()
            .saveCustomSubracesBatch(parsedSubraces);
      }

      for (final race in parsedRaces) {
        try {
          await HomebrewPersistenceService().saveCustomRace(race);
          racesRestored++;
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Failed to persist custom race ${race.id.slug}',
          );
        }
      }

      int featsRestored = 0;
      for (int i = 0; i < backup.customFeats.length; i++) {
        final rawFeat = backup.customFeats[i];
        try {
          final feat = Feat.fromMap(rawFeat);
          await HomebrewPersistenceService().saveCustomFeat(feat);
          featsRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customFeats[$i]: $e');
        }
      }

      int backgroundsRestored = 0;
      for (int i = 0; i < backup.customBackgrounds.length; i++) {
        final rawBg = backup.customBackgrounds[i];
        try {
          final bg = Background.fromMap(rawBg);
          await HomebrewPersistenceService().saveCustomBackground(bg);
          backgroundsRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customBackgrounds[$i]: $e');
        }
      }

      int othersRestored = 0;
      for (int i = 0; i < backup.customOtherEntries.length; i++) {
        final rawOther = backup.customOtherEntries[i];
        try {
          final other = HomebrewCompendiumEntry.fromMap(rawOther);
          await HomebrewPersistenceService().saveCustomOtherEntry(other);
          othersRestored++;
        } catch (e) {
          skippedCount++;
          skipReasons.add('customOtherEntries[$i]: $e');
        }
      }

      // Restore entity fluff and user notes
      EntityFluffService().importFromBackup(
        fluffData: backup.fluffData,
        userNotesData: backup.userNotesData,
      );

      final prefs = await SharedPreferences.getInstance();
      final base = SettingsProvider.hydrateFromPrefs(prefs);
      final decodedSettings = decodeAppBackupSettings(
        backup.settings,
        base: base,
      );
      skippedCount += decodedSettings.skipped.length;
      skipReasons.addAll(decodedSettings.skipped);
      await SettingsProvider.writeToPrefs(prefs, decodedSettings.settings);
      final int settingsRestored = decodedSettings.appliedCount;

      return BackupRestoreResult(
        success: true,
        restoredSettingsCount: settingsRestored,
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
        skippedCount: skippedCount,
        skipReasons: skipReasons,
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
