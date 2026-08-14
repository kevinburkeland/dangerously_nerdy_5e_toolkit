import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/dice_roll.dart';
import '../../theme/app_theme.dart';

class LatestRollCard extends StatefulWidget {
  final DiceRollResult? latestResult;

  const LatestRollCard({
    super.key,
    required this.latestResult,
  });

  @override
  State<LatestRollCard> createState() => _LatestRollCardState();
}

class _LatestRollCardState extends State<LatestRollCard> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    if (widget.latestResult != null) {
      _triggerFeedback(widget.latestResult!);
      _animController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant LatestRollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latestResult != null && widget.latestResult != oldWidget.latestResult) {
      _triggerFeedback(widget.latestResult!);
      _animController.forward(from: 0.0);
    }
  }

  void _triggerFeedback(DiceRollResult result) {
    if (result.isCrit) {
      HapticFeedback.heavyImpact();
    } else if (result.isFumble) {
      HapticFeedback.vibrate();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>() ?? TabletopColors.dark;

    if (widget.latestResult == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino_outlined, size: 28, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Text(
              'Tap ROLL to roll the dice!',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    final res = widget.latestResult!;

    Color borderColor = theme.colorScheme.primary.withValues(alpha: 0.5);
    Color totalColor = theme.colorScheme.primary;
    String badgeText = '';

    if (res.isCrit) {
      borderColor = customColors.critGold;
      totalColor = customColors.critGold;
      badgeText = '🔥 NATURAL 20! CRITICAL HIT';
    } else if (res.isFumble) {
      borderColor = customColors.fumbleRed;
      totalColor = customColors.fumbleRed;
      badgeText = '💀 NATURAL 1! CRITICAL FUMBLE';
    }

    final semanticsSummary = 'Latest Roll Result: ${res.total}. Formula: ${res.formulaString}. ${badgeText.isNotEmpty ? badgeText : ''}';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Semantics(
        label: semanticsSummary,
        container: true,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: res.isCrit || res.isFumble ? 2.5 : 1.5),
            boxShadow: [
              BoxShadow(
                color: borderColor.withValues(alpha: res.isCrit ? 0.35 : (res.isFumble ? 0.25 : 0.15)),
                blurRadius: res.isCrit ? 20 : 12,
                spreadRadius: res.isCrit ? 2 : 1,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        res.formulaString,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (badgeText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: res.isCrit ? customColors.critGold : customColors.fumbleRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
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
                  fontSize: 60,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1.0,
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
                          fontSize: 12,
                        ),
                      ),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: group.rolls.map((val) {
                          bool isMax = group.entry.dieType == DieType.d20 && val == 20;
                          bool isMin = group.entry.dieType == DieType.d20 && val == 1;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMax
                                  ? customColors.critGold.withValues(alpha: 0.3)
                                  : isMin
                                      ? customColors.fumbleRed.withValues(alpha: 0.3)
                                      : Colors.black38,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isMax
                                    ? customColors.critGold
                                    : isMin
                                        ? customColors.fumbleRed
                                        : Colors.white24,
                              ),
                            ),
                            child: Text(
                              '$val',
                              style: TextStyle(
                                color: isMax
                                    ? customColors.critGold
                                    : isMin
                                        ? customColors.fumbleRed
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      color: res.modifier > 0 ? customColors.hitGreen : customColors.fumbleRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
