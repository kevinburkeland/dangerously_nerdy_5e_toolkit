import 'dart:convert';

import 'package:vtt_engine_core/homebrew/models/homebrew_entity.dart';

import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/homebrew_bundle.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/homebrew_other_category.dart';
import '../../models/magic_items/magic_item_library.dart';
import '../../models/monster_codex_data.dart';
import '../../models/tables/rollable_table.dart';
import '../acl/homebrew_merge_resolver.dart';
import '../fluff/entity_fluff_service.dart';
import '../repository/layered_priority_repository.dart';
import 'homebrew/homebrew_bundle_io.dart';
import 'homebrew/homebrew_category_store.dart';
import 'homebrew/homebrew_clearing.dart';
import 'homebrew/homebrew_compendium_mappers.dart';
import 'homebrew/homebrew_library_sync.dart';
import 'homebrew/homebrew_raw_payload_store.dart';
import 'homebrew/homebrew_remote_batch_saver.dart';
import 'homebrew/homebrew_reparser.dart';

export 'homebrew/homebrew_reparser.dart' show ReparseResult;

/// Service managing persistent storage and repository hydration for user-created homebrew and campaign overrides.
class HomebrewPersistenceService {
  static final HomebrewPersistenceService _instance =
      HomebrewPersistenceService._internal();
  factory HomebrewPersistenceService() => _instance;
  HomebrewPersistenceService._internal();

  final HomebrewRawPayloadStore _rawStore = HomebrewRawPayloadStore();

  static bool _isValidOtherEntry(HomebrewCompendiumEntry e) =>
      !e.name.startsWith('[{') &&
      e.name.length <= 500 &&
      e.id.slug.length <= 200;

