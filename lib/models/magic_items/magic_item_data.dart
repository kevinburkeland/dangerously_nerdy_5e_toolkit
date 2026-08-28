import 'package:flutter/material.dart';
import '../dm_screen_data.dart';
import '../../widgets/glyphs/glyph_tokens.dart';

export 'package:flutter/material.dart' show Color;
export '../dm_screen_data.dart' show DmRulesEdition;
export '../../widgets/glyphs/glyph_tokens.dart';

/// Detailed rules information for a specific rules edition of a magic item.
class ItemEditionDetails {
  final String summary;
  final String description;
  final String? activation; // e.g. "1 Action", "1 Bonus Action", "Passive", "Special"
  final String? charges; // e.g. "7 charges (recharges 1d6 + 1 daily at dawn)"
  final String? masteryProperties; // e.g. "Vex", "Topple" (2024 Weapon Mastery)
  final String? savingThrowDc; // e.g. "DC 15 or your Spell Save DC"
  final List<String> properties; // bullet points of mechanics

  const ItemEditionDetails({
    required this.summary,
    required this.description,
    this.activation,
    this.charges,
    this.masteryProperties,
    this.savingThrowDc,
    this.properties = const [],
  });
}

/// Represents an SRD Magic Item with 2014 & 2024 comparison metadata and rules definitions.
class MagicItem {
  final String id;
  final String name;
  final String? name2014;
  final String? name2024;
  final ItemCategory category;
  final ItemRarity rarity;
  final String? cost;
  final String? cost2014;
  final String? cost2024;
  final bool requiresAttunement;
  final String? attunementRequirement;
  final DamageAccent? damageAccent;
  final List<ActionTraitRing> actionRings;
  final ItemEditionDetails rules2014;
  final ItemEditionDetails rules2024;
  final bool isChangedIn2024;
  final String? diffSummary;
  final List<String> diffHighlights;
  final Color? glyphColor;
  final List<String> tags;

  const MagicItem({
    required this.id,
    required this.name,
    this.name2014,
    this.name2024,
    required this.category,
    required this.rarity,
    this.cost,
    this.cost2014,
    this.cost2024,
    this.requiresAttunement = false,
    this.attunementRequirement,
    this.damageAccent,
    this.actionRings = const [],
    required this.rules2014,
    required this.rules2024,
    this.isChangedIn2024 = false,
    this.diffSummary,
    this.diffHighlights = const [],
    this.glyphColor,
    this.tags = const [],
  });

  /// True if this item is a consumable (potion, scroll, oil, ammunition, single-use token).
  bool get isConsumable {
    if (category == ItemCategory.potion || category == ItemCategory.scroll) {
      return true;
    }
    final lowerName = name.toLowerCase();
    final lowerTags = tags.map((t) => t.toLowerCase()).toSet();
    return lowerTags.contains('consumable') ||
        lowerTags.contains('potion') ||
        lowerTags.contains('scroll') ||
        lowerTags.contains('oil') ||
        lowerTags.contains('ammunition') ||
        lowerName.contains('potion of') ||
        lowerName.contains('scroll of') ||
        lowerName.contains('oil of') ||
        lowerName.contains('elixir') ||
        lowerName.contains('dust of') ||
        lowerName.contains('feather token') ||
        lowerName.contains('elemental gem') ||
        lowerName.contains('bead of') ||
        lowerName.contains('manual of') ||
        lowerName.contains('tome of') ||
        lowerName.contains('sovereign glue') ||
        lowerName.contains('universal solvent') ||
        lowerName.contains('restorative ointment') ||
        lowerName.contains('incense of') ||
        lowerName.contains('spell scroll');
  }

