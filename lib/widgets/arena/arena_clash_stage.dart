import 'package:flutter/material.dart';
import '../../models/arena/arena_action_result.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/dm_screen_data.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../glyphs/dnd_glyph.dart';

/// Central dynamic clash arena visualizer displaying current turn combat actions,
/// dice roll animations, hit/crit banners, and playback control buttons.
class ArenaClashStage extends StatelessWidget {
  final ArenaTurnStep? currentStep;
  final ArenaCombatant? activeAttacker;
  final ArenaCombatant? activeDefender;
  final bool isPlaying;
  final double playbackSpeed;
  final DmRulesEdition edition;
  final VoidCallback onTogglePlay;
  final VoidCallback onStepForward;
  final VoidCallback onSkipToEnd;
  final VoidCallback onResetMatch;
  final ValueChanged<double> onSpeedChanged;

  const ArenaClashStage({
    super.key,
    required this.currentStep,
    required this.activeAttacker,
    required this.activeDefender,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.edition,
    required this.onTogglePlay,
    required this.onStepForward,
    required this.onSkipToEnd,
    required this.onResetMatch,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final latestEvent = currentStep?.attackEvents.isNotEmpty == true
        ? currentStep!.attackEvents.last
        : null;

    final attacker = activeAttacker;
    final defender = activeDefender;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black12,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Round & Turn Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2230) : const Color(0xFFE2E8F0),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sports_kabaddi,
                      size: 18,
                      color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentStep != null
                          ? 'ROUND ${currentStep!.roundNumber} • STEP #${currentStep!.stepIndex + 1}'
                          : 'ARENA STAGE READY',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                      ),
                    ),
                  ],
                ),
                if (currentStep?.specialEventSummary != null)
                  Flexible(
                    child: Text(
                      currentStep!.specialEventSummary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Combat Clash Stage Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Attacker Avatar & Badge
                _buildCombatantStageSlot(
                  context,
                  combatant: attacker,
                  roleLabel: 'ATTACKER',
                  isAttacking: true,
                  isDark: isDark,
                ),

                // Center Action Outcome (Versus / Dice / Damage)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (latestEvent != null) ...[
                          // Action / Attack Name
                          Text(
                            latestEvent.attackName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // D20 Roll & Result Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDicePill(latestEvent, isDark),
                              const SizedBox(width: 6),
                              _buildOutcomeBadge(latestEvent),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Damage Dealt Pill
                          if (latestEvent.isHit)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.redAccent.withAlpha(120), width: 1),
                              ),
                              child: Text(
                                '-${latestEvent.damageDealt} ${latestEvent.damageType.toUpperCase()}${latestEvent.isKillShot ? ' (FATAL)' : ''}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ] else ...[
                          const Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Press Play or Step Forward',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Defender Avatar & Badge
                _buildCombatantStageSlot(
                  context,
                  combatant: defender,
                  roleLabel: 'DEFENDER',
                  isAttacking: false,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Playback Controls Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Play / Pause & Step Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 20),
                      label: Text(isPlaying ? 'Pause' : 'Play'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPlaying ? Colors.amber : const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onTogglePlay,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('Step'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isPlaying ? null : onStepForward,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.fast_forward, size: 18),
                      label: const Text('Skip to End'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onSkipToEnd,
                    ),
                  ],
                ),

                // Speed Selector & Reset
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speed Pills
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2230) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [0.5, 1.0, 2.0, 5.0].map((spd) {
                          final isSel = (playbackSpeed - spd).abs() < 0.1;
                          return InkWell(
                            onTap: () => onSpeedChanged(spd),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFFC084FC) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${spd == 0.5 ? '0.5' : spd.toInt()}x',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Reset Match',
                      onPressed: onResetMatch,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombatantStageSlot(
    BuildContext context, {
    required ArenaCombatant? combatant,
    required String roleLabel,
    required bool isAttacking,
    required bool isDark,
  }) {
    if (combatant == null) {
      return Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.withAlpha(40),
            child: const Icon(Icons.question_mark, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(roleLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      );
    }

    final teamColor = combatant.team.color;
    final sb = combatant.getStatBlock(edition);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isAttacking ? const Color(0xFFFFD700) : teamColor,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isAttacking
                        ? const Color(0xFFFFD700).withAlpha(100)
                        : teamColor.withAlpha(60),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: DndGlyph.monster(
                  creatureType: sb.glyphCreatureType,
                  crTier: sb.glyphCrTier,
                  actionRings: sb.glyphActionRings,
                  glyphColor: teamColor,
                  size: 42,
                  isDarkMode: isDark,
                ),
              ),
            ),
            Positioned(
              bottom: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isAttacking ? const Color(0xFFFFD700) : teamColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 95),
          child: Text(
            combatant.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          'HP ${combatant.currentHp}/${combatant.maxHp}',
          style: TextStyle(
            fontSize: 11,
            color: teamColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDicePill(ArenaAttackEvent event, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: event.isCrit
              ? const Color(0xFFFFD700)
              : (event.isFumble ? Colors.redAccent : Colors.grey.withAlpha(80)),
        ),
      ),
      child: Text(
        'd20: ${event.d20Roll}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: event.isCrit
              ? const Color(0xFFFFD700)
              : (event.isFumble ? Colors.redAccent : (isDark ? Colors.white : Colors.black87)),
        ),
      ),
    );
  }

  Widget _buildOutcomeBadge(ArenaAttackEvent event) {
    Color bg;
    Color fg;
    String label;

    if (event.isCrit) {
      bg = const Color(0xFFFFD700);
      fg = Colors.black;
      label = 'CRITICAL HIT';
    } else if (event.isFumble) {
      bg = Colors.redAccent;
      fg = Colors.white;
      label = 'FUMBLE';
    } else if (event.isHit) {
      bg = const Color(0xFF10B981);
      fg = Colors.white;
      label = 'HIT (vs AC ${event.targetAc})';
    } else {
      bg = Colors.grey;
      fg = Colors.white;
      label = 'MISS (vs AC ${event.targetAc})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
