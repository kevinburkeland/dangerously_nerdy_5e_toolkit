import 'package:flutter/material.dart';
import '../models/magic_items/magic_item_library.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/common/compendium_search_header.dart';
import '../widgets/common/empty_state_card.dart';
import '../widgets/common/responsive_card_grid.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/item_compendium/item_card.dart';
import '../widgets/item_compendium/item_comparison_dialog.dart';
import '../widgets/item_compendium/item_detail_dialog.dart';
import '../widgets/item_compendium/item_filter_sheet.dart';
import '../widgets/room_banner_widget.dart';

enum ItemCompendiumViewMode {
  allItems('All Items', Icons.auto_fix_high),
  myReliquary('Personal Reliquary', Icons.bookmark),
  revisions2024('2024 Diffs', Icons.auto_awesome);

  final String label;
  final IconData icon;

  const ItemCompendiumViewMode(this.label, this.icon);
}

/// Standalone Magic Item Compendium — searchable, filterable browser of SRD 5.1 & 5.2
/// magic items with full glyph visuals, 2014/2024 rules comparison, persistent bookmarks, and action trait rings.
class ItemCompendiumScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ItemCompendiumScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<ItemCompendiumScreen> createState() => _ItemCompendiumScreenState();
}

class _ItemCompendiumScreenState extends State<ItemCompendiumScreen> {
  DmRulesEdition? _localEditionOverride;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  ItemCompendiumViewMode _viewMode = ItemCompendiumViewMode.allItems;

  // Filter state
  ItemCategory? _selectedCategory;
  ItemRarity? _selectedRarity;
  bool _showOnlyAttunement = false;
  bool _showOnlyPinned = false;
  bool _showOnlyChangedIn2024 = false;
  DamageAccent? _selectedDamageAccent;

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  void didUpdateWidget(covariant ItemCompendiumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEdition != oldWidget.initialEdition) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Set<String> _getPinnedIds(BuildContext context) {
    return SettingsScope.of(context).settings.pinnedItemIds;
  }

