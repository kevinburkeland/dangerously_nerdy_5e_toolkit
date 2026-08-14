import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../providers/settings_provider.dart';
import '../services/a11y_service.dart';
import '../services/haptic_service.dart';
import '../utils/secure_random.dart';
import '../widgets/dm_reference/dm_rule_card.dart';
import '../widgets/dm_reference/dm_rule_comparison_dialog.dart';

class DmReferenceScreen extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const DmReferenceScreen({
    super.key,
    this.initialEdition,
  });

  @override
  State<DmReferenceScreen> createState() => _DmReferenceScreenState();
}

class _DmReferenceScreenState extends State<DmReferenceScreen> {
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
            const Icon(Icons.shield_outlined, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  "DM's Screen",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditionButton(
                  label: '2014',
                  edition: DmRulesEdition.v2014,
                  isActive: edition == DmRulesEdition.v2014,
                ),
                _buildEditionButton(
                  label: '2024',
                  edition: DmRulesEdition.v2024,
                  isActive: edition == DmRulesEdition.v2024,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBanner(theme, edition),
                  const SizedBox(height: 14),
                  _buildQuickRollBar(theme),
                  const SizedBox(height: 16),
                  _buildSearchAndFilters(theme, pinnedIds.length),
                  const SizedBox(height: 16),
                  _buildCategoryChips(theme),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                  if (pinnedFilteredItems.isNotEmpty) ...[
                    _buildPinnedSectionHeader(theme, pinnedFilteredItems.length),
                    const SizedBox(height: 10),
                    _buildItemsGrid(context, pinnedFilteredItems, edition, pinnedIds),
                    const SizedBox(height: 24),
                  ],

                  if (otherFilteredItems.isNotEmpty) ...[
                    if (pinnedFilteredItems.isNotEmpty) ...[
                      _buildSectionHeader(
                        theme,
                        _selectedCategory != null
                            ? _selectedCategory!.label.toUpperCase()
                            : 'ALL RULES (${otherFilteredItems.length})',
                      ),
                      const SizedBox(height: 10),
                    ],
                    _buildItemsGrid(context, otherFilteredItems, edition, pinnedIds),
                  ],

                  if (filteredItems.isEmpty)
                    _buildEmptyState(theme),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedSectionHeader(ThemeData theme, int count) {
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
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.push_pin, color: Colors.amber, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'PINNED RULES ($count)',
                style: const TextStyle(
                  color: Colors.amber,
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
              foregroundColor: Colors.white60,
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

  Widget _buildEditionButton({
    required String label,
    required DmRulesEdition edition,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label Edition Rules',
      child: InkWell(
        onTap: () => _onEditionChanged(context, edition),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(ThemeData theme, DmRulesEdition edition) {
    final is2024 = edition == DmRulesEdition.v2024;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: is2024 ? Colors.cyanAccent.withValues(alpha: 0.35) : Colors.amber.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: is2024 ? Colors.cyanAccent.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              is2024 ? Icons.auto_awesome : Icons.menu_book,
              color: is2024 ? Colors.cyanAccent : Colors.amber,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: is2024 ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        is2024 ? 'Revised' : 'Legacy',
                        style: TextStyle(
                          color: is2024 ? Colors.cyanAccent : Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  is2024
                      ? 'Displaying updated 2024 rules: standardized Unarmed Strike save DCs, -2 Exhaustion per level, Bonus Action potions, and Disadvantage Initiative for surprise.'
                      : 'Displaying classic 2014 rules: contested Athletics for grapple/shove, 6-tier Exhaustion, full Action potions, and round 1 surprise turn skips.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 12,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.casino_outlined, color: Colors.amber, size: 18),
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
          _buildDiceButton('d20', () => _performQuickRoll(20, 'd20')),
          _buildDiceButton('d100', () => _performQuickRoll(100, 'd100')),
          _buildDiceButton('d6', () => _performQuickRoll(6, 'd6')),
          _buildDiceButton('d8', () => _performQuickRoll(8, 'd8')),
          _buildDiceButton('d12', () => _performQuickRoll(12, 'd12')),
          if (_lastQuickRollLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _lastQuickRollLabel!,
                    style: const TextStyle(
                      color: Colors.amber,
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

  Widget _buildDiceButton(String label, VoidCallback onTap) {
    return Semantics(
      button: true,
      label: 'Quick roll $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2E2A44),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme, int pinnedCount) {
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
                    color: _searchQuery.isNotEmpty ? theme.colorScheme.primary : Colors.white12,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search actions, conditions, cover, DCs, resting...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              HapticService.selectionTick(context);
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              avatar: Icon(
                Icons.auto_awesome,
                size: 16,
                color: _showOnlyChangedIn2024 ? Colors.black : Colors.amber,
              ),
              label: Text(
                'Show Only 2024 Rule Changes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _showOnlyChangedIn2024 ? Colors.black : theme.colorScheme.onSurface,
                ),
              ),
              selected: _showOnlyChangedIn2024,
              selectedColor: Colors.amber,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              checkmarkColor: Colors.black,
              onSelected: (val) {
                HapticService.selectionTick(context);
                setState(() => _showOnlyChangedIn2024 = val);
              },
            ),
            FilterChip(
              avatar: Icon(
                Icons.push_pin,
                size: 16,
                color: _showOnlyPinned ? Colors.black : Colors.amber,
              ),
              label: Text(
                pinnedCount > 0 ? 'Pinned Only ($pinnedCount)' : 'Pinned Only',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _showOnlyPinned ? Colors.black : theme.colorScheme.onSurface,
                ),
              ),
              selected: _showOnlyPinned,
              selectedColor: Colors.amber,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              checkmarkColor: Colors.black,
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

  Widget _buildCategoryChips(ThemeData theme) {
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
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.black : cat.color),
                label: Text(cat.label, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                selectedColor: cat.color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.black : theme.colorScheme.onSurface,
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

  Widget _buildItemsGrid(
    BuildContext context,
    List<DmReferenceItem> items,
    DmRulesEdition edition,
    Set<String> pinnedIds,
  ) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1000 ? 3 : (width > 650 ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 14)) / crossAxisCount;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: items
              .map((item) => SizedBox(
                    width: itemWidth,
                    child: DmRuleCard(
                      item: item,
                      edition: edition,
                      isPinned: pinnedIds.contains(item.id),
                      onTogglePin: () => _togglePinRule(context, item.id),
                      onTap: () => _showCompareDialog(context, item),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No matching rules found',
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _showOnlyPinned
                ? 'No rules are pinned yet. Tap the pin icon on any rule card to pin it!'
                : 'Try clearing your search or removing the active filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            onPressed: () {
              HapticService.selectionTick(context);
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategory = null;
                _showOnlyChangedIn2024 = false;
                _showOnlyPinned = false;
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }
}
