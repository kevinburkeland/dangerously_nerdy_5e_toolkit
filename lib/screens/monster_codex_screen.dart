import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/monster_codex_data.dart';
import '../models/srd_summons/minion_stat_block.dart';
import '../providers/settings_provider.dart';
import '../services/a11y_service.dart';
import '../services/haptic_service.dart';
import '../services/rules/spellcasting_rules_engine.dart';
import '../widgets/dialogs/creature_stat_block_dialog.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/glyphs/glyph_tokens.dart';
import '../widgets/monster_codex/monster_card.dart';
import '../widgets/monster_codex/monster_filter_sheet.dart';
import '../widgets/monster_codex/monster_quick_roll_dialog.dart';

enum MonsterCodexViewMode {
  allMonsters('All Monsters', Icons.pets),
  myBestiary('My Bestiary', Icons.bookmark),
  revisions2024('2024 Diffs', Icons.auto_awesome),
  summonCatalog('Summons', Icons.auto_fix_high);

  final String label;
  final IconData icon;

  const MonsterCodexViewMode(this.label, this.icon);
}

class MonsterCodexScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const MonsterCodexScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<MonsterCodexScreen> createState() => _MonsterCodexScreenState();
}

class _MonsterCodexScreenState extends State<MonsterCodexScreen> {
  DmRulesEdition? _localEditionOverride;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  MonsterCodexViewMode _viewMode = MonsterCodexViewMode.allMonsters;

  String? _selectedType;
  String? _selectedSize;
  MonsterCrBand _selectedCrBand = MonsterCrBand.all;
  bool _showOnlyPinned = false;
  bool _showOnlySpellSummons = false;
  bool _showOnlyMagicItems = false;
  bool _showOnlyMultiattack = false;
  bool _showOnlySpellcasters = false;
  bool _showOnlyReactions = false;
  bool _showOnlyResistances = false;
  bool _showOnlyLegendary = false;

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

  DmRulesEdition _resolveEdition(BuildContext context) {
    return _localEditionOverride ??
        SettingsScope.of(context).settings.rulesEdition;
  }

  Set<String> _getPinnedIds(BuildContext context) {
    return SettingsScope.of(context).settings.pinnedMonsterIds;
  }

