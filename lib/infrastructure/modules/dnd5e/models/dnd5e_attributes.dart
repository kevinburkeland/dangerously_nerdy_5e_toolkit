import 'package:vtt_engine_core/models/generic_tabletop_primitives.dart';
import 'package:vtt_engine_core/models/character_models.dart';
import '../../../../models/domain/feature_grant.dart';
import '../dnd5e_ruleset_module.dart';

export 'package:vtt_engine_core/models/character_models.dart'
    show AbilityType, SkillType, SkillProficiencyLevel;

/// 5e Extension on [AttributePool] providing named getters for the 6 canonical abilities.
extension Dnd5eAttributePoolExtension on AttributePool {
  int get strength => getScore('strength');
  int get dexterity => getScore('dexterity');
  int get constitution => getScore('constitution');
  int get intelligence => getScore('intelligence');
  int get wisdom => getScore('wisdom');
  int get charisma => getScore('charisma');

  int getScoreByAbility(AbilityType ability) => getScore(ability.name);
  int getModifierByAbility(AbilityType ability, [IAttributeSystem? system]) =>
      getModifier(ability.name, system);
}

/// 5e Extension on [Character] providing convenience bridges to 5e proficiency models.
extension Dnd5eCharacterExtension on Character {
  int get armorClass => Dnd5eRulesetModule.calculateCharacterArmorClass(this);
  int get initiativeBonus =>
      Dnd5eRulesetModule.calculateCharacterInitiativeBonus(this);
  int get passivePerception =>
      Dnd5eRulesetModule.calculatePassivePerception(this);
  int get passiveInsight => Dnd5eRulesetModule.calculatePassiveInsight(this);
  int get passiveInvestigation =>
      Dnd5eRulesetModule.calculatePassiveInvestigation(this);

  AbilityType getEffectiveAttackAbility(
    InventoryItemInstance weapon, {
    AttributePool? scores,
    List<FeatureGrant>? additionalGrants,
  }) {
    return Dnd5eRulesetModule.resolveEffectiveAttackAbility(
      scores: scores ?? effectiveAbilityScores,
      weapon: weapon,
      character: this,
      additionalGrants: additionalGrants,
    );
  }

  Map<SkillType, SkillProficiencyLevel> get skillProficiencies {
    final result = <SkillType, SkillProficiencyLevel>{};
    for (final s in SkillType.values) {
      final mult = getTraitProficiency(s.name);
      if (mult > 0) {
        result[s] = SkillProficiencyLevel.fromMultiplier(mult);
      }
    }
    return result;
  }

  Set<AbilityType> get savingThrowAbilityTypes {
    return savingThrowProficiencies
        .map((k) => AbilityType.fromLooseString(k))
        .toSet();
  }

  /// Calculates dynamic skill modifier factoring ability score and proficiency multiplier.
  int getSkillModifier(dynamic skill, [IAttributeSystem? system]) {
    final skillType = skill is SkillType
        ? skill
        : SkillType.fromLooseString(skill.toString());
    final baseMod = getAttributeModifier(skillType.defaultAbility.name, system);
    final mult = getTraitProficiency(skillType.name);
    int bonus = (proficiencyBonus * mult).floor();
    if (mult == 0 && hasCapabilityFlag('jackOfAllTrades')) {
      bonus = (proficiencyBonus * 0.5).floor();
    }
    return baseMod + bonus;
  }
}
