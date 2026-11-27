import 'package:dangerously_nerdy_5e_toolkit/models/arena/monster_combat_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';

dynamic _jsonSafe(dynamic v) {
  if (v is Enum) return v.name;
  if (v is Map) {
    final sortedKeys = v.keys.map((k) => k.toString()).toList()..sort();
    final byStr = {for (final e in v.entries) e.key.toString(): e.value};
    return {for (final k in sortedKeys) k: _jsonSafe(byStr[k])};
  }
  if (v is List) return v.map(_jsonSafe).toList();
  return v;
}

Map<String, dynamic> serializeCreatureTrait(CreatureTrait t) => {
      'name': t.name,
      'description': t.description,
    };

Map<String, dynamic> serializeCreatureAction(CreatureAction a) => {
      'name': a.name,
      'description': a.description,
      'attackType': a.attackType,
      'attackBonus': a.attackBonus,
      'reach': a.reach,
      'hitDamage': a.hitDamage,
    };

Map<String, dynamic> serializeStatBlockForGolden(MonsterStatBlock sb) {
  return {
    'id': sb.id,
    'name': sb.name,
    'sizeDisplay': sb.sizeDisplay,
    'crDisplay': sb.crDisplay,
    'typeDisplay': sb.typeDisplay,
    'alignment': sb.alignment,
    'ac': sb.ac,
    'armorType': sb.armorType,
    'maxHp': sb.maxHp,
    'hitDice': sb.hitDice,
    'speed': sb.speed,
    'strScore': sb.strScore,
    'dexScore': sb.dexScore,
    'conScore': sb.conScore,
    'intScore': sb.intScore,
    'wisScore': sb.wisScore,
    'chaScore': sb.chaScore,
    'savingThrows': sb.savingThrows,
    'skills': sb.skills,
    'damageVulnerabilities': sb.damageVulnerabilities,
    'damageResistances': sb.damageResistances,
    'damageImmunities': sb.damageImmunities,
    'conditionImmunities': sb.conditionImmunities,
    'senses': sb.senses,
    'languages': sb.languages,
    'xp': sb.xp,
    'traits': sb.traits.map(serializeCreatureTrait).toList(),
    'actions': sb.actions.map(serializeCreatureAction).toList(),
    'reactions': sb.reactions.map(serializeCreatureAction).toList(),
    'legendaryActions': sb.legendaryActions.map(serializeCreatureAction).toList(),
    'explicitSpellSlots': _jsonSafe(sb.explicitSpellSlots),
    'explicitMeleeReachFt': sb.explicitMeleeReachFt,
    'explicitSavingThrows': sb.explicitSavingThrows == null
        ? null
        : {
            for (final e in sb.explicitSavingThrows!.entries)
              e.key.name: e.value,
          },
    'canFly': sb.canFly,
    'hasHover': sb.hasHover,
    'spellSaveDc': sb.spellSaveDc,
    'spellAttackBonus': sb.spellAttackBonus,
    'attackBonus': sb.attackBonus,
    'damageDiceCount': sb.damageDiceCount,
    'damageDiceSides': sb.damageDiceSides,
    'damageBonus': sb.damageBonus,
    'damageType': sb.damageType,
    'secondaryDamageDiceCount': sb.secondaryDamageDiceCount,
    'secondaryDamageDiceSides': sb.secondaryDamageDiceSides,
    'secondaryDamageType': sb.secondaryDamageType,
    'hasPackTactics': sb.hasPackTactics,
    'specialTrait': sb.specialTrait,
    'presentation': {
      'accentArgb': sb.accentArgb.value,
      'glyphCreatureType': sb.glyphCreatureType.name,
      'glyphCrTier': sb.glyphCrTier,
      'glyphActionRings': sb.glyphActionRings.map((r) => r.toString()).toList(),
    },
    'derived': {
      'crValue': sb.crValue,
      'strMod': sb.strMod,
      'dexMod': sb.dexMod,
      'conMod': sb.conMod,
      'intMod': sb.intMod,
      'wisMod': sb.wisMod,
      'chaMod': sb.chaMod,
      'hasLegendary': sb.hasLegendary,
      'hasLegendaryResistance': sb.hasLegendaryResistance,
      'hasLegendaryActions': sb.hasLegendaryActions,
    },
    'displayText': {
      'subtitleText':
          '${sb.sizeDisplay} ${sb.typeDisplay.toLowerCase()}, ${sb.alignment}',
      'acLine':
          '${sb.ac}${sb.armorType != null ? " (${sb.armorType})" : ""}',
      'hpLine':
          '${sb.maxHp}${sb.hitDice != null ? " (${sb.hitDice})" : ""}',
      'challengeLine':
          '${sb.crDisplay.replaceAll("CR ", "")}${sb.xp != null ? " (${sb.xp} XP)" : ""}',
      'primaryDamageFormula': sb.primaryDamageFormula,
      'fullDamageFormula': sb.fullDamageFormula,
    },
  };
}

