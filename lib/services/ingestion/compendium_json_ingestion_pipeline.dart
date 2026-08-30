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
      if (item is Map<String, dynamic>) {
        final subResult = _ingestSingleEntityMap(item);
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
    // 1. Check if it's a native HomebrewBundle envelope
    if (map.containsKey('schemaVersion') &&
        (map.containsKey('spells') ||
            map.containsKey('monsters') ||
            map.containsKey('items') ||
            map.containsKey('classes') ||
            map.containsKey('races') ||
            map.containsKey('feats') ||
            map.containsKey('backgrounds'))) {
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

    // If the map itself represents a single class (e.g. contains 'hd' and 'name'), delegate to _ingestSingleEntityMap
    if (map.containsKey('hd') && map.containsKey('name')) {
      return _ingestSingleEntityMap(map);
    }

    // Helper to safely loop over list in map key
    void ingestArray(String key, void Function(Map<String, dynamic>) handler, String entityLabel) {
      if (map.containsKey(key) && map[key] is List) {
        for (final raw in map[key]) {
          if (raw is Map<String, dynamic>) {
            try {
              handler(raw);
            } catch (e) {
              errors.add('$entityLabel error (${raw['name'] ?? 'unnamed'}): $e');
            }
          }
        }
      }
    }

    // Spells
    ingestArray('spell', (raw) => spells.add(spellParser.parseSpell(raw)), 'Spell');
    ingestArray('spells', (raw) => spells.add(spellParser.parseSpell(raw)), 'Spell');

    // Monsters / Bestiary
    ingestArray('monster', (raw) => monsters.add(monsterParser.parseMonster(raw)), 'Monster');
    ingestArray('monsters', (raw) => monsters.add(monsterParser.parseMonster(raw)), 'Monster');
    ingestArray('bestiary', (raw) => monsters.add(monsterParser.parseMonster(raw)), 'Monster');

    // Items / Equipment
    ingestArray('item', (raw) => items.add(itemParser.parseItem(raw)), 'Item');
    ingestArray('items', (raw) => items.add(itemParser.parseItem(raw)), 'Item');
    ingestArray('baseitem', (raw) => items.add(itemParser.parseItem(raw)), 'Item');
    ingestArray('magicitems', (raw) => items.add(itemParser.parseItem(raw)), 'Item');
    ingestArray('magicvariants', (raw) => items.add(itemParser.parseItem(raw)), 'Item');

    // Classes & Subclasses
    ingestArray('class', (raw) => classes.add(classParser.parseClass(raw)), 'Class');
    ingestArray('classes', (raw) => classes.add(classParser.parseClass(raw)), 'Class');
    ingestArray('subclass', (raw) => subclasses.add(classParser.parseSubclass(raw)), 'Subclass');
    ingestArray('subclasses', (raw) => subclasses.add(classParser.parseSubclass(raw)), 'Subclass');

    // Races / Species
    ingestArray('race', (raw) => races.add(raceParser.parseRace(raw)), 'Race');
    ingestArray('races', (raw) => races.add(raceParser.parseRace(raw)), 'Race');
    ingestArray('species', (raw) => races.add(raceParser.parseRace(raw)), 'Race');
    ingestArray('subrace', (raw) {
      final sub = raceParser.parseSubrace(raw);
      // Link subrace to race or standalone
      final match = races.where((r) => r.id.slug == sub.raceSlug).firstOrNull;
      if (match != null) {
        final idx = races.indexOf(match);
        races[idx] = match.copyWith(subraces: [...match.subraces, sub]);
      } else {
        // Create parent race holder
        races.add(Race(
          id: EntityId(slug: sub.raceSlug, ruleset: sub.id.ruleset),
          name: sub.raceSlug.replaceAll('-', ' '),
          traitsMarkdown: '',
          subraces: [sub],
        ));
      }
    }, 'Subrace');

    // Feats
    ingestArray('feat', (raw) => feats.add(featParser.parseFeat(raw)), 'Feat');
    ingestArray('feats', (raw) => feats.add(featParser.parseFeat(raw)), 'Feat');

    // Backgrounds
    ingestArray('background', (raw) => backgrounds.add(backgroundParser.parseBackground(raw)), 'Background');
    ingestArray('backgrounds', (raw) => backgrounds.add(backgroundParser.parseBackground(raw)), 'Background');

    // Other Compendium Entities
    ingestArray('table', (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Table')), 'Table');
    ingestArray('tables', (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Table')), 'Table');
    ingestArray('optionalfeature', (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Optional Feature')), 'Optional Feature');
    ingestArray('reward', (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Reward')), 'Reward');
    ingestArray('condition', (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Condition')), 'Condition');
    ingestArray('hazard', (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Hazard')), 'Hazard');
    ingestArray('variantrule', (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, defaultCategory: 'Rule')), 'Rule');

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
    // 1. Identify Spells (has school or level + time)
    if (map.containsKey('school') || (map.containsKey('level') && map.containsKey('time'))) {
      try {
        final spell = spellParser.parseSpell(map);
        return IngestionBatchResult(spells: [spell]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse spell: $e']);
      }
    }

    // 2. Identify Monsters (has cr or hp or ac)
    if (map.containsKey('cr') || (map.containsKey('hp') && map.containsKey('ac'))) {
      try {
        final monster = monsterParser.parseMonster(map);
        return IngestionBatchResult(monsters: [monster]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse monster: $e']);
      }
    }

    // 3. Identify Classes (has hd and proficiency or classFeatures)
    if (map.containsKey('hd') || map.containsKey('classFeatures') || (map.containsKey('proficiency') && map.containsKey('subclasses'))) {
      try {
        final cl = classParser.parseClass(map);
        return IngestionBatchResult(classes: [cl]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse class: $e']);
      }
    }

    // 4. Identify Subclasses (has className or classSlug)
    if (map.containsKey('className') || map.containsKey('classSlug') || map.containsKey('subclassFeatures')) {
      try {
        final sub = classParser.parseSubclass(map);
        return IngestionBatchResult(subclasses: [sub]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse subclass: $e']);
      }
    }

    // 5. Identify Races / Species (has speed or size without ac/hp, or traits)
    if ((map.containsKey('size') || map.containsKey('speed')) && !map.containsKey('ac') && !map.containsKey('hp')) {
      try {
        final race = raceParser.parseRace(map);
        return IngestionBatchResult(races: [race]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse race: $e']);
      }
    }

    // 6. Identify Feats (has prerequisite or featType or category)
    if (map.containsKey('prerequisite') || map.containsKey('featType') || (map['category']?.toString().toLowerCase().contains('feat') ?? false)) {
      try {
        final feat = featParser.parseFeat(map);
        return IngestionBatchResult(feats: [feat]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse feat: $e']);
      }
    }

    // 7. Identify Backgrounds (has skillProficiencies or backgroundFeature)
    if (map.containsKey('skillProficiencies') || map.containsKey('backgroundFeature')) {
      try {
        final bg = backgroundParser.parseBackground(map);
        return IngestionBatchResult(backgrounds: [bg]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse background: $e']);
      }
    }

    // 8. Identify Items (has rarity, itemType, reqAttune, or entries)
    if (map.containsKey('rarity') || map.containsKey('type') || map.containsKey('reqAttune')) {
      try {
        final item = itemParser.parseItem(map);
        return IngestionBatchResult(items: [item]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse item: $e']);
      }
    }

    // 9. Generic Fallback (tables, rules, etc.)
    if (map.containsKey('name')) {
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