  /// Automatically resolves an item's glyph color, prioritizing an explicit [glyphColor]
  /// override, and falling back to keyword color detection in the item's name or tags.
  Color? get effectiveGlyphColor {
    if (glyphColor != null) {
      return glyphColor;
    }
    final lowerName = name.toLowerCase();
    final lowerTags = tags.map((t) => t.toLowerCase()).toSet();

    // Gray / Grey (e.g. Gray Bag of Tricks, Gray Robe)
    if (lowerName.contains('(gray)') || lowerName.contains('(grey)') || lowerName.contains('gray') || lowerName.contains('grey') || lowerTags.contains('gray') || lowerTags.contains('grey')) {
      return const Color(0xFF94A3B8); // Slate Ash Gray
    }
    // Rust (e.g. Rust Bag of Tricks)
    if (lowerName.contains('(rust)') || lowerName.contains('rust') || lowerTags.contains('rust')) {
      return const Color(0xFFC2410C); // Terracotta Burnt Orange Rust
    }
    // Tan (e.g. Tan Bag of Tricks)
    if (lowerName.contains('(tan)') || lowerName.contains('tan') || lowerTags.contains('tan')) {
      return const Color(0xFFD4A373); // Warm Sandstone Amber Tan
    }
    // Deep Red / Ruby / Crimson / Flame / Fire
    if (lowerName.contains('deep red') || lowerName.contains('ruby') || lowerName.contains('crimson') || lowerName.contains('red dragon') || lowerName.contains('flame tongue') || lowerTags.contains('ruby')) {
      return const Color(0xFFEF4444); // Crimson Red
    }
    // Incandescent Blue / Sapphire / Azure / Frost
    if (lowerName.contains('incandescent blue') || lowerName.contains('sapphire') || lowerName.contains('blue dragon') || lowerName.contains('frost brand') || lowerName.contains('azure') || lowerTags.contains('sapphire')) {
      return const Color(0xFF38BDF8); // Electric Sky Azure
    }
    // Pale Green / Emerald / Jade / Poison
    if (lowerName.contains('pale green') || lowerName.contains('emerald') || lowerName.contains('green dragon') || lowerName.contains('jade') || lowerTags.contains('emerald')) {
      return const Color(0xFF10B981); // Radiant Emerald Green
    }
    // Dusty Rose / Pink
    if (lowerName.contains('dusty rose') || lowerName.contains('pink') || lowerName.contains('rose')) {
      return const Color(0xFFFB7185); // Dusty Rose Coral
    }
    // Clear Spindle / Pearl / White / Ivory / Diamond
    if (lowerName.contains('clear spindle') || lowerName.contains('pearl') || lowerName.contains('white dragon') || lowerName.contains('(white)') || lowerName.contains('ivory') || lowerName.contains('diamond') || lowerTags.contains('pearl')) {
      return const Color(0xFFF1F5F9); // Luminous Pearl White
    }
    // Black / Obsidian / Ebony
    if (lowerName.contains('black dragon') || lowerName.contains('(black)') || lowerName.contains('obsidian') || lowerName.contains('ebony')) {
      return const Color(0xFF475569); // Dark Obsidian Slate
    }
    // Gold / Solar / Radiant / Sun
    if (lowerName.contains('gold dragon') || lowerName.contains('golden') || lowerName.contains('sun blade') || lowerName.contains('radiant')) {
      return const Color(0xFFF59E0B); // Solar Radiant Gold
    }
    // Silver / Lunar / Moon
    if (lowerName.contains('silver dragon') || lowerName.contains('silver') || lowerName.contains('moon sickle') || lowerName.contains('mithral')) {
      return const Color(0xFFCBD5E1); // Polished Silver
    }
    // Bronze
    if (lowerName.contains('bronze dragon') || lowerName.contains('bronze')) {
      return const Color(0xFFCD7F32); // Patina Bronze
    }
    // Brass
    if (lowerName.contains('brass dragon') || lowerName.contains('brass')) {
      return const Color(0xFFD97706); // Polished Brass
    }
    // Copper
    if (lowerName.contains('copper dragon') || lowerName.contains('copper')) {
      return const Color(0xFFB87333); // Burnished Copper
    }
    // Purple / Violet / Amethyst
    if (lowerName.contains('purple') || lowerName.contains('violet') || lowerName.contains('amethyst')) {
      return const Color(0xFFA855F7); // Mystic Amethyst Violet
    }

    return null;
  }

