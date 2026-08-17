import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/spellbook_data.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../glyphs/dnd_glyph.dart';

/// Interactive modal comparing 2014 RAW spell mechanics vs 2024 Revised rules side-by-side.
class SpellComparisonDialog extends StatefulWidget {
  final SpellItem spell;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const SpellComparisonDialog({
    super.key,
    required this.spell,
    required this.isPinned,
    required this.onTogglePin,
  });

  static Future<void> show(
    BuildContext context, {
    required SpellItem spell,
    required bool isPinned,
    required VoidCallback onTogglePin,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => SpellComparisonDialog(
        spell: spell,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
      ),
    );
  }

  @override
  State<SpellComparisonDialog> createState() => _SpellComparisonDialogState();
}

class _SpellComparisonDialogState extends State<SpellComparisonDialog> {
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    _pinned = widget.isPinned;
  }

  void _handlePinToggle() {
    setState(() {
      _pinned = !_pinned;
    });
    widget.onTogglePin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final spell = widget.spell;
    final schoolColor = spell.school.getLegibleColor(isDark);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                DndGlyph.spell(
                  school: spell.school,
                  level: spell.level,
                  actionRings: spell.getGlyphActionRings(DmRulesEdition.v2024),
                  size: 46,
                  isDarkMode: isDark,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              spell.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (spell.isChangedIn2024)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.amber : const Color(0xFFB45309)).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: (isDark ? Colors.amber : const Color(0xFFB45309)).withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, color: isDark ? Colors.amber : const Color(0xFFB45309), size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    '2024 Revised',
                                    style: TextStyle(
                                      color: isDark ? Colors.amber : const Color(0xFFB45309),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${spell.levelLabel} ${spell.school.label} • 2014 vs 2024 Comparison',
                        style: TextStyle(
                          color: schoolColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _pinned ? Icons.bookmark : Icons.bookmark_border,
                    color: _pinned ? (isDark ? Colors.purpleAccent : theme.colorScheme.secondary) : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  tooltip: _pinned ? 'Remove from Personal Spellbook' : 'Pin to Personal Spellbook',
                  onPressed: _handlePinToggle,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                  tooltip: 'Close comparison dialog',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Diff Summary & Highlights Banner
            if (spell.isChangedIn2024 && (spell.diffSummary != null || spell.diffHighlights.isNotEmpty)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.amber : const Color(0xFFB45309)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (isDark ? Colors.amber : const Color(0xFFB45309)).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (spell.diffSummary != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome, color: isDark ? Colors.amber : const Color(0xFFB45309), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              spell.diffSummary!,
                              style: TextStyle(
                                color: isDark ? Colors.amber : const Color(0xFFB45309),
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (spell.diffHighlights.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...spell.diffHighlights.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(left: 28, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('▸ ', style: TextStyle(color: isDark ? Colors.amber : const Color(0xFFB45309), fontSize: 12)),
                              Expanded(
                                child: Text(
                                  h,
                                  style: TextStyle(
                                    color: isDark ? Colors.amber.shade100 : theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Side-by-side or stacked comparison columns
            Expanded(
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 580;
                    final v2014Color = isDark ? Colors.blueGrey : const Color(0xFF475569);
                    final v2024Color = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildEditionBox(context, '2014 (5e RAW)', spell.rules2014, v2014Color)),
                          const SizedBox(width: 14),
                          Expanded(child: _buildEditionBox(context, '2024 (Revised 5e)', spell.rules2024, v2024Color)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildEditionBox(context, '2014 (5e RAW)', spell.rules2014, v2014Color),
                          const SizedBox(height: 12),
                          _buildEditionBox(context, '2024 (Revised 5e)', spell.rules2024, v2024Color),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditionBox(
    BuildContext context,
    String title,
    SpellEditionDetails rules,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>() ?? TabletopColors.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tabletop.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Divider(height: 16, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

          // Metadata Grid
          _buildMetaRow(context, 'School', (rules.schoolOverride ?? widget.spell.school).label, accentColor),
          _buildMetaRow(context, 'Casting Time', rules.castingTime, accentColor),
          _buildMetaRow(context, 'Range', rules.range, accentColor),
          _buildMetaRow(context, 'Components', rules.components, accentColor),
          _buildMetaRow(context, 'Duration', rules.duration, accentColor),
          if (rules.savingThrow != null)
            _buildMetaRow(context, 'Saving Throw', '${rules.savingThrow} Save', accentColor),
          if (rules.damageOrHealType != null)
            _buildMetaRow(context, 'Type / Formula', '${rules.rollFormula ?? ''} (${rules.damageOrHealType})', accentColor),
          _buildMetaRow(context, 'Classes', rules.classes.map((c) => c.label).join(', '), accentColor),

          const SizedBox(height: 10),
          Divider(height: 16, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

          // Description Paragraphs
          ...rules.description.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  p,
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 13, height: 1.38),
                ),
              )),

          if (rules.higherLevels != null) ...[
            const SizedBox(height: 6),
            Text(
              'At Higher Levels:',
              style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              rules.higherLevels!,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, String label, String value, Color accentColor) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
