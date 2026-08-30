import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_bundle.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../acl/compendium_background_parser.dart';
import '../acl/compendium_class_parser.dart';
import '../acl/compendium_feat_parser.dart';
import '../acl/compendium_generic_entry_parser.dart';
import '../acl/compendium_item_parser.dart';
import '../acl/compendium_monster_parser.dart';
import '../acl/compendium_race_parser.dart';
import '../acl/compendium_spell_parser.dart';
import '../acl/entry_tag_transformer.dart';

/// Diagnostic summary of a JSON compendium ingestion operation.
class IngestionBatchResult {
  final List<Spell> spells;
  final List<Monster> monsters;
  final List<EquipmentItem> items;
  final List<CharacterClass> classes;
  final List<Subclass> subclasses;
  final List<Race> races;
  final List<Feat> feats;
  final List<Background> backgrounds;
  final List<HomebrewCompendiumEntry> otherEntries;
  final List<String> errors;

  const IngestionBatchResult({
    this.spells = const [],
    this.monsters = const [],
    this.items = const [],
    this.classes = const [],
    this.subclasses = const [],
    this.races = const [],
    this.feats = const [],
    this.backgrounds = const [],
    this.otherEntries = const [],
    this.errors = const [],
  });

  int get totalEntities =>
      spells.length +
      monsters.length +
      items.length +
      classes.length +
      subclasses.length +
      races.length +
      feats.length +
      backgrounds.length +
      otherEntries.length;

  bool get hasErrors => errors.isNotEmpty;

  /// Converts this ingestion result into a portable [HomebrewBundle].
  HomebrewBundle toBundle({
    String? bundleName,
    String? author,
    String? description,
  }) {
    return HomebrewBundle(
      appVersion: '1.0.0',
      exportedAt: DateTime.now(),
      bundleName: bundleName,
      author: author,
      description: description,
      spells: spells,
      monsters: monsters,
      items: items,
      classes: classes,
      subclasses: subclasses,
      races: races,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: otherEntries,
    );
  }
}

/// Generic, legally compliant ingestion pipeline for standard tabletop compendium JSON datasets
/// and portable HomebrewBundle schemas.
class CompendiumJsonIngestionPipeline {
  final EntryTagTransformer transformer;
  final CompendiumSpellParser spellParser;
  final CompendiumMonsterParser monsterParser;
  final CompendiumItemParser itemParser;
  final CompendiumClassParser classParser;
  final CompendiumRaceParser raceParser;
  final CompendiumFeatParser featParser;
  final CompendiumBackgroundParser backgroundParser;
  final CompendiumGenericEntryParser genericParser;

  CompendiumJsonIngestionPipeline({
    EntryTagTransformer? transformer,
    CompendiumSpellParser? spellParser,
    CompendiumMonsterParser? monsterParser,
    CompendiumItemParser? itemParser,
    CompendiumClassParser? classParser,
    CompendiumRaceParser? raceParser,
    CompendiumFeatParser? featParser,
    CompendiumBackgroundParser? backgroundParser,
    CompendiumGenericEntryParser? genericParser,
  })  : transformer = transformer ?? EntryTagTransformer(),
        spellParser = spellParser ??
            CompendiumSpellParser(transformer: transformer ?? EntryTagTransformer()),
        monsterParser = monsterParser ??
            CompendiumMonsterParser(transformer: transformer ?? EntryTagTransformer()),
        itemParser = itemParser ??
            CompendiumItemParser(transformer: transformer ?? EntryTagTransformer()),
        classParser = classParser ??
            CompendiumClassParser(transformer: transformer ?? EntryTagTransformer()),
        raceParser = raceParser ??
            CompendiumRaceParser(transformer: transformer ?? EntryTagTransformer()),
        featParser = featParser ??
            CompendiumFeatParser(transformer: transformer ?? EntryTagTransformer()),
        backgroundParser = backgroundParser ??
            CompendiumBackgroundParser(transformer: transformer ?? EntryTagTransformer()),
        genericParser = genericParser ??
            CompendiumGenericEntryParser(transformer: transformer ?? EntryTagTransformer());

