import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../logging_service.dart';
import '../persistence/homebrew_persistence_service.dart';
import 'community_compendium_adapters.dart';

/// Identified classification of community compendium JSON payloads.
enum CompendiumImportType {
  spell,
  monster,
  item,
  characterClass,
  subclass,
  race,
  feat,
  background,
  bundle,
  unknown,
}

/// Comprehensive summary report of a community compendium ingestion operation.
class CompendiumImportResult {
  final List<Spell> spells;
  final List<Monster> monsters;
  final List<EquipmentItem> items;
  final List<CharacterClass> classes;
  final List<Subclass> subclasses;
  final List<Race> races;
  final List<Feat> feats;
  final List<Background> backgrounds;
  final List<String> warnings;
  final List<String> errors;

  const CompendiumImportResult({
    this.spells = const [],
    this.monsters = const [],
    this.items = const [],
    this.classes = const [],
    this.subclasses = const [],
    this.races = const [],
    this.feats = const [],
    this.backgrounds = const [],
    this.warnings = const [],
    this.errors = const [],
  });

  int get totalImported =>
      spells.length +
      monsters.length +
      items.length +
      classes.length +
      subclasses.length +
      races.length +
      feats.length +
      backgrounds.length;

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => totalImported > 0 && errors.isEmpty;
}

/// Service orchestrating community compendium JSON ingestion, schema detection, and compendium synchronization.
class CommunityCompendiumImporterService {
  final CommunityCompendiumAdapters adapters;
  final HomebrewPersistenceService homebrewService;

  CommunityCompendiumImporterService({
    CommunityCompendiumAdapters? adapters,
    HomebrewPersistenceService? homebrewService,
  })  : adapters = adapters ?? CommunityCompendiumAdapters(),
        homebrewService = homebrewService ?? HomebrewPersistenceService();

  /// Inspects a JSON map to detect entity type.
  CompendiumImportType detectType(Map<String, dynamic> json) {
    if (json.containsKey('spell') && json['spell'] is List) return CompendiumImportType.bundle;
    if (json.containsKey('monster') && json['monster'] is List) return CompendiumImportType.bundle;
    if (json.containsKey('item') && json['item'] is List) return CompendiumImportType.bundle;
    if (json.containsKey('class') && json['class'] is List) return CompendiumImportType.bundle;
    if (json.containsKey('subclass') && json['subclass'] is List) return CompendiumImportType.bundle;
    if (json.containsKey('race') && json['race'] is List) return CompendiumImportType.bundle;
    if (json.containsKey('feat') && json['feat'] is List) return CompendiumImportType.bundle;
    if (json.containsKey('background') && json['background'] is List) return CompendiumImportType.bundle;

    // Single entity detection
    if (json.containsKey('school') && json.containsKey('level')) return CompendiumImportType.spell;
    if (json.containsKey('cr') || (json.containsKey('ac') && json.containsKey('hp'))) return CompendiumImportType.monster;
    if (json.containsKey('rarity') || (json.containsKey('type') && json.containsKey('reqAttune'))) return CompendiumImportType.item;
    if (json.containsKey('hd') && json.containsKey('name')) return CompendiumImportType.characterClass;
    if (json.containsKey('className') && json.containsKey('shortName')) return CompendiumImportType.subclass;
    if (json.containsKey('speed') && json.containsKey('size') && !json.containsKey('cr')) return CompendiumImportType.race;
    if (json.containsKey('category') && json.containsKey('prerequisite')) return CompendiumImportType.feat;
    if (json.containsKey('skillProficiencies') || (json.containsKey('name') && json.containsKey('entries') && !json.containsKey('cr'))) {
      return CompendiumImportType.background;
    }

    return CompendiumImportType.unknown;
  }

