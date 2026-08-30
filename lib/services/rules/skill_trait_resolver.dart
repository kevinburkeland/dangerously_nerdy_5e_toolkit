import 'package:flutter/foundation.dart';
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';

/// Innate/Racial native spell model for spells granted by species or racial heritage.
@immutable
class InnateSpeciesSpell {
  final EntityReference<Spell> spellRef;
  final int minCharacterLevel;
  final String castingAbility;
  final bool isCantrip;
  final int chargesPerLongRest; // 1 = once per long rest, 0 = at will (cantrip)

  const InnateSpeciesSpell({
    required this.spellRef,
    required this.minCharacterLevel,
    this.castingAbility = 'Charisma',
    this.isCantrip = false,
    this.chargesPerLongRest = 1,
  });
}

/// Structured collision and allocation report for skills.
@immutable
class SkillCollisionReport {
  final Map<SkillType, String> grantedSkills; // Skill -> Source description
  final List<SkillType> collidingSkills; // Collisions detected
  final int compensatoryPicksEarned; // Count of free compensatory selections granted
  final Set<SkillType> availableSkillPool; // Unassigned skills eligible for compensatory pick
  final Map<SkillType, SkillProficiencyLevel> resolvedProficiencies;

  const SkillCollisionReport({
    required this.grantedSkills,
    required this.collidingSkills,
    required this.compensatoryPicksEarned,
    required this.availableSkillPool,
    required this.resolvedProficiencies,
  });
}

/// Pure rules engine for resolving skill collisions, compensatory picks, and racial traits.
class SkillTraitResolver {
  SkillTraitResolver._();