  void _togglePinMonster(BuildContext context, String monsterId) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).togglePinMonster(monsterId);
  }

  void _clearAllPinnedMonsters(BuildContext context) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).clearPinnedMonsters();
  }

  void _clearAllFilters() {
    HapticService.selectionTick(context);
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedType = null;
      _selectedSize = null;
      _selectedCrBand = MonsterCrBand.all;
      _showOnlyPinned = false;
      _showOnlySpellSummons = false;
      _showOnlyMagicItems = false;
      _showOnlyMultiattack = false;
      _showOnlySpellcasters = false;
      _showOnlyReactions = false;
      _showOnlyResistances = false;
      _showOnlyLegendary = false;
    });
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedType != null) count++;
    if (_selectedSize != null) count++;
    if (_selectedCrBand != MonsterCrBand.all) count++;
    if (_showOnlyPinned) count++;
    if (_showOnlySpellSummons) count++;
    if (_showOnlyMagicItems) count++;
    if (_showOnlyMultiattack) count++;
    if (_showOnlySpellcasters) count++;
    if (_showOnlyReactions) count++;
    if (_showOnlyResistances) count++;
    if (_showOnlyLegendary) count++;
    return count;
  }

  void _openFilterSheet(BuildContext context) {
    MonsterFilterSheet.show(
      context,
      selectedType: _selectedType,
      selectedSize: _selectedSize,
      selectedCrBand: _selectedCrBand,
      showOnlyPinned: _showOnlyPinned,
      showOnlySpellSummons: _showOnlySpellSummons,
      showOnlyMagicItems: _showOnlyMagicItems,
      showOnlyMultiattack: _showOnlyMultiattack,
      showOnlySpellcasters: _showOnlySpellcasters,
      showOnlyReactions: _showOnlyReactions,
      showOnlyResistances: _showOnlyResistances,
      showOnlyLegendary: _showOnlyLegendary,
      onTypeChanged: (type) => setState(() => _selectedType = type),
      onSizeChanged: (size) => setState(() => _selectedSize = size),
      onCrBandChanged: (band) => setState(() => _selectedCrBand = band),
      onPinnedToggled: (val) => setState(() => _showOnlyPinned = val),
      onSpellSummonsToggled: (val) => setState(() => _showOnlySpellSummons = val),
      onMagicItemsToggled: (val) => setState(() => _showOnlyMagicItems = val),
      onMultiattackToggled: (val) => setState(() => _showOnlyMultiattack = val),
      onSpellcastersToggled: (val) => setState(() => _showOnlySpellcasters = val),
      onReactionsToggled: (val) => setState(() => _showOnlyReactions = val),
      onResistancesToggled: (val) => setState(() => _showOnlyResistances = val),
      onLegendaryToggled: (val) => setState(() => _showOnlyLegendary = val),
      onResetAll: _clearAllFilters,
    );
  }

  ({double? minCr, double? maxCr}) _activeCrRange() {
    switch (_selectedCrBand) {
      case MonsterCrBand.all:
        return (minCr: null, maxCr: null);
      case MonsterCrBand.cr0ToQuarter:
        return (minCr: 0, maxCr: 0.25);
      case MonsterCrBand.crHalfToOne:
        return (minCr: 0.5, maxCr: 1);
      case MonsterCrBand.crTwoToFour:
        return (minCr: 2, maxCr: 4);
      case MonsterCrBand.crFiveToEight:
        return (minCr: 5, maxCr: 8);
      case MonsterCrBand.crNinePlus:
        return (minCr: 9, maxCr: null);
    }
  }

  int _getBandCount(MonsterCrBand band) {
    switch (band) {
      case MonsterCrBand.all:
        return MonsterCodexLibrary.allMonsters.length;
      case MonsterCrBand.cr0ToQuarter:
        return MonsterCodexLibrary.getCr0ToQuarterMonsters().length;
      case MonsterCrBand.crHalfToOne:
        return MonsterCodexLibrary.getCrHalfToOneMonsters().length;
      case MonsterCrBand.crTwoToFour:
        return MonsterCodexLibrary.getCrTwoToFourMonsters().length;
      case MonsterCrBand.crFiveToEight:
        return MonsterCodexLibrary.getCrFiveToEightMonsters().length;
      case MonsterCrBand.crNinePlus:
        return MonsterCodexLibrary.getCrNinePlusMonsters().length;
    }
  }

  void _openQuickRollDialog(BuildContext context, MonsterItem monster) {
    MonsterQuickRollDialog.show(
      context,
      monster: monster,
      onRollCompleted: (result, monsterName) {
        final dmgStr = result.damageResult != null
            ? ', Dmg ${result.damageResult!.total} [${result.damageResult!.individualDice.join(", ")}]'
            : '';
        final resultText =
            '$monsterName - ${result.actionName}: Attack ${result.attackTotal} (d20: ${result.d20Roll1}${result.attackBonus >= 0 ? "+" : ""}${result.attackBonus})$dmgStr';
        setState(() {
          _lastQuickRollLabel = resultText;
        });
      },
    );
  }

  void _performQuickRoll(String formula, String label) {
    HapticService.lightImpact(context);
    final result = SpellRollEngine.roll(formula: formula);
    final modStr = result.modifier != 0
        ? (result.modifier > 0
            ? ' + ${result.modifier}'
            : ' - ${result.modifier.abs()}')
        : '';
    final resultText =
        '$label: ${result.total} [${result.individualDice.join(", ")}$modStr]';
    A11yService.announce(resultText);

    setState(() {
      _lastQuickRollLabel = resultText;
    });
  }

  Color _getCrTierColor(double cr, bool isDark) {
    if (cr <= 0.25) return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
    if (cr <= 1.0) return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    if (cr <= 4.0) return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    if (cr <= 8.0) return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  }

  String _getCrCategoryTitle(double cr, String crDisplay) {
    if (cr == 0) return 'Challenge 0 (Critters & NPCs)';
    if (cr == 0.125) return 'Challenge 1/8 (Minions)';
    if (cr == 0.25) return 'Challenge 1/4 (Skirmishers)';
    if (cr == 0.5) return 'Challenge 1/2 (Raiders)';
    if (cr == 1) return 'Challenge 1 (Warriors & Beasts)';
    if (cr == 2) return 'Challenge 2 (Tough Foes)';
    if (cr == 3) return 'Challenge 3 (Dangerous Foes)';
    if (cr == 4) return 'Challenge 4 (Formidable Foes)';
    if (cr == 5) return 'Challenge 5 (Deadly Threats)';
    if (cr >= 6 && cr <= 8) return 'Challenge ${cr.toInt()} (Elite Threats)';
    if (cr >= 9 && cr <= 16) return 'Challenge ${cr.toInt()} (Epic Bosses)';
    if (cr >= 17) return 'Challenge ${cr.toInt()} (Legendary & Mythic)';
    return 'Challenge $crDisplay';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeEdition = _resolveEdition(context);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final pinnedIds = _getPinnedIds(context);
    final allMonsters = MonsterCodexLibrary.allMonsters;
    final bandCounts = {
      for (final band in MonsterCrBand.values) band: _getBandCount(band),
    };
    final crRange = _activeCrRange();

    final filteredMonsters = allMonsters.where((monster) {
      final statBlock = monster.getStatBlock(activeEdition);

      if (_viewMode == MonsterCodexViewMode.myBestiary &&
          !pinnedIds.contains(monster.id)) {
        return false;
      }
      if (_viewMode == MonsterCodexViewMode.revisions2024 &&
          !monster.isChangedIn2024) {
        return false;
      }
      if (_viewMode == MonsterCodexViewMode.summonCatalog &&
          monster.sourceCategory != SummonCategory.spell) {
        return false;
      }
      if (_showOnlyPinned && !pinnedIds.contains(monster.id)) {
        return false;
      }
      if (_showOnlySpellSummons &&
          monster.sourceCategory != SummonCategory.spell) {
        return false;
      }
      if (_showOnlyMagicItems &&
          monster.sourceCategory != SummonCategory.magicItem) {
        return false;
      }
      if (_showOnlyMultiattack &&
          !statBlock.actions.any((a) => a.name.toLowerCase().contains('multiattack'))) {
        return false;
      }
      if (_showOnlySpellcasters &&
          !statBlock.traits.any((t) => t.name.toLowerCase().contains('spellcasting'))) {
        return false;
      }
      if (_showOnlyReactions && statBlock.reactions.isEmpty) {
        return false;
      }
      if (_showOnlyResistances &&
          (statBlock.damageResistances == null || statBlock.damageResistances!.isEmpty) &&
          (statBlock.damageImmunities == null || statBlock.damageImmunities!.isEmpty)) {
        return false;
      }
      if (_showOnlyLegendary && !statBlock.hasLegendary) {
        return false;
      }

      return monster.matches(
        _searchQuery,
        typeFilter: _selectedType,
        sizeFilter: _selectedSize,
        minCr: crRange.minCr,
        maxCr: crRange.maxCr,
        edition: activeEdition,
      );
    }).toList();

    final pinnedMonstersInResults =
        filteredMonsters.where((m) => pinnedIds.contains(m.id)).toList();
    final otherMonstersInResults =
        filteredMonsters.where((m) => !pinnedIds.contains(m.id)).toList();

    final activeFilterCount = _getActiveFilterCount();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.pets,
              color: isDark ? const Color(0xFF38BDF8) : theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              'Monster Codex',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          RulesEditionToggle(
            currentEdition: activeEdition,
            onEditionChanged: (newEdition) {
              setState(() {
                _localEditionOverride = newEdition;
              });
            },
          ),
          if (_viewMode == MonsterCodexViewMode.myBestiary &&
              pinnedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmark_remove_outlined),
              tooltip: 'Clear Personal Bestiary',
              onPressed: () => _clearAllPinnedMonsters(context),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'About Monster Codex',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.pets),
                      SizedBox(width: 8),
                      Text('Monster Codex'),
                    ],
                  ),
                  content: const Text(
                    'Browse, filter, and inspect creatures from the 5e SRD bestiary and summon catalogs.\n\n'
                    '• Switch between 2014 and 2024 rules editions.\n'
                    '• Bookmark creatures to your Personal Bestiary with the bookmark icon.\n'
                    '• Use the Dice button for fast attack & damage quick rolls.\n'
                    '• Tap any card to open the complete, full stat block dialog.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Sheet Trigger Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search monsters, CR, traits, actions...',
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: 'Filter Bestiary',
                        onPressed: () => _openFilterSheet(context),
                      ),
                      if (activeFilterCount > 0)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$activeFilterCount',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Segmented View Selector: All Monsters / My Bestiary / 2024 Diffs / Summons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SegmentedButton<MonsterCodexViewMode>(
                segments: MonsterCodexViewMode.values.map((mode) {
                  return ButtonSegment<MonsterCodexViewMode>(
                    value: mode,
                    label: Text(mode.label, style: const TextStyle(fontSize: 11)),
                    icon: Icon(mode.icon, size: 15),
                  );
                }).toList(),
                selected: {_viewMode},
                onSelectionChanged: (newSelection) {
                  HapticService.selectionTick(context);
                  setState(() {
                    _viewMode = newSelection.first;
                  });
                },
              ),
            ),

            // Creature Type Horizontal Filter Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('All Types',
                          style: TextStyle(fontSize: 11)),
                      selected: _selectedType == null,
                      onSelected: (selected) {
                        if (selected) {
                          HapticService.selectionTick(context);
                          setState(() => _selectedType = null);
                        }
                      },
                    ),
                  ),
                  ...CreatureType.values.map((type) {
                    final typeColor = type.getLegibleColor(isDark);
                    final isSelected =
                        _selectedType?.toLowerCase() == type.displayName.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(type.displayName,
                            style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: typeColor.withValues(alpha: 0.25),
                        onSelected: (selected) {
                          HapticService.selectionTick(context);
                          setState(() {
                            _selectedType = selected ? type.displayName : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Challenge Rating (CR) Band Quick Filter Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  for (final band in MonsterCrBand.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${band.label} (${bandCounts[band]})',
                            style: const TextStyle(fontSize: 11)),
                        selected: _selectedCrBand == band,
                        onSelected: (bandCounts[band] ?? 0) == 0 &&
                                band != MonsterCrBand.all
                            ? null
                            : (selected) {
                                if (selected) {
                                  HapticService.selectionTick(context);
                                  setState(() => _selectedCrBand = band);
                                }
                              },
                      ),
                    ),
                ],
              ),
            ),

            // Roll Result Banner
            if (_lastQuickRollLabel != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: pinColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pinColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.casino, color: pinColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastQuickRollLabel!,
                        style: TextStyle(
                          color: pinColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16, color: pinColor),
                      onPressed: () =>
                          setState(() => _lastQuickRollLabel = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            // Results count and attribution header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  Text(
                    '${filteredMonsters.length} entries',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${activeEdition.label} SRD bestiary',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            // Content List / Grouped Slivers
            Expanded(
              child: filteredMonsters.isEmpty
                  ? _buildEmptyState(
                      theme,
                      pinnedIds.isEmpty &&
                          _viewMode == MonsterCodexViewMode.myBestiary,
                    )
                  : CustomScrollView(
                      slivers: [
                        // Personal Bestiary Pinned Section in All Monsters view
                        if (_viewMode == MonsterCodexViewMode.allMonsters &&
                            pinnedMonstersInResults.isNotEmpty) ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  Icon(Icons.bookmark,
                                      color: pinColor, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Personal Bestiary (${pinnedMonstersInResults.length})',
                                    style: TextStyle(
                                      color: pinColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _buildSliverMonsterCards(
                            context,
                            pinnedMonstersInResults,
                            activeEdition,
                            pinnedIds,
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            sliver: SliverToBoxAdapter(
                              child: Divider(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                        ],
                        if (_viewMode == MonsterCodexViewMode.allMonsters &&
                            pinnedMonstersInResults.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Other Bestiary Creatures (${otherMonstersInResults.length})',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        if (_viewMode == MonsterCodexViewMode.allMonsters &&
                            pinnedMonstersInResults.isNotEmpty)
                          ..._buildGroupedCrSlivers(
                            context,
                            otherMonstersInResults,
                            activeEdition,
                            pinnedIds,
                          )
                        else
                          ..._buildGroupedCrSlivers(
                            context,
                            filteredMonsters,
                            activeEdition,
                            pinnedIds,
                          ),
                        const SliverPadding(
                            padding: EdgeInsets.only(bottom: 24)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedCrSlivers(
    BuildContext context,
    List<MonsterItem> monsters,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slivers = <Widget>[];

    // Group monsters by distinct challenge rating
    final crGroups = <double, List<MonsterItem>>{};
    for (final monster in monsters) {
      final cr = monster.challengeRating;
      crGroups.putIfAbsent(cr, () => []).add(monster);
    }

    final sortedCrs = crGroups.keys.toList()..sort();

    for (int i = 0; i < sortedCrs.length; i++) {
      final cr = sortedCrs[i];
      final crMonsters = crGroups[cr]!;
      final crDisplay = crMonsters.first.crDisplay;
      final tierColor = _getCrTierColor(cr, isDark);

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, i == 0 ? 8 : 20, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    crDisplay.toUpperCase(),
                    style: TextStyle(
                      color: tierColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getCrCategoryTitle(cr, crDisplay),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${crMonsters.length} ${crMonsters.length == 1 ? 'Monster' : 'Monsters'}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      slivers.add(
          _buildSliverMonsterCards(context, crMonsters, edition, pinnedIds));
    }

    return slivers;
  }

  Widget _buildSliverMonsterCards(
    BuildContext context,
    List<MonsterItem> monsters,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1000 ? 3 : (width > 650 ? 2 : 1);
    final rowCount = (monsters.length / crossAxisCount).ceil();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: rowCount,
        itemBuilder: (context, rowIndex) {
          final startIndex = rowIndex * crossAxisCount;
          final rowMonsters =
              monsters.skip(startIndex).take(crossAxisCount).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < crossAxisCount; c++) ...[
                  if (c > 0) const SizedBox(width: 14),
                  Expanded(
                    child: c < rowMonsters.length
                        ? RepaintBoundary(
                            child: MonsterCard(
                              monster: rowMonsters[c],
                              edition: edition,
                              isPinned: pinnedIds.contains(rowMonsters[c].id),
                              onTogglePin: () =>
                                  _togglePinMonster(context, rowMonsters[c].id),
                              onTap: () {
                                CreatureStatBlockDialog.show(
                                  context,
                                  statBlock: rowMonsters[c].getStatBlock(edition),
                                );
                              },
                              onQuickRoll: _performQuickRoll,
                              onOpenQuickRoll: () =>
                                  _openQuickRollDialog(context, rowMonsters[c]),
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

  Widget _buildEmptyState(ThemeData theme, bool isPersonalBestiaryEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPersonalBestiaryEmpty
                  ? Icons.bookmark_border
                  : Icons.search_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              isPersonalBestiaryEmpty
                  ? 'Your Personal Bestiary is Empty'
                  : 'No Monsters Found',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPersonalBestiaryEmpty
                  ? 'Tap the bookmark icon on any monster card to pin favorite creatures here for quick DM access.'
                  : 'Try adjusting your search query, CR band, or creature type filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            if (!isPersonalBestiaryEmpty) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset All Filters'),
                onPressed: _clearAllFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
