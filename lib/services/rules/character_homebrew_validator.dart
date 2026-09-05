import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_equipment_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/magic_items/magic_item_library.dart';
import '../../models/spellbook_data.dart';

/// The category/type of homebrew entity.
enum HomebrewEntityType {
  classType('Class'),
  subclassType('Subclass'),
  speciesType('Species / Race'),
  subspeciesType('Subspecies / Subrace'),
  backgroundType('Background'),
  featType('Feat'),
  spellType('Spell'),
  itemType('Item / Equipment'),
  otherType('Homebrew Content');

  final String label;
  const HomebrewEntityType(this.label);

  static HomebrewEntityType fromString(String val) {
    final lower = val.toLowerCase().trim();
    if (lower.contains('subclass')) return HomebrewEntityType.subclassType;
    if (lower.contains('class')) return HomebrewEntityType.classType;
    if (lower.contains('subspecies') || lower.contains('subrace')) {
      return HomebrewEntityType.subspeciesType;
    }
    if (lower.contains('species') || lower.contains('race')) {
      return HomebrewEntityType.speciesType;
    }
    if (lower.contains('background')) return HomebrewEntityType.backgroundType;
    if (lower.contains('feat')) return HomebrewEntityType.featType;
    if (lower.contains('spell')) return HomebrewEntityType.spellType;
    if (lower.contains('item') || lower.contains('equipment')) {
      return HomebrewEntityType.itemType;
    }
    return HomebrewEntityType.otherType;
  }
}

/// Represents a single missing homebrew item required by a character.
class MissingHomebrewItem {
  final HomebrewEntityType type;
  final String slug;
  final String name;
  final String? details;

