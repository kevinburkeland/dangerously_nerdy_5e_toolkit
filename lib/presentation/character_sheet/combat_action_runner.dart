import 'package:material_ui/material_ui.dart';

import '../../models/domain/action_economy_models.dart';
import '../../models/domain/character_models.dart';
import '../../models/room_roll.dart';
import '../../models/spellbook_data.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/dice_room_service.dart';
import '../../services/haptic_service.dart';
import '../../utils/secure_random.dart';

/// Runs a combat action dice roll from the character sheet UI.
void runActionRoll(
  BuildContext context,
  ActionRoll roll, {
  required Character character,
}) {
  HapticService.lightImpact(context);
  final cleanFormula = roll.formula.replaceAll(' ', '');
  final rollResult = SpellRollEngine.roll(formula: cleanFormula);
  if (rollResult == null) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text('Can\'t roll "${roll.formula}": not dice notation'),
      ),
    );
    return;
  }

  final roomService = DiceRoomService();
  final activeRoom = roomService.activeRoomCode;
  if (activeRoom != null) {
    final roomRoll = RoomRoll(
      id: 'roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
      roomCode: activeRoom,
      playerName: character.name.isNotEmpty ? character.name : 'Player',
      formulaString: roll.formula,
      total: rollResult.total,
      individualRolls: rollResult.individualDice,
      details: [roll.label],
      isCrit: rollResult.individualDice.contains(20),
      isFumble: rollResult.individualDice.contains(1),
      timestamp: DateTime.now(),
    );
    roomService.broadcastRoll(roomRoll);
  }

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      content: Text(
        '${character.name} ${roll.label}: ${rollResult.total} (${rollResult.formulaDescription})',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );
}

/// Runs a combat action use trigger (roll or pact slot restoration) from the UI.
void runActionUse(
  BuildContext context,
  ActionUse use, {
  required Character character,
  required CharacterSheetController controller,
}) {
  switch (use) {
    case RollOnUse(:final roll):
      runActionRoll(context, roll, character: character);
    case RestorePactSlotOnUse():
      HapticService.heavyImpact(context);
      final pool = controller.character.resources.spellSlots;
      if (pool.pactMagicMax > 0 &&
          pool.pactMagicCurrent < pool.pactMagicMax) {
        controller.togglePactSlot(false); // restores 1 pact slot
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Rod of the Pact Keeper: Restored 1 Warlock spell slot!'),
            backgroundColor: Colors.purple,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pact Magic slots are already full!'),
          ),
        );
      }
  }
}
