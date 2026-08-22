import 'package:flutter/material.dart';
import '../../models/spellbook_data.dart';
import '../../services/haptic_service.dart';

import '../common/filter_bottom_sheet_frame.dart';

/// Modal bottom sheet allowing multi-dimensional filtering of the Spellbook.
class SpellFilterSheet extends StatefulWidget {
  final int? selectedLevel;
  final SpellSchool? selectedSchool;
  final SpellClass? selectedClass;
  final bool showOnlyChangedIn2024;
  final bool showOnlyPinned;
  final bool showOnlyRitual;
  final bool showOnlyConcentration;

  final ValueChanged<int?> onLevelChanged;
  final ValueChanged<SpellSchool?> onSchoolChanged;
  final ValueChanged<SpellClass?> onClassChanged;
  final ValueChanged<bool> onChangedIn2024Toggled;
  final ValueChanged<bool> onPinnedToggled;
  final ValueChanged<bool> onRitualToggled;
  final ValueChanged<bool> onConcentrationToggled;
  final VoidCallback onResetAll;

  const SpellFilterSheet({
    super.key,
    required this.selectedLevel,
    required this.selectedSchool,
    required this.selectedClass,
    required this.showOnlyChangedIn2024,
    required this.showOnlyPinned,
    required this.showOnlyRitual,
    required this.showOnlyConcentration,
    required this.onLevelChanged,
    required this.onSchoolChanged,
    required this.onClassChanged,
    required this.onChangedIn2024Toggled,
    required this.onPinnedToggled,
    required this.onRitualToggled,
    required this.onConcentrationToggled,
    required this.onResetAll,
  });

  static Future<void> show(
    BuildContext context, {
    required int? selectedLevel,
    required SpellSchool? selectedSchool,
    required SpellClass? selectedClass,
    required bool showOnlyChangedIn2024,
    required bool showOnlyPinned,
    required bool showOnlyRitual,
    required bool showOnlyConcentration,
    required ValueChanged<int?> onLevelChanged,
    required ValueChanged<SpellSchool?> onSchoolChanged,
    required ValueChanged<SpellClass?> onClassChanged,
    required ValueChanged<bool> onChangedIn2024Toggled,
    required ValueChanged<bool> onPinnedToggled,
    required ValueChanged<bool> onRitualToggled,
    required ValueChanged<bool> onConcentrationToggled,
    required VoidCallback onResetAll,
  }) {
    HapticService.selectionTick(context);
    return FilterBottomSheetFrame.show(
      context,
      builder: (ctx) => SpellFilterSheet(
        selectedLevel: selectedLevel,
        selectedSchool: selectedSchool,
        selectedClass: selectedClass,
        showOnlyChangedIn2024: showOnlyChangedIn2024,
        showOnlyPinned: showOnlyPinned,
        showOnlyRitual: showOnlyRitual,
        showOnlyConcentration: showOnlyConcentration,
        onLevelChanged: onLevelChanged,
        onSchoolChanged: onSchoolChanged,
        onClassChanged: onClassChanged,
        onChangedIn2024Toggled: onChangedIn2024Toggled,
        onPinnedToggled: onPinnedToggled,
        onRitualToggled: onRitualToggled,
        onConcentrationToggled: onConcentrationToggled,
        onResetAll: onResetAll,
      ),
    );
  }

  @override
  State<SpellFilterSheet> createState() => _SpellFilterSheetState();
}

class _SpellFilterSheetState extends State<SpellFilterSheet> {
  late int? _level;
  late SpellSchool? _school;
  late SpellClass? _class;
  late bool _changedIn2024;
  late bool _pinned;
  late bool _ritual;
  late bool _concentration;

  @override
  void initState() {
    super.initState();
    _level = widget.selectedLevel;
    _school = widget.selectedSchool;
    _class = widget.selectedClass;
    _changedIn2024 = widget.showOnlyChangedIn2024;
    _pinned = widget.showOnlyPinned;
    _ritual = widget.showOnlyRitual;
    _concentration = widget.showOnlyConcentration;
  }

