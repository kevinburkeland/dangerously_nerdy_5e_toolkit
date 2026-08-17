import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/spellbook_data.dart';
import '../providers/settings_provider.dart';
import '../services/a11y_service.dart';
import '../services/haptic_service.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/spellbook/spell_card.dart';
import '../widgets/spellbook/spell_comparison_dialog.dart';
import '../widgets/spellbook/spell_filter_sheet.dart';
import '../widgets/spellbook/spell_quick_roll_dialog.dart';

enum SpellbookViewMode {
  allSpells('All Spells', Icons.menu_book),
  mySpellbook('Personal Spellbook', Icons.bookmark),
  revisions2024('2024 Revisions', Icons.auto_awesome);

  final String label;
  final IconData icon;

  const SpellbookViewMode(this.label, this.icon);
}

class SpellbookScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const SpellbookScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<SpellbookScreen> createState() => _SpellbookScreenState();
}

class _SpellbookScreenState extends State<SpellbookScreen> {
  DmRulesEdition? _localEditionOverride;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  SpellbookViewMode _viewMode = SpellbookViewMode.allSpells;

  int? _selectedLevel;
  SpellSchool? _selectedSchool;
  SpellClass? _selectedClass;
  bool _showOnlyChangedIn2024 = false;
  bool _showOnlyPinned = false;
  bool _showOnlyRitual = false;
  bool _showOnlyConcentration = false;

  String? _lastQuickRollLabel;

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> _getPinnedIds(BuildContext context) {
    return SettingsScope.of(context).settings.pinnedSpellIds;
  }

