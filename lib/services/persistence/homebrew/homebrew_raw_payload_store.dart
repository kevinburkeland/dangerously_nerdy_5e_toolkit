import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart' show EntityType;

import '../../logging_service.dart';
import '../app_database_service.dart';

/// Shared storage keys, string-list persistence, slug index cache, and raw JSON
/// payload helpers for homebrew entity stores.
class HomebrewRawPayloadStore {
  static const String keyHomebrewSpells = 'dn_homebrew_spells_v1';
  static const String keyHomebrewMonsters = 'dn_homebrew_monsters_v1';
  static const String keyHomebrewItems = 'dn_homebrew_items_v1';
  static const String keyHomebrewClasses = 'dn_homebrew_classes_v1';
  static const String keyHomebrewSubclasses = 'dn_homebrew_subclasses_v1';
  static const String keyHomebrewRaces = 'dn_homebrew_races_v1';
  static const String keyHomebrewSubraces = 'dn_homebrew_subraces_v1';
  static const String keyHomebrewFeats = 'dn_homebrew_feats_v1';
  static const String keyHomebrewBackgrounds = 'dn_homebrew_backgrounds_v1';
  static const String keyHomebrewOther = 'dn_homebrew_other_v1';
  static const String keyHomebrewFluff = 'dn_homebrew_fluff_v1';
  static const String keyCampaignOverrides = 'dn_campaign_overrides_v1';

  // Raw payload keys — store original source JSON for lossless re-parsing.
  static const String keyHomebrewSpellsRaw = 'dn_homebrew_spells_raw_v1';
  static const String keyHomebrewMonstersRaw = 'dn_homebrew_monsters_raw_v1';
  static const String keyHomebrewItemsRaw = 'dn_homebrew_items_raw_v1';
  static const String keyHomebrewClassesRaw = 'dn_homebrew_classes_raw_v1';
  static const String keyHomebrewSubclassesRaw =
      'dn_homebrew_subclasses_raw_v1';
  static const String keyHomebrewRacesRaw = 'dn_homebrew_races_raw_v1';
  static const String keyHomebrewSubracesRaw = 'dn_homebrew_subraces_raw_v1';
  static const String keyHomebrewFeatsRaw = 'dn_homebrew_feats_raw_v1';
  static const String keyHomebrewBackgroundsRaw =
      'dn_homebrew_backgrounds_raw_v1';
  static const String keyHomebrewOtherRaw = 'dn_homebrew_other_raw_v1';
  static const String keyHomebrewFluffRaw = 'dn_homebrew_fluff_raw_v1';

  static const List<EntityType> reparsableTypes = [
    EntityType.spell,
    EntityType.monster,
    EntityType.equipment,
    EntityType.classDefinition,
    EntityType.subclass,
    EntityType.species,
    EntityType.feat,
    EntityType.background,
    EntityType.custom,
  ];

  final Map<String, Map<String, int>> categorySlugIndex = {};

  AppDatabaseService get db => AppDatabaseService.instance;

  void invalidateCategoryCache(String parsedKey, [String? rawKey]) {
    categorySlugIndex.remove(parsedKey);
  }

  void invalidateAllCaches() {
    categorySlugIndex.clear();
  }

