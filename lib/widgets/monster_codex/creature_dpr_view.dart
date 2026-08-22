import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dpr/dpr_models.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/dpr_calculator_engine.dart';
import '../../utils/dice_formatters.dart';

enum CreatureCombatTurnMode {
  amortized3Round,
  rechargeBurst,
  multiattackOnly,
}

/// Interactive Damage Per Round (DPR) calculation and analysis view for creature entries.
class CreatureDprView extends StatefulWidget {
  final MinionStatBlock statBlock;

  const CreatureDprView({
    super.key,
    required this.statBlock,
  });

  @override
  State<CreatureDprView> createState() => _CreatureDprViewState();
}

class _CreatureDprViewState extends State<CreatureDprView> {
  late int _targetAc;
  late AdvantageType _advantage;
  late List<DprAttackAction> _attacks;
  late Map<String, int> _attackCounts;
  late Map<String, int> _targetCounts;
  CreatureCombatTurnMode _turnMode = CreatureCombatTurnMode.amortized3Round;
  bool _includeLegendary = true;

  @override
  void initState() {
    super.initState();
    _targetAc = 15;
    _advantage = widget.statBlock.hasPackTactics
        ? AdvantageType.advantage
        : AdvantageType.normal;
    _attacks = widget.statBlock.extractDprAttacks();
    _attackCounts = {
      for (final a in _attacks) a.id: a.attacksPerRound,
    };
    _targetCounts = {
      for (final a in _attacks) a.id: a.isAoe ? math.max(1, a.targetCount) : 1,
    };
    _applyTurnMode(_turnMode);
  }

  void _applyTurnMode(CreatureCombatTurnMode mode) {
    _turnMode = mode;
    final rechargeActions = _attacks.where((a) => a.rechargeRoll != null && !a.isLegendaryAction).toList();
    final regularTurnAttacks = _attacks.where((a) => a.rechargeRoll == null && !a.isLegendaryAction).toList();

    if (mode == CreatureCombatTurnMode.rechargeBurst && rechargeActions.isNotEmpty) {
      for (final r in rechargeActions) {
        _attackCounts[r.id] = 1;
      }
      for (final reg in regularTurnAttacks) {
        _attackCounts[reg.id] = 0;
      }
    } else if (mode == CreatureCombatTurnMode.multiattackOnly) {
      for (final r in rechargeActions) {
        _attackCounts[r.id] = 0;
      }
      // Reset regular attacks to their multiattack defaults
      final resolved = widget.statBlock.extractDprAttacks().where((a) => !a.isLegendaryAction).toList();
      for (final res in resolved) {
        if (res.rechargeRoll == null) {
          _attackCounts[res.id] = res.attacksPerRound;
        }
      }
    } else {
      // Amortized 3-round mode
      final resolved = widget.statBlock.extractDprAttacks().where((a) => !a.isLegendaryAction).toList();
      for (final res in resolved) {
        _attackCounts[res.id] = res.attacksPerRound;
      }
    }
  }

  void _updateAttackCount(String attackId, int delta) {
    HapticService.selectionTick(context);
    setState(() {
      final current = _attackCounts[attackId] ?? 1;
      _attackCounts[attackId] = math.max(0, math.min(10, current + delta));
    });
  }

  void _updateTargetCount(String attackId, int delta) {
    HapticService.selectionTick(context);
    setState(() {
      final current = _targetCounts[attackId] ?? 2;
      _targetCounts[attackId] = math.max(1, math.min(12, current + delta));
    });
  }

  void _setAdvantage(AdvantageType adv) {
    HapticService.selectionTick(context);
    setState(() => _advantage = adv);
  }

