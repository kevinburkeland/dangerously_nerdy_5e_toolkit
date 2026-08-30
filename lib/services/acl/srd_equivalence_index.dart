import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_equipment_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/domain/core_types.dart';
import '../../models/magic_items/magic_item_library.dart';
import '../../models/monster_codex_data.dart';
import '../../models/spellbook_data.dart';

/// Result of checking whether an incoming entity matches a canonical SRD entry.
enum SrdMatchResult {
  /// The entity is not an SRD canon entity — import normally as novel homebrew.
  notSrd,

  /// The entity is an exact canonical SRD entry (same slug or normalized name).
  /// Excluded by default during import and pruned during reparse to prevent duplicate content.
  exactSrdMatch,

  /// The entity shares an SRD name but has a different variant slug.
  srdVariantAdditive,
}

/// Comprehensive O(1) slug/name deduplication barrier over ALL canonical SRD libraries:
/// Spells, Monsters, Magic Items & Equipment, Classes, Subclasses, Species/Races, Feats, and Backgrounds.
class SrdEquivalenceIndex {
  static final SrdEquivalenceIndex _instance = SrdEquivalenceIndex._();
  factory SrdEquivalenceIndex() => _instance;
  SrdEquivalenceIndex._();

  // Normalized slug sets per entity type — exact slug match: "fireball" == "fireball"
  final Map<EntityType, Set<String>> _slugsByType = {};
  // Normalized-name sets per entity type for fuzzy/canonical name matching
  final Map<EntityType, Set<String>> _namesByType = {};

  bool _built = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Checks whether an incoming [slug]/[name]/[type] triple matches a canonical SRD entry.
  SrdMatchResult checkEntity({
    required String slug,
    required String name,
    required EntityType type,
  }) {
    if (!_built) build();

    final slugSet = _slugsByType[type] ?? const {};
    final nameSet = _namesByType[type] ?? const {};

    final normSlug = slug.toLowerCase().trim();
    final normName = _slugify(name);

    // 1. Direct slug or normalized name match
    if (slugSet.contains(normSlug) || slugSet.contains(normName)) {
      return SrdMatchResult.exactSrdMatch;
    }

    // 2. Normalized name match
    if (nameSet.contains(normName)) {
      return SrdMatchResult.exactSrdMatch;
    }

    // 3. Stripped source suffix match (e.g., "fireball-phb", "fireball-srd", "goblin-mm", "fighter-2024")
    final stripped = normSlug.replaceAll(
      RegExp(r'[-_](phb|dmg|mm|xge|tce|srd|srd52|srd51|2014|2024|v2014|v2024|xphb)$'),
      '',
    );
    if (slugSet.contains(stripped) || nameSet.contains(stripped)) {
      return SrdMatchResult.exactSrdMatch;
    }

    return SrdMatchResult.notSrd;
  }

  /// Returns true iff [slug] or [name] is a canonical SRD entity of [type].
  bool isCanonSrd(String slug, EntityType type, {String? name}) {
    if (!_built) build();
    if (name != null && name.isNotEmpty) {
      return checkEntity(slug: slug, name: name, type: type) != SrdMatchResult.notSrd;
    }
    final slugSet = _slugsByType[type] ?? const {};
    final normSlug = slug.toLowerCase().trim();
    if (slugSet.contains(normSlug)) return true;
    final stripped = normSlug.replaceAll(
      RegExp(r'[-_](phb|dmg|mm|xge|tce|srd|srd52|srd51|2014|2024|v2014|v2024|xphb)$'),
      '',
    );
    return slugSet.contains(stripped);
  }

