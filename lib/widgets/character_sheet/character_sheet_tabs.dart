import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/action_economy_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/spellbook_data.dart';
import '../../providers/character_sheet_controller.dart';
import '../../screens/party_room_screen.dart';
import '../../services/party/campaign_registry_service.dart';
import '../../services/rules/character_actions_resolver.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';
import '../party/campaign_dialogs.dart';
import 'features_traits_section.dart';
import 'interactive_spell_tile.dart';
import 'languages_tools_section.dart';
import 'skills_saves_matrix.dart';

/// 4-Tab Content Area: Actions & Combat, Spells & Magic, Skills & Traits, and Inventory & Reliquary.
class CharacterSheetTabs extends StatefulWidget {
  final CharacterSheetController controller;

  const CharacterSheetTabs({
    super.key,
    required this.controller,
  });

  @override
  State<CharacterSheetTabs> createState() => _CharacterSheetTabsState();
}

class _CharacterSheetTabsState extends State<CharacterSheetTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Action Economy Round State
  bool _actionSpent = false;
  bool _bonusActionSpent = false;
  bool _reactionSpent = false;
  String _selectedActionCategory = 'all'; // 'all', 'action', 'bonusAction', 'reaction', 'special', 'standard'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab Bar Header
          TabBar(
            controller: _tabController,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(icon: Icon(Icons.sports_martial_arts, size: 18), text: 'Actions'),
              Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Spells'),
              Tab(icon: Icon(Icons.format_list_bulleted, size: 18), text: 'Skills'),
              Tab(icon: Icon(Icons.backpack_outlined, size: 18), text: 'Inventory'),
            ],
          ),
          const Divider(height: 1),
          // Tab Content
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActionsTab(context),
                _buildSpellsTab(context),
                _buildSkillsTab(context),
                _buildInventoryTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: ACTIONS & COMBAT
  // ==========================================
  Widget _buildActionsTab(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.controller.stats;
    final character = widget.controller.character;

    final resolved = CharacterActionsResolver.resolve(
      character: character,
      stats: stats,
      controller: widget.controller,
    );

    List<CharacterCombatAction> displayActions;
    if (_selectedActionCategory == 'action') {
      displayActions = resolved.actions;
    } else if (_selectedActionCategory == 'bonusAction') {
      displayActions = resolved.bonusActions;
    } else if (_selectedActionCategory == 'reaction') {
      displayActions = resolved.reactions;
    } else if (_selectedActionCategory == 'special') {
      displayActions = resolved.specialActions;
    } else if (_selectedActionCategory == 'standard') {
      displayActions = resolved.standardActions;
    } else {
      displayActions = resolved.allActions;
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Action Economy Quick Tracker Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.amberAccent),
                      const SizedBox(width: 6),
                      Text(
                        'ROUND ECONOMY',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Reset Turn', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      HapticService.selectionTick(context);
                      setState(() {
                        _actionSpent = false;
                        _bonusActionSpent = false;
                        _reactionSpent = false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildEconomyTrackerChip(
                      label: 'Action',
                      isSpent: _actionSpent,
                      color: Colors.redAccent,
                      onTap: () {
                        HapticService.selectionTick(context);
                        setState(() => _actionSpent = !_actionSpent);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildEconomyTrackerChip(
                      label: 'Bonus Action',
                      isSpent: _bonusActionSpent,
                      color: Colors.orangeAccent,
                      onTap: () {
                        HapticService.selectionTick(context);
                        setState(() => _bonusActionSpent = !_bonusActionSpent);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildEconomyTrackerChip(
                      label: 'Reaction',
                      isSpent: _reactionSpent,
                      color: Colors.blueAccent,
                      onTap: () {
                        HapticService.selectionTick(context);
                        setState(() => _reactionSpent = !_reactionSpent);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 2. Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('all', 'All (${resolved.allActions.length})'),
              const SizedBox(width: 6),
              _buildCategoryChip('action', 'Actions (${resolved.actions.length})'),
              const SizedBox(width: 6),
              _buildCategoryChip('bonusAction', 'Bonus Actions (${resolved.bonusActions.length})'),
              const SizedBox(width: 6),
              _buildCategoryChip('reaction', 'Reactions (${resolved.reactions.length})'),
              if (resolved.specialActions.isNotEmpty) ...[
                const SizedBox(width: 6),
                _buildCategoryChip('special', 'Special (${resolved.specialActions.length})'),
              ],
              const SizedBox(width: 6),
              _buildCategoryChip('standard', 'Rules (${resolved.standardActions.length})'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 3. Render Categorized Sections or Filtered Action List
        if (_selectedActionCategory == 'all') ...[
          if (resolved.actions.isNotEmpty) ...[
            _buildSectionHeader('ACTIONS (${resolved.actions.length})', Colors.redAccent),
            const SizedBox(height: 6),
            ...resolved.actions.map((a) => _buildCombatActionCard(context, a)),
            const SizedBox(height: 12),
          ],
          if (resolved.bonusActions.isNotEmpty) ...[
            _buildSectionHeader('BONUS ACTIONS (${resolved.bonusActions.length})', Colors.orangeAccent),
            const SizedBox(height: 6),
            ...resolved.bonusActions.map((a) => _buildCombatActionCard(context, a)),
            const SizedBox(height: 12),
          ],
          if (resolved.reactions.isNotEmpty) ...[
            _buildSectionHeader('REACTIONS (${resolved.reactions.length})', Colors.blueAccent),
            const SizedBox(height: 6),
            ...resolved.reactions.map((a) => _buildCombatActionCard(context, a)),
            const SizedBox(height: 12),
          ],
          if (resolved.specialActions.isNotEmpty) ...[
            _buildSectionHeader('SPECIAL & MAGIC ITEMS (${resolved.specialActions.length})', Colors.purpleAccent),
            const SizedBox(height: 6),
            ...resolved.specialActions.map((a) => _buildCombatActionCard(context, a)),
            const SizedBox(height: 12),
          ],
          if (resolved.standardActions.isNotEmpty) ...[
            _buildSectionHeader('STANDARD 5E COMBAT ACTIONS', Colors.white70),
            const SizedBox(height: 6),
            ...resolved.standardActions.map((a) => _buildCombatActionCard(context, a)),
          ],
        ] else ...[
          if (displayActions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No ${_selectedActionCategory.replaceAll("Action", " Action")}s available.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54),
                ),
              ),
            )
          else
            ...displayActions.map((a) => _buildCombatActionCard(context, a)),
        ],
      ],
    );
  }

  Widget _buildEconomyTrackerChip({
    required String label,
    required bool isSpent,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSpent
              ? Colors.black26
              : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSpent ? Colors.white24 : color,
            width: isSpent ? 1 : 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isSpent ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isSpent ? Colors.grey : color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSpent ? Colors.white38 : Colors.white,
                decoration: isSpent ? TextDecoration.lineThrough : null,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              isSpent ? 'Spent' : 'Ready',
              style: TextStyle(
                fontSize: 9,
                color: isSpent ? Colors.white38 : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String categoryId, String label) {
    final isSelected = _selectedActionCategory == categoryId;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticService.selectionTick(context);
          setState(() => _selectedActionCategory = categoryId);
        }
      },
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildCombatActionCard(BuildContext context, CharacterCombatAction action) {
    final theme = Theme.of(context);
    final typeColor = action.actionTypeColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: typeColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.actionTypeIcon, size: 12, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      action.actionTypeLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      action.subtitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (action.range != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    action.range!,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
            ],
          ),
          if (action.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              action.description,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.3),
            ),
          ],
          if (action.resourceCost != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.bolt, size: 12, color: Colors.amberAccent),
                const SizedBox(width: 4),
                Text(
                  'Cost: ${action.resourceCost}',
                  style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (action.onRollAttack != null || action.onRollDamage != null || action.onExecute != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (action.onRollAttack != null) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.sports_martial_arts, size: 14),
                    label: Text(
                      action.toHitBonus != null
                          ? 'Atk ${action.toHitBonus! >= 0 ? "+${action.toHitBonus}" : "${action.toHitBonus}"}'
                          : 'Attack',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => action.onRollAttack!(context),
                  ),
                  const SizedBox(width: 8),
                ],
                if (action.onRollDamage != null) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.local_fire_department, size: 14),
                    label: Text(
                      action.damageFormula ?? 'Damage',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => action.onRollDamage!(context),
                  ),
                  const SizedBox(width: 8),
                ],
                if (action.onExecute != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('Use Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => action.onExecute!(context),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }




  // ==========================================
  // TAB 2: SKILLS & TRAITS
  // ==========================================
  Widget _buildSkillsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Interactive Skills & Saves Matrix with Advantage/Disadvantage
        SkillsSavesMatrix(controller: widget.controller),
        const SizedBox(height: 18),

        // Languages Known & Tool Proficiencies Section
        LanguagesToolsSection(controller: widget.controller),
        const SizedBox(height: 18),

        // Features, Feats & Lineage Section
        FeaturesTraitsSection(controller: widget.controller),
      ],
    );
  }

  // ==========================================
  // TAB 3: INVENTORY & RELIQUARY
  // ==========================================
  Widget _buildInventoryTab(BuildContext context) {
    final theme = Theme.of(context);
    final stats = widget.controller.stats;
    final character = widget.controller.character;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Linked Campaign Badge
        Builder(
          builder: (context) {
            final registry = CampaignRegistryService();
            final memberships = registry.memberships;
            final linked = memberships.cast<CampaignMembership?>().firstWhere(
                  (m) => m?.characterId == character.id.slug || m?.characterId == character.name,
                  orElse: () => null,
                );

            if (linked == null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => JoinCampaignDialog.show(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_off, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Not linked to a campaign room. Tap to join.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        Text('Join', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PartyRoomScreen(roomCode: linked.roomCode)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 16, color: Colors.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LINKED TO CAMPAIGN',
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.teal, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            Text(
                              '${linked.campaignName} (${linked.roomCode})',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.teal),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Coin Purse Card
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 18, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Text(
                        'Coin Purse',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '~${character.purse.totalGpEquivalent.toStringAsFixed(1)} GP Total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildCoinPill('PP', character.purse.pp, const Color(0xFFCBD5E1), theme),
                  const SizedBox(width: 6),
                  _buildCoinPill('GP', character.purse.gp, const Color(0xFFEAB308), theme),
                  const SizedBox(width: 6),
                  _buildCoinPill('EP', character.purse.ep, const Color(0xFF94A3B8), theme),
                  const SizedBox(width: 6),
                  _buildCoinPill('SP', character.purse.sp, const Color(0xFF94A3B8), theme),
                  const SizedBox(width: 6),
                  _buildCoinPill('CP', character.purse.cp, const Color(0xFFB45309), theme),
                ],
              ),
            ],
          ),
        ),

        // Attunement Slot Meter
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: stats.attunedItemCount >= stats.effectiveMaxAttunementSlots
                  ? Colors.amber.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: stats.attunedItemCount > 0 ? Colors.amber : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Attunement Slots',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stats.attunedItemCount >= stats.effectiveMaxAttunementSlots
                      ? Colors.amber.withValues(alpha: 0.2)
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${stats.attunedItemCount} / ${stats.effectiveMaxAttunementSlots} Attuned',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: stats.attunedItemCount >= stats.effectiveMaxAttunementSlots
                        ? Colors.amber
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Active Buffs / Magical Properties Notes
        if (stats.activeBuffNotes.isNotEmpty) ...[
          Text(
            'ACTIVE GEAR MODIFIERS',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          ...stats.activeBuffNotes.map((note) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 12, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(note, style: theme.textTheme.bodySmall),
                  ],
                ),
              )),
          const SizedBox(height: 14),
        ],

        // Items List
        Text(
          'INVENTORY ITEMS (${character.inventory.length})',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),

        if (character.inventory.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Inventory is empty.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...character.inventory.map((item) => _buildInventoryItemCard(context, item)),
      ],
    );
  }

  Widget _buildCoinPill(String denom, int count, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              denom,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              '$count',
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItemCard(BuildContext context, InventoryItemInstance item) {
    final theme = Theme.of(context);
    final stats = widget.controller.stats;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.isEquipped
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isEquipped
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      item.isEquipped ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 16,
                      color: item.isEquipped ? theme.colorScheme.primary : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: item.isEquipped ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.quantity > 1)
                Text('x${item.quantity}', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 8),
          // Action Buttons: Equip & Attune
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Attune Button (if requires attunement)
              if (item.requiresAttunement) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: item.isAttuned ? Colors.amber : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  icon: Icon(
                    item.isAttuned ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                    size: 14,
                    color: item.isAttuned ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    item.isAttuned ? 'Attuned' : 'Attune',
                    style: TextStyle(
                      fontSize: 11,
                      color: item.isAttuned ? Colors.amber : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onPressed: () async {
                    HapticService.selectionTick(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await widget.controller.toggleAttuneItem(item.instanceId);
                    if (!mounted) return;
                    if (!ok) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Cannot attune: Character has reached maximum attunement limit (${stats.effectiveMaxAttunementSlots} items).',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.amber.shade900,
                        ),
                      );
                      _showAttunementLimitDialog(this.context, stats.effectiveMaxAttunementSlots);
                    }
                  },
                ),
                const SizedBox(width: 8),
              ],
              // Equip Toggle Button
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  HapticService.selectionTick(context);
                  widget.controller.toggleEquipItem(item.instanceId);
                },
                child: Text(
                  item.isEquipped ? 'Unequip' : 'Equip',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttunementLimitDialog(BuildContext context, int maxSlots) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attunement Limit Reached'),
        content: Text(
          'You are already attuned to the maximum of $maxSlots magic items. Unattune from an existing item before attuning to a new one.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB: SPELLS & MAGIC
  // ==========================================
  Widget _buildSpellsTab(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();
    final stats = widget.controller.stats;
    final character = widget.controller.character;
    final edition = character.id.ruleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;

    final pool = character.resources.spellSlots;
    final cantrips = character.cantrips;
    final knownSpells = character.spellsKnown;
    final prepSlugs = character.spellsPrepared.map((s) => s.slug).toSet();

    // Group leveled spells by level
    final spellsByLevel = <int, List<EntityReference<Spell>>>{};
    for (final s in knownSpells) {
      final spellItem = SpellbookLibrary.getSpellById(s.slug);
      final lvl = spellItem?.level ?? 1;
      spellsByLevel.putIfAbsent(lvl, () => []).add(s);
    }
    final sortedLevels = spellsByLevel.keys.toList()..sort();

    final hasAnySpells = cantrips.isNotEmpty || knownSpells.isNotEmpty || pool.maxSlots.isNotEmpty || pool.pactMagicMax > 0;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Spellcasting Header HUD
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade900.withValues(alpha: 0.35),
                Colors.indigo.shade900.withValues(alpha: 0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 18, color: Colors.purpleAccent),
                      const SizedBox(width: 8),
                      Text(
                        'SPELLCASTING VITALS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: customColors?.critGold ?? Colors.amber,
                    ),
                    icon: const Icon(Icons.bedtime, size: 14),
                    label: const Text('Long Rest', style: TextStyle(fontSize: 11)),
                    onPressed: () {
                      HapticService.heavyImpact(context);
                      widget.controller.restoreAllSpellSlots();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All spell slots restored to full!')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSpellStatPill(
                    theme,
                    label: 'SPELL ATK',
                    value: stats.spellAttackBonuses.isNotEmpty
                        ? '+${stats.spellAttackBonuses.values.first}'
                        : '+${stats.proficiencyBonus}',
                    color: Colors.cyanAccent,
                  ),
                  _buildSpellStatPill(
                    theme,
                    label: 'SAVE DC',
                    value: stats.spellSaveDcs.isNotEmpty
                        ? 'DC ${stats.spellSaveDcs.values.first}'
                        : 'DC ${8 + stats.proficiencyBonus}',
                    color: Colors.purpleAccent,
                  ),
                  _buildSpellStatPill(
                    theme,
                    label: 'PREPARED',
                    value: '${prepSlugs.length}',
                    color: Colors.amberAccent,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Spell Slots Matrix
        if (pool.maxSlots.isNotEmpty || pool.pactMagicMax > 0) ...[
          Text(
            'SPELL SLOTS & PACT MAGIC',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                // Pact Magic
                if (pool.pactMagicMax > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pact Magic (Level ${pool.pactMagicSlotLevel}):',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.purpleAccent),
                        ),
                      ),
                      Row(
                        children: List.generate(pool.pactMagicMax, (i) {
                          final isAvailable = i < pool.pactMagicCurrent;
                          return InkWell(
                            onTap: () {
                              HapticService.selectionTick(context);
                              widget.controller.togglePactSlot(isAvailable);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                isAvailable ? Icons.circle : Icons.circle_outlined,
                                size: 20,
                                color: isAvailable ? Colors.purpleAccent : Colors.white30,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  if (pool.maxSlots.isNotEmpty) const Divider(height: 16),
                ],
                // Standard Leveled Slots
                ...pool.maxSlots.entries.map((entry) {
                  final lvl = entry.key;
                  final max = entry.value;
                  final cur = pool.currentSlots[lvl] ?? max;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Level $lvl Slots ($cur / $max):',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        Row(
                          children: List.generate(max, (i) {
                            final isAvailable = i < cur;
                            return InkWell(
                              onTap: () {
                                HapticService.selectionTick(context);
                                widget.controller.toggleSpellSlot(lvl, isAvailable);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  isAvailable ? Icons.circle : Icons.circle_outlined,
                                  size: 18,
                                  color: isAvailable ? Colors.cyanAccent : Colors.white30,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 3. Cantrips (Level 0)
        if (cantrips.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CANTRIPS (${cantrips.length})',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.purpleAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...cantrips.map((c) => _buildSpellItemCard(context, c, isCantrip: true, edition: edition)),
          const SizedBox(height: 14),
        ],

        // 4. Leveled Spells (Grouped by Level)
        if (sortedLevels.isNotEmpty) ...[
          ...sortedLevels.map((lvl) {
            final spellsAtLevel = spellsByLevel[lvl]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEVEL $lvl SPELLS (${spellsAtLevel.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 8),
                ...spellsAtLevel.map((s) => _buildSpellItemCard(
                      context,
                      s,
                      isCantrip: false,
                      isPrepared: prepSlugs.contains(s.slug),
                      edition: edition,
                    )),
                const SizedBox(height: 14),
              ],
            );
          }),
        ],

        if (!hasAnySpells)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const Column(
              children: [
                Icon(Icons.auto_awesome, size: 40, color: Colors.white38),
                SizedBox(height: 10),
                Text(
                  'No Spells or Cantrips Recorded',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                SizedBox(height: 4),
                Text(
                  'Tap "Add / Prepare Spells" below to manage your spellbook.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        // 5. Add / Prepare Spells Action Button
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.purpleAccent.shade700,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add / Manage Spells', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _showAddSpellModal(context, edition),
        ),
      ],
    );
  }

  Widget _buildSpellStatPill(ThemeData theme, {required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSpellItemCard(
    BuildContext context,
    EntityReference<Spell> spellRef, {
    required bool isCantrip,
    bool isPrepared = false,
    required DmRulesEdition edition,
  }) {
    final spellItem = SpellbookLibrary.getSpellById(spellRef.slug);
    final spellName = spellItem?.getName(edition) ?? spellRef.displayName;
    final rules = spellItem?.getRules(edition);

    final domainSpell = spellItem != null
        ? Spell(
            id: EntityId(
              slug: spellItem.id,
              ruleset: edition == DmRulesEdition.v2024 ? RulesetVersion.v2024 : RulesetVersion.v2014,
            ),
            name: spellName,
            level: spellItem.level,
            school: (rules?.schoolOverride ?? spellItem.school).name,
            castingTime: CastingTime(
              cost: 1,
              actionType: ActionType.action,
              triggerCondition: rules?.castingTime ?? '1 Action',
            ),
            duration: SpellDuration(
              type: rules?.concentration == true
                  ? DurationType.special
                  : DurationType.instantaneous,
              requiresConcentration: rules?.concentration ?? false,
              rawText: rules?.duration,
            ),
            range: rules?.range ?? '30 ft',
            components: SpellComponents(
              v: rules?.components.contains('V') ?? false,
              s: rules?.components.contains('S') ?? false,
              m: rules?.components.contains('M') ?? false,
              materialDescription: rules?.materialDetails?.description,
            ),
            descriptionMarkdown: rules != null ? rules.description.join('\n\n') : spellRef.displayName,
            higherLevelsMarkdown: rules?.higherLevels,
            damageMath: (rules?.rollFormula != null &&
                    rules!.rollFormula!.trim().isNotEmpty &&
                    rules.rollFormula!.trim().toLowerCase() != 'none')
                ? [
                    EvaluationMath(
                      diceFormula: rules.rollFormula!,
                      damageType: DamageType.values.firstWhere(
                        (d) => d.name.toLowerCase() == (rules.damageOrHealType ?? '').toLowerCase(),
                        orElse: () => DamageType.untyped,
                      ),
                    )
                  ]
                : const [],
            customProperties: {
              if (rules?.rollFormula != null) 'rollFormula': rules!.rollFormula,
              if (rules?.ritual != null) 'ritual': rules!.ritual,
            },
          )
        : Spell(
            id: EntityId(slug: spellRef.slug, ruleset: RulesetVersion.v2024),
            name: spellRef.displayName,
            level: isCantrip ? 0 : 1,
            school: 'evocation',
            castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
            duration: const SpellDuration(type: DurationType.instantaneous),
            range: '30 ft',
            components: const SpellComponents(),
            descriptionMarkdown: spellRef.displayName,
          );

    return InteractiveSpellTile(
      spell: domainSpell,
      controller: widget.controller,
      isCantrip: isCantrip,
      isPrepared: isPrepared,
      onTogglePrepared: isCantrip
          ? null
          : () {
              HapticService.selectionTick(context);
              widget.controller.togglePreparedSpell(spellRef);
            },
      trailingExtra: Semantics(
        button: true,
        label: 'More options for $spellName',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (action) {
              if (action == 'cast_slot') {
                HapticService.heavyImpact(context);
                final lvl = spellItem?.level ?? 1;
                widget.controller.toggleSpellSlot(lvl, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cast $spellName (Expended Level $lvl slot)')),
                );
              } else if (action == 'remove') {
                HapticService.selectionTick(context);
                widget.controller.removeSpell(spellRef, isCantrip: isCantrip);
              }
            },
            itemBuilder: (ctx) => [
              if (!isCantrip)
                const PopupMenuItem(
                  value: 'cast_slot',
                  child: Text('Cast & Expend Slot'),
                ),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove from Sheet', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSpellModal(BuildContext context, DmRulesEdition edition) {
    String searchQuery = '';
    int filterLevel = -1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final allSpells = SpellbookLibrary.allSpells.where((s) {
              if (filterLevel >= 0 && s.level != filterLevel) return false;
              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                return s.getName(edition).toLowerCase().contains(q) ||
                    s.id.toLowerCase().contains(q);
              }
              return true;
            }).toList();

            final existingCantripSlugs = widget.controller.character.cantrips.map((c) => c.slug).toSet();
            final existingKnownSlugs = widget.controller.character.spellsKnown.map((s) => s.slug).toSet();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Spell to Character Sheet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purpleAccent),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search Spells',
                            prefixIcon: Icon(Icons.search, size: 18),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setModalState(() => searchQuery = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: filterLevel,
                        items: const [
                          DropdownMenuItem(value: -1, child: Text('All Levels')),
                          DropdownMenuItem(value: 0, child: Text('Cantrip')),
                          DropdownMenuItem(value: 1, child: Text('1st Level')),
                          DropdownMenuItem(value: 2, child: Text('2nd Level')),
                          DropdownMenuItem(value: 3, child: Text('3rd Level')),
                          DropdownMenuItem(value: 4, child: Text('4th Level')),
                          DropdownMenuItem(value: 5, child: Text('5th Level')),
                        ],
                        onChanged: (v) => setModalState(() => filterLevel = v ?? -1),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: allSpells.length,
                      itemBuilder: (listCtx, idx) {
                        final spell = allSpells[idx];
                        final isCantrip = spell.level == 0;
                        final isAlreadyAdded = isCantrip
                            ? existingCantripSlugs.contains(spell.id)
                            : existingKnownSlugs.contains(spell.id);

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isCantrip ? Icons.star : Icons.auto_awesome,
                            color: isCantrip ? Colors.purpleAccent : Colors.cyanAccent,
                            size: 18,
                          ),
                          title: Text(spell.getName(edition), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${spell.levelLabel} • ${spell.school.name}'),
                          trailing: isAlreadyAdded
                              ? const Chip(
                                  label: Text('Added', style: TextStyle(fontSize: 10)),
                                  visualDensity: VisualDensity.compact,
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: Colors.purpleAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    HapticService.selectionTick(context);
                                    final spellRef = EntityReference<Spell>(
                                      refType: EntityType.spell,
                                      slug: spell.id,
                                      displayName: spell.getName(edition),
                                    );
                                    widget.controller.addSpell(
                                      spellRef,
                                      isCantrip: isCantrip,
                                      isPrepared: !isCantrip,
                                    );
                                    setModalState(() {});
                                  },
                                  child: const Text('Add'),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
