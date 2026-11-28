import 'dart:math';

/// Pure-Dart seeded input generator for Cleanup slice 19 Fix 4.1.
///
/// Produces plain Map/primitive inputs (zero app imports) for >= 100 spells and
/// >= 100 items per construction path, including SRD-named spells (with case
/// and trailing-space variants) and invented names.
class SeededSpellItemInputs {
  const SeededSpellItemInputs({
    required this.formSpells,
    required this.formItems,
    required this.compendiumSpells,
    required this.compendiumItems,
    required this.communitySpells,
    required this.communityItems,
    required this.ingestionSpells,
    required this.ingestionItems,
    required this.dtoSpells,
    required this.storedLegacySpells,
  });

  final List<Map<String, dynamic>> formSpells;
  final List<Map<String, dynamic>> formItems;
  final List<Map<String, dynamic>> compendiumSpells;
  final List<Map<String, dynamic>> compendiumItems;
  final List<Map<String, dynamic>> communitySpells;
  final List<Map<String, dynamic>> communityItems;
  final List<Map<String, dynamic>> ingestionSpells;
  final List<Map<String, dynamic>> ingestionItems;
  final List<Map<String, dynamic>> dtoSpells;
  final List<Map<String, dynamic>> storedLegacySpells;
}

const List<String> _kRequiredSrdSpells = [
  'Fireball',
  'Mage Hand',
  'Cure Wounds',
  'Shield',
  'Magic Missile',
  'Bless',
  'Eldritch Blast',
];

const List<String> _kFormSchools = [
  'Abjuration',
  'Conjuration',
  'Divination',
  'Enchantment',
  'Evocation',
  'Illusion',
  'Necromancy',
  'Transmutation',
];

const List<String> _kAclSchoolCodes = ['A', 'C', 'D', 'E', 'V', 'I', 'N', 'T'];

const List<String> _kFormRarities = [
  'Common',
  'Uncommon',
  'Rare',
  'Very Rare',
  'Legendary',
  'Artifact',
];

const List<String> _kItemTypes = [
  'Weapon',
  'Armor',
  'Shield',
  'Potion',
  'Ring',
  'Rod',
  'Scroll',
  'Staff',
  'Wand',
  'Wondrous Item',
  'Adventuring Gear',
];

const List<String> _kInventedPrefixes = [
  'Arcane',
  'Starlight',
  'Cinder',
  'Glimmer',
  'Verdant',
  'Obsidian',
  'Runic',
  'Tempest',
  'Vesper',
  'Aether',
  'Bramble',
  'Frost',
];

const List<String> _kInventedSuffixes = [
  'Bolt',
  'Lance',
  'Ward',
  'Sigil',
  'Veil',
  'Pulse',
  'Spark',
  'Mote',
  'Echo',
  'Grasp',
  'Shard',
  'Crest',
];

const List<String> _kDamageTypes = [
  'fire',
  'cold',
  'lightning',
  'acid',
  'force',
  'necrotic',
  'radiant',
  'psychic',
];

String _pickSpellName(
  Random rng,
  int index,
  List<String> srdPool,
) {
  if (index < _kRequiredSrdSpells.length) {
    return _kRequiredSrdSpells[index];
  }
  // At least 40% SRD-named spells (well above one-third)
  if (index % 5 < 2 && srdPool.isNotEmpty) {
    final base = srdPool[(index * 7 + rng.nextInt(srdPool.length)) % srdPool.length];
    final variant = index % 4;
    if (variant == 1) return base.toLowerCase();
    if (variant == 2) return base.toUpperCase();
    if (variant == 3) return '$base ';
    return base;
  }
  final p = _kInventedPrefixes[index % _kInventedPrefixes.length];
  final s = _kInventedSuffixes[(index ~/ _kInventedPrefixes.length + index) % _kInventedSuffixes.length];
  return '$p $s $index';
}

dynamic _pickClassShape(Random rng, int index) {
  switch (index % 6) {
    case 0:
      return null;
    case 1:
      return <String>[];
    case 2:
      return <String>['Wizard'];
    case 3:
      return <String>['Bard', 'Sorcerer'];
    case 4:
      return <String>['Chronomancer'];
    default:
      return <String>['wIzArD', 'CLERIC'];
  }
}

