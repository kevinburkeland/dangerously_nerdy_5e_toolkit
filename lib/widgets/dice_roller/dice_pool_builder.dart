import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../theme/app_theme.dart';

class DicePoolBuilder extends StatelessWidget {
  final List<DiceEntry> dicePool;
  final int modifier;
  final RollMode rollMode;
  final int customSides;
  final Function(DieType die, {int customSides}) onSelectDie;
  final VoidCallback onShowCustomDieDialog;
  final VoidCallback onResetPool;
  final ValueChanged<List<DiceEntry>> onUpdateDicePool;
  final ValueChanged<int> onUpdateModifier;
  final ValueChanged<RollMode> onUpdateRollMode;

  const DicePoolBuilder({
    super.key,
    required this.dicePool,
    required this.modifier,
    required this.rollMode,
    required this.customSides,
    required this.onSelectDie,
    required this.onShowCustomDieDialog,
    required this.onResetPool,
    required this.onUpdateDicePool,
    required this.onUpdateModifier,
    required this.onUpdateRollMode,
  });

  @override
  Widget build(BuildContext context) {
    final isDefaultPool = dicePool.length == 1 &&
        dicePool.first.dieType == DieType.d20 &&
        dicePool.first.count == 1 &&
        dicePool.first.customSides == 6 &&
        modifier == 0 &&
        rollMode == RollMode.normal;
    final hasD20 = dicePool.any((e) => e.dieType == DieType.d20);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final tabletop = theme.extension<TabletopColors>() ?? (isDark ? TabletopColors.dark : TabletopColors.light);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. DIE SELECTOR CHIPS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Select Die',
                style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            if (!isDefaultPool)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                icon: Icon(Icons.refresh,
                    size: 14, color: primary),
                label: Text('Reset Pool',
                    style: TextStyle(color: primary, fontSize: 12)),
                onPressed: onResetPool,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...DieType.values.where((d) => d != DieType.custom).map((die) {
              final isInPool = dicePool.any((e) => e.dieType == die);
              return Semantics(
                button: true,
                selected: isInPool,
                label: 'Add ${die.label} to dice pool',
                child: ChoiceChip(
                  label: Text(
                    die.label.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isInPool ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    ),
                  ),
                  selected: isInPool,
                  selectedColor: primary,
                  backgroundColor: tabletop.cardBackground,
                  onSelected: (selected) {
                    onSelectDie(die);
                  },
                ),
              );
            }),
            Semantics(
              button: true,
              label: 'Configure custom d$customSides die',
              child: ActionChip(
                avatar: Icon(Icons.add, size: 16, color: primary),
                label: Text(
                  'CUSTOM (d$customSides)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: primary),
                ),
                backgroundColor: tabletop.cardBackground,
                side: BorderSide(color: primary),
                onPressed: onShowCustomDieDialog,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 2. ACTIVE DICE POOL & MODIFIER CONTROLS CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tabletop.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tabletop.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'DICE POOL & MODIFIERS',
                  style: TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8),
                ),
              ),
              const SizedBox(height: 12),

              // Dice Pool Entry Items
              if (dicePool.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      'Dice pool is empty. Select a die above to add.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ...dicePool.asMap().entries.map((entry) {
                  final index = entry.key;
                  final diceEntry = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: primary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                diceEntry.dieLabel.toUpperCase(),
                                style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Quantity: ${diceEntry.count}',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: primary),
                              tooltip: 'Decrease quantity of ${diceEntry.dieLabel}',
                              onPressed: () {
                                final updatedPool = List<DiceEntry>.from(dicePool);
                                if (diceEntry.count > 1) {
                                  updatedPool[index] = diceEntry.copyWith(
                                      count: diceEntry.count - 1);
                                } else {
                                  updatedPool.removeAt(index);
                                }
                                onUpdateDicePool(updatedPool);
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black38 : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${diceEntry.count}',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline,
                                  color: primary),
                              tooltip: 'Increase quantity of ${diceEntry.dieLabel}',
                              onPressed: () {
                                final updatedPool = List<DiceEntry>.from(dicePool);
                                if (diceEntry.count < 50) {
                                  updatedPool[index] = diceEntry.copyWith(
                                      count: diceEntry.count + 1);
                                  onUpdateDicePool(updatedPool);
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: theme.colorScheme.onSurfaceVariant, size: 18),
                              tooltip: 'Remove ${diceEntry.dieLabel} from pool',
                              onPressed: () {
                                final updatedPool = List<DiceEntry>.from(dicePool);
                                updatedPool.removeAt(index);
                                onUpdateDicePool(updatedPool);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

              Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), height: 24),

              // Modifier Selector
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('Total Modifier',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: isDark ? Colors.orangeAccent : const Color(0xFFC2410C)),
                        tooltip: 'Decrease modifier by 1',
                        onPressed: () => onUpdateModifier(modifier - 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black38 : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          modifier >= 0 ? '+$modifier' : '$modifier',
                          style: TextStyle(
                            color: modifier > 0
                                ? tabletop.hitGreen
                                : modifier < 0
                                    ? tabletop.fumbleRed
                                    : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline,
                            color: isDark ? Colors.orangeAccent : const Color(0xFFC2410C)),
                        tooltip: 'Increase modifier by 1',
                        onPressed: () => onUpdateModifier(modifier + 1),
                      ),
                      if (modifier != 0)
                        IconButton(
                          icon: Icon(Icons.refresh,
                              color: theme.colorScheme.onSurfaceVariant, size: 18),
                          onPressed: () => onUpdateModifier(0),
                          tooltip: 'Reset modifier to 0',
                        ),
                    ],
                  ),
                ],
              ),

              // Advantage / Disadvantage for d20 roll pools
              if (hasD20) ...[
                Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), height: 24),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text('d20 Advantage',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    SegmentedButton<RollMode>(
                      segments: const [
                        ButtonSegment(
                            value: RollMode.disadvantage,
                            label: Text('Dis')),
                        ButtonSegment(
                            value: RollMode.normal, label: Text('Norm')),
                        ButtonSegment(
                            value: RollMode.advantage, label: Text('Adv')),
                      ],
                      selected: {rollMode},
                      onSelectionChanged: (newSelection) {
                        onUpdateRollMode(newSelection.first);
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor:
                            primary.withValues(alpha: 0.2),
                        selectedForegroundColor: primary,
                        foregroundColor: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
