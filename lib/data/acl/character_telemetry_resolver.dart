import 'package:flutter/foundation.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_equipment_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/magic_items/magic_item_library.dart';
import '../../services/persistence/homebrew_persistence_service.dart';
import 'character_telemetry_dto.dart';

/// Resolved presentation information for a single class level progression.
@immutable
class ResolvedClassInfo {
  final String classSlug;
  final String className;
  final String? subclassSlug;
  final String? subclassName;
  final int level;
  final bool isResolved;

  const ResolvedClassInfo({
    required this.classSlug,
    required this.className,
    this.subclassSlug,
    this.subclassName,
    required this.level,
    required this.isResolved,
  });

  String get displayName {
    if (subclassName != null && subclassName!.isNotEmpty) {
      return '$className ($subclassName) $level';
    }
    return '$className $level';
  }
}

/// Fully hydrated presentation model for a remote party member or DM dashboard character.
/// Rebuilt on-device from ephemeral telemetry data and local libraries.
@immutable
class ResolvedCharacterDisplay {
  final String id;
  final String name;
  final String speciesSlug;
  final String speciesName;
  final String? backgroundSlug;
  final String backgroundName;
  final String classSummary;
  final List<ResolvedClassInfo> classes;
  final int currentHp;
  final int maxHp;
  final int tempHp;
  final int armorClass;
  final int speed;
  final int totalLevel;
  final int passivePerception;
  final int exhaustionLevel;
  final int deathSaveSuccesses;
  final int deathSaveFailures;
  final List<String> conditions;
  final Map<String, int> spellSlots;
  final List<String> featNames;
  final List<String> equippedItemNames;
  final bool hasUnresolvedPointers;
  final List<String> unresolvedSlugs;
  final String rulesEdition;
  final int timestamp;

  const ResolvedCharacterDisplay({
    required this.id,
    required this.name,
    required this.speciesSlug,
    required this.speciesName,
    this.backgroundSlug,
    required this.backgroundName,
    required this.classSummary,
    required this.classes,
    required this.currentHp,
    required this.maxHp,
    required this.tempHp,
    required this.armorClass,
    required this.speed,
    required this.totalLevel,
    required this.passivePerception,
    required this.exhaustionLevel,
    required this.deathSaveSuccesses,
    required this.deathSaveFailures,
    required this.conditions,
    required this.spellSlots,
    required this.featNames,
    required this.equippedItemNames,
    required this.hasUnresolvedPointers,
    required this.unresolvedSlugs,
    required this.rulesEdition,
    required this.timestamp,
  });

  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;
  bool get isConscious => currentHp > 0;
  bool get isDying => currentHp == 0 && deathSaveFailures < 3;
  bool get isDead => deathSaveFailures >= 3;
}

