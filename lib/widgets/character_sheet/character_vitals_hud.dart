import 'package:flutter/material.dart';
import '../../providers/character_sheet_controller.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';

/// Core Vitals HUD presenting Armor Class (with breakdown modal), Initiative, Speed,
/// interactive HP Bar with Temp HP buffer, and Hit Dice tracker.
class CharacterVitalsHud extends StatelessWidget {
  final CharacterSheetController controller;

  const CharacterVitalsHud({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();
    final stats = controller.stats;
    final character = controller.character;
    final resources = character.resources;

    return Column(
      children: [
        // 3-Stat Metric Cards: AC, Initiative, Speed
        Row(
          children: [
            // AC Card with Tooltip / Breakdown Sheet
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'ARMOR CLASS',
                value: '${stats.armorClass}',
                icon: Icons.shield,
                iconColor: theme.colorScheme.primary,
                tooltip: stats.armorClassBreakdown,
                onTap: () => _showAcBreakdownDialog(context),
              ),
            ),
            const SizedBox(width: 8),
            // Initiative Card
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'INITIATIVE',
                value: stats.initiativeBonusString,
                icon: Icons.flash_on,
                iconColor: customColors?.critGold ?? Colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            // Speed Card
            Expanded(
              child: _buildMetricCard(
                context,
                title: 'SPEED',
                value: '${stats.speedFeet} ft',
                icon: Icons.directions_run,
                iconColor: customColors?.hitGreen ?? Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // HP & Temp HP Resource Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Current HP / Max HP & Temp HP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'HIT POINTS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${resources.currentHp}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: resources.currentHp <= (stats.maxHp * 0.25)
                              ? Colors.red
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        ' / ${stats.maxHp}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (resources.tempHp > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (customColors?.tempHpCyan ?? Colors.cyan).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (customColors?.tempHpCyan ?? Colors.cyan).withValues(alpha: 0.8),
                            ),
                          ),
                          child: Text(
                            '+${resources.tempHp} Temp',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: customColors?.tempHpCyan ?? Colors.cyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Visual HP Progress Bar with Temp HP overlay
              _buildHpProgressBar(context),

              const SizedBox(height: 12),

              // Quick HP Modification Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Damage Buttons (-5, -1)
                  Row(
                    children: [
                      _buildQuickHpButton(
                        context,
                        label: '-5',
                        color: Colors.red.shade400,
                        onPressed: () => controller.modifyHp(-5),
                      ),
                      const SizedBox(width: 6),
                      _buildQuickHpButton(
                        context,
                        label: '-1',
                        color: Colors.red.shade400,
                        onPressed: () => controller.modifyHp(-1),
                      ),
                    ],
                  ),
                  // Custom Value Adjust Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Adjust / Temp', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showHpAdjustDialog(context),
                  ),
                  // Healing Buttons (+1, +5)
                  Row(
                    children: [
                      _buildQuickHpButton(
                        context,
                        label: '+1',
                        color: Colors.green.shade400,
                        onPressed: () => controller.modifyHp(1),
                      ),
                      const SizedBox(width: 6),
                      _buildQuickHpButton(
                        context,
                        label: '+5',
                        color: Colors.green.shade400,
                        onPressed: () => controller.modifyHp(5),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Hit Dice Resource Tracker
        _buildHitDiceCard(context),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();

    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(height: 2),
            Text(
              'Tap for breakdown',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: () {
          HapticService.selectionTick(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: card,
      );
    }
    return card;
  }

  Widget _buildHpProgressBar(BuildContext context) {
    final stats = controller.stats;
    final resources = controller.character.resources;
    final curHp = resources.currentHp;
    final maxHp = stats.maxHp;
    final tempHp = resources.tempHp;

    final hpRatio = maxHp > 0 ? (curHp / maxHp).clamp(0.0, 1.0) : 0.0;
    final tempRatio = maxHp > 0 ? (tempHp / maxHp).clamp(0.0, 0.5) : 0.0;

    Color barColor;
    if (hpRatio > 0.5) {
      barColor = Colors.green;
    } else if (hpRatio > 0.2) {
      barColor = Colors.amber;
    } else {
      barColor = Colors.red;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // Background Track
          Container(
            height: 16,
            color: Colors.black26,
          ),
          // Current HP fill
          FractionallySizedBox(
            widthFactor: hpRatio,
            child: Container(
              height: 16,
              color: barColor,
            ),
          ),
          // Temp HP Overlay
          if (tempHp > 0)
            FractionallySizedBox(
              widthFactor: (hpRatio + tempRatio).clamp(0.0, 1.0),
              child: Container(
                height: 16,
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: Colors.cyanAccent,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickHpButton(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: () {
        HapticService.selectionTick(context);
        onPressed();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildHitDiceCard(BuildContext context) {
    final theme = Theme.of(context);
    final character = controller.character;
    final diceMap = character.resources.currentHitDice;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.casino_outlined, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'HIT DICE',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: character.progression.classes.map((c) {
              final die = c.hitDie;
              final current = diceMap[die] ?? c.level;
              final max = c.level;
              return InkWell(
                onTap: () {
                  HapticService.selectionTick(context);
                  if (current > 0) {
                    controller.expendHitDie(die);
                  } else {
                    controller.recoverHitDie(die);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: current > 0
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: current > 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '$current/$max $die',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: current > 0
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAcBreakdownDialog(BuildContext context) {
    final theme = Theme.of(context);
    final stats = controller.stats;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shield, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Armor Class Breakdown'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculation Formula:',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                stats.armorClassBreakdown,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Effective AC: ${stats.armorClass}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHpAdjustDialog(BuildContext context) {
    final valController = TextEditingController();
    final tempController = TextEditingController(
      text: '${controller.character.resources.tempHp}',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust HP & Temp HP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Damage / Heal Amount',
                hintText: 'e.g., -12 or +8',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tempController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Temporary Hit Points',
                hintText: 'e.g., 5',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final hpVal = int.tryParse(valController.text);
              if (hpVal != null && hpVal != 0) {
                controller.modifyHp(hpVal);
              }
              final tempVal = int.tryParse(tempController.text);
              if (tempVal != null) {
                controller.setTempHp(tempVal);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
