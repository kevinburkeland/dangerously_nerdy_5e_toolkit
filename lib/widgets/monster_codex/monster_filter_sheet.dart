import 'package:flutter/material.dart';
import '../../models/monster_codex_data.dart';
import '../../services/haptic_service.dart';
import '../glyphs/glyph_tokens.dart';
import '../common/filter_bottom_sheet_frame.dart';

/// Modal bottom sheet allowing multi-dimensional filtering and sorting of the Monster Codex.
class MonsterFilterSheet extends StatefulWidget {
  final MonsterSortMode selectedSortMode;
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

  final ValueChanged<MonsterSortMode> onSortModeChanged;
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
    this.selectedSortMode = MonsterSortMode.crAscending,
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
    required this.onSortModeChanged,
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
    MonsterSortMode selectedSortMode = MonsterSortMode.crAscending,
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
    required ValueChanged<MonsterSortMode> onSortModeChanged,
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
        selectedSortMode: selectedSortMode,
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
        onSortModeChanged: onSortModeChanged,
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
  State<MonsterFilterSheet> createState() => _MonsterFilterSheetState();
}

class _MonsterFilterSheetState extends State<MonsterFilterSheet> {
  late MonsterSortMode _sortMode;
  late String? _type;
  late String? _size;
  late MonsterCrBand _crBand;
  late bool _pinned;
  late bool _spellSummons;
  late bool _magicItems;
  late bool _multiattack;
  late bool _spellcasters;
  late bool _reactions;
  late bool _resistances;
  late bool _legendary;
  late bool _diff2024;

  @override
  void initState() {
    super.initState();
    _sortMode = widget.selectedSortMode;
    _type = widget.selectedType;
    _size = widget.selectedSize;
    _crBand = widget.selectedCrBand;
    _pinned = widget.showOnlyPinned;
    _spellSummons = widget.showOnlySpellSummons;
    _magicItems = widget.showOnlyMagicItems;
    _multiattack = widget.showOnlyMultiattack;
    _spellcasters = widget.showOnlySpellcasters;
    _reactions = widget.showOnlyReactions;
    _resistances = widget.showOnlyResistances;
    _legendary = widget.showOnlyLegendary;
    _diff2024 = widget.showOnly2024Diff;
  }

  void _handleResetAll() {
    HapticService.selectionTick(context);
    setState(() {
      _sortMode = MonsterSortMode.crAscending;
      _type = null;
      _size = null;
      _crBand = MonsterCrBand.all;
      _pinned = false;
      _spellSummons = false;
      _magicItems = false;
      _multiattack = false;
      _spellcasters = false;
      _reactions = false;
      _resistances = false;
      _legendary = false;
      _diff2024 = false;
    });
    widget.onResetAll();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pinColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE);
    final diffColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final primaryAccent = isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary;

    final sizeOptions = ['Tiny', 'Small', 'Medium', 'Large', 'Huge', 'Gargantuan'];

