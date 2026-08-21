import 'package:flutter/material.dart';
import '../models/magic_items/magic_item_library.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
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
    final activeEdition = _localEditionOverride ??
        settingsProvider?.settings.rulesEdition ??
        DmRulesEdition.v2024;
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final pinnedIds = _getPinnedIds(context);
    const allItems = MagicItemLibrary.allItems;
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
                  'Magic Item Compendium',
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
              setState(() {
                _localEditionOverride = newEdition;
              });
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
            tooltip: 'About Magic Item Compendium',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.auto_fix_high),
                      SizedBox(width: 8),
                      Text('Magic Item Compendium'),
                    ],
                  ),
                  content: const Text(
                    'Browse, filter, and inspect magic items from the 5e SRD 5.1 & 5.2.\n\n'
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
            // Search Bar & Filter Sheet Trigger Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search magic items, traits, rarity, element...',
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
                        tooltip: 'Filter Magic Items',
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
                        _buildSliverItemCards(
                          context,
                          _viewMode == ItemCompendiumViewMode.allItems &&
                                  pinnedItemsInResults.isNotEmpty
                              ? otherItemsInResults
                              : filteredItems,
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

  Widget _buildSliverItemCards(
    BuildContext context,
    List<MagicItem> items,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            final isPinned = pinnedIds.contains(item.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ItemCard(
                item: item,
                edition: edition,
                isPinned: isPinned,
                onTogglePin: () => _togglePinItem(context, item.id),
                onTap: () => _showItemDetails(item, edition, isPinned),
                onCompare: () => _showItemComparison(item, edition, isPinned),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isReliquaryEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReliquaryEmpty ? Icons.bookmark_border : Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              isReliquaryEmpty
                  ? 'Your Personal Reliquary is empty'
                  : 'No magic items match your filters',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isReliquaryEmpty
                  ? 'Tap the bookmark icon on any magic item card to save it to your personal reliquary.'
                  : 'Try clearing your search query or adjusting your filters.',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (isReliquaryEmpty)
              FilledButton.tonalIcon(
                onPressed: () {
                  HapticService.selectionTick(context);
                  setState(() => _viewMode = ItemCompendiumViewMode.allItems);
                },
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Browse All Magic Items'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reset All Filters'),
              ),
          ],
        ),
      ),
    );
  }
}