Map<String, dynamic> _serializeCombatProfile(MonsterCombatProfile p) {
  final attackKeys = p.attacks.keys.toList()..sort();
  final saveKeys = p.savingThrowBonuses.keys.toList()..sort();
  final slotKeys = p.maxSpellSlots.keys.toList()..sort();
  return {
    'attackNames': attackKeys,
    'maxSpellSlots': {for (final k in slotKeys) '$k': p.maxSpellSlots[k]},
    'knownSpellIds': p.knownSpellIds,
    'spellSaveDc': p.spellSaveDc,
    'spellAttackBonus': p.spellAttackBonus,
    'meleeReachInFeet': p.meleeReachInFeet,
    'canFly': p.canFly,
    'hasHover': p.hasHover,
    'defaultAltitudeInFeet': p.defaultAltitudeInFeet,
    'savingThrowBonuses': {for (final k in saveKeys) k: p.savingThrowBonuses[k]},
    'maxLegendaryActions': p.maxLegendaryActions,
    'maxLegendaryResistances': p.maxLegendaryResistances,
    'canSwim': p.canSwim,
    'canBurrow': p.canBurrow,
    'canClimb': p.canClimb,
    'hasEvasion': p.hasEvasion,
    'hasFlyby': p.hasFlyby,
    'hasNimbleEscape': p.hasNimbleEscape,
  };
}

Map<String, dynamic> _serializeDprProfile(DprCombatantProfile p) {
  return {
    'id': p.id,
    'name': p.name,
    'description': p.description,
    'level': p.level,
    'abilityScore': p.abilityScore,
    'proficiencyBonus': p.proficiencyBonus,
    'defaultAdvantage': p.defaultAdvantage.name,
    'attackCount': p.attacks.length,
    'attackNames': p.attacks.map((a) => a.name).toList(),
  };
}