    return FilterBottomSheetFrame(
      icon: Icons.filter_list,
      title: 'Filter & Sort Monster Codex',
      onResetAll: _handleResetAll,
      children: [
        const SizedBox(height: 16),

        // Sort Order Section
        _buildSectionHeader(context, 'Sort Order'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in MonsterSortMode.values)
              _buildAccessibleChip(
                context: context,
                label: mode.label,
                icon: mode.icon,
                isSelected: _sortMode == mode,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _sortMode = mode);
                    widget.onSortModeChanged(mode);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Quick Flags Section
        _buildSectionHeader(context, 'Quick Flags & Bookmarks'),
        const SizedBox(height: 6),
        _buildSwitchTile(
          context: context,
          title: '2024 Revised / Diffs Only',
          subtitle: 'Show creatures with 2024 revised rules changes',
          value: _diff2024,
          activeColor: diffColor,
          icon: Icons.auto_awesome,
          onChanged: (val) {
            setState(() => _diff2024 = val);
            widget.on2024DiffToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'My Bookmarked Bestiary Only',
          subtitle: 'Show only creatures pinned to your favorites',
          value: _pinned,
          activeColor: pinColor,
          icon: Icons.bookmark,
          onChanged: (val) {
            setState(() => _pinned = val);
            widget.onPinnedToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'Spell Summons Only',
          subtitle: 'Creatures conjured via 5e spells',
          value: _spellSummons,
          activeColor: primaryAccent,
          icon: Icons.auto_fix_high,
          onChanged: (val) {
            setState(() => _spellSummons = val);
            widget.onSpellSummonsToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'Magic Item Summons Only',
          subtitle: 'Creatures spawned from magical items & tokens',
          value: _magicItems,
          activeColor: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
          icon: Icons.token_outlined,
          onChanged: (val) {
            setState(() => _magicItems = val);
            widget.onMagicItemsToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'Has Multiattack',
          subtitle: 'Monsters with multi-action attack sequences',
          value: _multiattack,
          activeColor: isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
          icon: Icons.flash_on,
          onChanged: (val) {
            setState(() => _multiattack = val);
            widget.onMultiattackToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'Spellcasters',
          subtitle: 'Monsters with innate or prepared spellcasting',
          value: _spellcasters,
          activeColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          icon: Icons.auto_awesome,
          onChanged: (val) {
            setState(() => _spellcasters = val);
            widget.onSpellcastersToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'Has Reactions',
          subtitle: 'Creatures with special reaction abilities',
          value: _reactions,
          activeColor: isDark ? const Color(0xFFA855F7) : const Color(0xFF7E22CE),
          icon: Icons.reply,
          onChanged: (val) {
            setState(() => _reactions = val);
            widget.onReactionsToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'Has Resistances or Immunities',
          subtitle: 'Creatures with damage mitigation traits',
          value: _resistances,
          activeColor: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488),
          icon: Icons.shield,
          onChanged: (val) {
            setState(() => _resistances = val);
            widget.onResistancesToggled(val);
          },
        ),
        _buildSwitchTile(
          context: context,
          title: 'Legendary Creatures',
          subtitle: 'Bosses with legendary resistances or actions',
          value: _legendary,
          activeColor: isDark ? const Color(0xFFFDE047) : const Color(0xFFCA8A04),
          icon: Icons.stars,
          onChanged: (val) {
            setState(() => _legendary = val);
            widget.onLegendaryToggled(val);
          },
        ),
        const SizedBox(height: 16),

        // Challenge Rating (CR) Band Filter
        _buildSectionHeader(context, 'Challenge Rating (CR) Band'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final band in MonsterCrBand.values)
              _buildAccessibleChip(
                context: context,
                label: band.label,
                isSelected: _crBand == band,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _crBand = band);
                    widget.onCrBandChanged(band);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Creature Type Filter
        _buildSectionHeader(context, 'Creature Type'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAccessibleChip(
              context: context,
              label: 'All Types',
              isSelected: _type == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _type = null);
                  widget.onTypeChanged(null);
                }
              },
            ),
            ...CreatureType.values.map((type) {
              final isSelected = _type?.toLowerCase() == type.displayName.toLowerCase();
              return _buildAccessibleChip(
                context: context,
                label: type.displayName,
                isSelected: isSelected,
                onSelected: (selected) {
                  final newType = selected ? type.displayName : null;
                  setState(() => _type = newType);
                  widget.onTypeChanged(newType);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        // Creature Size Filter
        _buildSectionHeader(context, 'Creature Size'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildAccessibleChip(
              context: context,
              label: 'All Sizes',
              isSelected: _size == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _size = null);
                  widget.onSizeChanged(null);
                }
              },
            ),
            ...sizeOptions.map((size) {
              final isSelected = _size == size;
              return _buildAccessibleChip(
                context: context,
                label: size,
                isSelected: isSelected,
                onSelected: (selected) {
                  final newSize = selected ? size : null;
                  setState(() => _size = newSize);
                  widget.onSizeChanged(newSize);
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary;

    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAccessibleChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    IconData? icon,
    Color? customSelectedColor,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary;
    final activeColor = customSelectedColor ?? primaryColor;

    // High-contrast WCAG 2.1 AA/AAA compliant colors
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

    final iconColor = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));

    return Tooltip(
      message: tooltip ?? label,
      child: FilterChip(
        avatar: icon != null
            ? Icon(
                icon,
                size: 16,
                color: iconColor,
              )
            : null,
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

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return SwitchListTile(
      value: value,
      activeThumbColor: activeColor,
      activeTrackColor: activeColor.withValues(alpha: isDark ? 0.35 : 0.25),
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, size: 16, color: activeColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 24, top: 2),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: subtitleColor,
            height: 1.3,
          ),
        ),
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
