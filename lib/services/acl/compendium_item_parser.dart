import '../../models/domain/core_types.dart';
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

    return EquipmentItem(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      itemType: itemType,
      rarity: rarity,
      requiresAttunement: reqAttune.requiresAttunement,
      descriptionMarkdown: parsed.markdown,
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
      final t = raw['type'].toString().toUpperCase().trim();
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
        default:
          return raw['type'].toString();
      }
    }
    if (raw['weaponCategory'] != null) return 'Weapon';
    if (raw['armor'] == true || raw['ac'] != null) return 'Armor';
    return 'Wondrous Item';
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
      return (requiresAttunement: true, prerequisite: attuneData);
    }
    if (attuneData is Map) {
      final tags = attuneData['tags'] as List?;
      if (tags != null && tags.isNotEmpty) {
        return (requiresAttunement: true, prerequisite: tags.join(', '));
      }
      return (requiresAttunement: true, prerequisite: null);
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
