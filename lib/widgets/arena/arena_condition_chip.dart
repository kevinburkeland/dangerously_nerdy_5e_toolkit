import 'package:dangerously_nerdy_5e_toolkit/theme/domain_ui_extensions.dart';
import 'package:flutter/material.dart';
import '../../models/arena/arena_condition.dart';

/// Interactive micro-chip for an [ActiveCondition] on fighter tokens and combatant cards.
class ArenaConditionChip extends StatelessWidget {
  final ActiveCondition activeCondition;
  final bool isDense;
  final bool showLabel;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const ArenaConditionChip({
    super.key,
    required this.activeCondition,
    this.isDense = false,
    this.showLabel = false,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = activeCondition.colorTheme;
    final cond = activeCondition.condition;

    final tooltipContent = '${cond.label}'
        '${activeCondition.hasFiniteDuration ? ' (${activeCondition.durationDisplay})' : ''}'
        '${activeCondition.source != null ? ' • ${activeCondition.source}' : ''}\n'
        '${cond.penaltySummary}';

    final chipWidget = InkWell(
      onTap: onTap ?? onRemove,
      borderRadius: BorderRadius.circular(isDense ? 6 : 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isDense ? 4 : 6,
          vertical: isDense ? 1.5 : 3,
        ),
        decoration: BoxDecoration(
          color: isDark ? color.withAlpha(45) : color.withAlpha(35),
          borderRadius: BorderRadius.circular(isDense ? 6 : 8),
          border: Border.all(
            color: color.withAlpha(isDark ? 200 : 160),
            width: isDense ? 0.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(isDark ? 50 : 30),
              blurRadius: isDense ? 3 : 5,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              cond.icon,
              size: isDense ? 10 : 13,
              color: color,
            ),
            if (showLabel) ...[
              const SizedBox(width: 3),
              Text(
                cond.label,
                style: TextStyle(
                  fontSize: isDense ? 9 : 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ] else ...[
              const SizedBox(width: 2.5),
              Text(
                cond.shortCode,
                style: TextStyle(
                  fontSize: isDense ? 8.5 : 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
            if (activeCondition.hasFiniteDuration) ...[
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                decoration: BoxDecoration(
                  color: color.withAlpha(100),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  activeCondition.durationBadge,
                  style: TextStyle(
                    fontSize: isDense ? 7.5 : 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            if (onRemove != null && showLabel) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: isDense ? 10 : 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ],
          ],
        ),
      ),
    );

    return Tooltip(
      message: tooltipContent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      preferBelow: false,
      textStyle: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230).withAlpha(240),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(180), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: chipWidget,
    );
  }
}

/// Compact `+N` badge displayed when conditions exceed 3 active items.
class ArenaConditionOverflowBadge extends StatelessWidget {
  final int overflowCount;
  final List<ActiveCondition> allConditions;
  final bool isDense;
  final VoidCallback? onTap;

  const ArenaConditionOverflowBadge({
    super.key,
    required this.overflowCount,
    required this.allConditions,
    this.isDense = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tooltipSummary = allConditions
        .map((a) => '• ${a.name} (${a.durationDisplay})')
        .join('\n');

    final badgeWidget = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isDense ? 6 : 8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isDense ? 4 : 5,
          vertical: isDense ? 1.5 : 2.5,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3042) : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(isDense ? 6 : 8),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black26,
            width: 0.8,
          ),
        ),
        child: Text(
          '+$overflowCount',
          style: TextStyle(
            fontSize: isDense ? 8.5 : 10,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );

    return Tooltip(
      message: 'Active Conditions ($overflowCount more):\n$tooltipSummary',
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      preferBelow: false,
      textStyle: const TextStyle(fontSize: 11, color: Colors.white, height: 1.3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230).withAlpha(240),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white30, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: badgeWidget,
    );
  }
}

/// Dynamic condition bar with overflow handling for tokens and roster cards.
class ArenaConditionChipsBar extends StatelessWidget {
  final List<ActiveCondition> conditions;
  final bool isDense;
  final bool showLabel;
  final int maxVisible;
  final void Function(ArenaCondition condition)? onRemoveCondition;
  final VoidCallback? onManageConditions;

  const ArenaConditionChipsBar({
    super.key,
    required this.conditions,
    this.isDense = false,
    this.showLabel = false,
    this.maxVisible = 2,
    this.onRemoveCondition,
    this.onManageConditions,
  });

  @override
  Widget build(BuildContext context) {
    if (conditions.isEmpty) return const SizedBox.shrink();

    final hasOverflow = conditions.length > 3;
    final visibleCount = hasOverflow ? maxVisible : conditions.length;
    final visibleConditions = conditions.take(visibleCount).toList();
    final overflowCount = conditions.length - visibleCount;

    return Wrap(
      spacing: isDense ? 3 : 4,
      runSpacing: isDense ? 2 : 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...visibleConditions.map((active) => ArenaConditionChip(
              activeCondition: active,
              isDense: isDense,
              showLabel: showLabel,
              onRemove: onRemoveCondition != null
                  ? () => onRemoveCondition!(active.condition)
                  : null,
            )),
        if (hasOverflow && overflowCount > 0)
          ArenaConditionOverflowBadge(
            overflowCount: overflowCount,
            allConditions: conditions,
            isDense: isDense,
            onTap: onManageConditions,
          ),
      ],
    );
  }
}
