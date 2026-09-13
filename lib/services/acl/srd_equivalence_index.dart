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
    // Unify hyphenated possessives (e.g. 'melf-s-acid-arrow' -> 'melfs-acid-arrow')
    final unifiedSlug = normSlug.replaceAll(RegExp(r'-s(-|$)'), r's$1');

    // 1. Direct slug, unified slug, or normalized name match
    if (slugSet.contains(normSlug) ||
        slugSet.contains(unifiedSlug) ||
        slugSet.contains(normName)) {
      return SrdMatchResult.exactSrdMatch;
    }

    // 2. Normalized name match
    if (nameSet.contains(normName)) {
      return SrdMatchResult.exactSrdMatch;
    }

    // 3. Subclass class-prefix stripping (e.g., 'rogue-thief' -> 'thief')
    if (type == EntityType.subclass) {
      final withoutClass = normSlug.replaceFirst(RegExp(r'^[a-z]+-'), '');
      if (slugSet.contains(withoutClass) || nameSet.contains(withoutClass)) {
        return SrdMatchResult.exactSrdMatch;
      }
    }

    // 4. Stripped source suffix match (e.g., "fireball-phb", "fireball-srd", "goblin-mm", "fighter-2024")
    final stripped = normSlug.replaceAll(
      RegExp(r'[-_](phb|dmg|mm|xge|tce|srd|srd52|srd51|2014|2024|v2014|v2024|xphb)$'),
      '',
    );
    final strippedUnified = unifiedSlug.replaceAll(
      RegExp(r'[-_](phb|dmg|mm|xge|tce|srd|srd52|srd51|2014|2024|v2014|v2024|xphb)$'),
      '',
    );
    if (slugSet.contains(stripped) ||
        slugSet.contains(strippedUnified) ||
        nameSet.contains(stripped)) {
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
    final unifiedSlug = normSlug.replaceAll(RegExp(r'-s(-|$)'), r's$1');
    if (slugSet.contains(normSlug) || slugSet.contains(unifiedSlug)) return true;
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

    // 1. Spells (SpellbookLibrary — all canonical SRD spells only)
    final spellSlugs = <String>{};
    final spellNames = <String>{};
    for (final s in SpellbookLibrary.srdSpells) {
      final sSlug = s.id.toLowerCase().trim();
      final normName = _slugify(s.name);
      spellSlugs.add(sSlug);
      spellSlugs.add(sSlug.replaceAll(RegExp(r'[-_]'), ''));
      spellSlugs.add(sSlug.replaceAll('spell_', '').replaceAll('_', '-'));
      spellSlugs.add(normName);
      spellNames.add(normName);
    }
    _index(EntityType.spell, spellSlugs, spellNames);

    // 2. Monsters (MonsterCodexLibrary — base SRD monsters only)
    final monsterSlugs = <String>{};
    final monsterNames = <String>{};
    for (final m in MonsterCodexLibrary.allMonsters.where((m) => !m.isHomebrew)) {
      final mSlug = m.id.toLowerCase().trim();
      final normName = _slugify(m.name);
      monsterSlugs.add(mSlug);
      monsterSlugs.add(mSlug.replaceAll(RegExp(r'[-_]'), ''));
      monsterSlugs.add(normName);
      monsterNames.add(normName);
      if (m.name2014 != null) monsterNames.add(_slugify(m.name2014!));
    }
    _index(EntityType.monster, monsterSlugs, monsterNames);

    // 3. Equipment & Magic Items (MagicItemLibrary + SrdEquipmentLibrary)
    final itemSlugs = <String>{};
    final itemNames = <String>{};
    for (final item in MagicItemLibrary.baseItems) {
      final iSlug = item.id.toLowerCase().trim();
      final normName = _slugify(item.name);
      itemSlugs.add(iSlug);
      itemSlugs.add(iSlug.replaceAll('_', '-'));
      itemSlugs.add(normName);
      itemNames.add(normName);
      if (item.name2014 != null) itemNames.add(_slugify(item.name2014!));
      if (item.name2024 != null) itemNames.add(_slugify(item.name2024!));
    }
    for (final eq in SrdEquipmentLibrary.allEquipmentItems) {
      itemSlugs.add(eq.id.slug.toLowerCase().trim());
      itemSlugs.add(_slugify(eq.name));
      itemNames.add(_slugify(eq.name));
    }
    _index(EntityType.equipment, itemSlugs, itemNames);

    // 4. Classes (SrdClassesLibrary.baseClasses — base SRD only, unpolluted by custom classes)
    final baseClasses = SrdClassesLibrary.baseClasses;
    final classSlugs = <String>{};
    final classNames = <String>{};
    for (final c in baseClasses) {
      classSlugs.add(c.id.slug.toLowerCase().trim());
      classSlugs.add(_slugify(c.name));
      classNames.add(_slugify(c.name));
    }
    _index(EntityType.classDefinition, classSlugs, classNames);

    // 5. Subclasses (SrdClassesLibrary baseClasses)
    final subSlugs = <String>{};
    final subNames = <String>{};
    for (final c in baseClasses) {
      final cSlug = c.id.slug.toLowerCase().trim();
      for (final s in c.subclasses) {
        final sSlug = s.id.slug.toLowerCase().trim();
        final sName = _slugify(s.name);
        final sShort = _slugify(s.shortName);
        subSlugs.add(sSlug);
        subSlugs.add('$cSlug-$sSlug');
        subSlugs.add(sName);
        subSlugs.add('$cSlug-$sName');
        subSlugs.add(sShort);
        subNames.add(sName);
        subNames.add(sShort);
      }
    }
    _index(EntityType.subclass, subSlugs, subNames);

    // 6. Species & Races (SrdSpeciesLibrary.baseSpecies)
    final baseSpecies = SrdSpeciesLibrary.baseSpecies;
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

    // 7. Feats (SrdFeatsLibrary.baseFeats)
    final baseFeats = SrdFeatsLibrary.baseFeats;
    final featSlugs = <String>{};
    final featNames = <String>{};
    for (final f in baseFeats) {
      featSlugs.add(f.id.slug.toLowerCase().trim());
      featSlugs.add(_slugify(f.name));
      featNames.add(_slugify(f.name));
    }
    _index(EntityType.feat, featSlugs, featNames);

    // 8. Backgrounds (SrdBackgroundsLibrary.baseBackgrounds)
    final baseBgs = SrdBackgroundsLibrary.baseBackgrounds;
    final bgSlugs = <String>{};
    final bgNames = <String>{};
    for (final b in baseBgs) {
      bgSlugs.add(b.id.slug.toLowerCase().trim());
      bgSlugs.add(_slugify(b.name));
      bgNames.add(_slugify(b.name));
    }
    _index(EntityType.background, bgSlugs, bgNames);

    // 9. Canonical Eldritch Invocations, Actions & Conditions (SrdFeatureOptions & Core Rules)
    final customSlugs = <String>{};
    final customNames = <String>{};
    for (final inv in SrdFeatureOptions.baseWarlockInvocationsAndBoons) {
      customSlugs.add(inv.id.toLowerCase().trim());
      customSlugs.add(inv.id.replaceAll('_', '-').toLowerCase().trim());
      customSlugs.add(_slugify(inv.name));
      customNames.add(_slugify(inv.name));
    }
    const coreRules = [
      'attack', 'dash', 'disengage', 'dodge', 'help', 'hide', 'ready', 'search',
      'cast-a-spell', 'use-an-object', 'activate-an-item', 'climb-onto-a-bigger-creature',
      'blinded', 'charmed', 'deafened', 'frightened', 'grappled', 'incapacitated',
      'invisible', 'paralyzed', 'petrified', 'poisoned', 'prone', 'restrained',
      'stunned', 'unconscious', 'exhaustion',
    ];
    for (final cr in coreRules) {
      customSlugs.add(cr);
      customNames.add(cr);
    }
    _index(EntityType.custom, customSlugs, customNames);

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
