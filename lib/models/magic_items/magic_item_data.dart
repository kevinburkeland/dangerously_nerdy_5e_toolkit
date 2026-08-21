import '../dm_screen_data.dart';
import '../../widgets/glyphs/glyph_tokens.dart';

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
    this.tags = const [],
  });

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
