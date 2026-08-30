import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../providers/character_sheet_controller.dart';
import '../../theme/app_theme.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/character_evaluation_engine.dart';

/// 3-Tab Content Area: Actions & Combat, Skills & Traits, and Inventory & Reliquary.
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
    _tabController = TabController(length: 3, vsync: this);
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
              Tab(icon: Icon(Icons.format_list_bulleted, size: 18), text: 'Skills'),
              Tab(icon: Icon(Icons.backpack_outlined, size: 18), text: 'Inventory'),
            ],
          ),
          const Divider(height: 1),
          // Tab Content
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActionsTab(context),
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
        ...stats.attackProfiles.map((atk) => _buildAttackCard(context, atk)),

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

  Widget _buildAttackCard(BuildContext context, ComputedAttackProfile atk) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  atk.weaponName,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${atk.range} • ${atk.damageType.name}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // To-Hit Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  atk.attackBonusString,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Damage Formula Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  atk.damageFormula,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: customColors?.critGold ?? Colors.amber,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
    final theme = Theme.of(context);
    final stats = widget.controller.stats;
    final character = widget.controller.character;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Passive Senses Bar
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPassiveItem('Perception', stats.passivePerception),
              _buildPassiveItem('Insight', stats.passiveInsight),
              _buildPassiveItem('Investigation', stats.passiveInvestigation),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Saving Throws Summary
        Text(
          'SAVING THROWS',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AbilityType.values.map((ability) {
            final mod = stats.savingThrowModifiers[ability] ?? 0;
            final isProf = character.savingThrowProficiencies.contains(ability);
            final modStr = mod >= 0 ? '+$mod' : '$mod';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isProf
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isProf ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isProf ? Icons.check_circle : Icons.circle_outlined,
                    size: 12,
                    color: isProf ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text('${ability.shortName}: ', style: theme.textTheme.labelSmall),
                  Text(
                    modStr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isProf ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // 18-Skill Matrix
        Text(
          'SKILLS (18)',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...SkillType.values.map((skill) {
          final mod = stats.skillModifiers[skill] ?? 0;
          final modStr = mod >= 0 ? '+$mod' : '$mod';
          final profLevel = character.skillProficiencies[skill] ?? SkillProficiencyLevel.none;

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: profLevel != SkillProficiencyLevel.none
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildProficiencyPip(profLevel),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    skill.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: profLevel != SkillProficiencyLevel.none
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  skill.defaultAbility.shortName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 32,
                  child: Text(
                    modStr,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: profLevel != SkillProficiencyLevel.none
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPassiveItem(String name, int val) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          'Passive $name',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$val',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProficiencyPip(SkillProficiencyLevel level) {
    final theme = Theme.of(context);
    switch (level) {
      case SkillProficiencyLevel.expertise:
        return const Icon(Icons.star, size: 14, color: Colors.amber);
      case SkillProficiencyLevel.proficient:
        return Icon(Icons.circle, size: 12, color: theme.colorScheme.primary);
      case SkillProficiencyLevel.jackOfAllTrades:
        return Icon(Icons.adjust, size: 12, color: theme.colorScheme.tertiary);
      case SkillProficiencyLevel.none:
        return const Icon(Icons.circle_outlined, size: 12, color: Colors.grey);
    }
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
                    final ok = await widget.controller.toggleAttuneItem(item.instanceId);
                    if (!ok && mounted) {
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
}