/// Anti-Corruption Layer service hydrating display text, titles, and combat meters
/// from [CharacterTelemetryDto] against local canonical and homebrew databases.
class CharacterTelemetryResolver {
  /// Converts kebab-case, snake_case, or compact slugs to clean Title Case.
  static String formatSlugToTitle(String slug) {
    if (slug.isEmpty) return 'Unknown';
    final clean = slug.trim().replaceAll(RegExp(r'[-_]+'), ' ');
    return clean
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Resolves typed entity pointers in [dto] against local SRD libraries and
  /// the device's [HomebrewPersistenceService].
  static Future<ResolvedCharacterDisplay> resolve(
    CharacterTelemetryDto dto, {
    HomebrewPersistenceService? homebrewService,
  }) async {
    final hb = homebrewService ?? HomebrewPersistenceService();
    final unresolved = <String>[];

    // 1. Resolve Species
    String speciesName = 'Unknown Species';
    final spSlug = dto.speciesSlug.trim().toLowerCase();
    if (spSlug.isNotEmpty) {
      final srdSpecies = SrdSpeciesLibrary.findBySlug(spSlug);
      if (srdSpecies != null) {
        speciesName = srdSpecies.name;
      } else {
        final customRaces = await hb.loadCustomRaces();
        final match = customRaces.where((r) => r.id.slug.toLowerCase() == spSlug).firstOrNull;
        if (match != null) {
          speciesName = match.name;
        } else {
          speciesName = formatSlugToTitle(spSlug);
          unresolved.add(spSlug);
        }
      }
    }

    // 2. Resolve Background
    String backgroundName = 'None';
    final bgSlug = dto.backgroundSlug?.trim().toLowerCase();
    if (bgSlug != null && bgSlug.isNotEmpty) {
      final srdBg = SrdBackgroundsLibrary.findBySlug(bgSlug);
      if (srdBg != null) {
        backgroundName = srdBg.name;
      } else {
        final customBgs = await hb.loadCustomBackgrounds();
        final match = customBgs.where((b) => b.id.slug.toLowerCase() == bgSlug).firstOrNull;
        if (match != null) {
          backgroundName = match.name;
        } else {
          backgroundName = formatSlugToTitle(bgSlug);
          unresolved.add(bgSlug);
        }
      }
    }

    // 3. Resolve Classes and Subclasses
    final resolvedClasses = <ResolvedClassInfo>[];
    final classParts = <String>[];
    final customClasses = await hb.loadCustomClasses();
    final customSubclasses = await hb.loadCustomSubclasses();

    for (final pointer in dto.classPointers) {
      final cSlug = pointer.classSlug.trim().toLowerCase();
      String className = formatSlugToTitle(cSlug);
      bool isClassResolved = false;

      final srdClass = SrdClassesLibrary.findBySlug(cSlug);
      if (srdClass != null) {
        className = srdClass.name;
        isClassResolved = true;
      } else {
        final customClassMatch = customClasses.where((c) => c.id.slug.toLowerCase() == cSlug).firstOrNull;
        if (customClassMatch != null) {
          className = customClassMatch.name;
          isClassResolved = true;
        } else {
          unresolved.add(cSlug);
        }
      }

      String? subclassName;
      if (pointer.subclassSlug != null && pointer.subclassSlug!.trim().isNotEmpty) {
        final scSlug = pointer.subclassSlug!.trim().toLowerCase();
        final srdSubclass = SrdClassesLibrary.allSubclasses.where((s) => s.id.slug == scSlug || s.name.toLowerCase() == scSlug).firstOrNull;
        if (srdSubclass != null) {
          subclassName = srdSubclass.name;
        } else {
          final customSubMatch = customSubclasses.where((s) => s.id.slug.toLowerCase() == scSlug).firstOrNull;
          if (customSubMatch != null) {
            subclassName = customSubMatch.name;
          } else {
            subclassName = formatSlugToTitle(scSlug);
            unresolved.add(scSlug);
          }
        }
      }

      resolvedClasses.add(ResolvedClassInfo(
        classSlug: cSlug,
        className: className,
        subclassSlug: pointer.subclassSlug,
        subclassName: subclassName,
        level: pointer.level,
        isResolved: isClassResolved,
      ));

      if (subclassName != null && subclassName.isNotEmpty) {
        classParts.add('$className ($subclassName) ${pointer.level}');
      } else {
        classParts.add('$className ${pointer.level}');
      }
    }

    final classSummary = classParts.isNotEmpty ? classParts.join(' / ') : 'Adventurer ${dto.level}';

    // 4. Resolve Feats
    final resolvedFeatNames = <String>[];
    final customFeats = await hb.loadCustomFeats();
    for (final fSlug in dto.featSlugs) {
      final clean = fSlug.trim().toLowerCase();
      final srdFeat = SrdFeatsLibrary.findBySlug(clean);
      if (srdFeat != null) {
        resolvedFeatNames.add(srdFeat.name);
      } else {
        final customFeatMatch = customFeats.where((f) => f.id.slug.toLowerCase() == clean).firstOrNull;
        if (customFeatMatch != null) {
          resolvedFeatNames.add(customFeatMatch.name);
        } else {
          resolvedFeatNames.add(formatSlugToTitle(clean));
          unresolved.add(clean);
        }
      }
    }

    // 5. Resolve Equipped Items
    final resolvedEquippedNames = <String>[];
    final customItems = await hb.loadCustomItems();
    for (final eqSlug in dto.equippedItemSlugs) {
      final clean = eqSlug.trim().toLowerCase();
      final cleanNormalized = clean.replaceAll('-', '_');
      String? itemName;
      final magicItem = MagicItemLibrary.findById(clean) ??
          MagicItemLibrary.findById(cleanNormalized) ??
          MagicItemLibrary.findByName(clean) ??
          MagicItemLibrary.allItems.where((m) {
            final mId = m.id.toLowerCase();
            final mName = m.name.toLowerCase();
            return mId == clean ||
                mId == cleanNormalized ||
                mName == clean ||
                mId == 'armor_$cleanNormalized' ||
                mId == 'weapon_$cleanNormalized' ||
                mName.replaceAll(' ', '-') == clean ||
                (clean.contains('plate') && mId.contains('plate'));
          }).firstOrNull;

      if (magicItem != null) {
        itemName = magicItem.name;
      } else {
        final eqMatch = SrdEquipmentLibrary.allEquipmentItems.where((e) {
          final eId = e.id.slug.toLowerCase();
          final eName = e.name.toLowerCase();
          return eId == clean ||
              eId == cleanNormalized ||
              eName == clean ||
              eName.replaceAll(' ', '-') == clean;
        }).firstOrNull;
        if (eqMatch != null) {
          itemName = eqMatch.name;
        } else {
          final customItemMatch = customItems.where((i) => i.id.slug.toLowerCase() == clean).firstOrNull;
          if (customItemMatch != null) {
            itemName = customItemMatch.name;
          }
        }
      }

      if (itemName != null) {
        resolvedEquippedNames.add(itemName);
      } else {
        resolvedEquippedNames.add(formatSlugToTitle(clean));
        unresolved.add(clean);
      }
    }

    return ResolvedCharacterDisplay(
      id: dto.id,
      name: dto.name,
      speciesSlug: dto.speciesSlug,
      speciesName: speciesName,
      backgroundSlug: dto.backgroundSlug,
      backgroundName: backgroundName,
      classSummary: classSummary,
      classes: resolvedClasses,
      currentHp: dto.currentHp,
      maxHp: dto.maxHp,
      tempHp: dto.tempHp,
      armorClass: dto.armorClass,
      speed: dto.speed,
      totalLevel: dto.level,
      passivePerception: dto.passivePerception,
      exhaustionLevel: dto.exhaustionLevel,
      deathSaveSuccesses: dto.deathSaveSuccesses,
      deathSaveFailures: dto.deathSaveFailures,
      conditions: dto.conditions,
      spellSlots: dto.spellSlots,
      featNames: resolvedFeatNames,
      equippedItemNames: resolvedEquippedNames,
      hasUnresolvedPointers: unresolved.isNotEmpty,
      unresolvedSlugs: unresolved,
      rulesEdition: dto.rulesEdition,
      timestamp: dto.timestamp,
    );
  }
}
