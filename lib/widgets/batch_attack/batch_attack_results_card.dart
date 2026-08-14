import 'package:flutter/material.dart';
import '../../models/spell_session.dart';

class BatchAttackResultsCard extends StatelessWidget {
  final BatchAttackSummary summary;
  final int targetAc;

  const BatchAttackResultsCard({
    super.key,
    required this.summary,
    required this.targetAc,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Summary Stat Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildSummaryStat(
                    'TOTAL DAMAGE',
                    '${summary.totalDamage}',
                    Colors.orangeAccent,
                    fontSize: 22,
                  ),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildSummaryStat(
                    'HITS',
                    '${summary.totalHits} / ${summary.totalAttacks}',
                    Colors.greenAccent,
                  ),
                ),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildSummaryStat(
                    'CRITS',
                    '${summary.totalCrits}',
                    Colors.yellowAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Detailed Attack Breakdown List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: summary.results.length,
          itemBuilder: (context, index) {
            final res = summary.results[index];
            final obj = res.object;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: res.isHit
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: res.isCrit
                      ? Colors.amber
                      : (res.isHit
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 36,
                    decoration: BoxDecoration(
                      color: obj.size.accentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                obj.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
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
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Result Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatRollDetail(AttackRollResult res) {
    String rollStr;
    if (res.d20Roll2 != null) {
      rollStr = 'd20: [${res.d20Roll1}, ${res.d20Roll2}] -> ${res.finalD20}';
    } else {
      rollStr = 'd20: ${res.finalD20}';
    }

    String toHitStr =
        '$rollStr + ${res.object.attackBonus} = ${res.totalToHit} vs AC $targetAc';

    if (res.isHit) {
      String dmgDetails;
      if (res.isMaximizedCrit && res.maxedRolls != null) {
        dmgDetails =
            'Max: [${res.maxedRolls!.join("+")}] + Roll: [${res.damageRolls.join("+")}]';
      } else {
        dmgDetails =
            'Dice: [${res.damageRolls.join("+")}]';
      }

      if (res.secondaryDamageRolls != null && res.secondaryDamageRolls!.isNotEmpty) {
        dmgDetails += ' + Sec: [${res.secondaryDamageRolls!.join("+")}]';
      }

      if (res.damageBonus != 0) {
        dmgDetails += ' + ${res.damageBonus}';
      }

      return '$toHitStr | $dmgDetails';
    } else {
      return toHitStr;
    }
  }

  Widget _buildSummaryStat(String label, String value, Color color,
      {double fontSize = 16}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: fontSize, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