  Future<List<String>> loadStringList(String key) async {
    try {
      if (db.isBoxOpen(AppDatabaseService.boxHomebrew)) {
        final dbVal = db.get(AppDatabaseService.boxHomebrew, key);
        if (dbVal is List) {
          return dbVal.map((e) => e.toString()).toList();
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? <String>[];
      if (list.isNotEmpty && db.isBoxOpen(AppDatabaseService.boxHomebrew)) {
        await db.put(AppDatabaseService.boxHomebrew, key, list);
      }
      return list;
    } catch (e, st) {
      LoggingService()
          .logNonFatal(e, st, reason: 'Failed to load string list for $key');
      return [];
    }
  }

  Future<void> saveStringList(String key, List<String> list) async {
    try {
      categorySlugIndex.remove(key);
      final hiveOpen = db.isBoxOpen(AppDatabaseService.boxHomebrew);
      if (hiveOpen) {
        await db.put(AppDatabaseService.boxHomebrew, key, list);
      }
      try {
        // SharedPreferences has strict transaction buffer and memory limits.
        // When Hive is active, avoid mirroring large lists (>20 items) into SharedPreferences to eliminate ANRs/crashes.
        if (!hiveOpen || list.length <= 20) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(key, list);
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to mirror string list to SharedPreferences for $key',
        );
      }
    } catch (e, st) {
      LoggingService()
          .logNonFatal(e, st, reason: 'Failed to save string list for $key');
    }
  }

  /// Loads the raw source JSON payloads for the given [EntityType].
  /// Returns an empty list for entities without raw payloads (imported before
  /// raw storage was added).
  Future<List<Map<String, dynamic>>> loadRawPayloads(EntityType type) async {
    final key = rawKeyForType(type);
    if (key == null) return [];
    try {
      if (db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        final dbVal = db.get(AppDatabaseService.boxHomebrewRaw, key);
        if (dbVal is Map) {
          return dbVal.values
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        } else if (dbVal is String && dbVal.isNotEmpty) {
          final decoded = json.decode(dbVal) as Map<String, dynamic>;
          return decoded.values
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(key);
      if (stored == null || stored.isEmpty) return [];
      final decoded = json.decode(stored) as Map<String, dynamic>;
      if (db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        await db.put(AppDatabaseService.boxHomebrewRaw, key, decoded);
      }
      return decoded.values
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e, st) {
      LoggingService()
          .logNonFatal(e, st, reason: 'Failed to load raw payloads for $type');
      return [];
    }
  }

  /// Returns how many entities of [type] have stored raw payloads.
  Future<int> rawPayloadCount(EntityType type) async {
    final payloads = await loadRawPayloads(type);
    return payloads.length;
  }

  /// Saves multiple raw JSON payloads keyed by entity slug in a single batch transaction.
  Future<void> saveRawPayloadsBatch(
    String key,
    Map<String, Map<String, dynamic>> payloadsBySlug, [
    SharedPreferences? prefs,
  ]) async {
    if (payloadsBySlug.isEmpty) return;
    try {
      Map<String, dynamic> map = {};
      if (db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        final dbVal = db.get(AppDatabaseService.boxHomebrewRaw, key);
        if (dbVal is Map) {
          map = Map<String, dynamic>.from(dbVal);
        } else if (dbVal is String && dbVal.isNotEmpty) {
          map = Map<String, dynamic>.from(json.decode(dbVal) as Map);
        }
      }
      if (map.isEmpty) {
        final p = prefs ?? await SharedPreferences.getInstance();
        final existing = p.getString(key);
        if (existing != null && existing.isNotEmpty) {
          map = Map<String, dynamic>.from(json.decode(existing) as Map);
        }
      }

      map.addAll(payloadsBySlug);
      final hiveOpen = db.isBoxOpen(AppDatabaseService.boxHomebrewRaw);
      if (hiveOpen) {
        await db.put(AppDatabaseService.boxHomebrewRaw, key, map);
      }

      try {
        // Suppress mirroring large raw payload dictionaries (>20 items) into SharedPreferences to avoid OOM / TransactionTooLarge crashes.
        if (!hiveOpen || map.length <= 20) {
          final p = prefs ?? await SharedPreferences.getInstance();
          await p.setString(key, json.encode(map));
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason:
              'Failed to mirror batch raw payloads to SharedPreferences for $key',
        );
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to batch save raw payloads for $key');
    }
  }

  /// Public accessor to save a single raw JSON payload for homebrew entities.
  Future<void> saveCustomRawPayload(
    String key,
    String entitySlug,
    Map<String, dynamic> rawPayload,
  ) async {
    await saveRawPayload(key, entitySlug, rawPayload);
  }

  /// Saves a single raw JSON payload keyed by [entitySlug].
  /// Uses a `Map<slug, rawJson>` stored in database and syncs to SharedPreferences.
  Future<void> saveRawPayload(
    String key,
    String entitySlug,
    Map<String, dynamic> rawPayload, [
    SharedPreferences? prefs,
  ]) async {
    await saveRawPayloadsBatch(key, {entitySlug: rawPayload}, prefs);
  }

  /// Removes the raw payload for [entitySlug] from [key].
  Future<void> deleteRawPayload(
    String key,
    String entitySlug, [
    SharedPreferences? prefs,
  ]) async {
    try {
      Map<String, dynamic> map = {};
      final hiveOpen = db.isBoxOpen(AppDatabaseService.boxHomebrewRaw);
      if (hiveOpen) {
        final dbVal = db.get(AppDatabaseService.boxHomebrewRaw, key);
        if (dbVal is Map) {
          map = Map<String, dynamic>.from(dbVal);
        } else if (dbVal is String && dbVal.isNotEmpty) {
          map = Map<String, dynamic>.from(json.decode(dbVal) as Map);
        }
        map.remove(entitySlug);
        await db.put(AppDatabaseService.boxHomebrewRaw, key, map);
      }

      try {
        if (!hiveOpen || map.length <= 20) {
          final p = prefs ?? await SharedPreferences.getInstance();
          final existing = p.getString(key);
          if (existing != null && existing.isNotEmpty) {
            final pMap =
                Map<String, dynamic>.from(json.decode(existing) as Map);
            pMap.remove(entitySlug);
            await p.setString(key, json.encode(pMap));
          }
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason:
              'Failed to mirror delete raw payload to SharedPreferences for $key / $entitySlug',
        );
      }
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to delete raw payload for $key / $entitySlug',
      );
    }
  }

  /// Maps an [EntityType] to its raw payload key.
  String? rawKeyForType(EntityType type) => switch (type) {
        EntityType.spell => keyHomebrewSpellsRaw,
        EntityType.monster => keyHomebrewMonstersRaw,
        EntityType.equipment => keyHomebrewItemsRaw,
        EntityType.classDefinition => keyHomebrewClassesRaw,
        EntityType.subclass => keyHomebrewSubclassesRaw,
        EntityType.species => keyHomebrewRacesRaw,
        EntityType.feat => keyHomebrewFeatsRaw,
        EntityType.background => keyHomebrewBackgroundsRaw,
        EntityType.custom => keyHomebrewOtherRaw,
        _ => null,
      };

  /// Maps an [EntityType] to its parsed entity key.
  String? parsedKeyForType(EntityType type) => switch (type) {
        EntityType.spell => keyHomebrewSpells,
        EntityType.monster => keyHomebrewMonsters,
        EntityType.equipment => keyHomebrewItems,
        EntityType.classDefinition => keyHomebrewClasses,
        EntityType.subclass => keyHomebrewSubclasses,
        EntityType.species => keyHomebrewRaces,
        EntityType.feat => keyHomebrewFeats,
        EntityType.background => keyHomebrewBackgrounds,
        EntityType.custom => keyHomebrewOther,
        _ => null,
      };
}
