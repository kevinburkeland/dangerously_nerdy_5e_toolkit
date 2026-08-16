import 'package:flutter/material.dart';
import '../../models/spellbook_data.dart';
import '../../services/haptic_service.dart';

/// Modal bottom sheet or embedded panel allowing multi-dimensional filtering of the Spellbook.
class SpellFilterSheet extends StatelessWidget {
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SpellFilterSheet(
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle and header
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Filter Spellbook',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticService.selectionTick(context);
                onResetAll();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset All'),
            ),
          ],
        ),
        const Divider(height: 20, color: Colors.white12),

        // Quick Feature Toggles (2024 Diffs, Pinned, Ritual, Concentration)
        Text(
          'Quick Filters',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: const Icon(Icons.bookmark, size: 14, color: Colors.purpleAccent),
              label: const Text('My Pinned Spells'),
              selected: showOnlyPinned,
              selectedColor: Colors.purpleAccent.withValues(alpha: 0.25),
              onSelected: (val) {
                HapticService.selectionTick(context);
                onPinnedToggled(val);
              },
            ),
            FilterChip(
              avatar: const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
              label: const Text('2024 Revised Only'),
              selected: showOnlyChangedIn2024,
              selectedColor: Colors.amber.withValues(alpha: 0.25),
              onSelected: (val) {
                HapticService.selectionTick(context);
                onChangedIn2024Toggled(val);
              },
            ),
            FilterChip(
              avatar: const Icon(Icons.psychology_outlined, size: 14, color: Colors.amberAccent),
              label: const Text('Concentration'),
              selected: showOnlyConcentration,
              selectedColor: Colors.amberAccent.withValues(alpha: 0.25),
              onSelected: (val) {
                HapticService.selectionTick(context);
                onConcentrationToggled(val);
              },
            ),
            FilterChip(
              avatar: const Icon(Icons.auto_stories, size: 14, color: Colors.cyanAccent),
              label: const Text('Ritual'),
              selected: showOnlyRitual,
              selectedColor: Colors.cyanAccent.withValues(alpha: 0.25),
              onSelected: (val) {
                HapticService.selectionTick(context);
                onRitualToggled(val);
              },
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Spell Level Filter
        Text(
          'Spell Level',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All Levels'),
              selected: selectedLevel == null,
              onSelected: (selected) {
                if (selected) {
                  HapticService.selectionTick(context);
                  onLevelChanged(null);
                }
              },
            ),
            ChoiceChip(
              label: const Text('Cantrip (0)'),
              selected: selectedLevel == 0,
              onSelected: (selected) {
                HapticService.selectionTick(context);
                onLevelChanged(selected ? 0 : null);
              },
            ),
            ...List.generate(9, (index) {
              final lvl = index + 1;
              return ChoiceChip(
                label: Text('Level $lvl'),
                selected: selectedLevel == lvl,
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  onLevelChanged(selected ? lvl : null);
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
            color: theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All Classes'),
              selected: selectedClass == null,
              onSelected: (selected) {
                if (selected) {
                  HapticService.selectionTick(context);
                  onClassChanged(null);
                }
              },
            ),
            ...SpellClass.values.map(
              (cls) => ChoiceChip(
                avatar: Icon(cls.icon, size: 14),
                label: Text(cls.label),
                selected: selectedClass == cls,
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  onClassChanged(selected ? cls : null);
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
            color: theme.colorScheme.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('All Schools'),
              selected: selectedSchool == null,
              onSelected: (selected) {
                if (selected) {
                  HapticService.selectionTick(context);
                  onSchoolChanged(null);
                }
              },
            ),
            ...SpellSchool.values.map(
              (school) => ChoiceChip(
                avatar: Icon(school.icon, size: 14, color: school.color),
                label: Text(school.label),
                selected: selectedSchool == school,
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  onSchoolChanged(selected ? school : null);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
