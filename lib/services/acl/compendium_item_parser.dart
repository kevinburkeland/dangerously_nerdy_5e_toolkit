import '../../models/domain/core_types.dart';
import '../../models/domain/feature_grant.dart';
import '../../models/domain/spell_monster_equipment.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Equipment / Magic Items.
class CompendiumItemParser {
  final EntryTagTransformer transformer;

  CompendiumItemParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew item JSON map into a strongly-typed [EquipmentItem].
  EquipmentItem parseItem(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Item';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'DMG';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Item Type / Category
    final itemType = _parseItemType(raw);

    // Rarity
    final rarity = _parseRarity(raw['rarity']);

    // Attunement
    final reqAttune = _parseAttunement(raw['reqAttune'] ?? raw['attunement']);

    // Transform Markdown Entries (support entries, desc, description, text)
    final entriesData = raw['entries'] ?? raw['desc'] ?? raw['description'] ?? raw['text'];
    final parsed = transformer.transformEntries(entriesData, defaultRuleset: ruleset);

    // Auxiliary & Weapon/Armor Metrics (0% data loss)
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardItemKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    // Explicitly preserve mechanics
    if (raw.containsKey('weight')) customProperties['weight'] = raw['weight'];
    if (raw.containsKey('value')) customProperties['value'] = raw['value'];
    if (raw.containsKey('ac')) customProperties['ac'] = raw['ac'];
    if (raw.containsKey('armor')) customProperties['armor'] = raw['armor'];
    if (raw.containsKey('weaponCategory')) customProperties['weaponCategory'] = raw['weaponCategory'];
    if (raw.containsKey('property')) customProperties['property'] = raw['property'];
    if (raw.containsKey('dmg1')) customProperties['dmg1'] = raw['dmg1'];
    if (raw.containsKey('dmgType')) customProperties['dmgType'] = raw['dmgType'];
    if (raw.containsKey('dmg2')) customProperties['dmg2'] = raw['dmg2'];
    if (raw.containsKey('range')) customProperties['range'] = raw['range'];
    if (raw.containsKey('bonusWeapon')) customProperties['bonusWeapon'] = raw['bonusWeapon'];
    if (raw.containsKey('bonusAc')) customProperties['bonusAc'] = raw['bonusAc'];
    if (raw.containsKey('bonusSpellAttack')) customProperties['bonusSpellAttack'] = raw['bonusSpellAttack'];
    if (raw.containsKey('bonusSpellSaveDc')) customProperties['bonusSpellSaveDc'] = raw['bonusSpellSaveDc'];
    if (raw.containsKey('charges')) customProperties['charges'] = raw['charges'];
    if (raw.containsKey('recharge')) customProperties['recharge'] = raw['recharge'];
    if (raw.containsKey('rechargeAmount')) customProperties['rechargeAmount'] = raw['rechargeAmount'];

    // Fallback description markdown for mundane items or trade goods lacking entries
    var description = parsed.markdown;
    if (description.isEmpty) {
      final details = <String>[];
      details.add('**Type:** $itemType');
      if (rarity != 'None') details.add('**Rarity:** $rarity');
      if (reqAttune.requiresAttunement) {
        details.add('**Requires Attunement:** Yes${reqAttune.prerequisite != null ? " (${reqAttune.prerequisite})" : ""}');
      }
      if (customProperties['ac'] != null) details.add('**AC:** ${customProperties['ac']}');
      if (customProperties['bonusAc'] != null) details.add('**AC Bonus:** ${customProperties['bonusAc']}');
      if (customProperties['dmg1'] != null) {
        details.add('**Damage:** ${customProperties['dmg1']}${customProperties['dmgType'] != null ? " ${customProperties['dmgType']}" : ""}');
      }
      if (customProperties['dmg2'] != null) details.add('**Versatile Damage:** ${customProperties['dmg2']}');
      if (customProperties['value'] != null) {
        final val = customProperties['value'];
        if (val is num) {
          final gp = (val / 100).toStringAsFixed(val % 100 == 0 ? 0 : 2);
          details.add('**Value:** $gp gp');
        } else {
          details.add('**Value:** $val');
        }
      }
      if (customProperties['weight'] != null) details.add('**Weight:** ${customProperties['weight']} lb.');
      if (customProperties['vehHp'] != null) details.add('**Hull HP:** ${customProperties['vehHp']}');
      if (customProperties['vehAc'] != null) details.add('**Hull AC:** ${customProperties['vehAc']}');
      if (customProperties['vehSpeed'] != null) details.add('**Speed:** ${customProperties['vehSpeed']} mph');
      if (customProperties['crew'] != null) details.add('**Crew:** ${customProperties['crew']}');
      if (customProperties['capPassenger'] != null) details.add('**Passengers:** ${customProperties['capPassenger']}');
      if (customProperties['capCargo'] != null) details.add('**Cargo Capacity:** ${customProperties['capCargo']} tons');
      description = details.join('\n\n');
    }

    final grants = _extractGrants(slug, raw, customProperties);

    return EquipmentItem(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      itemType: itemType,
      rarity: rarity,
      requiresAttunement: reqAttune.requiresAttunement,
      descriptionMarkdown: description,
      grants: grants,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardItemKeys = {
    'name',
    'source',
    'type',
    'rarity',
    'reqAttune',
    'attunement',
    'entries',
    'desc',
    'description',
    'text',
  };

  String _parseItemType(Map<String, dynamic> raw) {
    if (raw['type'] != null) {
      final rawTypeStr = raw['type'].toString();
      // Handle compound types like 'RD|DMG', 'WD|DMG', 'RG|DMG', '$A|DMG'
      final t = rawTypeStr.split('|').first.toUpperCase().trim();
      switch (t) {
        case 'M':
        case 'MELEE':
          return 'Melee Weapon';
        case 'R':
        case 'RANGED':
          return 'Ranged Weapon';
        case 'LA':
          return 'Light Armor';
        case 'MA':
          return 'Medium Armor';
        case 'HA':
          return 'Heavy Armor';
        case 'S':
          return 'Shield';
        case 'W':
          return 'Wondrous Item';
        case 'P':
          return 'Potion';
        case 'SC':
          return 'Scroll';
        case 'WD':
          return 'Wand';
        case 'RD':
          return 'Rod';
        case 'RG':
          return 'Ring';
        case 'ST':
          return 'Staff';
        case 'G':
          return 'Adventuring Gear';
        case 'SCF':
          return 'Spellcasting Focus';
        case 'INS':
          return 'Instrument';
        case 'TG':
          return 'Trade Good';
        case 'OTH':
          return 'Other';
        case 'FD':
          return 'Food & Drink';
        case r'$A':
          return 'Art Object';
        case r'$C':
          return 'Coin / Currency';
        case r'$G':
          return 'Gemstone';
        case 'MNT':
          return 'Mount';
        case 'VEH':
          return 'Vehicle';
        case 'SHP':
          return 'Ship';
        case 'AIR':
          return 'Airship';
        case 'EXP':
          return 'Explosive';
        case 'SPC':
          return 'Spelljamming Ship';
        case 'GS':
          return 'Gaming Set';
        case 'A':
          return 'Ammunition';
        case 'TAH':
          return 'Tack and Harness';
        default:
          return rawTypeStr;
      }
    }
    if (raw['weaponCategory'] != null) return 'Weapon';
    if (raw['armor'] == true || raw['ac'] != null) return 'Armor';
    return 'Wondrous Item';
  }

  List<FeatureGrant> _extractGrants(String slug, Map<String, dynamic> raw, Map<String, dynamic> custom) {
    final grants = <FeatureGrant>[];

    // AC bonus (e.g. Ring of Protection +1, Shield +1)
    final rawBonusAc = raw['bonusAc'] ?? custom['bonusAc'];
    if (rawBonusAc != null) {
      final val = int.tryParse(rawBonusAc.toString().replaceAll('+', '').trim());
      if (val != null && val != 0) {
        grants.add(FeatureGrant.acBonus(
          grantId: 'item-$slug-ac-bonus',
          amount: val,
          label: '+${val > 0 ? "$val" : "$val"} AC',
        ));
      }
    }

    // Weapon bonus (attack & damage)
    final rawBonusWpn = raw['bonusWeapon'] ?? custom['bonusWeapon'] ?? raw['bonusWeaponAttack'] ?? custom['bonusWeaponAttack'];
    if (rawBonusWpn != null) {
      final val = int.tryParse(rawBonusWpn.toString().replaceAll('+', '').trim());
      if (val != null && val != 0) {
        grants.add(FeatureGrant.passiveBonus(
          grantId: 'item-$slug-weapon-bonus',
          stat: 'weapon_attack_damage',
          formula: 'flat_bonus',
          flat: val,
          label: '+${val > 0 ? "$val" : "$val"} Weapon Attack & Damage',
        ));
      }
    }

    // Saving throw bonus
    final rawSaveBonus = raw['bonusSavingThrow'] ?? custom['bonusSavingThrow'];
    if (rawSaveBonus != null) {
      final val = int.tryParse(rawSaveBonus.toString().replaceAll('+', '').trim());
      if (val != null && val != 0) {
        grants.add(FeatureGrant.passiveBonus(
          grantId: 'item-$slug-save-bonus',
          stat: 'saving_throw',
          formula: 'flat_bonus',
          flat: val,
          label: '+${val > 0 ? "$val" : "$val"} to Saving Throws',
        ));
      }
    }

    // Spell attack / DC bonus
    final rawSpellAtk = raw['bonusSpellAttack'] ?? custom['bonusSpellAttack'];
    if (rawSpellAtk != null) {
      final val = int.tryParse(rawSpellAtk.toString().replaceAll('+', '').trim());
      if (val != null && val != 0) {
        grants.add(FeatureGrant.passiveBonus(
          grantId: 'item-$slug-spell-attack',
          stat: 'spell_attack',
          formula: 'flat_bonus',
          flat: val,
          label: '+${val > 0 ? "$val" : "$val"} Spell Attack Rolls',
        ));
      }
    }

    final rawSpellDc = raw['bonusSpellSaveDc'] ?? custom['bonusSpellSaveDc'];
    if (rawSpellDc != null) {
      final val = int.tryParse(rawSpellDc.toString().replaceAll('+', '').trim());
      if (val != null && val != 0) {
        grants.add(FeatureGrant.passiveBonus(
          grantId: 'item-$slug-spell-dc',
          stat: 'spell_save_dc',
          formula: 'flat_bonus',
          flat: val,
          label: '+${val > 0 ? "$val" : "$val"} Spell Save DC',
        ));
      }
    }

    // Damage resistances
    final resist = raw['resist'] ?? custom['resist'];
    if (resist is List) {
      for (final r in resist) {
        final rStr = r.toString().toLowerCase().trim();
        if (rStr.isNotEmpty) {
          grants.add(FeatureGrant.resistance(
            rStr,
            grantId: 'item-$slug-resist-$rStr',
            label: 'Resistance to $rStr damage',
          ));
        }
      }
    } else if (resist is String && resist.isNotEmpty) {
      final rStr = resist.toLowerCase().trim();
      grants.add(FeatureGrant.resistance(
        rStr,
        grantId: 'item-$slug-resist-$rStr',
        label: 'Resistance to $resist damage',
      ));
    }

    // Speed bonus
    final modifySpeed = raw['modifySpeed'] ?? custom['modifySpeed'];
    if (modifySpeed is Map && modifySpeed['bonus'] != null) {
      final bonus = int.tryParse(modifySpeed['bonus'].toString().replaceAll('+', '').trim());
      if (bonus != null && bonus != 0) {
        grants.add(FeatureGrant.speedBonus(
          bonus,
          grantId: 'item-$slug-speed-bonus',
          label: '+${bonus > 0 ? "$bonus" : "$bonus"} ft. Speed',
        ));
      }
    }

    // Darkvision
    final darkvision = raw['darkvision'] ?? custom['darkvision'];
    if (darkvision is num && darkvision > 0) {
      grants.add(FeatureGrant.darkvisionRange(
        darkvision.toInt(),
        grantId: 'item-$slug-darkvision',
        label: 'Darkvision ${darkvision.toInt()} ft.',
      ));
    }

    return grants;
  }

  String _parseRarity(dynamic rarityData) {
    if (rarityData == null) return 'None';
    final r = rarityData.toString().toLowerCase().trim();
    switch (r) {
      case 'c':
      case 'common':
        return 'Common';
      case 'u':
      case 'uncommon':
        return 'Uncommon';
      case 'r':
      case 'rare':
        return 'Rare';
      case 'vr':
      case 'very rare':
      case 'veryrare':
        return 'Very Rare';
      case 'l':
      case 'legendary':
        return 'Legendary';
      case 'a':
      case 'artifact':
        return 'Artifact';
      case 'varies':
      case 'unknown':
        return 'Varies';
      default:
        if (r.isEmpty) return 'None';
        return r[0].toUpperCase() + r.substring(1);
    }
  }

  ({bool requiresAttunement, String? prerequisite}) _parseAttunement(dynamic attuneData) {
    if (attuneData == null || attuneData == false) {
      return (requiresAttunement: false, prerequisite: null);
    }
    if (attuneData == true) {
      return (requiresAttunement: true, prerequisite: null);
    }
    if (attuneData is String) {
      final clean = attuneData.trim();
      if (clean.toLowerCase() == 'false' || clean.isEmpty) {
        return (requiresAttunement: false, prerequisite: null);
      }
      final prereq = (clean.toLowerCase() == 'true' || clean.toLowerCase() == 'optional') ? null : clean;
      return (requiresAttunement: true, prerequisite: prereq);
    }
    if (attuneData is Map) {
      final tags = attuneData['tags'] as List?;
      String? prereq;
      if (tags != null && tags.isNotEmpty) {
        prereq = tags.join(', ');
      } else if (attuneData['prerequisite'] != null) {
        prereq = attuneData['prerequisite'].toString();
      } else if (attuneData['condition'] != null) {
        prereq = attuneData['condition'].toString();
      }
      return (requiresAttunement: true, prerequisite: prereq);
    }
    return (requiresAttunement: false, prerequisite: null);
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  RulesetVersion _mapSourceToRuleset(String? source) {
    if (source == null || source.isEmpty) return RulesetVersion.homebrew;
    final s = source.toUpperCase();
    if (s.contains('XDMG') || s.contains('SRD52') || s.contains('2024')) {
      return RulesetVersion.v2024;
    }
    if (s.contains('DMG') || s.contains('SRD') || s.contains('2014')) {
      return RulesetVersion.v2014;
    }
    return RulesetVersion.homebrew;
  }
}