  /// Parses raw JSON string (single entity, list of entities, or root bundle map) and optionally syncs to registries.
  Future<CompendiumImportResult> importJsonString(
    String rawJson, {
    bool persistAndSync = true,
    RulesetVersion? forceRuleset,
  }) async {
    try {
      final clean = rawJson.trim();
      if (clean.isEmpty) {
        return const CompendiumImportResult(errors: ['JSON payload is empty.']);
      }

      final decoded = json.decode(clean);

      List<Spell> spells = [];
      List<Monster> monsters = [];
      List<EquipmentItem> items = [];
      List<CharacterClass> classes = [];
      List<Subclass> subclasses = [];
      List<Race> races = [];
      List<Feat> feats = [];
      List<Background> backgrounds = [];
      List<String> warnings = [];
      List<String> errors = [];

      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _processSingleEntity(
              item,
              spells: spells,
              monsters: monsters,
              items: items,
              classes: classes,
              subclasses: subclasses,
              races: races,
              feats: feats,
              backgrounds: backgrounds,
              warnings: warnings,
              errors: errors,
              forceRuleset: forceRuleset,
            );
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        _processMapPayload(
          decoded,
          spells: spells,
          monsters: monsters,
          items: items,
          classes: classes,
          subclasses: subclasses,
          races: races,
          feats: feats,
          backgrounds: backgrounds,
          warnings: warnings,
          errors: errors,
          forceRuleset: forceRuleset,
        );
      } else {
        return const CompendiumImportResult(
          errors: ['Root JSON structure must be an Object Map or List of entities.'],
        );
      }

      // Persist to SharedPreferences and update in-memory runtime registries
      if (persistAndSync) {
        if (spells.isNotEmpty) await homebrewService.saveCustomSpellsBatch(spells);
        if (monsters.isNotEmpty) await homebrewService.saveCustomMonstersBatch(monsters);
        if (items.isNotEmpty) await homebrewService.saveCustomItemsBatch(items);
        if (classes.isNotEmpty) await homebrewService.saveCustomClassesBatch(classes);
        if (subclasses.isNotEmpty) await homebrewService.saveCustomSubclassesBatch(subclasses);
        if (races.isNotEmpty) await homebrewService.saveCustomRacesBatch(races);
        if (feats.isNotEmpty) await homebrewService.saveCustomFeatsBatch(feats);
        if (backgrounds.isNotEmpty) await homebrewService.saveCustomBackgroundsBatch(backgrounds);

        await homebrewService.syncToLibraries();
      }

      return CompendiumImportResult(
        spells: List.unmodifiable(spells),
        monsters: List.unmodifiable(monsters),
        items: List.unmodifiable(items),
        classes: List.unmodifiable(classes),
        subclasses: List.unmodifiable(subclasses),
        races: List.unmodifiable(races),
        feats: List.unmodifiable(feats),
        backgrounds: List.unmodifiable(backgrounds),
        warnings: List.unmodifiable(warnings),
        errors: List.unmodifiable(errors),
      );
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to import compendium JSON payload',
      );
      return CompendiumImportResult(errors: ['JSON parse error: $e']);
    }
  }

  void _processMapPayload(
    Map<String, dynamic> map, {
    required List<Spell> spells,
    required List<Monster> monsters,
    required List<EquipmentItem> items,
    required List<CharacterClass> classes,
    required List<Subclass> subclasses,
    required List<Race> races,
    required List<Feat> feats,
    required List<Background> backgrounds,
    required List<String> warnings,
    required List<String> errors,
    RulesetVersion? forceRuleset,
  }) {
    bool processedAsBundle = false;

    if (map['spell'] is List) {
      for (final e in map['spell']) {
        if (e is Map<String, dynamic>) {
          try {
            spells.add(adapters.parseSpell(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped spell ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (map['monster'] is List) {
      for (final e in map['monster']) {
        if (e is Map<String, dynamic>) {
          try {
            monsters.add(adapters.parseMonster(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped monster ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (map['item'] is List) {
      for (final e in map['item']) {
        if (e is Map<String, dynamic>) {
          try {
            items.add(adapters.parseItem(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped item ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (map['class'] is List) {
      for (final e in map['class']) {
        if (e is Map<String, dynamic>) {
          try {
            classes.add(adapters.parseClass(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped class ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (map['subclass'] is List) {
      for (final e in map['subclass']) {
        if (e is Map<String, dynamic>) {
          try {
            subclasses.add(adapters.parseSubclass(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped subclass ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (map['race'] is List) {
      for (final e in map['race']) {
        if (e is Map<String, dynamic>) {
          try {
            races.add(adapters.parseRace(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped race ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (map['feat'] is List) {
      for (final e in map['feat']) {
        if (e is Map<String, dynamic>) {
          try {
            feats.add(adapters.parseFeat(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped feat ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (map['background'] is List) {
      for (final e in map['background']) {
        if (e is Map<String, dynamic>) {
          try {
            backgrounds.add(adapters.parseBackground(e, forceRuleset: forceRuleset));
          } catch (err) {
            warnings.add('Skipped background ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    if (!processedAsBundle) {
      _processSingleEntity(
        map,
        spells: spells,
        monsters: monsters,
        items: items,
        classes: classes,
        subclasses: subclasses,
        races: races,
        feats: feats,
        backgrounds: backgrounds,
        warnings: warnings,
        errors: errors,
        forceRuleset: forceRuleset,
      );
    }
  }

  void _processSingleEntity(
    Map<String, dynamic> item, {
    required List<Spell> spells,
    required List<Monster> monsters,
    required List<EquipmentItem> items,
    required List<CharacterClass> classes,
    required List<Subclass> subclasses,
    required List<Race> races,
    required List<Feat> feats,
    required List<Background> backgrounds,
    required List<String> warnings,
    required List<String> errors,
    RulesetVersion? forceRuleset,
  }) {
    final type = detectType(item);
    try {
      switch (type) {
        case CompendiumImportType.spell:
          spells.add(adapters.parseSpell(item, forceRuleset: forceRuleset));
        case CompendiumImportType.monster:
          monsters.add(adapters.parseMonster(item, forceRuleset: forceRuleset));
        case CompendiumImportType.item:
          items.add(adapters.parseItem(item, forceRuleset: forceRuleset));
        case CompendiumImportType.characterClass:
          classes.add(adapters.parseClass(item, forceRuleset: forceRuleset));
        case CompendiumImportType.subclass:
          subclasses.add(adapters.parseSubclass(item, forceRuleset: forceRuleset));
        case CompendiumImportType.race:
          races.add(adapters.parseRace(item, forceRuleset: forceRuleset));
        case CompendiumImportType.feat:
          feats.add(adapters.parseFeat(item, forceRuleset: forceRuleset));
        case CompendiumImportType.background:
          backgrounds.add(adapters.parseBackground(item, forceRuleset: forceRuleset));
        case CompendiumImportType.bundle:
        case CompendiumImportType.unknown:
          warnings.add('Unrecognized entity schema for "${item['name'] ?? 'Unknown'}"');
      }
    } catch (e) {
      errors.add('Error parsing entity "${item['name'] ?? 'Unknown'}": $e');
    }
  }
}
