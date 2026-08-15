import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../models/room_roll.dart';
import '../../models/spell_session.dart';
import '../../services/a11y_service.dart';
import '../../services/dice_room_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/secure_random.dart';
import '../batch_attack/batch_attack_results_card.dart';

class BatchAttackDialog extends StatefulWidget {
  final SpellSession session;
  final DiceRoomService roomService;

  BatchAttackDialog({
    super.key,
    required this.session,
    DiceRoomService? roomService,
  }) : roomService = roomService ?? DiceRoomService();

  @override
  State<BatchAttackDialog> createState() => _BatchAttackDialogState();
}

class _BatchAttackDialogState extends State<BatchAttackDialog> {
  int _targetAc = 15;
  RollMode _advantageMode = RollMode.normal;
  bool _useMaximizedCrits = false;
  bool _showTacticalConditions = false;
  bool _targetProne = false;
  bool _packTactics = false;
  bool _targetIncapacitated = false;
  bool _attackerImpaired = false;

  BatchAttackSummary? _summary;
  DateTime? _lastAttackRollTime;

  @override
  void initState() {
    super.initState();
    if (widget.session.activeObjects.any((o) => o.hasPackTactics)) {
      _packTactics = true;
      _advantageMode = RollMode.advantage;
    }
  }

  void _recalculateTacticalAdvantage() {
    final hasAdv = _targetProne || _packTactics || _targetIncapacitated;
    final hasDis = _attackerImpaired;

    setState(() {
      if (hasAdv && hasDis) {
        _advantageMode = RollMode.normal;
      } else if (hasAdv) {
        _advantageMode = RollMode.advantage;
      } else if (hasDis) {
        _advantageMode = RollMode.disadvantage;
      } else {
        _advantageMode = RollMode.normal;
      }
    });
  }

  void _onManualRollModeChanged(RollMode mode) {
    HapticService.selectionTick(context);
    setState(() {
      _advantageMode = mode;
      _targetProne = false;
      _packTactics = false;
      _targetIncapacitated = false;
      _attackerImpaired = false;
    });
  }

  void _rollAttacks() {
    final now = DateTime.now();
    if (_lastAttackRollTime != null && now.difference(_lastAttackRollTime!).inMilliseconds < 200) {
      return;
    }
    _lastAttackRollTime = now;

    HapticService.heavyImpact(context);

    final summary = widget.session.performBatchAttack(
      targetAc: _targetAc,
      advantageMode: _advantageMode,
      useMaximizedCrits: _useMaximizedCrits,
    );

    setState(() {
      _summary = summary;
    });

    A11yService.announceBatchAttack(summary, _targetAc);

    final activeCode = widget.roomService.activeRoomCode;
    final activePlayer = widget.roomService.playerName;

    if (activeCode != null && activePlayer != null) {
      final timestamp = DateTime.now();
      final summaryId = '${timestamp.microsecondsSinceEpoch}_batch_${secureRandom.nextInt(1000000)}';

      final attackDetails = summary.results.map((res) {
        final d20Str = res.d20Roll2 != null
            ? 'd20 [${res.d20Roll1}, ${res.d20Roll2} -> ${res.finalD20}]'
            : 'd20 [${res.finalD20}]';
        final toHitStr = '$d20Str + ${res.object.attackBonus} = ${res.totalToHit} vs AC $_targetAc';
        final hitStatus = res.isCrit
            ? (res.isMaximizedCrit ? 'MAX CRIT!' : 'CRIT!')
            : (res.isHit ? 'HIT' : 'MISS');
        final dmgStr = res.isHit ? ' -> ${res.totalDamage} dmg' : '';
        return '${res.object.name} (${res.object.size.displayName}): $toHitStr [$hitStatus]$dmgStr';
      }).toList();

      final summaryRoll = RoomRoll(
        id: summaryId,
        roomCode: activeCode,
        playerName: activePlayer,
        timestamp: timestamp,
        formulaString: 'Batch Attack (${summary.totalHits}/${summary.totalAttacks} Hits vs AC $_targetAc)',
        total: summary.totalDamage,
        individualRolls: summary.results.map((r) => r.totalDamage).toList(),
        details: attackDetails,
        isCrit: summary.totalCrits > 0,
        isFumble: false,
      );
      unawaited(widget.roomService.broadcastRoll(summaryRoll));
    }
  }

