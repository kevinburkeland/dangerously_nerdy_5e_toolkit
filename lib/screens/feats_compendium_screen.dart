import 'package:flutter/material.dart';
import '../models/characters/srd_feats_library.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/core_types.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../presentation/codex/codex.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../widgets/common/compendium_search_header.dart';
import '../widgets/common/empty_state_card.dart';
import '../widgets/common/responsive_card_grid.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/feats/feat_card.dart';
import '../widgets/feats/feat_detail_dialog.dart';

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
  String?
      _selectedCategory; // null = all, 'Origin', 'General', 'Fighting Style', 'Epic Boon'
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

  @override
  void didUpdateWidget(covariant FeatsCompendiumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEdition != oldWidget.initialEdition) {
      _localEditionOverride = widget.initialEdition;
    }
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
    if (widget.initialEdition != null) {
      return _localEditionOverride ?? widget.initialEdition!;
    }
    return SettingsScope.maybeOf(context)?.settings.rulesEdition ??
        DmRulesEdition.v2024;
  }

  Set<String> _getPinnedIds(BuildContext context) {
    return SettingsScope.maybeOf(context)?.settings.pinnedFeatIds ??
        const <String>{};
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

  List<Feat> _filterFeats(
      List<Feat> allFeats, DmRulesEdition edition, Set<String> pinnedIds) {
    final is2024 = edition == DmRulesEdition.v2024;

    return allFeats.where((feat) {
      // 1. View Mode Filter
      if (_viewMode == FeatsViewMode.myBookmarks &&
          !pinnedIds.contains(feat.id.slug)) {
        return false;
      }
      if (_viewMode == FeatsViewMode.homebrew &&
          feat.id.ruleset != RulesetVersion.homebrew) {
        return false;
      }
      if (_viewMode == FeatsViewMode.revisions2024) {
        // Show 2024 specific Origin feats or revised feats
        if (feat.id.ruleset == RulesetVersion.homebrew) return false;
        final has2024Revision = feat.category == 'Origin' ||
            feat.id.ruleset == RulesetVersion.v2024 ||
            feat.customProperties['has2024Revision'] == true ||
            feat.id.slug == 'grappler';
        if (!has2024Revision) return false;
      }

      // 2. Ruleset / Edition Filter for All Feats view
      if (_viewMode == FeatsViewMode.allFeats) {
        if (!is2024) {
          // 2014 RAW mode: Hide 2024-exclusive feats (preserve feats present in both or revised)
          final isAvailableIn2014 = feat.id.slug == 'grappler' ||
              feat.id.ruleset == RulesetVersion.v2014 ||
              feat.id.ruleset == RulesetVersion.homebrew ||
              feat.customProperties['has2024Revision'] == true;
          if (!isAvailableIn2014 &&
              (feat.id.ruleset == RulesetVersion.v2024 ||
                  feat.category == 'Origin')) {
            return false;
          }
        }
      }

      // 3. Category Filter
      if (_selectedCategory != null) {
        final featCat =
            (!is2024 && feat.category == 'Origin') ? 'General' : feat.category;
        if (featCat.toLowerCase() != _selectedCategory!.toLowerCase() &&
            feat.category.toLowerCase() != _selectedCategory!.toLowerCase()) {
          return false;
        }
      }

      // 4. Prerequisite Filter
      if (_showOnlyPrerequisites &&
          (feat.prerequisite == null || feat.prerequisite!.isEmpty)) {
        return false;
      }
      if (_showOnlyNoPrerequisites &&
          feat.prerequisite != null &&
          feat.prerequisite!.isNotEmpty) {
        return false;
      }

      // 5. Search Query Filter
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

  @override
  Widget build(BuildContext context) {
    final edition = _resolveEdition(context);
    final pinnedIds = _getPinnedIds(context);
    final allFeats = SrdFeatsLibrary.allFeats;
    final filteredFeats = _filterFeats(allFeats, edition, pinnedIds);

    final categories = edition == DmRulesEdition.v2024
        ? const ['Origin', 'General', 'Fighting Style', 'Epic Boon']
        : const ['General', 'Fighting Style'];

    return CodexPageShell(
      headerConfig: CodexHeaderConfig(
        title: 'Feats Compendium',
        icon: Icons.military_tech,
        accentColor: const Color(0xFFF59E0B),
        visibleCount: filteredFeats.length,
      ),
      rulesEditionToggle: RulesEditionToggle(
        currentEdition: edition,
        onEditionChanged: (newEdition) {
          HapticService.selectionTick(context);
          if (widget.initialEdition != null) {
            setState(() => _localEditionOverride = newEdition);
          }
          SettingsScope.maybeOf(context)?.setRulesEdition(newEdition);
        },
      ),
      searchHeader: CompendiumSearchHeader(
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
      modeSelector: CodexModeSelector<FeatsViewMode>(
        modes: FeatsViewMode.values
            .map((mode) => CodexViewMode<FeatsViewMode>(
                  key: mode,
                  label: mode.label,
                  icon: mode.icon,
                ))
            .toList(),
        selectedMode: _viewMode,
        onModeSelected: (mode) => setState(() => _viewMode = mode),
      ),
      filterArea: CodexFilterStrip<String?>(
        options: [
          const CodexFilterOption<String?>(
            value: null,
            label: 'All Categories',
          ),
          ...categories.map((cat) => CodexFilterOption<String?>(
                value: cat,
                label: cat,
              )),
        ],
        selectedValue: _selectedCategory,
        allowDeselect: true,
        deselectValue: null,
        onSelected: (cat) => setState(() => _selectedCategory = cat),
      ),
      isEmpty: filteredFeats.isEmpty,
      emptyState: EmptyStateCard(
        title: 'No Feats Found',
        message: 'No feats matched your current search filters or category.',
        icon: Icons.military_tech,
        actionLabel: 'Clear Filters',
        onAction: _clearAllFilters,
      ),
      content: ResponsiveCardGrid<Feat>(
        items: filteredFeats,
        itemBuilder: (context, feat) => FeatCard(
          feat: feat,
          isPinned: pinnedIds.contains(feat.id.slug),
          edition: edition,
          onTogglePin: () => _togglePinFeat(context, feat.id.slug),
          onTap: () => FeatDetailDialog.show(
            context,
            feat: feat,
            isPinned: pinnedIds.contains(feat.id.slug),
            edition: edition,
            onTogglePin: () => _togglePinFeat(context, feat.id.slug),
          ),
        ),
      ),
    );
  }
}