  const MissingHomebrewItem({
    required this.type,
    required this.slug,
    required this.name,
    this.details,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MissingHomebrewItem &&
          type == other.type &&
          slug.toLowerCase() == other.slug.toLowerCase();

  @override
  int get hashCode => type.hashCode ^ slug.toLowerCase().hashCode;

  @override
  String toString() => '${type.label}: $name ($slug)';
}

/// Result report returned by [CharacterHomebrewValidator.validate].
class MissingHomebrewReport {
  final List<MissingHomebrewItem> missingItems;

  const MissingHomebrewReport({
    this.missingItems = const [],
  });

  bool get hasMissing => missingItems.isNotEmpty;
  int get count => missingItems.length;

  /// Returns missing items grouped by their [HomebrewEntityType].
  Map<HomebrewEntityType, List<MissingHomebrewItem>> get groupedByType {
    final map = <HomebrewEntityType, List<MissingHomebrewItem>>{};
    for (final item in missingItems) {
      map.putIfAbsent(item.type, () => []).add(item);
    }
    return map;
  }

  /// Human-readable summary for banner chips or tooltips.
  String get summary {
    if (!hasMissing) return 'All homebrew loaded.';
    final parts = <String>[];
    final grouped = groupedByType;
    grouped.forEach((type, items) {
      parts.add('${items.length} ${type.label}${items.length > 1 ? "s" : ""}');
    });
    return 'Missing ${parts.join(", ")}';
  }
}

/// Service that inspects characters for dependencies on homebrew content
/// (classes, subclasses, species, backgrounds, feats, spells, items)
/// and reports whether any of them are missing from the active runtime libraries.
class CharacterHomebrewValidator {
  CharacterHomebrewValidator._();

  static const Set<String> _coreClasses = {
    'barbarian',
    'bard',
    'cleric',
    'druid',
    'fighter',
    'monk',
    'paladin',
    'ranger',
    'rogue',
    'sorcerer',
    'warlock',
    'wizard',
    'artificer',
  };

  static const Set<String> _coreSpecies = {
    'human',
    'human-variant',
    'custom-lineage',
    'elf',
    'dwarf',
    'halfling',
    'dragonborn',
    'gnome',
    'half-elf',
    'half-orc',
    'tiefling',
    'aasimar',
    'goliath',
    'orc',
  };

  static const Set<String> _coreBackgrounds = {
    'acolyte',
    'criminal',
    'entertainer',
    'folk-hero',
    'guild-artisan',
    'noble',
    'sage',
    'sailor',
    'soldier',
    'urchin',
    'artisan',
    'charlatan',
    'farmer',
    'guard',
    'guide',
    'hermit',
    'merchant',
    'scribe',
    'wayfarer',
  };

  /// Validates [character] and returns a [MissingHomebrewReport].
  static MissingHomebrewReport validate(Character character) {
    final missing = <MissingHomebrewItem>[];

    // 1. Check explicit homebrew manifest if recorded in customProperties
    final explicitDeps = character.customProperties['usedHomebrew'] ??
        character.customProperties['homebrewDependencies'];
    if (explicitDeps is List) {
      for (final dep in explicitDeps) {
        if (dep is Map) {
          final typeStr = dep['type']?.toString() ?? '';
          final slug = dep['slug']?.toString() ?? '';
          final name = dep['name']?.toString() ?? slug;
          if (slug.isEmpty) continue;

          final entityType = HomebrewEntityType.fromString(typeStr);
          if (_isItemMissing(entityType, slug, name)) {
            final item = MissingHomebrewItem(
              type: entityType,
              slug: slug,
              name: name,
              details: dep['details']?.toString(),
            );
            if (!missing.contains(item)) {
              missing.add(item);
            }
          }
        }
      }
    }

    // 2. Inherent / deep inspection of character references
    // 2a. Classes
    for (final clsProg in character.progression.classes) {
      final classRef = clsProg.classRef;
      final classSlug = classRef.slug.toLowerCase().trim();
      final isHomebrewClass = classRef.rulesetPreferred == RulesetVersion.homebrew ||
          classSlug.startsWith('custom_') ||
          classSlug.startsWith('homebrew_') ||
          !_coreClasses.contains(classSlug);

      if (isHomebrewClass) {
        final found = SrdClassesLibrary.findBySlug(classSlug);
        if (found == null) {
          final item = MissingHomebrewItem(
            type: HomebrewEntityType.classType,
            slug: classRef.slug,
            name: classRef.displayName.isNotEmpty
                ? classRef.displayName
                : classRef.slug,
            details: 'Required class is not installed in Compendium.',
          );
          if (!missing.contains(item)) missing.add(item);
        }
      }

      // 2b. Subclass
      final subRef = clsProg.subclassRef;
      if (subRef != null && subRef.slug.isNotEmpty) {
        final subSlug = subRef.slug.toLowerCase().trim();
        final subName = subRef.displayName.toLowerCase().trim();
        final foundSub = SrdClassesLibrary.allSubclasses.any((s) =>
            s.id.slug.toLowerCase() == subSlug ||
            s.name.toLowerCase() == subName ||
            s.id.slug.toLowerCase() == subName.replaceAll(' ', '-'));
        if (!foundSub) {
          final item = MissingHomebrewItem(
            type: HomebrewEntityType.subclassType,
            slug: subRef.slug,
            name: subRef.displayName.isNotEmpty
                ? subRef.displayName
                : subRef.slug,
            details: 'Subclass is not installed in Compendium.',
          );
          if (!missing.contains(item)) missing.add(item);
        }
      }
    }

    // 2c. Species / Race
    final speciesRef = character.speciesRef;
    final speciesSlug = speciesRef.slug.toLowerCase().trim();
    final isHomebrewSpecies =
        speciesRef.rulesetPreferred == RulesetVersion.homebrew ||
            speciesSlug.startsWith('custom_') ||
            speciesSlug.startsWith('homebrew_') ||
            !_coreSpecies.contains(speciesSlug);

    if (isHomebrewSpecies) {
      final found = SrdSpeciesLibrary.findBySlug(speciesSlug);
      if (found == null) {
        final item = MissingHomebrewItem(
          type: HomebrewEntityType.speciesType,
          slug: speciesRef.slug,
          name: speciesRef.displayName.isNotEmpty
              ? speciesRef.displayName
              : speciesRef.slug,
          details: 'Species/Race is not installed in Compendium.',
        );
        if (!missing.contains(item)) missing.add(item);
      }
    }

    // 2d. Subspecies / Subrace (if stored in customProperties)
    final subraceProp = character.customProperties['subrace'] ??
        character.customProperties['subspecies'];
    if (subraceProp != null) {
      final subraceStr = subraceProp.toString().toLowerCase().trim();
      if (subraceStr.isNotEmpty) {
        final foundSubrace = SrdSpeciesLibrary.allSpecies.any((r) =>
            r.subraces.any((s) =>
                s.id.slug.toLowerCase() == subraceStr ||
                s.name.toLowerCase() == subraceStr));
        if (!foundSubrace) {
          final item = MissingHomebrewItem(
            type: HomebrewEntityType.subspeciesType,
            slug: subraceStr,
            name: subraceProp.toString(),
            details: 'Subspecies/Subrace is not installed in Compendium.',
          );
          if (!missing.contains(item)) missing.add(item);
        }
      }
    }

    // 2e. Background
    final bgRef = character.backgroundRef;
    if (bgRef != null && bgRef.slug.isNotEmpty) {
      final bgSlug = bgRef.slug.toLowerCase().trim();
      final isHomebrewBg = bgRef.rulesetPreferred == RulesetVersion.homebrew ||
          bgSlug.startsWith('custom_') ||
          bgSlug.startsWith('homebrew_') ||
          !_coreBackgrounds.contains(bgSlug);

      if (isHomebrewBg) {
        final found = SrdBackgroundsLibrary.findBySlug(bgSlug);
        if (found == null) {
          final item = MissingHomebrewItem(
            type: HomebrewEntityType.backgroundType,
            slug: bgRef.slug,
            name: bgRef.displayName.isNotEmpty ? bgRef.displayName : bgRef.slug,
            details: 'Background is not installed in Compendium.',
          );
          if (!missing.contains(item)) missing.add(item);
        }
      }
    }

    // 2f. Feats
    for (final featRef in character.feats) {
      final featSlug = featRef.slug.toLowerCase().trim();
      final isHomebrewFeat = featRef.rulesetPreferred == RulesetVersion.homebrew ||
          featSlug.startsWith('custom_') ||
          featSlug.startsWith('homebrew_');

      if (isHomebrewFeat) {
        final found = SrdFeatsLibrary.findBySlug(featSlug);
        if (found == null) {
          final item = MissingHomebrewItem(
            type: HomebrewEntityType.featType,
            slug: featRef.slug,
            name: featRef.displayName.isNotEmpty
                ? featRef.displayName
                : featRef.slug,
            details: 'Feat is not installed in Compendium.',
          );
          if (!missing.contains(item)) missing.add(item);
        }
      }
    }

    // 2g. Spells
    final allSpells = [
      ...character.cantrips,
      ...character.spellsKnown,
      ...character.spellsPrepared,
    ];
    final checkedSpellSlugs = <String>{};
    for (final spellRef in allSpells) {
      final spellSlug = spellRef.slug.toLowerCase().trim();
      if (checkedSpellSlugs.contains(spellSlug)) continue;
      checkedSpellSlugs.add(spellSlug);

      final isHomebrewSpell =
          spellRef.rulesetPreferred == RulesetVersion.homebrew ||
              spellSlug.startsWith('custom_') ||
              spellSlug.startsWith('homebrew_');

      if (isHomebrewSpell) {
        final found = SpellbookLibrary.findSpell(spellSlug) ??
            SpellbookLibrary.getSpellById(spellSlug);
        if (found == null) {
          final item = MissingHomebrewItem(
            type: HomebrewEntityType.spellType,
            slug: spellRef.slug,
            name: spellRef.displayName.isNotEmpty
                ? spellRef.displayName
                : spellRef.slug,
            details: 'Spell is not installed in Spellbook Compendium.',
          );
          if (!missing.contains(item)) missing.add(item);
        }
      }
    }

    // 2h. Inventory Items
    final checkedItemSlugs = <String>{};
    for (final itemInstance in character.inventory) {
      final itemRef = itemInstance.itemRef;
      final itemSlug = itemRef.slug.toLowerCase().trim();
      if (checkedItemSlugs.contains(itemSlug)) continue;
      checkedItemSlugs.add(itemSlug);

      final isHomebrewItem =
          itemRef.rulesetPreferred == RulesetVersion.homebrew ||
              itemSlug.startsWith('custom_') ||
              itemSlug.startsWith('homebrew_');

      if (isHomebrewItem) {
        final foundMagic = MagicItemLibrary.findById(itemSlug) ??
            MagicItemLibrary.findByName(itemRef.displayName);
        final foundPackage = SrdEquipmentLibrary.allPackages.any(
            (p) => p.items.any((i) => i.itemRef.slug.toLowerCase() == itemSlug));
        if (foundMagic == null && !foundPackage) {
          final item = MissingHomebrewItem(
            type: HomebrewEntityType.itemType,
            slug: itemRef.slug,
            name: itemRef.displayName.isNotEmpty
                ? itemRef.displayName
                : itemRef.slug,
            details: 'Equipment/Item is not installed in Compendium.',
          );
          if (!missing.contains(item)) missing.add(item);
        }
      }
    }

    return MissingHomebrewReport(missingItems: missing);
  }

  /// Checks if an entity is missing from the global compendiums.
  static bool _isItemMissing(HomebrewEntityType type, String slug, String name) {
    final cleanSlug = slug.toLowerCase().trim();
    final cleanName = name.toLowerCase().trim();

    switch (type) {
      case HomebrewEntityType.classType:
        final found = SrdClassesLibrary.findBySlug(cleanSlug);
        return found == null;

      case HomebrewEntityType.subclassType:
        final found = SrdClassesLibrary.allSubclasses.any((s) =>
            s.id.slug.toLowerCase() == cleanSlug ||
            s.name.toLowerCase() == cleanName ||
            s.id.slug.toLowerCase() == cleanName.replaceAll(' ', '-'));
        return !found;

      case HomebrewEntityType.speciesType:
        final found = SrdSpeciesLibrary.findBySlug(cleanSlug);
        return found == null;

      case HomebrewEntityType.subspeciesType:
        final found = SrdSpeciesLibrary.allSpecies.any((r) =>
            r.subraces.any((s) =>
                s.id.slug.toLowerCase() == cleanSlug ||
                s.name.toLowerCase() == cleanName));
        return !found;

      case HomebrewEntityType.backgroundType:
        final found = SrdBackgroundsLibrary.findBySlug(cleanSlug);
        return found == null;

      case HomebrewEntityType.featType:
        final found = SrdFeatsLibrary.findBySlug(cleanSlug);
        return found == null;

      case HomebrewEntityType.spellType:
        final found = SpellbookLibrary.findSpell(cleanSlug) ??
            SpellbookLibrary.getSpellById(cleanSlug);
        return found == null;

      case HomebrewEntityType.itemType:
        final foundMagic = MagicItemLibrary.findById(cleanSlug) ??
            MagicItemLibrary.findByName(cleanName);
        final foundPackage = SrdEquipmentLibrary.allPackages.any(
            (p) => p.items.any((i) => i.itemRef.slug.toLowerCase() == cleanSlug));
        return foundMagic == null && !foundPackage;

      case HomebrewEntityType.otherType:
        return false;
    }
  }

  /// Extracts a list of all homebrew dependencies used by [character] to be stored
  /// in `character.customProperties['usedHomebrew']`.
  static List<Map<String, dynamic>> collectHomebrewDependencies(Character character) {
    final deps = <Map<String, dynamic>>[];
    final seen = <String>{};

    void addDep(HomebrewEntityType type, String slug, String name) {
      final key = '${type.name}_${slug.toLowerCase().trim()}';
      if (seen.contains(key)) return;
      seen.add(key);
      deps.add({
        'type': type.name,
        'slug': slug,
        'name': name,
      });
    }

    // Classes & Subclasses
    for (final clsProg in character.progression.classes) {
      final classRef = clsProg.classRef;
      final classSlug = classRef.slug.toLowerCase().trim();
      if (classRef.rulesetPreferred == RulesetVersion.homebrew ||
          classSlug.startsWith('custom_') ||
          classSlug.startsWith('homebrew_') ||
          !_coreClasses.contains(classSlug)) {
        addDep(
          HomebrewEntityType.classType,
          classRef.slug,
          classRef.displayName.isNotEmpty ? classRef.displayName : classRef.slug,
        );
      }

      final subRef = clsProg.subclassRef;
      if (subRef != null && subRef.slug.isNotEmpty) {
        final isCore = SrdClassesLibrary.allClasses
            .where((c) => _coreClasses.contains(c.id.slug.toLowerCase()))
            .any((c) => c.subclasses.any((s) => s.id.slug == subRef.slug));
        if (!isCore || subRef.rulesetPreferred == RulesetVersion.homebrew) {
          addDep(
            HomebrewEntityType.subclassType,
            subRef.slug,
            subRef.displayName.isNotEmpty ? subRef.displayName : subRef.slug,
          );
        }
      }
    }

    // Species
    final speciesRef = character.speciesRef;
    final speciesSlug = speciesRef.slug.toLowerCase().trim();
    if (speciesRef.rulesetPreferred == RulesetVersion.homebrew ||
        speciesSlug.startsWith('custom_') ||
        speciesSlug.startsWith('homebrew_') ||
        !_coreSpecies.contains(speciesSlug)) {
      addDep(
        HomebrewEntityType.speciesType,
        speciesRef.slug,
        speciesRef.displayName.isNotEmpty
            ? speciesRef.displayName
            : speciesRef.slug,
      );
    }

    // Subspecies / Subrace
    final subraceProp = character.customProperties['subrace'] ??
        character.customProperties['subspecies'];
    if (subraceProp != null && subraceProp.toString().isNotEmpty) {
      addDep(
        HomebrewEntityType.subspeciesType,
        subraceProp.toString().toLowerCase().trim(),
        subraceProp.toString(),
      );
    }

    // Background
    final bgRef = character.backgroundRef;
    if (bgRef != null && bgRef.slug.isNotEmpty) {
      final bgSlug = bgRef.slug.toLowerCase().trim();
      if (bgRef.rulesetPreferred == RulesetVersion.homebrew ||
          bgSlug.startsWith('custom_') ||
          bgSlug.startsWith('homebrew_') ||
          !_coreBackgrounds.contains(bgSlug)) {
        addDep(
          HomebrewEntityType.backgroundType,
          bgRef.slug,
          bgRef.displayName.isNotEmpty ? bgRef.displayName : bgRef.slug,
        );
      }
    }

    // Feats
    for (final featRef in character.feats) {
      final featSlug = featRef.slug.toLowerCase().trim();
      if (featRef.rulesetPreferred == RulesetVersion.homebrew ||
          featSlug.startsWith('custom_') ||
          featSlug.startsWith('homebrew_')) {
        addDep(
          HomebrewEntityType.featType,
          featRef.slug,
          featRef.displayName.isNotEmpty ? featRef.displayName : featRef.slug,
        );
      }
    }

    // Spells
    final allSpells = [
      ...character.cantrips,
      ...character.spellsKnown,
      ...character.spellsPrepared,
    ];
    for (final spellRef in allSpells) {
      final spellSlug = spellRef.slug.toLowerCase().trim();
      if (spellRef.rulesetPreferred == RulesetVersion.homebrew ||
          spellSlug.startsWith('custom_') ||
          spellSlug.startsWith('homebrew_')) {
        addDep(
          HomebrewEntityType.spellType,
          spellRef.slug,
          spellRef.displayName.isNotEmpty
              ? spellRef.displayName
              : spellRef.slug,
        );
      }
    }

    // Items
    for (final itemInstance in character.inventory) {
      final itemRef = itemInstance.itemRef;
      final itemSlug = itemRef.slug.toLowerCase().trim();
      if (itemRef.rulesetPreferred == RulesetVersion.homebrew ||
          itemSlug.startsWith('custom_') ||
          itemSlug.startsWith('homebrew_')) {
        addDep(
          HomebrewEntityType.itemType,
          itemRef.slug,
          itemRef.displayName.isNotEmpty ? itemRef.displayName : itemRef.slug,
        );
      }
    }

    return deps;
  }
}