SeededSpellItemInputs generateSeededSpellItemInputs({
  required List<String> srdSpellNames,
  int seed = 20261127,
  int spellsPerPath = 120,
  int itemsPerPath = 100,
}) {
  final rng = Random(seed);
  final srdPool = List<String>.from(srdSpellNames)..sort();

  final formSpells = <Map<String, dynamic>>[];
  final compendiumSpells = <Map<String, dynamic>>[];
  final communitySpells = <Map<String, dynamic>>[];
  final ingestionSpells = <Map<String, dynamic>>[];
  final dtoSpells = <Map<String, dynamic>>[];
  final storedLegacySpells = <Map<String, dynamic>>[];

  for (var i = 0; i < spellsPerPath; i++) {
    final name = _pickSpellName(rng, i, srdPool);
    final level = i % 10;
    final schoolIdx = i % _kFormSchools.length;
    final school = _kFormSchools[schoolIdx];
    final schoolCode = _kAclSchoolCodes[schoolIdx];
    final actionType = ['action', 'bonusAction', 'reaction', 'minute'][i % 4];
    final durationType = ['instantaneous', 'timed', 'permanent'][i % 3];
    final concentration = i % 3 == 1;
    final verbal = i % 5 != 0;
    final somatic = i % 4 != 0;
    final material = i % 3 == 0;
    final dmgType = _kDamageTypes[i % _kDamageTypes.length];

    formSpells.add({
      'inputId': 'form_spell_$i',
      'name': name,
      'level': level,
      'school': school,
      'actionType': actionType,
      'range': level == 0 ? '30 feet' : '60 feet',
      'durationType': durationType,
      'concentration': concentration,
      'verbal': verbal,
      'somatic': somatic,
      'material': material,
      'materialDescription': material ? 'a pinch of sulfur' : '',
      'diceFormula': level == 0 ? '1d10' : '${level}d6',
      'description': 'Generated spell description $i.',
      'higherLevels': level > 0 ? 'At higher levels: +1d6.' : '',
      'damageType': dmgType,
    });

    final clsShape = _pickClassShape(rng, i);
    final compRaw = <String, dynamic>{
      'name': _pickSpellName(rng, i, srdPool),
      'level': level,
      'school': schoolCode,
      'time': [
        {'number': 1, 'unit': actionType == 'bonusAction' ? 'bonus' : 'action'}
      ],
      'range': {
        'type': 'point',
        'distance': {'type': 'feet', 'amount': 60},
      },
      'components': {
        'v': verbal,
        's': somatic,
        if (material) 'm': 'a crystal prism',
      },
      'duration': [
        {
          'type': durationType == 'instantaneous' ? 'instant' : 'timed',
          if (concentration) 'concentration': true,
        }
      ],
      'entries': ['Compendium spell text $i.'],
      'source': i % 2 == 0 ? 'HB' : 'SRD',
    };
    if (clsShape != null) {
      compRaw['classes'] = {
        'fromClassList': (clsShape as List).map((c) => {'name': c}).toList(),
      };
    }
    compendiumSpells.add({
      'inputId': 'comp_spell_$i',
      'raw': compRaw,
    });

    final commRaw = <String, dynamic>{
      'name': _pickSpellName(rng, i, srdPool),
      'level': level,
      'school': schoolCode,
      'time': [
        {'number': 1, 'unit': actionType == 'bonusAction' ? 'bonus' : 'action'}
      ],
      'range': {
        'type': 'point',
        'distance': {'type': 'feet', 'amount': 60},
      },
      'components': {
        'v': verbal,
        's': somatic,
        if (material) 'm': 'a crystal prism',
      },
      'duration': [
        {
          'type': durationType == 'instantaneous' ? 'instant' : 'timed',
          if (concentration) 'concentration': true,
        }
      ],
      'entries': ['Community spell text $i.'],
    };
    if (clsShape != null) {
      commRaw['classes'] = clsShape;
    }
    communitySpells.add({
      'inputId': 'comm_spell_$i',
      'raw': commRaw,
    });

    final ingFields = <String, dynamic>{
      'name': _pickSpellName(rng, i, srdPool),
      'level': level,
      'school': school,
      'castingTime': '1 action',
      'range': '60 feet',
      'components': 'V, S',
      'duration': 'Instantaneous',
      'descriptionMarkdown': 'Ingested spell text $i.',
    };
    if (clsShape != null) {
      ingFields['classes'] = clsShape;
    }
    ingestionSpells.add({
      'inputId': 'ing_spell_$i',
      'rawSource': 'Ingested spell $i',
      'fields': ingFields,
    });

    final dtoName = _pickSpellName(rng, i, srdPool);
    dtoSpells.add({
      'inputId': 'dto_spell_$i',
      'raw': {
        'id': 'hb_dto_$i',
        'name': dtoName,
        'level': level,
        'school': school,
        'actionType': actionType,
        'range': '60 feet',
        'duration': 'Instantaneous',
        'description': 'DTO spell $i.',
        'classes': clsShape ?? <String>[],
      },
    });

    // Stored old-format homebrew spell records with SRD names and no class list
    final legacyName = srdPool.isNotEmpty
        ? (i < _kRequiredSrdSpells.length
            ? _kRequiredSrdSpells[i]
            : srdPool[(i * 11) % srdPool.length])
        : _kRequiredSrdSpells[i % _kRequiredSrdSpells.length];
    storedLegacySpells.add({
      'inputId': 'stored_legacy_spell_$i',
      'raw': {
        'id': 'hb_legacy_$i',
        'name': legacyName,
        'level': level,
        'school': school,
        'castingTime': '1 action',
        'range': '60 feet',
        'components': 'V, S',
        'duration': 'Instantaneous',
        'description': 'Stored legacy spell $i.',
        'classes': <String>[],
      },
    });
  }

  final formItems = <Map<String, dynamic>>[];
  final compendiumItems = <Map<String, dynamic>>[];
  final communityItems = <Map<String, dynamic>>[];
  final ingestionItems = <Map<String, dynamic>>[];

  for (var i = 0; i < itemsPerPath; i++) {
    final itemType = _kItemTypes[i % _kItemTypes.length];
    final rarity = _kFormRarities[i % _kFormRarities.length];
    final attuneBool = i % 2 == 1;
    final attuneText = switch (i % 5) {
      0 => false,
      1 => true,
      2 => 'requires attunement',
      3 => 'requires attunement by a spellcaster',
      _ => '',
    };
    final itemName = 'Generated ${_kInventedPrefixes[i % _kInventedPrefixes.length]} Relic $i';

    formItems.add({
      'inputId': 'form_item_$i',
      'name': itemName,
      'itemType': itemType,
      'rarity': rarity,
      'requiresAttunement': attuneBool,
      'description': 'Generated item description $i.',
    });

    compendiumItems.add({
      'inputId': 'comp_item_$i',
      'raw': {
        'name': 'Compendium $itemName',
        'type': itemType,
        'rarity': rarity.toLowerCase(),
        'reqAttune': attuneText,
        'entries': ['Compendium item text $i.'],
        'source': 'HB',
      },
    });

    communityItems.add({
      'inputId': 'comm_item_$i',
      'raw': {
        'name': 'Community $itemName',
        'type': itemType,
        'rarity': rarity,
        'requiresAttunement': attuneText,
        'description': 'Community item text $i.',
      },
    });

    ingestionItems.add({
      'inputId': 'ing_item_$i',
      'rawSource': 'Ingested item $i',
      'fields': {
        'name': 'Ingested $itemName',
        'itemType': itemType,
        'rarity': rarity,
        'requiresAttunement': attuneBool,
        'descriptionMarkdown': 'Ingested item text $i.',
      },
    });
  }

  return SeededSpellItemInputs(
    formSpells: formSpells,
    formItems: formItems,
    compendiumSpells: compendiumSpells,
    compendiumItems: compendiumItems,
    communitySpells: communitySpells,
    communityItems: communityItems,
    ingestionSpells: ingestionSpells,
    ingestionItems: ingestionItems,
    dtoSpells: dtoSpells,
    storedLegacySpells: storedLegacySpells,
  );
}
