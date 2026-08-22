import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../glyphs/glyph_tokens.dart';

import '../common/filter_bottom_sheet_frame.dart';

/// Modal bottom sheet allowing multi-dimensional filtering of the Item Compendium.
class ItemFilterSheet extends StatefulWidget {
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
  State<ItemFilterSheet> createState() => _ItemFilterSheetState();
}

class _ItemFilterSheetState extends State<ItemFilterSheet> {
  late ItemCategory? _category;
  late ItemRarity? _rarity;
  late bool _attunement;
  late bool _pinned;
  late bool _changedIn2024;
  late DamageAccent? _damageAccent;

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _rarity = widget.selectedRarity;
    _attunement = widget.showOnlyAttunement;
    _pinned = widget.showOnlyPinned;
    _changedIn2024 = widget.showOnlyChangedIn2024;
    _damageAccent = widget.selectedDamageAccent;
  }

  void _handleResetAll() {
    HapticService.selectionTick(context);
    setState(() {
      _category = null;
      _rarity = null;
      _attunement = false;
      _pinned = false;
      _changedIn2024 = false;
      _damageAccent = null;
    });
    widget.onResetAll();
  }

  Widget _buildAccessibleChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    Widget? avatar,
    Color? customSelectedColor,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary;
    final activeColor = customSelectedColor ?? primaryColor;

    final backgroundColor = isSelected
        ? (isDark
            ? activeColor.withValues(alpha: 0.28)
            : activeColor.withValues(alpha: 0.16))
        : (isDark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF1F5F9));

    final borderColor = isSelected
        ? activeColor
        : (isDark
            ? const Color(0xFF475569)
            : const Color(0xFF94A3B8));

    final textColor = isSelected
        ? (isDark
            ? Colors.white
            : (customSelectedColor != null
                ? const Color(0xFF0F172A)
                : theme.colorScheme.primary))
        : (isDark
            ? const Color(0xFFF1F5F9)
            : const Color(0xFF0F172A));

    return Tooltip(
      message: tooltip ?? label,
      child: FilterChip(
        avatar: avatar,
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: backgroundColor,
        selectedColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: borderColor,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (selected) {
          HapticService.selectionTick(context);
          onSelected(selected);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pinColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE);
    final diffColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final attuneColor = isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary;

    return FilterBottomSheetFrame(
      icon: Icons.tune,
      title: 'Filter Magic Items',
      onResetAll: _handleResetAll,
      children: [
        // Quick Toggles Section
        Text(
          'Quick Filters',
          style: TextStyle(
            color: isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAccessibleChip(
              context: context,
              label: 'Personal Reliquary Only',
              avatar: Icon(
                _pinned ? Icons.bookmark : Icons.bookmark_border,
                size: 16,
                color: _pinned ? pinColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              customSelectedColor: pinColor,
              isSelected: _pinned,
              onSelected: (val) {
                setState(() => _pinned = val);
                widget.onPinnedToggled(val);
              },
            ),
            _buildAccessibleChip(
              context: context,
              label: '2024 Diffs Only',
              avatar: Icon(
                Icons.auto_awesome,
                size: 16,
                color: _changedIn2024 ? diffColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              customSelectedColor: diffColor,
              isSelected: _changedIn2024,
              onSelected: (val) {
                setState(() => _changedIn2024 = val);
                widget.onChangedIn2024Toggled(val);
              },
            ),
            _buildAccessibleChip(
              context: context,
              label: 'Requires Attunement',
              avatar: Icon(
                Icons.link,
                size: 16,
                color: _attunement ? attuneColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              customSelectedColor: attuneColor,
              isSelected: _attunement,
              onSelected: (val) {
                setState(() => _attunement = val);
                widget.onAttunementToggled(val);
              },
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Item Rarity Section
        Text(
          'Item Rarity',
          style: TextStyle(
            color: isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildAccessibleChip(
              context: context,
              label: 'All Rarities',
              isSelected: _rarity == null,
              onSelected: (sel) {
                if (sel) {
                  setState(() => _rarity = null);
                  widget.onRarityChanged(null);
                }
              },
            ),
            ...ItemRarity.values.map((rarity) {
              final color = rarity.getLegibleColor(isDark);
              final isSelected = _rarity == rarity;
              return _buildAccessibleChip(
                context: context,
                label: rarity.displayName,
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                customSelectedColor: color,
                isSelected: isSelected,
                onSelected: (sel) {
                  final newRarity = sel ? rarity : null;
                  setState(() => _rarity = newRarity);
                  widget.onRarityChanged(newRarity);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 18),

        // Item Category Section
        Text(
          'Item Category',
          style: TextStyle(
            color: isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildAccessibleChip(
              context: context,
              label: 'All Categories',
              isSelected: _category == null,
              onSelected: (sel) {
                if (sel) {
                  setState(() => _category = null);
                  widget.onCategoryChanged(null);
                }
              },
            ),
            ...ItemCategory.values.map((cat) {
              final color = cat.getLegibleColor(isDark);
              final isSelected = _category == cat;
              return _buildAccessibleChip(
                context: context,
                label: cat.displayName,
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                customSelectedColor: color,
                isSelected: isSelected,
                onSelected: (sel) {
                  final newCat = sel ? cat : null;
                  setState(() => _category = newCat);
                  widget.onCategoryChanged(newCat);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 18),

        // Damage / Elemental Accent Section
        Text(
          'Damage Type / Elemental Affiliation',
          style: TextStyle(
            color: isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildAccessibleChip(
              context: context,
              label: 'Any Element',
              isSelected: _damageAccent == null,
              onSelected: (sel) {
                if (sel) {
                  setState(() => _damageAccent = null);
                  widget.onDamageAccentChanged(null);
                }
              },
            ),
            ...DamageAccent.values.map((accent) {
              final isSelected = _damageAccent == accent;
              return _buildAccessibleChip(
                context: context,
                label: accent.displayName,
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent.color,
                    shape: BoxShape.circle,
                  ),
                ),
                customSelectedColor: accent.color,
                isSelected: isSelected,
                onSelected: (sel) {
                  final newAccent = sel ? accent : null;
                  setState(() => _damageAccent = newAccent);
                  widget.onDamageAccentChanged(newAccent);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
