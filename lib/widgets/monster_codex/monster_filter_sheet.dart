import 'package:flutter/material.dart';
import '../../models/monster_codex_data.dart';
import '../../services/haptic_service.dart';
import '../glyphs/glyph_tokens.dart';

import '../common/filter_bottom_sheet_frame.dart';

/// Modal bottom sheet allowing multi-dimensional filtering of the Monster Codex.
class MonsterFilterSheet extends StatelessWidget {
  final String? selectedType;
  final String? selectedSize;
  final MonsterCrBand selectedCrBand;
  final bool showOnlyPinned;
  final bool showOnlySpellSummons;
  final bool showOnlyMagicItems;
  final bool showOnlyMultiattack;
  final bool showOnlySpellcasters;
  final bool showOnlyReactions;
  final bool showOnlyResistances;
  final bool showOnlyLegendary;
  final bool showOnly2024Diff;

  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onSizeChanged;
  final ValueChanged<MonsterCrBand> onCrBandChanged;
  final ValueChanged<bool> onPinnedToggled;
  final ValueChanged<bool> onSpellSummonsToggled;
  final ValueChanged<bool> onMagicItemsToggled;
  final ValueChanged<bool> onMultiattackToggled;
  final ValueChanged<bool> onSpellcastersToggled;
  final ValueChanged<bool> onReactionsToggled;
  final ValueChanged<bool> onResistancesToggled;
  final ValueChanged<bool> onLegendaryToggled;
  final ValueChanged<bool> on2024DiffToggled;
  final VoidCallback onResetAll;

  const MonsterFilterSheet({
    super.key,
    required this.selectedType,
    required this.selectedSize,
    required this.selectedCrBand,
    required this.showOnlyPinned,
    required this.showOnlySpellSummons,
    required this.showOnlyMagicItems,
    required this.showOnlyMultiattack,
    required this.showOnlySpellcasters,
    required this.showOnlyReactions,
    required this.showOnlyResistances,
    required this.showOnlyLegendary,
    required this.showOnly2024Diff,
    required this.onTypeChanged,
    required this.onSizeChanged,
    required this.onCrBandChanged,
    required this.onPinnedToggled,
    required this.onSpellSummonsToggled,
    required this.onMagicItemsToggled,
    required this.onMultiattackToggled,
    required this.onSpellcastersToggled,
    required this.onReactionsToggled,
    required this.onResistancesToggled,
    required this.onLegendaryToggled,
    required this.on2024DiffToggled,
    required this.onResetAll,
  });

