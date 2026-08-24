import 'package:flutter/material.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/dm_screen_data.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../glyphs/dnd_glyph.dart';
import 'arena_condition_chip.dart';
import 'arena_condition_toggle_dialog.dart';

/// Reusable combatant token widget displaying creature avatar, HP indicators,
/// team styling, and dynamic condition chip overlays with overflow management.
class ArenaCombatantToken extends StatelessWidget {
  final ArenaCombatant combatant;
  final double size;
  final bool isCurrentTurn;
  final bool isTargeted;
  final bool showConditionChips;
  final bool interactive;
  final DmRulesEdition edition;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onConditionsChanged;

  const ArenaCombatantToken({
    super.key,
    required this.combatant,
    this.size = 64,
    this.isCurrentTurn = false,
    this.isTargeted = false,
    this.showConditionChips = true,
    this.interactive = true,
    this.edition = DmRulesEdition.v2024,
    this.onTap,
    this.onLongPress,
    this.onConditionsChanged,
  });

  void _openConditionDialog(BuildContext context) {
    ArenaConditionToggleDialog.show(
      context,
      combatant: combatant,
      onUpdated: onConditionsChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teamColor = combatant.team.color;
    final sb = combatant.getStatBlock(edition);
    final isDefeated = combatant.isDefeated;

    Color borderColor;
    double borderWidth = size > 50 ? 2.5 : 1.8;
    List<BoxShadow> shadows = [];

    if (isCurrentTurn) {
      borderColor = const Color(0xFFFFD700); // Gold
      borderWidth = size > 50 ? 3.0 : 2.2;
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD700).withAlpha(isDark ? 140 : 100),
          blurRadius: size > 50 ? 12 : 8,
          spreadRadius: 1,
        ),
      ];
    } else if (isTargeted) {
      borderColor = Colors.redAccent;
      borderWidth = size > 50 ? 3.0 : 2.2;
      shadows = [
        BoxShadow(
          color: Colors.redAccent.withAlpha(isDark ? 140 : 100),
          blurRadius: size > 50 ? 10 : 6,
          spreadRadius: 1,
        ),
      ];
    } else if (isDefeated) {
      borderColor = isDark ? const Color(0xFF3B4252) : const Color(0xFFCBD5E1);
    } else {
      borderColor = teamColor;
      shadows = [
        BoxShadow(
          color: teamColor.withAlpha(isDark ? 50 : 30),
          blurRadius: 6,
        ),
      ];
    }

    final avatar = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Outer Container with Team & State Border
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDefeated
                ? (isDark ? const Color(0xFF161822) : const Color(0xFFF1F5F9))
                : (isDark ? const Color(0xFF1E2230) : Colors.white),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glyph creature icon
                Opacity(
                  opacity: isDefeated ? 0.35 : 1.0,
                  child: DndGlyph.monster(
                    creatureType: sb.glyphCreatureType,
                    crTier: sb.glyphCrTier,
                    actionRings: sb.glyphActionRings,
                    glyphColor: isDefeated ? Colors.grey : teamColor,
                    size: size * 0.72,
                    isDarkMode: isDark,
                  ),
                ),

                // Defeated X icon
                if (isDefeated)
                  Icon(
                    Icons.close,
                    size: size * 0.6,
                    color: Colors.redAccent.withAlpha(180),
                  ),
              ],
            ),
          ),
        ),

        // Mini Badges (Fly / Swim / Concentration) on top-right
        if (!isDefeated && (combatant.isAirborne || combatant.activeConcentrationSpellId != null))
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: combatant.activeConcentrationSpellId != null
                    ? Colors.purpleAccent
                    : Colors.cyanAccent,
                border: Border.all(
                  color: isDark ? const Color(0xFF13151F) : Colors.white,
                  width: 1.5,
                ),
              ),
              child: Icon(
                combatant.activeConcentrationSpellId != null
                    ? Icons.psychology
                    : Icons.air,
                size: size > 50 ? 10 : 8,
                color: Colors.black,
              ),
            ),
          ),

        // Dynamic Condition Chips Overlay positioned along the bottom edge
        if (showConditionChips && combatant.activeConditions.isNotEmpty)
          Positioned(
            bottom: size > 50 ? -8 : -5,
            left: -size * 0.5,
            right: -size * 0.5,
            child: Center(
              child: ArenaConditionChipsBar(
                conditions: combatant.activeConditions,
                isDense: size <= 60,
                onRemoveCondition: interactive
                    ? (c) {
                        combatant.removeCondition(c);
                        onConditionsChanged?.call();
                      }
                    : null,
                onManageConditions: interactive
                    ? () => _openConditionDialog(context)
                    : null,
              ),
            ),
          ),
      ],
    );

    if (!interactive) return avatar;

    return InkWell(
      onTap: onTap ?? () => _openConditionDialog(context),
      onLongPress: onLongPress ?? () => _openConditionDialog(context),
      borderRadius: BorderRadius.circular(size),
      child: avatar,
    );
  }
}
