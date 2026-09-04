import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../models/domain/character_models.dart';
import '../../models/room_roll.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/a11y_service.dart';
import '../../services/dice_room_service.dart';
import '../../services/haptic_service.dart';
import '../../utils/secure_random.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';

/// Interactive modal bottom sheet allowing players to spend hit dice during a Short Rest,
/// roll dice with Constitution modifier, restore Pact Magic slots, and update character vitals.
class ShortRestDialog extends StatefulWidget {
  final CharacterSheetController controller;

  const ShortRestDialog({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, {required CharacterSheetController controller}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShortRestDialog(controller: controller),
    );
  }

  @override
  State<ShortRestDialog> createState() => _ShortRestDialogState();
}

class _ShortRestDialogState extends State<ShortRestDialog> {
  final Map<String, int> _spentDice = {};
  bool _isRolling = false;

  @override
  void initState() {
    super.initState();
    for (final c in widget.controller.character.progression.classes) {
      _spentDice.putIfAbsent(c.hitDie, () => 0);
    }
  }

  int _calculateEstimatedHealing(int conMod) {
    int total = 0;
    for (final entry in _spentDice.entries) {
      final dieSize = int.tryParse(entry.key.replaceAll('d', '')) ?? 8;
      final avgRoll = (dieSize / 2 + 0.5).round();
      total += entry.value * math.max(1, avgRoll + conMod);
    }
    return total;
  }

  int get _totalDiceSelected => _spentDice.values.fold(0, (sum, count) => sum + count);

  void _executeShortRest() {
    if (_totalDiceSelected == 0) {
      // Short rest without spending hit dice (e.g. to regain pact slots)
      widget.controller.applyShortRest(
        hitDiceSpent: {},
        healingRolled: 0,
      );
      A11yService.announce('Short rest completed. Pact Magic slots restored.');
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Short rest completed (Pact Magic slots restored).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isRolling = true);
    HapticService.heavyImpact(context);

    final character = widget.controller.character;
    final conMod = character.effectiveAbilityScores.getModifier(AbilityType.constitution);

    final entries = <DiceEntry>[];
    for (final entry in _spentDice.entries) {
      if (entry.value <= 0) continue;
      final dieTypeStr = entry.key;
      final dieSides = int.tryParse(dieTypeStr.replaceAll('d', '')) ?? 8;
      final dieType = DieType.values.firstWhere(
        (d) => d.sides == dieSides && d != DieType.custom,
        orElse: () => DieType.custom,
      );
      entries.add(DiceEntry(
        dieType: dieType,
        count: entry.value,
        customSides: dieSides,
      ));
    }

    final totalMod = conMod * _totalDiceSelected;
    final rollResult = DiceRollResult.rollPool(
      diceEntries: entries,
      modifier: totalMod,
    );

    // Each hit die recovery is clamped at minimum 1 overall
    final totalHealing = math.max(1, rollResult.total);

    // Format individual breakdown details
    final individualRollStrings = <String>[];
    for (final group in rollResult.groupResults) {
      for (final roll in group.rolls) {
        final healFromDie = math.max(1, roll + conMod);
        individualRollStrings.add('${group.entry.dieLabel}($roll) + $conMod = $healFromDie');
      }
    }

    // Broadcast roll to dice room if active
    final roomService = DiceRoomService();
    final activeRoom = roomService.activeRoomCode;
    final characterName = character.name.isNotEmpty ? character.name : 'Player';

    if (activeRoom != null) {
      final roomRoll = RoomRoll(
        id: 'roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
        roomCode: activeRoom,
        playerName: characterName,
        formulaString: 'Short Rest Hit Dice (${rollResult.formulaString})',
        total: totalHealing,
        individualRolls: rollResult.individualRolls,
        details: individualRollStrings,
        isCrit: false,
        isFumble: false,
        timestamp: DateTime.now(),
      );
      roomService.broadcastRoll(roomRoll);
    }

    // Apply Short Rest to controller
    widget.controller.applyShortRest(
      hitDiceSpent: _spentDice,
      healingRolled: totalHealing,
    );

    A11yService.announce('Short rest completed. Recovered $totalHealing hit points.');

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Short rest finished! Spent $_totalDiceSelected Hit Dice, recovered $totalHealing HP.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = widget.controller.character;
    final conMod = character.effectiveAbilityScores.getModifier(AbilityType.constitution);
    final conModStr = conMod >= 0 ? '+$conMod' : '$conMod';

    // Map of available dice
    final availableDiceMap = <String, int>{};
    for (final c in character.progression.classes) {
      final current = character.resources.currentHitDice[c.hitDie] ?? c.level;
      availableDiceMap[c.hitDie] = current;
    }

    final totalHealEstimate = _calculateEstimatedHealing(conMod);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bottom sheet drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.coffee_outlined, color: Colors.amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Short Rest',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close dialog',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Spend available Hit Dice to recover HP. Each die adds your Constitution modifier ($conModStr). Pact Magic slots will also be restored.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SELECT HIT DICE TO SPEND',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              ...character.progression.classes.map((c) {
                final die = c.hitDie;
                final maxAvailable = availableDiceMap[die] ?? c.level;
                final spent = _spentDice[die] ?? 0;
                final remaining = maxAvailable - spent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: spent > 0 ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                      width: spent > 0 ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (GenericUiGlyphType.fromDie(die) != null) ...[
                            DndGlyph.genericUi(
                              uiType: GenericUiGlyphType.fromDie(die)!,
                              size: 32,
                              isDarkMode: theme.brightness == Brightness.dark,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Die: $die',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$conModStr CON',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$remaining of $maxAvailable available',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Semantics(
                            button: true,
                            label: 'Decrease $die Hit Dice spent',
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: spent > 0 ? theme.colorScheme.primary : theme.disabledColor,
                                onPressed: spent > 0
                                    ? () {
                                        HapticService.selectionTick(context);
                                        setState(() {
                                          _spentDice[die] = spent - 1;
                                        });
                                      }
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '$spent',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: spent > 0 ? theme.colorScheme.primary : null,
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Increase $die Hit Dice spent',
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              child: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: spent < maxAvailable ? theme.colorScheme.primary : theme.disabledColor,
                                onPressed: spent < maxAvailable
                                    ? () {
                                        HapticService.selectionTick(context);
                                        setState(() {
                                          _spentDice[die] = spent + 1;
                                        });
                                      }
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _totalDiceSelected > 0
                            ? 'Estimated Recovery: ~$totalHealEstimate HP ($_totalDiceSelected dice with $conModStr CON per die)'
                            : 'No dice selected. Rest will only recharge Pact Magic slots.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Modal actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                      icon: _isRolling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.casino_outlined, size: 18),
                      label: Text(_totalDiceSelected > 0 ? 'Roll & Heal' : 'Complete Rest'),
                      onPressed: _isRolling ? null : _executeShortRest,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
