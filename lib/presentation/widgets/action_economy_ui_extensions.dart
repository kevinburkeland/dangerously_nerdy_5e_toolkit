import 'package:flutter/material.dart';
import '../../models/domain/action_economy_models.dart';
import '../../models/domain/core_types.dart';

extension CharacterCombatActionUiExtension on CharacterCombatAction {
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
