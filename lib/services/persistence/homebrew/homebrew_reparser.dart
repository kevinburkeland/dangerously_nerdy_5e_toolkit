import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/monster_codex_data.dart';
import '../../../models/spellbook_data.dart';
import '../../acl/compendium_background_parser.dart';
import '../../acl/compendium_class_parser.dart';
import '../../acl/compendium_feat_parser.dart';
import '../../acl/compendium_generic_entry_parser.dart';
import '../../acl/compendium_item_parser.dart';
import '../../acl/compendium_monster_parser.dart';
import '../../acl/compendium_race_parser.dart';
import '../../acl/compendium_spell_parser.dart';
import '../../acl/srd_equivalence_index.dart';
import '../../logging_service.dart';
import '../app_database_service.dart';
import '../character_persistence_service.dart';
import 'homebrew_raw_payload_store.dart';

/// Re-parse engine that rebuilds stored homebrew categories from raw source JSON
/// payloads using the latest parsers and SRD equivalence filter.
class HomebrewReparser {
  HomebrewReparser({
    required this.rawStore,
    required this.loadCustomSpells,
    required this.loadCustomMonsters,
    required this.loadCustomItems,
    required this.loadCustomClasses,
    required this.loadCustomSubclasses,
    required this.loadCustomRaces,
    required this.loadCustomFeats,
    required this.loadCustomBackgrounds,
    required this.loadCustomOtherEntries,
    required this.syncToLibraries,
  });

  final HomebrewRawPayloadStore rawStore;
  final Future<List<Spell>> Function() loadCustomSpells;
  final Future<List<Monster>> Function() loadCustomMonsters;
  final Future<List<EquipmentItem>> Function() loadCustomItems;
  final Future<List<CharacterClass>> Function() loadCustomClasses;
  final Future<List<Subclass>> Function() loadCustomSubclasses;
  final Future<List<Race>> Function() loadCustomRaces;
  final Future<List<Feat>> Function() loadCustomFeats;
  final Future<List<Background>> Function() loadCustomBackgrounds;
  final Future<List<HomebrewCompendiumEntry>> Function() loadCustomOtherEntries;
  final Future<void> Function() syncToLibraries;

  AppDatabaseService get _db => rawStore.db;

  /// Re-parses all homebrew entities that have raw payloads using the latest
  /// parser logic and SRD equivalence filter.
  ///
  /// Returns a [ReparseResult] describing what changed.
  Future<ReparseResult> reparseAllHomebrew() async {
    final srdIndex = SrdEquivalenceIndex();
    srdIndex.build();

    int updated = 0;
    int srdRemoved = 0;
    int noPayload = 0;

    // Count entities without raw payloads (so the UI can report it)
    for (final type in HomebrewRawPayloadStore.reparsableTypes) {
      final payloads = await rawStore.loadRawPayloads(type);
      final entities = await _loadEntitiesForType(type);
      noPayload += entities.length - payloads.length;
    }

    // Re-parse spells
    final spellParser = CompendiumSpellParser();
    updated += await _reparseCategory<Spell>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewSpellsRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewSpells,
      fromRaw: (raw) => spellParser.parseSpell(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.spell,
      onSrdRemoved: (slug) {
        srdRemoved++;
      },
    );

    // Re-parse monsters
    final monsterParser = CompendiumMonsterParser();
    updated += await _reparseCategory<Monster>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewMonstersRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewMonsters,
      fromRaw: (raw) => monsterParser.parseMonster(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.monster,
      onSrdRemoved: (slug) {
        srdRemoved++;
        MonsterCodexLibrary.removeHomebrewMonster(slug);
      },
    );

    // Re-parse items
    updated += await _reparseCategory<EquipmentItem>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewItemsRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewItems,
      fromRaw: (raw) => CompendiumItemParser().parseItem(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.equipment,
    );

    // Re-parse classes
    final classParser = CompendiumClassParser();
    updated += await _reparseCategory<CharacterClass>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewClassesRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewClasses,
      fromRaw: (raw) => classParser.parseClass(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.classDefinition,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdClassesLibrary.removeCustomClass(slug);
      },
    );

    // Hydrate subclass features from raw payloads if available before re-parsing subclasses
    final rawOthers = await rawStore.loadRawPayloads(EntityType.custom);
    for (final raw in rawOthers) {
      final t = (raw['entityType'] ?? raw['type'] ?? raw['category'] ?? '')
          .toString()
          .toLowerCase();
      if (t.contains('subclassfeature') ||
          raw.containsKey('subclassShortName') ||
          raw.containsKey('subclass')) {
        SrdClassesLibrary.registerSubclassFeature(raw);
      }
    }