  void _handleResetAll() {
    HapticService.selectionTick(context);
    setState(() {
      _level = null;
      _school = null;
      _class = null;
      _changedIn2024 = false;
      _pinned = false;
      _ritual = false;
      _concentration = false;
    });
    widget.onResetAll();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pinColor = isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE);
    final diffColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final concColor = isDark ? const Color(0xFFFDE047) : const Color(0xFFB45309);
    final ritualColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0E7490);

    return FilterBottomSheetFrame(
      icon: Icons.menu_book,
      title: 'Filter Spellbook',
      onResetAll: _handleResetAll,
      children: [
        // Quick Feature Toggles
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
              label: 'My Pinned Spells',
              icon: Icons.bookmark,
              customSelectedColor: pinColor,
              isSelected: _pinned,
              onSelected: (val) {
                setState(() => _pinned = val);
                widget.onPinnedToggled(val);
              },
            ),
            _buildAccessibleChip(
              context: context,
              label: '2024 Revised Only',
              icon: Icons.auto_awesome,
              customSelectedColor: diffColor,
              isSelected: _changedIn2024,
              onSelected: (val) {
                setState(() => _changedIn2024 = val);
                widget.onChangedIn2024Toggled(val);
              },
            ),
            _buildAccessibleChip(
              context: context,
              label: 'Concentration',
              icon: Icons.psychology_outlined,
              customSelectedColor: concColor,
              isSelected: _concentration,
              onSelected: (val) {
                setState(() => _concentration = val);
                widget.onConcentrationToggled(val);
              },
            ),
            _buildAccessibleChip(
              context: context,
              label: 'Ritual',
              icon: Icons.auto_stories,
              customSelectedColor: ritualColor,
              isSelected: _ritual,
              onSelected: (val) {
                setState(() => _ritual = val);
                widget.onRitualToggled(val);
              },
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Spell Level Filter
        Text(
          'Spell Level',
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
              label: 'All Levels',
              isSelected: _level == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _level = null);
                  widget.onLevelChanged(null);
                }
              },
            ),
            _buildAccessibleChip(
              context: context,
              label: 'Cantrip (0)',
              isSelected: _level == 0,
              onSelected: (selected) {
                final newLvl = selected ? 0 : null;
                setState(() => _level = newLvl);
                widget.onLevelChanged(newLvl);
              },
            ),
            ...List.generate(9, (index) {
              final lvl = index + 1;
              return _buildAccessibleChip(
                context: context,
                label: 'Level $lvl',
                isSelected: _level == lvl,
                onSelected: (selected) {
                  final newLvl = selected ? lvl : null;
                  setState(() => _level = newLvl);
                  widget.onLevelChanged(newLvl);
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 18),

        // Class Filter
        Text(
          'Class List',
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
              label: 'All Classes',
              isSelected: _class == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _class = null);
                  widget.onClassChanged(null);
                }
              },
            ),
            ...SpellClass.values.map(
              (cls) => _buildAccessibleChip(
                context: context,
                label: cls.label,
                icon: cls.icon,
                isSelected: _class == cls,
                onSelected: (selected) {
                  final newCls = selected ? cls : null;
                  setState(() => _class = newCls);
                  widget.onClassChanged(newCls);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Magic School Filter
        Text(
          'School of Magic',
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
              label: 'All Schools',
              isSelected: _school == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _school = null);
                  widget.onSchoolChanged(null);
                }
              },
            ),
            ...SpellSchool.values.map(
              (school) {
                final schoolColor = school.getLegibleColor(isDark);
                return _buildAccessibleChip(
                  context: context,
                  label: school.label,
                  icon: school.icon,
                  customSelectedColor: schoolColor,
                  isSelected: _school == school,
                  onSelected: (selected) {
                    final newSchool = selected ? school : null;
                    setState(() => _school = newSchool);
                    widget.onSchoolChanged(newSchool);
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
