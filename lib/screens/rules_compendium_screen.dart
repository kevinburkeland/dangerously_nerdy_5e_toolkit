import 'package:dangerously_nerdy_5e_toolkit/theme/domain_ui_extensions.dart';
import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../providers/settings_provider.dart';
import '../services/a11y_service.dart';
import '../services/haptic_service.dart';
import '../utils/secure_random.dart';
import '../widgets/common/empty_state_card.dart';
import '../widgets/common/responsive_card_grid.dart';
import '../widgets/dm_reference/dm_rule_card.dart';
import '../widgets/dm_reference/dm_rule_comparison_dialog.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/room_banner_widget.dart';
import 'table_index_screen.dart';

/// High-speed SRD 5.1 (2014) & SRD 5.2 (2024) Rules Compendium Screen.
class RulesCompendiumScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const RulesCompendiumScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<RulesCompendiumScreen> createState() => _RulesCompendiumScreenState();
}

class _RulesCompendiumScreenState extends State<RulesCompendiumScreen> {
  DmRulesEdition? _localEditionOverride;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DmCategory? _selectedCategory;
  bool _showOnlyChangedIn2024 = false;
  bool _showOnlyPinned = false;

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
    return SettingsScope.of(context).settings.pinnedRuleIds;
  }

  void _togglePinRule(BuildContext context, String ruleId) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).togglePinRule(ruleId);
  }

  void _clearAllPinnedRules(BuildContext context) {
    HapticService.selectionTick(context);
    SettingsScope.of(context).clearPinnedRules();
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

  void _performQuickRoll(int sides, String label) {
    HapticService.lightImpact(context);
    final result = secureRandom.nextInt(sides) + 1;
    A11yService.announce('Quick roll for $label: rolled $result on d$sides.');
    setState(() {
      _lastQuickRollLabel = '$label: $result';
    });
  }

  void _showCompareDialog(BuildContext context, DmReferenceItem item) {
    DmRuleComparisonDialog.show(
      context,
      item: item,
      isPinned: _getPinnedIds(context).contains(item.id),
      onTogglePin: () => _togglePinRule(context, item.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final pinnedIds = _getPinnedIds(context);
    const allItems = DmScreenLibrary.allItems;

    final filteredItems = allItems.where((item) {
      if (_showOnlyPinned && !pinnedIds.contains(item.id)) {
        return false;
      }
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_showOnlyChangedIn2024 && !item.isChangedIn2024) {
        return false;
      }
      if (_searchQuery.isNotEmpty && !item.matches(_searchQuery)) {
        return false;
      }
      return true;
    }).toList();

    final pinnedFilteredItems = filteredItems.where((item) => pinnedIds.contains(item.id)).toList();
    final otherFilteredItems = filteredItems.where((item) => !pinnedIds.contains(item.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  "Rules Compendium",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: RulesEditionToggle(
              currentEdition: edition,
              onEditionChanged: (newEdition) => _onEditionChanged(context, newEdition),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderBanner(theme, edition),
                        const SizedBox(height: 12),
                        RoomBannerWidget(compact: true),
                        const SizedBox(height: 12),
                        _buildQuickRollBar(theme),
                        const SizedBox(height: 16),
                        _buildSearchAndFilters(theme, pinnedIds.length),
                        const SizedBox(height: 16),
                        _buildCategoryChips(theme, allItems),
                        const SizedBox(height: 16),
                        if (_selectedCategory == DmCategory.tables) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.casino_outlined, color: Color(0xFFF59E0B), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Interactive Table Roller & Generators',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Roll on SRD treasure hoards, magic items A-I, trinkets, wild magic, and madness tables.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.black,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                  onPressed: () {
                                    HapticService.selectionTick(context);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const TableIndexScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.table_chart, size: 14),
                                  label: const Text('Open Roller', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'SHOWING ${filteredItems.length} OF ${allItems.length} RULES',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: edition == DmRulesEdition.v2024
                                    ? Colors.cyanAccent.withValues(alpha: 0.15)
                                    : Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: edition == DmRulesEdition.v2024
                                      ? Colors.cyanAccent.withValues(alpha: 0.4)
                                      : Colors.amber.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                edition == DmRulesEdition.v2024 ? 'Active: 2024 Revised' : 'Active: 2014 5e RAW',
                                style: TextStyle(
                                  color: edition == DmRulesEdition.v2024 ? Colors.cyanAccent : Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                if (pinnedFilteredItems.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: _buildPinnedSectionHeader(theme, pinnedFilteredItems.length),
                    ),
                  ),
                  _buildSliverItemsGrid(context, pinnedFilteredItems, edition, pinnedIds),
                ],

                if (otherFilteredItems.isNotEmpty) ...[
                  if (pinnedFilteredItems.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      sliver: SliverToBoxAdapter(
                        child: _buildSectionHeader(
                          theme,
                          _selectedCategory != null
                              ? _selectedCategory!.label.toUpperCase()
                              : 'ALL RULES (${otherFilteredItems.length})',
                        ),
                      ),
                    ),
                  _buildSliverItemsGrid(context, otherFilteredItems, edition, pinnedIds),
                ],

                if (filteredItems.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _buildEmptyState(theme),
                    ),
                  ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedSectionHeader(ThemeData theme, int count) {
    final isDark = theme.brightness == Brightness.dark;
    final pinColor = isDark ? Colors.amber : const Color(0xFFB45309);
    return Semantics(
      header: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: pinColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pinColor.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.push_pin, color: pinColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'PINNED RULES ($count)',
                style: TextStyle(
                  color: pinColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => _clearAllPinnedRules(context),
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Unpin All', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(ThemeData theme, DmRulesEdition edition) {
    final is2024 = edition == DmRulesEdition.v2024;
    final isDark = theme.brightness == Brightness.dark;
    final bannerAccent = is2024
        ? (isDark ? Colors.cyanAccent : theme.colorScheme.primary)
        : (isDark ? Colors.amber : const Color(0xFFB45309));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: bannerAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bannerAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              is2024 ? Icons.auto_awesome : Icons.menu_book,
              color: bannerAccent,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        is2024 ? '2024 Revised 5e Rulebook' : '2014 (SRD 5.1 RAW) Rulebook',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: bannerAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        is2024 ? 'Revised' : 'Legacy',
                        style: TextStyle(
                          color: bannerAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  is2024
                      ? 'Displaying 2024 Revised rules (Free SRD 5.2 compatible). Rules that changed are tagged with "2024 Diff".'
                      : 'Displaying original 2014 rules (SRD 5.1). Tap any rule card to see what changed in 2024.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRollBar(ThemeData theme) {
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino_outlined, color: primary, size: 18),
              const SizedBox(width: 6),
              Semantics(
                header: true,
                child: Text(
                  'Quick Roller:',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          _buildDiceButton(theme, 'd20', () => _performQuickRoll(20, 'd20')),
          _buildDiceButton(theme, 'd100', () => _performQuickRoll(100, 'd100')),
          _buildDiceButton(theme, 'd6', () => _performQuickRoll(6, 'd6')),
          _buildDiceButton(theme, 'd8', () => _performQuickRoll(8, 'd8')),
          _buildDiceButton(theme, 'd12', () => _performQuickRoll(12, 'd12')),
          if (_lastQuickRollLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _lastQuickRollLabel!,
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiceButton(ThemeData theme, String label, VoidCallback onTap) {
    final isDark = theme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Quick roll $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2E2A44) : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme, int pinnedCount) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty ? primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search rules (supports tag:action, category:combat, etc.)...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: primary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: Icon(
                Icons.auto_awesome,
                size: 16,
                color: _showOnlyChangedIn2024 ? theme.colorScheme.onPrimary : diffColor,
              ),
              label: Text(
                'Show Only 2024 Rule Changes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _showOnlyChangedIn2024 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                ),
              ),
              selected: _showOnlyChangedIn2024,
              selectedColor: diffColor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              checkmarkColor: theme.colorScheme.onPrimary,
              onSelected: (val) {
                HapticService.selectionTick(context);
                setState(() => _showOnlyChangedIn2024 = val);
              },
            ),
            FilterChip(
              avatar: Icon(
                Icons.push_pin,
                size: 16,
                color: _showOnlyPinned ? theme.colorScheme.onPrimary : diffColor,
              ),
              label: Text(
                pinnedCount > 0 ? 'Pinned Only ($pinnedCount)' : 'Pinned Only',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _showOnlyPinned ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                ),
              ),
              selected: _showOnlyPinned,
              selectedColor: diffColor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              checkmarkColor: theme.colorScheme.onPrimary,
              onSelected: (val) {
                HapticService.selectionTick(context);
                setState(() => _showOnlyPinned = val);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChips(ThemeData theme, List<DmReferenceItem> allItems) {
    final isDark = theme.brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All Rules', style: TextStyle(fontSize: 12)),
              selected: _selectedCategory == null,
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: _selectedCategory == null ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) {
                HapticService.selectionTick(context);
                setState(() => _selectedCategory = null);
              },
            ),
          ),
          ...DmCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            final catColor = cat.getLegibleColor(isDark);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : catColor),
                label: Text(cat.label, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: catColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (_) {
                  HapticService.selectionTick(context);
                  setState(() => _selectedCategory = cat);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSliverItemsGrid(
    BuildContext context,
    List<DmReferenceItem> items,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    return SliverResponsiveCardGrid<DmReferenceItem>(
      items: items,
      itemBuilder: (context, item) => DmRuleCard(
        item: item,
        edition: edition,
        isPinned: pinnedIds.contains(item.id),
        onTogglePin: () => _togglePinRule(context, item.id),
        onTap: () => _showCompareDialog(context, item),
        searchQuery: _searchQuery,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return EmptyStateCard(
      icon: Icons.search_off,
      title: 'No matching rules found',
      message: _showOnlyPinned
          ? 'No rules are pinned yet. Tap the pin icon on any rule card to pin it!'
          : 'Try clearing your search or removing the active filters.',
      actionLabel: 'Reset Filters',
      actionIcon: Icons.refresh,
      onAction: () {
        HapticService.selectionTick(context);
        _searchController.clear();
        setState(() {
          _searchQuery = '';
          _selectedCategory = null;
          _showOnlyChangedIn2024 = false;
          _showOnlyPinned = false;
        });
      },
    );
  }
}