Map<String, dynamic> serializeMonsterForGolden(Monster m) {
  final nameQ = m.name.split(' ').first;
  return {
    'id': m.id.slug,
    'name': m.name,
    'name2014': m.name2014,
    'name2024': m.name2024,
    'isChangedIn2024': m.isChangedIn2024,
    'diffSummary': m.diffSummary,
    'diffHighlights': m.diffHighlights,
    'sourcePresetId': m.sourcePresetId,
    'sourcePresetName': m.sourcePresetName,
    'sourceSpellId': m.sourceSpellId,
    'sourceCategory': m.sourceCategory.name,
    'isHomebrew': m.isHomebrew,
    'challengeRating': m.challengeRatingValue,
    'xp': m.xp,
    'size': m.size,
    'type': m.type,
    'alignment': m.alignment,
    'crDisplay': m.crDisplay,
    'ac': m.ac,
    'hp': m.hp,
    'speed': m.speed,
    'v2014': {
      'editionName': m.getName(DmRulesEdition.v2014),
      'baselineDpr': double.parse(
        m.calculateBaselineDpr(DmRulesEdition.v2014).toStringAsFixed(4),
      ),
      'matchesName': m.matches(nameQ, edition: DmRulesEdition.v2014),
      'combatProfile':
          _serializeCombatProfile(m.getCombatProfile(DmRulesEdition.v2014)),
      'dprProfile': _serializeDprProfile(
        DprCombatantProfile.fromMonsterItem(m, edition: DmRulesEdition.v2014),
      ),
      'statBlock': serializeStatBlockForGolden(
        m.getStatBlock(DmRulesEdition.v2014),
      ),
    },
    'v2024': {
      'editionName': m.getName(DmRulesEdition.v2024),
      'baselineDpr': double.parse(
        m.calculateBaselineDpr(DmRulesEdition.v2024).toStringAsFixed(4),
      ),
      'matchesName': m.matches(nameQ, edition: DmRulesEdition.v2024),
      'combatProfile':
          _serializeCombatProfile(m.getCombatProfile(DmRulesEdition.v2024)),
      'dprProfile': _serializeDprProfile(
        DprCombatantProfile.fromMonsterItem(m, edition: DmRulesEdition.v2024),
      ),
      'statBlock': serializeStatBlockForGolden(
        m.getStatBlock(DmRulesEdition.v2024),
      ),
    },
  };
}

Map<String, dynamic> serializeDomainMonster(Monster m) {
  final full = m.toMap();
  return _jsonSafe({
    'id': full['id'],
    'name': full['name'],
    'size': full['size'],
    'monsterType': full['monsterType'],
    'alignment': full['alignment'],
    'armorClass': full['armorClass'],
    'hitPoints': full['hitPoints'],
    'hitDieFormula': full['hitDieFormula'],
    'challengeRating': full['challengeRating'],
    'actionsMarkdown': full['actionsMarkdown'],
    'innateSpells': full['innateSpells'],
    'attackMath': full['attackMath'],
    'customProperties': full['customProperties'],
  }) as Map<String, dynamic>;
}

/// Orders monsters exactly as [MonsterCodexScreen] sorts them for each
/// [MonsterSortMode].
List<String> sortMonsterIdsByMode(
  List<Monster> monsters,
  MonsterSortMode mode,
  DmRulesEdition edition,
) {
  switch (mode) {
    case MonsterSortMode.crAscending:
      final groups = <double, List<Monster>>{};
      for (final m in monsters) {
        groups.putIfAbsent(m.challengeRatingValue, () => []).add(m);
      }
      final crs = groups.keys.toList()..sort();
      return [
        for (final cr in crs) ...groups[cr]!.map((m) => m.id.slug),
      ];
    case MonsterSortMode.crDescending:
      final groups = <double, List<Monster>>{};
      for (final m in monsters) {
        groups.putIfAbsent(m.challengeRatingValue, () => []).add(m);
      }
      final crs = groups.keys.toList()..sort((a, b) => b.compareTo(a));
      return [
        for (final cr in crs) ...groups[cr]!.map((m) => m.id.slug),
      ];
    case MonsterSortMode.dprDescending:
      final sorted = List<Monster>.from(monsters)
        ..sort((a, b) {
          final dprA = a.calculateBaselineDpr(edition);
          final dprB = b.calculateBaselineDpr(edition);
          final cmp = dprB.compareTo(dprA);
          if (cmp != 0) return cmp;
          return a.getName(edition).compareTo(b.getName(edition));
        });
      return sorted.map((m) => m.id.slug).toList();
    case MonsterSortMode.nameAscending:
      final sorted = List<Monster>.from(monsters)
        ..sort((a, b) => a.getName(edition).compareTo(b.getName(edition)));
      return sorted.map((m) => m.id.slug).toList();
  }
}

