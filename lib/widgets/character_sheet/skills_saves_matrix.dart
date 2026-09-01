import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../models/domain/character_models.dart';
import '../../models/room_roll.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/dice_room_service.dart';
import '../../services/haptic_service.dart';
import '../../utils/secure_random.dart';

/// Interactive Skills and Saving Throws matrix with global Advantage/Disadvantage roll mode toggling,
/// accessible tap targets (min 48dp height), and live DiceRoom roll broadcasting.
class SkillsSavesMatrix extends StatefulWidget {
  final CharacterSheetController controller;

  const SkillsSavesMatrix({
    super.key,
    required this.controller,
  });

  @override
  State<SkillsSavesMatrix> createState() => _SkillsSavesMatrixState();
}

class _SkillsSavesMatrixState extends State<SkillsSavesMatrix> {
  RollMode _rollMode = RollMode.normal;

  void _dispatchRoll({
    required String title,
    required String subtitle,
    required int modifier,
  }) {
    HapticService.lightImpact(context);

    final rollResult = DiceRollResult.roll(
      dieType: DieType.d20,
      modifier: modifier,
      rollMode: _rollMode,
    );

    final roomService = DiceRoomService();
    final activeRoom = roomService.activeRoomCode;
    final characterName = widget.controller.character.name.isNotEmpty
        ? widget.controller.character.name
        : 'Player';

    if (activeRoom != null) {
      final roomRoll = RoomRoll.fromDiceRollResult(
        id: 'roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
        roomCode: activeRoom,
        playerName: characterName,
        result: rollResult,
        details: ['$title ($subtitle)'],
      );
      roomService.broadcastRoll(roomRoll);
    }

    String rollDetail = '';
    if (rollResult.droppedRolls != null && rollResult.droppedRolls!.isNotEmpty) {
      final kept = rollResult.individualRolls.first;
      final dropped = rollResult.droppedRolls!.first;
      final modeLabel = _rollMode == RollMode.advantage ? 'Adv' : 'Dis';
      rollDetail = ' [$modeLabel: kept $kept, dropped $dropped]';
    } else {
      rollDetail = ' [d20: ${rollResult.individualRolls.first}]';
    }

    final modStr = modifier >= 0 ? '+$modifier' : '$modifier';
    final critText = rollResult.isCrit ? ' 🌟 NATURAL 20!' : (rollResult.isFumble ? ' 💀 NATURAL 1!' : '');

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        content: Row(
          children: [
            Icon(
              rollResult.isCrit
                  ? Icons.star
                  : (rollResult.isFumble ? Icons.warning_amber_rounded : Icons.casino_outlined),
              color: rollResult.isCrit
                  ? Colors.amberAccent
                  : (rollResult.isFumble ? Colors.redAccent : Theme.of(context).colorScheme.primary),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '[$characterName] $title $modStr ➔ ${rollResult.total}$rollDetail$critText',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.controller.stats;
    final profBonus = stats.proficiencyBonus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Roll Mode Selector Bar
        _buildRollModeSelector(context),
        const SizedBox(height: 14),

        // Saving Throws Section
        Text(
          'SAVING THROWS (6)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        _buildSavesGrid(context),
        const SizedBox(height: 18),

        // Skills Section Header
        Text(
          'SKILLS (18)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        _buildSkillsList(context, profBonus),
      ],
    );
  }

  Widget _buildRollModeSelector(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.casino, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'ROLL MODE:',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SegmentedButton<RollMode>(
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: const [
              ButtonSegment<RollMode>(
                value: RollMode.disadvantage,
                label: Text('Dis', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.arrow_downward, size: 12),
              ),
              ButtonSegment<RollMode>(
                value: RollMode.normal,
                label: Text('Norm', style: TextStyle(fontSize: 11)),
              ),
              ButtonSegment<RollMode>(
                value: RollMode.advantage,
                label: Text('Adv', style: TextStyle(fontSize: 11)),
                icon: Icon(Icons.arrow_upward, size: 12),
              ),
            ],
            selected: {_rollMode},
            onSelectionChanged: (Set<RollMode> newSelection) {
              HapticService.selectionTick(context);
              setState(() {
                _rollMode = newSelection.first;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSavesGrid(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.controller.stats;
    final character = widget.controller.character;

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: AbilityType.values.map((ability) {
        final mod = stats.savingThrowModifiers[ability] ?? 0;
        final isProf = character.savingThrowProficiencies.contains(ability);
        final modStr = mod >= 0 ? '+$mod' : '$mod';

        return Semantics(
          button: true,
          label: '${ability.name} saving throw modifier $modStr',
          child: Material(
            color: isProf
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isProf ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _dispatchRoll(
                title: '${ability.shortName} Save',
                subtitle: ability.name,
                modifier: mod,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isProf ? Icons.check_circle : Icons.circle_outlined,
                            size: 13,
                            color: isProf ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ability.shortName,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        modStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isProf ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsList(BuildContext context, int profBonus) {
    final theme = Theme.of(context);
    final stats = widget.controller.stats;
    final character = widget.controller.character;

    return Column(
      children: SkillType.values.map((skill) {
        final profLevel = character.skillProficiencies[skill] ?? SkillProficiencyLevel.none;
        final ability = skill.defaultAbility;
        final baseAbilityMod = stats.abilityModifiers[ability] ?? 0;
        final skillMod = stats.skillModifiers[skill] ?? (baseAbilityMod + (profBonus * profLevel.multiplier).toInt());
        final modStr = skillMod >= 0 ? '+$skillMod' : '$skillMod';
        final isTrained = profLevel != SkillProficiencyLevel.none;

        return Semantics(
          button: true,
          label: '${skill.displayName} (${ability.shortName}) modifier $modStr, ${profLevel.name}',
          child: Material(
            color: isTrained
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.18)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isTrained
                  ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.25))
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _dispatchRoll(
                title: skill.displayName,
                subtitle: '${ability.shortName} Skill',
                modifier: skillMod,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      _buildProficiencyPip(profLevel, theme),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              skill.displayName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isTrained ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${ability.shortName})',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTrained
                              ? theme.colorScheme.primary.withValues(alpha: 0.15)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          modStr,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isTrained ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProficiencyPip(SkillProficiencyLevel level, ThemeData theme) {
    return switch (level) {
      SkillProficiencyLevel.none => Icon(
          Icons.circle_outlined,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      SkillProficiencyLevel.jackOfAllTrades => Icon(
          Icons.adjust,
          size: 14,
          color: theme.colorScheme.tertiary,
        ),
      SkillProficiencyLevel.proficient => Icon(
          Icons.check_circle,
          size: 14,
          color: theme.colorScheme.primary,
        ),
      SkillProficiencyLevel.expertise => Icon(
          Icons.stars,
          size: 14,
          color: theme.colorScheme.primary,
        ),
    };
  }
}
