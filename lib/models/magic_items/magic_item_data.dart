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