    // Ensure subclass features inadvertently stored in subclasses raw box are registered and migrated
    final rawSubclasses = await rawStore.loadRawPayloads(EntityType.subclass);
    final featuresToMigrate = <String, Map<String, dynamic>>{};
    for (final raw in rawSubclasses) {
      final t =
          (raw['entityType'] ?? raw['type'] ?? '').toString().toLowerCase();
      final isFeature = t.contains('subclassfeature') ||
          raw['gainSubclassFeature'] == true ||
          (raw.containsKey('subclassShortName') &&
              !raw.containsKey('subclassFeatures'));
      if (isFeature) {
        SrdClassesLibrary.registerSubclassFeature(raw);
        final slug = (raw['id'] ??
                raw['slug'] ??
                (raw['name']?.toString() ?? '')
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '-'))
            .toString();
        featuresToMigrate[slug] = raw;
      }
    }
    if (featuresToMigrate.isNotEmpty) {
      for (final slug in featuresToMigrate.keys) {
        await rawStore.deleteRawPayload(
            HomebrewRawPayloadStore.keyHomebrewSubclassesRaw, slug);
      }
      await rawStore.saveRawPayloadsBatch(
          HomebrewRawPayloadStore.keyHomebrewOtherRaw, featuresToMigrate);
    }

    // Re-parse subclasses
    updated += await _reparseCategory<Subclass>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewSubclassesRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewSubclasses,
      fromRaw: (raw) => classParser.parseSubclass(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.subclass,
    );

    // Re-parse races
    updated += await _reparseCategory<Race>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewRacesRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewRaces,
      fromRaw: (raw) => CompendiumRaceParser().parseRace(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.species,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdSpeciesLibrary.removeCustomSpecies(slug);
      },
    );

    // Re-parse subraces
    updated += await _reparseCategory<Subrace>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewSubracesRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewSubraces,
      fromRaw: (raw) => CompendiumRaceParser().parseSubrace(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.species,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdSpeciesLibrary.removeCustomSubrace(slug);
      },
    );

    // Re-parse feats
    updated += await _reparseCategory<Feat>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewFeatsRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewFeats,
      fromRaw: (raw) => CompendiumFeatParser().parseFeat(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.feat,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdFeatsLibrary.removeCustomFeat(slug);
      },
    );

    // Re-parse backgrounds
    updated += await _reparseCategory<Background>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewBackgroundsRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewBackgrounds,
      fromRaw: (raw) => CompendiumBackgroundParser().parseBackground(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.background,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdBackgroundsLibrary.removeCustomBackground(slug);
      },
    );

    // Re-parse rules and other entries
    final genericParser = CompendiumGenericEntryParser();
    updated += await _reparseCategory<HomebrewCompendiumEntry>(
      rawKey: HomebrewRawPayloadStore.keyHomebrewOtherRaw,
      parsedKey: HomebrewRawPayloadStore.keyHomebrewOther,
      fromRaw: (raw) => genericParser.parseGenericEntry(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.custom,
      onSrdRemoved: (slug) {
        srdRemoved++;
      },
    );

    rawStore.invalidateAllCaches();
    await syncToLibraries();
    srdIndex.invalidate();

    // Automatically reparse existing characters in roster to inherit updated homebrew
    try {
      await CharacterPersistenceService().reparseAllCharacters();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to reparse character roster during homebrew reparse');
    }

    return ReparseResult(
      updatedCount: updated,
      srdRemovedCount: srdRemoved,
      noPayloadCount: noPayload,
    );
  }

  Future<List<DomainEntity>> _loadEntitiesForType(EntityType type) async {
    return switch (type) {
      EntityType.spell => await loadCustomSpells(),
      EntityType.monster => await loadCustomMonsters(),
      EntityType.equipment => await loadCustomItems(),
      EntityType.classDefinition => await loadCustomClasses(),
      EntityType.subclass => await loadCustomSubclasses(),
      EntityType.species => await loadCustomRaces(),
      EntityType.feat => await loadCustomFeats(),
      EntityType.background => await loadCustomBackgrounds(),
      EntityType.custom => await loadCustomOtherEntries(),
      _ => const <DomainEntity>[],
    };
  }

  /// Generic re-parse engine for a single category.
  Future<int> _reparseCategory<T extends DomainEntity>({
    required String rawKey,
    required String parsedKey,
    required T Function(Map<String, dynamic>) fromRaw,
    required String Function(T) toJson,
    required SrdEquivalenceIndex srdIndex,
    required EntityType entityType,
    void Function(String slug)? onSrdRemoved,
  }) async {
    try {
      Map<String, dynamic> rawMap = {};
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        final dbVal = _db.get(AppDatabaseService.boxHomebrewRaw, rawKey);
        if (dbVal is Map) {
          rawMap = Map<String, dynamic>.from(dbVal);
        } else if (dbVal is String && dbVal.isNotEmpty) {
          try {
            rawMap = Map<String, dynamic>.from(json.decode(dbVal) as Map);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Failed to JSON decode dbVal rawMap for $rawKey',
            );
          }
        }
      }
      if (rawMap.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final storedRaw = prefs.getString(rawKey);
        if (storedRaw != null && storedRaw.isNotEmpty) {
          try {
            rawMap = Map<String, dynamic>.from(json.decode(storedRaw) as Map);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Failed to JSON decode storedRaw rawMap for $rawKey',
            );
          }
        }
      }

      final reparsed = <T>[];
      final slugsToPrune = <String>{};
      final seenSlugs = <String>{};

      // 1. Re-parse from raw JSON payloads where available
      for (final entry in rawMap.entries) {
        final rawPayload = Map<String, dynamic>.from(entry.value as Map);
        try {
          final entity = fromRaw(rawPayload);
          final srdResult = srdIndex.checkEntity(
            slug: entity.id.slug,
            name: entity.name,
            type: entityType,
          );
          if (srdResult != SrdMatchResult.notSrd) {
            slugsToPrune.add(entry.key);
            slugsToPrune.add(entity.id.slug);
            onSrdRemoved?.call(entity.id.slug);
            continue;
          }
          if (seenSlugs.contains(entity.id.slug)) {
            continue;
          }
          seenSlugs.add(entity.id.slug);
          reparsed.add(entity);
        } catch (e, st) {
          LoggingService()
              .logNonFatal(e, st, reason: 'Re-parse failed for ${entry.key}');
        }
      }

      // 2. Remove pruned SRD keys from rawMap and save back
      if (slugsToPrune.isNotEmpty) {
        for (final slug in slugsToPrune) {
          rawMap.remove(slug);
        }
        if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
          await _db.put(AppDatabaseService.boxHomebrewRaw, rawKey, rawMap);
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(rawKey, json.encode(rawMap));
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason:
                'Failed to persist pruned rawMap to SharedPreferences for $rawKey',
          );
        }
      }

      // 3. Check legacy parsed store for any SRD duplicates not in rawMap
      final existingParsed = await rawStore.loadStringList(parsedKey);
      final allSlugsHandled = <String>{
        ...seenSlugs,
        ...slugsToPrune,
      };
      if (entityType == EntityType.subclass) {
        for (final s in seenSlugs) {
          if (s.contains('-')) {
            // "fighter-champion" -> also mark "champion" as handled
            allSlugsHandled.add(s.split('-').skip(1).join('-'));
          }
        }
      }

      for (final jsonStr in existingParsed) {
        try {
          final decoded = json.decode(jsonStr) as Map<String, dynamic>;
          final idObj = decoded['id'];
          final slug = idObj is Map
              ? (idObj['slug']?.toString() ?? '')
              : (decoded['slug']?.toString() ?? '');
          final name = decoded['name']?.toString() ?? '';

          if (slug.isNotEmpty &&
              !allSlugsHandled.contains(slug) &&
              !seenSlugs.contains(slug)) {
            final srdResult = srdIndex.checkEntity(
              slug: slug,
              name: name,
              type: entityType,
            );
            if (srdResult != SrdMatchResult.notSrd) {
              onSrdRemoved?.call(slug);
              allSlugsHandled.add(slug);
              continue;
            }
            // Keep non-SRD legacy entity
            T? legacyEntity;
            try {
              legacyEntity = fromRaw(decoded);
            } catch (_) {
              legacyEntity = _restoreLegacyEntity<T>(decoded, entityType);
            }
            if (legacyEntity != null &&
                !seenSlugs.contains(legacyEntity.id.slug)) {
              seenSlugs.add(legacyEntity.id.slug);
              allSlugsHandled.add(slug);
              reparsed.add(legacyEntity);
            }
            allSlugsHandled.add(slug);
          }
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Failed to parse legacy JSON entry in $parsedKey',
          );
        }
      }

      await rawStore.saveStringList(parsedKey, reparsed.map(toJson).toList());
      return reparsed.length;
    } catch (e, st) {
      LoggingService()
          .logNonFatal(e, st, reason: 'Re-parse category $entityType failed');
      return 0;
    }
  }

  T? _restoreLegacyEntity<T extends DomainEntity>(
      Map<String, dynamic> map, EntityType type) {
    try {
      return switch (type) {
        EntityType.spell => Spell.fromMap(map) as T,
        EntityType.monster => Monster.fromMap(map) as T,
        EntityType.equipment => EquipmentItem.fromMap(map) as T,
        EntityType.classDefinition => CharacterClass.fromMap(map) as T,
        EntityType.subclass => Subclass.fromMap(map) as T,
        EntityType.species => (map.containsKey('raceSlug')
            ? Subrace.fromMap(map)
            : Race.fromMap(map)) as T,
        EntityType.feat => Feat.fromMap(map) as T,
        EntityType.background => Background.fromMap(map) as T,
        EntityType.custom => HomebrewCompendiumEntry.fromMap(map) as T,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

/// Result of a repository-wide homebrew re-parse operation.
class ReparseResult {
  /// Number of entities successfully re-parsed and updated.
  final int updatedCount;

  /// Number of entities removed because they matched an SRD canonical entry.
  final int srdRemovedCount;

  /// Number of entities that could NOT be re-parsed because they were imported
  /// before raw payload storage was added.
  final int noPayloadCount;

  const ReparseResult({
    required this.updatedCount,
    required this.srdRemovedCount,
    required this.noPayloadCount,
  });

  bool get hadSrdRemovals => srdRemovedCount > 0;
  bool get hasUnreparseableEntities => noPayloadCount > 0;

  @override
  String toString() =>
      'ReparseResult(updated=$updatedCount, srdRemoved=$srdRemovedCount, noPayload=$noPayloadCount)';
}