  /// Rebuilds the index from all SRD libraries across all 8 major categories.
  void build() {
    _slugsByType.clear();
    _namesByType.clear();

    // 1. Spells (SpellbookLibrary — all canonical SRD spells)
    final spellSlugs = <String>{};
    final spellNames = <String>{};
    for (final s in SpellbookLibrary.allSpells) {
      spellSlugs.add(s.id.toLowerCase().trim());
      spellSlugs.add(_slugify(s.name));
      spellNames.add(_slugify(s.name));
    }
    _index(EntityType.spell, spellSlugs, spellNames);

    // 2. Monsters (MonsterCodexLibrary — base SRD monsters only)
    final monsterSlugs = <String>{};
    final monsterNames = <String>{};
    for (final m in MonsterCodexLibrary.allMonsters.where((m) => !m.isHomebrew)) {
      monsterSlugs.add(m.id.toLowerCase().trim());
      monsterSlugs.add(_slugify(m.name));
      monsterNames.add(_slugify(m.name));
    }
    _index(EntityType.monster, monsterSlugs, monsterNames);

    // 3. Equipment & Magic Items (MagicItemLibrary + SrdEquipmentLibrary)
    final itemSlugs = <String>{};
    final itemNames = <String>{};
    for (final item in MagicItemLibrary.allItems) {
      itemSlugs.add(item.id.toLowerCase().trim());
      itemSlugs.add(item.id.replaceAll('_', '-').toLowerCase().trim());
      itemSlugs.add(_slugify(item.name));
      itemNames.add(_slugify(item.name));
      if (item.name2014 != null) itemNames.add(_slugify(item.name2014!));
      if (item.name2024 != null) itemNames.add(_slugify(item.name2024!));
    }
    for (final eq in SrdEquipmentLibrary.allEquipmentItems) {
      itemSlugs.add(eq.id.slug.toLowerCase().trim());
      itemSlugs.add(_slugify(eq.name));
      itemNames.add(_slugify(eq.name));
    }
    _index(EntityType.equipment, itemSlugs, itemNames);

    // 4. Classes (SrdClassesLibrary — base SRD only)
    final baseClasses = SrdClassesLibrary.allClasses.where((c) => c.id.ruleset != RulesetVersion.homebrew);
    final classSlugs = <String>{};
    final classNames = <String>{};
    for (final c in baseClasses) {
      classSlugs.add(c.id.slug.toLowerCase().trim());
      classSlugs.add(_slugify(c.name));
      classNames.add(_slugify(c.name));
    }
    _index(EntityType.classDefinition, classSlugs, classNames);

    // 5. Subclasses (SrdClassesLibrary)
    final baseSubclasses = baseClasses.expand((c) => c.subclasses);
    final subSlugs = <String>{};
    final subNames = <String>{};
    for (final s in baseSubclasses) {
      subSlugs.add(s.id.slug.toLowerCase().trim());
      subSlugs.add(_slugify(s.name));
      subSlugs.add(_slugify(s.shortName));
      subNames.add(_slugify(s.name));
      subNames.add(_slugify(s.shortName));
    }
    _index(EntityType.subclass, subSlugs, subNames);

    // 6. Species & Races (SrdSpeciesLibrary)
    final baseSpecies = SrdSpeciesLibrary.allSpecies.where((r) => r.id.ruleset != RulesetVersion.homebrew);
    final raceSlugs = <String>{};
    final raceNames = <String>{};
    for (final r in baseSpecies) {
      raceSlugs.add(r.id.slug.toLowerCase().trim());
      raceSlugs.add(_slugify(r.name));
      raceNames.add(_slugify(r.name));
      for (final sub in r.subraces) {
        raceSlugs.add(sub.id.slug.toLowerCase().trim());
        raceSlugs.add(_slugify(sub.name));
        raceNames.add(_slugify(sub.name));
      }
    }
    _index(EntityType.species, raceSlugs, raceNames);

    // 7. Feats (SrdFeatsLibrary)
    final baseFeats = SrdFeatsLibrary.allFeats.where((f) => f.id.ruleset != RulesetVersion.homebrew);
    final featSlugs = <String>{};
    final featNames = <String>{};
    for (final f in baseFeats) {
      featSlugs.add(f.id.slug.toLowerCase().trim());
      featSlugs.add(_slugify(f.name));
      featNames.add(_slugify(f.name));
    }
    _index(EntityType.feat, featSlugs, featNames);

    // 8. Backgrounds (SrdBackgroundsLibrary)
    final baseBgs = SrdBackgroundsLibrary.allBackgrounds.where((b) => b.id.ruleset != RulesetVersion.homebrew);
    final bgSlugs = <String>{};
    final bgNames = <String>{};
    for (final b in baseBgs) {
      bgSlugs.add(b.id.slug.toLowerCase().trim());
      bgSlugs.add(_slugify(b.name));
      bgNames.add(_slugify(b.name));
    }
    _index(EntityType.background, bgSlugs, bgNames);

    // 9. Canonical Eldritch Invocations & Optional Features (SrdFeatureOptions)
    final invSlugs = <String>{};
    final invNames = <String>{};
    for (final inv in SrdFeatureOptions.warlockInvocationsAndBoons) {
      invSlugs.add(inv.id.toLowerCase().trim());
      invSlugs.add(inv.id.replaceAll('_', '-').toLowerCase().trim());
      invSlugs.add(_slugify(inv.name));
      invNames.add(_slugify(inv.name));
    }
    _index(EntityType.custom, invSlugs, invNames);

    _built = true;
  }

  /// Invalidates the index — it will be rebuilt on the next check call.
  void invalidate() => _built = false;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _index(EntityType type, Set<String> slugs, Set<String> names) {
    _slugsByType[type] = slugs;
    _namesByType[type] = names;
  }

  static String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