  static Future<void> show(
    BuildContext context, {
    required String? selectedType,
    required String? selectedSize,
    required MonsterCrBand selectedCrBand,
    required bool showOnlyPinned,
    required bool showOnlySpellSummons,
    required bool showOnlyMagicItems,
    required bool showOnlyMultiattack,
    required bool showOnlySpellcasters,
    required bool showOnlyReactions,
    required bool showOnlyResistances,
    required bool showOnlyLegendary,
    required bool showOnly2024Diff,
    required ValueChanged<String?> onTypeChanged,
    required ValueChanged<String?> onSizeChanged,
    required ValueChanged<MonsterCrBand> onCrBandChanged,
    required ValueChanged<bool> onPinnedToggled,
    required ValueChanged<bool> onSpellSummonsToggled,
    required ValueChanged<bool> onMagicItemsToggled,
    required ValueChanged<bool> onMultiattackToggled,
    required ValueChanged<bool> onSpellcastersToggled,
    required ValueChanged<bool> onReactionsToggled,
    required ValueChanged<bool> onResistancesToggled,
    required ValueChanged<bool> onLegendaryToggled,
    required ValueChanged<bool> on2024DiffToggled,
    required VoidCallback onResetAll,
  }) {
    HapticService.selectionTick(context);
    return FilterBottomSheetFrame.show(
      context,
      builder: (ctx) => MonsterFilterSheet(
        selectedType: selectedType,
        selectedSize: selectedSize,
        selectedCrBand: selectedCrBand,
        showOnlyPinned: showOnlyPinned,
        showOnlySpellSummons: showOnlySpellSummons,
        showOnlyMagicItems: showOnlyMagicItems,
        showOnlyMultiattack: showOnlyMultiattack,
        showOnlySpellcasters: showOnlySpellcasters,
        showOnlyReactions: showOnlyReactions,
        showOnlyResistances: showOnlyResistances,
        showOnlyLegendary: showOnlyLegendary,
        showOnly2024Diff: showOnly2024Diff,
        onTypeChanged: onTypeChanged,
        onSizeChanged: onSizeChanged,
        onCrBandChanged: onCrBandChanged,
        onPinnedToggled: onPinnedToggled,
        onSpellSummonsToggled: onSpellSummonsToggled,
        onMagicItemsToggled: onMagicItemsToggled,
        onMultiattackToggled: onMultiattackToggled,
        onSpellcastersToggled: onSpellcastersToggled,
        onReactionsToggled: onReactionsToggled,
        onResistancesToggled: onResistancesToggled,
        onLegendaryToggled: onLegendaryToggled,
        on2024DiffToggled: on2024DiffToggled,
        onResetAll: onResetAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);

    final sizeOptions = ['Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Gargantuan'];

    return FilterBottomSheetFrame(
      icon: Icons.filter_list,
      title: 'Filter Monster Codex',
      onResetAll: () {
        HapticService.selectionTick(context);
        onResetAll();
      },
      children: [
        const SizedBox(height: 16),

        // Quick Flags Section
        _buildSectionHeader(theme, 'Quick Flags & Bookmarks'),
        const SizedBox(height: 6),
        _buildSwitchTile(
          title: '2024 Revised / Diffs Only',
          subtitle: 'Show creatures with 2024 revised rules changes',
          value: showOnly2024Diff,
          activeColor: diffColor,
          icon: Icons.auto_awesome,
          onChanged: on2024DiffToggled,
        ),
        _buildSwitchTile(
          title: 'My Bookmarked Bestiary Only',
          subtitle: 'Show only creatures pinned to your favorites',
          value: showOnlyPinned,
          activeColor: pinColor,
          icon: Icons.bookmark,
          onChanged: onPinnedToggled,
        ),
        _buildSwitchTile(
          title: 'Spell Summons Only',
          subtitle: 'Creatures conjured via 5e spells',
          value: showOnlySpellSummons,
          activeColor: theme.colorScheme.primary,
          icon: Icons.auto_fix_high,
          onChanged: onSpellSummonsToggled,
        ),
        _buildSwitchTile(
          title: 'Magic Item Summons Only',
          subtitle: 'Creatures spawned from magical items & tokens',
          value: showOnlyMagicItems,
          activeColor: Colors.amber,
          icon: Icons.token_outlined,
          onChanged: onMagicItemsToggled,
        ),
        _buildSwitchTile(
          title: 'Has Multiattack',
          subtitle: 'Monsters with multi-action attack sequences',
          value: showOnlyMultiattack,
          activeColor: Colors.deepOrangeAccent,
          icon: Icons.flash_on,
          onChanged: onMultiattackToggled,
        ),
        _buildSwitchTile(
          title: 'Spellcasters',
          subtitle: 'Monsters with innate or prepared spellcasting',
          value: showOnlySpellcasters,
          activeColor: Colors.indigoAccent,
          icon: Icons.auto_awesome,
          onChanged: onSpellcastersToggled,
        ),
        _buildSwitchTile(
          title: 'Has Reactions',
          subtitle: 'Creatures with special reaction abilities',
          value: showOnlyReactions,
          activeColor: Colors.purpleAccent,
          icon: Icons.reply,
          onChanged: onReactionsToggled,
        ),
        _buildSwitchTile(
          title: 'Has Resistances or Immunities',
          subtitle: 'Creatures with damage mitigation traits',
          value: showOnlyResistances,
          activeColor: Colors.tealAccent,
          icon: Icons.shield,
          onChanged: onResistancesToggled,
        ),
        _buildSwitchTile(
          title: 'Legendary Creatures',
          subtitle: 'Bosses with legendary resistances or actions',
          value: showOnlyLegendary,
          activeColor: const Color(0xFFFDE047),
          icon: Icons.stars,
          onChanged: onLegendaryToggled,
        ),
        const SizedBox(height: 16),

        // Challenge Rating (CR) Band Filter
        _buildSectionHeader(theme, 'Challenge Rating (CR) Band'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final band in MonsterCrBand.values)
              ChoiceChip(
                label: Text(band.label, style: const TextStyle(fontSize: 12)),
                selected: selectedCrBand == band,
                onSelected: (selected) {
                  if (selected) {
                    HapticService.selectionTick(context);
                    onCrBandChanged(band);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Creature Type Filter
        _buildSectionHeader(theme, 'Creature Type'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All Types', style: TextStyle(fontSize: 12)),
              selected: selectedType == null,
              onSelected: (selected) {
                if (selected) {
                  HapticService.selectionTick(context);
                  onTypeChanged(null);
                }
              },
            ),
            ...CreatureType.values.map((type) {
              return ChoiceChip(
                label: Text(type.displayName, style: const TextStyle(fontSize: 12)),
                selected: selectedType?.toLowerCase() == type.displayName.toLowerCase(),
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  onTypeChanged(selected ? type.displayName : null);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        // Creature Size Filter
        _buildSectionHeader(theme, 'Creature Size'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All Sizes', style: TextStyle(fontSize: 12)),
              selected: selectedSize == null,
              onSelected: (selected) {
                if (selected) {
                  HapticService.selectionTick(context);
                  onSizeChanged(null);
                }
              },
            ),
            ...sizeOptions.map((size) {
              return ChoiceChip(
                label: Text(size, style: const TextStyle(fontSize: 12)),
                selected: selectedSize == size,
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  onSizeChanged(selected ? size : null);
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: (val) {
        onChanged(val);
      },
      title: Row(
        children: [
          Icon(icon, size: 16, color: activeColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
