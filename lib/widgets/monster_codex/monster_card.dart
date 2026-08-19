import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/monster_codex_data.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../glyphs/dnd_glyph.dart';
import '../interactive/pressable_card.dart';

/// Modular, interactive card presenting an individual SRD creature in the Monster Codex.
class MonsterCard extends StatelessWidget {
  final MonsterItem monster;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;
  final void Function(String formula, String label)? onQuickRoll;
  final VoidCallback? onOpenQuickRoll;

  const MonsterCard({
    super.key,
    required this.monster,
    this.edition = DmRulesEdition.v2024,
    required this.isPinned,
    required this.onTogglePin,
    required this.onTap,
    this.onQuickRoll,
    this.onOpenQuickRoll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statBlock = monster.getStatBlock(edition);
    final creatureType = statBlock.glyphCreatureType;
    final typeColor = creatureType.getLegibleColor(isDark);
    final glyphRings = statBlock.glyphActionRings;
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);
    final cardBorderColor = isPinned
        ? pinColor.withValues(alpha: 0.85)
        : typeColor.withValues(alpha: 0.35);

    final crClean = statBlock.crDisplay.replaceAll('CR ', '');

    return PressableCard(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cardBorderColor,
          width: isPinned ? 1.6 : 1.2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: DndGlyph HUD + Title & Type + Diff Badge + Pin Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DndGlyph.monster(
                creatureType: creatureType,
                crTier: statBlock.glyphCrTier,
                actionRings: glyphRings,
                size: 40,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monster.getName(edition),
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${statBlock.sizeDisplay} ${statBlock.typeDisplay.toLowerCase()}, ${statBlock.alignment}',
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (monster.isChangedIn2024) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: diffColor, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        '2024 Diff',
                        style: TextStyle(
                            color: diffColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 2),
              ],
              IconButton(
                icon: Icon(
                  isPinned ? Icons.bookmark : Icons.bookmark_border,
                  color: isPinned ? pinColor : theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                tooltip: isPinned ? 'Remove from My Bestiary' : 'Pin to My Bestiary',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onTogglePin,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Key Combat Stats Chips: CR, AC, HP, Speed
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildStatChip(
                context,
                icon: Icons.shield,
                label: 'CR $crClean',
                color: typeColor,
                isFilled: true,
              ),
              _buildStatChip(
                context,
                icon: Icons.shield_outlined,
                label: 'AC ${statBlock.ac}${statBlock.armorType != null ? ' (${statBlock.armorType})' : ''}',
                color: theme.colorScheme.onSurfaceVariant,
              ),
              _buildStatChip(
                context,
                icon: Icons.favorite_outline,
                label: 'HP ${statBlock.maxHp}${statBlock.hitDice != null ? ' (${statBlock.hitDice})' : ''}',
                color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
              ),
              _buildStatChip(
                context,
                icon: Icons.directions_run_outlined,
                label: statBlock.speed,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Action & Trait Preview Pills
          if (statBlock.traits.isNotEmpty || statBlock.actions.isNotEmpty || statBlock.legendaryActions.isNotEmpty) ...[
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (statBlock.hasLegendaryResistance)
                  _buildTraitPill(
                    statBlock.traits.firstWhere((t) => t.name.toLowerCase().contains('legendary resistance')).name,
                    isDark ? const Color(0xFFFDE047) : const Color(0xFFD97706),
                  ),
                if (statBlock.legendaryActions.isNotEmpty || statBlock.hasLegendaryActions)
                  _buildTraitPill(
                    'Legendary Actions (${statBlock.legendaryActions.isNotEmpty ? statBlock.legendaryActions.length : 3})',
                    isDark ? const Color(0xFFF472B6) : const Color(0xFFDB2777),
                  ),
                ...statBlock.traits
                    .where((t) => !t.name.toLowerCase().contains('legendary resistance'))
                    .take(2)
                    .map(
                      (trait) => _buildTraitPill(
                        trait.name,
                        isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                      ),
                    ),
                ...statBlock.actions.take(3).map(
                      (action) => _buildActionPill(
                        context,
                        action,
                        typeColor,
                      ),
                    ),
                if (statBlock.reactions.isNotEmpty)
                  _buildTraitPill(
                    'Reactions (${statBlock.reactions.length})',
                    isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                  ),
                if (statBlock.damageResistances != null && statBlock.damageResistances!.isNotEmpty)
                  _buildTraitPill(
                    'Resistances',
                    isDark ? Colors.amberAccent : const Color(0xFFB45309),
                  ),
                if (statBlock.damageImmunities != null && statBlock.damageImmunities!.isNotEmpty)
                  _buildTraitPill(
                    'Immunities',
                    isDark ? Colors.orangeAccent : const Color(0xFFC2410C),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Footer: Source Preset / Spell Attribution & Quick Actions
          Row(
            children: [
              Icon(
                monster.sourceCategory == SummonCategory.spell
                    ? Icons.auto_fix_high
                    : Icons.token_outlined,
                size: 13,
                color: theme.colorScheme.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  monster.sourcePresetName,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onOpenQuickRoll != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onOpenQuickRoll,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.casino, size: 12, color: typeColor),
                        const SizedBox(width: 3),
                        Text(
                          'Quick Roll',
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    bool isFilled = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isFilled
            ? color.withValues(alpha: isDark ? 0.22 : 0.15)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFilled
              ? color.withValues(alpha: 0.6)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isFilled ? color : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isFilled ? color : theme.colorScheme.onSurface.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: isFilled ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionPill(
    BuildContext context,
    CreatureAction action,
    Color color,
  ) {
    final bonus = action.attackBonus != null
        ? '${action.attackBonus! >= 0 ? '+' : ''}${action.attackBonus}'
        : null;
    final label = bonus != null ? '${action.name} $bonus' : action.name;

    return InkWell(
      onTap: onQuickRoll != null && action.attackBonus != null
          ? () {
              final rollFormula = '1d20$bonus';
              onQuickRoll!(rollFormula, '${monster.name} - ${action.name} (Attack Roll)');
            }
          : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.attackBonus != null) ...[
              Icon(Icons.colorize_outlined, size: 10, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
