import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// Interactive animated 3D/tumbling dice physics simulation
class AnimatedDiceRollOverlay extends StatefulWidget {
  final DiceRollResult result;
  final VoidCallback onDismiss;

  const AnimatedDiceRollOverlay({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  @override
  State<AnimatedDiceRollOverlay> createState() => _AnimatedDiceRollOverlayState();
}

class _AnimatedDiceRollOverlayState extends State<AnimatedDiceRollOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _bounceAnimation;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _scaleAnimation;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: -180.0, end: 0.0).chain(CurveTween(curve: Curves.easeInQuad)), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -35.0).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -35.0, end: 0.0).chain(CurveTween(curve: Curves.bounceOut)), weight: 35),
    ]).animate(_animController);

    _rotationAnimation = Tween<double>(begin: 0.0, end: 4 * pi).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 40),
    ]).animate(_animController);

    _animController.addListener(() {
      if (mounted) setState(() {});
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        HapticService.heavyImpact(context);
      }
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>();
    final isDone = _animController.isCompleted;
    final res = widget.result;

    // Collect all individual die rolls for visualization (up to 12 visible dice)
    final allDice = <_IndividualDie>[];
    for (final group in res.groupResults) {
      for (final roll in group.rolls) {
        allDice.add(_IndividualDie(dieType: group.entry.dieType, finalValue: roll));
        if (allDice.length >= 12) break;
      }
      if (allDice.length >= 12) break;
    }

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dice Tumbling Tray
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: allDice.asMap().entries.map((entry) {
                final idx = entry.key;
                final die = entry.value;
                return _buildAnimatedDieWidget(
                  die: die,
                  index: idx,
                  isSettled: isDone,
                  theme: theme,
                  tabletop: tabletop,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Roll Result Banner
            if (isDone) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 250),
                builder: (context, val, child) => Transform.scale(
                  scale: val,
                  child: Opacity(opacity: val, child: child),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: res.isCrit
                              ? (tabletop?.critGold ?? Colors.amber)
                              : (res.isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (res.isCrit
                                    ? (tabletop?.critGold ?? Colors.amber)
                                    : (res.isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary))
                                .withValues(alpha: 0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            res.formulaString,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${res.total}',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: res.isCrit
                                  ? (tabletop?.critGold ?? Colors.amber)
                                  : (res.isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary),
                            ),
                          ),
                          if (res.isCrit)
                            const Text('🔥 NATURAL 20! 🔥',
                                style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 13)),
                          if (res.isFumble)
                            const Text('💀 NATURAL 1! 💀',
                                style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap anywhere to dismiss',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedDieWidget({
    required _IndividualDie die,
    required int index,
    required bool isSettled,
    required ThemeData theme,
    required TabletopColors? tabletop,
  }) {
    final seedVal = _rng.nextInt(die.dieType.sides) + 1;
    final displayValue = isSettled ? die.finalValue : seedVal;
    final isCrit = die.dieType == DieType.d20 && displayValue == 20;
    final isFumble = die.dieType == DieType.d20 && displayValue == 1;

    final baseColor = isCrit
        ? (tabletop?.critGold ?? Colors.amber)
        : (isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary);

    final angle = isSettled ? 0.0 : _rotationAnimation.value * (index % 2 == 0 ? 1 : -1) + (index * 0.4);
    final yOffset = isSettled ? 0.0 : _bounceAnimation.value;

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Transform.scale(
        scale: _scaleAnimation.value,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(angle * 0.7)
            ..rotateY(angle * 0.8)
            ..rotateZ(angle * 0.4),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [baseColor, baseColor.withValues(alpha: 0.8)],
                center: const Alignment(-0.3, -0.3),
              ),
              shape: die.dieType == DieType.d20 ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: die.dieType == DieType.d20 ? null : BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.5),
                  blurRadius: isSettled ? 12 : 6,
                  spreadRadius: isSettled ? 2 : 0,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$displayValue',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                shadows: [
                  Shadow(color: Colors.white70, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndividualDie {
  final DieType dieType;
  final int finalValue;
  const _IndividualDie({required this.dieType, required this.finalValue});
}
