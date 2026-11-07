import 'core_types.dart';

/// Categories of character combat actions
enum CombatActionCategory {
  weapon,
  spell,
  feature,
  magicItem,
  standard,
}

final class ActionRoll {
  final String label;
  final String formula;
  const ActionRoll({required this.label, required this.formula});
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionRoll &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          formula == other.formula;
  @override
  int get hashCode => Object.hash(label, formula);
}

sealed class ActionUse {
  const ActionUse();
}

final class RollOnUse extends ActionUse {
  final ActionRoll roll;
  const RollOnUse(this.roll);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RollOnUse &&
          runtimeType == other.runtimeType &&
          roll == other.roll;
  @override
  int get hashCode => roll.hashCode;
}

final class RestorePactSlotOnUse extends ActionUse {
  const RestorePactSlotOnUse();
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestorePactSlotOnUse &&
          runtimeType == other.runtimeType;
  @override
  int get hashCode => runtimeType.hashCode;
}

/// Rich, interactive representation of a combat action available to a character.
class CharacterCombatAction {
  final String id;
  final String name;
  final ActionType actionType;
  final CombatActionCategory category;
  final String subtitle;
  final String description;
  final String? trigger;
  final String? range;
  final int? toHitBonus;
  final String? damageFormula;
  final DamageType? damageType;
  final int? saveDc;
  final AbilityType? saveAbility;
  final String? resourceCost;
  final bool isAttack;
  final bool dealsDamage;
  final ActionRoll? attackRoll;
  final ActionRoll? damageRoll;
  final ActionUse? use;

  const CharacterCombatAction({
    required this.id,
    required this.name,
    required this.actionType,
    required this.category,
    required this.subtitle,
    required this.description,
    this.trigger,
    this.range,
    this.toHitBonus,
    this.damageFormula,
    this.damageType,
    this.saveDc,
    this.saveAbility,
    this.resourceCost,
    this.isAttack = false,
    this.dealsDamage = false,
    this.attackRoll,
    this.damageRoll,
    this.use,
  });

  String get actionTypeLabel {
    switch (actionType) {
      case ActionType.action:
        return 'Action';
      case ActionType.bonusAction:
        return 'Bonus Action';
      case ActionType.reaction:
        return 'Reaction';
      case ActionType.minute:
        return '1 Minute';
      case ActionType.hour:
        return '1 Hour';
      case ActionType.special:
        return 'Special';
    }
  }

}
