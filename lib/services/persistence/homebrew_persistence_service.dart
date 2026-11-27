import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/homebrew/models/homebrew_entity.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/homebrew_bundle.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/homebrew_other_category.dart';
import '../../models/monster_codex_data.dart';
import '../../models/magic_items/magic_item_library.dart';
import '../../models/spellbook_data.dart';
import '../../models/tables/rollable_table.dart';
import '../../models/tables/srd_tables_library.dart';
import '../acl/compendium_background_parser.dart';
import '../acl/compendium_class_parser.dart';
import '../acl/compendium_feat_parser.dart';
import '../acl/compendium_generic_entry_parser.dart';
import '../acl/compendium_item_parser.dart';
import '../acl/compendium_monster_parser.dart';
import '../acl/compendium_race_parser.dart';
import '../acl/compendium_spell_parser.dart';
import '../acl/homebrew_merge_resolver.dart';
import '../acl/srd_equivalence_index.dart';
import '../importers/community_compendium_adapters.dart';
import 'character_persistence_service.dart';
import '../ingestion/compendium_json_ingestion_pipeline.dart';
import '../fluff/entity_fluff_service.dart';
import '../logging_service.dart';
import '../repository/layered_priority_repository.dart';
import 'app_database_service.dart';
import 'homebrew/homebrew_category_store.dart';
import 'homebrew/homebrew_compendium_mappers.dart';
import 'homebrew/homebrew_raw_payload_store.dart';

/// Service managing persistent storage and repository hydration for user-created homebrew and campaign overrides.
class HomebrewPersistenceService {
  static final HomebrewPersistenceService _instance =
      HomebrewPersistenceService._internal();
  factory HomebrewPersistenceService() => _instance;
  HomebrewPersistenceService._internal();

  final HomebrewRawPayloadStore _rawStore = HomebrewRawPayloadStore();
  AppDatabaseService get _db => _rawStore.db;

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

  void _invalidateCategoryCache(String parsedKey, [String? rawKey]) =>
      _rawStore.invalidateCategoryCache(parsedKey, rawKey);

  void invalidateAllCaches() => _rawStore.invalidateAllCaches();

  Future<List<String>> _loadStringList(String key) =>
      _rawStore.loadStringList(key);

  Future<void> _saveStringList(String key, List<String> list) =>
      _rawStore.saveStringList(key, list);

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
  Future<void> syncToLibraries() async {
    final spells = await loadCustomSpells();
    SpellbookLibrary.setHomebrewSpells(spells);

    final monsters = await loadCustomMonsters();
    MonsterCodexLibrary.setHomebrewMonsters(monsters);

    final items = await loadCustomItems();
    MagicItemLibrary.setHomebrewItems(items);

    final races = await loadCustomRaces();
    SrdSpeciesLibrary.setCustomSpecies(races);

    final customSubraces = <Subrace>[];
    for (final r in races) {
      customSubraces.addAll(r.subraces);
    }
    final standaloneSubs = await loadCustomSubraces();
    for (final s in standaloneSubs) {
      if (!customSubraces.any((sub) => sub.id.slug == s.id.slug)) {
        customSubraces.add(s);
      }
    }
    SrdSpeciesLibrary.setCustomSubraces(customSubraces);

    final feats = await loadCustomFeats();
    final revitalizedFeats = feats.map((f) {
      if (f.customProperties['selectableAbilities'] == null ||
          (f.customProperties['selectableAbilities'] is List &&
              (f.customProperties['selectableAbilities'] as List).isEmpty)) {
        final rawAbility =
            f.customProperties['ability'] ?? f.customProperties['abilities'];
        if (rawAbility != null) {
          final parsed = FeatAsiExtension.parseFeatAbilityData(rawAbility);
          if (parsed.selectableAbilities.isNotEmpty) {
            final updatedCp = Map<String, dynamic>.from(f.customProperties);
            updatedCp['selectableAbilities'] =
                parsed.selectableAbilities.map((a) => a.name).toList();
            updatedCp['statIncreaseAmount'] = parsed.amount;
            if (parsed.selectableAbilities.length == 1) {
              updatedCp['statIncreaseAbility'] =
                  parsed.selectableAbilities.first.name;
            }
            return f.copyWith(customProperties: updatedCp);
          }
        }
      }
      return f;
    }).toList();
    SrdFeatsLibrary.setCustomFeats(revitalizedFeats);

    final classes = await loadCustomClasses();
    final revitalizedClasses = classes.map((c) {
      if (c.grants.isEmpty) {
        final addSpells = c.customProperties['additionalSpells'] ??
            c.customProperties['spells'];
        if (addSpells != null) {
          final grants =
              FeatureGrant.extractBonusSpells(addSpells, 'class', c.id.slug);
          if (grants.isNotEmpty) return c.copyWith(grants: grants);
        }
      }
      return c;
    }).toList();
    SrdClassesLibrary.setCustomClasses(revitalizedClasses);

    final subclasses = await loadCustomSubclasses();
    final revitalizedSubclasses = subclasses.map((s) {
      if (s.grants.isEmpty) {
        final addSpells = s.customProperties['additionalSpells'] ??
            s.customProperties['subclassSpells'];
        if (addSpells != null) {
          final grants =
              FeatureGrant.extractBonusSpells(addSpells, 'subclass', s.id.slug);
          if (grants.isNotEmpty) return s.copyWith(grants: grants);
        }
      }
      return s;
    }).toList();
    SrdClassesLibrary.setCustomSubclasses(revitalizedSubclasses);

    final backgrounds = await loadCustomBackgrounds();
    SrdBackgroundsLibrary.setCustomBackgrounds(backgrounds);

    final others = await loadCustomOtherEntries();
    _hydrateCustomOtherSubsystems(others);

    final updatedSubs = SrdClassesLibrary.customSubclasses.map((s) {
      if (s.featuresMarkdown.isEmpty ||
          s.featuresMarkdown.contains('Granted at level')) {
        final stitched = SrdClassesLibrary.buildFeaturesMarkdownForSubclass(s);
        if (stitched.isNotEmpty) {
          return s.copyWith(featuresMarkdown: stitched);
        }
      }
      return s;
    }).toList();
    SrdClassesLibrary.setCustomSubclasses(updatedSubs);

    final customFluff = await loadCustomFluff();
    if (customFluff.isNotEmpty) {
      EntityFluffService().batchRegisterFluff(customFluff);
    }
  }

  /// Converts a generic [HomebrewCompendiumEntry] to a rollable [RollableTable].
  static RollableTable compendiumEntryToRollableTable(
          HomebrewCompendiumEntry entry) =>
      HomebrewCompendiumMappers.compendiumEntryToRollableTable(entry);

  /// Converts a generic [HomebrewCompendiumEntry] to a [DmReferenceItem].
  static DmReferenceItem compendiumEntryToDmReferenceItem(
          HomebrewCompendiumEntry entry) =>
      HomebrewCompendiumMappers.compendiumEntryToDmReferenceItem(entry);

