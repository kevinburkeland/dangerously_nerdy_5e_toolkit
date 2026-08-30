import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../providers/character_sheet_controller.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';

/// Horizontal ribbon / responsive grid displaying the 6 core ability scores,
/// calculated modifiers, magic item indicators, and quick-roll triggers.
class AbilityScoresRibbon extends StatelessWidget {
  final CharacterSheetController controller;
  final void Function(AbilityType ability, int modifier)? onRollCheck;

  const AbilityScoresRibbon({
    super.key,
    required this.controller,
    this.onRollCheck,
  });

  @override
  Widget build(BuildContext context) {
    final stats = controller.stats;
    final baseScores = controller.character.baseScores;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 450 ? 3 : 6;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
          children: AbilityType.values.map((ability) {
            final effectiveScore = stats.effectiveScores.getScore(ability);
            final baseScore = baseScores.getScore(ability);
            final mod = stats.abilityModifiers[ability] ?? 0;
            final isModified = effectiveScore != baseScore;

            return _buildAbilityCard(
              context,
              ability: ability,
              score: effectiveScore,
              modifier: mod,
              isModified: isModified,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAbilityCard(
    BuildContext context, {
    required AbilityType ability,
    required int score,
    required int modifier,
    required bool isModified,
  }) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();
    final modString = modifier >= 0 ? '+$modifier' : '$modifier';

    return InkWell(
      onTap: () {
        HapticService.selectionTick(context);
        if (onRollCheck != null) {
          onRollCheck!(ability, modifier);
        } else {
          _showRollFeedback(context, ability, modifier);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isModified
                ? (customColors?.critGold ?? Colors.amber)
                : (customColors?.cardBorder ?? theme.colorScheme.outlineVariant),
            width: isModified ? 1.5 : 1.0,
          ),
          boxShadow: isModified
              ? [
                  BoxShadow(
                    color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Ability Header
            Text(
              ability.shortName,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isModified
                    ? (customColors?.critGold ?? Colors.amber)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // Big Modifier Numerals
            Text(
              modString,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: modifier >= 0 ? theme.colorScheme.primary : Colors.red.shade400,
              ),
            ),
            // Base/Effective Score Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isModified
                      ? (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$score',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRollFeedback(BuildContext context, AbilityType ability, int mod) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rolling ${ability.shortName} Check: 1d20 ${mod >= 0 ? "+$mod" : "$mod"}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