  /// Resolves background fixed skills, species fixed skills, and class selections.
  /// When a class skill selection collides with a background/species grant, a compensatory pick is granted.
  static SkillCollisionReport resolveSkills({
    required String speciesSlug,
    required String? backgroundSlug,
    required String classSlug,
    required Set<SkillType> requestedClassSkills,
    required Set<SkillType> compensatoryPicks,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final granted = <SkillType, String>{};
    final collisions = <SkillType>[];
    final resolved = <SkillType, SkillProficiencyLevel>{};

    // 1. Ingest Species Fixed Skills
    final sSlug = speciesSlug.toLowerCase();
    if (sSlug.contains('elf') && !sSlug.contains('half-elf')) {
      granted[SkillType.perception] = 'Species: Elf (Keen Senses)';
    } else if (sSlug.contains('half-orc') || sSlug.contains('orc')) {
      granted[SkillType.intimidation] = 'Species: Half-Orc (Menacing)';
    }

    // 2. Ingest Background Fixed Skills
    if (backgroundSlug != null) {
      final bg = backgroundSlug.toLowerCase();
      switch (bg) {
        case 'acolyte':
          _addOrCollide(granted, collisions, SkillType.insight, 'Background: Acolyte');
          _addOrCollide(granted, collisions, SkillType.religion, 'Background: Acolyte');
        case 'criminal':
        case 'spy':
          _addOrCollide(granted, collisions, SkillType.deception, 'Background: Criminal');
          _addOrCollide(granted, collisions, SkillType.stealth, 'Background: Criminal');
        case 'entertainer':
          _addOrCollide(granted, collisions, SkillType.acrobatics, 'Background: Entertainer');
          _addOrCollide(granted, collisions, SkillType.performance, 'Background: Entertainer');
        case 'folk-hero':
        case 'folk_hero':
        case 'guide':
          _addOrCollide(granted, collisions, SkillType.animalHandling, 'Background: Folk Hero');
          _addOrCollide(granted, collisions, SkillType.survival, 'Background: Folk Hero');
        case 'guild-artisan':
        case 'guild_artisan':
        case 'merchant':
          _addOrCollide(granted, collisions, SkillType.insight, 'Background: Guild Artisan');
          _addOrCollide(granted, collisions, SkillType.persuasion, 'Background: Guild Artisan');
        case 'noble':
          _addOrCollide(granted, collisions, SkillType.history, 'Background: Noble');
          _addOrCollide(granted, collisions, SkillType.persuasion, 'Background: Noble');
        case 'sage':
          _addOrCollide(granted, collisions, SkillType.arcana, 'Background: Sage');
          _addOrCollide(granted, collisions, SkillType.history, 'Background: Sage');
        case 'sailor':
          _addOrCollide(granted, collisions, SkillType.athletics, 'Background: Sailor');
          _addOrCollide(granted, collisions, SkillType.perception, 'Background: Sailor');
        case 'soldier':
          _addOrCollide(granted, collisions, SkillType.athletics, 'Background: Soldier');
          _addOrCollide(granted, collisions, SkillType.intimidation, 'Background: Soldier');
        case 'urchin':
          _addOrCollide(granted, collisions, SkillType.sleightOfHand, 'Background: Urchin');
          _addOrCollide(granted, collisions, SkillType.stealth, 'Background: Urchin');
      }
    }

    // 3. Process Requested Class Skills & Detect Overlaps
    for (final skill in requestedClassSkills) {
      if (granted.containsKey(skill)) {
        collisions.add(skill);
      } else {
        granted[skill] = 'Class: ${classSlug.toUpperCase()}';
      }
    }

    // 4. Ingest Compensatory Picks
    for (final compSkill in compensatoryPicks) {
      if (!granted.containsKey(compSkill)) {
        granted[compSkill] = 'Compensatory Choice (RAW Fallback)';
      }
    }

    // 5. Populate resolved map
    for (final skill in granted.keys) {
      resolved[skill] = SkillProficiencyLevel.proficient;
    }

    // 6. Compute unassigned available skill pool
    final available = SkillType.values.where((s) => !granted.containsKey(s)).toSet();

    return SkillCollisionReport(
      grantedSkills: granted,
      collidingSkills: collisions,
      compensatoryPicksEarned: collisions.length,
      availableSkillPool: available,
      resolvedProficiencies: resolved,
    );
  }

  static void _addOrCollide(
    Map<SkillType, String> granted,
    List<SkillType> collisions,
    SkillType skill,
    String source,
  ) {
    if (granted.containsKey(skill)) {
      collisions.add(skill);
    } else {
      granted[skill] = source;
    }
  }

  /// Calculates dynamic flexible skill bonus count granted by species
  static int getSpeciesBonusSkillCount(String speciesSlug, DmRulesEdition edition) {
    final slug = speciesSlug.toLowerCase();
    if (slug == 'human' && edition == DmRulesEdition.v2024) {
      return 1; // 2024 Human Skillful
    } else if (slug == 'human-variant' || slug == 'human_variant') {
      return 1; // 2014 Variant Human
    } else if (slug == 'half-elf' || slug == 'half_elf') {
      return 2; // Half-Elf Skill Versatility
    } else if (slug == 'custom-lineage' || slug == 'custom_lineage') {
      return 1;
    }
    return 0;
  }

  /// Returns native innate species spells based on character level scaling
  static List<InnateSpeciesSpell> getInnateSpeciesSpells({
    required String speciesSlug,
    required String? subraceSlug,
    required int totalCharacterLevel,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final spells = <InnateSpeciesSpell>[];
    final slug = speciesSlug.toLowerCase();
    final subSlug = subraceSlug?.toLowerCase() ?? '';

    // Tiefling
    if (slug.contains('tiefling')) {
      spells.add(InnateSpeciesSpell(
        spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'thaumaturgy', displayName: 'Thaumaturgy'),
        minCharacterLevel: 1,
        isCantrip: true,
        chargesPerLongRest: 0,
      ));
      if (totalCharacterLevel >= 3) {
        spells.add(InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'hellish-rebuke', displayName: 'Hellish Rebuke'),
          minCharacterLevel: 3,
          chargesPerLongRest: 1,
        ));
      }
      if (totalCharacterLevel >= 5) {
        spells.add(InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'darkness', displayName: 'Darkness'),
          minCharacterLevel: 5,
          chargesPerLongRest: 1,
        ));
      }
    }

    // Drow / Dark Elf
    if (subSlug.contains('drow') || slug.contains('drow')) {
      spells.add(InnateSpeciesSpell(
        spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'dancing-lights', displayName: 'Dancing Lights'),
        minCharacterLevel: 1,
        isCantrip: true,
        chargesPerLongRest: 0,
      ));
      if (totalCharacterLevel >= 3) {
        spells.add(InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'faerie-fire', displayName: 'Faerie Fire'),
          minCharacterLevel: 3,
          chargesPerLongRest: 1,
        ));
      }
      if (totalCharacterLevel >= 5) {
        spells.add(InnateSpeciesSpell(
          spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'darkness', displayName: 'Darkness'),
          minCharacterLevel: 5,
          chargesPerLongRest: 1,
        ));
      }
    }

    // Forest Gnome
    if (subSlug.contains('forest') && slug.contains('gnome')) {
      spells.add(InnateSpeciesSpell(
        spellRef: EntityReference<Spell>(refType: EntityType.spell, slug: 'minor-illusion', displayName: 'Minor Illusion'),
        minCharacterLevel: 1,
        isCantrip: true,
        chargesPerLongRest: 0,
      ));
    }

    return spells;
  }

  /// Derives native physical and sensory traits from species
  static ({int baseSpeedFeet, int darkvisionFeet, int hpPerLevelBonus, bool powerfulBuild}) getSpeciesTraits({
    required String speciesSlug,
    required String? subraceSlug,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final slug = speciesSlug.toLowerCase();
    final subSlug = subraceSlug?.toLowerCase() ?? '';

    int speed = 30;
    int darkvision = 0;
    int hpBonus = 0;
    bool powerfulBuild = false;

    // Speed calculation
    if (subSlug.contains('wood') || subSlug.contains('wood-elf')) {
      speed = 35;
    } else if (slug == 'goliath') {
      speed = edition == DmRulesEdition.v2024 ? 35 : 30;
      powerfulBuild = true;
    } else if (edition == DmRulesEdition.v2014 &&
        (slug == 'dwarf' || slug == 'gnome' || slug == 'halfling')) {
      speed = 25;
    }

    // Darkvision
    if (slug.contains('elf') || slug.contains('dwarf') || slug.contains('gnome') ||
        slug.contains('half-orc') || slug.contains('tiefling')) {
      darkvision = (subSlug.contains('drow') || slug.contains('drow')) ? 120 : 60;
    }

    // Dwarven Toughness
    if (slug.contains('dwarf') && (edition == DmRulesEdition.v2024 || subSlug.contains('hill'))) {
      hpBonus = 1;
    }

    return (
      baseSpeedFeet: speed,
      darkvisionFeet: darkvision,
      hpPerLevelBonus: hpBonus,
      powerfulBuild: powerfulBuild,
    );
  }
}
