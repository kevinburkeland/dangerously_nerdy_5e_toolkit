import 'package:flutter/material.dart';
import '../models/animated_object.dart';
import '../models/room_roll.dart';
import '../models/spell_session.dart';
import '../services/dice_room_service.dart';

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

    return Dialog(
      backgroundColor: const Color(0xFF1E1B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Attack Roller',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (currentRoomCode != null)
                          Row(
                            children: [
                              const Icon(Icons.sensors, color: Colors.cyanAccent, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Broadcasting to Room: $currentRoomCode',
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),

            if (livingCount == 0)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No living animated objects available to attack!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
              )
            else ...[
              // Controls Row: Target AC & Advantage Toggle
              Row(
                children: [
                  // Target AC Input
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Target AC', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
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
                    ),
                  ),

                  // Advantage Toggle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Roll Mode', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      SegmentedButton<RollAdvantage>(
                        style: ButtonStyle(
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
                          ButtonSegment(value: RollAdvantage.disadvantage, label: Text('Dis')),
                          ButtonSegment(value: RollAdvantage.normal, label: Text('Norm')),
                          ButtonSegment(value: RollAdvantage.advantage, label: Text('Adv')),
                        ],
                        selected: {_advantageMode},
                        onSelectionChanged: (set) => setState(() => _advantageMode = set.first),
                      ),
                    ],
                  ),
                ],
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
                        Text(
                          'Maximized Criticals',
                          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
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
              ElevatedButton.icon(
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),

              // Results Summary Banner
              if (_summary != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade900.withValues(alpha: 0.4),
                        Colors.purple.shade900.withValues(alpha: 0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryStat(
                            'TOTAL DAMAGE',
                            '${_summary!.totalDamage}',
                            Colors.orangeAccent,
                            fontSize: 22,
                          ),
                          _buildSummaryStat(
                            'HITS',
                            '${_summary!.totalHits} / ${_summary!.totalAttacks}',
                            Colors.greenAccent,
                          ),
                          _buildSummaryStat(
                            'CRITS',
                            '${_summary!.totalCrits}',
                            Colors.yellowAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Detailed Attack Breakdown List
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _summary!.results.length,
                    itemBuilder: (context, index) {
                      final res = _summary!.results[index];
                      final obj = res.object;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: res.isHit
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: res.isCrit
                                ? Colors.amber
                                : (res.isHit ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.2)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 36,
                              decoration: BoxDecoration(
                                color: obj.size.accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        obj.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${obj.size.displayName})',
                                        style: TextStyle(
                                          color: obj.size.accentColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatRollDetail(res),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Result Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: res.isCrit
                                    ? Colors.amber
                                    : (res.isHit ? Colors.green : Colors.red.shade900),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                res.isCrit
                                    ? '${res.isMaximizedCrit ? "MAX CRIT!" : "CRIT!"} (${res.totalDamage} dmg)'
                                    : (res.isHit ? '${res.totalDamage} DMG' : 'MISS'),
                                style: TextStyle(
                                  color: res.isCrit ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatRollDetail(AttackRollResult res) {
    String rollStr;
    if (res.d20Roll2 != null) {
      rollStr = 'd20: [${res.d20Roll1}, ${res.d20Roll2}] -> ${res.finalD20}';
    } else {
      rollStr = 'd20: ${res.finalD20}';
    }

    String toHitStr = '$rollStr + ${res.object.size.attackBonus} = ${res.totalToHit} vs AC $_targetAc';

    if (res.isHit) {
      String dmgDetails;
      if (res.isMaximizedCrit && res.maxedRolls != null) {
        dmgDetails = 'Max: [${res.maxedRolls!.join("+")}] + Roll: [${res.damageRolls.join("+")}] + ${res.damageBonus}';
      } else {
        dmgDetails = 'Dice: ${res.damageRolls.join("+")} + ${res.damageBonus}';
      }
      return '$toHitStr | $dmgDetails';
    } else {
      return toHitStr;
    }
  }

  Widget _buildSummaryStat(String label, String value, Color color, {double fontSize = 16}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
