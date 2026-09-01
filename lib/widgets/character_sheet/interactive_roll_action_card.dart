import 'package:flutter/material.dart';
import '../../models/room_roll.dart';
import '../../services/dice_room_service.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/character_stat_calculator.dart';
import '../../services/rules/spellcasting_rules_engine.dart';
import '../../theme/app_theme.dart';
import '../../utils/secure_random.dart';

/// Interactive Action Card supporting tap-to-roll for To-Hit attacks, damage formulas, and dice room dispatch.
class InteractiveRollActionCard extends StatelessWidget {
  final ComputedAttackProfile attack;
  final String characterName;

  const InteractiveRollActionCard({
    super.key,
    required this.attack,
    required this.characterName,
  });

  void _dispatchRoll(BuildContext context, {required bool isDamage, required String label, required String formula}) {
    HapticService.lightImpact(context);

    final cleanFormula = formula.replaceAll(' ', '');
    final rollResult = SpellRollEngine.roll(formula: cleanFormula);

    final roomService = DiceRoomService();
    final activeRoom = roomService.activeRoomCode;

    if (activeRoom != null) {
      final roomRoll = RoomRoll(
        id: 'roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
        roomCode: activeRoom,
        playerName: characterName.isNotEmpty ? characterName : 'Player',
        formulaString: formula,
        total: rollResult.total,
        individualRolls: rollResult.individualDice,
        details: ['${attack.weaponName} ($label)'],
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
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        content: Row(
          children: [
            Icon(
              isDamage ? Icons.local_fire_department : Icons.sports_martial_arts,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '[$characterName] ${attack.weaponName} $label: ${rollResult.total} (${rollResult.formulaDescription})',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rollAttack(BuildContext context) {
    final bonus = attack.attackBonus;
    final bonusStr = bonus >= 0 ? '+$bonus' : '$bonus';
    _dispatchRoll(context, isDamage: false, label: 'Attack Roll', formula: '1d20$bonusStr');
  }

  void _rollDamage(BuildContext context) {
    _dispatchRoll(context, isDamage: true, label: '${attack.damageType.name.toUpperCase()} Damage', formula: attack.damageFormula);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        attack.weaponName,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (attack.activeMastery != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          attack.activeMastery!.displayName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${attack.range} • ${attack.damageType.name}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // To-Hit Roll Button
              Semantics(
                button: true,
                label: 'Roll ${attack.weaponName} Attack ${attack.attackBonusString}',
                child: InkWell(
                  onTap: () => _rollAttack(context),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.casino_outlined, size: 14, color: theme.colorScheme.onPrimaryContainer),
                          const SizedBox(width: 4),
                          Text(
                            attack.attackBonusString,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Damage Roll Button
              Semantics(
                button: true,
                label: 'Roll ${attack.weaponName} Damage ${attack.damageFormula}',
                child: InkWell(
                  onTap: () => _rollDamage(context),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department_outlined, size: 14, color: customColors?.critGold ?? Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            attack.damageFormula,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: customColors?.critGold ?? Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
