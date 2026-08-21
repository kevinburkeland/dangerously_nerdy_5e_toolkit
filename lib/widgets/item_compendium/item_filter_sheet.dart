import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../glyphs/glyph_tokens.dart';

import '../common/filter_bottom_sheet_frame.dart';

/// Modal bottom sheet allowing multi-dimensional filtering of the Item Compendium.
class ItemFilterSheet extends StatelessWidget {
  final ItemCategory? selectedCategory;
  final ItemRarity? selectedRarity;
  final bool showOnlyAttunement;
  final bool showOnlyPinned;
  final bool showOnlyChangedIn2024;
  final DamageAccent? selectedDamageAccent;

  final ValueChanged<ItemCategory?> onCategoryChanged;
  final ValueChanged<ItemRarity?> onRarityChanged;
  final ValueChanged<bool> onAttunementToggled;
  final ValueChanged<bool> onPinnedToggled;
  final ValueChanged<bool> onChangedIn2024Toggled;
  final ValueChanged<DamageAccent?> onDamageAccentChanged;
  final VoidCallback onResetAll;

  const ItemFilterSheet({
    super.key,
    required this.selectedCategory,
    required this.selectedRarity,
    required this.showOnlyAttunement,
    required this.showOnlyPinned,
    required this.showOnlyChangedIn2024,
    required this.selectedDamageAccent,
    required this.onCategoryChanged,
    required this.onRarityChanged,
    required this.onAttunementToggled,
    required this.onPinnedToggled,
    required this.onChangedIn2024Toggled,
    required this.onDamageAccentChanged,
    required this.onResetAll,
  });

  static Future<void> show(
    BuildContext context, {
    required ItemCategory? selectedCategory,
    required ItemRarity? selectedRarity,
    required bool showOnlyAttunement,
    required bool showOnlyPinned,
    required bool showOnlyChangedIn2024,
    required DamageAccent? selectedDamageAccent,
    required ValueChanged<ItemCategory?> onCategoryChanged,
    required ValueChanged<ItemRarity?> onRarityChanged,
    required ValueChanged<bool> onAttunementToggled,
    required ValueChanged<bool> onPinnedToggled,
    required ValueChanged<bool> onChangedIn2024Toggled,
    required ValueChanged<DamageAccent?> onDamageAccentChanged,
    required VoidCallback onResetAll,
  }) {
    HapticService.selectionTick(context);
    return FilterBottomSheetFrame.show(
      context,
      builder: (ctx) => ItemFilterSheet(
        selectedCategory: selectedCategory,
        selectedRarity: selectedRarity,
        showOnlyAttunement: showOnlyAttunement,
        showOnlyPinned: showOnlyPinned,
        showOnlyChangedIn2024: showOnlyChangedIn2024,
        selectedDamageAccent: selectedDamageAccent,
        onCategoryChanged: onCategoryChanged,
        onRarityChanged: onRarityChanged,
        onAttunementToggled: onAttunementToggled,
        onPinnedToggled: onPinnedToggled,
        onChangedIn2024Toggled: onChangedIn2024Toggled,
        onDamageAccentChanged: onDamageAccentChanged,
        onResetAll: onResetAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FilterBottomSheetFrame(
      icon: Icons.tune,
      title: 'Filter Magic Items',
      onResetAll: () {
        HapticService.selectionTick(context);
        onResetAll();
        Navigator.of(context).pop();
      },
      children: [
        // Quick Toggles Section
        Text(
          'Quick Filters',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: Icon(
                showOnlyPinned ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
              ),
              label: const Text('Personal Reliquary Only'),
              selected: showOnlyPinned,
              onSelected: (val) {
                HapticService.selectionTick(context);
                onPinnedToggled(val);
              },
            ),
            FilterChip(
              avatar: const Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
              label: const Text('2024 Diffs Only'),
              selected: showOnlyChangedIn2024,
              onSelected: (val) {
                HapticService.selectionTick(context);
                onChangedIn2024Toggled(val);
              },
            ),
            FilterChip(
              avatar: const Icon(Icons.link, size: 16),
              label: const Text('Requires Attunement'),
              selected: showOnlyAttunement,
              onSelected: (val) {
                HapticService.selectionTick(context);
                onAttunementToggled(val);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Item Rarity Section
        Text(
          'Item Rarity',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All Rarities'),
              selected: selectedRarity == null,
              onSelected: (sel) {
                if (sel) {
                  HapticService.selectionTick(context);
                  onRarityChanged(null);
                }
              },
            ),
            ...ItemRarity.values.map((rarity) {
              final color = rarity.getLegibleColor(isDark);
              final isSelected = selectedRarity == rarity;
              return ChoiceChip(
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  rarity.displayName,
                  style: TextStyle(
                    color: isSelected ? null : color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (sel) {
                  HapticService.selectionTick(context);
                  onRarityChanged(sel ? rarity : null);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        // Item Category Section
        Text(
          'Item Category',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All Categories'),
              selected: selectedCategory == null,
              onSelected: (sel) {
                if (sel) {
                  HapticService.selectionTick(context);
                  onCategoryChanged(null);
                }
              },
            ),
            ...ItemCategory.values.map((cat) {
              final color = cat.getLegibleColor(isDark);
              final isSelected = selectedCategory == cat;
              return ChoiceChip(
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  cat.displayName,
                  style: TextStyle(
                    color: isSelected ? null : color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (sel) {
                  HapticService.selectionTick(context);
                  onCategoryChanged(sel ? cat : null);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        // Damage / Elemental Accent Section
        Text(
          'Damage Type / Elemental Affiliation',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Any Element'),
              selected: selectedDamageAccent == null,
              onSelected: (sel) {
                if (sel) {
                  HapticService.selectionTick(context);
                  onDamageAccentChanged(null);
                }
              },
            ),
            ...DamageAccent.values.map((accent) {
              final isSelected = selectedDamageAccent == accent;
              return ChoiceChip(
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent.color,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(accent.displayName),
                selected: isSelected,
                onSelected: (sel) {
                  HapticService.selectionTick(context);
                  onDamageAccentChanged(sel ? accent : null);
                },
              );
            }),
          ],
        ),
      ],
    );
  }
}
