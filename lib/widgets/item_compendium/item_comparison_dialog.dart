import 'package:flutter/material.dart';
import '../../models/magic_items/magic_item_data.dart';
import '../../services/haptic_service.dart';
import '../glyphs/dnd_glyph.dart';

/// Interactive modal comparing 2014 RAW magic item mechanics vs 2024 Revised rules side-by-side.
class ItemComparisonDialog extends StatefulWidget {
  final MagicItem item;
  final DmRulesEdition initialEdition;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const ItemComparisonDialog({
    super.key,
    required this.item,
    required this.initialEdition,
    required this.isPinned,
    required this.onTogglePin,
  });

  static Future<void> show(
    BuildContext context, {
    required MagicItem item,
    DmRulesEdition? edition,
    required bool isPinned,
    required VoidCallback onTogglePin,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => ItemComparisonDialog(
        item: item,
        initialEdition: edition ?? DmRulesEdition.v2024,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
      ),
    );
  }

  @override
  State<ItemComparisonDialog> createState() => _ItemComparisonDialogState();
}

class _ItemComparisonDialogState extends State<ItemComparisonDialog> {
  late bool _pinned;
  late DmRulesEdition _activeEdition;
  bool _showDiff = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.isPinned;
    _activeEdition = widget.initialEdition;
    _showDiff = widget.item.isChangedIn2024;
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
    final item = widget.item;
    final rarityColor = item.rarity.getLegibleColor(isDark);
    final categoryColor = item.category.getLegibleColor(isDark);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final showDualView = _showDiff && item.isChangedIn2024;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: rarityColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                DndGlyph.item(
                  category: item.category,
                  rarity: item.rarity,
                  requiresAttunement: item.requiresAttunement,
                  damageAccent: item.damageAccent,
                  actionRings: item.actionRings,
                  size: 48,
                  isDarkMode: isDark,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.getName(_activeEdition),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.category.displayName,
                            style: TextStyle(
                              color: categoryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text('•', style: TextStyle(color: theme.colorScheme.outline)),
                          Text(
                            item.rarity.displayName,
                            style: TextStyle(
                              color: rarityColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (item.requiresAttunement) ...[
                            Text('•', style: TextStyle(color: theme.colorScheme.outline)),
                            Text(
                              item.getAttunementLabel(),
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF0284C7),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (item.isChangedIn2024)
                  IconButton(
                    icon: Icon(
                      _showDiff ? Icons.view_column : Icons.compare_arrows,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: _showDiff
                        ? 'Switch to Single View'
                        : 'Compare 2014 vs 2024 Side-by-Side',
                    onPressed: () {
                      HapticService.selectionTick(context);
                      setState(() => _showDiff = !_showDiff);
                    },
                  ),
                IconButton(
                  icon: Icon(
                    _pinned ? Icons.bookmark : Icons.bookmark_border,
                    color: _pinned ? pinColor : theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _pinned ? 'Remove from Reliquary' : 'Pin to Reliquary',
                  onPressed: _handlePinToggle,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                child: showDualView
                    ? _buildDualColumnView(context, item, isDark, rarityColor)
                    : _buildSingleEditionView(context, item, _activeEdition, isDark, rarityColor),
              ),
            ),

            // Bottom Actions / Edition Switcher
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!showDualView)
                  SegmentedButton<DmRulesEdition>(
                    segments: const [
                      ButtonSegment(
                        value: DmRulesEdition.v2014,
                        label: Text('2014 RAW', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: DmRulesEdition.v2024,
                        label: Text('2024 Revised', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_activeEdition},
                    onSelectionChanged: (val) {
                      HapticService.selectionTick(context);
                      setState(() => _activeEdition = val.first);
                    },
                  )
                else
                  Text(
                    'Viewing 2014 vs 2024 Side-by-Side Comparison',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleEditionView(
    BuildContext context,
    MagicItem item,
    DmRulesEdition edition,
    bool isDark,
    Color rarityColor,
  ) {
    final theme = Theme.of(context);
    final rules = item.getRules(edition);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.isChangedIn2024 && item.diffSummary != null) ...[
          _buildDiffBanner(context, item.diffSummary!, isDark),
          const SizedBox(height: 12),
        ],
        _buildStatRow(context, 'Activation', rules.activation ?? 'Standard Action'),
        if (rules.charges != null)
          _buildStatRow(context, 'Charges', rules.charges!),
        if (rules.savingThrowDc != null)
          _buildStatRow(context, 'Save DC', rules.savingThrowDc!),
        if (rules.masteryProperties != null)
          _buildStatRow(context, 'Weapon Mastery', rules.masteryProperties!),
        const SizedBox(height: 14),
        Text(
          'Rules & Description',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          rules.description,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
          ),
        ),
        if (item.actionRings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Action Traits & HUD Rings',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...item.actionRings.map((r) => _buildRingRow(r, rarityColor)),
        ],
      ],
    );
  }

  Widget _buildDualColumnView(
    BuildContext context,
    MagicItem item,
    bool isDark,
    Color rarityColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.diffSummary != null) ...[
          _buildDiffBanner(context, item.diffSummary!, isDark),
          const SizedBox(height: 12),
        ],
        if (item.diffHighlights.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Key Revision Differences',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...item.diffHighlights.map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(h, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            if (isNarrow) {
              return Column(
                children: [
                  _buildEditionColumn(context, item, DmRulesEdition.v2014, '2014 RAW Rules', Colors.blueGrey, isDark),
                  const SizedBox(height: 16),
                  _buildEditionColumn(context, item, DmRulesEdition.v2024, '2024 Revised Rules', Colors.amber, isDark),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildEditionColumn(
                    context,
                    item,
                    DmRulesEdition.v2014,
                    '2014 RAW Rules',
                    Colors.blueGrey,
                    isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildEditionColumn(
                    context,
                    item,
                    DmRulesEdition.v2024,
                    '2024 Revised Rules',
                    Colors.amber,
                    isDark,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditionColumn(
    BuildContext context,
    MagicItem item,
    DmRulesEdition edition,
    String header,
    Color headerColor,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final rules = item.getRules(edition);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              header,
              style: TextStyle(
                color: headerColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildStatRow(context, 'Activation', rules.activation ?? 'Standard Action'),
          if (rules.charges != null)
            _buildStatRow(context, 'Charges', rules.charges!),
          if (rules.savingThrowDc != null)
            _buildStatRow(context, 'Save DC', rules.savingThrowDc!),
          if (rules.masteryProperties != null)
            _buildStatRow(context, 'Weapon Mastery', rules.masteryProperties!),
          const SizedBox(height: 8),
          Text(
            rules.description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffBanner(BuildContext context, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingRow(ActionTraitRing ring, Color rarityColor) {
    final ringColor = ring.getEffectiveColor(rarityColor);
    final label = ring.label ??
        (ring.damageLegend.isNotEmpty
            ? '${ring.ringType.displayName} (${ring.damageLegend})'
            : ring.ringType.displayName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '${ring.ringType.displayName}: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ringColor),
          ),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
