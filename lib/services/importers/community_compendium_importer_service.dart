import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../logging_service.dart';
import '../persistence/homebrew_persistence_service.dart';
import '../acl/compendium_class_parser.dart';
import '../acl/compendium_race_parser.dart';
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
    if (json.containsKey('spell') && json['spell'] is List)
      return CompendiumImportType.bundle;
    if (json.containsKey('monster') && json['monster'] is List)
      return CompendiumImportType.bundle;
    if (json.containsKey('item') && json['item'] is List)
      return CompendiumImportType.bundle;
    if (json.containsKey('class') && json['class'] is List)
      return CompendiumImportType.bundle;
    if (json.containsKey('subclass') && json['subclass'] is List)
      return CompendiumImportType.bundle;
    if (json.containsKey('race') && json['race'] is List)
      return CompendiumImportType.bundle;
    if (json.containsKey('feat') && json['feat'] is List)
      return CompendiumImportType.bundle;
    if (json.containsKey('background') && json['background'] is List)
      return CompendiumImportType.bundle;

    // Single entity detection
    if (json.containsKey('school') && json.containsKey('level'))
      return CompendiumImportType.spell;
    if (json.containsKey('cr') ||
        (json.containsKey('ac') && json.containsKey('hp')))
      return CompendiumImportType.monster;
    if (json.containsKey('rarity') ||
        (json.containsKey('type') && json.containsKey('reqAttune')))
      return CompendiumImportType.item;
    if (json.containsKey('hd') && json.containsKey('name'))
      return CompendiumImportType.characterClass;
    if (json.containsKey('className') && json.containsKey('shortName'))
      return CompendiumImportType.subclass;
    if (json.containsKey('speed') &&
        json.containsKey('size') &&
        !json.containsKey('cr')) return CompendiumImportType.race;
    if (json.containsKey('category') && json.containsKey('prerequisite'))
      return CompendiumImportType.feat;
    if (json.containsKey('skillProficiencies') ||
        (json.containsKey('name') &&
            json.containsKey('entries') &&
            !json.containsKey('cr'))) {
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
          errors: [
            'Root JSON structure must be an Object Map or List of entities.'
          ],
        );
      }

      // Persist to SharedPreferences and update in-memory runtime registries
      if (persistAndSync) {
        if (spells.isNotEmpty)
          await homebrewService.saveCustomSpellsBatch(spells);
        if (monsters.isNotEmpty)
          await homebrewService.saveCustomMonstersBatch(monsters);
        if (items.isNotEmpty) await homebrewService.saveCustomItemsBatch(items);
        if (classes.isNotEmpty)
          await homebrewService.saveCustomClassesBatch(classes);
        if (subclasses.isNotEmpty)
          await homebrewService.saveCustomSubclassesBatch(subclasses);
        if (races.isNotEmpty) {
          await homebrewService.saveCustomRacesBatch(races);
          final subs = [
            for (final r in races) ...r.subraces,
          ];
          if (subs.isNotEmpty) {
            await homebrewService.saveCustomSubracesBatch(subs);
          }
        }
        if (feats.isNotEmpty) await homebrewService.saveCustomFeatsBatch(feats);
        if (backgrounds.isNotEmpty)
          await homebrewService.saveCustomBackgroundsBatch(backgrounds);

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

    // Collect class features & subclass features if present
    final rawSubclassFeatures = <Map<String, dynamic>>[];
    final rawClassFeatures = <Map<String, dynamic>>[];

    void addRawFeatures(dynamic list, bool isSubclassDefault) {
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            final isSub = isSubclassDefault ||
                m['subclassShortName'] != null ||
                m['subclass'] != null ||
                m['subclassName'] != null ||
                m['gainSubclassFeature'] == true;
            if (isSub) {
              rawSubclassFeatures.add(m);
            } else {
              rawClassFeatures.add(m);
            }
          }
        }
      }
    }

    addRawFeatures(
        map['subclassFeature'] ??
            map['subclassFeatures'] ??
            map['subclassfeature'] ??
            map['subclassfeatures'],
        true);
    addRawFeatures(
        map['classFeature'] ??
            map['classFeatures'] ??
            map['classfeature'] ??
            map['classfeatures'],
        false);

    final classFeatureMap = <String, Map<String, dynamic>>{};
    for (final feat in rawClassFeatures) {
      final name = feat['name']?.toString().toLowerCase().trim() ?? '';
      final className =
          (feat['className']?.toString() ?? feat['class']?.toString() ?? '')
              .toLowerCase()
              .trim();
      final source = (feat['source']?.toString() ?? '').toLowerCase().trim();
      final level = (feat['level']?.toString() ?? '').trim();
      if (name.isNotEmpty) {
        classFeatureMap[name] = feat;
        classFeatureMap[name.replaceAll(' ', '-')] = feat;
        if (className.isNotEmpty) {
          classFeatureMap['$name|$className'] = feat;
          if (level.isNotEmpty) {
            classFeatureMap['$name|$className|$level'] = feat;
            if (source.isNotEmpty) {
              classFeatureMap['$name|$className|$source|$level'] = feat;
            }
          }
        }
      }
    }

    final subclassFeatureMap = <String, Map<String, dynamic>>{};
    for (final feat in rawSubclassFeatures) {
      final name = feat['name']?.toString().toLowerCase().trim() ?? '';
      final className =
          (feat['className']?.toString() ?? feat['class']?.toString() ?? '')
              .toLowerCase()
              .trim();
      final subShort = (feat['subclassShortName']?.toString() ??
              feat['shortName']?.toString() ??
              '')
          .toLowerCase()
          .trim();
      final source = (feat['source']?.toString() ?? '').toLowerCase().trim();
      final classSource =
          (feat['classSource']?.toString() ?? '').toLowerCase().trim();
      final subSource =
          (feat['subclassSource']?.toString() ?? source).toLowerCase().trim();
      final level = (feat['level']?.toString() ?? '').trim();

      if (name.isNotEmpty) {
        subclassFeatureMap[name] = feat;
        final nameSlug = name.replaceAll(' ', '-');
        subclassFeatureMap[nameSlug] = feat;
        if (subShort.isNotEmpty) {
          final subSlug = subShort.replaceAll(' ', '-');
          subclassFeatureMap['$name|$subShort'] = feat;
          subclassFeatureMap['$name|$subSlug'] = feat;
          if (className.isNotEmpty) {
            subclassFeatureMap['$name|$className|$subShort'] = feat;
            subclassFeatureMap['$name|$className|$subSlug'] = feat;
          }
          if (level.isNotEmpty) {
            subclassFeatureMap['$name|$subShort|$level'] = feat;
            subclassFeatureMap['$name|$subSlug|$level'] = feat;
            if (className.isNotEmpty) {
              subclassFeatureMap['$name|$className|$subShort|$level'] = feat;
              subclassFeatureMap['$name|$className|$subSlug|$level'] = feat;
              if (classSource.isNotEmpty) {
                subclassFeatureMap[
                        '$name|$className|$classSource|$subShort|$subSource|$level'] =
                    feat;
                subclassFeatureMap[
                    '$name|$className|$classSource|$subShort||$level'] = feat;
              }
              if (source.isNotEmpty) {
                subclassFeatureMap[
                        '$name|$className|$source|$subShort|$subSource|$level'] =
                    feat;
              }
              subclassFeatureMap['$name|$className||$subShort||$level'] = feat;
            }
          }
        }
        if (className.isNotEmpty) {
          subclassFeatureMap['$name|$className'] = feat;
          if (level.isNotEmpty) {
            subclassFeatureMap['$name|$className|$level'] = feat;
          }
        }
        if (level.isNotEmpty) {
          subclassFeatureMap['$name|$level'] = feat;
        }
      }
    }

    if (map['class'] is List) {
      for (final e in map['class']) {
        if (e is Map<String, dynamic>) {
          try {
            classes.add(adapters.parseClass(
              e,
              forceRuleset: forceRuleset,
              classFeatureMap: classFeatureMap,
              subclassFeatureMap: subclassFeatureMap,
            ));
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
            subclasses.add(adapters.parseSubclass(
              e,
              forceRuleset: forceRuleset,
              subclassFeatureMap: subclassFeatureMap,
            ));
          } catch (err) {
            warnings.add('Skipped subclass ${e['name']}: $err');
          }
        }
      }
      processedAsBundle = true;
    }

    // Stitch external subclass features into Subclasses
    if (rawSubclassFeatures.isNotEmpty) {
      final classParser = CompendiumClassParser();
      for (int i = 0; i < subclasses.length; i++) {
        final sub = subclasses[i];
        final cleanSubName = sub.name.toLowerCase().trim();
        final cleanSubShort = sub.shortName.toLowerCase().trim();
        final cleanClass = sub.classSlug.toLowerCase().trim();

        final matchingFeatures = rawSubclassFeatures.where((f) {
          final fClass =
              (f['className']?.toString() ?? f['class']?.toString() ?? '')
                  .toLowerCase()
                  .trim();
          String fSubShort = '';
          if (f['subclassShortName'] != null) {
            fSubShort = f['subclassShortName'].toString().toLowerCase().trim();
          } else if (f['subclassName'] != null) {
            fSubShort = f['subclassName'].toString().toLowerCase().trim();
          } else if (f['subclass'] != null) {
            if (f['subclass'] is Map) {
              fSubShort =
                  (f['subclass']['shortName'] ?? f['subclass']['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
            } else {
              fSubShort = f['subclass'].toString().toLowerCase().trim();
            }
          } else if (f['shortName'] != null) {
            fSubShort = f['shortName'].toString().toLowerCase().trim();
          }

          final matchesClass = fClass.isEmpty ||
              cleanClass.isEmpty ||
              fClass == cleanClass ||
              cleanClass.contains(fClass) ||
              fClass.contains(cleanClass);
          final matchesSub = fSubShort.isNotEmpty &&
              (fSubShort == cleanSubShort ||
                  fSubShort == cleanSubName ||
                  cleanSubName.contains(fSubShort) ||
                  cleanSubShort.contains(fSubShort) ||
                  sub.id.slug
                      .toLowerCase()
                      .contains(fSubShort.replaceAll(' ', '-')));

          return matchesClass && matchesSub;
        }).toList();

        if (matchingFeatures.isNotEmpty) {
          matchingFeatures.sort((a, b) =>
              ((a['level'] as num?) ?? 0).compareTo((b['level'] as num?) ?? 0));
          final featureBlocks = <String>[];
          for (final feat in matchingFeatures) {
            final fName = feat['name']?.toString() ?? '';
            final level =
                feat['level'] != null ? ' (Level ${feat['level']})' : '';
            final fContent = classParser.transformer
                .transformEntries(feat['entries'] ??
                    feat['entry'] ??
                    feat['desc'] ??
                    feat['description'])
                .markdown;
            if (fName.isNotEmpty || fContent.isNotEmpty) {
              featureBlocks.add('### $fName$level\n$fContent');
            }
          }
          if (featureBlocks.isNotEmpty) {
            final isOnlyFallback = sub.featuresMarkdown.isEmpty ||
                !sub.featuresMarkdown.contains('\n\n') ||
                sub.featuresMarkdown.contains('Feature*\n\nGranted at level');
            final combinedMarkdown = isOnlyFallback
                ? featureBlocks.join('\n\n')
                : '${sub.featuresMarkdown}\n\n${featureBlocks.join('\n\n')}';
            subclasses[i] = Subclass(
              id: sub.id,
              name: sub.name,
              classSlug: sub.classSlug,
              shortName: sub.shortName,
              featuresMarkdown: combinedMarkdown.trim(),
              customProperties: sub.customProperties,
            );
          }
        }
      }
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

    final rawSubraces = (map['subrace'] is List)
        ? (map['subrace'] as List)
        : (map['subraces'] is List ? (map['subraces'] as List) : null);
    if (rawSubraces != null) {
      final raceParser = CompendiumRaceParser();
      for (final e in rawSubraces) {
        if (e is Map<String, dynamic>) {
          try {
            final sub = raceParser.parseSubrace(e, forceRuleset: forceRuleset);
            final match =
                races.where((r) => r.id.slug == sub.raceSlug).firstOrNull;
            if (match != null) {
              final idx = races.indexOf(match);
              races[idx] = match.copyWith(subraces: [...match.subraces, sub]);
            } else {
              final parentName = (e['raceName'] as String?) ??
                  sub.raceSlug.replaceAll('-', ' ');
              races.add(Race(
                id: EntityId(slug: sub.raceSlug, ruleset: sub.id.ruleset),
                name: parentName,
                traitsMarkdown: '',
                subraces: [sub],
                customProperties: const {'isShellForSubrace': true},
              ));
            }
          } catch (err) {
            warnings.add('Skipped subrace ${e['name']}: $err');
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
            backgrounds
                .add(adapters.parseBackground(e, forceRuleset: forceRuleset));
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
          subclasses
              .add(adapters.parseSubclass(item, forceRuleset: forceRuleset));
        case CompendiumImportType.race:
          races.add(adapters.parseRace(item, forceRuleset: forceRuleset));
        case CompendiumImportType.feat:
          feats.add(adapters.parseFeat(item, forceRuleset: forceRuleset));
        case CompendiumImportType.background:
          backgrounds
              .add(adapters.parseBackground(item, forceRuleset: forceRuleset));
        case CompendiumImportType.bundle:
        case CompendiumImportType.unknown:
          warnings.add(
              'Unrecognized entity schema for "${item['name'] ?? 'Unknown'}"');
      }
    } catch (e) {
      errors.add('Error parsing entity "${item['name'] ?? 'Unknown'}": $e');
    }
  }
}