  void _togglePinItem(BuildContext context, String itemId) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).togglePinItem(itemId);
  }

  void _clearAllPinnedItems(BuildContext context) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).clearPinnedItems();
  }

  void _clearAllFilters() {
    HapticService.selectionTick(context);
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _selectedRarity = null;
      _showOnlyAttunement = false;
      _showOnlyPinned = false;
      _showOnlyChangedIn2024 = false;
      _selectedDamageAccent = null;
    });
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedRarity != null) count++;
    if (_showOnlyAttunement) count++;
    if (_showOnlyPinned) count++;
    if (_showOnlyChangedIn2024) count++;
    if (_selectedDamageAccent != null) count++;
    return count;
  }

  void _openFilterSheet(BuildContext context) {
    ItemFilterSheet.show(
      context,
      selectedCategory: _selectedCategory,
      selectedRarity: _selectedRarity,
      showOnlyAttunement: _showOnlyAttunement,
      showOnlyPinned: _showOnlyPinned,
      showOnlyChangedIn2024: _showOnlyChangedIn2024,
      selectedDamageAccent: _selectedDamageAccent,
      onCategoryChanged: (cat) => setState(() => _selectedCategory = cat),
      onRarityChanged: (rarity) => setState(() => _selectedRarity = rarity),
      onAttunementToggled: (val) => setState(() => _showOnlyAttunement = val),
      onPinnedToggled: (val) => setState(() => _showOnlyPinned = val),
      onChangedIn2024Toggled: (val) => setState(() => _showOnlyChangedIn2024 = val),
      onDamageAccentChanged: (dmg) => setState(() => _selectedDamageAccent = dmg),
      onResetAll: _clearAllFilters,
    );
  }

  void _showItemDetails(MagicItem item, DmRulesEdition edition, bool isPinned) {
    HapticService.lightImpact(context);
    ItemDetailDialog.show(
      context,
      item: item,
      edition: edition,
      isPinned: isPinned,
      onTogglePin: () => _togglePinItem(context, item.id),
    );
  }

  void _showItemComparison(MagicItem item, DmRulesEdition edition, bool isPinned) {
    ItemComparisonDialog.show(
      context,
      item: item,
      edition: edition,
      isPinned: isPinned,
      onTogglePin: () => _togglePinItem(context, item.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsProvider = SettingsScope.maybeOf(context);
    final activeEdition = widget.initialEdition != null
        ? (_localEditionOverride ?? widget.initialEdition!)
        : (settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final pinnedIds = _getPinnedIds(context);
    final allItems = MagicItemLibrary.allItems;
    final diffCount = allItems.where((i) => i.isChangedIn2024).length;
    final activeFilterCount = _getActiveFilterCount();

    // Filter items based on search, view mode, and sheet filters
    final filteredItems = allItems.where((item) {
      if (_viewMode == ItemCompendiumViewMode.myReliquary &&
          !pinnedIds.contains(item.id)) {
        return false;
      }
      if (_viewMode == ItemCompendiumViewMode.revisions2024 &&
          !item.isChangedIn2024) {
        return false;
      }
      if (_showOnlyPinned && !pinnedIds.contains(item.id)) {
        return false;
      }
      return item.matches(
        _searchQuery,
        categoryFilter: _selectedCategory,
        rarityFilter: _selectedRarity,
        attunementOnly: _showOnlyAttunement,
        changedOnly: _showOnlyChangedIn2024,
        damageAccentFilter: _selectedDamageAccent,
        edition: activeEdition,
      );
    }).toList();

    // Grouping for "All Items" view mode
    final pinnedItemsInResults =
        filteredItems.where((item) => pinnedIds.contains(item.id)).toList();
    final otherItemsInResults =
        filteredItems.where((item) => !pinnedIds.contains(item.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_fix_high, color: pinColor, size: 24),
            const SizedBox(width: 10),
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  'Item Codex',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          RulesEditionToggle(
            currentEdition: activeEdition,
            onEditionChanged: (newEdition) {
              if (widget.initialEdition != null) {
                setState(() {
                  _localEditionOverride = newEdition;
                });
              }
              settingsProvider?.setRulesEdition(newEdition);
            },
          ),
          if (_viewMode == ItemCompendiumViewMode.myReliquary &&
              pinnedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmark_remove_outlined),
              tooltip: 'Clear Personal Reliquary',
              onPressed: () => _clearAllPinnedItems(context),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'About Item Codex',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.auto_fix_high),
                      SizedBox(width: 8),
                      Text('Item Codex'),
                    ],
                  ),
                  content: const Text(
                    'Browse, filter, and inspect magic items, gemstones, art objects, trinkets, and adventuring gear from the 5e SRD.\n\n'
                    '• Switch between 2014 RAW and 2024 Revised rules editions.\n'
                    '• Check the 2024 Diffs tab to compare side-by-side rule changes.\n'
                    '• Bookmark items to your Personal Reliquary with the bookmark icon.\n'
                    '• Inspect action trait rings and attunement requirements.\n'
                    '• Tap any card to open complete details; tap 2024 Diff badges to compare editions.',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: RoomBannerWidget(compact: true),
            ),
            CompendiumSearchHeader(
              controller: _searchController,
              searchQuery: _searchQuery,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              hintText: 'Search items, loot, gems, art, rarity, element...',
              activeFilterCount: activeFilterCount,
              filterTooltip: 'Filter Items & Loot',
              onFilterTap: () => _openFilterSheet(context),
            ),

            // View Mode Segments (All Items / Personal Reliquary / 2024 Diffs)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  SegmentedButton<ItemCompendiumViewMode>(
                    segments: [
                      ButtonSegment(
                        value: ItemCompendiumViewMode.allItems,
                        label: Text('All Items (${allItems.length})',
                            style: const TextStyle(fontSize: 12)),
                        icon: const Icon(Icons.auto_fix_high, size: 15),
                      ),
                      ButtonSegment(
                        value: ItemCompendiumViewMode.myReliquary,
                        label: Text('Personal Reliquary (${pinnedIds.length})',
                            style: const TextStyle(fontSize: 12)),
                        icon: const Icon(Icons.bookmark, size: 15),
                      ),
                      ButtonSegment(
                        value: ItemCompendiumViewMode.revisions2024,
                        label: Text('2024 Diffs ($diffCount)',
                            style: const TextStyle(fontSize: 12)),
                        icon: const Icon(Icons.auto_awesome, size: 15),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (val) {
                      HapticService.selectionTick(context);
                      setState(() => _viewMode = val.first);
                    },
                  ),
                ],
              ),
            ),

            // Item Category Horizontal Filter Row
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
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        if (selected) {
                          HapticService.selectionTick(context);
                          setState(() => _selectedCategory = null);
                        }
                      },
                    ),
                  ),
                  ...ItemCategory.values.map((cat) {
                    final catColor = cat.getLegibleColor(isDark);
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        label: Text(
                          cat.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? null : catColor,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          HapticService.selectionTick(context);
                          setState(
                              () => _selectedCategory = selected ? cat : null);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Results count and attribution header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  Text(
                    '${filteredItems.length} entries',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${activeEdition.label} SRD magic items',
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
              child: filteredItems.isEmpty
                  ? _buildEmptyState(
                      theme,
                      pinnedIds.isEmpty &&
                          _viewMode == ItemCompendiumViewMode.myReliquary,
                    )
                  : CustomScrollView(
                      slivers: [
                        // Personal Reliquary Pinned Section in All Items view
                        if (_viewMode == ItemCompendiumViewMode.allItems &&
                            pinnedItemsInResults.isNotEmpty) ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                            sliver: SliverToBoxAdapter(
                              child: Row(
                                children: [
                                  Icon(Icons.bookmark,
                                      color: pinColor, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Personal Reliquary (${pinnedItemsInResults.length})',
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
                          _buildSliverItemCards(
                            context,
                            pinnedItemsInResults,
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
                        if (_viewMode == ItemCompendiumViewMode.allItems &&
                            pinnedItemsInResults.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Other Magic Items (${otherItemsInResults.length})',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        if (_viewMode == ItemCompendiumViewMode.allItems &&
                            pinnedItemsInResults.isNotEmpty)
                          ..._buildGroupedCategorySlivers(
                            context,
                            otherItemsInResults,
                            activeEdition,
                            pinnedIds,
                          )
                        else
                          ..._buildGroupedCategorySlivers(
                            context,
                            filteredItems,
                            activeEdition,
                            pinnedIds,
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

  List<Widget> _buildGroupedCategorySlivers(
    BuildContext context,
    List<MagicItem> items,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final slivers = <Widget>[];

    // Group items by category in predefined canonical order
    final groupedByCategory = <ItemCategory, List<MagicItem>>{};
    for (final cat in ItemCategory.values) {
      final inCat = items.where((i) => i.category == cat).toList();
      if (inCat.isNotEmpty) {
        groupedByCategory[cat] = inCat;
      }
    }

    int catIndex = 0;
    for (final entry in groupedByCategory.entries) {
      final category = entry.key;
      final categoryItems = entry.value;
      final catColor = category.getLegibleColor(isDark);

      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, catIndex == 0 ? 8 : 20, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: catColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    category.displayName.toUpperCase(),
                    style: TextStyle(
                      color: catColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category.displayName,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${categoryItems.length} ${categoryItems.length == 1 ? 'Item' : 'Items'}',
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
        _buildSliverItemCards(
          context,
          categoryItems,
          edition,
          pinnedIds,
        ),
      );
      catIndex++;
    }

    return slivers;
  }

  Widget _buildSliverItemCards(
    BuildContext context,
    List<MagicItem> items,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    return SliverResponsiveCardGrid<MagicItem>(
      items: items,
      itemBuilder: (context, item) => ItemCard(
        item: item,
        edition: edition,
        isPinned: pinnedIds.contains(item.id),
        onTogglePin: () => _togglePinItem(context, item.id),
        onTap: () => _showItemDetails(
            item, edition, pinnedIds.contains(item.id)),
        onCompare: () => _showItemComparison(
            item, edition, pinnedIds.contains(item.id)),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isReliquaryEmpty) {
    return EmptyStateCard(
      icon: isReliquaryEmpty ? Icons.bookmark_border : Icons.search_off,
      title: isReliquaryEmpty
          ? 'Your Personal Reliquary is empty'
          : 'No magic items match your filters',
      message: isReliquaryEmpty
          ? 'Tap the bookmark icon on any magic item card to save it to your personal reliquary.'
          : 'Try clearing your search query or adjusting your filters.',
      actionLabel: isReliquaryEmpty
          ? 'Browse All Magic Items'
          : 'Reset All Filters',
      actionIcon: isReliquaryEmpty ? Icons.auto_fix_high : Icons.refresh,
      onAction: () {
        HapticService.selectionTick(context);
        if (isReliquaryEmpty) {
          setState(() => _viewMode = ItemCompendiumViewMode.allItems);
        } else {
          _clearAllFilters();
        }
      },
    );
  }
}