  /// Parses arbitrary JSON text containing single entity maps, multi-entity bundles, or [HomebrewBundle] envelopes.
  IngestionBatchResult ingestJsonString(String jsonString) {
    try {
      final clean = jsonString.trim();
      final decoded = json.decode(clean);

      if (decoded is List) {
        return _ingestList(decoded);
      } else if (decoded is Map<String, dynamic>) {
        return _ingestMap(decoded);
      } else if (decoded is Map) {
        return _ingestMap(Map<String, dynamic>.from(decoded));
      } else {
        return const IngestionBatchResult(
          errors: ['Invalid JSON format: expected Map or List at root.'],
        );
      }
    } catch (e) {
      return IngestionBatchResult(
        errors: ['Failed to parse JSON: $e'],
      );
    }
  }

  IngestionBatchResult _ingestList(List<dynamic> list) {
    final spells = <Spell>[];
    final monsters = <Monster>[];
    final items = <EquipmentItem>[];
    final classes = <CharacterClass>[];
    final subclasses = <Subclass>[];
    final races = <Race>[];
    final feats = <Feat>[];
    final backgrounds = <Background>[];
    final otherEntries = <HomebrewCompendiumEntry>[];
    final errors = <String>[];

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map) {
        final subResult = _ingestSingleEntityMap(Map<String, dynamic>.from(item));
        spells.addAll(subResult.spells);
        monsters.addAll(subResult.monsters);
        items.addAll(subResult.items);
        classes.addAll(subResult.classes);
        subclasses.addAll(subResult.subclasses);
        races.addAll(subResult.races);
        feats.addAll(subResult.feats);
        backgrounds.addAll(subResult.backgrounds);
        otherEntries.addAll(subResult.otherEntries);
        errors.addAll(subResult.errors.map((e) => 'Item #$i: $e'));
      }
    }

    return IngestionBatchResult(
      spells: spells,
      monsters: monsters,
      items: items,
      classes: classes,
      subclasses: subclasses,
      races: races,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: otherEntries,
      errors: errors,
    );
  }

  IngestionBatchResult _ingestMap(Map<String, dynamic> map) {
    final lowerKeys = map.keys.map((k) => k.toLowerCase()).toSet();

    // 1. Check if it's a native HomebrewBundle envelope
    if (lowerKeys.contains('schemaversion') &&
        (lowerKeys.contains('spells') ||
            lowerKeys.contains('monsters') ||
            lowerKeys.contains('items') ||
            lowerKeys.contains('classes') ||
            lowerKeys.contains('races') ||
            lowerKeys.contains('feats') ||
            lowerKeys.contains('backgrounds'))) {
      try {
        final bundle = HomebrewBundle.fromMap(map);
        return IngestionBatchResult(
          spells: bundle.spells,
          monsters: bundle.monsters,
          items: bundle.items,
          classes: bundle.classes,
          subclasses: bundle.subclasses,
          races: bundle.races,
          feats: bundle.feats,
          backgrounds: bundle.backgrounds,
          otherEntries: bundle.otherEntries,
        );
      } catch (e) {
        // Fall back to standard map ingestion
      }
    }

    // 2. If the map itself represents a single class definition (e.g. has 'hd' and 'name')
    if ((lowerKeys.contains('hd') || lowerKeys.contains('hitdie') || (lowerKeys.contains('name') && lowerKeys.contains('subclasslevel'))) &&
        !lowerKeys.contains('class') &&
        !lowerKeys.contains('classes') &&
        !lowerKeys.contains('spell') &&
        !lowerKeys.contains('monster')) {
      return _ingestSingleEntityMap(map);
    }

    final spells = <Spell>[];
    final monsters = <Monster>[];
    final items = <EquipmentItem>[];
    final classes = <CharacterClass>[];
    final subclasses = <Subclass>[];
    final races = <Race>[];
    final feats = <Feat>[];
    final backgrounds = <Background>[];
    final otherEntries = <HomebrewCompendiumEntry>[];
    final errors = <String>[];

    // Helper to find key case-insensitively
    List<dynamic>? findListForKeys(List<String> candidateKeys) {
      for (final candidate in candidateKeys) {
        final candLower = candidate.toLowerCase();
        for (final entry in map.entries) {
          if (entry.key.toLowerCase() == candLower && entry.value is List) {
            return entry.value as List;
          }
        }
      }
      return null;
    }

    // Helper to safely loop over list in matching map keys
    void ingestKeys(List<String> candidateKeys, void Function(Map<String, dynamic>) handler, String entityLabel) {
      final list = findListForKeys(candidateKeys);
      if (list != null) {
        for (final raw in list) {
          if (raw is Map) {
            try {
              handler(Map<String, dynamic>.from(raw));
            } catch (e) {
              errors.add('$entityLabel error (${raw['name'] ?? 'unnamed'}): $e');
            }
          }
        }
      }
    }

    // Spells
    ingestKeys(['spell', 'spells'], (raw) => spells.add(spellParser.parseSpell(raw)), 'Spell');

    // Monsters / Bestiary
    ingestKeys(['monster', 'monsters', 'bestiary', 'creature', 'creatures', 'npc', 'npcs'],
        (raw) => monsters.add(monsterParser.parseMonster(raw)), 'Monster');

    // Items / Equipment
    ingestKeys(['item', 'items', 'baseitem', 'magicitems', 'magicitem', 'magicvariants', 'equipment'],
        (raw) => items.add(itemParser.parseItem(raw)), 'Item');

    // Classes & Subclasses
    ingestKeys(['class', 'classes'], (raw) {
      final parsedClass = classParser.parseClass(raw);
      classes.add(parsedClass);
      // Automatically extract any embedded subclasses as standalone subclasses
      // so additive additions to SRD classes are tracked and importable!
      for (final sub in parsedClass.subclasses) {
        if (!subclasses.any((s) => s.id.slug == sub.id.slug)) {
          subclasses.add(sub);
        }
      }
    }, 'Class');

    ingestKeys(['subclass', 'subclasses'], (raw) {
      final sub = classParser.parseSubclass(raw);
      if (!subclasses.any((s) => s.id.slug == sub.id.slug)) {
        subclasses.add(sub);
      }
      final matchClass = classes.where((c) => c.id.slug == sub.classSlug || c.name.toLowerCase() == sub.classSlug.toLowerCase()).firstOrNull;
      if (matchClass != null) {
        if (!matchClass.subclasses.any((s) => s.id.slug == sub.id.slug)) {
          final idx = classes.indexOf(matchClass);
          classes[idx] = matchClass.copyWith(subclasses: [...matchClass.subclasses, sub]);
        }
      }
    }, 'Subclass');

    // Races / Species
    ingestKeys(['race', 'races', 'species', 'lineage', 'lineages'], (raw) => races.add(raceParser.parseRace(raw)), 'Race');
    ingestKeys(['subrace', 'subraces'], (raw) {
      final sub = raceParser.parseSubrace(raw);
      final match = races.where((r) => r.id.slug == sub.raceSlug).firstOrNull;
      if (match != null) {
        final idx = races.indexOf(match);
        races[idx] = match.copyWith(subraces: [...match.subraces, sub]);
      } else {
        races.add(Race(
          id: EntityId(slug: sub.raceSlug, ruleset: sub.id.ruleset),
          name: sub.raceSlug.replaceAll('-', ' '),
          traitsMarkdown: '',
          subraces: [sub],
        ));
      }
    }, 'Subrace');

    // Feats
    ingestKeys(['feat', 'feats'], (raw) => feats.add(featParser.parseFeat(raw)), 'Feat');

    // Backgrounds
    ingestKeys(['background', 'backgrounds'], (raw) => backgrounds.add(backgroundParser.parseBackground(raw)), 'Background');

    // Eldritch Invocations
    ingestKeys([
      'invocation',
      'invocations',
      'eldritchinvocation',
      'eldritchinvocations',
    ], (raw) {
      otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Eldritch Invocation'));
    }, 'Eldritch Invocation');

    // Other Compendium Entities & Optional Features
    ingestKeys(['optionalfeature', 'optionalfeatures'], (raw) {
      final featureType = raw['featureType']?.toString().toUpperCase() ?? '';
      final name = raw['name']?.toString().toLowerCase() ?? '';
      String category = 'Optional Feature';
      if (featureType.contains('EI') || name.contains('invocation') || raw['isInvocation'] == true) {
        category = 'Eldritch Invocation';
      } else if (featureType.contains('MM') || name.contains('metamagic')) {
        category = 'Metamagic';
      } else if (featureType.contains('MAN') || featureType.contains('BM') || name.contains('maneuver')) {
        category = 'Maneuver';
      } else if (featureType.contains('AI') || featureType.contains('INF') || name.contains('infusion')) {
        category = 'Infusion';
      }
      otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: category));
    }, 'Optional Feature');

    ingestKeys(['table', 'tables'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Table')), 'Table');
    ingestKeys(['reward', 'rewards'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Reward')), 'Reward');
    ingestKeys(['condition', 'conditions'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Condition')), 'Condition');
    ingestKeys(['hazard', 'hazards'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Hazard')), 'Hazard');
    ingestKeys(['variantrule', 'variantrules', 'rule', 'rules'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Rule')), 'Rule');

    // Class & Subclass feature array handling (stitches external features into Subclass and Class definitions)
    final rawSubclassFeatures = <Map<String, dynamic>>[];
    ingestKeys(['subclassfeature', 'subclassfeatures'], (raw) {
      rawSubclassFeatures.add(raw);
    }, 'Subclass Feature');

    final rawClassFeatures = <Map<String, dynamic>>[];
    ingestKeys(['classfeature', 'classfeatures'], (raw) {
      rawClassFeatures.add(raw);
    }, 'Class Feature');

    // Stitch external subclass features into Subclasses
    if (rawSubclassFeatures.isNotEmpty) {
      final entryTransformer = classParser.transformer;
      for (int i = 0; i < subclasses.length; i++) {
        final sub = subclasses[i];
        final cleanSubName = sub.name.toLowerCase().trim();
        final cleanSubShort = sub.shortName.toLowerCase().trim();
        final cleanClass = sub.classSlug.toLowerCase().trim();

        final matchingFeatures = rawSubclassFeatures.where((f) {
          final fClass = (f['className']?.toString() ?? f['class']?.toString() ?? '').toLowerCase().trim();
          final fSubShort = (f['subclassShortName']?.toString() ?? f['shortName']?.toString() ?? '').toLowerCase().trim();
          final fSubName = (f['subclassName']?.toString() ?? f['name']?.toString() ?? '').toLowerCase().trim();

          final matchesClass = fClass.isEmpty || cleanClass.isEmpty || fClass == cleanClass || cleanClass.contains(fClass) || fClass.contains(cleanClass);
          final matchesSub = fSubShort == cleanSubShort ||
              fSubShort == cleanSubName ||
              fSubName == cleanSubName ||
              fSubName == cleanSubShort ||
              (fSubShort.isNotEmpty && cleanSubName.contains(fSubShort));

          return matchesClass && matchesSub;
        }).toList();

        if (matchingFeatures.isNotEmpty) {
          matchingFeatures.sort((a, b) => ((a['level'] as num?) ?? 0).compareTo((b['level'] as num?) ?? 0));
          final featureBlocks = <String>[];
          for (final feat in matchingFeatures) {
            final fName = feat['name']?.toString() ?? '';
            final level = feat['level'] != null ? ' (Level ${feat['level']})' : '';
            final fContent = entryTransformer.transformEntries(feat['entries'] ?? feat['entry'] ?? feat['desc'] ?? feat['description']).markdown;
            if (fName.isNotEmpty || fContent.isNotEmpty) {
              featureBlocks.add('### $fName$level\n$fContent');
            }
          }
          if (featureBlocks.isNotEmpty) {
            final combinedMarkdown = sub.featuresMarkdown.isEmpty || (sub.featuresMarkdown.contains('|') && !sub.featuresMarkdown.contains('\n'))
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

      // Keep class.subclasses synchronized with the newly enriched subclasses
      for (int i = 0; i < classes.length; i++) {
        final cls = classes[i];
        final updatedSubs = <Subclass>[];
        for (final sub in cls.subclasses) {
          final matchingSub = subclasses.where((s) => s.id.slug == sub.id.slug).firstOrNull;
          updatedSubs.add(matchingSub ?? sub);
        }
        classes[i] = cls.copyWith(subclasses: updatedSubs);
      }
    }

    // Stitch external class features into Classes
    if (rawClassFeatures.isNotEmpty) {
      final entryTransformer = classParser.transformer;
      for (int i = 0; i < classes.length; i++) {
        final cls = classes[i];
        final cleanClass = cls.id.slug.toLowerCase().trim();
        final cleanClassName = cls.name.toLowerCase().trim();

        final matchingFeatures = rawClassFeatures.where((f) {
          final fClass = (f['className']?.toString() ?? f['class']?.toString() ?? '').toLowerCase().trim();
          return fClass == cleanClass || fClass == cleanClassName;
        }).toList();

        if (matchingFeatures.isNotEmpty) {
          matchingFeatures.sort((a, b) => ((a['level'] as num?) ?? 0).compareTo((b['level'] as num?) ?? 0));
          final featureBlocks = <String>[];
          for (final feat in matchingFeatures) {
            final fName = feat['name']?.toString() ?? '';
            final level = feat['level'] != null ? ' (Level ${feat['level']})' : '';
            final fContent = entryTransformer.transformEntries(feat['entries'] ?? feat['entry'] ?? feat['desc'] ?? feat['description']).markdown;
            if (fName.isNotEmpty || fContent.isNotEmpty) {
              featureBlocks.add('### $fName$level\n$fContent');
            }
          }
          if (featureBlocks.isNotEmpty) {
            final combinedMarkdown = cls.featuresMarkdown.isEmpty || (cls.featuresMarkdown.contains('|') && !cls.featuresMarkdown.contains('\n'))
                ? featureBlocks.join('\n\n')
                : '${cls.featuresMarkdown}\n\n${featureBlocks.join('\n\n')}';
            classes[i] = cls.copyWith(featuresMarkdown: combinedMarkdown.trim());
          }
        }
      }
    }

    // If no bundle arrays found, attempt single entity map parse
    final hasAny = spells.isNotEmpty ||
        monsters.isNotEmpty ||
        items.isNotEmpty ||
        classes.isNotEmpty ||
        subclasses.isNotEmpty ||
        races.isNotEmpty ||
        feats.isNotEmpty ||
        backgrounds.isNotEmpty ||
        otherEntries.isNotEmpty;

    if (!hasAny) {
      return _ingestSingleEntityMap(map);
    }

    return IngestionBatchResult(
      spells: spells,
      monsters: monsters,
      items: items,
      classes: classes,
      subclasses: subclasses,
      races: races,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: otherEntries,
      errors: errors,
    );
  }

  IngestionBatchResult _ingestSingleEntityMap(Map<String, dynamic> map) {
    final lowerKeys = map.keys.map((k) => k.toLowerCase()).toSet();

    // 1. Identify Spells (has school or level + time/duration/range)
    if (lowerKeys.contains('school') ||
        (lowerKeys.contains('level') &&
            (lowerKeys.contains('time') || lowerKeys.contains('duration') || lowerKeys.contains('range')))) {
      try {
        final spell = spellParser.parseSpell(map);
        return IngestionBatchResult(spells: [spell]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse spell: $e']);
      }
    }

    // 2. Identify Monsters (has cr or hp or ac or statblock)
    if (lowerKeys.contains('cr') ||
        (lowerKeys.contains('hp') && (lowerKeys.contains('ac') || lowerKeys.contains('speed')))) {
      try {
        final monster = monsterParser.parseMonster(map);
        return IngestionBatchResult(monsters: [monster]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse monster: $e']);
      }
    }

    // 3. Identify Classes (has hd and proficiency or classFeatures)
    if (lowerKeys.contains('hd') ||
        lowerKeys.contains('classfeatures') ||
        (lowerKeys.contains('proficiency') && lowerKeys.contains('subclasses'))) {
      try {
        final cl = classParser.parseClass(map);
        return IngestionBatchResult(
          classes: [cl],
          subclasses: cl.subclasses,
        );
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse class: $e']);
      }
    }

    // 4. Identify Subclasses (has className, classSlug, subclassFeatures, shortName, subclassTitle, or class)
    if (lowerKeys.contains('classname') ||
        lowerKeys.contains('classslug') ||
        lowerKeys.contains('subclassfeatures') ||
        lowerKeys.contains('subclassshortname') ||
        lowerKeys.contains('subclasstitle') ||
        (lowerKeys.contains('class') && (lowerKeys.contains('features') || lowerKeys.contains('desc') || lowerKeys.contains('entries')))) {
      try {
        final sub = classParser.parseSubclass(map);
        return IngestionBatchResult(subclasses: [sub]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse subclass: $e']);
      }
    }

    // 5. Identify Races / Species (has speed or size without ac/hp, or traits)
    if ((lowerKeys.contains('size') || lowerKeys.contains('speed')) &&
        !lowerKeys.contains('ac') &&
        !lowerKeys.contains('hp') &&
        !lowerKeys.contains('school')) {
      try {
        final race = raceParser.parseRace(map);
        return IngestionBatchResult(races: [race]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse race: $e']);
      }
    }

    // 6. Identify Feats (has prerequisite or featType or category)
    if (lowerKeys.contains('prerequisite') ||
        lowerKeys.contains('feattype') ||
        (map['category']?.toString().toLowerCase().contains('feat') ?? false)) {
      try {
        final feat = featParser.parseFeat(map);
        return IngestionBatchResult(feats: [feat]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse feat: $e']);
      }
    }

    // 7. Identify Backgrounds (has skillProficiencies or backgroundFeature)
    if (lowerKeys.contains('skillproficiencies') || lowerKeys.contains('backgroundfeature')) {
      try {
        final bg = backgroundParser.parseBackground(map);
        return IngestionBatchResult(backgrounds: [bg]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse background: $e']);
      }
    }

    // 8. Identify Items (has rarity, itemType, reqAttune, or entries)
    if (lowerKeys.contains('rarity') ||
        lowerKeys.contains('type') ||
        lowerKeys.contains('reqattune') ||
        lowerKeys.contains('weaponcategory')) {
      try {
        final item = itemParser.parseItem(map);
        return IngestionBatchResult(items: [item]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse item: $e']);
      }
    }

    // 9. Generic Fallback (tables, rules, etc.)
    if (lowerKeys.contains('name')) {
      try {
        final entry = genericParser.parseGenericEntry(map, defaultCategory: 'Custom');
        return IngestionBatchResult(otherEntries: [entry]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse custom compendium entry: $e']);
      }
    }

    return const IngestionBatchResult(
      errors: ['Unrecognized compendium schema. Could not categorize entity.'],
    );
  }
}
