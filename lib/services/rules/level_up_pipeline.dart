import 'package:flutter/foundation.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../repository/reference_resolver.dart';
import 'character_stat_calculator.dart';

/// HP Progression Strategy for a level up step
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

/// Ability Score Improvement (+2 / +1+1) or Feat Selection
@immutable
class AsiOrFeatChoice {
  final Map<AbilityType, int> abilityIncreases; // e.g. {strength: 2} or {dexterity: 1, constitution: 1}
  final EntityReference<DomainEntity>? featRef;

  const AsiOrFeatChoice.asi(this.abilityIncreases) : featRef = null;
  const AsiOrFeatChoice.feat(EntityReference<DomainEntity> feat)
      : featRef = feat,
        abilityIncreases = const {};

  bool get isFeat => featRef != null;
}

/// Complete parameter request for advancing a character level
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

/// Validation result with diagnostic reasons
class LevelUpValidationResult {
  final bool isValid;
  final List<String> errors;

  const LevelUpValidationResult.valid()
      : isValid = true,
        errors = const [];

  const LevelUpValidationResult.invalid(this.errors) : isValid = false;
}

/// Level-Up and Multiclassing Prerequisite Engine
class LevelUpPipeline {
  /// Standard 5e Multiclass Prerequisites
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

  /// Checks if scores satisfy prerequisite requirements
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

  /// Validates multiclass prerequisites (for both existing classes and the new target class)
  static LevelUpValidationResult validateMulticlass(Character character, String targetClassSlug) {
    final errors = <String>[];
    final scores = character.baseScores.withBonus(character.bonusScores);
    final prereqs = getMulticlassPrerequisites();

    // 1. Max level ceiling check
    if (character.totalLevel >= 20) {
      errors.add('Character has reached maximum level (20).');
    }

    final isExisting = character.progression.classes.any((c) => c.classRef.slug == targetClassSlug);
    if (!isExisting) {
      // Multiclassing into a new class requires satisfying:
      // a) Current class prerequisites to multiclass OUT
      for (final existingClass in character.progression.classes) {
        final slug = existingClass.classRef.slug.toLowerCase();
        final currentPrereq = prereqs[slug];
        if (currentPrereq != null && !_meetsPrereq(scores, currentPrereq)) {
          errors.add('Cannot multiclass out of $slug: does not meet attribute prerequisite.');
        }
      }

      // b) Target class prerequisites to multiclass IN
      final targetPrereq = prereqs[targetClassSlug.toLowerCase()];
      if (targetPrereq != null && !_meetsPrereq(scores, targetPrereq)) {
        errors.add('Cannot multiclass into $targetClassSlug: does not meet attribute prerequisite.');
      }
    }

    if (errors.isNotEmpty) {
      return LevelUpValidationResult.invalid(errors);
    }
    return const LevelUpValidationResult.valid();
  }

  /// Pure function applying level up to a Character
  static Character applyLevelUp(
    Character character,
    LevelUpRequest request, {
    ReferenceResolver? resolver,
  }) {
    final validation = validateMulticlass(character, request.targetClassSlug);
    if (!validation.isValid) {
      throw ArgumentError('Level up validation failed: ${validation.errors.join(', ')}');
    }

    // 1. Update Class Progression
    final updatedClasses = <ClassLevelProgression>[];
    bool classFound = false;

    for (final cls in character.progression.classes) {
      if (cls.classRef.slug == request.targetClassSlug) {
        classFound = true;
        final newLevel = cls.level + 1;
        final rolledHpList = List<int>.from(cls.hitPointsRolled);

        final addedHp = request.hpChoice.useFixedAverage
            ? cls.averageHpPerLevel
            : (request.hpChoice.rolledValue ?? cls.averageHpPerLevel);
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
      // New Multiclass slice
      final hitDie = request.targetClassHitDie ?? 'd8';
      final clean = hitDie.replaceAll('d', '').trim();
      final sides = int.tryParse(clean) ?? 8;
      final avg = (sides / 2).floor() + 1;

      final addedHp = request.hpChoice.useFixedAverage
          ? avg
          : (request.hpChoice.rolledValue ?? avg);

      updatedClasses.add(ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: request.targetClassSlug,
          displayName: request.targetClassDisplayName ?? request.targetClassSlug,
        ),
        subclassRef: request.subclassRef,
        level: 1,
        hitDie: hitDie,
        hitPointsRolled: [addedHp],
        isStartingClass: false,
      ));
    }

    final newProgression = character.progression.copyWith(classes: updatedClasses);

    // 2. Apply ASI or Feat
    var newBonusScores = character.bonusScores;
    final newFeats = List<EntityReference<DomainEntity>>.from(character.feats);

    if (request.asiOrFeat != null) {
      final choice = request.asiOrFeat!;
      if (choice.isFeat) {
        newFeats.add(choice.featRef!);
      } else {
        choice.abilityIncreases.forEach((ability, bonus) {
          switch (ability) {
            case AbilityType.strength:
              newBonusScores = newBonusScores.copyWith(strength: newBonusScores.strength + bonus);
              break;
            case AbilityType.dexterity:
              newBonusScores = newBonusScores.copyWith(dexterity: newBonusScores.dexterity + bonus);
              break;
            case AbilityType.constitution:
              newBonusScores = newBonusScores.copyWith(constitution: newBonusScores.constitution + bonus);
              break;
            case AbilityType.intelligence:
              newBonusScores = newBonusScores.copyWith(intelligence: newBonusScores.intelligence + bonus);
              break;
            case AbilityType.wisdom:
              newBonusScores = newBonusScores.copyWith(wisdom: newBonusScores.wisdom + bonus);
              break;
            case AbilityType.charisma:
              newBonusScores = newBonusScores.copyWith(charisma: newBonusScores.charisma + bonus);
              break;
          }
        });
      }
    }

    // 3. Update Spells Known / Cantrips
    final updatedCantrips = List<EntityReference<Spell>>.from(character.cantrips)..addAll(request.newCantrips);
    final updatedSpellsKnown = List<EntityReference<Spell>>.from(character.spellsKnown)..addAll(request.newSpells);

    // 4. Update Hit Dice Resource Pools
    final updatedHitDice = Map<String, int>.from(character.resources.currentHitDice);
    final gainedHitDie = classFound
        ? character.progression.classes.firstWhere((c) => c.classRef.slug == request.targetClassSlug).hitDie
        : (request.targetClassHitDie ?? 'd8');
    updatedHitDice[gainedHitDie] = (updatedHitDice[gainedHitDie] ?? 0) + 1;

    var updatedCharacter = character.copyWith(
      progression: newProgression,
      bonusScores: newBonusScores,
      feats: newFeats,
      cantrips: updatedCantrips,
      spellsKnown: updatedSpellsKnown,
      resources: character.resources.copyWith(
        currentHitDice: updatedHitDice,
      ),
    );

    // 5. Update Current HP if resolver is provided or calculate directly
    if (resolver != null) {
      final computed = CharacterStatCalculator.compute(updatedCharacter, resolver);
      updatedCharacter = updatedCharacter.copyWith(
        resources: updatedCharacter.resources.copyWith(
          currentHp: computed.maxHp,
          spellSlots: computed.computedSpellSlots,
        ),
      );
    }

    return updatedCharacter;
  }
}