  /// Dynamic action rings for DndGlyph HUD rendering derived from tags, mechanics, and explicit rings.
  List<ActionTraitRing> getGlyphActionRings([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final rings = <ActionTraitRing>[];
    final rules = getRules(edition);
    final text = [
      name,
      category.displayName,
      rarity.displayName,
      ...tags,
      rules.summary,
      rules.description,
      rules.activation ?? '',
      rules.charges ?? '',
      rules.masteryProperties ?? '',
      rules.savingThrowDc ?? '',
      ...rules.properties,
      if (diffSummary != null) diffSummary!,
      ...diffHighlights,
    ].map((value) => value.toLowerCase()).join(' ');

    bool hasControlSemantics() {
      const controlTerms = [
        'restrain',
        'restrained',
        'paralyze',
        'paralyzed',
        'charm',
        'charmed',
        'frighten',
        'frightened',
        'incapacitated',
        'stun',
        'stunned',
        'banish',
        'banished',
        'grapple',
        'grappled',
        'prone',
        'sleep',
        'confusion',
        'petrif',
        'blind',
        'blinded',
      ];
      return controlTerms.any(text.contains);
    }

    bool hasSustainSemantics() {
      const sustainTerms = [
        'healing',
        'heal',
        'regain hit points',
        'regains hit points',
        'regain hp',
        'regains hp',
        'temporary hit points',
        'temp hp',
        'regeneration',
        'regenerate',
        'restore',
        'cures',
        'curing',
        'neutralize poison',
        'remove curse',
      ];
      return sustainTerms.any(text.contains);
    }

    bool hasRechargeOrCharges() {
      const rechargeTerms = [
        'charge',
        'charges',
        'recharge',
        'recharges',
        'daily at dawn',
        'daily at dusk',
        'per day',
        'cone',
        'sphere',
        'cylinder',
        'emanation',
        'radius',
        'line of effect',
        'area of effect',
      ];
      return rechargeTerms.any(text.contains);
    }

    bool sameDamageTypes(List<DamageAccent> a, List<DamageAccent> b) {
      if (identical(a, b)) return true;
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    void addRing(ActionRingType type,
        {DamageAccent? damageType, List<DamageAccent> damageTypes = const [], String? label}) {
      final exists = rings.any((r) =>
          r.ringType == type &&
          r.damageType == damageType &&
          sameDamageTypes(r.damageTypes, damageTypes));
      if (exists) return;
      rings.add(ActionTraitRing(
        ringType: type,
        damageType: damageType,
        damageTypes: damageTypes,
        label: label,
      ));
    }

    // 1. First add any explicitly configured actionRings
    for (final ring in actionRings) {
      addRing(
        ring.ringType,
        damageType: ring.damageType,
        damageTypes: ring.damageTypes,
        label: ring.label,
      );
    }

    // 2. Attunement ring if required
    if (requiresAttunement || tags.contains('attunement')) {
      addRing(ActionRingType.attunement, label: getAttunementLabel());
    }

    final primaryDamage = getGlyphPrimaryDamageAccent(edition);
    final allDamageAccents = getGlyphDamageAccents(edition);
    final extraAccents = allDamageAccents.length > 1
        ? allDamageAccents.sublist(1)
        : const <DamageAccent>[];

    // 3. Category & Tag based combat dynamics
    final lowerTags = tags.map((t) => t.toLowerCase()).toSet();

    // Melee weapons
    if (category == ItemCategory.weapon &&
        !lowerTags.contains('ranged') &&
        !lowerTags.contains('ammunition') &&
        !lowerTags.contains('bow') &&
        !lowerTags.contains('crossbow')) {
      addRing(
        ActionRingType.melee,
        damageType: primaryDamage,
        damageTypes: extraAccents,
      );
    } else if (lowerTags.contains('melee')) {
      addRing(
        ActionRingType.melee,
        damageType: primaryDamage,
        damageTypes: extraAccents,
      );
    }

    // Ranged weapons / items
    if (lowerTags.contains('ranged') ||
        lowerTags.contains('bow') ||
        lowerTags.contains('crossbow') ||
        lowerTags.contains('ammunition') ||
        lowerTags.contains('dart') ||
        lowerTags.contains('sling') ||
        lowerTags.contains('blowgun') ||
        lowerTags.contains('firearm')) {
      addRing(
        ActionRingType.ranged,
        damageType: primaryDamage,
        damageTypes: extraAccents,
      );
    }

    // Reaction items (shields, parry, deflection, reaction activation)
    final activation = (rules.activation ?? '').toLowerCase();
    if (lowerTags.contains('reaction') ||
        lowerTags.contains('shield') ||
        lowerTags.contains('deflect') ||
        activation.contains('reaction')) {
      addRing(ActionRingType.reaction);
    }

    // Control mechanics
    if (hasControlSemantics()) {
      addRing(ActionRingType.control);
    }

    // Sustain / Healing
    if (hasSustainSemantics()) {
      addRing(ActionRingType.sustain);
    }

    // Recharge / Charges / AoE / Spells in items
    if (hasRechargeOrCharges() ||
        category == ItemCategory.wand ||
        category == ItemCategory.staff ||
        category == ItemCategory.rod ||
        category == ItemCategory.scroll ||
        category == ItemCategory.potion) {
      addRing(
        ActionRingType.recharge,
        damageType: primaryDamage,
        damageTypes: extraAccents,
      );
    }

    // Concentration
    if (lowerTags.contains('concentration') || text.contains('concentration')) {
      addRing(ActionRingType.concentration);
    }

    // Legendary / Artifact
    if (rarity == ItemRarity.legendary ||
        rarity == ItemRarity.artifact ||
        lowerTags.contains('legendary') ||
        lowerTags.contains('artifact')) {
      addRing(ActionRingType.legendary);
    }

    return rings.take(3).toList(growable: false);
  }

  /// Primary damage accent used by glyphs for this magic item.
  DamageAccent? getGlyphPrimaryDamageAccent([DmRulesEdition edition = DmRulesEdition.v2024]) {
    if (damageAccent != null) return damageAccent;
    final accents = getGlyphDamageAccents(edition);
    return accents.isNotEmpty ? accents.first : null;
  }

  /// Ordered damage accents used by glyphs for this magic item.
  List<DamageAccent> getGlyphDamageAccents([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final accents = <DamageAccent>[];
    if (damageAccent != null) {
      accents.add(damageAccent!);
    }

    final rules = getRules(edition);
    final text = [
      name,
      ...tags,
      rules.summary,
      rules.description,
      rules.masteryProperties ?? '',
      ...rules.properties,
      if (diffSummary != null) diffSummary!,
      ...diffHighlights,
    ].map((value) => value.toLowerCase()).join(' ');

    void addIfMatch(String keyword, DamageAccent accent) {
      if (!accents.contains(accent) && text.contains(keyword)) {
        accents.add(accent);
      }
    }

    addIfMatch('fire', DamageAccent.fire);
    addIfMatch('flame', DamageAccent.fire);
    addIfMatch('cold', DamageAccent.cold);
    addIfMatch('frost', DamageAccent.cold);
    addIfMatch('ice', DamageAccent.cold);
    addIfMatch('lightning', DamageAccent.lightning);
    addIfMatch('shock', DamageAccent.lightning);
    addIfMatch('thunder', DamageAccent.thunder);
    addIfMatch('acid', DamageAccent.acid);
    addIfMatch('poison', DamageAccent.poison);
    addIfMatch('necrotic', DamageAccent.necrotic);
    addIfMatch('radiant', DamageAccent.radiant);
    addIfMatch('holy', DamageAccent.radiant);
    addIfMatch('sun', DamageAccent.radiant);
    addIfMatch('psychic', DamageAccent.psychic);
    addIfMatch('force', DamageAccent.force);
    addIfMatch('slashing', DamageAccent.slashing);
    addIfMatch('piercing', DamageAccent.piercing);
    addIfMatch('bludgeoning', DamageAccent.bludgeoning);

    return accents;
  }

  /// Formatted market cost or estimated price for the specified rules edition.
  String getEffectivePrice([DmRulesEdition edition = DmRulesEdition.v2024]) {
    if (edition == DmRulesEdition.v2014 && cost2014 != null && cost2014!.isNotEmpty) {
      return cost2014!;
    }
    if (edition == DmRulesEdition.v2024 && cost2024 != null && cost2024!.isNotEmpty) {
      return cost2024!;
    }
    if (cost != null && cost!.isNotEmpty) {
      return cost!;
    }

    // Check for explicit 'Cost: ...' in properties
    final rules = getRules(edition);
    for (final prop in rules.properties) {
      final lower = prop.toLowerCase();
      if (lower.startsWith('cost:')) {
        return prop.substring(5).trim();
      }
    }

    // Standard 5e / DMG Rarity-based pricing
    final consumable = isConsumable;
    return switch (rarity) {
      ItemRarity.nonmagical => 'Varies',
      ItemRarity.common => consumable ? '25–50 gp' : '50–100 gp',
      ItemRarity.uncommon => consumable ? '100–250 gp' : '100–500 gp',
      ItemRarity.rare => consumable ? '1,000–2,500 gp' : '500–5,000 gp',
      ItemRarity.veryRare => consumable ? '10,000–25,000 gp' : '5,000–50,000 gp',
      ItemRarity.legendary => consumable ? '50,000–100,000+ gp' : '50,000–200,000+ gp',
      ItemRarity.artifact => 'Priceless / Unique',
    };
  }

  /// Formatted attunement label (e.g. "Requires Attunement by a Spellcaster").
  String getAttunementLabel() {
    if (!requiresAttunement) return 'No Attunement Required';
    if (attunementRequirement != null && attunementRequirement!.isNotEmpty) {
      return 'Requires Attunement ($attunementRequirement)';
    }
    return 'Requires Attunement';
  }

  /// Resolves comprehensive 5e (2014 & 2024) crafting rules and downtime parameters for this item.
  ItemCraftingDetails getCraftingDetails([DmRulesEdition edition = DmRulesEdition.v2024]) {
    final lowerName = name.toLowerCase();
    final lowerTags = tags.map((t) => t.toLowerCase()).toSet();
    final rules = getRules(edition);
    final text = '${rules.summary} ${rules.description} ${rules.properties.join(" ")}'.toLowerCase();
    final consumable = isConsumable;

    // 1. Resolve Tool Proficiencies
    String primaryTool;
    List<String> altTools = [];

    if (category == ItemCategory.potion) {
      if (lowerName.contains('healing') ||
          lowerName.contains('antitoxin') ||
          lowerTags.contains('healing') ||
          lowerTags.contains('herbalism')) {
        primaryTool = 'Herbalism Kit';
        altTools = ['Alchemist\'s Supplies'];
      } else {
        primaryTool = 'Alchemist\'s Supplies';
        altTools = ['Herbalism Kit', 'Brewer\'s Supplies'];
      }
    } else if (category == ItemCategory.scroll) {
      primaryTool = 'Calligrapher\'s Supplies';
      altTools = ['Arcana (Spell Focus)'];
    } else if (category == ItemCategory.weapon) {
      if (lowerTags.contains('bow') ||
          lowerTags.contains('crossbow') ||
          lowerTags.contains('arrow') ||
          lowerTags.contains('ammunition') ||
          lowerName.contains('bow') ||
          lowerName.contains('arrow') ||
          lowerName.contains('club') ||
          lowerName.contains('staff') ||
          lowerName.contains('sling') ||
          lowerName.contains('blowgun') ||
          lowerName.contains('dart')) {
        primaryTool = 'Woodcarver\'s Tools';
        altTools = ['Carpenter\'s Tools', 'Smith\'s Tools'];
      } else {
        primaryTool = 'Smith\'s Tools';
        altTools = ['Tinker\'s Tools'];
      }
    } else if (category == ItemCategory.armor) {
      if (lowerTags.contains('leather') ||
          lowerTags.contains('hide') ||
          lowerTags.contains('padded') ||
          lowerName.contains('leather') ||
          lowerName.contains('hide') ||
          lowerName.contains('padded') ||
          lowerName.contains('studded')) {
        primaryTool = 'Leatherworker\'s Tools';
        altTools = ['Cobbler\'s Tools', 'Weaver\'s Tools'];
      } else if (lowerTags.contains('robe') ||
          lowerTags.contains('cloak') ||
          lowerTags.contains('cloth') ||
          lowerName.contains('robe') ||
          lowerName.contains('cloak') ||
          lowerName.contains('cloth') ||
          lowerName.contains('garb')) {
        primaryTool = 'Weaver\'s Tools';
        altTools = ['Leatherworker\'s Tools'];
      } else {
        primaryTool = 'Smith\'s Tools';
        altTools = ['Leatherworker\'s Tools'];
      }
    } else if (category == ItemCategory.ring) {
      primaryTool = 'Jeweler\'s Tools';
      altTools = ['Smith\'s Tools'];
    } else if (category == ItemCategory.rod ||
        category == ItemCategory.wand ||
        category == ItemCategory.staff) {
      if (lowerTags.contains('metal') ||
          lowerTags.contains('iron') ||
          lowerTags.contains('steel') ||
          lowerName.contains('iron') ||
          lowerName.contains('steel') ||
          lowerName.contains('silver') ||
          lowerName.contains('gold')) {
        primaryTool = 'Smith\'s Tools';
        altTools = ['Jeweler\'s Tools', 'Woodcarver\'s Tools'];
      } else {
        primaryTool = 'Woodcarver\'s Tools';
        altTools = ['Jeweler\'s Tools', 'Glassblower\'s Tools'];
      }
    } else {
      // Wondrous item or Adventuring gear
      if (lowerTags.contains('leather') ||
          lowerTags.contains('boot') ||
          lowerTags.contains('shoe') ||
          lowerName.contains('boot') ||
          lowerName.contains('shoe') ||
          lowerName.contains('slipper') ||
          lowerName.contains('glove') ||
          lowerName.contains('gauntlet') ||
          lowerName.contains('belt') ||
          lowerName.contains('saddle') ||
          lowerName.contains('bag') ||
          lowerName.contains('pouch') ||
          lowerName.contains('quiver') ||
          lowerName.contains('scabbard')) {
        primaryTool = 'Leatherworker\'s Tools';
        altTools = ['Cobbler\'s Tools', 'Weaver\'s Tools'];
      } else if (lowerTags.contains('cloth') ||
          lowerTags.contains('robe') ||
          lowerTags.contains('cloak') ||
          lowerName.contains('robe') ||
          lowerName.contains('cloak') ||
          lowerName.contains('hat') ||
          lowerName.contains('cap') ||
          lowerName.contains('carpet') ||
          lowerName.contains('rope') ||
          lowerName.contains('sail') ||
          lowerName.contains('banner') ||
          lowerName.contains('flag') ||
          lowerName.contains('tent') ||
          lowerName.contains('blanket')) {
        primaryTool = 'Weaver\'s Tools';
        altTools = ['Leatherworker\'s Tools'];
      } else if (lowerTags.contains('gem') ||
          lowerTags.contains('jewel') ||
          lowerTags.contains('amulet') ||
          lowerTags.contains('necklace') ||
          lowerName.contains('gem') ||
          lowerName.contains('jewel') ||
          lowerName.contains('amulet') ||
          lowerName.contains('necklace') ||
          lowerName.contains('periapt') ||
          lowerName.contains('brooch') ||
          lowerName.contains('circlet') ||
          lowerName.contains('medallion') ||
          lowerName.contains('crown') ||
          lowerName.contains('pearl') ||
          lowerName.contains('bead') ||
          lowerName.contains('stone') ||
          lowerName.contains('ioun') ||
          lowerName.contains('crystal') ||
          lowerName.contains('talisman')) {
        primaryTool = 'Jeweler\'s Tools';
        altTools = ['Smith\'s Tools'];
      } else if (lowerTags.contains('instrument') ||
          lowerName.contains('instrument') ||
          lowerName.contains('horn') ||
          lowerName.contains('flute') ||
          lowerName.contains('lute') ||
          lowerName.contains('harp') ||
          lowerName.contains('drum') ||
          lowerName.contains('pipe') ||
          lowerName.contains('bell') ||
          lowerName.contains('whistle') ||
          lowerName.contains('chime')) {
        primaryTool = 'Musical Instrument (relevant)';
        altTools = ['Woodcarver\'s Tools', 'Smith\'s Tools'];
      } else if (lowerTags.contains('clockwork') ||
          lowerTags.contains('device') ||
          lowerName.contains('clockwork') ||
          lowerName.contains('apparatus') ||
          lowerName.contains('cube') ||
          lowerName.contains('box') ||
          lowerName.contains('tinker') ||
          lowerName.contains('folding') ||
          lowerName.contains('compass') ||
          lowerName.contains('sphere') ||
          lowerName.contains('mechanism')) {
        primaryTool = 'Tinker\'s Tools';
        altTools = ['Smith\'s Tools', 'Carpenter\'s Tools'];
      } else if (lowerTags.contains('glass') ||
          lowerName.contains('glass') ||
          lowerName.contains('flask') ||
          lowerName.contains('bottle') ||
          lowerName.contains('mirror') ||
          lowerName.contains('lens') ||
          lowerName.contains('orb') ||
          lowerName.contains('beaker') ||
          lowerName.contains('decanter') ||
          lowerName.contains('hourglass')) {
        primaryTool = 'Glassblower\'s Tools';
        altTools = ['Jeweler\'s Tools', 'Tinker\'s Tools'];
      } else if (lowerTags.contains('wood') ||
          lowerName.contains('boat') ||
          lowerName.contains('ship') ||
          lowerName.contains('canoe') ||
          lowerName.contains('chest') ||
          lowerName.contains('statue') ||
          lowerName.contains('figurine') ||
          lowerName.contains('feather')) {
        primaryTool = 'Woodcarver\'s Tools';
        altTools = ['Carpenter\'s Tools'];
      } else if (lowerTags.contains('metal') ||
          lowerName.contains('iron') ||
          lowerName.contains('steel') ||
          lowerName.contains('horseshoe') ||
          lowerName.contains('brazier') ||
          lowerName.contains('anvil') ||
          lowerName.contains('chain') ||
          lowerName.contains('shackles')) {
        primaryTool = 'Smith\'s Tools';
        altTools = ['Tinker\'s Tools'];
      } else {
        primaryTool = 'Tinker\'s Tools';
        altTools = ['Jeweler\'s Tools', 'Arcana Focus'];
      }
    }

    // 2. Bastion Facility Recommendation (2024 DMG)
    String bastionFacility;
    if (category == ItemCategory.potion) {
      bastionFacility = 'Laboratory or Garden';
    } else if (category == ItemCategory.scroll) {
      bastionFacility = 'Arcane Study or Scriptorium';
    } else if (category == ItemCategory.weapon ||
        category == ItemCategory.armor ||
        primaryTool == 'Smith\'s Tools') {
      bastionFacility = 'Smithy or Workshop';
    } else if (lowerTags.contains('radiant') ||
        lowerTags.contains('holy') ||
        lowerTags.contains('healing') ||
        lowerName.contains('holy') ||
        lowerName.contains('divine')) {
      bastionFacility = 'Sanctuary or Arcane Study';
    } else {
      bastionFacility = 'Workshop or Arcane Study';
    }

    // 3. Prerequisite Spells Detection
    final spells = <String>[];
    void checkSpell(String keyword, String spellName) {
      if (text.contains(keyword) || lowerName.contains(keyword)) {
        if (!spells.contains(spellName)) spells.add(spellName);
      }
    }

    checkSpell('fireball', 'Fireball');
    checkSpell('cure wounds', 'Cure Wounds');
    checkSpell('healing word', 'Healing Word');
    checkSpell('lightning bolt', 'Lightning Bolt');
    checkSpell('invisibility', 'Invisibility');
    checkSpell('fly', 'Fly');
    checkSpell('haste', 'Haste');
    checkSpell('teleport', 'Teleport');
    checkSpell('misty step', 'Misty Step');
    checkSpell('dimension door', 'Dimension Door');
    checkSpell('shield', 'Shield');
    checkSpell('mage armor', 'Mage Armor');
    checkSpell('detect magic', 'Detect Magic');
    checkSpell('identify', 'Identify');
    checkSpell('water breathing', 'Water Breathing');
    checkSpell('water walk', 'Water Walk');
    checkSpell('feather fall', 'Feather Fall');
    checkSpell('polymorph', 'Polymorph');
    checkSpell('scrying', 'Scrying');
    checkSpell('revivify', 'Revivify');
    checkSpell('restoration', 'Lesser/Greater Restoration');

    // 4. Gold Cost & Crafting Time Resolution
    int goldCost;
    String goldCostDisplay;
    int days2024;
    String time2024Display;
    String time2014Display;
    int? minLevel;
    String exoticCr;
    bool formulaRequired = true;
    final notes = <String>[];

    if (rarity == ItemRarity.nonmagical) {
      final priceStr = getEffectivePrice(edition);
      final match = RegExp(r'(\d[\d,]*)').firstMatch(priceStr);
      final basePrice = match != null ? int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 10 : 10;
      goldCost = (basePrice / 2).ceil().clamp(1, 1000000);
      goldCostDisplay = '$goldCost gp (50% of $priceStr base price)';
      days2024 = (basePrice / 10).ceil().clamp(1, 365);
      final days2014 = (basePrice / 5).ceil().clamp(1, 730);
      time2024Display = '$days2024 ${days2024 == 1 ? 'day' : 'days'} (at 10 gp/day progress rate)';
      time2014Display = '$days2014 ${days2014 == 1 ? 'day' : 'days'} (at 5 gp/day RAW progress)';
      minLevel = null;
      exoticCr = 'Standard raw materials (No monster harvest needed)';
      formulaRequired = false;
      notes.add('Requires proficiency with $primaryTool.');
      notes.add('Raw materials cost 50% of the item\'s market purchase price.');
      notes.add('2024 Rules: Progress is made at 10 gp per day during downtime.');
    } else if (rarity == ItemRarity.common) {
      goldCost = consumable ? 25 : 50;
      goldCostDisplay = '$goldCost gp${consumable ? " (Consumable half-cost)" : ""}';
      days2024 = consumable ? 3 : 5;
      time2024Display = consumable
          ? '2.5 days (approx 3 days @ 10 gp/day)'
          : '5 days (1 workweek @ 10 gp/day)';
      time2014Display = consumable ? '2.5 days' : '1 workweek (5 days)';
      minLevel = 3;
      exoticCr = 'CR 1–3 monster component or minor planar harvest';
      notes.add('Requires Arcane Formula / Schematic.');
      notes.add('Character must be at least 3rd level.');
      if (consumable) {
        notes.add('Consumable item: Halves crafting time and gold material costs.');
      }
    } else if (rarity == ItemRarity.uncommon) {
      goldCost = consumable ? 100 : 200;
      goldCostDisplay = '$goldCost gp${consumable ? " (Consumable half-cost)" : ""}';
      days2024 = consumable ? 10 : 20;
      time2024Display = consumable
          ? '10 days (2 workweeks @ 10 gp/day)'
          : '20 days (4 workweeks @ 10 gp/day)';
      time2014Display = consumable ? '1 workweek (5 days)' : '2 workweeks (10 days)';
      minLevel = 3;
      exoticCr = 'CR 4–8 monster component or rare elemental essence';
      notes.add('Requires Arcane Formula / Blueprint.');
      notes.add('Character must be at least 3rd level.');
      if (consumable) {
        notes.add('Consumable item: Halves crafting time and gold material costs.');
      }
    } else if (rarity == ItemRarity.rare) {
      goldCost = consumable ? 1000 : 2000;
      goldCostDisplay = '$goldCost gp${consumable ? " (Consumable half-cost)" : ""}';
      days2024 = consumable ? 100 : 200;
      time2024Display = consumable
          ? '100 days (or 25 days with 4 workshop assistants)'
          : '200 days (or 50 days with 4 workshop assistants)';
      time2014Display = consumable ? '5 workweeks (25 days)' : '10 workweeks (50 days)';
      minLevel = 6;
      exoticCr = 'CR 9–12 monster component (e.g., Young Dragon, Salamander, Chimera)';
      notes.add('Requires Arcane Formula / Blueprint.');
      notes.add('Character must be at least 6th level.');
      notes.add('Assistant crafters with tool proficiency can divide the crafting time.');
      if (consumable) {
        notes.add('Consumable item: Halves crafting time and gold material costs.');
      }
    } else if (rarity == ItemRarity.veryRare) {
      goldCost = consumable ? 10000 : 20000;
      goldCostDisplay = '$goldCost gp${consumable ? " (Consumable half-cost)" : ""}';
      days2024 = consumable ? 1000 : 2000;
      time2024Display = consumable
          ? '1,000 days (Bastion workshop / guild assisted)'
          : '2,000 days (Bastion workshop / guild assisted)';
      time2014Display = consumable ? '12.5 workweeks (62.5 days)' : '25 workweeks (125 days)';
      minLevel = 11;
      exoticCr = 'CR 13–18 monster component (e.g., Adult Dragon, Iron Golem, Marilith, Purple Worm)';
      notes.add('Requires Arcane Formula / Master Blueprint.');
      notes.add('Character must be at least 11th level.');
      notes.add('Typically crafted in a high-tier Bastion or with an organized artisan guild.');
      if (consumable) {
        notes.add('Consumable item: Halves crafting time and gold material costs.');
      }
    } else if (rarity == ItemRarity.legendary) {
      goldCost = consumable ? 50000 : 100000;
      goldCostDisplay = '$goldCost gp${consumable ? " (Consumable half-cost)" : ""}';
      days2024 = consumable ? 10000 : 20000;
      time2024Display = consumable
          ? '10,000 days (Mythic Bastion enterprise)'
          : '20,000 days (Mythic Bastion enterprise)';
      time2014Display = consumable ? '25 workweeks (125 days)' : '50 workweeks (250 days)';
      minLevel = 17;
      exoticCr = 'CR 19+ monster component (e.g., Ancient Dragon, Pit Fiend, Kraken, Lich)';
      notes.add('Requires Master Arcane Formula.');
      notes.add('Character must be at least 17th level.');
      notes.add('Requires mythic planar forging or grand guild/Bastion enterprise.');
      if (consumable) {
        notes.add('Consumable item: Halves crafting time and gold material costs.');
      }
    } else {
      // Artifact
      goldCost = 0;
      goldCostDisplay = 'Priceless / Cosmic (Cannot be crafted via standard downtime)';
      days2024 = 0;
      time2024Display = 'Planar / Divine Quest Undertaking';
      time2014Display = 'Artifact Quest / Divine Intervention';
      minLevel = 20;
      exoticCr = 'Divine / Cosmic catalyst or deity forge';
      formulaRequired = false;
      notes.add('Artifacts cannot be forged through ordinary mortal downtime crafting.');
      notes.add('Forging an artifact requires a cosmic quest, planar furnace, or divine patron.');
    }

    if (spells.isNotEmpty) {
      notes.add('Spellcasting Prerequisite: Must be capable of casting ${spells.join(", ")} or expend the requisite spell slot daily during crafting.');
    }

    final quickSummary = rarity == ItemRarity.artifact
        ? 'Artifact: Divine quest or planar forge required.'
        : '$goldCostDisplay • $primaryTool • ${edition == DmRulesEdition.v2024 ? time2024Display : time2014Display}';

    return ItemCraftingDetails(
      primaryTool: primaryTool,
      alternativeTools: altTools,
      goldCost: goldCost,
      goldCostDisplay: goldCostDisplay,
      craftingDays2024: days2024,
      craftingTime2024Display: time2024Display,
      craftingTime2014Display: time2014Display,
      minimumCharacterLevel: minLevel,
      exoticIngredientCr: exoticCr,
      bastionFacility: bastionFacility,
      isConsumable: consumable,
      formulaRequired: formulaRequired,
      prerequisiteSpells: spells,
      specialNotes: notes,
      quickSummary: quickSummary,
    );
  }

  /// Formatted item name for the requested rules edition.
  String getName(DmRulesEdition edition) {
    if (edition == DmRulesEdition.v2014 && name2014 != null) {
      return name2014!;
    }
    if (edition == DmRulesEdition.v2024 && name2024 != null) {
      return name2024!;
    }
    return name;
  }

  /// Rules details for the active rules edition.
  ItemEditionDetails getRules(DmRulesEdition edition) {
    return edition == DmRulesEdition.v2014 ? rules2014 : rules2024;
  }

  static final Map<String, String> _corpusCache = {};

  static void clearCacheForTesting() {
    _corpusCache.clear();
  }

  String _getCorpus(DmRulesEdition edition) {
    final cacheKey = '${id}_${edition.name}';
    final cached = _corpusCache[cacheKey];
    if (cached != null) return cached;

    final effectiveName = getName(edition);
    final effectiveRules = getRules(edition);
    final priceStr = getEffectivePrice(edition);
    final crafting = getCraftingDetails(edition);

    final buffer = StringBuffer()
      ..write('$effectiveName ')
      ..write('${category.displayName} ')
      ..write('${rarity.displayName} ')
      ..write('$priceStr ')
      ..write('${crafting.primaryTool} ')
      ..write('${crafting.bastionFacility} ')
      ..write('${crafting.alternativeTools.join(" ")} ')
      ..write('${damageAccent?.displayName ?? ""} ')
      ..write('${effectiveRules.summary} ')
      ..write('${effectiveRules.description} ')
      ..write('${diffSummary ?? ""} ')
      ..write('${tags.join(" ")} ');

    for (final r in actionRings) {
      buffer
        ..write('${r.ringType.displayName} ')
        ..write('${r.damageLegend} ')
        ..write('${r.label ?? ""} ');
    }

    final corpus = buffer.toString().toLowerCase();
    _corpusCache[cacheKey] = corpus;
    return corpus;
  }

  /// Checks if this item matches search and filter criteria.
  bool matches(
    String query, {
    ItemCategory? categoryFilter,
    ItemRarity? rarityFilter,
    bool? attunementOnly,
    bool? changedOnly,
    DamageAccent? damageAccentFilter,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    if (categoryFilter != null && category != categoryFilter) return false;
    if (rarityFilter != null && rarity != rarityFilter) return false;
    if (attunementOnly == true && !requiresAttunement) return false;
    if (changedOnly == true && !isChangedIn2024) return false;
    if (damageAccentFilter != null && damageAccent != damageAccentFilter) return false;

    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return _getCorpus(edition).contains(q);
  }
}

/// Comprehensive 5e Crafting and Downtime Metadata for magic & mundane items.
class ItemCraftingDetails {
  final String primaryTool;
  final List<String> alternativeTools;
  final int goldCost;
  final String goldCostDisplay;
  final int craftingDays2024;
  final String craftingTime2024Display;
  final String craftingTime2014Display;
  final int? minimumCharacterLevel;
  final String exoticIngredientCr;
  final String bastionFacility;
  final bool isConsumable;
  final bool formulaRequired;
  final List<String> prerequisiteSpells;
  final List<String> specialNotes;
  final String quickSummary;

  const ItemCraftingDetails({
    required this.primaryTool,
    this.alternativeTools = const [],
    required this.goldCost,
    required this.goldCostDisplay,
    required this.craftingDays2024,
    required this.craftingTime2024Display,
    required this.craftingTime2014Display,
    this.minimumCharacterLevel,
    required this.exoticIngredientCr,
    required this.bastionFacility,
    this.isConsumable = false,
    this.formulaRequired = true,
    this.prerequisiteSpells = const [],
    this.specialNotes = const [],
    required this.quickSummary,
  });
}

/// Standard 5e D&D Currency types (cp, sp, ep, gp, pp) with distinct color coding.
enum CurrencyCoinType {
  cp('Copper', 'cp', Color(0xFFFB923C), Color(0xFFC2410C)),
  sp('Silver', 'sp', Color(0xFF94A3B8), Color(0xFF475569)),
  ep('Electrum', 'ep', Color(0xFFFDE047), Color(0xFF854D0E)),
  gp('Gold', 'gp', Color(0xFFFBBF24), Color(0xFFB45309)),
  pp('Platinum', 'pp', Color(0xFF38BDF8), Color(0xFF0369A1));

  final String displayName;
  final String suffix;
  final Color darkColor;
  final Color lightColor;

  const CurrencyCoinType(this.displayName, this.suffix, this.darkColor, this.lightColor);

  Color getLegibleColor(bool isDarkMode) => isDarkMode ? darkColor : lightColor;

  /// Resolves the currency coin type from a price string (e.g. "1 sp", "50 cp", "100 gp", "10 pp").
  static CurrencyCoinType resolve(String text) {
    final lower = text.toLowerCase().trim();
    final tokens = lower.split(RegExp(r'[^a-zA-Z]+'));
    if (tokens.contains('cp') || lower.endsWith('cp') || lower.contains('copper')) {
      return CurrencyCoinType.cp;
    }
    if (tokens.contains('sp') || lower.endsWith('sp') || lower.contains('silver')) {
      return CurrencyCoinType.sp;
    }
    if (tokens.contains('ep') || lower.endsWith('ep') || lower.contains('electrum')) {
      return CurrencyCoinType.ep;
    }
    if (tokens.contains('pp') || lower.endsWith('pp') || lower.contains('platinum')) {
      return CurrencyCoinType.pp;
    }
    return CurrencyCoinType.gp;
  }
}

/// Resolves the theme-aware accent color for a currency or price string (cp, sp, ep, gp, pp).
Color getCurrencyColor(String priceText, bool isDarkMode) {
  return CurrencyCoinType.resolve(priceText).getLegibleColor(isDarkMode);
}


