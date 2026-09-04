import 'package:flutter/material.dart';
import '../../models/arena/arena_condition.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/character_models.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';
import 'short_rest_dialog.dart';

/// Core Vitals HUD presenting Armor Class, Initiative, Speed, Passive Senses,
/// Interactive HP Bar with Temp HP buffer, Hit Dice tracker, Death Saves,
/// Exhaustion tracker with 2024 penalty calculation, and Resting triggers.
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
    final isDowned = resources.currentHp <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 3-Stat Metric Cards: AC, Initiative, Speed
        Row(
          children: [
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
        const SizedBox(height: 10),

        // 2. Passive Senses Bar
        _buildPassiveSensesCard(context),
        const SizedBox(height: 10),

        // 3. HP & Temp HP Resource Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDowned ? Colors.redAccent : (customColors?.cardBorder ?? theme.colorScheme.outlineVariant),
              width: isDowned ? 1.5 : 1.0,
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
                      Icon(
                        isDowned ? Icons.heart_broken : Icons.favorite,
                        color: isDowned ? Colors.redAccent : Colors.redAccent,
                        size: 18,
                      ),
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
                        onPressed: () => controller.takeDamage(5),
                      ),
                      const SizedBox(width: 6),
                      _buildQuickHpButton(
                        context,
                        label: '-1',
                        color: Colors.red.shade400,
                        onPressed: () => controller.takeDamage(1),
                      ),
                    ],
                  ),
                  // Custom Value Adjust Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Adjust / Temp', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showHpAdjustDialog(context),
                    ),
                  ),
                  // Healing Buttons (+1, +5)
                  Row(
                    children: [
                      _buildQuickHpButton(
                        context,
                        label: '+1',
                        color: Colors.green.shade400,
                        onPressed: () => controller.heal(1),
                      ),
                      const SizedBox(width: 6),
                      _buildQuickHpButton(
                        context,
                        label: '+5',
                        color: Colors.green.shade400,
                        onPressed: () => controller.heal(5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Rest Action Buttons below the HP bar
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Short Rest',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.coffee_outlined, size: 18),
                          label: const Text('Short Rest', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showShortRestDialog(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Long Rest',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.bedtime_outlined, size: 18),
                          label: const Text('Long Rest', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _showLongRestConfirmationDialog(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 4. Death Saves Tracker (Always shown if currentHp <= 0 or if any death saves recorded)
        if (isDowned || resources.deathSaveSuccesses > 0 || resources.deathSaveFailures > 0) ...[
          const SizedBox(height: 10),
          _buildDeathSavesCard(context),
        ],

        const SizedBox(height: 10),

        // 5. Rest & Inspiration Bar + Exhaustion Tracker
        _buildRestAndStatusCard(context),

        const SizedBox(height: 10),

        // 6. Hit Dice Resource Tracker
        _buildHitDiceCard(context),

        // 7. Active Conditions Tracker (if any)
        if (character.conditions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildActiveConditionsCard(context),
        ],
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
      return Semantics(
        button: true,
        label: '$title breakdown: $value',
        child: InkWell(
          onTap: () {
            HapticService.selectionTick(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: card,
          ),
        ),
      );
    }
    return card;
  }

  Widget _buildPassiveSensesCard(BuildContext context) {
    final theme = Theme.of(context);
    final stats = controller.stats;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildPassiveSenseItem(theme, 'Perception', stats.passivePerception, Icons.visibility_outlined)),
          Expanded(child: _buildPassiveSenseItem(theme, 'Insight', stats.passiveInsight, Icons.psychology_outlined)),
          Expanded(child: _buildPassiveSenseItem(theme, 'Investig.', stats.passiveInvestigation, Icons.search_outlined)),
        ],
      ),
    );
  }

  Widget _buildPassiveSenseItem(ThemeData theme, String label, int value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$value',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          Container(
            height: 16,
            color: Colors.black26,
          ),
          FractionallySizedBox(
            widthFactor: hpRatio,
            child: Container(
              height: 16,
              color: barColor,
            ),
          ),
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
    return Semantics(
      button: true,
      label: 'Modify HP $label',
      child: InkWell(
        onTap: () {
          HapticService.selectionTick(context);
          onPressed();
        },
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeathSavesCard(BuildContext context) {
    final theme = Theme.of(context);
    final resources = controller.character.resources;
    final successes = resources.deathSaveSuccesses;
    final failures = resources.deathSaveFailures;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              DndGlyph.genericUi(
                uiType: GenericUiGlyphType.deathSave,
                size: 20,
                isDarkMode: true,
              ),
              const SizedBox(width: 8),
              Text(
                'DEATH SAVES',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Successes
              Row(
                children: [
                  const Icon(Icons.check, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  ...List.generate(3, (index) {
                    final isChecked = index < successes;
                    return Semantics(
                      button: true,
                      label: 'Death save success ${index + 1}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          HapticService.selectionTick(context);
                          controller.setDeathSaves(
                            successes: isChecked ? index : index + 1,
                          );
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: Center(
                            child: Icon(
                              isChecked ? Icons.check_circle : Icons.circle_outlined,
                              size: 22,
                              color: isChecked ? Colors.green : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(width: 12),
              // Failures
              Row(
                children: [
                  const Icon(Icons.close, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  ...List.generate(3, (index) {
                    final isChecked = index < failures;
                    return Semantics(
                      button: true,
                      label: 'Death save failure ${index + 1}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          HapticService.selectionTick(context);
                          controller.setDeathSaves(
                            failures: isChecked ? index : index + 1,
                          );
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          child: Center(
                            child: Icon(
                              isChecked ? Icons.cancel : Icons.circle_outlined,
                              size: 22,
                              color: isChecked ? Colors.red : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestAndStatusCard(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();
    final resources = controller.character.resources;
    final is2024 = controller.rulesEdition == DmRulesEdition.v2024;
    final exhaustionLevel = resources.exhaustionLevel;
    final penalty = -2 * exhaustionLevel;
    final hasInspiration = controller.hasInspiration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Heroic Inspiration Toggle
              Semantics(
                button: true,
                label: 'Heroic Inspiration ${hasInspiration ? "Active" : "Inactive"}',
                child: Material(
                  color: hasInspiration
                      ? (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.2)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: hasInspiration
                          ? (customColors?.critGold ?? Colors.amber)
                          : theme.colorScheme.outlineVariant,
                      width: hasInspiration ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticService.selectionTick(context);
                      controller.toggleInspiration();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: hasInspiration
                                  ? (customColors?.critGold ?? Colors.amber)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'INSPIRATION',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasInspiration
                                    ? (customColors?.critGold ?? Colors.amber)
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Rest Triggers
              Row(
                children: [
                  // Short Rest Button
                  Semantics(
                    button: true,
                    label: 'Take Short Rest',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.coffee_outlined, size: 14),
                        label: const Text('Short Rest', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showShortRestDialog(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Long Rest Button
                  Semantics(
                    button: true,
                    label: 'Take Long Rest',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.bedtime_outlined, size: 14),
                        label: const Text('Long Rest', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showLongRestConfirmationDialog(context),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Exhaustion Tracker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.battery_alert,
                    size: 16,
                    color: exhaustionLevel > 0 ? Colors.orangeAccent : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'EXHAUSTION: $exhaustionLevel',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (exhaustionLevel > 0 && is2024) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '$penalty on d20 tests',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Decrease Exhaustion',
                    child: InkWell(
                      onTap: exhaustionLevel > 0
                          ? () {
                              HapticService.selectionTick(context);
                              controller.setExhaustionLevel(exhaustionLevel - 1);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: Icon(
                          Icons.remove_circle_outline,
                          size: 20,
                          color: exhaustionLevel > 0 ? theme.colorScheme.primary : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '$exhaustionLevel / ${is2024 ? 10 : 6}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Semantics(
                    button: true,
                    label: 'Increase Exhaustion',
                    child: InkWell(
                      onTap: exhaustionLevel < (is2024 ? 10 : 6)
                          ? () {
                              HapticService.selectionTick(context);
                              controller.setExhaustionLevel(exhaustionLevel + 1);
                            }
                          : null,
                      borderRadius: BorderRadius.circular(6),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: exhaustionLevel < (is2024 ? 10 : 6)
                              ? Colors.redAccent
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHitDiceCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
              DndGlyph.genericUi(
                uiType: GenericUiGlyphType.d20,
                size: 18,
                isDarkMode: isDark,
              ),
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
              final dieGlyph = GenericUiGlyphType.fromDie(die);
              return Semantics(
                button: true,
                label: 'Spend or recover $die hit die, $current of $max available',
                child: InkWell(
                  onTap: () {
                    HapticService.selectionTick(context);
                    if (current > 0) {
                      controller.expendHitDie(die);
                    } else {
                      controller.recoverHitDie(die);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (dieGlyph != null) ...[
                            DndGlyph.genericUi(
                              uiType: dieGlyph,
                              size: 16,
                              isDarkMode: isDark,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '$current/$max $die',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: current > 0
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildActiveConditionsCard(BuildContext context) {
    final theme = Theme.of(context);
    final character = controller.character;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACTIVE CONDITIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: character.conditions.map((cond) {
              final arenaCond = ArenaCondition.values.firstWhere(
                (c) => c.name.toLowerCase() == cond.conditionName.toLowerCase(),
                orElse: () => ArenaCondition.incapacitated,
              );

              return Semantics(
                button: true,
                label: 'Condition ${cond.conditionName}',
                child: InkWell(
                  onTap: () => _showConditionDialog(context, cond, arenaCond),
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: arenaCond.colorTheme.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: arenaCond.colorTheme.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(arenaCond.icon, size: 14, color: arenaCond.colorTheme),
                          const SizedBox(width: 4),
                          Text(
                            cond.conditionName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: arenaCond.colorTheme,
                            ),
                          ),
                        ],
                      ),
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

  void _showConditionDialog(BuildContext context, CharacterCondition cond, ArenaCondition arenaCond) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(arenaCond.icon, color: arenaCond.colorTheme),
            const SizedBox(width: 8),
            Text(arenaCond.label),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mechanical Penalties:',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: arenaCond.colorTheme.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: arenaCond.colorTheme.withValues(alpha: 0.3)),
              ),
              child: Text(
                arenaCond.penaltySummary,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (cond.source != null) ...[
              const SizedBox(height: 8),
              Text(
                'Source: ${cond.source}',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Remove Condition'),
            onPressed: () {
              controller.removeCondition(cond.conditionName);
              Navigator.of(ctx).pop();
            },
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showShortRestDialog(BuildContext context) {
    ShortRestDialog.show(context, controller: controller);
  }

  void _showLongRestConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bedtime, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text('Begin Long Rest?'),
          ],
        ),
        content: const Text(
          'Begin Long Rest? This will restore HP, spell slots, half your hit dice, and reduce Exhaustion.',
        ),
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: FilledButton(
              onPressed: () {
                controller.applyLongRest();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Long rest completed! HP, spell slots, and hit dice restored.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Begin Long Rest'),
            ),
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
