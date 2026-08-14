import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';

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
    final hasD20 = dicePool.any((e) => e.dieType == DieType.d20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. DIE SELECTOR CHIPS
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Die',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            if (dicePool.length > 1 ||
                dicePool.first.count > 1 ||
                dicePool.first.dieType != DieType.d20)
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                icon: const Icon(Icons.refresh,
                    size: 14, color: Colors.cyanAccent),
                label: const Text('Reset Pool',
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
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
              return ChoiceChip(
                label: Text(
                  die.label.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isInPool ? Colors.black : Colors.white,
                  ),
                ),
                selected: isInPool,
                selectedColor: Colors.cyanAccent,
                backgroundColor: const Color(0xFF28243D),
                onSelected: (selected) {
                  onSelectDie(die);
                },
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: Colors.cyanAccent),
              label: Text(
                'CUSTOM (d$customSides)',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
              backgroundColor: const Color(0xFF28243D),
              side: const BorderSide(color: Colors.cyanAccent),
              onPressed: onShowCustomDieDialog,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 2. ACTIVE DICE POOL & MODIFIER CONTROLS CARD
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DICE POOL & MODIFIERS',
                style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),

              // Dice Pool Entry Items
              ...dicePool.asMap().entries.map((entry) {
                final index = entry.key;
                final diceEntry = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.cyanAccent
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              diceEntry.dieLabel.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Quantity: ${diceEntry.count}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.cyanAccent),
                            onPressed: () {
                              final updatedPool = List<DiceEntry>.from(dicePool);
                              if (diceEntry.count > 1) {
                                updatedPool[index] = diceEntry.copyWith(
                                    count: diceEntry.count - 1);
                              } else {
                                if (updatedPool.length > 1) {
                                  updatedPool.removeAt(index);
                                }
                              }
                              onUpdateDicePool(updatedPool);
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${diceEntry.count}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.cyanAccent),
                            onPressed: () {
                              final updatedPool = List<DiceEntry>.from(dicePool);
                              if (diceEntry.count < 50) {
                                updatedPool[index] = diceEntry.copyWith(
                                    count: diceEntry.count + 1);
                                onUpdateDicePool(updatedPool);
                              }
                            },
                          ),
                          if (dicePool.length > 1)
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white38, size: 18),
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

              const Divider(color: Colors.white10, height: 24),

              // Modifier Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Modifier',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.orangeAccent),
                        onPressed: () => onUpdateModifier(modifier - 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          modifier >= 0 ? '+$modifier' : '$modifier',
                          style: TextStyle(
                            color: modifier > 0
                                ? Colors.greenAccent
                                : modifier < 0
                                    ? Colors.redAccent
                                    : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.orangeAccent),
                        onPressed: () => onUpdateModifier(modifier + 1),
                      ),
                      if (modifier != 0)
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: Colors.white38, size: 18),
                          onPressed: () => onUpdateModifier(0),
                          tooltip: 'Reset modifier',
                        ),
                    ],
                  ),
                ],
              ),

              // Advantage / Disadvantage for d20 roll pools
              if (hasD20) ...[
                const Divider(color: Colors.white10, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('d20 Advantage',
                        style: TextStyle(
                            color: Colors.white,
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
                            Colors.cyanAccent.withValues(alpha: 0.3),
                        selectedForegroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.white70,
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