  void _setTargetAc(int ac) {
    HapticService.selectionTick(context);
    setState(() => _targetAc = ac.clamp(5, 30));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.statBlock.accentColor;

    final hasRecharge = _attacks.any((a) => a.rechargeRoll != null && !a.isLegendaryAction);
    final hasLegendary = _attacks.any((a) => a.isLegendaryAction);

    // Calculate regular turn DPR
    double regularTurnDpr = 0.0;
    final attackPoints = <String, DprPoint>{};

    for (final attack in _attacks) {
      final count = _attackCounts[attack.id] ?? 0;
      final tgCount = _targetCounts[attack.id] ?? (attack.isAoe ? 2 : 1);
      final effAttack = attack.copyWith(
        targetCount: tgCount,
        attacksPerRound: 1,
      );

      final point = DprCalculatorEngine.calculateSingleAttackDpr(
        effAttack,
        _targetAc,
        _advantage,
      );
      attackPoints[attack.id] = point;

      if (!attack.isLegendaryAction && count > 0) {
        if (hasRecharge && _turnMode == CreatureCombatTurnMode.amortized3Round && attack.rechargeRoll != null) {
          // Amortized 3-round frequency
          final freq = attack.rechargeRoll == 5 ? (1.667 / 3.0) : (1.333 / 3.0);
          regularTurnDpr += point.dpr * count * freq;
        } else {
          regularTurnDpr += point.dpr * count;
        }
      }
    }

    // If in amortized mode, also scale non-recharge multiattack by non-recharge frequency
    if (hasRecharge && _turnMode == CreatureCombatTurnMode.amortized3Round) {
      final primaryRecharge = _attacks.firstWhere((a) => a.rechargeRoll != null && !a.isLegendaryAction);
      final freq = primaryRecharge.rechargeRoll == 5 ? (1.667 / 3.0) : (1.333 / 3.0);
      double multiDpr = 0.0;
      for (final a in _attacks) {
        if (a.rechargeRoll == null && !a.isLegendaryAction) {
          final count = _attackCounts[a.id] ?? 0;
          if (count > 0 && attackPoints.containsKey(a.id)) {
            multiDpr += attackPoints[a.id]!.dpr * count;
          }
        }
      }
      final rechargeDpr = attackPoints[primaryRecharge.id]?.dpr ?? 0.0;
      regularTurnDpr = (rechargeDpr * freq) + (multiDpr * (1.0 - freq));
    }

    // Calculate legendary action DPR (3 actions / round budget)
    double legendaryDpr = 0.0;
    if (hasLegendary && _includeLegendary) {
      final legOptions = _attacks.where((a) => a.isLegendaryAction).toList();
      double bestLegSum = 0.0;
      for (final la in legOptions) {
        final pt = attackPoints[la.id];
        if (pt != null) {
          final cost = la.legendaryCost > 0 ? la.legendaryCost : 1;
          final uses = 3 ~/ cost;
          final sum = pt.dpr * uses;
          if (sum > bestLegSum) bestLegSum = sum;
        }
      }
      legendaryDpr = bestLegSum;
    }

    final totalDpr = regularTurnDpr + legendaryDpr;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pack Tactics Badge if applicable
          if (widget.statBlock.hasPackTactics) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pack Tactics: Creature has Advantage on attacks when an ally is within 5 ft.',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 2. Recharge Horizon Mode Selector if applicable
          if (hasRecharge) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.blueGrey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Recharge Combat Horizon',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('3-Round Amortized (5e DMG)'),
                        selected: _turnMode == CreatureCombatTurnMode.amortized3Round,
                        onSelected: (sel) {
                          if (sel) setState(() => _applyTurnMode(CreatureCombatTurnMode.amortized3Round));
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Breath Burst Turn'),
                        selected: _turnMode == CreatureCombatTurnMode.rechargeBurst,
                        onSelected: (sel) {
                          if (sel) setState(() => _applyTurnMode(CreatureCombatTurnMode.rechargeBurst));
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Multiattack Only'),
                        selected: _turnMode == CreatureCombatTurnMode.multiattackOnly,
                        onSelected: (sel) {
                          if (sel) setState(() => _applyTurnMode(CreatureCombatTurnMode.multiattackOnly));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // 3. Hero DPR Summary Card
          _buildHeroDprCard(
            context,
            totalDpr: totalDpr,
            regularTurnDpr: regularTurnDpr,
            legendaryDpr: legendaryDpr,
            hasLegendary: hasLegendary,
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 4. Combat Parameters: Target AC & Advantage State
          _buildCombatControls(
            context,
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 5. Attack Routine Breakdown
          _buildRoutineBreakdown(
            context,
            attackPoints: attackPoints,
            hasLegendary: hasLegendary,
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 6. Target AC Benchmark Comparison
          _buildAcBenchmarkTable(
            context,
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeroDprCard(
    BuildContext context, {
    required double totalDpr,
    required double regularTurnDpr,
    required double legendaryDpr,
    required bool hasLegendary,
    required Color accent,
    required bool isDark,
  }) {
    final activeAttacksCount = _attackCounts.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF2A2242),
                  const Color(0xFF1E1730),
                ]
              : [
                  accent.withValues(alpha: 0.12),
                  accent.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPECTED DAMAGE / ROUND',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        totalDpr.toStringAsFixed(1),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFFFD54F) : accent,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'serif',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'DPR',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Target AC $_targetAc',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$activeAttacksCount attack${activeAttacksCount == 1 ? '' : 's'} in turn',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasLegendary) ...[
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.2)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.stars,
                      size: 16,
                      color: isDark ? Colors.amber : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Turn: ${regularTurnDpr.toStringAsFixed(1)} + Legendary (3/rnd): +${legendaryDpr.toStringAsFixed(1)} DPR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: _includeLegendary,
                  activeTrackColor: Colors.amber,
                  onChanged: (val) {
                    HapticService.selectionTick(context);
                    setState(() => _includeLegendary = val);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCombatControls(
    BuildContext context, {
    required Color accent,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target AC Selector
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF60A5FA)),
              const SizedBox(width: 6),
              Text(
                'Target Armor Class: ',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'AC $_targetAc',
                style: const TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                tooltip: 'Decrease AC',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _setTargetAc(_targetAc - 1),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Increase AC',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _setTargetAc(_targetAc + 1),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quick AC Preset Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ac in [10, 12, 15, 18, 20])
                ChoiceChip(
                  label: Text('AC $ac${ac == 15 ? ' (Avg)' : ''}'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _targetAc == ac
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  selected: _targetAc == ac,
                  selectedColor: accent.withValues(alpha: 0.35),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  onSelected: (selected) {
                    if (selected) _setTargetAc(ac);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15)),
          const SizedBox(height: 8),

          // Advantage State Segmented Control
          Row(
            children: [
              const Icon(Icons.casino_outlined, size: 18, color: Color(0xFFA78BFA)),
              const SizedBox(width: 6),
              Text(
                'Roll Modifier:',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAdvantageButton(
                AdvantageType.normal,
                'Normal (1d20)',
                isDark,
                accent,
              ),
              const SizedBox(width: 6),
              _buildAdvantageButton(
                AdvantageType.advantage,
                'Advantage',
                isDark,
                accent,
              ),
              const SizedBox(width: 6),
              _buildAdvantageButton(
                AdvantageType.disadvantage,
                'Disadvantage',
                isDark,
                accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvantageButton(
    AdvantageType type,
    String label,
    bool isDark,
    Color accent,
  ) {
    final isSelected = _advantage == type;
    return Expanded(
      child: InkWell(
        onTap: () => _setAdvantage(type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: isDark ? 0.05 : 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accent
                  : Colors.white.withValues(alpha: isDark ? 0.1 : 0.2),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? (isDark ? const Color(0xFFFFD54F) : accent)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineBreakdown(
    BuildContext context, {
    required Map<String, DprPoint> attackPoints,
    required bool hasLegendary,
    required Color accent,
    required bool isDark,
  }) {
    final turnAttacks = _attacks.where((a) => !a.isLegendaryAction).toList();
    final legAttacks = _attacks.where((a) => a.isLegendaryAction).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACK ROUTINE IN ROUND',
          style: TextStyle(
            color: isDark ? const Color(0xFFFFD54F) : accent,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            fontFamily: 'serif',
          ),
        ),
        const SizedBox(height: 8),
        for (final attack in turnAttacks) ...[
          _buildAttackActionRow(
            context,
            attack: attack,
            point: attackPoints[attack.id],
            count: _attackCounts[attack.id] ?? 0,
            targetCount: _targetCounts[attack.id] ?? (attack.isAoe ? 2 : 1),
            accent: accent,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
        ],
        if (legAttacks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'LEGENDARY ACTIONS (3 / ROUND)',
            style: TextStyle(
              color: isDark ? Colors.amber : const Color(0xFFB45309),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 8),
          for (final attack in legAttacks) ...[
            _buildAttackActionRow(
              context,
              attack: attack,
              point: attackPoints[attack.id],
              count: 3 ~/ (attack.legendaryCost > 0 ? attack.legendaryCost : 1),
              targetCount: _targetCounts[attack.id] ?? (attack.isAoe ? 2 : 1),
              accent: accent,
              isDark: isDark,
              isLegendary: true,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildAttackActionRow(
    BuildContext context, {
    required DprAttackAction attack,
    required DprPoint? point,
    required int count,
    required int targetCount,
    required Color accent,
    required bool isDark,
    bool isLegendary = false,
  }) {
    final hitChancePct = point != null ? (point.hitChance * 100).toStringAsFixed(0) : '0';
    final critChancePct = point != null ? (point.critChance * 100).toStringAsFixed(1) : '0.0';
    final perAttackDpr = point != null ? point.dpr.toStringAsFixed(1) : '0.0';
    final formula = DiceFormatters.formatFormula(
      count: attack.diceCount,
      sides: attack.diceSides,
      bonus: attack.damageBonus,
    );

    final isIncluded = count > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isIncluded
            ? (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isIncluded
              ? (isLegendary ? Colors.amber.withValues(alpha: 0.5) : accent.withValues(alpha: 0.35))
              : Colors.white.withValues(alpha: isDark ? 0.06 : 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            attack.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (attack.deliveryType == DprActionDeliveryType.savingThrow) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DC ${attack.saveDc ?? 15} ${attack.saveAbility?.toUpperCase() ?? "SAVE"}',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${attack.attackBonus >= 0 ? "+" : ""}${attack.attackBonus} to hit',
                              style: TextStyle(
                                color: isDark ? const Color(0xFFFFD54F) : accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attack.deliveryType == DprActionDeliveryType.savingThrow
                          ? '$formula ${attack.damageType} • $hitChancePct% target fail rate'
                          : '$formula ${attack.damageType} • $hitChancePct% hit ($critChancePct% crit)',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$perAttackDpr DPR ${attack.isAoe ? "($targetCount targets)" : ""}',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Attack Stepper (if not legendary action)
              if (!isLegendary) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      tooltip: 'Remove one attack',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: () => _updateAttackCount(attack.id, -1),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: count > 0
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white38 : Colors.black26),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      tooltip: 'Add one attack',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: () => _updateAttackCount(attack.id, 1),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // AoE Target Count Stepper if applicable
          if (attack.isAoe) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.hub_outlined, size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(
                  'AoE Targets: $targetCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  onPressed: () => _updateTargetCount(attack.id, -1),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  onPressed: () => _updateTargetCount(attack.id, 1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcBenchmarkTable(
    BuildContext context, {
    required Color accent,
    required bool isDark,
  }) {
    final benchmarks = [
      (ac: 10, label: 'Unarmored (AC 10)'),
      (ac: 13, label: 'Light Armor (AC 13)'),
      (ac: 15, label: 'Standard (AC 15)'),
      (ac: 18, label: 'Heavy/Shield (AC 18)'),
      (ac: 21, label: 'Boss/Shield (AC 21)'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AC BENCHMARK CURVE',
            style: TextStyle(
              color: isDark ? const Color(0xFFFFD54F) : accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 8),
          for (final b in benchmarks) ...[
            _buildBenchmarkRow(
              b.ac,
              b.label,
              accent: accent,
              isDark: isDark,
            ),
            if (b.ac != benchmarks.last.ac)
              Divider(color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.1), height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildBenchmarkRow(
    int ac,
    String label, {
    required Color accent,
    required bool isDark,
  }) {
    double rowDpr = 0.0;
    double primaryHitPct = 0.0;

    for (int i = 0; i < _attacks.length; i++) {
      final attack = _attacks[i];
      final count = _attackCounts[attack.id] ?? 0;
      if (count > 0) {
        final pt = DprCalculatorEngine.calculateSingleAttackDpr(
          attack.copyWith(attacksPerRound: 1),
          ac,
          _advantage,
        );
        rowDpr += pt.dpr * count;
        if (i == 0) primaryHitPct = pt.hitChance * 100;
      }
    }

    final isSelected = _targetAc == ac;

    return InkWell(
      onTap: () => _setTargetAc(ac),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? (isDark ? const Color(0xFFFFD54F) : accent)
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${primaryHitPct.toStringAsFixed(0)}% hit',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '${rowDpr.toStringAsFixed(1)} DPR',
              style: TextStyle(
                color: isSelected
                    ? (isDark ? const Color(0xFFFFD54F) : accent)
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
