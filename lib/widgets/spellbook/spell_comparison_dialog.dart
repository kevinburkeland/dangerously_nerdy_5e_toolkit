import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/spellbook_data.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../common/diff_highlight_banner.dart';
import '../glyphs/dnd_glyph.dart';
import 'spell_dpr_view.dart';

/// Interactive modal comparing 2014 RAW spell mechanics vs 2024 Revised rules side-by-side with Damage/DPR tab.
class SpellComparisonDialog extends StatefulWidget {
  final SpellItem spell;
  final DmRulesEdition initialEdition;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const SpellComparisonDialog({
    super.key,
    required this.spell,
    required this.initialEdition,
    required this.isPinned,
    required this.onTogglePin,
  });

  static Future<void> show(
    BuildContext context, {
    required SpellItem spell,
    DmRulesEdition? edition,
    required bool isPinned,
    required VoidCallback onTogglePin,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => SpellComparisonDialog(
        spell: spell,
        initialEdition: edition ?? DmRulesEdition.v2024,
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
  late DmRulesEdition _activeEdition;
  bool _showDiff = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.isPinned;
    _activeEdition = widget.initialEdition;
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
    final currentRules = spell.getRules(_activeEdition);
    final currentSchool = spell.getSchool(_activeEdition);
    final showDualView = _showDiff && spell.isChangedIn2024;

    final hasDamageOrDpr = currentRules.rollFormula != null ||
        currentRules.scalingFormula != null ||
        currentRules.damageOrHealType != null ||
        currentRules.savingThrow != null ||
        currentRules.description.any((p) =>
            p.toLowerCase().contains('damage') ||
            p.toLowerCase().contains('hit point'));

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
        padding: const EdgeInsets.all(20),
        child: DefaultTabController(
          length: hasDamageOrDpr ? 2 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  DndGlyph.spell(
                    school: currentSchool,
                    level: spell.level,
                    actionRings: spell.getGlyphActionRings(_activeEdition),
                    size: 46,
                    isDarkMode: isDark,
                    isActive: true,
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark
                                          ? Colors.amber
                                          : const Color(0xFFB45309))
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: (isDark
                                              ? Colors.amber
                                              : const Color(0xFFB45309))
                                          .withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        color: isDark
                                            ? Colors.amber
                                            : const Color(0xFFB45309),
                                        size: 11),
                                    const SizedBox(width: 3),
                                    Text(
                                      _activeEdition == DmRulesEdition.v2014
                                          ? '2014 RAW'
                                          : '2024 Revised',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.amber
                                            : const Color(0xFFB45309),
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
                          '${spell.levelLabel} ${currentSchool.label} • ${_showDiff && spell.isChangedIn2024 ? 'Side-by-side 2014 vs 2024' : (_activeEdition == DmRulesEdition.v2014 ? '2014 RAW View' : '2024 Revised View')}',
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
                      color: _pinned
                          ? (isDark
                              ? Colors.purpleAccent
                              : theme.colorScheme.secondary)
                          : theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    tooltip: _pinned
                        ? 'Remove from Personal Spellbook'
                        : 'Pin to Personal Spellbook',
                    onPressed: _handlePinToggle,
                  ),
                  if (spell.isChangedIn2024)
                    TextButton.icon(
                      onPressed: () => setState(() => _showDiff = !_showDiff),
                      icon: Icon(
                          _showDiff
                              ? Icons.visibility_outlined
                              : Icons.compare_arrows,
                          size: 16),
                      label: Text(_showDiff ? 'Keep Current View' : 'View Diff'),
                    ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: theme.colorScheme.onSurfaceVariant),
                    tooltip: 'Close comparison dialog',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // TabBar when damaging/scaling
              if (hasDamageOrDpr) ...[
                TabBar(
                  indicatorColor: schoolColor,
                  labelColor: isDark ? const Color(0xFFFFD54F) : schoolColor,
                  unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.menu_book, size: 16),
                      text: 'Spell Details',
                    ),
                    Tab(
                      icon: Icon(Icons.sports_kabaddi, size: 16),
                      text: 'Damage / DPR',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // Content Area
              Expanded(
                child: hasDamageOrDpr
                    ? TabBarView(
                        children: [
                          _buildDetailsTabContent(context, showDualView, theme, isDark),
                          SpellDprView(spell: spell, edition: _activeEdition),
                        ],
                      )
                    : _buildDetailsTabContent(context, showDualView, theme, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsTabContent(
    BuildContext context,
    bool showDualView,
    ThemeData theme,
    bool isDark,
  ) {
    final spell = widget.spell;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Diff Summary & Highlights Banner
          if (spell.isChangedIn2024 &&
              (spell.diffSummary != null || spell.diffHighlights.isNotEmpty)) ...[
            DiffHighlightBanner(
              diffSummary: spell.diffSummary,
              diffHighlights: spell.diffHighlights,
            ),
            const SizedBox(height: 12),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 580;
              final v2014Color =
                  isDark ? Colors.blueGrey : const Color(0xFF475569);
              final v2024Color =
                  isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

              if (showDualView) {
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _buildEditionBox(context, '2014 (5e RAW)',
                              spell.rules2014, v2014Color)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: _buildEditionBox(context, '2024 (Revised 5e)',
                              spell.rules2024, v2024Color)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildEditionBox(context, '2014 (5e RAW)',
                          spell.rules2014, v2014Color),
                      const SizedBox(height: 12),
                      _buildEditionBox(context, '2024 (Revised 5e)',
                          spell.rules2024, v2024Color),
                    ],
                  );
                }
              }

              final activeRules = spell.getRules(_activeEdition);
              final activeAccentColor = _activeEdition == DmRulesEdition.v2014
                  ? v2014Color
                  : v2024Color;
              final activeTitle = _activeEdition == DmRulesEdition.v2014
                  ? '2014 (5e RAW)'
                  : '2024 (Revised 5e)';

              final displayCard = _buildEditionBox(
                  context, activeTitle, activeRules, activeAccentColor);

              if (isWide) {
                return Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 650),
                        child: displayCard));
              }

              return displayCard;
            },
          ),
        ],
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
          Divider(
              height: 16,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

          // Metadata Grid
          _buildMetaRow(context, 'School',
              (rules.schoolOverride ?? widget.spell.school).label, accentColor),
          _buildMetaRow(
              context, 'Casting Time', rules.castingTime, accentColor),
          _buildMetaRow(context, 'Range', rules.range, accentColor),
          _buildMetaRow(context, 'Components', rules.components, accentColor),
          _buildMetaRow(context, 'Duration', rules.duration, accentColor),
          if (rules.savingThrow != null)
            _buildMetaRow(context, 'Saving Throw', '${rules.savingThrow} Save',
                accentColor),
          if (rules.damageOrHealType != null)
            _buildMetaRow(
                context,
                'Type / Formula',
                '${rules.rollFormula ?? ''} (${rules.damageOrHealType})',
                accentColor),
          _buildMetaRow(context, 'Classes',
              rules.classes.map((c) => c.label).join(', '), accentColor),

          const SizedBox(height: 10),
          Divider(
              height: 16,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

          // Description Paragraphs
          ...rules.description.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  p,
                  style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.38),
                ),
              )),

          if (rules.higherLevels != null) ...[
            const SizedBox(height: 6),
            Text(
              'At Higher Levels:',
              style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              rules.higherLevels!,
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(
      BuildContext context, String label, String value, Color accentColor) {
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
