import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/domain/homebrew_other_category.dart';
import '../../../models/monster_codex_data.dart';
import '../../../models/spellbook_data.dart';
import '../../acl/srd_equivalence_index.dart';
import '../app_database_service.dart';
import 'homebrew_category_store.dart';
import 'homebrew_library_sync.dart';
import 'homebrew_raw_payload_store.dart';

/// Category-level and full-reset clearing operations for persisted homebrew
/// data and runtime library caches.
class HomebrewClearing {
  HomebrewClearing({
    required this.rawStore,
    required this.spellsStore,
    required this.monstersStore,
    required this.itemsStore,
    required this.classesStore,
    required this.subclassesStore,
    required this.racesStore,
    required this.featsStore,
    required this.backgroundsStore,
    required this.otherStore,
    required this.loadCustomOtherEntries,
  });

  final HomebrewRawPayloadStore rawStore;
  final HomebrewCategoryStore<Spell> spellsStore;
  final HomebrewCategoryStore<Monster> monstersStore;
  final HomebrewCategoryStore<EquipmentItem> itemsStore;
  final HomebrewCategoryStore<CharacterClass> classesStore;
  final HomebrewCategoryStore<Subclass> subclassesStore;
  final HomebrewCategoryStore<Race> racesStore;
  final HomebrewCategoryStore<Feat> featsStore;
  final HomebrewCategoryStore<Background> backgroundsStore;
  final HomebrewCategoryStore<HomebrewCompendiumEntry> otherStore;
  final Future<List<HomebrewCompendiumEntry>> Function() loadCustomOtherEntries;

  AppDatabaseService get _db => rawStore.db;

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
    await rawStore.saveStringList(
        HomebrewRawPayloadStore.keyHomebrewOther, remainingJson);

    // Prune removed slugs from raw payloads
    for (final slug in removedSlugs) {
      await rawStore.deleteRawPayload(
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

    HomebrewLibrarySync.hydrateCustomOtherSubsystems(remaining);

    return removedSlugs.length;
  }

  /// Batch deletes multiple custom entities by [slugs] for the given [EntityType].
  /// Returns the number of entities removed.
  Future<int> deleteCustomEntitiesBatch(
      EntityType type, List<String> slugs) async {
    if (slugs.isEmpty) return 0;
    final slugSet = slugs.toSet();
    final int count = switch (type) {
      EntityType.spell => await spellsStore.deleteBatch(slugSet),
      EntityType.monster => await monstersStore.deleteBatch(
          slugSet,
          onSlugDeleted: MonsterCodexLibrary.removeHomebrewMonster,
        ),
      EntityType.equipment => await itemsStore.deleteBatch(slugSet),
      EntityType.classDefinition => await classesStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdClassesLibrary.removeCustomClass,
        ),
      EntityType.subclass => await subclassesStore.deleteBatch(slugSet),
      EntityType.species => await racesStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdSpeciesLibrary.removeCustomSpecies,
        ),
      EntityType.feat => await featsStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdFeatsLibrary.removeCustomFeat,
        ),
      EntityType.background => await backgroundsStore.deleteBatch(
          slugSet,
          onSlugDeleted: SrdBackgroundsLibrary.removeCustomBackground,
        ),
      EntityType.custom => await otherStore.deleteBatch(slugSet),
      _ => 0,
    };

    SrdEquivalenceIndex().invalidate();
    return count;
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

    rawStore.invalidateAllCaches();

    MonsterCodexLibrary.clearHomebrewMonsters();
    SpellbookLibrary.setHomebrewSpells([]);
    SrdSpeciesLibrary.setCustomSpecies([]);
    SrdSpeciesLibrary.setCustomSubraces([]);
    SrdFeatsLibrary.setCustomFeats([]);
    SrdClassesLibrary.setCustomClasses([]);
    SrdClassesLibrary.setCustomSubclasses([]);
    SrdBackgroundsLibrary.setCustomBackgrounds([]);
    HomebrewLibrarySync.hydrateCustomOtherSubsystems([]);
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
        HomebrewLibrarySync.hydrateCustomOtherSubsystems([]);
      default:
        break;
    }
    final rawKey = rawStore.rawKeyForType(type);
    final parsedKey = rawStore.parsedKeyForType(type);
    if (parsedKey != null) rawStore.invalidateCategoryCache(parsedKey, rawKey);
    if (type == EntityType.species) {
      rawStore.invalidateCategoryCache(
        HomebrewRawPayloadStore.keyHomebrewSubraces,
        HomebrewRawPayloadStore.keyHomebrewSubracesRaw,
      );
    }
    SrdEquivalenceIndex().invalidate();
  }
}
