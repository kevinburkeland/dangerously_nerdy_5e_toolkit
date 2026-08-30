import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../repository/reference_resolver.dart';
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import 'character_stat_calculator.dart';
import 'dnd_5e_rules_engine.dart';

/// HP Progression Choice for a level up step (Fixed Average vs Rolled Die).
@immutable
class HpProgressionChoice {
  final bool useFixedAverage;
  final int? rolledValue;

  const HpProgressionChoice.average()
      : useFixedAverage = true,
        rolledValue = null;

  const HpProgressionChoice.rolled(int value)
      : useFixedAverage = false,
        rolledValue = value;
}

/// Ability Score Improvement (+2 / +1+1) or Feat Selection.
@immutable
class AsiOrFeatChoice {
  final Map<AbilityType, int> abilityIncreases;
  final EntityReference<DomainEntity>? featRef;

  const AsiOrFeatChoice.asi(this.abilityIncreases) : featRef = null;
  const AsiOrFeatChoice.feat(EntityReference<DomainEntity> feat)
      : featRef = feat,
        abilityIncreases = const {};

  bool get isFeat => featRef != null;
}

/// Complete parameter request for advancing a character level.
@immutable
class LevelUpRequest {
  final String targetClassSlug;
  final String? targetClassDisplayName;
  final String? targetClassHitDie; // e.g. "d8", "d10"
  final bool isMulticlass;
  final EntityReference<DomainEntity>? subclassRef;
  final HpProgressionChoice hpChoice;
  final AsiOrFeatChoice? asiOrFeat;
  final List<EntityReference<Spell>> newCantrips;
  final List<EntityReference<Spell>> newSpells;

  const LevelUpRequest({
    required this.targetClassSlug,
    this.targetClassDisplayName,
    this.targetClassHitDie,
    this.isMulticlass = false,
    this.subclassRef,
    this.hpChoice = const HpProgressionChoice.average(),
    this.asiOrFeat,
    this.newCantrips = const [],
    this.newSpells = const [],
  });
}

/// Validation result with diagnostic reason strings.
class LevelUpValidationResult {
  final bool isValid;
  final List<String> errors;

  const LevelUpValidationResult.valid()
      : isValid = true,
        errors = const [];

  const LevelUpValidationResult.invalid(this.errors) : isValid = false;
}

/// Pure Dart progression service providing 5e RAW / 2024 revised mechanics for leveling up.
class CharacterProgressionEngine {
  CharacterProgressionEngine._();

  /// Standard 5e Multiclass Prerequisites mapping class slug to required attribute threshold options.
  static Map<String, List<Map<AbilityType, int>>> getMulticlassPrerequisites() {
    return {
      'barbarian': [
        {AbilityType.strength: 13}
      ],
      'bard': [
        {AbilityType.charisma: 13}
      ],
      'cleric': [
        {AbilityType.wisdom: 13}
      ],
      'druid': [
        {AbilityType.wisdom: 13}
      ],
      'fighter': [
        {AbilityType.strength: 13},
        {AbilityType.dexterity: 13}, // STR or DEX 13
      ],
      'monk': [
        {AbilityType.dexterity: 13, AbilityType.wisdom: 13} // Both DEX and WIS 13
      ],
      'paladin': [
        {AbilityType.strength: 13, AbilityType.charisma: 13} // Both STR and CHA 13
      ],
      'ranger': [
        {AbilityType.dexterity: 13, AbilityType.wisdom: 13} // Both DEX and WIS 13
      ],
      'rogue': [
        {AbilityType.dexterity: 13}
      ],
      'sorcerer': [
        {AbilityType.charisma: 13}
      ],
      'warlock': [
        {AbilityType.charisma: 13}
      ],
      'wizard': [
        {AbilityType.intelligence: 13}
      ],
      'artificer': [
        {AbilityType.intelligence: 13}
      ],
    };
  }

