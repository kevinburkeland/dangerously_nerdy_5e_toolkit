import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/domain/core_types.dart';

/// Result of checking whether an incoming entity matches a canonical SRD entry.
enum SrdMatchResult {
  /// The entity is not an SRD canon entity — import normally.
  notSrd,

  /// The entity is identical to an SRD entry (same slug + same core name).
  /// Skip it entirely to avoid duplicating built-in content.
  exactSrdMatch,

  /// The entity shares an SRD name but has a different slug or additional
  /// custom content. The additive merge strategy will enrich the SRD entity
  /// with any extra traits/features from the incoming entity.
  srdVariantAdditive,
}

/// Comprehensive O(1) slug/name deduplication barrier over all SRD libraries.
///
/// The index is built lazily the first time [checkEntity] is called, and can
/// be explicitly [rebuild]d after any SRD library mutation.
///
/// ## Additive Merge Policy (Q1 resolution)
/// When an incoming entity is [srdVariantAdditive], the ingestion pipeline
/// enriches the canonical SRD entity with any non-duplicate extra content from
/// the incoming entity rather than creating a duplicate or rejecting it.
class SrdEquivalenceIndex {
  // Singleton — one index for the lifetime of the app.
  static final SrdEquivalenceIndex _instance = SrdEquivalenceIndex._();
  factory SrdEquivalenceIndex() => _instance;
  SrdEquivalenceIndex._();

  // Slug sets per entity type — exact match: "fighter" == "fighter"
  final Map<EntityType, Set<String>> _slugsByType = {};
  // Normalised-name sets for fuzzy name matching
  final Map<EntityType, Set<String>> _namesByType = {};

  bool _built = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Checks whether an incoming [slug]/[name]/[type] triple matches a
  /// canonical SRD entry. Builds the index on first call.
  SrdMatchResult checkEntity({
    required String slug,
    required String name,
    required EntityType type,
  }) {
    if (!_built) build();

    final slugSet = _slugsByType[type] ?? const {};
    final nameSet = _namesByType[type] ?? const {};

    if (slugSet.contains(slug)) return SrdMatchResult.exactSrdMatch;

    final normalizedName = _slugify(name);
    if (nameSet.contains(normalizedName)) {
      return SrdMatchResult.srdVariantAdditive;
    }

    return SrdMatchResult.notSrd;
  }

  /// Returns true iff [slug] is a canonical SRD entity of [type].
  bool isCanonSrd(String slug, EntityType type) {
    if (!_built) build();
    return (_slugsByType[type] ?? const <String>{}).contains(slug);
  }

  /// Rebuilds the index from all SRD libraries.
  /// Call after SRD library mutations or test reset.
  void build() {
    _slugsByType.clear();
    _namesByType.clear();

    // 1. Classes (SrdClassesLibrary — base SRD only, not custom homebrew)
    _index(EntityType.classDefinition,
      SrdClassesLibrary.allClasses.where((c) => c.id.ruleset != RulesetVersion.homebrew).map((c) => c.id.slug).toSet(),
      SrdClassesLibrary.allClasses.where((c) => c.id.ruleset != RulesetVersion.homebrew).map((c) => _slugify(c.name)).toSet(),
    );

    // 2. Subclasses
    final baseSubclasses = SrdClassesLibrary.allClasses
        .where((c) => c.id.ruleset != RulesetVersion.homebrew)
        .expand((c) => c.subclasses);
    _index(EntityType.subclass,
      baseSubclasses.map((s) => s.id.slug).toSet(),
      baseSubclasses.map((s) => _slugify(s.name)).toSet(),
    );

    // 3. Species (SrdSpeciesLibrary — base only)
    final baseSpecies = SrdSpeciesLibrary.allSpecies.where((r) => r.id.ruleset != RulesetVersion.homebrew);
    _index(EntityType.species,
      baseSpecies.map((r) => r.id.slug).toSet(),
      baseSpecies.map((r) => _slugify(r.name)).toSet(),
    );

    // 4. Feats (SrdFeatsLibrary — base only)
    final baseFeats = SrdFeatsLibrary.allFeats.where((f) => f.id.ruleset != RulesetVersion.homebrew);
    _index(EntityType.feat,
      baseFeats.map((f) => f.id.slug).toSet(),
      baseFeats.map((f) => _slugify(f.name)).toSet(),
    );

    // 5. Backgrounds (SrdBackgroundsLibrary — base only)
    final baseBgs = SrdBackgroundsLibrary.allBackgrounds.where((b) => b.id.ruleset != RulesetVersion.homebrew);
    _index(EntityType.background,
      baseBgs.map((b) => b.id.slug).toSet(),
      baseBgs.map((b) => _slugify(b.name)).toSet(),
    );

    // Note: Spells and Monsters are excluded from the SRD deduplication scope
    // per the engineering brief (they are "largely working as intended").
    // Items (magic + mundane) are not deduplicated since the SRD equipment
    // library doesn't expose a flat EquipmentItem list (it uses SrdEquipmentPackage).
    // Both can be added in a future phase if needed.

    _built = true;
  }

  /// Invalidates the index — it will be rebuilt on the next [checkEntity] call.
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
        .replaceAll(RegExp(r"['']"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
