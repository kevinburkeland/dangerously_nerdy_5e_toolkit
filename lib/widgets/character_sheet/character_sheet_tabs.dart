import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/spellbook_data.dart';
import '../../providers/character_sheet_controller.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';
import 'features_traits_section.dart';
import 'interactive_roll_action_card.dart';
import 'interactive_spell_tile.dart';
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

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Section: Attacks
        Text(
          'EQUIPPED ATTACKS',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...stats.attackProfiles.map((atk) => InteractiveRollActionCard(
          attack: atk,
          characterName: character.name,
        )),

        const SizedBox(height: 16),

        // Section: Spellcasting & Save DCs
        if (stats.spellSaveDcs.isNotEmpty) ...[
          Text(
            'SPELLCASTING STATS',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...stats.spellSaveDcs.entries.map((entry) {
            final cls = entry.key;
            final dc = entry.value;
            final atkBonus = stats.spellAttackBonuses[cls] ?? (dc - 8);
            final atkStr = atkBonus >= 0 ? '+$atkBonus' : '$atkBonus';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cls,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Text('Save DC: ', style: theme.textTheme.labelSmall),
                      Text('$dc', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Text('Spell Atk: ', style: theme.textTheme.labelSmall),
                      Text(atkStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
        ],

        // Section: Spell Slots Matrix
        _buildSpellSlotsMatrix(context),

        // Section: Cantrips
        if (character.cantrips.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'CANTRIPS',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: character.cantrips.map((c) {
              return Chip(
                avatar: const Icon(Icons.auto_awesome, size: 14),
                label: Text(c.displayName),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }


  Widget _buildSpellSlotsMatrix(BuildContext context) {
    final theme = Theme.of(context);
    final pool = widget.controller.character.resources.spellSlots;
    final maxSlots = pool.maxSlots;
    final curSlots = pool.currentSlots;

    if (maxSlots.isEmpty && pool.pactMagicMax == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SPELL SLOTS',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(9, (index) {
            final level = index + 1;
            final max = maxSlots[level] ?? 0;
            if (max == 0) return const SizedBox.shrink();
            final current = curSlots[level] ?? max;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text('Lvl $level', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(max, (slotIdx) {
                      final isAvailable = slotIdx < current;
                      return InkWell(
                        onTap: () {
                          HapticService.selectionTick(context);
                          widget.controller.toggleSpellSlot(level, isAvailable);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            isAvailable ? Icons.circle : Icons.circle_outlined,
                            size: 14,
                            color: isAvailable ? theme.colorScheme.primary : Colors.grey,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
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
