import 'package:flutter/material.dart';
import '../models/glyph_gallery_data.dart';
import '../services/haptic_service.dart';
import '../widgets/glyphs/dnd_glyph.dart';
import '../widgets/glyphs/glyph_tokens.dart';

// ---------------------------------------------------------------------------
// VIEW MODE
// ---------------------------------------------------------------------------

enum ItemCompendiumViewMode {
  allItems('All Items', Icons.auto_fix_high),
  myReliquary('My Reliquary', Icons.bookmark);

  final String label;
  final IconData icon;

  const ItemCompendiumViewMode(this.label, this.icon);
}

// ---------------------------------------------------------------------------
// SCREEN
// ---------------------------------------------------------------------------

/// Standalone Magic Item Compendium — searchable, filterable browser of SRD
/// magic items with full glyph visuals and action-trait ring details.
class ItemCompendiumScreen extends StatefulWidget {
  const ItemCompendiumScreen({super.key});

  @override
  State<ItemCompendiumScreen> createState() => _ItemCompendiumScreenState();
}

class _ItemCompendiumScreenState extends State<ItemCompendiumScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  ItemCompendiumViewMode _viewMode = ItemCompendiumViewMode.allItems;

  // Filter state
  ItemCategory? _selectedCategory;
  ItemRarity? _selectedRarity;
  bool _showOnlyAttunement = false;

  // Local "My Reliquary" pinned items (session-level, no persistence needed for MVP)
  final Set<String> _pinnedItemNames = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePin(String itemName) {
    HapticService.selectionTick(context);
    setState(() {
      if (_pinnedItemNames.contains(itemName)) {
        _pinnedItemNames.remove(itemName);
      } else {
        _pinnedItemNames.add(itemName);
      }
    });
  }

  void _clearAllFilters() {
    HapticService.selectionTick(context);
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _selectedRarity = null;
      _showOnlyAttunement = false;
    });
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedRarity != null) count++;
    if (_showOnlyAttunement) count++;
    return count;
  }

  List<GlyphItemEntry> _buildFilteredItems() {
    return GlyphGalleryData.allItems.where((item) {
      if (_viewMode == ItemCompendiumViewMode.myReliquary &&
          !_pinnedItemNames.contains(item.name)) {
        return false;
      }
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_selectedRarity != null && item.rarity != _selectedRarity) {
        return false;
      }
      if (_showOnlyAttunement && !item.requiresAttunement) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        final match = item.name.toLowerCase().contains(q) ||
            item.category.displayName.toLowerCase().contains(q) ||
            item.rarity.displayName.toLowerCase().contains(q) ||
            item.summary.toLowerCase().contains(q) ||
            (item.damageAccent?.displayName.toLowerCase().contains(q) ??
                false) ||
            item.actionRings.any((r) =>
                r.ringType.displayName.toLowerCase().contains(q) ||
                r.damageLegend.toLowerCase().contains(q) ||
                (r.label?.toLowerCase().contains(q) ?? false));
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeFilters = _getActiveFilterCount();
    final filteredItems = _buildFilteredItems();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Color(0xFF2DD4BF)),
            SizedBox(width: 10),
            Text('Magic Item Compendium'),
          ],
        ),
        actions: [
          // View mode toggle
          _buildViewModeToggle(isDark),
          const SizedBox(width: 8),
          // Filter badge button
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filters',
                onPressed: () => _showFilterSheet(context, isDark),
              ),
              if (activeFilters > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2DD4BF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$activeFilters',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildSearchBar(isDark),
        ),
      ),
      body: Column(
        children: [
          _buildCategoryChips(isDark),
          const Divider(height: 1),
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState(isDark)
                : _buildItemGrid(filteredItems, isDark),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildViewModeToggle(bool isDark) {
    return SegmentedButton<ItemCompendiumViewMode>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(
          value: ItemCompendiumViewMode.allItems,
          icon: Icon(ItemCompendiumViewMode.allItems.icon, size: 16),
          label: Text(
            '${ItemCompendiumViewMode.allItems.label} (${GlyphGalleryData.allItems.length})',
          ),
        ),
        ButtonSegment(
          value: ItemCompendiumViewMode.myReliquary,
          icon: Icon(ItemCompendiumViewMode.myReliquary.icon, size: 16),
          label: Text(
            '${ItemCompendiumViewMode.myReliquary.label} (${_pinnedItemNames.length})',
          ),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (sel) {
        HapticService.selectionTick(context);
        setState(() => _viewMode = sel.first);
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search items, rarity, traits, damage type…',
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          isDense: true,
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: isDark ? Colors.white24 : Colors.black12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: isDark ? Colors.white24 : Colors.black12),
          ),
        ),
        onChanged: (val) =>
            setState(() => _searchQuery = val.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF030712) : const Color(0xFFF1F5F9),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Types'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 6),
                ...ItemCategory.values.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: c.getLegibleColor(isDark),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(c.displayName),
                      selected: _selectedCategory == c,
                      onSelected: (sel) =>
                          setState(() => _selectedCategory = sel ? c : null),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Rarities'),
                  selected: _selectedRarity == null,
                  onSelected: (_) => setState(() => _selectedRarity = null),
                ),
                const SizedBox(width: 6),
                ...ItemRarity.values.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: r.getLegibleColor(isDark),
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(r.displayName),
                      selected: _selectedRarity == r,
                      onSelected: (sel) =>
                          setState(() => _selectedRarity = sel ? r : null),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.link, size: 14),
                  label: const Text('Attunement'),
                  selected: _showOnlyAttunement,
                  onSelected: (sel) =>
                      setState(() => _showOnlyAttunement = sel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER SHEET
  // ---------------------------------------------------------------------------

  void _showFilterSheet(BuildContext context, bool isDark) {
    final activeFilters = _getActiveFilterCount();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (activeFilters > 0)
                    TextButton.icon(
                      onPressed: () {
                        _clearAllFilters();
                        Navigator.of(ctx).pop();
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label:
                          Text('Reset All ($activeFilters active)'),
                    ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text('Attunement',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Requires Attunement only'),
                value: _showOnlyAttunement,
                onChanged: (val) {
                  setState(() => _showOnlyAttunement = val);
                  setSheetState(() {});
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(bool isDark) {
    final isMyReliquary = _viewMode == ItemCompendiumViewMode.myReliquary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMyReliquary ? Icons.bookmark_border : Icons.search_off,
              size: 56,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              isMyReliquary
                  ? 'Your reliquary is empty'
                  : 'No items match the current filters',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMyReliquary
                  ? 'Tap the bookmark icon on any item card to add it to your personal reliquary.'
                  : 'Try adjusting filters or clearing your search query.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isMyReliquary && _getActiveFilterCount() > 0) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ITEM GRID
  // ---------------------------------------------------------------------------

  Widget _buildItemGrid(List<GlyphItemEntry> items, bool isDark) {
    // Category header grouping
    final byCategory = <ItemCategory, List<GlyphItemEntry>>{};
    for (final item in items) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }

    // Flatten into sections: header + items per category
    final sections = <_SectionItem>[];
    for (final cat in ItemCategory.values) {
      final catItems = byCategory[cat];
      if (catItems == null || catItems.isEmpty) continue;
      sections.add(_SectionItem.header(cat));
      for (final item in catItems) {
        sections.add(_SectionItem.item(item));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sections.length,
      itemBuilder: (context, idx) {
        final section = sections[idx];
        if (section.isHeader) {
          return _buildCategoryHeader(section.category!, isDark);
        }
        return _buildItemCard(section.item!, isDark);
      },
    );
  }

  Widget _buildCategoryHeader(ItemCategory category, bool isDark) {
    final color = category.getLegibleColor(isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            category.displayName.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(GlyphItemEntry item, bool isDark) {
    final rarityColor = item.rarity.getLegibleColor(isDark);
    final categoryColor = item.category.getLegibleColor(isDark);
    final isPinned = _pinnedItemNames.contains(item.name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Card(
        elevation: isPinned ? 6 : 3,
        color: isDark ? const Color(0xFF090D16) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isPinned
                ? const Color(0xFF2DD4BF).withValues(alpha: 0.7)
                : rarityColor.withValues(alpha: 0.45),
            width: isPinned ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showItemDetails(item, isDark),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Glyph
                DndGlyph.item(
                  category: item.category,
                  rarity: item.rarity,
                  requiresAttunement: item.requiresAttunement,
                  damageAccent: item.damageAccent,
                  actionRings: item.actionRings,
                  size: 72,
                  isDarkMode: isDark,
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + rarity badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: rarityColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              item.rarity.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: rarityColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Category + attunement
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.category.displayName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: categoryColor,
                            ),
                          ),
                          if (item.requiresAttunement)
                            Text(
                              '• ATTUNEMENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF0284C7),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Summary
                      Text(
                        item.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      // Action rings
                      if (item.actionRings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: item.actionRings.map((r) {
                              final ringColor =
                                  r.getEffectiveColor(rarityColor);
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ringColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: ringColor.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                          color: ringColor,
                                          shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      r.damageLegend.isNotEmpty
                                          ? '${r.ringType.displayName} (${r.damageLegend})'
                                          : r.ringType.displayName,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: ringColor,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Bookmark button
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isPinned ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: isPinned
                        ? const Color(0xFF2DD4BF)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                  tooltip: isPinned
                      ? 'Remove from My Reliquary'
                      : 'Add to My Reliquary',
                  onPressed: () => _togglePin(item.name),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DETAIL DIALOG
  // ---------------------------------------------------------------------------

  void _showItemDetails(GlyphItemEntry item, bool isDark) {
    final rarityColor = item.rarity.getLegibleColor(isDark);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final pinned = _pinnedItemNames.contains(item.name);
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
            title: Row(
              children: [
                DndGlyph.item(
                  category: item.category,
                  rarity: item.rarity,
                  requiresAttunement: item.requiresAttunement,
                  damageAccent: item.damageAccent,
                  actionRings: item.actionRings,
                  size: 72,
                  isDarkMode: isDark,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category.displayName} • ${item.rarity.displayName}'
                        '${item.requiresAttunement ? ' (Requires Attunement)' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: rarityColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Category', item.category.displayName,
                      isDark: isDark),
                  _buildDetailRow('Rarity', item.rarity.displayName,
                      accentColor: rarityColor, isDark: isDark),
                  _buildDetailRow(
                      'Attunement',
                      item.requiresAttunement ? 'Required' : 'Not required',
                      isDark: isDark),
                  if (item.damageAccent != null)
                    _buildDetailRow(
                        'Damage / Element', item.damageAccent!.displayName,
                        isDark: isDark),
                  const SizedBox(height: 12),
                  Text(
                    item.summary,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (item.actionRings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Action & Trait Rings:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ...item.actionRings.map((r) {
                      final ringColor = r.getEffectiveColor(rarityColor);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: ringColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${r.ringType.displayName}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: ringColor,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                r.label ?? r.damageLegend,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  _togglePin(item.name);
                  setDialogState(() {});
                },
                icon: Icon(
                  pinned ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: pinned
                      ? const Color(0xFF2DD4BF)
                      : null,
                ),
                label: Text(pinned
                    ? 'Remove from Reliquary'
                    : 'Add to Reliquary'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {Color? accentColor, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: accentColor,
                fontWeight:
                    accentColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------

/// Union type for ListView sections (header or item row).
class _SectionItem {
  final bool isHeader;
  final ItemCategory? category;
  final GlyphItemEntry? item;

  const _SectionItem.header(this.category)
      : isHeader = true,
        item = null;

  const _SectionItem.item(this.item)
      : isHeader = false,
        category = null;
}
