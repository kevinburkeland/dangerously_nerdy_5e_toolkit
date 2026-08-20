import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/monster_codex_data.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../services/haptic_service.dart';
import '../glyphs/dnd_glyph.dart';

/// Interactive modal comparing 2014 RAW monster stat blocks vs 2024 Revised rules side-by-side.
class MonsterComparisonDialog extends StatefulWidget {
  final MonsterItem monster;
  final DmRulesEdition initialEdition;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const MonsterComparisonDialog({
    super.key,
    required this.monster,
    required this.initialEdition,
    required this.isPinned,
    required this.onTogglePin,
  });

  static Future<void> show(
    BuildContext context, {
    required MonsterItem monster,
    DmRulesEdition? edition,
    required bool isPinned,
    required VoidCallback onTogglePin,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => MonsterComparisonDialog(
        monster: monster,
        initialEdition: edition ?? DmRulesEdition.v2024,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
      ),
    );
  }

  @override
  State<MonsterComparisonDialog> createState() => _MonsterComparisonDialogState();
}

class _MonsterComparisonDialogState extends State<MonsterComparisonDialog> {
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
    final monster = widget.monster;
    final statBlock = monster.getStatBlock(_activeEdition);
    final creatureType = statBlock.glyphCreatureType;
    final typeColor = creatureType.getLegibleColor(isDark);
    final showDualView = _showDiff && monster.isChangedIn2024;
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);

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
                DndGlyph.monster(
                  creatureType: creatureType,
                  crTier: statBlock.glyphCrTier,
                  actionRings: statBlock.glyphActionRings,
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
                              monster.getName(_activeEdition),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (monster.isChangedIn2024)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: diffColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: diffColor.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome,
                                      color: diffColor, size: 11),
                                  const SizedBox(width: 3),
                                  Text(
                                    _activeEdition == DmRulesEdition.v2014
                                        ? '2014 RAW'
                                        : '2024 Revised',
                                    style: TextStyle(
                                      color: diffColor,
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
                        'CR ${statBlock.crDisplay} ${statBlock.sizeDisplay} ${statBlock.typeDisplay.toLowerCase()} • ${showDualView ? "Side-by-side 2014 vs 2024" : (_activeEdition == DmRulesEdition.v2014 ? "2014 RAW View" : "2024 Revised View")}',
                        style: TextStyle(
                          color: typeColor,
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
                      ? 'Remove from My Bestiary'
                      : 'Pin to My Bestiary',
                  onPressed: _handlePinToggle,
                ),
                if (monster.isChangedIn2024)
                  TextButton.icon(
                    onPressed: () => setState(() => _showDiff = !_showDiff),
                    icon: Icon(
                        _showDiff
                            ? Icons.visibility_outlined
                            : Icons.compare_arrows,
                        size: 16),
                    label: Text(_showDiff ? 'Single View' : 'Compare Diff'),
                  ),
                IconButton(
                  icon: Icon(Icons.close,
                      color: theme.colorScheme.onSurfaceVariant),
                  tooltip: 'Close comparison dialog',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Diff Summary & Highlights Banner
            if (monster.isChangedIn2024 &&
                (monster.diffSummary != null ||
                    monster.diffHighlights.isNotEmpty)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: diffColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '2024 REVISED RULES DIFF HIGHLIGHTS',
                          style: TextStyle(
                            color: diffColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    if (monster.diffSummary != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        monster.diffSummary!,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (monster.diffHighlights.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: monster.diffHighlights.map((hl) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: diffColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: diffColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '• $hl',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.amberAccent
                                    : const Color(0xFF92400E),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Edition Toggle Segments (if not dual view)
            if (!showDualView) ...[
              SegmentedButton<DmRulesEdition>(
                segments: const [
                  ButtonSegment(
                    value: DmRulesEdition.v2014,
                    label: Text('2014 Rules (5.1)'),
                    icon: Icon(Icons.history, size: 16),
                  ),
                  ButtonSegment(
                    value: DmRulesEdition.v2024,
                    label: Text('2024 Revised (5.2)'),
                    icon: Icon(Icons.auto_awesome, size: 16),
                  ),
                ],
                selected: {_activeEdition},
                onSelectionChanged: (val) {
                  HapticService.selectionTick(context);
                  setState(() => _activeEdition = val.first);
                },
              ),
              const SizedBox(height: 12),
            ],

            // Content Area: Dual Comparison vs Single View
            Expanded(
              child: showDualView
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildEditionCard(
                            context,
                            edition: DmRulesEdition.v2014,
                            statBlock: monster.statBlock2014,
                            isHighlighted: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildEditionCard(
                            context,
                            edition: DmRulesEdition.v2024,
                            statBlock: monster.statBlock2024,
                            isHighlighted: true,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: _buildStatBlockBody(context, statBlock, _activeEdition),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditionCard(
    BuildContext context, {
    required DmRulesEdition edition,
    required MinionStatBlock statBlock,
    required bool isHighlighted,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted
            ? diffColor.withValues(alpha: 0.05)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted
              ? diffColor.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? diffColor.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Text(
              edition == DmRulesEdition.v2014 ? '2014 RAW RULES (5.1)' : '2024 REVISED RULES (5.2)',
              style: TextStyle(
                color: isHighlighted ? diffColor : theme.colorScheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildStatBlockBody(context, statBlock, edition),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlockBody(
    BuildContext context,
    MinionStatBlock sb,
    DmRulesEdition edition,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Stats Row
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildStatChip('CR ${sb.crDisplay}', theme),
            _buildStatChip('AC ${sb.ac}', theme),
            _buildStatChip('HP ${sb.maxHp} (${sb.hitDice})', theme),
            _buildStatChip('Speed ${sb.speed}', theme),
          ],
        ),
        const SizedBox(height: 10),

        // Ability Scores Table
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(child: _buildAbilityScore('STR', sb.strScore)),
              Expanded(child: _buildAbilityScore('DEX', sb.dexScore)),
              Expanded(child: _buildAbilityScore('CON', sb.conScore)),
              Expanded(child: _buildAbilityScore('INT', sb.intScore)),
              Expanded(child: _buildAbilityScore('WIS', sb.wisScore)),
              Expanded(child: _buildAbilityScore('CHA', sb.chaScore)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Senses / Languages / Immunities
        if (sb.senses.isNotEmpty)
          _buildInfoRow('Senses', sb.senses, theme),
        if (sb.languages.isNotEmpty)
          _buildInfoRow('Languages', sb.languages, theme),
        if (sb.damageResistances != null)
          _buildInfoRow('Resistances', sb.damageResistances!, theme),
        if (sb.damageImmunities != null)
          _buildInfoRow('Immunities', sb.damageImmunities!, theme),
        if (sb.conditionImmunities != null)
          _buildInfoRow('Conditions', sb.conditionImmunities!, theme),

        const Divider(height: 16),

        // Traits
        if (sb.traits.isNotEmpty) ...[
          Text(
            'TRAITS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          for (final t in sb.traits) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${t.name}. ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  TextSpan(
                    text: t.description,
                    style: const TextStyle(fontSize: 12.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
        ],

        // Actions
        if (sb.actions.isNotEmpty) ...[
          Text(
            'ACTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          for (final a in sb.actions) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${a.name}. ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  TextSpan(
                    text: a.description,
                    style: const TextStyle(fontSize: 12.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],

        // Legendary Actions
        if (sb.legendaryActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'LEGENDARY ACTIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade700,
            ),
          ),
          const SizedBox(height: 4),
          for (final la in sb.legendaryActions) ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${la.name}. ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  TextSpan(
                    text: la.description,
                    style: const TextStyle(fontSize: 12.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }

  Widget _buildStatChip(String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildAbilityScore(String name, int score) {
    final mod = (score - 10) ~/ 2;
    final modStr = mod >= 0 ? '+$mod' : '$mod';
    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text('$score ($modStr)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }
}