  /// Synchronizes runtime registries for generic compendium items:
  /// - Feature Options (Invocations, Pacts, Infusions, Character Options)
  /// - Rollable Tables (TableIndexScreen / SrdTablesLibrary)
  /// - DM Reference Items (RulesCompendiumScreen / DmScreenLibrary)
  ///
  /// Only entries with [isEnabled] == true are registered into the active runtime toolkit.
  static void _hydrateCustomOtherSubsystems(
      List<HomebrewCompendiumEntry> others) {
    final activeOthers = others.where((e) => e.isEnabled).toList();

    final customPactBoons = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final name = e.name.toLowerCase();
          return cat.contains('pact boon') ||
              cat.contains('pb') ||
              name.startsWith('pact of the');
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomPactBoons(customPactBoons);

    final customInvocations = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final isPactBoon = cat.contains('pact boon') ||
              cat.contains('pb') ||
              e.name.toLowerCase().startsWith('pact of the');
          if (isPactBoon) return false;
          return cat.contains('invocation') ||
              cat == 'ei' ||
              cat.startsWith('ei:') ||
              e.customProperties['featureType']?.toString().toUpperCase() ==
                  'EI';
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomInvocations(customInvocations);

    final customInfusions = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final isPactBoon = cat.contains('pact boon') ||
              cat.contains('pb') ||
              e.name.toLowerCase().startsWith('pact of the');
          if (isPactBoon) return false;
          final isInvocation = cat.contains('invocation') ||
              cat.contains('ei') ||
              e.customProperties['featureType']
                      ?.toString()
                      .toUpperCase()
                      .contains('EI') ==
                  true;
          if (isInvocation) return false;
          return cat.contains('infusion') ||
              cat.contains('ai') ||
              e.customProperties['featureType']
                      ?.toString()
                      .toUpperCase()
                      .contains('AI') ==
                  true ||
              e.customProperties['featureType']
                      ?.toString()
                      .toUpperCase()
                      .contains('INF') ==
                  true;
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomInfusions(customInfusions);

    final customCharOptions = activeOthers
        .where((e) {
          final classified = HomebrewOtherCategory.classify(
            category: e.category,
            name: e.name,
            customProperties: e.customProperties,
          );
          return classified == HomebrewOtherCategory.characterOptions;
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomCharacterOptions(customCharOptions);

    final customTables = activeOthers
        .where((e) =>
            HomebrewOtherCategory.classify(
              category: e.category,
              name: e.name,
              customProperties: e.customProperties,
            ) ==
            HomebrewOtherCategory.tables)
        .map(compendiumEntryToRollableTable)
        .toList();
    SrdTablesLibrary.setCustomTables(customTables);

    final customRefItems = activeOthers
        .where((e) {
          final classified = HomebrewOtherCategory.classify(
            category: e.category,
            name: e.name,
            customProperties: e.customProperties,
          );
          return classified == HomebrewOtherCategory.trapsAndHazards ||
              classified == HomebrewOtherCategory.conditionsAndDiseases ||
              classified == HomebrewOtherCategory.deities ||
              classified == HomebrewOtherCategory.vehicles ||
              classified == HomebrewOtherCategory.charmsAndRewards ||
              classified == HomebrewOtherCategory.rulesAndReference ||
              classified == HomebrewOtherCategory.tables ||
              classified == HomebrewOtherCategory.dataTables;
        })
        .map(compendiumEntryToDmReferenceItem)
        .toList();
    DmScreenLibrary.setCustomItems(customRefItems);

    final customSubclassFeatures = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final type = (e.customProperties['entityType'] ??
                  e.customProperties['type'] ??
                  '')
              .toString()
              .toLowerCase();
          return cat.contains('subclassfeature') ||
              cat == 'subclass feature' ||
              type.contains('subclassfeature') ||
              e.customProperties.containsKey('subclassShortName') ||
              e.customProperties.containsKey('subclass');
        })
        .map((e) => {
              'name': e.name,
              'subclassShortName': e.customProperties['subclassShortName'] ??
                  e.customProperties['subclass'] ??
                  e.customProperties['shortName'],
              'className': e.customProperties['className'] ??
                  e.customProperties['class'],
              'level': e.customProperties['level'],
              'classSource': e.customProperties['classSource'],
              'subclassSource': e.customProperties['subclassSource'],
              'entries':
                  e.customProperties['entries'] ?? [e.descriptionMarkdown],
              'descriptionMarkdown': e.descriptionMarkdown,
              ...e.customProperties,
            })
        .toList();

    if (customSubclassFeatures.isNotEmpty) {
      SrdClassesLibrary.registerSubclassFeatures(customSubclassFeatures);
    } else if (others.isEmpty) {
      SrdClassesLibrary.clearCustomSubclassFeatures();
    }
  }

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
    await _subclassesStore.saveBatchList(newSubclasses, rawPayloads: rawPayloads);
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
    _hydrateCustomOtherSubsystems(entries);
  }

  /// Batch saves multiple generic compendium entries to persistent storage.
  Future<void> saveCustomOtherEntriesBatch(
    List<HomebrewCompendiumEntry> newEntries, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (!newEntries.any(_isValidOtherEntry)) return;
    await _otherStore.saveBatchFast(newEntries, rawPayloads: rawPayloads);
    final all = await loadCustomOtherEntries();
    _hydrateCustomOtherSubsystems(all);
  }

  /// Deletes a generic compendium entry by slug.
  Future<void> deleteCustomOtherEntry(String slug) async {
    final remaining = await _otherStore.delete(slug);
    _hydrateCustomOtherSubsystems(remaining);
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

    await _saveStringList(
      HomebrewRawPayloadStore.keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );

    _hydrateCustomOtherSubsystems(entries);
    return newEnabled;
  }

  /// Returns a map of counts for each granular [HomebrewOtherCategory] stored
  /// in the generic compendium collection.
  Future<Map<HomebrewOtherCategory, int>> loadOtherCategoryCounts() async {
    final entries = await loadCustomOtherEntries();
    final counts = <HomebrewOtherCategory, int>{
      for (final cat in HomebrewOtherCategory.values) cat: 0,
    };
    for (final e in entries) {
      final cat = HomebrewOtherCategory.classify(
        category: e.category,
        name: e.name,
        customProperties: e.customProperties,
      );
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  /// Prunes specified [HomebrewOtherCategory] subcategories from persistent storage
  /// while preserving all other custom entries and their raw payloads.
  ///
  /// Returns the number of entities removed.
  Future<int> clearOtherEntriesByCategories(
      Set<HomebrewOtherCategory> categories) async {
    if (categories.isEmpty) return 0;
    final allOthers = await loadCustomOtherEntries();
    if (allOthers.isEmpty) return 0;

    final remaining = <HomebrewCompendiumEntry>[];
    final removedSlugs = <String>{};

    for (final entry in allOthers) {
      final cat = HomebrewOtherCategory.classify(
        category: entry.category,
        name: entry.name,
        customProperties: entry.customProperties,
      );
      if (categories.contains(cat)) {
        removedSlugs.add(entry.id.slug);
      } else {
        remaining.add(entry);
      }
    }

    if (removedSlugs.isEmpty) return 0;

    // Save updated parsed list
    final remainingJson = remaining.map((e) => json.encode(e.toMap())).toList();
    await _saveStringList(HomebrewRawPayloadStore.keyHomebrewOther, remainingJson);

    // Prune removed slugs from raw payloads
    for (final slug in removedSlugs) {
      await _deleteRawPayload(
          HomebrewRawPayloadStore.keyHomebrewOtherRaw, slug);
    }

    // Clean up runtime feature options if invocations or infusions were removed
    if (categories.contains(HomebrewOtherCategory.invocationsAndPacts)) {
      for (final slug in removedSlugs) {
        SrdFeatureOptions.removeCustomInvocation(slug);
      }
    }
    if (categories.contains(HomebrewOtherCategory.infusions)) {
      for (final slug in removedSlugs) {
        SrdFeatureOptions.removeCustomInfusion(slug);
      }
    }

    _hydrateCustomOtherSubsystems(remaining);

    return removedSlugs.length;
  }

  /// Batch deletes multiple custom entities by [slugs] for the given [EntityType].
  /// Returns the number of entities removed.
  Future<int> deleteCustomEntitiesBatch(
      EntityType type, List<String> slugs) async {
    if (slugs.isEmpty) return 0;
    final slugSet = slugs.toSet();
    final int count = switch (type) {
      EntityType.spell => await _spellsStore.deleteBatch(slugSet),
      EntityType.monster => await _monstersStore.deleteBatch(
          slugSet,
          onSlugDeleted: MonsterCodexLibrary.removeHomebrewMonster,
        ),
      EntityType.equipment => await _itemsStore.deleteBatch(slugSet),
      EntityType.classDefinition => await _classesStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdClassesLibrary.removeCustomClass,
        ),
      EntityType.subclass => await _subclassesStore.deleteBatch(slugSet),
      EntityType.species => await _racesStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdSpeciesLibrary.removeCustomSpecies,
        ),
      EntityType.feat => await _featsStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdFeatsLibrary.removeCustomFeat,
        ),
      EntityType.background => await _backgroundsStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdBackgroundsLibrary.removeCustomBackground,
        ),
      EntityType.custom => await _otherStore.deleteBatch(slugSet),
      _ => 0,
    };

    SrdEquivalenceIndex().invalidate();
    return count;
  }

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
  }) async {
    final includeSpells =
        categories == null || categories.contains(EntityType.spell);
    final includeMonsters =
        categories == null || categories.contains(EntityType.monster);
    final includeItems =
        categories == null || categories.contains(EntityType.equipment);
    final includeClasses =
        categories == null || categories.contains(EntityType.classDefinition);
    final includeSubclasses =
        categories == null || categories.contains(EntityType.subclass);
    final includeRaces =
        categories == null || categories.contains(EntityType.species);
    final includeFeats =
        categories == null || categories.contains(EntityType.feat);
    final includeBackgrounds =
        categories == null || categories.contains(EntityType.background);
    final includeOther =
        categories == null || categories.contains(EntityType.custom);

    final loadedClasses =
        includeClasses ? await loadCustomClasses() : const <CharacterClass>[];
    final classesMap = <String, CharacterClass>{
      if (includeClasses)
        for (final c in SrdClassesLibrary.customClasses) c.id.slug: c,
      for (final c in loadedClasses) c.id.slug: c,
    };
    final classes = classesMap.values.toList();

    final loadedSubclasses =
        includeSubclasses ? await loadCustomSubclasses() : const <Subclass>[];
    final subclassesMap = <String, Subclass>{
      if (includeSubclasses) ...{
        for (final s in SrdClassesLibrary.customSubclasses) s.id.slug: s,
        for (final s in loadedSubclasses) s.id.slug: s,
        for (final c in classes)
          for (final s in c.subclasses) s.id.slug: s,
      },
    };
    final subclasses = subclassesMap.values.toList();

    final loadedRaces = includeRaces ? await loadCustomRaces() : const <Race>[];
    final racesMap = <String, Race>{
      if (includeRaces)
        for (final r in SrdSpeciesLibrary.customSpecies) r.id.slug: r,
      for (final r in loadedRaces) r.id.slug: r,
    };
    final races = racesMap.values.toList();

    final includeSubraces = includeRaces;
    final standaloneSubs =
        includeSubraces ? await loadCustomSubraces() : const <Subrace>[];
    final subracesMap = <String, Subrace>{
      if (includeSubraces) ...{
        for (final s in SrdSpeciesLibrary.customSubraces) s.id.slug: s,
        for (final s in standaloneSubs) s.id.slug: s,
        for (final r in races)
          for (final s in r.subraces) s.id.slug: s,
      },
    };
    final subraces = subracesMap.values.toList();

    final loadedFeats = includeFeats ? await loadCustomFeats() : const <Feat>[];
    final featsMap = <String, Feat>{
      if (includeFeats)
        for (final f in SrdFeatsLibrary.customFeats) f.id.slug: f,
      for (final f in loadedFeats) f.id.slug: f,
    };
    final feats = featsMap.values.toList();

    final loadedBackgrounds = includeBackgrounds
        ? await loadCustomBackgrounds()
        : const <Background>[];
    final backgroundsMap = <String, Background>{
      if (includeBackgrounds)
        for (final b in SrdBackgroundsLibrary.customBackgrounds) b.id.slug: b,
      for (final b in loadedBackgrounds) b.id.slug: b,
    };
    final backgrounds = backgroundsMap.values.toList();

    final storedFluff = await loadCustomFluff();
    final memoryFluff = EntityFluffService().getAllFluff();
    final fluffMap = <String, EntityFluff>{
      for (final f in storedFluff) '${f.entityType}_${f.slug}': f,
      for (final f in memoryFluff) '${f.entityType}_${f.slug}': f,
    };
    final fluffList = fluffMap.values.toList();

    return HomebrewBundle(
      appVersion: '1.0.0',
      exportedAt: DateTime.now(),
      bundleName: bundleName,
      author: author,
      description: description,
      spells: includeSpells ? await loadCustomSpells() : const [],
      monsters: includeMonsters ? await loadCustomMonsters() : const [],
      items: includeItems ? await loadCustomItems() : const [],
      classes: classes,
      subclasses: subclasses,
      races: races,
      subraces: subraces,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: includeOther ? await loadCustomOtherEntries() : const [],
      fluff: fluffList,
    );
  }

  /// Exports saved homebrew entities across all active registries into a comprehensive
  /// dictionary with sibling arrays (`races`, `subraces`, `classes`, `subclasses`, `backgrounds`, `feats`, `items`, `spells`, `monsters`, `fluff`).
  Future<Map<String, dynamic>> exportBundle({
    String? bundleName,
    String? author,
    String? description,
    Set<EntityType>? categories,
  }) async {
    final includeSpells =
        categories == null || categories.contains(EntityType.spell);
    final includeMonsters =
        categories == null || categories.contains(EntityType.monster);
    final includeItems =
        categories == null || categories.contains(EntityType.equipment);
    final includeClasses =
        categories == null || categories.contains(EntityType.classDefinition);
    final includeSubclasses =
        categories == null || categories.contains(EntityType.subclass);
    final includeRaces =
        categories == null || categories.contains(EntityType.species);
    final includeFeats =
        categories == null || categories.contains(EntityType.feat);
    final includeBackgrounds =
        categories == null || categories.contains(EntityType.background);
    final includeOther =
        categories == null || categories.contains(EntityType.custom);

    final spells = includeSpells ? await loadCustomSpells() : const <Spell>[];
    final monsters =
        includeMonsters ? await loadCustomMonsters() : const <Monster>[];
    final items =
        includeItems ? await loadCustomItems() : const <EquipmentItem>[];

    final loadedClasses =
        includeClasses ? await loadCustomClasses() : const <CharacterClass>[];
    final classesMap = <String, CharacterClass>{
      if (includeClasses)
        for (final c in SrdClassesLibrary.customClasses) c.id.slug: c,
      for (final c in loadedClasses) c.id.slug: c,
    };
    final classes = classesMap.values.toList();

    final loadedSubclasses =
        includeSubclasses ? await loadCustomSubclasses() : const <Subclass>[];
    final subclassesMap = <String, Subclass>{
      if (includeSubclasses) ...{
        for (final s in SrdClassesLibrary.customSubclasses) s.id.slug: s,
        for (final s in loadedSubclasses) s.id.slug: s,
        for (final c in classes)
          for (final s in c.subclasses) s.id.slug: s,
      },
    };
    final subclasses = subclassesMap.values.toList();

    final loadedRaces = includeRaces ? await loadCustomRaces() : const <Race>[];
    final racesMap = <String, Race>{
      if (includeRaces)
        for (final r in SrdSpeciesLibrary.customSpecies) r.id.slug: r,
      for (final r in loadedRaces) r.id.slug: r,
    };
    final races = racesMap.values.toList();

    final includeSubraces = includeRaces;
    final standaloneSubs =
        includeSubraces ? await loadCustomSubraces() : const <Subrace>[];
    final exportSubracesMap = <String, Subrace>{
      if (includeSubraces) ...{
        for (final s in SrdSpeciesLibrary.customSubraces) s.id.slug: s,
        for (final s in standaloneSubs) s.id.slug: s,
        for (final r in races)
          for (final s in r.subraces) s.id.slug: s,
      },
    };
    final subraces = exportSubracesMap.values.toList();

    final loadedFeats = includeFeats ? await loadCustomFeats() : const <Feat>[];
    final featsMap = <String, Feat>{
      if (includeFeats)
        for (final f in SrdFeatsLibrary.customFeats) f.id.slug: f,
      for (final f in loadedFeats) f.id.slug: f,
    };
    final feats = featsMap.values.toList();

    final loadedBackgrounds = includeBackgrounds
        ? await loadCustomBackgrounds()
        : const <Background>[];
    final backgroundsMap = <String, Background>{
      if (includeBackgrounds)
        for (final b in SrdBackgroundsLibrary.customBackgrounds) b.id.slug: b,
      for (final b in loadedBackgrounds) b.id.slug: b,
    };
    final backgrounds = backgroundsMap.values.toList();

    final otherEntries = includeOther
        ? await loadCustomOtherEntries()
        : const <HomebrewCompendiumEntry>[];

    final storedFluff = await loadCustomFluff();
    final memoryFluff = EntityFluffService().getAllFluff();
    final fluffMap = <String, EntityFluff>{
      for (final f in storedFluff) '${f.entityType}_${f.slug}': f,
      for (final f in memoryFluff) '${f.entityType}_${f.slug}': f,
    };
    final fluffList = fluffMap.values.toList();

    return {
      'schemaVersion': 1,
      'appVersion': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'bundleName': ?bundleName,
      'author': ?author,
      'description': ?description,
      'spells': spells.map((s) => s.toMap()).toList(),
      'monsters': monsters.map((m) => m.toMap()).toList(),
      'items': items.map((i) => i.toMap()).toList(),
      'classes': classes.map((c) => c.toMap()).toList(),
      'subclasses': subclasses.map((s) => s.toMap()).toList(),
      'races': races.map((r) => r.toMap()).toList(),
      'subraces': subraces.map((s) => s.toMap()).toList(),
      'backgrounds': backgrounds.map((b) => b.toMap()).toList(),
      'feats': feats.map((f) => f.toMap()).toList(),
      'otherEntries': otherEntries.map((o) => o.toMap()).toList(),
      if (fluffList.isNotEmpty)
        'fluff': fluffList.map((f) => f.toMap()).toList(),
    };
  }

  /// Imports an analyzed and resolved [ImportAnalysisResult], writing entities to storage
  /// according to user-selected collision resolutions, and syncs runtime libraries immediately.
  ///
  /// [onProgress] is called after every entity write with (saved, total).
  Future<void> importResolvedBundle(
    ImportAnalysisResult resolution, {
    void Function(int saved, int total, String phase)? onProgress,
  }) async {
    // Pre-count total selected entities for accurate progress reporting
    final total = resolution.selectedCount;
    int saved = 0;

    void tick(String phase) {
      saved++;
      onProgress?.call(saved, total, phase);
    }

    // 1. Spells
    final existingSpells = await loadCustomSpells();
    final spellSlugs = existingSpells.map((s) => s.id.slug).toSet();
    final spellIndex = <String, int>{
      for (int i = 0; i < existingSpells.length; i++)
        '${existingSpells[i].id.slug}_${existingSpells[i].id.ruleset.name}': i,
    };
    bool spellsModified = false;
    for (final item in resolution.spells) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Spell toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(
            toSave.id.slug, spellSlugs);
        spellSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = spellIndex[key];
      if (idx != null) {
        existingSpells[idx] = toSave;
      } else {
        spellIndex[key] = existingSpells.length;
        existingSpells.add(toSave);
      }
      spellsModified = true;
      tick('Spells');
    }
    if (spellsModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewSpells,
        existingSpells.map((s) => json.encode(s.toMap())).toList(),
      );
    }

    // 2. Monsters
    final existingMonsters = await loadCustomMonsters();
    final monsterSlugs = existingMonsters.map((m) => m.id.slug).toSet();
    final monsterIndex = <String, int>{
      for (int i = 0; i < existingMonsters.length; i++)
        '${existingMonsters[i].id.slug}_${existingMonsters[i].id.ruleset.name}':
            i,
    };
    bool monstersModified = false;
    for (final item in resolution.monsters) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Monster toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(
            toSave.id.slug, monsterSlugs);
        monsterSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = monsterIndex[key];
      if (idx != null) {
        existingMonsters[idx] = toSave;
      } else {
        monsterIndex[key] = existingMonsters.length;
        existingMonsters.add(toSave);
      }
      monstersModified = true;
      tick('Monsters');
    }
    if (monstersModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewMonsters,
        existingMonsters.map((m) => json.encode(m.toMap())).toList(),
      );
    }

    // 3. Items
    final existingItems = await loadCustomItems();
    final itemSlugs = existingItems.map((i) => i.id.slug).toSet();
    final itemIndex = <String, int>{
      for (int i = 0; i < existingItems.length; i++)
        '${existingItems[i].id.slug}_${existingItems[i].id.ruleset.name}': i,
    };
    bool itemsModified = false;
    for (final item in resolution.items) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      EquipmentItem toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug =
            HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, itemSlugs);
        itemSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = itemIndex[key];
      if (idx != null) {
        existingItems[idx] = toSave;
      } else {
        itemIndex[key] = existingItems.length;
        existingItems.add(toSave);
      }
      itemsModified = true;
      tick('Items');
    }
    if (itemsModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewItems,
        existingItems.map((i) => json.encode(i.toMap())).toList(),
      );
    }

    // 4. Classes
    final existingClasses = await loadCustomClasses();
    final classSlugs = existingClasses.map((c) => c.id.slug).toSet();
    final classIndex = <String, int>{
      for (int i = 0; i < existingClasses.length; i++)
        '${existingClasses[i].id.slug}_${existingClasses[i].id.ruleset.name}':
            i,
    };
    bool classesModified = false;
    for (final item in resolution.classes) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      CharacterClass toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(
            toSave.id.slug, classSlugs);
        classSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = classIndex[key];
      if (idx != null) {
        existingClasses[idx] = toSave;
      } else {
        classIndex[key] = existingClasses.length;
        existingClasses.add(toSave);
      }
      classesModified = true;
      tick('Classes');
    }
    if (classesModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewClasses,
        existingClasses.map((c) => json.encode(c.toMap())).toList(),
      );
    }

    // 5. Subclasses
    final existingSubclasses = await loadCustomSubclasses();
    final subSlugs = existingSubclasses.map((s) => s.id.slug).toSet();
    final subIndex = <String, int>{
      for (int i = 0; i < existingSubclasses.length; i++)
        '${existingSubclasses[i].id.slug}_${existingSubclasses[i].id.ruleset.name}':
            i,
    };
    bool subclassesModified = false;
    for (final item in resolution.subclasses) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Subclass toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug =
            HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, subSlugs);
        subSlugs.add(newSlug);
        toSave = Subclass(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
          classSlug: toSave.classSlug,
          shortName: '${toSave.shortName} (Copy)',
          featuresMarkdown: toSave.featuresMarkdown,
          customProperties: toSave.customProperties,
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = subIndex[key];
      if (idx != null) {
        existingSubclasses[idx] = toSave;
      } else {
        subIndex[key] = existingSubclasses.length;
        existingSubclasses.add(toSave);
      }
      subclassesModified = true;
      tick('Subclasses');
    }
    if (subclassesModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewSubclasses,
        existingSubclasses.map((s) => json.encode(s.toMap())).toList(),
      );
    }

    // 6. Races
    final existingRaces = await loadCustomRaces();
    final raceSlugs = existingRaces.map((r) => r.id.slug).toSet();
    final raceIndex = <String, int>{
      for (int i = 0; i < existingRaces.length; i++)
        '${existingRaces[i].id.slug}_${existingRaces[i].id.ruleset.name}': i,
    };
    bool racesModified = false;
    for (final item in resolution.races) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Race toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug =
            HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, raceSlugs);
        raceSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = raceIndex[key];
      if (idx != null) {
        existingRaces[idx] = toSave;
      } else {
        raceIndex[key] = existingRaces.length;
        existingRaces.add(toSave);
      }
      racesModified = true;
      tick('Races & Species');
    }
    if (racesModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewRaces,
        existingRaces.map((r) => json.encode(r.toMap())).toList(),
      );
    }

    // 7. Subraces
    final existingSubraces = await loadCustomSubraces();
    final subraceSlugs = existingSubraces.map((s) => s.id.slug).toSet();
    final subraceIndex = <String, int>{
      for (int i = 0; i < existingSubraces.length; i++)
        '${existingSubraces[i].id.slug}_${existingSubraces[i].id.ruleset.name}':
            i,
    };
    bool subracesModified = false;
    for (final item in resolution.subraces) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Subrace toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(
            toSave.id.slug, subraceSlugs);
        subraceSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = subraceIndex[key];
      if (idx != null) {
        existingSubraces[idx] = toSave;
      } else {
        subraceIndex[key] = existingSubraces.length;
        existingSubraces.add(toSave);
      }
      subracesModified = true;
      tick('Subraces');
    }
    if (subracesModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewSubraces,
        existingSubraces.map((s) => json.encode(s.toMap())).toList(),
      );
    }

    // 8. Feats
    final existingFeats = await loadCustomFeats();
    final featSlugs = existingFeats.map((f) => f.id.slug).toSet();
    final featIndex = <String, int>{
      for (int i = 0; i < existingFeats.length; i++)
        '${existingFeats[i].id.slug}_${existingFeats[i].id.ruleset.name}': i,
    };
    bool featsModified = false;
    for (final item in resolution.feats) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Feat toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug =
            HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, featSlugs);
        featSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = featIndex[key];
      if (idx != null) {
        existingFeats[idx] = toSave;
      } else {
        featIndex[key] = existingFeats.length;
        existingFeats.add(toSave);
      }
      featsModified = true;
      tick('Feats');
    }
    if (featsModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewFeats,
        existingFeats.map((f) => json.encode(f.toMap())).toList(),
      );
    }

    // 8. Backgrounds
    final existingBgs = await loadCustomBackgrounds();
    final bgSlugs = existingBgs.map((b) => b.id.slug).toSet();
    final bgIndex = <String, int>{
      for (int i = 0; i < existingBgs.length; i++)
        '${existingBgs[i].id.slug}_${existingBgs[i].id.ruleset.name}': i,
    };
    bool bgsModified = false;
    for (final item in resolution.backgrounds) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Background toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug =
            HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, bgSlugs);
        bgSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = bgIndex[key];
      if (idx != null) {
        existingBgs[idx] = toSave;
      } else {
        bgIndex[key] = existingBgs.length;
        existingBgs.add(toSave);
      }
      bgsModified = true;
      tick('Backgrounds');
    }
    if (bgsModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewBackgrounds,
        existingBgs.map((b) => json.encode(b.toMap())).toList(),
      );
    }

    // 9. Other entries
    final existingOthers = await loadCustomOtherEntries();
    final otherSlugs = existingOthers.map((o) => o.id.slug).toSet();
    final otherIndex = <String, int>{
      for (int i = 0; i < existingOthers.length; i++)
        '${existingOthers[i].id.slug}_${existingOthers[i].id.ruleset.name}': i,
    };
    bool othersModified = false;
    for (final item in resolution.otherEntries) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      HomebrewCompendiumEntry toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(
            toSave.id.slug, otherSlugs);
        otherSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = otherIndex[key];
      if (idx != null) {
        existingOthers[idx] = toSave;
      } else {
        otherIndex[key] = existingOthers.length;
        existingOthers.add(toSave);
      }
      othersModified = true;
      tick('Rules & Tables');
    }
    if (othersModified) {
      await _saveStringList(
        HomebrewRawPayloadStore.keyHomebrewOther,
        existingOthers.map((e) => json.encode(e.toMap())).toList(),
      );
    }

    // Save any pending lore/fluff to persistent storage
    if (EntityFluffService().fluffCount > 0) {
      await saveCustomFluffBatch(EntityFluffService().getAllFluff());
    }

    // Immediately synchronize runtime libraries
    await syncToLibraries();
  }

  /// Hydrates a LayeredPriorityRepository with saved Homebrew and Campaign Overrides.
  Future<void> hydrateRepository(LayeredPriorityRepository repository) async {
    // 1. Homebrew Layer
    PriorityLayer? homebrewLayer;
    try {
      homebrewLayer = repository.layers.firstWhere(
        (l) => l.layerId == 'homebrew-packs',
      );
    } catch (_) {
      homebrewLayer = PriorityLayer(
        layerId: 'homebrew-packs',
        name: 'Homebrew & Custom Packs',
        priority: LayerPriority.homebrewPacks,
      );
      repository.addLayer(homebrewLayer);
    }

    final spells = await loadCustomSpells();
    for (final s in spells) {
      homebrewLayer.registerEntity(s);
    }

    final monsters = await loadCustomMonsters();
    for (final m in monsters) {
      homebrewLayer.registerEntity(m);
    }

    final items = await loadCustomItems();
    for (final i in items) {
      homebrewLayer.registerEntity(i);
    }

    final classes = await loadCustomClasses();
    for (final c in classes) {
      homebrewLayer.registerEntity(c);
    }

    final subclasses = await loadCustomSubclasses();
    for (final sub in subclasses) {
      homebrewLayer.registerEntity(sub);
    }

    final races = await loadCustomRaces();
    for (final r in races) {
      homebrewLayer.registerEntity(r);
    }

    final feats = await loadCustomFeats();
    for (final f in feats) {
      homebrewLayer.registerEntity(f);
    }

    final backgrounds = await loadCustomBackgrounds();
    for (final b in backgrounds) {
      homebrewLayer.registerEntity(b);
    }

    final others = await loadCustomOtherEntries();
    for (final o in others) {
      homebrewLayer.registerEntity(o);
    }
  }

  /// Clears all saved homebrew and override data.
  Future<void> clearAllHomebrew() async {
    final prefs = await SharedPreferences.getInstance();
    if (_db.isBoxOpen(AppDatabaseService.boxHomebrew)) {
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewSpells);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewMonsters);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewItems);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewClasses);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewSubclasses);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewRaces);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewFeats);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewBackgrounds);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewOther);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewSubraces);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewFluff);
      await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyCampaignOverrides);
    }

    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSpells);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewMonsters);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewItems);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewClasses);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubclasses);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewRaces);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubraces);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewFeats);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewBackgrounds);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewOther);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewFluff);
    await prefs.remove(HomebrewRawPayloadStore.keyCampaignOverrides);

    // Clear raw payload keys
    if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
      await _db.delete(AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewSpellsRaw);
      await _db.delete(
          AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewMonstersRaw);
      await _db.delete(AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewItemsRaw);
      await _db.delete(AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewClassesRaw);
      await _db.delete(
          AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewSubclassesRaw);
      await _db.delete(AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewRacesRaw);
      await _db.delete(
          AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewSubracesRaw);
      await _db.delete(AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewFeatsRaw);
      await _db.delete(
          AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewBackgroundsRaw);
      await _db.delete(AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewOtherRaw);
      await _db.delete(AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewFluffRaw);
    }

    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSpellsRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewMonstersRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewItemsRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewClassesRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubclassesRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewRacesRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubracesRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewFeatsRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewBackgroundsRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewOtherRaw);
    await prefs.remove(HomebrewRawPayloadStore.keyHomebrewFluffRaw);

    invalidateAllCaches();

    MonsterCodexLibrary.clearHomebrewMonsters();
    SpellbookLibrary.setHomebrewSpells([]);
    SrdSpeciesLibrary.setCustomSpecies([]);
    SrdSpeciesLibrary.setCustomSubraces([]);
    SrdFeatsLibrary.setCustomFeats([]);
    SrdClassesLibrary.setCustomClasses([]);
    SrdClassesLibrary.setCustomSubclasses([]);
    SrdBackgroundsLibrary.setCustomBackgrounds([]);
    _hydrateCustomOtherSubsystems([]);
    SrdEquivalenceIndex().invalidate();
  }

  /// Purges all persisted data for a single [EntityType] category and
  /// refreshes the corresponding runtime library.
  ///
  /// Only [classDefinition], [subclass], [species], [feat], [background],
  /// [equipment], [spell], [monster], and [custom] are supported.
  Future<void> clearHomebrewCategory(EntityType type) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case EntityType.spell:
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewSpells);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSpells);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewSpellsRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSpellsRaw);
        SpellbookLibrary.setHomebrewSpells([]);
      case EntityType.monster:
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewMonsters);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewMonsters);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewMonstersRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewMonstersRaw);
        MonsterCodexLibrary.clearHomebrewMonsters();
      case EntityType.equipment:
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewItems);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewItems);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewItemsRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewItemsRaw);
      case EntityType.classDefinition:
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewClasses);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewClasses);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewClassesRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewClassesRaw);
        SrdClassesLibrary.setCustomClasses([]);
      case EntityType.subclass:
        await _db.delete(
            AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewSubclasses);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubclasses);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewSubclassesRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubclassesRaw);
        SrdClassesLibrary.setCustomSubclasses([]);
      case EntityType.species:
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewRaces);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewRaces);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewRacesRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewRacesRaw);
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewSubraces);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubraces);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewSubracesRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewSubracesRaw);
        SrdSpeciesLibrary.setCustomSpecies([]);
        SrdSpeciesLibrary.setCustomSubraces([]);
      case EntityType.feat:
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewFeats);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewFeats);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewFeatsRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewFeatsRaw);
        SrdFeatsLibrary.setCustomFeats([]);
      case EntityType.background:
        await _db.delete(
            AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewBackgrounds);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewBackgrounds);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewBackgroundsRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewBackgroundsRaw);
        SrdBackgroundsLibrary.setCustomBackgrounds([]);
      case EntityType.custom:
        await _db.delete(AppDatabaseService.boxHomebrew, HomebrewRawPayloadStore.keyHomebrewOther);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewOther);
        await _db.delete(
            AppDatabaseService.boxHomebrewRaw, HomebrewRawPayloadStore.keyHomebrewOtherRaw);
        await prefs.remove(HomebrewRawPayloadStore.keyHomebrewOtherRaw);
        _hydrateCustomOtherSubsystems([]);
      default:
        break;
    }
    final rawKey = _rawKeyForType(type);
    final parsedKey = switch (type) {
      EntityType.spell => HomebrewRawPayloadStore.keyHomebrewSpells,
      EntityType.monster => HomebrewRawPayloadStore.keyHomebrewMonsters,
      EntityType.equipment => HomebrewRawPayloadStore.keyHomebrewItems,
      EntityType.classDefinition => HomebrewRawPayloadStore.keyHomebrewClasses,
      EntityType.subclass => HomebrewRawPayloadStore.keyHomebrewSubclasses,
      EntityType.species => HomebrewRawPayloadStore.keyHomebrewRaces,
      EntityType.feat => HomebrewRawPayloadStore.keyHomebrewFeats,
      EntityType.background => HomebrewRawPayloadStore.keyHomebrewBackgrounds,
      EntityType.custom => HomebrewRawPayloadStore.keyHomebrewOther,
      _ => null,
    };
    if (parsedKey != null) _invalidateCategoryCache(parsedKey, rawKey);
    if (type == EntityType.species) {
      _invalidateCategoryCache(HomebrewRawPayloadStore.keyHomebrewSubraces, HomebrewRawPayloadStore.keyHomebrewSubracesRaw);
    }
    SrdEquivalenceIndex().invalidate();
  }

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
  Future<ReparseResult> reparseAllHomebrew() async {
    final srdIndex = SrdEquivalenceIndex();
    srdIndex.build();

    int updated = 0;
    int srdRemoved = 0;
    int noPayload = 0;

    // Count entities without raw payloads (so the UI can report it)
    for (final type in _reparsableTypes) {
      final payloads = await loadRawPayloads(type);
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
    final rawOthers = await loadRawPayloads(EntityType.custom);
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
    final rawSubclasses = await loadRawPayloads(EntityType.subclass);
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
        await _deleteRawPayload(HomebrewRawPayloadStore.keyHomebrewSubclassesRaw, slug);
      }
      await _saveRawPayloadsBatch(HomebrewRawPayloadStore.keyHomebrewOtherRaw, featuresToMigrate);
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

    invalidateAllCaches();
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

  // ---------------------------------------------------------------------------
  // Private: raw payload storage helpers (delegated to HomebrewRawPayloadStore)
  // ---------------------------------------------------------------------------

  Future<void> _saveRawPayloadsBatch(
    String key,
    Map<String, Map<String, dynamic>> payloadsBySlug, [
    SharedPreferences? prefs,
  ]) =>
      _rawStore.saveRawPayloadsBatch(key, payloadsBySlug, prefs);

  /// Public accessor to save a single raw JSON payload for homebrew entities.
  Future<void> saveCustomRawPayload(
    String key,
    String entitySlug,
    Map<String, dynamic> rawPayload,
  ) =>
      _rawStore.saveCustomRawPayload(key, entitySlug, rawPayload);

  Future<void> _deleteRawPayload(
    String key,
    String entitySlug, [
    SharedPreferences? prefs,
  ]) =>
      _rawStore.deleteRawPayload(key, entitySlug, prefs);

  String? _rawKeyForType(EntityType type) => _rawStore.rawKeyForType(type);

  static const List<EntityType> _reparsableTypes =
      HomebrewRawPayloadStore.reparsableTypes;

  Future<List<dynamic>> _loadEntitiesForType(EntityType type) async {
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
      _ => [],
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
            reason: 'Failed to persist pruned rawMap to SharedPreferences for $rawKey',
          );
        }
      }

      // 3. Check legacy parsed store for any SRD duplicates not in rawMap
      final existingParsed = await _loadStringList(parsedKey);
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

      await _saveStringList(parsedKey, reparsed.map(toJson).toList());
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

  /// Persists a batch of [HomebrewEntity] items parsed from remote repositories
  /// into canonical storage collections and optionally synchronizes runtime libraries.
  Future<void> saveHomebrewEntitiesBatch(
    List<HomebrewEntity> entities, {
    bool syncLibraries = true,
    bool excludeSrdCanon = true,
  }) async {
    if (entities.isEmpty) return;

    final spells = <Spell>[];
    final monsters = <Monster>[];
    final items = <EquipmentItem>[];
    final classes = <CharacterClass>[];
    final subclasses = <Subclass>[];
    final races = <Race>[];
    final subraces = <Subrace>[];
    final feats = <Feat>[];
    final backgrounds = <Background>[];
    final others = <HomebrewCompendiumEntry>[];
    final fluffToSave = <EntityFluff>[];

    final spellPayloads = <Map<String, dynamic>>[];
    final monsterPayloads = <Map<String, dynamic>>[];
    final itemPayloads = <Map<String, dynamic>>[];
    final classPayloads = <Map<String, dynamic>>[];
    final subclassPayloads = <Map<String, dynamic>>[];
    final racePayloads = <Map<String, dynamic>>[];
    final subracePayloads = <Map<String, dynamic>>[];
    final featPayloads = <Map<String, dynamic>>[];
    final backgroundPayloads = <Map<String, dynamic>>[];
    final otherPayloads = <Map<String, dynamic>>[];
    final fluffPayloads = <Map<String, dynamic>>[];

    final adapters = CommunityCompendiumAdapters();
    final raceParser = CompendiumRaceParser();
    final genericParser = CompendiumGenericEntryParser();
    final srdIndex = SrdEquivalenceIndex();
    if (excludeSrdCanon && !srdIndex.isBuilt) srdIndex.build();

    const creatureTypes = {
      'monster',
      'creature',
      'npc',
      'bestiary',
      'aberration',
      'beast',
      'celestial',
      'construct',
      'dragon',
      'elemental',
      'fey',
      'fiend',
      'giant',
      'humanoid',
      'monstrosity',
      'ooze',
      'plant',
      'undead',
    };

    final batchSubclassFeatureMap = <String, Map<String, dynamic>>{};
    final batchClassFeatureMap = <String, Map<String, dynamic>>{};

    for (final entity in entities) {
      final t = entity.entityType.toLowerCase().trim();
      final p = entity.rawPayload;
      if (t == 'subclassfeature' || t == 'subclassfeatures') {
        SrdClassesLibrary.registerSubclassFeature(p);
        final name = (p['name'] ?? entity.name).toString().toLowerCase().trim();
        final subShort = (p['subclassShortName'] ?? p['shortName'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final lvl = (p['level'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          batchSubclassFeatureMap[name] = p;
          if (subShort.isNotEmpty) {
            batchSubclassFeatureMap['$name|$subShort'] = p;
            if (lvl.isNotEmpty) {
              batchSubclassFeatureMap['$name|$subShort|$lvl'] = p;
            }
          }
          if (lvl.isNotEmpty) {
            batchSubclassFeatureMap['$name|$lvl'] = p;
          }
        }
      } else if (t == 'classfeature' || t == 'classfeatures') {
        final name = (p['name'] ?? entity.name).toString().toLowerCase().trim();
        final cls = (p['className'] ?? p['class'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final lvl = (p['level'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          batchClassFeatureMap[name] = p;
          if (cls.isNotEmpty) {
            batchClassFeatureMap['$name|$cls'] = p;
            if (lvl.isNotEmpty) {
              batchClassFeatureMap['$name|$cls|$lvl'] = p;
            }
          }
        }
      }
    }

    for (final entity in entities) {
      final payload = Map<String, dynamic>.from(entity.rawPayload);
      final typeLower = entity.entityType.toLowerCase().trim();

      final isFluff = typeLower.endsWith('fluff') ||
          typeLower == 'fluff' ||
          ((typeLower == 'custom' || typeLower == 'generic') &&
              (payload.containsKey('_fluff') ||
                  payload.containsKey('flufftype')));

      if (isFluff) {
        final rawType = typeLower.endsWith('fluff') && typeLower != 'fluff'
            ? typeLower.substring(0, typeLower.length - 5)
            : 'generic';
        final pipeline = CompendiumJsonIngestionPipeline();
        final batchResult = pipeline.ingestJsonMap({
          '${rawType}Fluff': [payload],
        });
        fluffToSave.addAll(batchResult.fluff);
        fluffPayloads.add(payload);
        continue;
      }

      final primaryType = typeLower.split(RegExp(r'[\s(,]')).first.trim();
      final hasMonsterAttributes = payload.containsKey('cr') ||
          payload.containsKey('challengeRating') ||
          payload.containsKey('hitDice') ||
          payload.containsKey('ac') ||
          payload.containsKey('hp') ||
          payload.containsKey('actions') ||
          payload.containsKey('action') ||
          payload.containsKey('isNpc') ||
          payload.containsKey('isNamedCreature') ||
          payload.containsKey('legendary') ||
          payload.containsKey('reactions') ||
          (payload.containsKey('_copy') &&
              (typeLower.contains('monster') ||
                  typeLower.contains('creature') ||
                  typeLower.contains('bestiary') ||
                  typeLower == 'race'));

      final isMonster = creatureTypes.contains(primaryType) ||
          creatureTypes.contains(typeLower) ||
          typeLower.startsWith('{type:') ||
          hasMonsterAttributes;

      try {
        if (isMonster) {
          if (excludeSrdCanon &&
              srdIndex.checkEntity(
                    slug: entity.id,
                    name: entity.name,
                    type: EntityType.monster,
                  ) !=
                  SrdMatchResult.notSrd) {
            continue;
          }
          monsters
              .add(adapters.parseMonster(payload, forceRuleset: entity.ruleset));
          monsterPayloads.add(payload);
        } else {
          switch (typeLower) {
            case 'spell':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.spell,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              spells
                  .add(adapters.parseSpell(payload, forceRuleset: entity.ruleset));
              spellPayloads.add(payload);
            case 'equipment' ||
                  'item' ||
                  'magicitem' ||
                  'weapon' ||
                  'armor' ||
                  'baseitem' ||
                  'magicvariant':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.equipment,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              items.add(adapters.parseItem(payload, forceRuleset: entity.ruleset));
              itemPayloads.add(payload);
            case 'class':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.classDefinition,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              classes.add(adapters.parseClass(
                payload,
                forceRuleset: entity.ruleset,
                classFeatureMap: batchClassFeatureMap.isNotEmpty
                    ? batchClassFeatureMap
                    : null,
                subclassFeatureMap: batchSubclassFeatureMap.isNotEmpty
                    ? batchSubclassFeatureMap
                    : null,
              ));
              classPayloads.add(payload);
            case 'subclass':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.subclass,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              subclasses.add(adapters.parseSubclass(
                payload,
                forceRuleset: entity.ruleset,
                subclassFeatureMap: batchSubclassFeatureMap.isNotEmpty
                    ? batchSubclassFeatureMap
                    : null,
              ));
              subclassPayloads.add(payload);
            case 'race' || 'species':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.species,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              races.add(adapters.parseRace(payload, forceRuleset: entity.ruleset));
              racePayloads.add(payload);
            case 'subrace':
              final sub =
                  raceParser.parseSubrace(payload, forceRuleset: entity.ruleset);
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: sub.id.slug,
                        name: sub.name,
                        type: EntityType.species,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              subraces.add(sub);
              subracePayloads.add(payload);
              SrdSpeciesLibrary.addCustomSubrace(sub);

              if (sub.raceSlug.isNotEmpty) {
                final match =
                    races.where((r) => r.id.slug == sub.raceSlug).firstOrNull;
                if (match != null) {
                  final idx = races.indexOf(match);
                  races[idx] =
                      match.copyWith(subraces: [...match.subraces, sub]);
                  if (idx < racePayloads.length) {
                    final existingSubs = List<dynamic>.from(
                        racePayloads[idx]['subraces'] as List? ?? []);
                    existingSubs.add(payload);
                    racePayloads[idx] = {
                      ...racePayloads[idx],
                      'subraces': existingSubs,
                    };
                  }
                } else if (!excludeSrdCanon ||
                    srdIndex.checkEntity(
                          slug: sub.raceSlug,
                          name: sub.raceSlug.replaceAll('-', ' '),
                          type: EntityType.species,
                        ) ==
                        SrdMatchResult.notSrd) {
                  final parentName = (payload['raceName'] as String?) ??
                      sub.raceSlug.replaceAll('-', ' ');
                  races.add(Race(
                    id: EntityId(slug: sub.raceSlug, ruleset: entity.ruleset),
                    name: parentName,
                    traitsMarkdown: '',
                    subraces: [sub],
                  ));
                  racePayloads.add({
                    'name': parentName,
                    'slug': sub.raceSlug,
                    'entityType': 'race',
                    'subraces': [payload],
                  });
                }
              }
            case 'feat':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.feat,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              feats.add(adapters.parseFeat(payload, forceRuleset: entity.ruleset));
              featPayloads.add(payload);
            case 'background':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.background,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              backgrounds.add(
                  adapters.parseBackground(payload, forceRuleset: entity.ruleset));
              backgroundPayloads.add(payload);
            default:
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.custom,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              final entry = genericParser.parseGenericEntry(
                payload,
                defaultCategory: entity.entityType,
                forceRuleset: entity.ruleset,
              );
              others.add(entry);
              otherPayloads.add(payload);
          }
        }
      } catch (_) {
        if (excludeSrdCanon &&
            srdIndex.checkEntity(
                  slug: entity.id,
                  name: entity.name,
                  type: EntityType.custom,
                ) !=
                SrdMatchResult.notSrd) {
          continue;
        }
        final entry = genericParser.parseGenericEntry(
          payload,
          defaultCategory: entity.entityType,
          forceRuleset: entity.ruleset,
        );
        others.add(entry);
        otherPayloads.add(payload);
      }
    }

    if (spells.isNotEmpty)
      await saveCustomSpellsBatch(spells, rawPayloads: spellPayloads);
    if (monsters.isNotEmpty)
      await saveCustomMonstersBatch(monsters, rawPayloads: monsterPayloads);
    if (items.isNotEmpty)
      await saveCustomItemsBatch(items, rawPayloads: itemPayloads);
    if (classes.isNotEmpty)
      await saveCustomClassesBatch(classes, rawPayloads: classPayloads);
    if (subclasses.isNotEmpty)
      await saveCustomSubclassesBatch(subclasses,
          rawPayloads: subclassPayloads);
    if (races.isNotEmpty)
      await saveCustomRacesBatch(races, rawPayloads: racePayloads);
    if (subraces.isNotEmpty)
      await saveCustomSubracesBatch(subraces, rawPayloads: subracePayloads);
    if (feats.isNotEmpty)
      await saveCustomFeatsBatch(feats, rawPayloads: featPayloads);
    if (backgrounds.isNotEmpty)
      await saveCustomBackgroundsBatch(backgrounds,
          rawPayloads: backgroundPayloads);
    if (others.isNotEmpty)
      await saveCustomOtherEntriesBatch(others, rawPayloads: otherPayloads);
    if (fluffToSave.isNotEmpty)
      await saveCustomFluffBatch(fluffToSave, rawPayloads: fluffPayloads);

    if (syncLibraries) {
      await syncToLibraries();
    }
  }

  /// Persists a single [HomebrewEntity] into canonical storage and optionally synchronizes libraries.
  Future<void> saveHomebrewEntity(
    HomebrewEntity entity, {
    bool syncLibraries = true,
  }) async {
    await saveHomebrewEntitiesBatch([entity], syncLibraries: syncLibraries);
  }
}

/// Result of a [HomebrewPersistenceService.reparseAllHomebrew] run.
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
