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

  /// Formatted attunement label (e.g. "Requires Attunement by a Spellcaster").
  String getAttunementLabel() {
    if (!requiresAttunement) return 'No Attunement Required';
    if (attunementRequirement != null && attunementRequirement!.isNotEmpty) {
      return 'Requires Attunement ($attunementRequirement)';
    }
    return 'Requires Attunement';
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
    final effectiveName = getName(edition).toLowerCase();
    final effectiveRules = getRules(edition);

    return effectiveName.contains(q) ||
        category.displayName.toLowerCase().contains(q) ||
        rarity.displayName.toLowerCase().contains(q) ||
        (damageAccent?.displayName.toLowerCase().contains(q) ?? false) ||
        effectiveRules.summary.toLowerCase().contains(q) ||
        effectiveRules.description.toLowerCase().contains(q) ||
        (diffSummary?.toLowerCase().contains(q) ?? false) ||
        tags.any((t) => t.toLowerCase().contains(q)) ||
        actionRings.any((r) =>
            r.ringType.displayName.toLowerCase().contains(q) ||
            r.damageLegend.toLowerCase().contains(q) ||
            (r.label?.toLowerCase().contains(q) ?? false));
  }
}
