import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/monster_codex_data.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../services/a11y_service.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/spellcasting_rules_engine.dart';
import '../glyphs/dnd_glyph.dart';

enum RollAdvantageMode {
  normal('Normal', Icons.crop_square),
  advantage('Advantage', Icons.arrow_upward),
  disadvantage('Disadvantage', Icons.arrow_downward);

  final String label;
  final IconData icon;
  const RollAdvantageMode(this.label, this.icon);
}

/// Represents a single attack roll within an action or multiattack sequence.
class SingleAttackRoll {
  final String attackName;
  final int d20Roll1;
  final int? d20Roll2;
  final RollAdvantageMode advantageMode;
  final int attackBonus;
  final int attackTotal;
  final bool isCrit;
  final bool isFumble;
  final SpellRollResult? damageResult;

  const SingleAttackRoll({
    required this.attackName,
    required this.d20Roll1,
    this.d20Roll2,
    required this.advantageMode,
    required this.attackBonus,
    required this.attackTotal,
    required this.isCrit,
    required this.isFumble,
    this.damageResult,
  });
}

/// Result of executing a creature action, supporting both single strikes and multiattack sequences.
class MonsterActionResult {
  final String actionName;
  final bool isMultiattack;
  final List<SingleAttackRoll> attackRolls;

  const MonsterActionResult({
    required this.actionName,
    this.isMultiattack = false,
    required this.attackRolls,
  });

  // Convenience getters for backward compatibility with single attack rolls
  SingleAttackRoll get primaryAttack => attackRolls.isNotEmpty
      ? attackRolls.first
      : const SingleAttackRoll(
          attackName: 'Action',
          d20Roll1: 10,
          advantageMode: RollAdvantageMode.normal,
          attackBonus: 0,
          attackTotal: 10,
          isCrit: false,
          isFumble: false,
        );

  int get d20Roll1 => primaryAttack.d20Roll1;
  int? get d20Roll2 => primaryAttack.d20Roll2;
  RollAdvantageMode get advantageMode => primaryAttack.advantageMode;
  int get attackBonus => primaryAttack.attackBonus;
  int get attackTotal => primaryAttack.attackTotal;
  bool get isCrit => attackRolls.any((a) => a.isCrit);
  bool get isFumble => attackRolls.isNotEmpty && attackRolls.every((a) => a.isFumble);
  SpellRollResult? get damageResult => primaryAttack.damageResult;

  int get totalDamage {
    int sum = 0;
    for (final a in attackRolls) {
      if (a.damageResult != null) {
        sum += a.damageResult!.total;
      }
    }
    return sum;
  }

  factory MonsterActionResult.single({
    required String actionName,
    required int d20Roll1,
    int? d20Roll2,
    required RollAdvantageMode advantageMode,
    required int attackBonus,
    required int attackTotal,
    required bool isCrit,
    required bool isFumble,
    SpellRollResult? damageResult,
  }) {
    return MonsterActionResult(
      actionName: actionName,
      isMultiattack: false,
      attackRolls: [
        SingleAttackRoll(
          attackName: actionName,
          d20Roll1: d20Roll1,
          d20Roll2: d20Roll2,
          advantageMode: advantageMode,
          attackBonus: attackBonus,
          attackTotal: attackTotal,
          isCrit: isCrit,
          isFumble: isFumble,
          damageResult: damageResult,
        ),
      ],
    );
  }
}

/// Interactive modal for quick-rolling creature attack rolls, damage, multiattacks, and traits.
class MonsterQuickRollDialog extends StatefulWidget {
  final MonsterItem monster;
  final CreatureAction? initialAction;
  final void Function(MonsterActionResult result, String monsterName)? onRollCompleted;

  const MonsterQuickRollDialog({
    super.key,
    required this.monster,
    this.initialAction,
    this.onRollCompleted,
  });

