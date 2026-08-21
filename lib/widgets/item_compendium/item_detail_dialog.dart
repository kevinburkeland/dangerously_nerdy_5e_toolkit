import 'package:flutter/material.dart';
import '../../models/magic_items/magic_item_data.dart';
import '../../services/haptic_service.dart';
import '../common/diff_highlight_banner.dart';
import '../dm_reference/rules_edition_toggle.dart';
import '../glyphs/dnd_glyph.dart';

/// Modal dialog showing full magic item details, properties, action traits, attunement rules,
/// and complete 5e (2014 & 2024) downtime crafting parameters across dedicated tabs.
class ItemDetailDialog extends StatefulWidget {
  final MagicItem item;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final int initialTabIndex;

  const ItemDetailDialog({
    super.key,
    required this.item,
    this.edition = DmRulesEdition.v2024,
    required this.isPinned,
    required this.onTogglePin,
    this.initialTabIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required MagicItem item,
    DmRulesEdition edition = DmRulesEdition.v2024,
    required bool isPinned,
    required VoidCallback onTogglePin,
    int initialTabIndex = 0,
  }) {
    HapticService.lightImpact(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => ItemDetailDialog(
        item: item,
        edition: edition,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  State<ItemDetailDialog> createState() => _ItemDetailDialogState();
}

class _ItemDetailDialogState extends State<ItemDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DmRulesEdition _activeEdition;
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    _activeEdition = widget.edition;
    _pinned = widget.isPinned;
    final tabCount = widget.item.isChangedIn2024 ? 3 : 2;
    final initialIndex = widget.initialTabIndex.clamp(0, tabCount - 1);
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticService.selectionTick(context);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _togglePin() {
    setState(() {
      _pinned = !_pinned;
    });
    widget.onTogglePin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;
    final rules = item.getRules(_activeEdition);
    final rarityColor = item.rarity.getLegibleColor(isDark);
    final categoryColor = item.category.getLegibleColor(isDark);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;
    final goldColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    final crafting = item.getCraftingDetails(_activeEdition);
    final hasDiff = item.isChangedIn2024;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0D111D) : theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: rarityColor.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 780),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Glyph HUD + Title + Category & Rarity + Pin & Close
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DndGlyph.item(
                  category: item.category,
                  rarity: item.rarity,
                  requiresAttunement: item.requiresAttunement,
                  damageAccent: item.getGlyphPrimaryDamageAccent(_activeEdition),
                  actionRings: item.getGlyphActionRings(_activeEdition),
                  glyphColor: item.effectiveGlyphColor,
                  size: 56,
                  isDarkMode: isDark,
                  isActive: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.getName(_activeEdition),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.category.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: categoryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('•', style: TextStyle(color: theme.colorScheme.outlineVariant)),
                          Text(
                            item.rarity.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: rarityColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('•', style: TextStyle(color: theme.colorScheme.outlineVariant)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: goldColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: goldColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.monetization_on_outlined, size: 12, color: goldColor),
                                const SizedBox(width: 3),
                                Text(
                                  item.getEffectivePrice(_activeEdition),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: goldColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _pinned ? Icons.bookmark : Icons.bookmark_border,
                    color: _pinned ? pinColor : theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  tooltip: _pinned
                      ? 'Remove from Personal Reliquary'
                      : 'Pin to Personal Reliquary',
                  onPressed: _togglePin,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  const Tab(
                    icon: Icon(Icons.menu_book_outlined, size: 17),
                    text: 'Rules & Traits',
                  ),
                  const Tab(
                    icon: Icon(Icons.handyman_outlined, size: 17),
                    text: 'Crafting Rules',
                  ),
                  if (hasDiff)
                    const Tab(
                      icon: Icon(Icons.compare_arrows, size: 17),
                      text: '2024 Diffs',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRulesTab(context, item, rules, isDark, rarityColor, categoryColor, goldColor),
                  _buildCraftingTab(context, item, crafting, isDark, rarityColor, goldColor),
                  if (hasDiff)
                    _buildDiffsTab(context, item, isDark, rarityColor),
                ],
              ),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Bottom Action Bar: Edition Switcher + Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RulesEditionToggle(
                  currentEdition: _activeEdition,
                  onEditionChanged: (newEdition) {
                    setState(() => _activeEdition = newEdition);
                  },
                  isDense: true,
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _togglePin,
                      icon: Icon(
                        _pinned ? Icons.bookmark_remove : Icons.bookmark_add,
                        size: 16,
                        color: _pinned ? pinColor : null,
                      ),
                      label: Text(
                        _pinned ? 'In Reliquary' : 'Pin Item',
                        style: TextStyle(color: _pinned ? pinColor : null, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesTab(
    BuildContext context,
    MagicItem item,
    ItemEditionDetails rules,
    bool isDark,
    Color rarityColor,
    Color categoryColor,
    Color goldColor,
  ) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Highlights Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _buildDetailRow('Market Price', item.getEffectivePrice(_activeEdition), color: goldColor),
                _buildDetailRow('Category', item.category.displayName, color: categoryColor),
                _buildDetailRow('Rarity', item.rarity.displayName, color: rarityColor),
                _buildDetailRow(
                  'Attunement',
                  item.getAttunementLabel(),
                  color: item.requiresAttunement
                      ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                      : null,
                ),
                if (rules.activation != null)
                  _buildDetailRow('Activation', rules.activation!),
                if (rules.charges != null)
                  _buildDetailRow('Charges', rules.charges!),
                if (rules.savingThrowDc != null)
                  _buildDetailRow('Save DC', rules.savingThrowDc!),
                if (rules.masteryProperties != null)
                  _buildDetailRow('Weapon Mastery', rules.masteryProperties!),
                if (item.damageAccent != null)
                  _buildDetailRow(
                    'Damage Accent',
                    item.damageAccent!.displayName,
                    color: item.damageAccent!.color,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Properties summary bullet points
          if (rules.properties.isNotEmpty) ...[
            Text(
              'Item Properties',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: rules.properties.map((prop) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    prop,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Rules & Mechanics Description
          Text(
            'Rules & Description',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rules.description,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),

          // Action Trait Rings
          if (item.actionRings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Action Traits & HUD Rings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...item.actionRings.map((ring) {
              final ringColor = ring.getEffectiveColor(rarityColor);
              final label = ring.label ??
                  (ring.damageLegend.isNotEmpty
                      ? '${ring.ringType.displayName} (${ring.damageLegend})'
                      : ring.ringType.displayName);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ringColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${ring.ringType.displayName}: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: ringColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        label,
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
    );
  }

  Widget _buildCraftingTab(
    BuildContext context,
    MagicItem item,
    ItemCraftingDetails crafting,
    bool isDark,
    Color rarityColor,
    Color goldColor,
  ) {
    final theme = Theme.of(context);
    final accentCyan = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final is2024 = _activeEdition == DmRulesEdition.v2024;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crafting Quick Summary Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  goldColor.withValues(alpha: 0.15),
                  rarityColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: goldColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.handyman_outlined, color: goldColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Downtime Crafting Requirements (${_activeEdition.label} Rules)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: goldColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        crafting.quickSummary,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Primary Crafting Grid
          _buildCraftingCard(
            context,
            title: 'Tools & Material Cost',
            icon: Icons.construction,
            iconColor: Colors.orangeAccent,
            children: [
              _buildDetailRow('Primary Tool', crafting.primaryTool, color: Colors.amber),
              if (crafting.alternativeTools.isNotEmpty)
                _buildDetailRow('Alternate Tools', crafting.alternativeTools.join(', ')),
              _buildDetailRow('Raw Materials Cost', crafting.goldCostDisplay, color: goldColor),
              if (crafting.isConsumable)
                _buildDetailRow('Consumable Item', 'Half crafting time & gold cost (Potions/Scrolls/Ammo)', color: Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 10),

          // Time & Character Requirements Card
          _buildCraftingCard(
            context,
            title: 'Downtime & Level Requirements',
            icon: Icons.schedule,
            iconColor: accentCyan,
            children: [
              _buildDetailRow(
                '2024 Crafting Time',
                crafting.craftingTime2024Display,
                color: is2024 ? accentCyan : null,
              ),
              _buildDetailRow(
                '2014 Crafting Time',
                crafting.craftingTime2014Display,
                color: !is2024 ? accentCyan : null,
              ),
              _buildDetailRow(
                'Minimum Character Level',
                crafting.minimumCharacterLevel != null
                    ? '${crafting.minimumCharacterLevel}th Level'
                    : 'None (Tool Proficiency required)',
              ),
              _buildDetailRow('Formula / Schematic', crafting.formulaRequired ? 'Arcane Formula Required' : 'Standard Recipe / Blueprint'),
              _buildDetailRow('2024 Bastion Facility', crafting.bastionFacility, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 10),

          // Monster CR & Planar Harvest Card
          _buildCraftingCard(
            context,
            title: 'Exotic Reagents & Creature Harvest',
            icon: Icons.biotech_outlined,
            iconColor: Colors.purpleAccent,
            children: [
              _buildDetailRow('Creature / Harvest CR', crafting.exoticIngredientCr, color: Colors.purpleAccent),
              if (crafting.prerequisiteSpells.isNotEmpty)
                _buildDetailRow(
                  'Prerequisite Spells',
                  'Must cast ${crafting.prerequisiteSpells.join(", ")} daily during crafting',
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Special Crafting Rules Bullet Points
          if (crafting.specialNotes.isNotEmpty) ...[
            Text(
              'Crafting Notes & Guidelines',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            ...crafting.specialNotes.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Icon(Icons.arrow_right, size: 16, color: goldColor),
                      ),
                      Expanded(
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffsTab(
    BuildContext context,
    MagicItem item,
    bool isDark,
    Color rarityColor,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.diffSummary != null || item.diffHighlights.isNotEmpty)
            DiffHighlightBanner(
              diffSummary: item.diffSummary,
              diffHighlights: item.diffHighlights,
            ),
          const SizedBox(height: 14),
          _buildEditionComparisonSection(
            context,
            '2024 Revised Rules',
            item.rules2024,
            Colors.amber,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildEditionComparisonSection(
            context,
            '2014 RAW Rules',
            item.rules2014,
            Colors.blueGrey,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildEditionComparisonSection(
    BuildContext context,
    String title,
    ItemEditionDetails editionRules,
    Color color,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (editionRules.activation != null)
            _buildDetailRow('Activation', editionRules.activation!),
          if (editionRules.charges != null)
            _buildDetailRow('Charges', editionRules.charges!),
          if (editionRules.masteryProperties != null)
            _buildDetailRow('Weapon Mastery', editionRules.masteryProperties!),
          const SizedBox(height: 6),
          Text(
            editionRules.description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCraftingCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
                color: color,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