Map<String, dynamic> buildMonsterCatalogGoldenMap() {
  MonsterCodexLibrary.clearHomebrewMonsters();
  MonsterCodexLibrary.clearCaches();

  final monsters = <String, dynamic>{};
  for (final m in MonsterCodexLibrary.allMonsters) {
    monsters[m.id.slug] = serializeMonsterForGolden(m);
  }

  final presets = <String, dynamic>{};
  var summonStatBlockCount = 0;
  for (final preset in SrdSummonsLibrary.allPresets) {
    final blocks = <String, dynamic>{};
    for (final sb in preset.statBlocks) {
      summonStatBlockCount++;
      final instance = sb.toInstance(id: 'inst_${sb.id}');
      blocks[sb.id] = {
        'statBlock': serializeStatBlockForGolden(sb),
        'dprProfile': _serializeDprProfile(
          DprCombatantProfile.fromMinionStatBlock(sb),
        ),
        'toInstanceSummary': {
          'name': instance.name,
          'size': instance.size.name,
          'maxHp': instance.maxHp,
          'damageType': instance.damageType,
          'statBlockId': instance.statBlockId,
          'customAc': instance.customAc,
          'customAttackBonus': instance.customAttackBonus,
          'customDamageDiceCount': instance.customDamageDiceCount,
          'customDamageDiceSides': instance.customDamageDiceSides,
          'customDamageBonus': instance.customDamageBonus,
          'secondaryDamageDiceCount': instance.secondaryDamageDiceCount,
          'secondaryDamageDiceSides': instance.secondaryDamageDiceSides,
          'secondaryDamageType': instance.secondaryDamageType,
          'specialTrait': instance.specialTrait,
        },
      };
    }
    presets[preset.id] = {
      'id': preset.id,
      'name': preset.name,
      'category': preset.category.name,
      'spellId': preset.spellId,
      'statBlockCount': blocks.length,
      'statBlocks': blocks,
    };
  }

  return {
    'monsterCount': monsters.length,
    'summonPresetCount': presets.length,
    'summonStatBlockCount': summonStatBlockCount,
    'monsters': monsters,
    'summonPresets': presets,
  };
}

List<Monster> buildCatalogLookupSampleHomebrewMonsters() {
  return [
    Monster.singleEdition(
      id: const EntityId(slug: 'hb-lookup-mire-hound', ruleset: RulesetVersion.homebrew),
      name: 'Mire Hound',
      size: 'Medium',
      monsterType: 'Beast',
      alignment: 'unaligned',
      armorClass: 13,
      hitPoints: 26,
      hitDieFormula: '4d8 + 8',
      challengeRating: '1',
      actionsMarkdown:
          '**Pack Tactics.** Advantage on attack rolls when an ally is adjacent.\n\n**Bite.** Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 9 (2d6 + 2) piercing damage.',
      customProperties: const {
        'speed': '40 ft., swim 20 ft.',
        'str': 14,
        'dex': 14,
        'con': 14,
        'int': 3,
        'wis': 12,
        'cha': 6,
      },
    ),
    Monster.singleEdition(
      id: const EntityId(slug: 'hb-lookup-ash-drake', ruleset: RulesetVersion.homebrew),
      name: 'Ash Drake',
      size: 'Large',
      monsterType: 'Dragon',
      alignment: 'neutral evil',
      armorClass: 17,
      hitPoints: 112,
      hitDieFormula: '15d10 + 30',
      challengeRating: '6',
      actionsMarkdown:
          '**Bite.** Melee Weapon Attack: +8 to hit, reach 10 ft., one target. Hit: 16 (2d10 + 5) piercing damage.',
      customProperties: const {
        'speed': '30 ft., fly 60 ft.',
        'damageImmunities': 'fire',
      },
    ),
    Monster.singleEdition(
      id: const EntityId(slug: 'hb-lookup-void-titan', ruleset: RulesetVersion.homebrew),
      name: 'Void Titan',
      size: 'Huge',
      monsterType: 'Fiend',
      alignment: 'chaotic evil',
      armorClass: 19,
      hitPoints: 210,
      hitDieFormula: '20d12 + 80',
      challengeRating: '12',
      actionsMarkdown:
          '**Slam.** Melee Weapon Attack: +11 to hit, reach 10 ft., one target. Hit: 24 (3d10 + 7) bludgeoning damage.',
      customProperties: const {
        'speed': '40 ft.',
      },
    ),
  ];
}

