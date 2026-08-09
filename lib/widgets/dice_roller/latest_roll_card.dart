import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';

class LatestRollCard extends StatelessWidget {
  final DiceRollResult? latestResult;

  const LatestRollCard({
    super.key,
    required this.latestResult,
  });

  @override
  Widget build(BuildContext context) {
    if (latestResult == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 8),
            Text('Tap ROLL to roll the dice!',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      );
    }

    final res = latestResult!;

    Color borderColor = Colors.cyanAccent.withValues(alpha: 0.5);
    Color totalColor = Colors.cyanAccent;
    String badgeText = '';

    if (res.isCrit) {
      borderColor = Colors.amber;
      totalColor = Colors.amber;
      badgeText = 'CRITICAL HIT!';
    } else if (res.isFumble) {
      borderColor = Colors.redAccent;
      totalColor = Colors.redAccent;
      badgeText = 'NATURAL 1!';
    }

    final semanticsSummary = 'Latest Roll Result: ${res.total}. Formula: ${res.formulaString}. ${badgeText.isNotEmpty ? badgeText : ''}';

    return Semantics(
      label: semanticsSummary,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      res.formulaString,
                      style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (badgeText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: res.isCrit ? Colors.amber : Colors.redAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 12),

          // Total Number Display
          Text(
            '${res.total}',
            style: TextStyle(
              color: totalColor,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Breakdown per Die Group
          ...res.groupResults.map((group) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${group.entry.dieLabel.toUpperCase()}: ',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: group.rolls.map((val) {
                      bool isMax =
                          group.entry.dieType == DieType.d20 && val == 20;
                      bool isMin =
                          group.entry.dieType == DieType.d20 && val == 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMax
                              ? Colors.amber.withValues(alpha: 0.3)
                              : isMin
                                  ? Colors.redAccent.withValues(alpha: 0.3)
                                  : Colors.black38,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isMax
                                ? Colors.amber
                                : isMin
                                    ? Colors.redAccent
                                    : Colors.white24,
                          ),
                        ),
                        child: Text(
                          '$val',
                          style: TextStyle(
                            color: isMax
                                ? Colors.amber
                                : isMin
                                    ? Colors.redAccent
                                    : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),

          if (res.droppedRolls != null && res.droppedRolls!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 4,
                children: res.droppedRolls!.map((val) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '$val (dropped)',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          if (res.modifier != 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Modifier: ${res.modifier > 0 ? "+${res.modifier}" : "${res.modifier}"}',
                style: TextStyle(
                  color:
                      res.modifier > 0 ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}
