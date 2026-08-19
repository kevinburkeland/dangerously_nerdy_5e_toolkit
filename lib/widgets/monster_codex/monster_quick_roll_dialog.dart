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

class MonsterActionResult {
  final String actionName;
  final int d20Roll1;
  final int? d20Roll2;
  final RollAdvantageMode advantageMode;
  final int attackBonus;
  final int attackTotal;
  final bool isCrit;
  final bool isFumble;
  final SpellRollResult? damageResult;

  const MonsterActionResult({
    required this.actionName,
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

/// Interactive modal for quick-rolling creature attack rolls, damage, and traits.
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

  void _executeRoll() {
    HapticService.heavyImpact(context);
    final rnd = Random();
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

    final bonus = _selectedAction.attackBonus ?? 0;
    final totalAttack = effectiveD20 + bonus;
    final isCrit = effectiveD20 == 20;
    final isFumble = effectiveD20 == 1;

    SpellRollResult? dmgResult;
    final hitDamage = _selectedAction.hitDamage;
    if (hitDamage != null && hitDamage.isNotEmpty) {
      final formulaMatch = RegExp(r'(\d+d\d+(?:\s*[+-]\s*\d+)?)').firstMatch(hitDamage);
      if (formulaMatch != null) {
        final formula = formulaMatch.group(1)!;
        dmgResult = SpellRollEngine.roll(formula: formula);
      }
    }

    final result = MonsterActionResult(
      actionName: _selectedAction.name,
      d20Roll1: roll1,
      d20Roll2: roll2,
      advantageMode: _advantageMode,
      attackBonus: bonus,
      attackTotal: totalAttack,
      isCrit: isCrit,
      isFumble: isFumble,
      damageResult: dmgResult,
    );

    final announceText = '${widget.monster.name} - ${_selectedAction.name}: Attack Total $totalAttack (d20: $effectiveD20${bonus >= 0 ? "+$bonus" : "$bonus"})${dmgResult != null ? ", Damage: ${dmgResult.total}" : ""}';
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                      size: 28,
                      isDarkMode: isDark,
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
                                final bonus = act.attackBonus != null
                                    ? ' (${act.attackBonus! >= 0 ? "+" : ""}${act.attackBonus})'
                                    : '';
                                return DropdownMenuItem(
                                  value: act,
                                  child: Text(
                                    '${act.name}$bonus',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                        child: Text(
                          _selectedAction.description,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_latestResult!.isCrit
                                    ? Colors.green
                                    : (_latestResult!.isFumble ? Colors.red : typeColor))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (_latestResult!.isCrit
                                      ? Colors.green
                                      : (_latestResult!.isFumble ? Colors.red : typeColor))
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _latestResult!.isCrit
                                        ? Icons.stars
                                        : (_latestResult!.isFumble ? Icons.warning_amber : Icons.casino),
                                    color: _latestResult!.isCrit
                                        ? Colors.greenAccent
                                        : (_latestResult!.isFumble ? Colors.redAccent : typeColor),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _latestResult!.isCrit
                                        ? 'NATURAL 20 CRITICAL HIT!'
                                        : (_latestResult!.isFumble ? 'NATURAL 1 FUMBLE!' : 'Attack Result'),
                                    style: TextStyle(
                                      color: _latestResult!.isCrit
                                          ? Colors.greenAccent
                                          : (_latestResult!.isFumble ? Colors.redAccent : typeColor),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Total: ${_latestResult!.attackTotal}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'd20 roll: ${_latestResult!.d20Roll1}${_latestResult!.d20Roll2 != null ? ", ${_latestResult!.d20Roll2}" : ""} + ${_latestResult!.attackBonus}',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                                  fontSize: 11.5,
                                ),
                              ),
                              if (_latestResult!.damageResult != null) ...[
                                const Divider(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      'Damage: ${_latestResult!.damageResult!.total}',
                                      style: TextStyle(
                                        color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '[${_latestResult!.damageResult!.individualDice.join(", ")}${_latestResult!.damageResult!.modifier != 0 ? " + ${_latestResult!.damageResult!.modifier}" : ""}]',
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
                        ),
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
                            'Roll ${_selectedAction.name}',
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
}
