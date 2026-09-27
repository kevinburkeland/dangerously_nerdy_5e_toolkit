import 'package:flutter/material.dart';
import '../models/characters/srd_species_library.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/core_types.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../presentation/codex/codex.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/common/compendium_search_header.dart';
import '../widgets/common/empty_state_card.dart';
import '../widgets/common/responsive_card_grid.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/races/race_card.dart';
import '../widgets/races/race_detail_dialog.dart';
import '../widgets/room_banner_widget.dart';

enum SpeciesViewMode {
  all('All Species', Icons.people_alt),
  bookmarked('Bookmarks', Icons.bookmark),
  diffs2024('2024 Diffs', Icons.auto_awesome),
  homebrew('Homebrew', Icons.auto_fix_high);

  final String label;
  final IconData icon;
  const SpeciesViewMode(this.label, this.icon);
}

/// Species & Lineages Codex browser screen providing comprehensive SRD & Homebrew species catalog.
class SpeciesCodexScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const SpeciesCodexScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<SpeciesCodexScreen> createState() => _SpeciesCodexScreenState();
}

class _SpeciesCodexScreenState extends State<SpeciesCodexScreen> {
  DmRulesEdition? _localEditionOverride;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  SpeciesViewMode _viewMode = SpeciesViewMode.all;
  String _selectedSize = 'All';

  final List<String> _sizeOptions = ['All', 'Medium', 'Small', 'Has Lineages'];

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  void didUpdateWidget(covariant SpeciesCodexScreen oldWidget) {
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

  DmRulesEdition _resolveEdition(BuildContext context) {
    if (widget.initialEdition != null) {
      return _localEditionOverride ?? widget.initialEdition!;
    }
    return SettingsScope.maybeOf(context)?.settings.rulesEdition ??
        DmRulesEdition.v2024;
  }

  Set<String> _getPinnedIds(BuildContext context) {
    return SettingsScope.of(context).settings.pinnedRaceIds;
  }

  void _togglePinRace(BuildContext context, String slug) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).togglePinRace(slug);
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSize = 'All';
      _viewMode = SpeciesViewMode.all;
    });
  }

  List<Race> _filterRaces(
      List<Race> races, DmRulesEdition edition, Set<String> pinnedIds) {
    final is2024 = edition == DmRulesEdition.v2024;

    return races.where((race) {
      final slug = race.id.slug.toLowerCase();
      final name = race.name.toLowerCase();
      final size = race.size.toLowerCase();
      final traits = race.traitsMarkdown.toLowerCase();

      // 1. Rules Edition Filter
      if (is2024) {
        if (slug == 'human-variant' || slug == 'custom-lineage') return false;
      }

      // 2. View Mode Filter
      switch (_viewMode) {
        case SpeciesViewMode.bookmarked:
          if (!pinnedIds.contains(race.id.slug)) return false;
        case SpeciesViewMode.diffs2024:
          if (race.id.ruleset != RulesetVersion.v2024 ||
              race.id.ruleset == RulesetVersion.homebrew) {
            return false;
          }
        case SpeciesViewMode.homebrew:
          if (race.id.ruleset != RulesetVersion.homebrew) return false;
        case SpeciesViewMode.all:
          break;
      }

      // 3. Size / Lineage Filter
      if (_selectedSize != 'All') {
        if (_selectedSize == 'Medium' && !size.contains('medium')) return false;
        if (_selectedSize == 'Small' && !size.contains('small')) return false;
        if (_selectedSize == 'Has Lineages' && race.subraces.isEmpty) {
          return false;
        }
      }

      // 4. Text Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchesName = name.contains(query);
        final matchesSlug = slug.contains(query);
        final matchesSize = size.contains(query);
        final matchesSpeed = race.speed.toLowerCase().contains(query);
        final matchesTraits = traits.contains(query);
        final matchesSubraces = race.subraces.any((s) =>
            s.name.toLowerCase().contains(query) ||
            s.traitsMarkdown.toLowerCase().contains(query));

        if (!matchesName &&
            !matchesSlug &&
            !matchesSize &&
            !matchesSpeed &&
            !matchesTraits &&
            !matchesSubraces) {
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
    final allRaces = SrdSpeciesLibrary.allSpecies;
    final filteredRaces = _filterRaces(allRaces, edition, pinnedIds);

    return CodexPageShell(
      headerConfig: CodexHeaderConfig(
        title: 'Species & Lineages Codex',
        icon: Icons.people_alt,
        accentColor: const Color(0xFF10B981),
        visibleCount: filteredRaces.length,
      ),
      headerControl: RulesEditionToggle(
        currentEdition: edition,
        onEditionChanged: (newEdition) {
          HapticService.selectionTick(context);
          if (widget.initialEdition != null) {
            setState(() => _localEditionOverride = newEdition);
          }
          SettingsScope.maybeOf(context)?.setRulesEdition(newEdition);
        },
      ),
      sessionContextBanner: RoomBannerWidget(compact: true),
      searchHeader: CompendiumSearchHeader(
        controller: _searchController,
        searchQuery: _searchQuery,
        hintText: 'Search species by name, speed, size, or trait...',
        activeFilterCount:
            (_selectedSize != 'All' ? 1 : 0) + (_searchQuery.isNotEmpty ? 1 : 0),
        onChanged: (query) => setState(() => _searchQuery = query),
        onClear: () => setState(() {
          _searchController.clear();
          _searchQuery = '';
        }),
        onFilterTap: null,
      ),
      modeSelector: CodexModeSelector<SpeciesViewMode>(
        modes: SpeciesViewMode.values
            .map((mode) => CodexViewMode<SpeciesViewMode>(
                  key: mode,
                  label: mode.label,
                  icon: mode.icon,
                  accentColor: const Color(0xFF10B981),
                ))
            .toList(),
        selectedMode: _viewMode,
        defaultAccentColor: const Color(0xFF10B981),
        onModeSelected: (mode) {
          HapticService.selectionTick(context);
          setState(() => _viewMode = mode);
        },
      ),
      filterArea: CodexFilterStrip<String>(
        options: _sizeOptions
            .map((size) => CodexFilterOption<String>(
                  value: size,
                  label: size,
                ))
            .toList(),
        selectedValue: _selectedSize,
        onSelected: (size) {
          HapticService.selectionTick(context);
          setState(() => _selectedSize = size);
        },
      ),
      isEmpty: filteredRaces.isEmpty,
      emptyState: EmptyStateCard(
        title: 'No Species Found',
        message: 'No species match your query or size filter.',
        icon: Icons.people_outline,
        actionLabel: 'Clear All Filters',
        onAction: _clearAllFilters,
      ),
      content: ResponsiveCardGrid<Race>(
        items: filteredRaces,
        itemBuilder: (context, race) => RaceCard(
          race: race,
          edition: edition,
          isPinned: pinnedIds.contains(race.id.slug),
          onTogglePin: () => _togglePinRace(context, race.id.slug),
          onTap: () => RaceDetailDialog.show(
            context,
            race,
            edition: edition,
          ),
        ),
      ),
    );
  }
}