  late final HomebrewCategoryStore<Spell> _spellsStore = HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewSpells,
    rawKey: HomebrewRawPayloadStore.keyHomebrewSpellsRaw,
    fromMap: Spell.fromMap,
    toMap: (s) => s.toMap(),
    getEntityKey: (s) => '${s.id.slug}_${s.id.ruleset.name}',
    getEntitySlug: (s) => s.id.slug,
    corruptedReason: 'Corrupted spell skipped in loadCustomSpells',
    loadFailedReason: 'Failed to load homebrew spells',
  );

  late final HomebrewCategoryStore<Monster> _monstersStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewMonsters,
    rawKey: HomebrewRawPayloadStore.keyHomebrewMonstersRaw,
    fromMap: Monster.fromMap,
    toMap: (m) => m.toMap(),
    getEntityKey: (m) => '${m.id.slug}_${m.id.ruleset.name}',
    getEntitySlug: (m) => m.id.slug,
    corruptedReason: 'Corrupted monster skipped in loadCustomMonsters',
    loadFailedReason: 'Failed to load homebrew monsters',
  );

  late final HomebrewCategoryStore<EquipmentItem> _itemsStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewItems,
    rawKey: HomebrewRawPayloadStore.keyHomebrewItemsRaw,
    fromMap: EquipmentItem.fromMap,
    toMap: (i) => i.toMap(),
    getEntityKey: (i) => '${i.id.slug}_${i.id.ruleset.name}',
    getEntitySlug: (i) => i.id.slug,
    corruptedReason: 'Corrupted item skipped in loadCustomItems',
    loadFailedReason: 'Failed to load homebrew items',
  );

  late final HomebrewCategoryStore<CharacterClass> _classesStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewClasses,
    rawKey: HomebrewRawPayloadStore.keyHomebrewClassesRaw,
    fromMap: CharacterClass.fromMap,
    toMap: (c) => c.toMap(),
    getEntityKey: (c) => '${c.id.slug}_${c.id.ruleset.name}',
    getEntitySlug: (c) => c.id.slug,
    corruptedReason: 'Corrupted class skipped in loadCustomClasses',
    loadFailedReason: 'Failed to load homebrew classes',
  );

  late final HomebrewCategoryStore<Subclass> _subclassesStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewSubclasses,
    rawKey: HomebrewRawPayloadStore.keyHomebrewSubclassesRaw,
    fromMap: Subclass.fromMap,
    toMap: (s) => s.toMap(),
    getEntityKey: (s) => '${s.id.slug}_${s.id.ruleset.name}',
    getEntitySlug: (s) => s.id.slug,
    corruptedReason: 'Corrupted subclass skipped in loadCustomSubclasses',
    loadFailedReason: 'Failed to load homebrew subclasses',
  );

  late final HomebrewCategoryStore<Race> _racesStore = HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewRaces,
    rawKey: HomebrewRawPayloadStore.keyHomebrewRacesRaw,
    fromMap: Race.fromMap,
    toMap: (r) => r.toMap(),
    getEntityKey: (r) => '${r.id.slug}_${r.id.ruleset.name}',
    getEntitySlug: (r) => r.id.slug,
    corruptedReason: 'Corrupted race skipped in loadCustomRaces',
    loadFailedReason: 'Failed to load homebrew races',
    mergeOnReplace: (existing, incoming) {
      final subMap = <String, Subrace>{
        for (final s in existing.subraces) s.id.slug: s,
        for (final s in incoming.subraces) s.id.slug: s,
      };
      return incoming.copyWith(
        traitsMarkdown: incoming.traitsMarkdown.isNotEmpty
            ? incoming.traitsMarkdown
            : existing.traitsMarkdown,
        subraces: subMap.values.toList(),
      );
    },
  );

  late final HomebrewCategoryStore<Subrace> _subracesStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewSubraces,
    rawKey: HomebrewRawPayloadStore.keyHomebrewSubracesRaw,
    fromMap: Subrace.fromMap,
    toMap: (s) => s.toMap(),
    getEntityKey: (s) => '${s.id.slug}_${s.id.ruleset.name}',
    getEntitySlug: (s) => s.id.slug,
    corruptedReason: 'Corrupted subrace skipped in loadCustomSubraces',
    loadFailedReason: 'Failed to load homebrew subraces',
  );

  late final HomebrewCategoryStore<Feat> _featsStore = HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewFeats,
    rawKey: HomebrewRawPayloadStore.keyHomebrewFeatsRaw,
    fromMap: Feat.fromMap,
    toMap: (f) => f.toMap(),
    getEntityKey: (f) => '${f.id.slug}_${f.id.ruleset.name}',
    getEntitySlug: (f) => f.id.slug,
    corruptedReason: 'Corrupted feat skipped in loadCustomFeats',
    loadFailedReason: 'Failed to load homebrew feats',
  );

  late final HomebrewCategoryStore<Background> _backgroundsStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewBackgrounds,
    rawKey: HomebrewRawPayloadStore.keyHomebrewBackgroundsRaw,
    fromMap: Background.fromMap,
    toMap: (b) => b.toMap(),
    getEntityKey: (b) => '${b.id.slug}_${b.id.ruleset.name}',
    getEntitySlug: (b) => b.id.slug,
    corruptedReason: 'Corrupted background skipped in loadCustomBackgrounds',
    loadFailedReason: 'Failed to load homebrew backgrounds',
  );

  late final HomebrewCategoryStore<HomebrewCompendiumEntry> _otherStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewOther,
    rawKey: HomebrewRawPayloadStore.keyHomebrewOtherRaw,
    fromMap: HomebrewCompendiumEntry.fromMap,
    toMap: (e) => e.toMap(),
    getEntityKey: (e) => '${e.id.slug}_${e.id.ruleset.name}',
    getEntitySlug: (e) => e.id.slug,
    corruptedReason: 'Corrupted other entry skipped in loadCustomOtherEntries',
    loadFailedReason: 'Failed to load homebrew custom entries',
    isValid: _isValidOtherEntry,
  );

  late final HomebrewCategoryStore<EntityFluff> _fluffStore =
      HomebrewCategoryStore(
    rawStore: _rawStore,
    parsedKey: HomebrewRawPayloadStore.keyHomebrewFluff,
    rawKey: HomebrewRawPayloadStore.keyHomebrewFluffRaw,
    fromMap: EntityFluff.fromMap,
    toMap: (f) => f.toMap(),
    getEntityKey: (f) => '${f.entityType}_${f.slug}',
    getEntitySlug: (f) => '${f.entityType}_${f.slug}',
    corruptedReason: 'Corrupted fluff skipped in loadCustomFluff',
    loadFailedReason: 'Failed to load homebrew fluff',
  );

  late final HomebrewLibrarySync _librarySync = HomebrewLibrarySync(
    loadCustomSpells: loadCustomSpells,
    loadCustomMonsters: loadCustomMonsters,
    loadCustomItems: loadCustomItems,
    loadCustomRaces: loadCustomRaces,
    loadCustomSubraces: loadCustomSubraces,
    loadCustomFeats: loadCustomFeats,
    loadCustomClasses: loadCustomClasses,
    loadCustomSubclasses: loadCustomSubclasses,
    loadCustomBackgrounds: loadCustomBackgrounds,
    loadCustomOtherEntries: loadCustomOtherEntries,
    loadCustomFluff: loadCustomFluff,
  );

  late final HomebrewBundleIo _bundleIo = HomebrewBundleIo(
    rawStore: _rawStore,
    loadCustomSpells: loadCustomSpells,
    loadCustomMonsters: loadCustomMonsters,
    loadCustomItems: loadCustomItems,
    loadCustomClasses: loadCustomClasses,
    loadCustomSubclasses: loadCustomSubclasses,
    loadCustomRaces: loadCustomRaces,
    loadCustomSubraces: loadCustomSubraces,
    loadCustomFeats: loadCustomFeats,
    loadCustomBackgrounds: loadCustomBackgrounds,
    loadCustomOtherEntries: loadCustomOtherEntries,
    loadCustomFluff: loadCustomFluff,
    saveCustomFluffBatch: (fluff) => saveCustomFluffBatch(fluff),
    syncToLibraries: syncToLibraries,
  );

  late final HomebrewClearing _clearing = HomebrewClearing(
    rawStore: _rawStore,
    spellsStore: _spellsStore,
    monstersStore: _monstersStore,
    itemsStore: _itemsStore,
    classesStore: _classesStore,
    subclassesStore: _subclassesStore,
    racesStore: _racesStore,
    featsStore: _featsStore,
    backgroundsStore: _backgroundsStore,
    otherStore: _otherStore,
    loadCustomOtherEntries: loadCustomOtherEntries,
  );

  late final HomebrewReparser _reparser = HomebrewReparser(
    rawStore: _rawStore,
    loadCustomSpells: loadCustomSpells,
    loadCustomMonsters: loadCustomMonsters,
    loadCustomItems: loadCustomItems,
    loadCustomClasses: loadCustomClasses,
    loadCustomSubclasses: loadCustomSubclasses,
    loadCustomRaces: loadCustomRaces,
    loadCustomFeats: loadCustomFeats,
    loadCustomBackgrounds: loadCustomBackgrounds,
    loadCustomOtherEntries: loadCustomOtherEntries,
    syncToLibraries: syncToLibraries,
  );

  late final HomebrewRemoteBatchSaver _remoteBatchSaver =
      HomebrewRemoteBatchSaver(
    saveCustomSpellsBatch: saveCustomSpellsBatch,
    saveCustomMonstersBatch: saveCustomMonstersBatch,
    saveCustomItemsBatch: saveCustomItemsBatch,
    saveCustomClassesBatch: saveCustomClassesBatch,
    saveCustomSubclassesBatch: saveCustomSubclassesBatch,
    saveCustomRacesBatch: saveCustomRacesBatch,
    saveCustomSubracesBatch: saveCustomSubracesBatch,
    saveCustomFeatsBatch: saveCustomFeatsBatch,
    saveCustomBackgroundsBatch: saveCustomBackgroundsBatch,
    saveCustomOtherEntriesBatch: saveCustomOtherEntriesBatch,
    saveCustomFluffBatch: saveCustomFluffBatch,
    syncToLibraries: syncToLibraries,
  );

  void invalidateAllCaches() => _rawStore.invalidateAllCaches();

  /// Loads all custom spells from persistent storage.
  Future<List<Spell>> loadCustomSpells() => _spellsStore.loadAll();

  /// Saves a custom spell to persistent storage, optionally storing [rawPayload].
  Future<void> saveCustomSpell(Spell spell,
      {Map<String, dynamic>? rawPayload}) async {
    await saveCustomSpellsBatch(
      [spell],
      rawPayloads: rawPayload != null ? [rawPayload] : null,
    );
  }

  /// Batch saves multiple custom spells to persistent storage.
  Future<void> saveCustomSpellsBatch(
    List<Spell> newSpells, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _spellsStore.saveBatchFast(newSpells, rawPayloads: rawPayloads);
  }

  /// Deletes a custom spell by slug.
  Future<void> deleteCustomSpell(String slug) async {
    await _spellsStore.delete(slug);
  }

  /// Loads all custom monsters from persistent storage.
  Future<List<Monster>> loadCustomMonsters() => _monstersStore.loadAll();

  /// Synchronizes all loaded homebrew entities into global runtime libraries.
  Future<void> syncToLibraries() => _librarySync.syncToLibraries();

  /// Converts a generic [HomebrewCompendiumEntry] to a rollable [RollableTable].
  static RollableTable compendiumEntryToRollableTable(
          HomebrewCompendiumEntry entry) =>
      HomebrewCompendiumMappers.compendiumEntryToRollableTable(entry);

  /// Converts a generic [HomebrewCompendiumEntry] into a DM Screen reference card.
  static DmReferenceItem compendiumEntryToDmReferenceItem(
          HomebrewCompendiumEntry entry) =>
      HomebrewCompendiumMappers.compendiumEntryToDmReferenceItem(entry);

  /// Saves a custom monster to persistent storage and updates MonsterCodexLibrary.
  Future<void> saveCustomMonster(Monster monster,
      {Map<String, dynamic>? rawPayload}) async {
    await saveCustomMonstersBatch(
      [monster],
      rawPayloads: rawPayload != null ? [rawPayload] : null,
    );
  }

  /// Batch saves multiple custom monsters to persistent storage and updates MonsterCodexLibrary.
  Future<void> saveCustomMonstersBatch(
    List<Monster> newMonsters, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _monstersStore.saveBatchFast(
      newMonsters,
      rawPayloads: rawPayloads,
      onEntityAddedOrUpdated: (m) => MonsterCodexLibrary.addHomebrewMonster(m),
    );
  }

  /// Deletes a custom monster by slug and updates MonsterCodexLibrary.
  Future<void> deleteCustomMonster(String slug) async {
    await _monstersStore.delete(slug);
    MonsterCodexLibrary.removeHomebrewMonster(slug);
  }

  /// Loads all custom items from persistent storage.
  Future<List<EquipmentItem>> loadCustomItems() => _itemsStore.loadAll();

  /// Saves a custom item to persistent storage.
  Future<void> saveCustomItem(EquipmentItem item,
      {Map<String, dynamic>? rawPayload}) async {
    await _itemsStore.save(item, rawPayload: rawPayload);
  }

  /// Batch saves multiple custom items to persistent storage.
  Future<void> saveCustomItemsBatch(
    List<EquipmentItem> newItems, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _itemsStore.saveBatchFast(
      newItems,
      rawPayloads: rawPayloads,
      onEntityAddedOrUpdated: (i) => MagicItemLibrary.addHomebrewItem(i),
    );
  }

  /// Deletes a custom item by slug.
  Future<void> deleteCustomItem(String slug) async {
    await _itemsStore.delete(slug);
  }

  /// Loads all custom classes from persistent storage.
  Future<List<CharacterClass>> loadCustomClasses() => _classesStore.loadAll();

  /// Saves a custom class to persistent storage and runtime library.
  Future<void> saveCustomClass(CharacterClass characterClass,
      {Map<String, dynamic>? rawPayload}) async {
    await _classesStore.save(
      characterClass,
      rawPayload: rawPayload,
      onAfterSave: SrdClassesLibrary.addCustomClass,
    );
  }

  /// Batch saves multiple custom classes to persistent storage and runtime library.
  Future<void> saveCustomClassesBatch(
    List<CharacterClass> newClasses, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _classesStore.saveBatchList(
      newClasses,
      rawPayloads: rawPayloads,
      onEachInLoop: SrdClassesLibrary.addCustomClass,
    );
  }

  /// Deletes a custom class by slug and runtime library.
  Future<void> deleteCustomClass(String slug) async {
    await _classesStore.delete(slug, invalidateCache: false);
    SrdClassesLibrary.removeCustomClass(slug);
  }

  /// Loads all custom subclasses from persistent storage.
  Future<List<Subclass>> loadCustomSubclasses() => _subclassesStore.loadAll();

  /// Saves a custom subclass to persistent storage.
  Future<void> saveCustomSubclass(Subclass subclass,
      {Map<String, dynamic>? rawPayload}) async {
    await _subclassesStore.save(
      subclass,
      rawPayload: rawPayload,
      onAfterSave: SrdClassesLibrary.addCustomSubclass,
    );
  }

  /// Batch saves multiple custom subclasses to persistent storage.
  Future<void> saveCustomSubclassesBatch(
    List<Subclass> newSubclasses, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _subclassesStore.saveBatchList(newSubclasses,
        rawPayloads: rawPayloads);
    for (final s in newSubclasses) {
      SrdClassesLibrary.addCustomSubclass(s);
    }
  }

  /// Deletes a custom subclass by slug and runtime library.
  Future<void> deleteCustomSubclass(String slug) async {
    await _subclassesStore.delete(
      slug,
      invalidateCache: false,
      match: (s) =>
          s.id.slug == slug ||
          s.id.slug.endsWith('-$slug') ||
          (s.classSlug.isNotEmpty && s.id.slug == '${s.classSlug}-$slug'),
      onRemoved: (removed) async {
        for (final s in removed) {
          await _rawStore.deleteRawPayload(
              HomebrewRawPayloadStore.keyHomebrewSubclassesRaw, s.id.slug);
          SrdClassesLibrary.removeCustomSubclass(s.id.slug);
        }
      },
    );
    SrdClassesLibrary.removeCustomSubclass(slug);
  }

  /// Loads all custom races from persistent storage.
  Future<List<Race>> loadCustomRaces() => _racesStore.loadAll();

  /// Saves a custom race to persistent storage and runtime library.
  Future<void> saveCustomRace(Race race,
      {Map<String, dynamic>? rawPayload}) async {
    await _racesStore.save(
      race,
      rawPayload: rawPayload,
      onAfterSave: SrdSpeciesLibrary.addCustomSpecies,
    );
  }

  /// Batch saves multiple custom races to persistent storage and runtime library.
  Future<void> saveCustomRacesBatch(
    List<Race> newRaces, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _racesStore.saveBatchList(
      newRaces,
      rawPayloads: rawPayloads,
      onEachInLoop: SrdSpeciesLibrary.addCustomSpecies,
    );
  }

  /// Deletes a custom race by slug and runtime library.
  Future<void> deleteCustomRace(String slug) async {
    await _racesStore.delete(slug, invalidateCache: false);
    SrdSpeciesLibrary.removeCustomSpecies(slug);
  }

  /// Loads all custom standalone subraces from persistent storage.
  Future<List<Subrace>> loadCustomSubraces() => _subracesStore.loadAll();

  /// Saves a custom subrace to persistent storage and runtime library.
  Future<void> saveCustomSubrace(Subrace subrace,
      {Map<String, dynamic>? rawPayload}) async {
    await _subracesStore.save(
      subrace,
      rawPayload: rawPayload,
      onAfterSave: SrdSpeciesLibrary.addCustomSubrace,
    );
  }

  /// Batch saves multiple custom subraces to persistent storage and runtime library.
  Future<void> saveCustomSubracesBatch(
    List<Subrace> newSubraces, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _subracesStore.saveBatchList(
      newSubraces,
      rawPayloads: rawPayloads,
      onEachInLoop: SrdSpeciesLibrary.addCustomSubrace,
    );
  }

  /// Deletes a custom subrace by slug and runtime library.
  Future<void> deleteCustomSubrace(String slug) async {
    await _subracesStore.delete(slug, invalidateCache: false);
    SrdSpeciesLibrary.removeCustomSubrace(slug);
  }

  /// Loads all custom feats from persistent storage.
  Future<List<Feat>> loadCustomFeats() => _featsStore.loadAll();

  /// Saves a custom feat to persistent storage and runtime library.
  Future<void> saveCustomFeat(Feat feat,
      {Map<String, dynamic>? rawPayload}) async {
    await _featsStore.save(
      feat,
      rawPayload: rawPayload,
      onAfterSave: SrdFeatsLibrary.addCustomFeat,
    );
  }

  /// Batch saves multiple custom feats to persistent storage and runtime library.
  Future<void> saveCustomFeatsBatch(
    List<Feat> newFeats, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _featsStore.saveBatchFast(
      newFeats,
      rawPayloads: rawPayloads,
      onEntityAddedOrUpdated: (f) => SrdFeatsLibrary.addCustomFeat(f),
    );
  }

  /// Deletes a custom feat by slug and runtime library.
  Future<void> deleteCustomFeat(String slug) async {
    await _featsStore.delete(slug);
    SrdFeatsLibrary.removeCustomFeat(slug);
  }

  /// Loads all custom backgrounds from persistent storage.
  Future<List<Background>> loadCustomBackgrounds() =>
      _backgroundsStore.loadAll();

  /// Saves a custom background to persistent storage and runtime library.
  Future<void> saveCustomBackground(Background background,
      {Map<String, dynamic>? rawPayload}) async {
    await _backgroundsStore.save(
      background,
      rawPayload: rawPayload,
      onAfterSave: SrdBackgroundsLibrary.addCustomBackground,
    );
  }

  /// Batch saves multiple custom backgrounds to persistent storage and runtime library.
  Future<void> saveCustomBackgroundsBatch(
    List<Background> newBackgrounds, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    await _backgroundsStore.saveBatchFast(
      newBackgrounds,
      rawPayloads: rawPayloads,
      onEntityAddedOrUpdated: (b) => SrdBackgroundsLibrary.addCustomBackground(b),
    );
  }

  /// Deletes a custom background by slug and runtime library.
  Future<void> deleteCustomBackground(String slug) async {
    await _backgroundsStore.delete(slug);
    SrdBackgroundsLibrary.removeCustomBackground(slug);
  }

  /// Loads all custom generic entries (tables, rules, etc.) from persistent storage.
  Future<List<HomebrewCompendiumEntry>> loadCustomOtherEntries() =>
      _otherStore.loadAll();

  /// Saves a generic compendium entry to persistent storage.
  Future<void> saveCustomOtherEntry(HomebrewCompendiumEntry entry,
      {Map<String, dynamic>? rawPayload}) async {
    if (!_isValidOtherEntry(entry)) return;
    await _otherStore.save(
      entry,
      rawPayload: rawPayload,
      matchExisting: (existing, incoming) => existing.id.slug == incoming.id.slug,
    );
    final entries = await loadCustomOtherEntries();
    HomebrewLibrarySync.hydrateCustomOtherSubsystems(entries);
  }

  /// Batch saves multiple generic compendium entries to persistent storage.
  Future<void> saveCustomOtherEntriesBatch(
    List<HomebrewCompendiumEntry> newEntries, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (!newEntries.any(_isValidOtherEntry)) return;
    await _otherStore.saveBatchFast(newEntries, rawPayloads: rawPayloads);
    final all = await loadCustomOtherEntries();
    HomebrewLibrarySync.hydrateCustomOtherSubsystems(all);
  }

  /// Deletes a generic compendium entry by slug.
  Future<void> deleteCustomOtherEntry(String slug) async {
    final remaining = await _otherStore.delete(slug);
    HomebrewLibrarySync.hydrateCustomOtherSubsystems(remaining);
  }

  /// Toggles or sets the [isEnabled] active flag on an individual homebrew compendium entry (rule, table, etc.).
  ///
  /// Persists the updated collection and re-synchronizes runtime libraries so disabled rules are excluded.
  /// Returns the updated [isEnabled] state (or false if slug was not found).
  Future<bool> toggleOtherEntryEnabled(String slug, {bool? isEnabled}) async {
    final entries = await loadCustomOtherEntries();
    final idx = entries.indexWhere((e) => e.id.slug == slug);
    if (idx == -1) return false;

    final target = entries[idx];
    final newEnabled = isEnabled ?? !target.isEnabled;
    entries[idx] = target.copyWith(isEnabled: newEnabled);

    await _rawStore.saveStringList(
      HomebrewRawPayloadStore.keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );

    HomebrewLibrarySync.hydrateCustomOtherSubsystems(entries);
    return newEnabled;
  }

  /// Returns a map of counts for each granular [HomebrewOtherCategory] stored
  /// in the generic compendium collection.
  Future<Map<HomebrewOtherCategory, int>> loadOtherCategoryCounts() =>
      _clearing.loadOtherCategoryCounts();

  /// Prunes specified [HomebrewOtherCategory] subcategories from persistent storage
  /// while preserving all other custom entries and their raw payloads.
  ///
  /// Returns the number of entities removed.
  Future<int> clearOtherEntriesByCategories(
          Set<HomebrewOtherCategory> categories) =>
      _clearing.clearOtherEntriesByCategories(categories);

  /// Batch deletes multiple custom entities by [slugs] for the given [EntityType].
  /// Returns the number of entities removed.
  Future<int> deleteCustomEntitiesBatch(EntityType type, List<String> slugs) =>
      _clearing.deleteCustomEntitiesBatch(type, slugs);

  /// Loads all custom fluff/lore from persistent storage.
  Future<List<EntityFluff>> loadCustomFluff() async {
    final items = await _fluffStore.loadAll();
    if (items.isEmpty && EntityFluffService().fluffCount > 0) {
      return EntityFluffService().getAllFluff();
    }
    return items;
  }

  /// Batch saves fluff entries to persistent storage and updates runtime [EntityFluffService].
  Future<void> saveCustomFluffBatch(
    List<EntityFluff> newFluff, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newFluff.isEmpty) return;
    EntityFluffService().batchRegisterFluff(newFluff, saveToDisk: false);
    await _fluffStore.saveBatchFast(newFluff, rawPayloads: rawPayloads);
  }

  /// Exports saved homebrew entities into a portable [HomebrewBundle].
  Future<HomebrewBundle> exportHomebrewBundle({
    String? bundleName,
    String? author,
    String? description,
    Set<EntityType>? categories,
  }) =>
      _bundleIo.exportHomebrewBundle(
        bundleName: bundleName,
        author: author,
        description: description,
        categories: categories,
      );

  /// Exports saved homebrew entities across all active registries into a comprehensive
  /// dictionary with sibling arrays (`races`, `subraces`, `classes`, `subclasses`, `backgrounds`, `feats`, `items`, `spells`, `monsters`, `fluff`).
  Future<Map<String, dynamic>> exportBundle({
    String? bundleName,
    String? author,
    String? description,
    Set<EntityType>? categories,
  }) =>
      _bundleIo.exportBundle(
        bundleName: bundleName,
        author: author,
        description: description,
        categories: categories,
      );

  /// Imports an analyzed and resolved [ImportAnalysisResult], writing entities to storage
  /// according to user-selected collision resolutions, and syncs runtime libraries immediately.
  ///
  /// [onProgress] is called after every entity write with (saved, total).
  Future<void> importResolvedBundle(
    ImportAnalysisResult resolution, {
    void Function(int saved, int total, String phase)? onProgress,
  }) =>
      _bundleIo.importResolvedBundle(resolution, onProgress: onProgress);

  /// Hydrates a LayeredPriorityRepository with saved Homebrew and Campaign Overrides.
  Future<void> hydrateRepository(LayeredPriorityRepository repository) =>
      _librarySync.hydrateRepository(repository);

  /// Clears all saved homebrew and override data.
  Future<void> clearAllHomebrew() => _clearing.clearAllHomebrew();

  /// Purges all persisted data for a single [EntityType] category and
  /// refreshes the corresponding runtime library.
  ///
  /// Only [classDefinition], [subclass], [species], [feat], [background],
  /// [equipment], [spell], [monster], and [custom] are supported.
  Future<void> clearHomebrewCategory(EntityType type) =>
      _clearing.clearHomebrewCategory(type);

  /// Loads the raw source JSON payloads for the given [EntityType].
  /// Returns an empty list for entities without raw payloads (imported before
  /// raw storage was added).
  Future<List<Map<String, dynamic>>> loadRawPayloads(EntityType type) =>
      _rawStore.loadRawPayloads(type);

  /// Returns how many entities of [type] have stored raw payloads.
  Future<int> rawPayloadCount(EntityType type) => _rawStore.rawPayloadCount(type);

  /// Re-parses all homebrew entities that have raw payloads using the latest
  /// parser logic and SRD equivalence filter.
  ///
  /// Returns a [ReparseResult] describing what changed.
  Future<ReparseResult> reparseAllHomebrew() => _reparser.reparseAllHomebrew();

  /// Public accessor to save a single raw JSON payload for homebrew entities.
  Future<void> saveCustomRawPayload(
    String key,
    String entitySlug,
    Map<String, dynamic> rawPayload,
  ) =>
      _rawStore.saveCustomRawPayload(key, entitySlug, rawPayload);

  /// Persists a batch of [HomebrewEntity] items parsed from remote repositories
  /// into canonical storage collections and optionally synchronizes runtime libraries.
  Future<void> saveHomebrewEntitiesBatch(
    List<HomebrewEntity> entities, {
    bool syncLibraries = true,
    bool excludeSrdCanon = true,
  }) =>
      _remoteBatchSaver.saveHomebrewEntitiesBatch(
        entities,
        syncLibraries: syncLibraries,
        excludeSrdCanon: excludeSrdCanon,
      );

  /// Persists a single [HomebrewEntity] into canonical storage and optionally synchronizes libraries.
  Future<void> saveHomebrewEntity(
    HomebrewEntity entity, {
    bool syncLibraries = true,
  }) =>
      _remoteBatchSaver.saveHomebrewEntity(entity, syncLibraries: syncLibraries);
}
