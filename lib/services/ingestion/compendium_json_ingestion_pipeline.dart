import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../acl/entry_tag_transformer.dart';
import 'compendium_spell_ingestion_pipeline.dart';

/// Diagnostic summary of a JSON compendium ingestion operation.
class IngestionBatchResult {
  final List<Spell> spells;
  final List<Monster> monsters;
  final List<EquipmentItem> items;
  final List<String> errors;

  const IngestionBatchResult({
    this.spells = const [],
    this.monsters = const [],
    this.items = const [],
    this.errors = const [],
  });

  int get totalEntities => spells.length + monsters.length + items.length;
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
    final errors = <String>[];

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map<String, dynamic>) {
        final subResult = _ingestSingleEntityMap(item);
        spells.addAll(subResult.spells);
        monsters.addAll(subResult.monsters);
        items.addAll(subResult.items);
        errors.addAll(subResult.errors.map((e) => 'Item #$i: $e'));
      }
    }

    return IngestionBatchResult(
      spells: spells,
      monsters: monsters,
      items: items,
      errors: errors,
    );
  }

  IngestionBatchResult _ingestMap(Map<String, dynamic> map) {
    final spells = <Spell>[];
    final monsters = <Monster>[];
    final items = <EquipmentItem>[];
    final errors = <String>[];

    // Check for bundle arrays: "spell", "monster", "item", "bestiary", "items"
    if (map.containsKey('spell') && map['spell'] is List) {
      for (final raw in map['spell']) {
        if (raw is Map<String, dynamic>) {
          try {
            spells.add(_spellPipeline.ingestSpell(raw));
          } catch (e) {
            errors.add('Spell error (${raw['name']}): $e');
          }
        }
      }
    }

    if (map.containsKey('monster') && map['monster'] is List) {
      for (final raw in map['monster']) {
        if (raw is Map<String, dynamic>) {
          try {
            monsters.add(_ingestMonsterMap(raw));
          } catch (e) {
            errors.add('Monster error (${raw['name']}): $e');
          }
        }
      }
    }

    if (map.containsKey('item') && map['item'] is List) {
      for (final raw in map['item']) {
        if (raw is Map<String, dynamic>) {
          try {
            items.add(_ingestItemMap(raw));
          } catch (e) {
            errors.add('Item error (${raw['name']}): $e');
          }
        }
      }
    }

    // If no bundle arrays found, attempt single entity map parse
    if (spells.isEmpty && monsters.isEmpty && items.isEmpty) {
      return _ingestSingleEntityMap(map);
    }

    return IngestionBatchResult(
      spells: spells,
      monsters: monsters,
      items: items,
      errors: errors,
    );
  }

  IngestionBatchResult _ingestSingleEntityMap(Map<String, dynamic> map) {
    // 1. Identify Spells (has level & school or time)
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

    // 3. Identify Equipment / Magic Items (has rarity or type)
    if (map.containsKey('rarity') || map.containsKey('type') || map.containsKey('wondrous')) {
      try {
        final item = _ingestItemMap(map);
        return IngestionBatchResult(items: [item]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse item: $e']);
      }
    }

    return const IngestionBatchResult(
      errors: ['Unrecognized entity schema. Ensure valid fields for Spell, Monster, or Item.'],
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
    if (map['trait'] is List) {
      for (final trait in map['trait']) {
        if (trait is Map) {
          final tName = trait['name'] ?? '';
          final parsedEntries = _transformer.transformEntries(trait['entries']);
          actionsBuffer.writeln('### $tName\n${parsedEntries.markdown}\n');
        }
      }
    }
    if (map['action'] is List) {
      actionsBuffer.writeln('### Actions');
      for (final action in map['action']) {
        if (action is Map) {
          final aName = action['name'] ?? '';
          final parsedEntries = _transformer.transformEntries(action['entries']);
          actionsBuffer.writeln('**$aName**: ${parsedEntries.markdown}\n');
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
