import 'package:flutter/material.dart';
import '../models/animated_object.dart';
import '../models/room_roll.dart';
import '../models/spell_session.dart';
import '../services/dice_room_service.dart';
import 'batch_attack/batch_attack_results_card.dart';

class BatchAttackDialog extends StatefulWidget {
  final SpellSession session;
  final String? activeRoomCode;
  final String? playerName;

  const BatchAttackDialog({
    super.key,
    required this.session,
    this.activeRoomCode,
    this.playerName,
  });

  @override
  State<BatchAttackDialog> createState() => _BatchAttackDialogState();
}

class _BatchAttackDialogState extends State<BatchAttackDialog> {
  int _targetAc = 15;
  RollAdvantage _advantageMode = RollAdvantage.normal;
  bool _useMaximizedCrits = false;
  BatchAttackSummary? _summary;

  void _rollAttacks() {
    setState(() {
      _summary = widget.session.performBatchAttack(
        targetAc: _targetAc,
        advantageMode: _advantageMode,
        useMaximizedCrits: _useMaximizedCrits,
      );

      final activeCode = widget.activeRoomCode ?? DiceRoomService().activeRoomCode;
      final activePlayer = widget.playerName ?? DiceRoomService().playerName;

      if (_summary != null && activeCode != null && activePlayer != null) {
        final roomService = DiceRoomService();

        // 1. Broadcast summary roll for overall batch results
        final summaryRoll = RoomRoll(
          id: '${DateTime.now().microsecondsSinceEpoch}_summary',
          roomCode: activeCode,
          playerName: activePlayer,
          timestamp: DateTime.now(),
          formulaString: 'Animate Objects Batch (${_summary!.totalHits}/${_summary!.totalAttacks} Hits vs AC $_targetAc)',
          total: _summary!.totalDamage,
          individualRolls: _summary!.results.map((r) => r.totalDamage).toList(),
          isCrit: _summary!.totalCrits > 0,
          isFumble: false,
        );
        roomService.broadcastRoll(summaryRoll);

        // 2. Broadcast each object attack roll detail
        for (int i = 0; i < _summary!.results.length; i++) {
          final res = _summary!.results[i];
          final obj = res.object;

          String statusText = res.isCrit ? 'CRIT!' : (res.isHit ? 'HIT' : 'MISS');
          String formulaStr = '${obj.name} (${obj.size.displayName}) +${obj.size.attackBonus} vs AC $_targetAc [$statusText]';

          final objRoll = RoomRoll(
            id: '${DateTime.now().microsecondsSinceEpoch}_$i',
            roomCode: activeCode,
            playerName: activePlayer,
            timestamp: DateTime.now(),
            formulaString: formulaStr,
            total: res.totalDamage,
            individualRolls: [res.totalToHit, ...res.damageRolls],
            isCrit: res.isCrit,
            isFumble: res.finalD20 == 1,
          );
          roomService.broadcastRoll(objRoll);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final livingCount = widget.session.activeObjects.where((o) => !o.isDead).length;
    final currentRoomCode = widget.activeRoomCode ?? DiceRoomService().activeRoomCode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 500;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      backgroundColor: const Color(0xFF1E1B2E),
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
                                child: SegmentedButton<RollAdvantage>(
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
                                    ButtonSegment(value: RollAdvantage.disadvantage, label: Text('Dis', style: TextStyle(fontSize: 12))),
                                    ButtonSegment(value: RollAdvantage.normal, label: Text('Norm', style: TextStyle(fontSize: 12))),
                                    ButtonSegment(value: RollAdvantage.advantage, label: Text('Adv', style: TextStyle(fontSize: 12))),
                                  ],
                                  selected: {_advantageMode},
                                  onSelectionChanged: (set) => setState(() => _advantageMode = set.first),
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
                      const SizedBox(height: 12),

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
