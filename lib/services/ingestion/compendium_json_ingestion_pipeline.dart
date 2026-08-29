import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../acl/entry_tag_transformer.dart';
import 'compendium_spell_ingestion_pipeline.dart';

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
}

/// Generic, legally compliant ingestion pipeline for standard tabletop compendium JSON datasets.
class CompendiumJsonIngestionPipeline {
  final EntryTagTransformer _transformer;
  final CompendiumSpellIngestionPipeline _spellPipeline;

  CompendiumJsonIngestionPipeline({
    EntryTagTransformer? transformer,
    CompendiumSpellIngestionPipeline? spellPipeline,
  })  : _transformer = transformer ?? EntryTagTransformer(),
        _spellPipeline = spellPipeline ??
            CompendiumSpellIngestionPipeline(transformer ?? EntryTagTransformer());

  /// Parses arbitrary JSON text containing single entity maps or multi-entity bundles.
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
    ingestArray('spell', (raw) => spells.add(_spellPipeline.ingestSpell(raw)), 'Spell');
    ingestArray('spells', (raw) => spells.add(_spellPipeline.ingestSpell(raw)), 'Spell');

    // Monsters / Bestiary
    ingestArray('monster', (raw) => monsters.add(_ingestMonsterMap(raw)), 'Monster');
    ingestArray('monsters', (raw) => monsters.add(_ingestMonsterMap(raw)), 'Monster');
    ingestArray('bestiary', (raw) => monsters.add(_ingestMonsterMap(raw)), 'Monster');

    // Items / Equipment
    ingestArray('item', (raw) => items.add(_ingestItemMap(raw)), 'Item');
    ingestArray('items', (raw) => items.add(_ingestItemMap(raw)), 'Item');
    ingestArray('baseitem', (raw) => items.add(_ingestItemMap(raw)), 'Item');
    ingestArray('magicitems', (raw) => items.add(_ingestItemMap(raw)), 'Item');

    // Classes & Subclasses
    ingestArray('class', (raw) => classes.add(_ingestClassMap(raw)), 'Class');
    ingestArray('classes', (raw) => classes.add(_ingestClassMap(raw)), 'Class');
    ingestArray('subclass', (raw) => subclasses.add(_ingestSubclassMap(raw)), 'Subclass');
    ingestArray('subclasses', (raw) => subclasses.add(_ingestSubclassMap(raw)), 'Subclass');

    // Races / Species
    ingestArray('race', (raw) => races.add(_ingestRaceMap(raw)), 'Race');
    ingestArray('races', (raw) => races.add(_ingestRaceMap(raw)), 'Race');
    ingestArray('species', (raw) => races.add(_ingestRaceMap(raw)), 'Race');

    // Feats
    ingestArray('feat', (raw) => feats.add(_ingestFeatMap(raw)), 'Feat');
    ingestArray('feats', (raw) => feats.add(_ingestFeatMap(raw)), 'Feat');

    // Backgrounds
    ingestArray('background', (raw) => backgrounds.add(_ingestBackgroundMap(raw)), 'Background');
    ingestArray('backgrounds', (raw) => backgrounds.add(_ingestBackgroundMap(raw)), 'Background');

