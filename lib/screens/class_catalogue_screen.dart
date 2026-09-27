import 'package:flutter/material.dart';
import '../models/characters/srd_classes_library.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/core_types.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../presentation/codex/codex.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../widgets/classes/class_card.dart';
import '../widgets/classes/class_detail_dialog.dart';
import '../widgets/common/compendium_search_header.dart';
import '../widgets/common/empty_state_card.dart';
import '../widgets/common/responsive_card_grid.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';

enum ClassViewMode {
  allClasses('All Classes', Icons.shield),
  myBookmarks('Bookmarks', Icons.bookmark),
  revisions2024('2024 Diffs', Icons.auto_awesome),
  homebrew('Homebrew', Icons.auto_fix_high);

  final String label;
  final IconData icon;

  const ClassViewMode(this.label, this.icon);
}

enum ClassRoleFilter {
  all('All Roles'),
  martial('Martial'),
  fullCaster('Full Casters'),
  halfCaster('Half Casters'),
  pactCaster('Pact Casters');

  final String label;
  const ClassRoleFilter(this.label);
}

/// Comprehensive Class & Subclass Catalogue providing browsing, feature exploration,
/// and archetype breakdowns for 5e classes under 2014, 2024, and homebrew rules.
class ClassCatalogueScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ClassCatalogueScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<ClassCatalogueScreen> createState() => _ClassCatalogueScreenState();
}

class _ClassCatalogueScreenState extends State<ClassCatalogueScreen> {
  DmRulesEdition? _localEditionOverride;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  ClassViewMode _viewMode = ClassViewMode.allClasses;
  ClassRoleFilter _roleFilter = ClassRoleFilter.all;

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
    _syncHomebrew();
  }

  @override
  void didUpdateWidget(covariant ClassCatalogueScreen oldWidget) {
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
    return SettingsScope.maybeOf(context)?.settings.pinnedClassIds ??
        const <String>{};
  }

  void _togglePinClass(BuildContext context, String classSlug) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).togglePinClass(classSlug);
  }

  void _clearAllFilters() {
    HapticService.selectionTick(context);
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _roleFilter = ClassRoleFilter.all;
    });
  }

  bool _matchesRole(CharacterClass cls, ClassRoleFilter filter) {
    final slug = cls.id.slug.toLowerCase();
    switch (filter) {
      case ClassRoleFilter.all:
        return true;
      case ClassRoleFilter.martial:
        return ['barbarian', 'fighter', 'monk', 'rogue'].contains(slug);
      case ClassRoleFilter.fullCaster:
        return ['bard', 'cleric', 'druid', 'sorcerer', 'wizard'].contains(slug);
      case ClassRoleFilter.halfCaster:
        return ['paladin', 'ranger'].contains(slug);
      case ClassRoleFilter.pactCaster:
        return slug == 'warlock';
    }
  }

  List<CharacterClass> _filterClasses(
    List<CharacterClass> allClasses,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    return allClasses.where((cls) {
      // 1. View Mode Filter
      if (_viewMode == ClassViewMode.myBookmarks &&
          !pinnedIds.contains(cls.id.slug)) {
        return false;
      }
      if (_viewMode == ClassViewMode.homebrew &&
          cls.id.ruleset != RulesetVersion.homebrew) {
        return false;
      }
      if (_viewMode == ClassViewMode.revisions2024) {
        if (cls.id.ruleset == RulesetVersion.homebrew) return false;
      }

      // 2. Role Filter
      if (!_matchesRole(cls, _roleFilter)) {
        return false;
      }

      // Search Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = cls.name.toLowerCase().contains(q);
        final matchFeatures = cls.featuresMarkdown.toLowerCase().contains(q);
        final matchSubclasses =
            cls.subclasses.any((s) => s.name.toLowerCase().contains(q));
        final matchPrimary =
            cls.primaryAbility?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchFeatures && !matchSubclasses && !matchPrimary) {
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
    final allClasses = SrdClassesLibrary.allClasses;
    final filteredClasses = _filterClasses(allClasses, edition, pinnedIds);

    return CodexPageShell(
      headerConfig: CodexHeaderConfig(
        title: 'Class Catalogue',
        icon: Icons.shield,
        accentColor: const Color(0xFFFF7043),
        visibleCount: filteredClasses.length,
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
        hintText: 'Search classes, subclasses, or features...',
        activeFilterCount: _roleFilter != ClassRoleFilter.all ? 1 : 0,
        onChanged: (query) => setState(() => _searchQuery = query),
        onClear: () => setState(() {
          _searchController.clear();
          _searchQuery = '';
        }),
        onFilterTap: null,
      ),
      modeSelector: CodexModeSelector<ClassViewMode>(
        modes: ClassViewMode.values
            .map((mode) => CodexViewMode<ClassViewMode>(
                  key: mode,
                  label: mode.label,
                  icon: mode.icon,
                ))
            .toList(),
        selectedMode: _viewMode,
        onModeSelected: (mode) => setState(() => _viewMode = mode),
      ),
      filterArea: CodexFilterStrip<ClassRoleFilter>(
        options: ClassRoleFilter.values
            .map((role) => CodexFilterOption<ClassRoleFilter>(
                  value: role,
                  label: role.label,
                ))
            .toList(),
        selectedValue: _roleFilter,
        onSelected: (role) => setState(() => _roleFilter = role),
      ),
      isEmpty: filteredClasses.isEmpty,
      emptyState: EmptyStateCard(
        title: 'No Classes Found',
        message: 'No classes matched your current filter criteria or query.',
        icon: Icons.shield,
        actionLabel: 'Clear Filters',
        onAction: _clearAllFilters,
      ),
      content: ResponsiveCardGrid<CharacterClass>(
        items: filteredClasses,
        itemBuilder: (context, cls) => ClassCard(
          characterClass: cls,
          edition: edition,
          isPinned: pinnedIds.contains(cls.id.slug),
          onTogglePin: () => _togglePinClass(context, cls.id.slug),
          onTap: () => ClassDetailDialog.show(
            context,
            characterClass: cls,
            edition: edition,
            isPinned: pinnedIds.contains(cls.id.slug),
            onTogglePin: () => _togglePinClass(context, cls.id.slug),
          ),
        ),
      ),
    );
  }
}