  void _togglePinSpell(BuildContext context, String spellId) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).togglePinSpell(spellId);
  }

  void _clearAllPinnedSpells(BuildContext context) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).clearPinnedSpells();
  }

  void _onEditionChanged(BuildContext context, DmRulesEdition newEdition) {
    final settingsProvider = SettingsScope.of(context);
    final current = _localEditionOverride ?? settingsProvider.settings.rulesEdition;
    if (current == newEdition) return;
    HapticService.selectionTick(context);
    setState(() {
      _localEditionOverride = newEdition;
    });
    settingsProvider.setRulesEdition(newEdition);
  }

  void _openFilterSheet(BuildContext context) {
    SpellFilterSheet.show(
      context,
      selectedLevel: _selectedLevel,
      selectedSchool: _selectedSchool,
      selectedClass: _selectedClass,
      showOnlyChangedIn2024: _showOnlyChangedIn2024,
      showOnlyPinned: _showOnlyPinned,
      showOnlyRitual: _showOnlyRitual,
      showOnlyConcentration: _showOnlyConcentration,
      onLevelChanged: (lvl) => setState(() => _selectedLevel = lvl),
      onSchoolChanged: (sch) => setState(() => _selectedSchool = sch),
      onClassChanged: (cls) => setState(() => _selectedClass = cls),
      onChangedIn2024Toggled: (val) => setState(() => _showOnlyChangedIn2024 = val),
      onPinnedToggled: (val) => setState(() => _showOnlyPinned = val),
      onRitualToggled: (val) => setState(() => _showOnlyRitual = val),
      onConcentrationToggled: (val) => setState(() => _showOnlyConcentration = val),
      onResetAll: () {
        setState(() {
          _selectedLevel = null;
          _selectedSchool = null;
          _selectedClass = null;
          _showOnlyChangedIn2024 = false;
          _showOnlyPinned = false;
          _showOnlyRitual = false;
          _showOnlyConcentration = false;
        });
      },
    );
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedLevel != null) count++;
    if (_selectedSchool != null) count++;
    if (_selectedClass != null) count++;
    if (_showOnlyChangedIn2024) count++;
    if (_showOnlyPinned) count++;
    if (_showOnlyRitual) count++;
    if (_showOnlyConcentration) count++;
    return count;
  }

  void _showCompareDialog(BuildContext context, SpellItem spell) {
    SpellComparisonDialog.show(
      context,
      spell: spell,
      isPinned: _getPinnedIds(context).contains(spell.id),
      onTogglePin: () => _togglePinSpell(context, spell.id),
    );
  }

  void _openQuickRollDialog(BuildContext context, SpellItem spell, DmRulesEdition edition) {
    SpellQuickRollDialog.show(
      context,
      spell: spell,
      edition: edition,
      onRollCompleted: (result, spellName, castLevel) {
        final levelLabel = spell.level == 0 ? 'Cantrip' : 'Level $castLevel';
        final modStr = result.modifier != 0 ? (result.modifier > 0 ? ' + ${result.modifier}' : ' - ${result.modifier.abs()}') : '';
        final resultText = '$spellName ($levelLabel): ${result.total} [${result.individualDice.join(", ")}$modStr]';
        setState(() {
          _lastQuickRollLabel = resultText;
        });
      },
    );
  }

  void _performSpellRoll(String formula, String spellName) {
    HapticService.lightImpact(context);
    final result = SpellRollEngine.roll(formula: formula);
    final modStr = result.modifier != 0 ? (result.modifier > 0 ? ' + ${result.modifier}' : ' - ${result.modifier.abs()}') : '';
    final resultText = '$spellName (${result.formulaDescription}): ${result.total} [${result.individualDice.join(", ")}$modStr]';
    A11yService.announce(resultText);

    setState(() {
      _lastQuickRollLabel = resultText;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final pinnedIds = _getPinnedIds(context);
    const allSpells = SpellbookLibrary.allSpells;

    // Filter spells based on search, view mode, and sheet filters
    final filteredSpells = allSpells.where((spell) {
      if (_viewMode == SpellbookViewMode.mySpellbook && !pinnedIds.contains(spell.id)) {
        return false;
      }
      if (_viewMode == SpellbookViewMode.revisions2024 && !spell.isChangedIn2024) {
        return false;
      }
      if (_showOnlyPinned && !pinnedIds.contains(spell.id)) {
        return false;
      }
      return spell.matches(
        _searchQuery,
        schoolFilter: _selectedSchool,
        levelFilter: _selectedLevel,
        classFilter: _selectedClass,
        changedOnly: _showOnlyChangedIn2024,
        ritualOnly: _showOnlyRitual,
        concentrationOnly: _showOnlyConcentration,
        edition: edition,
      );
    }).toList();

    // Grouping for "All Spells" view mode
    final pinnedSpellsInResults = filteredSpells.where((s) => pinnedIds.contains(s.id)).toList();
    final otherSpellsInResults = filteredSpells.where((s) => !pinnedIds.contains(s.id)).toList();

    final activeFilterCount = _getActiveFilterCount();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, color: Colors.purpleAccent, size: 24),
            const SizedBox(width: 10),
            Flexible(
              child: Semantics(
                header: true,
                child: const Text(
                  'Spellbook Companion',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          RulesEditionToggle(
            currentEdition: edition,
            onEditionChanged: (newEdition) => _onEditionChanged(context, newEdition),
          ),
          const SizedBox(width: 8),
          if (pinnedIds.isNotEmpty && _viewMode == SpellbookViewMode.mySpellbook)
            IconButton(
              icon: const Icon(Icons.bookmark_remove_outlined),
              tooltip: 'Clear Personal Spellbook',
              onPressed: () => _clearAllPinnedSpells(context),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search spells, damage, components, classes...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Stack(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.tune),
                        tooltip: 'Filter Spells',
                        onPressed: () => _openFilterSheet(context),
                      ),
                      if (activeFilterCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.purpleAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$activeFilterCount',
                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // View Mode Segments (All Spells / Personal Spellbook / 2024 Revisions)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SegmentedButton<SpellbookViewMode>(
                    segments: [
                      ButtonSegment(
                        value: SpellbookViewMode.allSpells,
                        label: Text('All Spells (${allSpells.length})'),
                        icon: const Icon(Icons.menu_book, size: 16),
                      ),
                      ButtonSegment(
                        value: SpellbookViewMode.mySpellbook,
                        label: Text('My Spellbook (${pinnedIds.length})'),
                        icon: const Icon(Icons.bookmark, size: 16),
                      ),
                      ButtonSegment(
                        value: SpellbookViewMode.revisions2024,
                        label: Text('2024 Diffs (${SpellbookLibrary.getChangedSpells().length})'),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (newSelection) {
                      HapticService.selectionTick(context);
                      setState(() {
                        _viewMode = newSelection.first;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Class Spell List Quick Filters
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  FilterChip(
                    selected: _selectedClass == null,
                    label: const Text('All Classes'),
                    onSelected: (_) {
                      setState(() => _selectedClass = null);
                    },
                  ),
                  const SizedBox(width: 6),
                  ...SpellClass.values.map((cls) {
                    final isSelected = _selectedClass == cls;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        selected: isSelected,
                        avatar: Icon(cls.icon, size: 14),
                        label: Text(cls.label),
                        onSelected: (selected) {
                          setState(() {
                            _selectedClass = selected ? cls : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Roll Result Banner
            if (_lastQuickRollLabel != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.casino, color: Colors.purpleAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastQuickRollLabel!,
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.purpleAccent),
                      onPressed: () => setState(() => _lastQuickRollLabel = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 6),

            // Content List
            Expanded(
              child: filteredSpells.isEmpty
                  ? _buildEmptyState(theme, pinnedIds.isEmpty && _viewMode == SpellbookViewMode.mySpellbook)
                  : CustomScrollView(
                      slivers: [
                        if (_viewMode == SpellbookViewMode.allSpells && pinnedSpellsInResults.isNotEmpty) ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  const Icon(Icons.bookmark, color: Colors.purpleAccent, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Personal Spellbook (${pinnedSpellsInResults.length})',
                                    style: const TextStyle(
                                      color: Colors.purpleAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _buildSliverSpellCards(context, pinnedSpellsInResults, edition, pinnedIds),
                          const SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            sliver: SliverToBoxAdapter(
                              child: Divider(color: Colors.white12),
                            ),
                          ),
                        ],

                        if (_viewMode == SpellbookViewMode.allSpells && pinnedSpellsInResults.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Other SRD Spells (${otherSpellsInResults.length})',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),

                        // Level-by-Level Separated Spell Display
                        ..._buildSliverLevelSeparatedCards(
                          context,
                          (_viewMode == SpellbookViewMode.allSpells && pinnedSpellsInResults.isNotEmpty)
                              ? otherSpellsInResults
                              : filteredSpells,
                          edition,
                          pinnedIds,
                          theme,
                        ),

                        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSliverLevelSeparatedCards(
    BuildContext context,
    List<SpellItem> spells,
    DmRulesEdition edition,
    Set<String> pinnedIds,
    ThemeData theme,
  ) {
    // Group spells by level
    final Map<int, List<SpellItem>> levelGroups = {};
    for (final s in spells) {
      levelGroups.putIfAbsent(s.level, () => []).add(s);
    }
    final sortedLevels = levelGroups.keys.toList()..sort();

    final slivers = <Widget>[];

    for (int i = 0; i < sortedLevels.length; i++) {
      final level = sortedLevels[i];
      final levelSpells = levelGroups[level]!;

      final levelTitle = level == 0
          ? 'Cantrips (0-Level)'
          : (level == 1
              ? '1st-Level Spells'
              : (level == 2
                  ? '2nd-Level Spells'
                  : (level == 3
                      ? '3rd-Level Spells'
                      : '${level}th-Level Spells')));

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 8 : 20, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    level == 0 ? 'CANTRIP' : 'LEVEL $level',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  levelTitle,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${levelSpells.length} ${levelSpells.length == 1 ? 'Spell' : 'Spells'}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(_buildSliverSpellCards(context, levelSpells, edition, pinnedIds));
    }

    return slivers;
  }

  Widget _buildEmptyState(ThemeData theme, bool isSpellbookEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSpellbookEmpty ? Icons.bookmark_border : Icons.search_off,
              size: 54,
              color: Colors.white24,
            ),
            const SizedBox(height: 14),
            Text(
              isSpellbookEmpty ? 'Your Personal Spellbook is Empty' : 'No Spells Found',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSpellbookEmpty
                  ? 'Browse the Spellbook Companion and tap the bookmark icon on any spell to pin it to your personal spellbook.'
                  : 'Try adjusting your search terms or clearing active filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            if (!isSpellbookEmpty) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedLevel = null;
                    _selectedSchool = null;
                    _selectedClass = null;
                    _showOnlyChangedIn2024 = false;
                    _showOnlyPinned = false;
                    _showOnlyRitual = false;
                    _showOnlyConcentration = false;
                  });
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Clear All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSliverSpellCards(
    BuildContext context,
    List<SpellItem> spells,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1000 ? 3 : (width > 650 ? 2 : 1);
    final rowCount = (spells.length / crossAxisCount).ceil();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: rowCount,
        itemBuilder: (context, rowIndex) {
          final startIndex = rowIndex * crossAxisCount;
          final rowSpells = spells.skip(startIndex).take(crossAxisCount).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < crossAxisCount; c++) ...[
                  if (c > 0) const SizedBox(width: 14),
                  Expanded(
                    child: c < rowSpells.length
                        ? RepaintBoundary(
                            child: SpellCard(
                              spell: rowSpells[c],
                              edition: edition,
                              isPinned: pinnedIds.contains(rowSpells[c].id),
                              onTogglePin: () => _togglePinSpell(context, rowSpells[c].id),
                              onTap: () => _showCompareDialog(context, rowSpells[c]),
                              onOpenQuickRoll: () => _openQuickRollDialog(context, rowSpells[c], edition),
                              onQuickRoll: _performSpellRoll,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