  /// Default Hit Die for standard 5e classes.
  static String getDefaultHitDie(String classSlug) {
    switch (classSlug.toLowerCase()) {
      case 'barbarian':
        return 'd12';
      case 'fighter':
      case 'paladin':
      case 'ranger':
        return 'd10';
      case 'bard':
      case 'cleric':
      case 'druid':
      case 'monk':
      case 'rogue':
      case 'warlock':
      case 'artificer':
        return 'd8';
      case 'sorcerer':
      case 'wizard':
        return 'd6';
      default:
        return 'd8';
    }
  }

  /// Calculates average HP gain per level for a hit die (e.g., d6 -> 4, d8 -> 5, d10 -> 6, d12 -> 7).
  static int getAverageHpForHitDie(String hitDie) {
    final clean = hitDie.replaceAll('d', '').trim();
    final sides = int.tryParse(clean) ?? 8;
    return (sides / 2).floor() + 1;
  }

  /// Parses hit die sides integer.
  static int getHitDieSides(String hitDie) {
    final clean = hitDie.replaceAll('d', '').trim();
    return int.tryParse(clean) ?? 8;
  }

  /// Checks if reaching [newClassLevel] in [classSlug] triggers an Ability Score Improvement (ASI) milestone.
  static bool isAsiMilestone(String classSlug, int newClassLevel) {
    final slug = classSlug.toLowerCase();
    if (slug == 'fighter') {
      return [4, 6, 8, 12, 14, 16, 19].contains(newClassLevel);
    } else if (slug == 'rogue') {
      return [4, 8, 10, 12, 16, 19].contains(newClassLevel);
    } else {
      return [4, 8, 12, 16, 19].contains(newClassLevel);
    }
  }

  /// Checks if reaching [newClassLevel] in [classSlug] unlocks subclass selection.
  /// Standard 5e (and 2024 revision) unlocks subclass archetypes at Level 3.
  static bool isSubclassMilestone(String classSlug, int newClassLevel) {
    return newClassLevel == 3;
  }

  /// Checks if ability scores satisfy multiclass prerequisite requirement options.
  static bool _meetsPrereq(AbilityScores scores, List<Map<AbilityType, int>> prereqOptions) {
    for (final option in prereqOptions) {
      bool allPassed = true;
      option.forEach((ability, requiredScore) {
        if (scores.getScore(ability) < requiredScore) {
          allPassed = false;
        }
      });
      if (allPassed) return true;
    }
    return false;
  }

  /// Validates multiclass prerequisites for both existing classes (multiclassing OUT)
  /// and target class (multiclassing IN).
  static LevelUpValidationResult validateMulticlass(Character character, String targetClassSlug) {
    final errors = <String>[];
    final scores = character.baseScores.withBonus(character.bonusScores);
    final prereqs = getMulticlassPrerequisites();

    // 1. Max level ceiling check (20)
    if (character.totalLevel >= 20) {
      errors.add('Character has already reached the maximum total level (20).');
    }

    final isExisting = character.progression.classes.any(
      (c) => c.classRef.slug.toLowerCase() == targetClassSlug.toLowerCase(),
    );

    if (!isExisting) {
      // Multiclassing into a new class requires satisfying:
      // a) Current class prerequisites to multiclass OUT
      for (final existingClass in character.progression.classes) {
        final slug = existingClass.classRef.slug.toLowerCase();
        final currentPrereq = prereqs[slug];
        if (currentPrereq != null && !_meetsPrereq(scores, currentPrereq)) {
          errors.add('Cannot multiclass out of ${existingClass.classRef.displayName}: does not meet attribute prerequisite (13+ in primary stat).');
        }
      }

      // b) Target class prerequisites to multiclass IN
      final targetPrereq = prereqs[targetClassSlug.toLowerCase()];
      if (targetPrereq != null && !_meetsPrereq(scores, targetPrereq)) {
        errors.add('Cannot multiclass into $targetClassSlug: does not meet attribute prerequisite (13+ required).');
      }
    }

    if (errors.isNotEmpty) {
      return LevelUpValidationResult.invalid(errors);
    }
    return const LevelUpValidationResult.valid();
  }