Map<String, dynamic> buildMonsterLookupsGoldenMap() {
  MonsterCodexLibrary.clearHomebrewMonsters();
  MonsterCodexLibrary.clearCaches();

  final allBundled = MonsterCodexLibrary.allMonsters;
  final byIdMismatches = <String>[];
  final byName = <String, String?>{};
  for (final m in allBundled) {
    final resolved = MonsterCodexLibrary.getMonsterById(m.id.slug)?.id.slug;
    if (resolved != m.id.slug) {
      byIdMismatches.add('${m.id.slug}->$resolved');
    }
    byName[m.name] = MonsterCodexLibrary.getMonsterByName(m.name)?.id.slug;
  }

  final nameSpotChecks = <String, String?>{
    'Dragon': MonsterCodexLibrary.getMonsterByName('Dragon')?.id.slug,
    'Dragon Turtle': MonsterCodexLibrary.getMonsterByName('Dragon Turtle')?.id.slug,
    'Wolf': MonsterCodexLibrary.getMonsterByName('Wolf')?.id.slug,
    'nonexistent_monster_xyz':
        MonsterCodexLibrary.getMonsterByName('nonexistent_monster_xyz')?.id.slug,
  };

  final crBandsBundled = <String, List<String>>{
    'all': allBundled.map((m) => m.id.slug).toList(),
    'cr0ToQuarter':
        MonsterCodexLibrary.getCr0ToQuarterMonsters().map((m) => m.id.slug).toList(),
    'crHalfToOne':
        MonsterCodexLibrary.getCrHalfToOneMonsters().map((m) => m.id.slug).toList(),
    'crTwoToFour':
        MonsterCodexLibrary.getCrTwoToFourMonsters().map((m) => m.id.slug).toList(),
    'crFiveToEight':
        MonsterCodexLibrary.getCrFiveToEightMonsters().map((m) => m.id.slug).toList(),
    'crNinePlus':
        MonsterCodexLibrary.getCrNinePlusMonsters().map((m) => m.id.slug).toList(),
  };

  final sortModes2014 = <String, List<String>>{};
  final sortModes2024 = <String, List<String>>{};
  for (final mode in MonsterSortMode.values) {
    sortModes2014[mode.name] =
        sortMonsterIdsByMode(allBundled, mode, DmRulesEdition.v2014);
    sortModes2024[mode.name] =
        sortMonsterIdsByMode(allBundled, mode, DmRulesEdition.v2024);
  }

  final searches = <String, List<String>>{
    'query_wolf': MonsterCodexLibrary.search('wolf').map((m) => m.id.slug).toList(),
    'query_pack_tactics':
        MonsterCodexLibrary.search('pack tactics').map((m) => m.id.slug).toList(),
    'query_fire': MonsterCodexLibrary.search('fire').map((m) => m.id.slug).toList(),
    'type_dragon': MonsterCodexLibrary.search('', typeFilter: 'Dragon')
        .map((m) => m.id.slug)
        .toList(),
    'size_medium': MonsterCodexLibrary.search('', sizeFilter: 'Medium')
        .map((m) => m.id.slug)
        .toList(),
    'minCr_5':
        MonsterCodexLibrary.search('', minCr: 5).map((m) => m.id.slug).toList(),
    'maxCr_quarter':
        MonsterCodexLibrary.search('', maxCr: 0.25).map((m) => m.id.slug).toList(),
  };

  final byType = <String, List<String>>{
    for (final t in ['Beast', 'Undead', 'Dragon', 'Fiend', 'Elemental'])
      t: MonsterCodexLibrary.getMonstersByType(t).map((m) => m.id.slug).toList(),
  };

  final bySize = <String, List<String>>{
    for (final s in ['Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Gargantuan'])
      s: MonsterCodexLibrary.getMonstersBySize(s).map((m) => m.id.slug).toList(),
  };

  final summonsById = <String, String?>{};
  final summonsByName = <String, String?>{};
  for (final preset in SrdSummonsLibrary.allPresets) {
    for (final sb in preset.statBlocks) {
      summonsById[sb.id] = SrdSummonsLibrary.findStatBlockById(sb.id)?.id;
      summonsByName[sb.name] =
          SrdSummonsLibrary.findStatBlockByName(sb.name)?.id;
    }
  }

  // With representative homebrew loaded
  MonsterCodexLibrary.setHomebrewMonsters(
    buildCatalogLookupSampleHomebrewMonsters(),
  );
  final allWithHb = MonsterCodexLibrary.allMonsters;
  final withHomebrew = {
    'homebrewIds':
        MonsterCodexLibrary.homebrewMonsters.map((m) => m.id.slug).toList(),
    'crBands': {
      'all': allWithHb.map((m) => m.id.slug).toList(),
      'cr0ToQuarter': MonsterCodexLibrary.getCr0ToQuarterMonsters()
          .map((m) => m.id.slug)
          .toList(),
      'crHalfToOne': MonsterCodexLibrary.getCrHalfToOneMonsters()
          .map((m) => m.id.slug)
          .toList(),
      'crTwoToFour': MonsterCodexLibrary.getCrTwoToFourMonsters()
          .map((m) => m.id.slug)
          .toList(),
      'crFiveToEight': MonsterCodexLibrary.getCrFiveToEightMonsters()
          .map((m) => m.id.slug)
          .toList(),
      'crNinePlus': MonsterCodexLibrary.getCrNinePlusMonsters()
          .map((m) => m.id.slug)
          .toList(),
    },
    'sortModes2024': {
      for (final mode in MonsterSortMode.values)
        mode.name: sortMonsterIdsByMode(allWithHb, mode, DmRulesEdition.v2024),
    },
    'conjureAnimalsEffectiveIds': BeastSummons
        .conjureAnimalsPreset.effectiveStatBlocks
        .map((s) => s.id)
        .toList(),
    'homebrewPresetIds': SrdSummonsLibrary.homebrewPreset.statBlocks
        .map((s) => s.id)
        .toList(),
  };

  MonsterCodexLibrary.clearHomebrewMonsters();

  return {
    'byIdCount': allBundled.length,
    'byIdMismatches': byIdMismatches,
    'byName': byName,
    'nameSpotChecks': nameSpotChecks,
    'crBands': crBandsBundled,
    'sortModes2014': sortModes2014,
    'sortModes2024': sortModes2024,
    'searches': searches,
    'byType': byType,
    'bySize': bySize,
    'spellSummoned': MonsterCodexLibrary.getSpellSummonedMonsters()
        .map((m) => m.id.slug)
        .toList(),
    'magicItemSummoned': MonsterCodexLibrary.getMagicItemMonsters()
        .map((m) => m.id.slug)
        .toList(),
    'bySourcePreset': {
      'animate_dead': MonsterCodexLibrary.getMonstersBySourcePreset('animate_dead')
          .map((m) => m.id.slug)
          .toList(),
      'conjure_animals':
          MonsterCodexLibrary.getMonstersBySourcePreset('conjure_animals')
              .map((m) => m.id.slug)
              .toList(),
    },
    'summonsById': summonsById,
    'summonsByName': summonsByName,
    'withHomebrew': withHomebrew,
  };
}
