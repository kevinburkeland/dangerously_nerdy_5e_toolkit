import 'package:flutter/material.dart';
import '../models/characters/srd_feats_library.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/core_types.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../widgets/common/compendium_search_header.dart';
import '../widgets/common/empty_state_card.dart';
import '../widgets/common/responsive_card_grid.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/feats/feat_card.dart';
import '../widgets/feats/feat_detail_dialog.dart';
import '../widgets/room_banner_widget.dart';

enum FeatsViewMode {
  allFeats('All Feats', Icons.military_tech),
  myBookmarks('Bookmarks', Icons.bookmark),
  revisions2024('2024 Diffs', Icons.auto_awesome),
  homebrew('Homebrew', Icons.auto_fix_high);

  final String label;
  final IconData icon;

  const FeatsViewMode(this.label, this.icon);
}

/// Comprehensive Feats Compendium providing browsing, filtering, and bookmarking
/// for all 2014 and 2024 SRD feats, Origin feats, Fighting styles, and custom homebrew.
class FeatsCompendiumScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const FeatsCompendiumScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<FeatsCompendiumScreen> createState() => _FeatsCompendiumScreenState();
}

class _FeatsCompendiumScreenState extends State<FeatsCompendiumScreen> {
  DmRulesEdition? _localEditionOverride;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  FeatsViewMode _viewMode = FeatsViewMode.allFeats;
  String? _selectedCategory; // null = all, 'Origin', 'General', 'Fighting Style', 'Epic Boon'
  bool _showOnlyPrerequisites = false;
  bool _showOnlyNoPrerequisites = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
    _syncHomebrew();
  }

  Future<void> _syncHomebrew() async {
    await HomebrewPersistenceService().syncToLibraries();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DmRulesEdition _resolveEdition(BuildContext context) {
    return _localEditionOverride ??
        SettingsScope.maybeOf(context)?.settings.rulesEdition ??
        DmRulesEdition.v2024;
  }

  Set<String> _getPinnedIds(BuildContext context) {
    return SettingsScope.maybeOf(context)?.settings.pinnedFeatIds ?? const <String>{};
  }

  void _togglePinFeat(BuildContext context, String featSlug) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).togglePinFeat(featSlug);
  }

  void _clearAllFilters() {
    HapticService.selectionTick(context);
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _showOnlyPrerequisites = false;
      _showOnlyNoPrerequisites = false;
    });
  }

  List<Feat> _filterFeats(List<Feat> allFeats, DmRulesEdition edition, Set<String> pinnedIds) {
    final ruleset = edition == DmRulesEdition.v2024 ? RulesetVersion.v2024 : RulesetVersion.v2014;

    return allFeats.where((feat) {
      // View Mode Filter
      if (_viewMode == FeatsViewMode.myBookmarks && !pinnedIds.contains(feat.id.slug)) {
        return false;
      }
      if (_viewMode == FeatsViewMode.homebrew && feat.id.ruleset != RulesetVersion.homebrew) {
        return false;
      }
      if (_viewMode == FeatsViewMode.revisions2024 && feat.id.ruleset != RulesetVersion.v2024) {
        return false;
      }

      // Ruleset baseline filter (unless viewing homebrew or all)
      if (_viewMode == FeatsViewMode.allFeats) {
        if (feat.id.ruleset != RulesetVersion.homebrew && feat.id.ruleset != ruleset) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != null) {
        if (feat.category.toLowerCase() != _selectedCategory!.toLowerCase()) {
          return false;
        }
      }

      // Prerequisite filter
      if (_showOnlyPrerequisites && (feat.prerequisite == null || feat.prerequisite!.isEmpty)) {
        return false;
      }
      if (_showOnlyNoPrerequisites && feat.prerequisite != null && feat.prerequisite!.isNotEmpty) {
        return false;
      }

      // Search Query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = feat.name.toLowerCase().contains(q);
        final matchDesc = feat.descriptionMarkdown.toLowerCase().contains(q);
        final matchCat = feat.category.toLowerCase().contains(q);
        final matchReq = feat.prerequisite?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchDesc && !matchCat && !matchReq) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildViewModeTabs(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: FeatsViewMode.values.map((mode) {
          final isSelected = _viewMode == mode;
          final primaryColor = theme.colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                mode.icon,
                size: 16,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(mode.label),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: isDark ? primaryColor.withValues(alpha: 0.3) : primaryColor.withValues(alpha: 0.15),
              side: BorderSide(
                color: isSelected ? primaryColor : theme.colorScheme.outlineVariant,
                width: isSelected ? 1.4 : 1.0,
              ),
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? (isDark ? Colors.white : primaryColor) : theme.colorScheme.onSurface,
                fontSize: 12.5,
              ),
              onSelected: (_) {
                HapticService.selectionTick(context);
                setState(() => _viewMode = mode);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryFilters(BuildContext context) {
    final categories = ['Origin', 'General', 'Fighting Style', 'Epic Boon'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All Categories'),
            selected: _selectedCategory == null,
            onSelected: (_) {
              HapticService.selectionTick(context);
              setState(() => _selectedCategory = null);
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 6),
          ...categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) {
                  HapticService.selectionTick(context);
                  setState(() => _selectedCategory = isSelected ? null : cat);
                },
                visualDensity: VisualDensity.compact,
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edition = _resolveEdition(context);
    final pinnedIds = _getPinnedIds(context);
    final allFeats = SrdFeatsLibrary.allFeats;
    final filteredFeats = _filterFeats(allFeats, edition, pinnedIds);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.military_tech, size: 22, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            const Text('Feats Compendium', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${filteredFeats.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        actions: [
          RulesEditionToggle(
            currentEdition: edition,
            onEditionChanged: (newEdition) {
              HapticService.selectionTick(context);
              setState(() => _localEditionOverride = newEdition);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Room Broadcast Banner (if connected to party)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: RoomBannerWidget(compact: true),
            ),

            // Search Header
            CompendiumSearchHeader(
              controller: _searchController,
              searchQuery: _searchQuery,
              hintText: 'Search feats by name, prerequisite, or effect...',
              activeFilterCount: (_selectedCategory != null ? 1 : 0) +
                  (_showOnlyPrerequisites ? 1 : 0) +
                  (_showOnlyNoPrerequisites ? 1 : 0),
              onChanged: (query) => setState(() => _searchQuery = query),
              onClear: () => setState(() {
                _searchController.clear();
                _searchQuery = '';
              }),
              onFilterTap: null,
            ),

            // View Mode Tabs
            _buildViewModeTabs(context),

            // Category Chips
            _buildCategoryFilters(context),

            const SizedBox(height: 6),

            // Responsive Card Grid or Empty State
            Expanded(
              child: filteredFeats.isEmpty
                  ? EmptyStateCard(
                      title: 'No Feats Found',
                      message: 'No feats matched your current search filters or category.',
                      icon: Icons.military_tech,
                      actionLabel: 'Clear Filters',
                      onAction: _clearAllFilters,
                    )
                  : ResponsiveCardGrid<Feat>(
                      items: filteredFeats,
                      itemBuilder: (context, feat) => FeatCard(
                        feat: feat,
                        isPinned: pinnedIds.contains(feat.id.slug),
                        onTogglePin: () => _togglePinFeat(context, feat.id.slug),
                        onTap: () => FeatDetailDialog.show(
                          context,
                          feat: feat,
                          isPinned: pinnedIds.contains(feat.id.slug),
                          onTogglePin: () => _togglePinFeat(context, feat.id.slug),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