  static Future<MonsterActionResult?> show(
    BuildContext context, {
    required MonsterItem monster,
    CreatureAction? initialAction,
    void Function(MonsterActionResult result, String monsterName)? onRollCompleted,
  }) {
    HapticService.selectionTick(context);
    return showDialog<MonsterActionResult>(
      context: context,
      builder: (ctx) => MonsterQuickRollDialog(
        monster: monster,
        initialAction: initialAction,
        onRollCompleted: onRollCompleted,
      ),
    );
  }

  @override
  State<MonsterQuickRollDialog> createState() => _MonsterQuickRollDialogState();
}

class _MonsterQuickRollDialogState extends State<MonsterQuickRollDialog> {
  late CreatureAction _selectedAction;
  RollAdvantageMode _advantageMode = RollAdvantageMode.normal;
  MonsterActionResult? _latestResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != null) {
      _selectedAction = widget.initialAction!;
    } else if (widget.monster.actions.isNotEmpty) {
      _selectedAction = widget.monster.actions.first;
    } else {
      _selectedAction = const CreatureAction(
        name: 'Basic Attack',
        description: 'Standard melee strike',
        attackBonus: 2,
        hitDamage: '1d4 + 2 damage',
      );
    }
  }

  /// Parses Multiattack text to resolve the list of specific weapon attacks.
  List<CreatureAction> _resolveMultiattackActions(CreatureAction multiattack) {
    final desc = multiattack.description.toLowerCase();
    final otherActions = widget.monster.actions
        .where((a) => !a.name.toLowerCase().contains('multiattack'))
        .toList();
    if (otherActions.isEmpty) return [multiattack];

    const wordToNum = <String, int>{
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8,
      '1': 1, '2': 2, '3': 3, '4': 4, '5': 5,
      '6': 6, '7': 7, '8': 8,
    };

    final resolved = <CreatureAction>[];
    bool foundExplicit = false;

    for (final action in otherActions) {
      final aName = action.name.toLowerCase().trim();
      final stem = (aName.endsWith('s') && aName.length > 3)
          ? aName.substring(0, aName.length - 1)
          : aName;

      final patterns = [
        RegExp(r'(one|two|three|four|five|six|seven|eight|\d+)\s+(?:melee\s+|ranged\s+)?attacks?\s+(?:with\s+its\s+|of\s+its\s+)?' + RegExp.escape(stem)),
        RegExp(r'(one|two|three|four|five|six|seven|eight|\d+)\s+with\s+(?:its\s+)?' + RegExp.escape(stem)),
        RegExp(r'(one|two|three|four|five|six|seven|eight|\d+)\s+' + RegExp.escape(stem) + r'\s+attacks?'),
        RegExp(r'(one|two|three|four|five|six|seven|eight|\d+)\s+' + RegExp.escape(stem)),
      ];

      int count = 0;
      for (final p in patterns) {
        final match = p.firstMatch(desc);
        if (match != null) {
          count = wordToNum[match.group(1)!] ?? 1;
          break;
        }
      }

      if (count > 0) {
        foundExplicit = true;
        for (int i = 0; i < count; i++) {
          resolved.add(action);
        }
      }
    }

    if (!foundExplicit) {
      final genericMatch = RegExp(r'makes\s+(one|two|three|four|five|six|seven|eight|\d+)\s+attacks?').firstMatch(desc);
      if (genericMatch != null) {
        final count = wordToNum[genericMatch.group(1)!] ?? 2;
        for (int i = 0; i < count; i++) {
          resolved.add(otherActions.first);
        }
      } else {
        resolved.add(otherActions.first);
        resolved.add(otherActions.first);
      }
    }

    return resolved;
  }

  SingleAttackRoll _rollSingleAttack(CreatureAction action, Random rnd) {
    final roll1 = rnd.nextInt(20) + 1;
    int? roll2;
    int effectiveD20 = roll1;

    if (_advantageMode == RollAdvantageMode.advantage) {
      roll2 = rnd.nextInt(20) + 1;
      effectiveD20 = max(roll1, roll2);
    } else if (_advantageMode == RollAdvantageMode.disadvantage) {
      roll2 = rnd.nextInt(20) + 1;
      effectiveD20 = min(roll1, roll2);
    }

    final bonus = action.attackBonus ?? 0;
    final totalAttack = effectiveD20 + bonus;
    final isCrit = effectiveD20 == 20;
    final isFumble = effectiveD20 == 1;

    SpellRollResult? dmgResult;
    final hitDamage = action.hitDamage;
    if (hitDamage != null && hitDamage.isNotEmpty) {
      final formulaMatch = RegExp(r'(\d+d\d+(?:\s*[+-]\s*\d+)?)').firstMatch(hitDamage);
      if (formulaMatch != null) {
        final formula = formulaMatch.group(1)!;
        dmgResult = SpellRollEngine.roll(formula: formula);
      }
    }

    return SingleAttackRoll(
      attackName: action.name,
      d20Roll1: roll1,
      d20Roll2: roll2,
      advantageMode: _advantageMode,
      attackBonus: bonus,
      attackTotal: totalAttack,
      isCrit: isCrit,
      isFumble: isFumble,
      damageResult: dmgResult,
    );
  }

  void _executeRoll() {
    HapticService.heavyImpact(context);
    final rnd = Random();
    final isMulti = _selectedAction.name.toLowerCase().contains('multiattack');

    final attackActions = isMulti
        ? _resolveMultiattackActions(_selectedAction)
        : [_selectedAction];

    final attackRolls = attackActions.map((act) => _rollSingleAttack(act, rnd)).toList();

    final result = MonsterActionResult(
      actionName: _selectedAction.name,
      isMultiattack: isMulti,
      attackRolls: attackRolls,
    );

    final announceText = isMulti
        ? '${widget.monster.name} - Multiattack (${attackRolls.length} attacks): Total Combined Damage ${result.totalDamage}'
        : '${widget.monster.name} - ${_selectedAction.name}: Attack Total ${result.attackTotal}${result.damageResult != null ? ", Damage: ${result.damageResult!.total}" : ""}';
    A11yService.announce(announceText);

    setState(() {
      _latestResult = result;
    });

    widget.onRollCompleted?.call(result, widget.monster.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statBlock = widget.monster.sourceStatBlock;
    final creatureType = statBlock.glyphCreatureType;
    final typeColor = creatureType.getLegibleColor(isDark);
    final isMulti = _selectedAction.name.toLowerCase().contains('multiattack');
    final multiActions = isMulti ? _resolveMultiattackActions(_selectedAction) : const <CreatureAction>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13111C) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: typeColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  border: Border(
                    bottom: BorderSide(
                      color: typeColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    DndGlyph.monster(
                      creatureType: creatureType,
                      crTier: statBlock.glyphCrTier,
                      actionRings: statBlock.glyphActionRings,
                      size: 28,
                      isDarkMode: isDark,
                      isActive: true,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.monster.name,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Quick Action & Attack Roller',
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(_latestResult),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Select Action Dropdown
                      Text(
                        'Select Action',
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (widget.monster.actions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CreatureAction>(
                              value: widget.monster.actions.contains(_selectedAction)
                                  ? _selectedAction
                                  : widget.monster.actions.first,
                              isExpanded: true,
                              items: widget.monster.actions.map((act) {
                                final isActMulti = act.name.toLowerCase().contains('multiattack');
                                final bonus = act.attackBonus != null
                                    ? ' (${act.attackBonus! >= 0 ? "+" : ""}${act.attackBonus})'
                                    : (isActMulti ? ' [Multiattack]' : '');
                                return DropdownMenuItem(
                                  value: act,
                                  child: Text(
                                    '${act.name}$bonus',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isActMulti
                                          ? (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (act) {
                                if (act != null) {
                                  HapticService.selectionTick(context);
                                  setState(() => _selectedAction = act);
                                }
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Action description
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAction.description,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                            if (isMulti && multiActions.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (int i = 0; i < multiActions.length; i++)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                                              .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        '#${i + 1} ${multiActions[i].name}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Advantage / Disadvantage Segments
                      Text(
                        'Attack Roll Mode',
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SegmentedButton<RollAdvantageMode>(
                        segments: [
                          for (final mode in RollAdvantageMode.values)
                            ButtonSegment(
                              value: mode,
                              label: Text(mode.label, style: const TextStyle(fontSize: 11)),
                              icon: Icon(mode.icon, size: 14),
                            ),
                        ],
                        selected: {_advantageMode},
                        onSelectionChanged: (val) {
                          HapticService.selectionTick(context);
                          setState(() => _advantageMode = val.first);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Latest Roll Result Card
                      if (_latestResult != null) ...[
                        _buildRollResultCard(context, _latestResult!, typeColor, isDark),
                        const SizedBox(height: 16),
                      ],

                      // Roll Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _executeRoll,
                          icon: const Icon(Icons.casino, size: 18),
                          label: Text(
                            isMulti
                                ? 'Roll Multiattack (${multiActions.length} Attacks)'
                                : 'Roll ${_selectedAction.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRollResultCard(
    BuildContext context,
    MonsterActionResult result,
    Color typeColor,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    if (result.isMultiattack) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (isDark ? Colors.amber : const Color(0xFFB45309)).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isDark ? Colors.amberAccent : const Color(0xFFB45309)).withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: isDark ? Colors.amberAccent : const Color(0xFFB45309), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'MULTIATTACK (${result.attackRolls.length} STRIKES)',
                    style: TextStyle(
                      color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Total: ${result.totalDamage} dmg',
                  style: TextStyle(
                    color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            for (int i = 0; i < result.attackRolls.length; i++) ...[
              _buildSingleAttackRow(context, result.attackRolls[i], i + 1, typeColor, isDark),
              if (i < result.attackRolls.length - 1)
                const Divider(height: 12, thickness: 0.5),
            ],
          ],
        ),
      );
    }

    final single = result.primaryAttack;
    final cardColor = single.isCrit
        ? Colors.green
        : (single.isFumble ? Colors.red : typeColor);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cardColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                single.isCrit
                    ? Icons.stars
                    : (single.isFumble ? Icons.warning_amber : Icons.casino),
                color: single.isCrit
                    ? Colors.greenAccent
                    : (single.isFumble ? Colors.redAccent : typeColor),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                single.isCrit
                    ? 'NATURAL 20 CRITICAL HIT!'
                    : (single.isFumble ? 'NATURAL 1 FUMBLE!' : 'Attack Result'),
                style: TextStyle(
                  color: single.isCrit
                      ? Colors.greenAccent
                      : (single.isFumble ? Colors.redAccent : typeColor),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                'Total: ${single.attackTotal}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'd20 roll: ${single.d20Roll1}${single.d20Roll2 != null ? ", ${single.d20Roll2}" : ""} + ${single.attackBonus}',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              fontSize: 11.5,
            ),
          ),
          if (single.damageResult != null) ...[
            const Divider(height: 12),
            Row(
              children: [
                Text(
                  'Damage: ${single.damageResult!.total}',
                  style: TextStyle(
                    color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '[${single.damageResult!.individualDice.join(", ")}${single.damageResult!.modifier != 0 ? " + ${single.damageResult!.modifier}" : ""}]',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleAttackRow(
    BuildContext context,
    SingleAttackRoll attack,
    int index,
    Color typeColor,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: attack.isCrit
                ? Colors.green.withValues(alpha: 0.3)
                : (attack.isFumble
                    ? Colors.red.withValues(alpha: 0.3)
                    : theme.colorScheme.surfaceContainerHighest),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '#$index ${attack.attackName}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: attack.isCrit
                  ? Colors.greenAccent
                  : (attack.isFumble ? Colors.redAccent : theme.colorScheme.onSurface),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Text(
                'Hit: ${attack.attackTotal}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: attack.isCrit
                      ? Colors.greenAccent
                      : (attack.isFumble ? Colors.redAccent : null),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '(d20: ${attack.d20Roll1}${attack.attackBonus >= 0 ? "+${attack.attackBonus}" : "${attack.attackBonus}"})',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (attack.damageResult != null)
          Text(
            '${attack.damageResult!.total} dmg',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
            ),
          ),
      ],
    );
  }
}
