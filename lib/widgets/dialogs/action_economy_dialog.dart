import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../dm_reference/rules_edition_toggle.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';

class ActionEconomyDialog extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ActionEconomyDialog({super.key, this.initialEdition});

  static void show(BuildContext context, {DmRulesEdition? edition}) {
    showDialog(
      context: context,
      builder: (ctx) => ActionEconomyDialog(initialEdition: edition),
    );
  }

  @override
  State<ActionEconomyDialog> createState() => _ActionEconomyDialogState();
}

class _ActionEconomyDialogState extends State<ActionEconomyDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DmRulesEdition? _localEditionOverride;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;

    final standardActions = DmScreenLibrary.standardActions(edition);
    final bonusActions = DmScreenLibrary.bonusActions(edition);
    final reactions = DmScreenLibrary.reactions;
    final coverRules = DmScreenLibrary.coverRules;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.flash_on, color: primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        '5e Combat Action Economy',
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: RulesEditionToggle(
                      currentEdition: edition,
                      isDense: true,
                      onEditionChanged: (newEdition) {
                        setState(() => _localEditionOverride = newEdition);
                        settingsProvider?.setRulesEdition(newEdition);
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                    tooltip: 'Close dialog',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search actions (e.g., Dodge, Cover, Grapple, Potion)...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12),
                  prefixIcon: Icon(Icons.search, color: primary, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF252236) : theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: primary,
              labelColor: primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(
                  icon: RepaintBoundary(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: DndGlyph.genericUi(
                          uiType: GenericUiGlyphType.actionEconomyAction,
                          size: 18,
                          isDarkMode: isDark,
                        ),
                      ),
                    ),
                  ),
                  text: '1 Action (Standard)',
                ),
                Tab(
                  icon: RepaintBoundary(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: DndGlyph.genericUi(
                          uiType: GenericUiGlyphType.actionEconomyBonus,
                          size: 18,
                          isDarkMode: isDark,
                        ),
                      ),
                    ),
                  ),
                  text: 'Bonus Action',
                ),
                Tab(
                  icon: RepaintBoundary(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: DndGlyph.genericUi(
                          uiType: GenericUiGlyphType.actionEconomyReaction,
                          size: 18,
                          isDarkMode: isDark,
                        ),
                      ),
                    ),
                  ),
                  text: 'Reaction',
                ),
                Tab(
                  icon: RepaintBoundary(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: DndGlyph.item(
                          category: ItemCategory.armor,
                          rarity: ItemRarity.common,
                          size: 18,
                          isDarkMode: isDark,
                        ),
                      ),
                    ),
                  ),
                  text: 'Cover Rules',
                ),
              ],
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(standardActions, edition),
                  _buildList(bonusActions, edition),
                  _buildList(reactions, edition),
                  _buildList(coverRules, edition),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<DmReferenceItem> items, DmRulesEdition edition) {
    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>();
    final isDark = theme.brightness == Brightness.dark;

    final filtered = items.where((i) {
      if (_searchQuery.isEmpty) return true;
      return i.matches(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No matching combat actions found.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final itemColor = item.getLegibleColor(isDark);
        final title = item.getTitle(edition);
        final cost = item.getCost(edition) ?? item.cost ?? '';
        final rules = item.getRules(edition);
        final desc = rules.isNotEmpty ? rules.join(' ') : item.summary;

        return Card(
          color: tabletop?.cardBackground ?? (isDark ? const Color(0xFF252236) : theme.colorScheme.surfaceContainerHighest),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: itemColor.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: itemColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          if (cost.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: itemColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cost,
                                style: TextStyle(color: itemColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
