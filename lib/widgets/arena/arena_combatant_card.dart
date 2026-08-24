import 'package:flutter/material.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/dm_screen_data.dart';
import 'arena_combatant_token.dart';
import 'arena_condition_chip.dart';
import 'arena_condition_toggle_dialog.dart';

/// Interactive fighter card in the Arena team roster.
class ArenaCombatantCard extends StatelessWidget {
  final ArenaCombatant combatant;
  final bool isCurrentTurn;
  final bool isTargeted;
  final bool isSetupMode;
  final DmRulesEdition edition;
  final VoidCallback? onRemove;
  final VoidCallback? onDuplicate;
  final VoidCallback? onConditionsChanged;

  const ArenaCombatantCard({
    super.key,
    required this.combatant,
    this.isCurrentTurn = false,
    this.isTargeted = false,
    this.isSetupMode = false,
    this.edition = DmRulesEdition.v2024,
    this.onRemove,
    this.onDuplicate,
    this.onConditionsChanged,
  });


  Color _getHpColor(double percent) {
    if (percent <= 0) return Colors.grey;
    if (percent > 0.5) return const Color(0xFF10B981); // Emerald Green
    if (percent > 0.25) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Crimson Red
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teamColor = combatant.team.color;
    final sb = combatant.getStatBlock(edition);
    final hpPercent = combatant.hpPercent;
    final hpColor = _getHpColor(hpPercent);
    final isDefeated = combatant.isDefeated;

    Color borderColor;
    double borderWidth = 1.0;
    List<BoxShadow>? shadows;

    if (isCurrentTurn) {
      borderColor = const Color(0xFFFFD700); // Radiant Gold
      borderWidth = 2.0;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD700).withAlpha(120),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];
    } else if (isTargeted) {
      borderColor = Colors.redAccent;
      borderWidth = 2.0;
      shadows = [
        BoxShadow(
          color: Colors.redAccent.withAlpha(100),
          blurRadius: 8,
        ),
      ];
    } else if (isDefeated) {
      borderColor = isDark ? const Color(0xFF333846) : const Color(0xFFCBD5E1);
    } else {
      borderColor = teamColor.withAlpha(isDark ? 80 : 120);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: isDefeated
            ? (isDark ? const Color(0xFF181A22).withAlpha(150) : const Color(0xFFF1F5F9))
            : (isDark ? const Color(0xFF1E2230) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: Token Avatar, Name, CR, Conditions, Actions/Controls
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ArenaCombatantToken(
                  combatant: combatant,
                  size: 36,
                  isCurrentTurn: isCurrentTurn,
                  isTargeted: isTargeted,
                  edition: edition,
                  showConditionChips: false,
                  onConditionsChanged: onConditionsChanged,
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
                              combatant.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                decoration: isDefeated ? TextDecoration.lineThrough : null,
                                color: isDefeated
                                    ? (isDark ? Colors.white38 : Colors.black38)
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                          if (isCurrentTurn) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD700).withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFFD700), width: 1),
                              ),
                              child: const Text(
                                'TURN',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          Text(
                            'CR ${sb.crDisplay} • AC ${combatant.ac}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          if (combatant.initiative > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: teamColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Init ${combatant.initiative}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: teamColor,
                                ),
                              ),
                            ),
                          if (combatant.canFly(edition))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '🪽 Fly',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                          if (combatant.canSwim(edition))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '🏊 Swim',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ),
                          if (combatant.hasEvasion(edition))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amberAccent.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '⚡ Evasion',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ),
                          if (combatant.activeConcentrationSpellId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent.withAlpha(35),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purpleAccent, width: 0.8),
                              ),
                              child: const Text(
                                '🔮 Conc',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purpleAccent,
                                ),
                              ),
                            ),
                          if (combatant.isSpellcaster && combatant.maxSpellSlots.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.indigoAccent.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '✨ Slots ${combatant.currentSpellSlots.values.fold(0, (a, b) => a + b)}/${combatant.maxSpellSlots.values.fold(0, (a, b) => a + b)}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigoAccent,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Dynamic Status Condition Chips Row
                      if (combatant.activeConditions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ArenaConditionChipsBar(
                          conditions: combatant.activeConditions,
                          isDense: true,
                          maxVisible: 3,
                          onRemoveCondition: (c) {
                            combatant.removeCondition(c);
                            onConditionsChanged?.call();
                          },
                          onManageConditions: () {
                            ArenaConditionToggleDialog.show(
                              context,
                              combatant: combatant,
                              onUpdated: onConditionsChanged,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSetupMode) ...[
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Duplicate',
                    onPressed: onDuplicate,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Remove',
                    onPressed: onRemove,
                  ),
                ] else ...[
                  IconButton(
                    icon: Icon(
                      combatant.conditions.isNotEmpty
                          ? Icons.medical_information
                          : Icons.medical_information_outlined,
                      size: 16,
                      color: combatant.conditions.isNotEmpty
                          ? Colors.amberAccent
                          : (isDark ? Colors.white38 : Colors.black38),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Status Conditions (${combatant.conditions.length})',
                    onPressed: () {
                      ArenaConditionToggleDialog.show(
                        context,
                        combatant: combatant,
                        onUpdated: onConditionsChanged,
                      );
                    },
                  ),
                  if (isDefeated)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Icon(Icons.sentiment_very_dissatisfied, color: Colors.grey, size: 18),
                    ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Row 2: HP Bar with numeric readout
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDefeated ? 'DEFEATED' : 'HP ${combatant.currentHp} / ${combatant.maxHp}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDefeated ? Colors.grey : hpColor,
                      ),
                    ),
                    if (!isSetupMode && (combatant.totalDamageDealt > 0 || combatant.kills > 0))
                      Text(
                        'Dealt: ${combatant.totalDamageDealt} dmg${combatant.kills > 0 ? ' • ${combatant.kills} kills' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hpPercent,
                    backgroundColor: isDark ? const Color(0xFF13151F) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