  /// Pure function applying level-up progression to a [Character].
  static Character applyLevelUp(
    Character character,
    LevelUpRequest request, {
    ReferenceResolver? resolver,
  }) {
    final validation = validateMulticlass(character, request.targetClassSlug);
    if (!validation.isValid) {
      throw ArgumentError('Level up validation failed: ${validation.errors.join(', ')}');
    }

    // 1. Update Class Progression slices
    final updatedClasses = <ClassLevelProgression>[];
    bool classFound = false;
    String gainedHitDie = request.targetClassHitDie ?? getDefaultHitDie(request.targetClassSlug);

    for (final cls in character.progression.classes) {
      if (cls.classRef.slug.toLowerCase() == request.targetClassSlug.toLowerCase()) {
        classFound = true;
        gainedHitDie = cls.hitDie;
        final newLevel = cls.level + 1;
        final rolledHpList = List<int>.from(cls.hitPointsRolled);

        final avg = cls.averageHpPerLevel;
        final addedHp = request.hpChoice.useFixedAverage
            ? avg
            : (request.hpChoice.rolledValue ?? avg);
        rolledHpList.add(addedHp);

        updatedClasses.add(cls.copyWith(
          level: newLevel,
          subclassRef: request.subclassRef ?? cls.subclassRef,
          hitPointsRolled: rolledHpList,
        ));
      } else {
        updatedClasses.add(cls);
      }
    }

    if (!classFound) {
      // Initiating a new Multiclass slice
      final hitDie = request.targetClassHitDie ?? getDefaultHitDie(request.targetClassSlug);
      gainedHitDie = hitDie;
      final avg = getAverageHpForHitDie(hitDie);

      final addedHp = request.hpChoice.useFixedAverage
          ? avg
          : (request.hpChoice.rolledValue ?? avg);

      updatedClasses.add(ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: request.targetClassSlug,
          displayName: request.targetClassDisplayName ?? request.targetClassSlug.toUpperCase(),
        ),
        subclassRef: request.subclassRef,
        level: 1,
        hitDie: hitDie,
        hitPointsRolled: [addedHp],
        isStartingClass: false,
      ));
    }

    final newProgression = character.progression.copyWith(classes: updatedClasses);

    // 2. Apply ASI or Feat Choice
    var newBonusScores = character.bonusScores;
    final newFeats = List<EntityReference<DomainEntity>>.from(character.feats);

    if (request.asiOrFeat != null) {
      final choice = request.asiOrFeat!;
      if (choice.isFeat && choice.featRef != null) {
        newFeats.add(choice.featRef!);
      } else {
        choice.abilityIncreases.forEach((ability, bonus) {
          switch (ability) {
            case AbilityType.strength:
              newBonusScores = newBonusScores.copyWith(strength: newBonusScores.strength + bonus);
            case AbilityType.dexterity:
              newBonusScores = newBonusScores.copyWith(dexterity: newBonusScores.dexterity + bonus);
            case AbilityType.constitution:
              newBonusScores = newBonusScores.copyWith(constitution: newBonusScores.constitution + bonus);
            case AbilityType.intelligence:
              newBonusScores = newBonusScores.copyWith(intelligence: newBonusScores.intelligence + bonus);
            case AbilityType.wisdom:
              newBonusScores = newBonusScores.copyWith(wisdom: newBonusScores.wisdom + bonus);
            case AbilityType.charisma:
              newBonusScores = newBonusScores.copyWith(charisma: newBonusScores.charisma + bonus);
          }
        });
      }
    }

    // 3. Update Spells Known, Spells Prepared & Cantrips
    final existingCantripSlugs = character.cantrips.map((c) => c.slug).toSet();
    final updatedCantrips = List<EntityReference<Spell>>.from(character.cantrips);
    for (final c in request.newCantrips) {
      if (!existingCantripSlugs.contains(c.slug)) {
        updatedCantrips.add(c);
        existingCantripSlugs.add(c.slug);
      }
    }

    final existingKnownSlugs = character.spellsKnown.map((s) => s.slug).toSet();
    final updatedSpellsKnown = List<EntityReference<Spell>>.from(character.spellsKnown);
    for (final s in request.newSpells) {
      if (!existingKnownSlugs.contains(s.slug)) {
        updatedSpellsKnown.add(s);
        existingKnownSlugs.add(s.slug);
      }
    }

    final updatedSpellsPrepared = List<EntityReference<Spell>>.from(character.spellsPrepared);
    final existingPrepSlugs = character.spellsPrepared.map((s) => s.slug).toSet();
    for (final s in request.newSpells) {
      if (!existingPrepSlugs.contains(s.slug)) {
        updatedSpellsPrepared.add(s);
        existingPrepSlugs.add(s.slug);
      }
    }

    // 4. Update Hit Dice Resource Pool (increment pool for gained hit die)
    final updatedHitDice = Map<String, int>.from(character.resources.currentHitDice);
    updatedHitDice[gainedHitDie] = (updatedHitDice[gainedHitDie] ?? 0) + 1;

    // 5. Build candidate updated Character
    var candidate = character.copyWith(
      progression: newProgression,
      bonusScores: newBonusScores,
      feats: newFeats,
      cantrips: updatedCantrips,
      spellsKnown: updatedSpellsKnown,
      spellsPrepared: updatedSpellsPrepared,
      resources: character.resources.copyWith(
        currentHitDice: updatedHitDice,
      ),
    );

    // 6. Recalculate derived combat stats (HP, Spell Slots) using RAW calculation
    int newMaxHp = _computeMaxHp(candidate);
    final newSlotPool = computeSpellSlots(
      candidate.progression.classes,
      edition: candidate.rulesEdition,
    );

    // Preserve expended slot delta if possible, or initialize up to new max
    final currentSlotMap = Map<int, int>.from(character.resources.spellSlots.currentSlots);
    final maxSlotMap = Map<int, int>.from(newSlotPool.maxSlots);
    final mergedCurrentSlots = <int, int>{};

    maxSlotMap.forEach((level, maxCount) {
      final prevCur = currentSlotMap[level] ?? maxCount;
      mergedCurrentSlots[level] = math.min(prevCur, maxCount);
    });

    final updatedSlots = newSlotPool.copyWith(
      currentSlots: mergedCurrentSlots,
      pactMagicCurrent: math.min(character.resources.spellSlots.pactMagicCurrent, newSlotPool.pactMagicMax),
    );

    // If resolver is provided, use full CharacterStatCalculator
    if (resolver != null) {
      final computed = CharacterStatCalculator.compute(candidate, resolver);
      newMaxHp = computed.maxHp;
    }

    // Calculate HP increase to add to current HP (including retroactive CON scaling)
    final oldMaxHp = resolver != null
        ? CharacterStatCalculator.compute(character, resolver).maxHp
        : _computeMaxHp(character);
    final hpDelta = math.max(0, newMaxHp - oldMaxHp);
    final updatedCurrentHp = math.min(newMaxHp, character.resources.currentHp + hpDelta);

    return candidate.copyWith(
      resources: candidate.resources.copyWith(
        currentHp: updatedCurrentHp,
        spellSlots: updatedSlots,
      ),
    );
  }

  /// Internal max HP computation adhering strictly to 5e RAW rules:
  /// - Starting class gets full hit die sides + CON at Level 1.
  /// - Subsequent levels (and all multiclass levels) gain rolled/average hit die + CON (min 1 per level).
  /// - Retroactive CON modifier adjustments apply automatically across all levels.
  /// - Feats (like Tough) add +2 HP per total character level.
  static int _computeMaxHp(Character character) {
    int maxHp = 0;
    final totalCon = character.baseScores.constitution + character.bonusScores.constitution;
    final conMod = totalCon.dndModifier;

    for (int i = 0; i < character.progression.classes.length; i++) {
      final cls = character.progression.classes[i];
      if (cls.isStartingClass || i == 0) {
        // Starting class level 1 gets max hit die + CON
        maxHp += cls.hitDieSides + conMod;
        // Remaining levels of starting class
        for (int l = 1; l < cls.level; l++) {
          final rolledIndex = l - 1;
          final rolled = (rolledIndex < cls.hitPointsRolled.length)
              ? cls.hitPointsRolled[rolledIndex]
              : cls.averageHpPerLevel;
          maxHp += math.max(1, rolled + conMod);
        }
      } else {
        // Multiclass slices: all levels gain rolled/average + CON
        for (int l = 0; l < cls.level; l++) {
          final rolled = (l < cls.hitPointsRolled.length)
              ? cls.hitPointsRolled[l]
              : cls.averageHpPerLevel;
          maxHp += math.max(1, rolled + conMod);
        }
      }
    }

    // Tough Feat (+2 HP per level)
    for (final feat in character.feats) {
      if (feat.slug == 'tough' || feat.slug == 'toughness') {
        maxHp += character.totalLevel * 2;
      }
    }

    return math.max(1, maxHp);
  }

  /// Computes composite Multiclass and Pact Magic spell slots.
  static SpellSlotPool computeSpellSlots(
    List<ClassLevelProgression> classes, {
    DmRulesEdition edition = DmRulesEdition.v2014,
  }) {
    int fullCasterLevels = 0;
    int paladinLevels = 0;
    int rangerLevels = 0;
    int artificerLevels = 0;
    int thirdCasterLevels = 0;
    int warlockLevels = 0;

    for (final cls in classes) {
      final slug = cls.classRef.slug.toLowerCase();
      switch (slug) {
        case 'wizard':
        case 'cleric':
        case 'druid':
        case 'bard':
        case 'sorcerer':
          fullCasterLevels += cls.level;
        case 'paladin':
          paladinLevels += cls.level;
        case 'ranger':
          rangerLevels += cls.level;
        case 'artificer':
          artificerLevels += cls.level;
        case 'warlock':
          warlockLevels += cls.level;
      }

      // Check for third caster subclasses (Eldritch Knight, Arcane Trickster)
      final subSlug = cls.subclassRef?.slug.toLowerCase() ?? '';
      if (subSlug.contains('eldritch_knight') || subSlug.contains('arcane_trickster')) {
        thirdCasterLevels += cls.level;
      }
    }

    final ecl = MulticlassSlotMatrix.calculateEffectiveCasterLevel(
      fullCasterLevels: fullCasterLevels,
      paladinLevels: paladinLevels,
      rangerLevels: rangerLevels,
      artificerLevels: artificerLevels,
      thirdCasterLevels: thirdCasterLevels,
      edition: edition,
    );

    final Map<int, int> maxSlots = {};
    if (ecl > 0) {
      final slotList = MulticlassSlotMatrix.getSpellSlots(ecl);
      for (int i = 0; i < slotList.length; i++) {
        final slotLevel = i + 1;
        final count = slotList[i];
        if (count > 0) {
          maxSlots[slotLevel] = count;
        }
      }
    }

    // Add Pact Magic slots if Warlock levels exist
    int pactSlotLevel = 0;
    int pactCount = 0;
    if (warlockLevels > 0) {
      final pactPool = PactMagicPool.fromWarlockLevel(warlockLevels);
      pactSlotLevel = pactPool.slotLevel;
      pactCount = pactPool.totalSlots;
    }

    return SpellSlotPool(
      currentSlots: Map<int, int>.from(maxSlots),
      maxSlots: Map<int, int>.from(maxSlots),
      pactMagicSlotLevel: pactSlotLevel,
      pactMagicMax: pactCount,
      pactMagicCurrent: pactCount,
    );
  }
}
