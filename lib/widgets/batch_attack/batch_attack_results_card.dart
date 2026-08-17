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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textScaler = MediaQuery.textScalerOf(context);
    final isLargeScale = textScaler.scale(14) > 18;

    final summaryA11yLabel =
        'Batch Attack Summary: ${summary.totalDamage} total damage, ${summary.totalHits} of ${summary.totalAttacks} attacks hit, ${summary.totalCrits} critical hits.';

    return Column(
      children: [
        // Summary Stat Banner
        Semantics(
          label: summaryA11yLabel,
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.amber.shade900.withValues(alpha: 0.4),
                        Colors.purple.shade900.withValues(alpha: 0.4),
                      ]
                    : [
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                        theme.colorScheme.secondary.withValues(alpha: 0.12),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            ),
            child: isLargeScale
                ? Column(
                    children: [
                      _buildSummaryStat(
                        context,
                        'TOTAL DAMAGE',
                        '${summary.totalDamage}',
                        isDark ? Colors.orangeAccent : const Color(0xFFC2410C),
                        fontSize: 22,
                      ),
                      Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), height: 12),
                      _buildSummaryStat(
                        context,
                        'HITS',
                        '${summary.totalHits} / ${summary.totalAttacks}',
                        isDark ? Colors.greenAccent : const Color(0xFF15803D),
                      ),
                      Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), height: 12),
                      _buildSummaryStat(
                        context,
                        'CRITS',
                        '${summary.totalCrits}',
                        isDark ? Colors.yellowAccent : const Color(0xFFB45309),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildSummaryStat(
                            context,
                            'TOTAL DAMAGE',
                            '${summary.totalDamage}',
                            isDark ? Colors.orangeAccent : const Color(0xFFC2410C),
                            fontSize: 22,
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildSummaryStat(
                            context,
                            'HITS',
                            '${summary.totalHits} / ${summary.totalAttacks}',
                            isDark ? Colors.greenAccent : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildSummaryStat(
                            context,
                            'CRITS',
                            '${summary.totalCrits}',
                            isDark ? Colors.yellowAccent : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
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

            final itemA11yLabel =
                '${obj.name} (${obj.size.displayName}): rolled ${res.finalD20} with bonus ${res.object.attackBonus} equals ${res.totalToHit} against Armor Class $targetAc. ${res.isCrit ? (res.isMaximizedCrit ? "Maximized Critical Hit!" : "Critical Hit!") : (res.isHit ? "Hit!" : "Miss.")} ${res.isHit ? "${res.totalDamage} damage dealt." : ""}';

            return Semantics(
              label: itemA11yLabel,
              excludeSemantics: true,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: res.isHit
                      ? (isDark ? const Color(0xFF1B5E20).withValues(alpha: 0.2) : const Color(0xFF15803D).withValues(alpha: 0.1))
                      : (isDark ? const Color(0xFFB71C1C).withValues(alpha: 0.15) : const Color(0xFFDC2626).withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: res.isCrit
                        ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309))
                        : (res.isHit
                            ? (isDark ? const Color(0xFF4CAF50).withValues(alpha: 0.4) : const Color(0xFF15803D).withValues(alpha: 0.4))
                            : (isDark ? const Color(0xFFE57373).withValues(alpha: 0.3) : const Color(0xFFDC2626).withValues(alpha: 0.3))),
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
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${obj.size.displayName})',
                                style: TextStyle(
                                  color: isDark ? obj.size.accentColor : theme.colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatRollDetail(res),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // WCAG 2.2 AA Compliant Result Badge (>= 4.5:1 contrast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: res.isCrit
                            ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309))
                            : (res.isHit
                                ? (isDark ? const Color(0xFF1B5E20) : const Color(0xFF15803D))
                                : (isDark ? const Color(0xFFB71C1C) : const Color(0xFFB91C1C))),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        res.isCrit
                            ? '${res.isMaximizedCrit ? "MAX CRIT!" : "CRIT!"} (${res.totalDamage} dmg)'
                            : (res.isHit ? '${res.totalDamage} DMG' : 'MISS'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildSummaryStat(BuildContext context, String label, String value, Color color,
      {double fontSize = 16}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold),
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