    // Other Compendium Entities (tables, optional features, conditions, rules, etc.)
    ingestArray('table', (raw) => otherEntries.add(_ingestGenericEntryMap(raw, 'Table')), 'Table');
    ingestArray('tables', (raw) => otherEntries.add(_ingestGenericEntryMap(raw, 'Table')), 'Table');
    ingestArray('optionalfeature', (raw) => otherEntries.add(_ingestGenericEntryMap(raw, 'Optional Feature')), 'Optional Feature');
    ingestArray('reward', (raw) => otherEntries.add(_ingestGenericEntryMap(raw, 'Reward')), 'Reward');
    ingestArray('condition', (raw) => otherEntries.add(_ingestGenericEntryMap(raw, 'Condition')), 'Condition');
    ingestArray('hazard', (raw) => otherEntries.add(_ingestGenericEntryMap(raw, 'Hazard')), 'Hazard');
    ingestArray('variantrule', (raw) => otherEntries.add(_ingestGenericEntryMap(raw, 'Rule')), 'Rule');

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
        final spell = _spellPipeline.ingestSpell(map);
        return IngestionBatchResult(spells: [spell]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse spell: $e']);
      }
    }

    // 2. Identify Monsters (has cr or hp or ac)
    if (map.containsKey('cr') || (map.containsKey('hp') && map.containsKey('ac'))) {
      try {
        final monster = _ingestMonsterMap(map);
        return IngestionBatchResult(monsters: [monster]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse monster: $e']);
      }
    }

    // 3. Identify Classes (has hd and proficiency or classFeatures)
    if (map.containsKey('hd') || map.containsKey('classFeatures') || (map.containsKey('proficiency') && map.containsKey('subclasses'))) {
      try {
        final cl = _ingestClassMap(map);
        return IngestionBatchResult(classes: [cl]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse class: $e']);
      }
    }

    // 4. Identify Subclasses (has className or classSlug)
    if (map.containsKey('className') || map.containsKey('classSlug') || map.containsKey('subclassFeatures')) {
      try {
        final sub = _ingestSubclassMap(map);
        return IngestionBatchResult(subclasses: [sub]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse subclass: $e']);
      }
    }

    // 5. Identify Races / Species (has speed or size without ac/hp, or traits)
    if ((map.containsKey('size') || map.containsKey('speed')) && !map.containsKey('ac') && !map.containsKey('hp')) {
      try {
        final race = _ingestRaceMap(map);
        return IngestionBatchResult(races: [race]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse race: $e']);
      }
    }

    // 6. Identify Feats (has prerequisite or featType or category)
    if (map.containsKey('prerequisite') || map.containsKey('featType') || (map['category']?.toString().toLowerCase().contains('feat') ?? false)) {
      try {
        final feat = _ingestFeatMap(map);
        return IngestionBatchResult(feats: [feat]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse feat: $e']);
      }
    }

    // 7. Identify Backgrounds (has skillProficiencies or backgroundFeature)
    if (map.containsKey('skillProficiencies') || map.containsKey('backgroundFeature')) {
      try {
        final bg = _ingestBackgroundMap(map);
        return IngestionBatchResult(backgrounds: [bg]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse background: $e']);
      }
    }

    // 8. Identify Items (has rarity, itemType, reqAttune, or entries)
    if (map.containsKey('rarity') || map.containsKey('type') || map.containsKey('reqAttune')) {
      try {
        final item = _ingestItemMap(map);
        return IngestionBatchResult(items: [item]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse item: $e']);
      }
    }

    // 9. Generic Fallback (tables, rules, etc.)
    if (map.containsKey('name')) {
      try {
        final entry = _ingestGenericEntryMap(map, 'Custom');
        return IngestionBatchResult(otherEntries: [entry]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse custom compendium entry: $e']);
      }
    }

    return const IngestionBatchResult(
      errors: ['Unrecognized compendium schema. Could not categorize entity.'],
    );
  }

  CharacterClass _ingestClassMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'Unnamed Class';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    String hitDie = 'd8';
    if (map['hd'] is Map) {
      hitDie = 'd${map['hd']['faces'] ?? 8}';
    } else if (map['hd'] != null) {
      final hdStr = map['hd'].toString();
      hitDie = hdStr.startsWith('d') ? hdStr : 'd$hdStr';
    }

    final savingThrows = <String>[];
    if (map['proficiency'] is List) {
      for (final p in map['proficiency']) {
        savingThrows.add(p.toString().toUpperCase());
      }
    } else if (map['savingThrows'] is List) {
      for (final s in map['savingThrows']) {
        savingThrows.add(s.toString().toUpperCase());
      }
    }

    final parsedEntries = _transformer.transformEntries(map['classFeatures'] ?? map['entries']);

    final subList = <Subclass>[];
    if (map['subclasses'] is List) {
      for (final rawSub in map['subclasses']) {
        if (rawSub is Map<String, dynamic>) {
          try {
            subList.add(_ingestSubclassMap(rawSub, defaultClassSlug: slug));
          } catch (_) {}
        }
      }
    }

    return CharacterClass(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      hitDie: hitDie,
      primaryAbility: map['primaryAbility']?.toString(),
      savingThrows: savingThrows,
      spellcastingAbility: map['spellcastingAbility']?.toString(),
      featuresMarkdown: parsedEntries.markdown,
      subclasses: subList,
    );
  }

  Subclass _ingestSubclassMap(Map<String, dynamic> map, {String? defaultClassSlug}) {
    final name = map['name']?.toString() ?? 'Unnamed Subclass';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    final classSlug = map['className'] != null
        ? _slugify(map['className'].toString())
        : (map['classSlug']?.toString() ?? defaultClassSlug ?? '');

    final parsedEntries = _transformer.transformEntries(map['subclassFeatures'] ?? map['entries']);

    return Subclass(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      classSlug: classSlug,
      shortName: map['shortName']?.toString() ?? name,
      featuresMarkdown: parsedEntries.markdown,
    );
  }

  Race _ingestRaceMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'Unnamed Race';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    String size = 'Medium';
    if (map['size'] is List && (map['size'] as List).isNotEmpty) {
      size = map['size'][0].toString();
    } else if (map['size'] != null) {
      size = map['size'].toString();
    }

    String speed = '30 ft.';
    if (map['speed'] is Map) {
      speed = '${map['speed']['walk'] ?? 30} ft.';
    } else if (map['speed'] != null) {
      speed = map['speed'].toString();
      if (!speed.contains('ft')) speed = '$speed ft.';
    }

    final parsedEntries = _transformer.transformEntries(map['trait'] ?? map['entries']);

    final subraces = <Subrace>[];
    if (map['subraces'] is List) {
      for (final rawSub in map['subraces']) {
        if (rawSub is Map<String, dynamic>) {
          final subName = rawSub['name']?.toString() ?? '';
          final subEntries = _transformer.transformEntries(rawSub['trait'] ?? rawSub['entries']);
          subraces.add(Subrace(
            id: EntityId(slug: _slugify(subName), ruleset: ruleset),
            name: subName,
            raceSlug: slug,
            traitsMarkdown: subEntries.markdown,
          ));
        }
      }
    }

    return Race(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      size: size,
      speed: speed,
      abilityScoreSummary: map['ability']?.toString(),
      traitsMarkdown: parsedEntries.markdown,
      subraces: subraces,
    );
  }

  Feat _ingestFeatMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'Unnamed Feat';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    String? prereq;
    if (map['prerequisite'] is List) {
      prereq = (map['prerequisite'] as List).map((e) => e.toString()).join('; ');
    } else if (map['prerequisite'] != null) {
      prereq = map['prerequisite'].toString();
    }

    final category = map['category']?.toString() ??
        map['featType']?.toString() ??
        (map['source']?.toString().contains('2024') == true ? 'General' : 'General');

    final parsedEntries = _transformer.transformEntries(map['entries']);

    return Feat(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      prerequisite: prereq,
      category: category,
      descriptionMarkdown: parsedEntries.markdown,
    );
  }

  Background _ingestBackgroundMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'Unnamed Background';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    final skills = <String>[];
    if (map['skillProficiencies'] is List) {
      for (final s in map['skillProficiencies']) {
        if (s is Map) {
          skills.addAll(s.keys.map((k) => k.toString()));
        } else {
          skills.add(s.toString());
        }
      }
    }

    final tools = <String>[];
    if (map['toolProficiencies'] is List) {
      for (final t in map['toolProficiencies']) {
        tools.add(t.toString());
      }
    }

    final languages = <String>[];
    if (map['languageProficiencies'] is List) {
      for (final l in map['languageProficiencies']) {
        languages.add(l.toString());
      }
    }

    final parsedEntries = _transformer.transformEntries(map['entries']);

    return Background(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      originFeat: map['feat']?.toString() ?? map['feats']?.toString(),
      skillProficiencies: skills,
      toolProficiencies: tools,
      languages: languages,
      descriptionMarkdown: parsedEntries.markdown,
    );
  }

  HomebrewCompendiumEntry _ingestGenericEntryMap(Map<String, dynamic> map, String defaultCategory) {
    final name = map['name']?.toString() ?? map['caption']?.toString() ?? 'Unnamed Entry';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    final category = map['category']?.toString() ?? map['type']?.toString() ?? defaultCategory;
    final parsedEntries = _transformer.transformEntries(map['entries'] ?? map['rows'] ?? map['table']);

    return HomebrewCompendiumEntry(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      category: category,
      descriptionMarkdown: parsedEntries.markdown,
    );
  }

  Monster _ingestMonsterMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'Unnamed Monster';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    // AC
    int ac = 10;
    if (map['ac'] is List && (map['ac'] as List).isNotEmpty) {
      final firstAc = map['ac'][0];
      if (firstAc is int) {
        ac = firstAc;
      } else if (firstAc is Map) {
        ac = (firstAc['ac'] as num?)?.toInt() ?? 10;
      }
    } else if (map['ac'] is num) {
      ac = (map['ac'] as num).toInt();
    }

    // HP
    int hp = 10;
    String hitDice = '2d8';
    if (map['hp'] is Map) {
      hp = (map['hp']['average'] as num?)?.toInt() ?? 10;
      hitDice = map['hp']['formula']?.toString() ?? '2d8';
    } else if (map['hp'] is num) {
      hp = (map['hp'] as num).toInt();
    }

    // CR
    String cr = '1';
    if (map['cr'] is Map) {
      cr = map['cr']['cr']?.toString() ?? '1';
    } else if (map['cr'] != null) {
      cr = map['cr'].toString();
    }

    // Actions & Traits
    final actionsBuffer = StringBuffer();
    final traits = (map['trait'] is List ? map['trait'] : map['traits']) as List?;
    if (traits != null) {
      for (final trait in traits) {
        if (trait is Map) {
          final tName = trait['name'] ?? '';
          final parsedEntries = _transformer.transformEntries(trait['entries']);
          actionsBuffer.writeln('**$tName**: ${parsedEntries.markdown}\n');
        }
      }
    }

    final actions = (map['action'] is List ? map['action'] : map['actions']) as List?;
    if (actions != null) {
      actionsBuffer.writeln('### Actions');
      for (final action in actions) {
        if (action is Map) {
          final aName = action['name'] ?? '';
          final parsedEntries = _transformer.transformEntries(action['entries']);
          actionsBuffer.writeln('**$aName**: ${parsedEntries.markdown}\n');
        }
      }
    }

    final bonusActions = (map['bonus'] is List ? map['bonus'] : map['bonusActions']) as List?;
    if (bonusActions != null && bonusActions.isNotEmpty) {
      actionsBuffer.writeln('\n### Bonus Actions');
      for (final bonus in bonusActions) {
        if (bonus is Map) {
          final bName = bonus['name'] ?? '';
          final parsedEntries = _transformer.transformEntries(bonus['entries']);
          actionsBuffer.writeln('**$bName**: ${parsedEntries.markdown}\n');
        }
      }
    }

    final reactions = (map['reaction'] is List ? map['reaction'] : map['reactions']) as List?;
    if (reactions != null && reactions.isNotEmpty) {
      actionsBuffer.writeln('\n### Reactions');
      for (final reaction in reactions) {
        if (reaction is Map) {
          final rName = reaction['name'] ?? '';
          final parsedEntries = _transformer.transformEntries(reaction['entries']);
          actionsBuffer.writeln('**$rName**: ${parsedEntries.markdown}\n');
        }
      }
    }

    final legendary = (map['legendary'] is List ? map['legendary'] : map['legendaryActions']) as List?;
    if (legendary != null && legendary.isNotEmpty) {
      actionsBuffer.writeln('\n### Legendary Actions');
      for (final leg in legendary) {
        if (leg is Map) {
          final lName = leg['name'] ?? '';
          final parsedEntries = _transformer.transformEntries(leg['entries']);
          actionsBuffer.writeln('**$lName**: ${parsedEntries.markdown}\n');
        }
      }
    }

    // Size & Type
    final size = (map['size'] is List && (map['size'] as List).isNotEmpty)
        ? map['size'][0].toString()
        : (map['size']?.toString() ?? 'Medium');

    String type = 'Humanoid';
    if (map['type'] is Map) {
      type = map['type']['type']?.toString() ?? 'Humanoid';
    } else if (map['type'] != null) {
      type = map['type'].toString();
    }

    return Monster(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      size: size,
      monsterType: type,
      alignment: (map['alignment'] is List)
          ? (map['alignment'] as List).join(' ')
          : (map['alignment']?.toString() ?? 'unaligned'),
      armorClass: ac,
      hitPoints: hp,
      hitDieFormula: hitDice,
      challengeRating: cr,
      actionsMarkdown: actionsBuffer.toString().trim(),
    );
  }

  EquipmentItem _ingestItemMap(Map<String, dynamic> map) {
    final name = map['name']?.toString() ?? 'Unnamed Item';
    final slug = _slugify(name);
    final source = map['source']?.toString().toUpperCase() ?? 'HOMEBREW';
    final ruleset = source.contains('XPHB') || source.contains('SRD52')
        ? RulesetVersion.v2024
        : (source.contains('PHB') || source.contains('SRD')
            ? RulesetVersion.v2014
            : RulesetVersion.homebrew);

    final rarity = map['rarity']?.toString() ?? 'Common';
    final reqAttunement = map['reqAttune'] == true || map['reqAttune'] != null;

    final parsedEntries = _transformer.transformEntries(map['entries']);

    return EquipmentItem(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      itemType: map['type']?.toString() ?? 'Wondrous Item',
      rarity: rarity,
      requiresAttunement: reqAttunement,
      descriptionMarkdown: parsedEntries.markdown,
    );
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
