import 'dart:convert';

import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/homebrew_bundle.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/spellbook_data.dart';
import '../../acl/homebrew_merge_resolver.dart';
import '../../fluff/entity_fluff_service.dart';
import 'homebrew_raw_payload_store.dart';

/// Bundle export and collision-resolved import operations for persisted homebrew data.
class HomebrewBundleIo {
  HomebrewBundleIo({
    required this.rawStore,
    required this.loadCustomSpells,
    required this.loadCustomMonsters,
    required this.loadCustomItems,
    required this.loadCustomClasses,
    required this.loadCustomSubclasses,
    required this.loadCustomRaces,
    required this.loadCustomSubraces,
    required this.loadCustomFeats,
    required this.loadCustomBackgrounds,
    required this.loadCustomOtherEntries,
    required this.loadCustomFluff,
    required this.saveCustomFluffBatch,
    required this.syncToLibraries,
  });

  final HomebrewRawPayloadStore rawStore;
  final Future<List<Spell>> Function() loadCustomSpells;
  final Future<List<Monster>> Function() loadCustomMonsters;
  final Future<List<EquipmentItem>> Function() loadCustomItems;
  final Future<List<CharacterClass>> Function() loadCustomClasses;
  final Future<List<Subclass>> Function() loadCustomSubclasses;
  final Future<List<Race>> Function() loadCustomRaces;
  final Future<List<Subrace>> Function() loadCustomSubraces;
  final Future<List<Feat>> Function() loadCustomFeats;
  final Future<List<Background>> Function() loadCustomBackgrounds;
  final Future<List<HomebrewCompendiumEntry>> Function() loadCustomOtherEntries;
  final Future<List<EntityFluff>> Function() loadCustomFluff;
  final Future<void> Function(List<EntityFluff>) saveCustomFluffBatch;
  final Future<void> Function() syncToLibraries;

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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
      await rawStore.saveStringList(
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
}
