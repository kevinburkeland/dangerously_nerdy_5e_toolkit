import 'package:flutter/material.dart';
import 'core_types.dart';
import 'character_models.dart' show AbilityType;

/// Categories of character combat actions
enum CombatActionCategory {
  weapon,
  spell,
  feature,
  magicItem,
  standard,
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
  final void Function(BuildContext context)? onRollAttack;
  final void Function(BuildContext context)? onRollDamage;
  final void Function(BuildContext context)? onExecute;

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
    this.onRollAttack,
    this.onRollDamage,
    this.onExecute,
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

  Color get actionTypeColor {
    switch (actionType) {
      case ActionType.action:
        return Colors.redAccent;
      case ActionType.bonusAction:
        return Colors.orangeAccent;
      case ActionType.reaction:
        return Colors.blueAccent;
      case ActionType.special:
      default:
        return Colors.purpleAccent;
    }
  }

  IconData get actionTypeIcon {
    switch (actionType) {
      case ActionType.action:
        return Icons.sports_martial_arts;
      case ActionType.bonusAction:
        return Icons.bolt;
      case ActionType.reaction:
        return Icons.flash_on;
      case ActionType.special:
      default:
        return Icons.stars;
    }
  }
}