  @override
  Widget build(BuildContext context) {
    final livingCount = widget.session.activeObjects.where((o) => !o.isDead).length;
    final currentRoomCode = widget.roomService.activeRoomCode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;
    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>() ?? TabletopColors.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset('assets/images/logo.png', width: 32, height: 32),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Batch Attack Roller',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 18 : 20,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (currentRoomCode != null)
                              Row(
                                children: [
                                  const Icon(Icons.sensors, color: Colors.cyanAccent, size: 12),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Broadcasting to Room: $currentRoomCode',
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  tooltip: 'Close dialog',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 6),

            if (livingCount == 0)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No living animated objects available to attack!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Controls: Target AC & Advantage Toggle
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 420;

                          final targetAcWidget = Column(
                            crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                            children: [
                              const Text('Target AC', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.remove_circle, color: Colors.amber),
                                    onPressed: _targetAc > 1 ? () => setState(() => _targetAc--) : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      '$_targetAc',
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.add_circle, color: Colors.amber),
                                    onPressed: () => setState(() => _targetAc++),
                                  ),
                                ],
                              ),
                            ],
                          );

                          final advantageWidget = Column(
                            crossAxisAlignment: isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.end,
                            children: [
                              const Text('Roll Mode', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: SegmentedButton<RollMode>(
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 6, vertical: 0)),
                                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(WidgetState.selected)) return Colors.amber;
                                      return Colors.white10;
                                    }),
                                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                                      if (states.contains(WidgetState.selected)) return Colors.black;
                                      return Colors.white;
                                    }),
                                  ),
                                  segments: const [
                                    ButtonSegment(value: RollMode.disadvantage, label: Text('Dis', style: TextStyle(fontSize: 12))),
                                    ButtonSegment(value: RollMode.normal, label: Text('Norm', style: TextStyle(fontSize: 12))),
                                    ButtonSegment(value: RollMode.advantage, label: Text('Adv', style: TextStyle(fontSize: 12))),
                                  ],
                                  selected: {_advantageMode},
                                  onSelectionChanged: (set) => _onManualRollModeChanged(set.first),
                                ),
                              ),
                            ],
                          );

                          if (isCompact) {
                            return Column(
                              children: [
                                targetAcWidget,
                                const SizedBox(height: 10),
                                advantageWidget,
                              ],
                            );
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              targetAcWidget,
                              advantageWidget,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Tactical Modifiers Accordion
                      Container(
                        decoration: BoxDecoration(
                          color: tabletop.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_targetProne || _packTactics || _targetIncapacitated || _attackerImpaired)
                                ? Colors.cyanAccent.withValues(alpha: 0.6)
                                : tabletop.cardBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => setState(() => _showTacticalConditions = !_showTacticalConditions),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.flash_on, color: Colors.cyanAccent, size: 18),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Tactical Combat Conditions',
                                        style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    if (_targetProne || _packTactics || _targetIncapacitated || _attackerImpaired)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _advantageMode == RollMode.advantage
                                              ? 'Advantage Active'
                                              : (_advantageMode == RollMode.disadvantage ? 'Disadvantage Active' : 'Cancelled Out'),
                                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    Icon(
                                      _showTacticalConditions ? Icons.expand_less : Icons.expand_more,
                                      color: Colors.cyanAccent,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showTacticalConditions) ...[
                              const Divider(height: 1, color: Colors.white12),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilterChip(
                                      label: const Text('Target Prone (Melee)', style: TextStyle(fontSize: 11)),
                                      selected: _targetProne,
                                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                                      checkmarkColor: Colors.cyanAccent,
                                      onSelected: (val) {
                                        _targetProne = val;
                                        _recalculateTacticalAdvantage();
                                      },
                                    ),
                                    FilterChip(
                                      label: const Text('Pack Tactics (Ally 5ft)', style: TextStyle(fontSize: 11)),
                                      selected: _packTactics,
                                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                                      checkmarkColor: Colors.cyanAccent,
                                      onSelected: (val) {
                                        _packTactics = val;
                                        _recalculateTacticalAdvantage();
                                      },
                                    ),
                                    FilterChip(
                                      label: const Text('Target Stunned/Restrained', style: TextStyle(fontSize: 11)),
                                      selected: _targetIncapacitated,
                                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                                      checkmarkColor: Colors.cyanAccent,
                                      onSelected: (val) {
                                        _targetIncapacitated = val;
                                        _recalculateTacticalAdvantage();
                                      },
                                    ),
                                    FilterChip(
                                      label: const Text('Attacker Poisoned/Blinded', style: TextStyle(fontSize: 11)),
                                      selected: _attackerImpaired,
                                      selectedColor: Colors.redAccent.withValues(alpha: 0.3),
                                      checkmarkColor: Colors.redAccent,
                                      onSelected: (val) {
                                        _attackerImpaired = val;
                                        _recalculateTacticalAdvantage();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Maximized Criticals Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _useMaximizedCrits ? Colors.amber : Colors.white12,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Row(
                              children: [
                                Icon(Icons.bolt, color: Colors.amber, size: 18),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Maximized Criticals',
                                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: const Text(
                              'Crits deal max dice damage + a normal dice roll',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            value: _useMaximizedCrits,
                            activeThumbColor: Colors.amber,
                            onChanged: (val) => setState(() => _useMaximizedCrits = val),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Roll Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _rollAttacks,
                          icon: const Icon(Icons.casino, size: 24),
                          label: Text(
                            _summary == null
                                ? 'ROLL ALL $livingCount ATTACKS'
                                : 'RE-ROLL ALL $livingCount ATTACKS',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Results Summary & Detailed Breakdown Card
                      if (_summary != null) ...[
                        BatchAttackResultsCard(
                          summary: _summary!,
                          targetAc: _targetAc,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
