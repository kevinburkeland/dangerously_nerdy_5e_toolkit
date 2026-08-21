import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/dpr/dpr_models.dart';
import '../../services/haptic_service.dart';
import '../common/numeric_stepper.dart';

/// Interactive card component for configuring a single weapon attack or cantrip action.
class DprAttackEditorCard extends StatelessWidget {
  final DprAttackAction attack;
  final int index;
  final int totalAttacks;
  final int abilityModifier;
  final int proficiencyBonus;
  final bool anythingGoesMode;
  final DmRulesEdition edition;
  final ValueChanged<DprAttackAction> onUpdate;
  final VoidCallback onEquipPreset;
  final VoidCallback? onDelete;

  const DprAttackEditorCard({
    super.key,
    required this.attack,
    required this.index,
    required this.totalAttacks,
    required this.abilityModifier,
    required this.proficiencyBonus,
    required this.anythingGoesMode,
    required this.edition,
    required this.onUpdate,
    required this.onEquipPreset,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final is2024 = edition == DmRulesEdition.v2024;
    final damageTypeLower = attack.damageType.toLowerCase();

    Color auraColor = Colors.cyanAccent;
    if (damageTypeLower.contains('fire')) {
      auraColor = const Color(0xFFFF5722);
    } else if (damageTypeLower.contains('cold')) {
      auraColor = const Color(0xFF00E5FF);
    } else if (damageTypeLower.contains('radiant') || damageTypeLower.contains('holy')) {
      auraColor = const Color(0xFFFFC107);
    } else if (damageTypeLower.contains('necrotic')) {
      auraColor = const Color(0xFFA855F7);
    } else if (damageTypeLower.contains('force')) {
      auraColor = const Color(0xFFE040FB);
    } else if (damageTypeLower.contains('lightning') || damageTypeLower.contains('thunder')) {
      auraColor = const Color(0xFF38BDF8);
    } else if (damageTypeLower.contains('poison') || damageTypeLower.contains('acid')) {
      auraColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161327) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: auraColor.withValues(alpha: isDark ? 0.35 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: auraColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Equip Preset Weapon / Cantrip / Magic Item Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Equip Weapon / Cantrip', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: onEquipPreset,
                ),
              ),
              if (totalAttacks > 1 && onDelete != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    onDelete!();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Custom Weapon/Cantrip Name Free-Form Text Field
          TextFormField(
            key: ValueKey('${attack.id}_${attack.name}'),
            initialValue: attack.name,
            decoration: InputDecoration(
              labelText: 'Attack / Weapon / Cantrip Name',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            onChanged: (text) => onUpdate(attack.copyWith(name: text)),
          ),
          const SizedBox(height: 10),

          // Attack Bonus & Primary Damage Dice Inputs
          Row(
            children: [
              // To-Hit Bonus
              Expanded(
                child: NumericStepper(
                  label: 'To-Hit',
                  value: attack.attackBonus,
                  display: attack.attackBonus >= 0 ? '+${attack.attackBonus}' : '${attack.attackBonus}',
                  onChanged: (val) => onUpdate(attack.copyWith(attackBonus: val)),
                ),
              ),
              const SizedBox(width: 8),

              // Dice Count & Sides
              Expanded(
                child: NumericStepper(
                  label: 'Dice Count',
                  value: attack.diceCount,
                  min: 0,
                  max: 10,
                  onChanged: (val) => onUpdate(attack.copyWith(diceCount: val)),
                ),
              ),
              const SizedBox(width: 8),

              // Die Sides (d4, d6, d8, d10, d12)
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('${attack.id}_${attack.diceSides}'),
                  initialValue: attack.diceSides > 0 ? attack.diceSides : 6,
                  decoration: InputDecoration(
                    labelText: 'Die',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [4, 6, 8, 10, 12, 20].map((sides) {
                    return DropdownMenuItem(
                      value: sides,
                      child: Text('d$sides', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      onUpdate(attack.copyWith(diceSides: val));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Flat Damage Bonus
              Expanded(
                child: NumericStepper(
                  label: 'Dmg Mod',
                  value: attack.damageBonus,
                  display: attack.damageBonus >= 0 ? '+${attack.damageBonus}' : '${attack.damageBonus}',
                  onChanged: (val) => onUpdate(attack.copyWith(damageBonus: val)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Secondary / Rider Damage (Smite, Hunter's Mark, Flame Tongue, Poison)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: NumericStepper(
                  label: 'Rider Dice',
                  value: attack.secondaryDiceCount,
                  min: 0,
                  max: 10,
                  onChanged: (val) => onUpdate(attack.copyWith(secondaryDiceCount: val)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('${attack.id}_sec_${attack.secondaryDiceSides}'),
                  initialValue: attack.secondaryDiceSides > 0 ? attack.secondaryDiceSides : 6,
                  decoration: InputDecoration(
                    labelText: 'Rider Die',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [4, 6, 8, 10, 12].map((sides) {
                    return DropdownMenuItem(
                      value: sides,
                      child: Text('d$sides', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      onUpdate(attack.copyWith(secondaryDiceSides: val));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('${attack.id}_sec_type'),
                  initialValue: attack.secondaryDamageType ?? '',
                  decoration: InputDecoration(
                    labelText: 'Rider Type (Fire, Radiant...)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (text) => onUpdate(attack.copyWith(secondaryDamageType: text)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Attacks per round counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attacks with this weapon:', style: TextStyle(fontSize: 12)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: attack.attacksPerRound > 1
                        ? () => onUpdate(attack.copyWith(attacksPerRound: attack.attacksPerRound - 1))
                        : null,
                  ),
                  Text('${attack.attacksPerRound}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: attack.attacksPerRound < 8
                        ? () => onUpdate(attack.copyWith(attacksPerRound: attack.attacksPerRound + 1))
                        : null,
                  ),
                ],
              ),
            ],
          ),

          // Modifiers & Style Chips Wrap
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // GWM 2014 Power Attack (-5/+10)
              if (anythingGoesMode || !is2024)
                FilterChip(
                  label: const Text('GWM 2014 (-5/+10)', style: TextStyle(fontSize: 11)),
                  selected: attack.gwmMode == GwmMode.v2014PowerAttack,
                  selectedColor: Colors.amber.withValues(alpha: 0.25),
                  onSelected: (val) {
                    onUpdate(attack.copyWith(
                      gwmMode: val ? GwmMode.v2014PowerAttack : GwmMode.none,
                    ));
                  },
                ),

              // GWM 2024 (+PB flat damage on hit)
              if (anythingGoesMode || is2024)
                FilterChip(
                  label: Text('GWM 2024 (+$proficiencyBonus dmg)', style: const TextStyle(fontSize: 11)),
                  selected: attack.gwmMode == GwmMode.v2024ProficiencyBonus,
                  selectedColor: Colors.cyan.withValues(alpha: 0.25),
                  onSelected: (val) {
                    onUpdate(attack.copyWith(
                      gwmMode: val ? GwmMode.v2024ProficiencyBonus : GwmMode.none,
                    ));
                  },
                ),

              // GWF Style 2014 (Reroll 1s & 2s)
              if (anythingGoesMode || !is2024)
                FilterChip(
                  label: const Text('GWF 2014 (Reroll 1s & 2s)', style: TextStyle(fontSize: 11)),
                  selected: attack.gwfVersion == GwfVersion.v2014Reroll,
                  selectedColor: Colors.amber.withValues(alpha: 0.25),
                  onSelected: (val) {
                    onUpdate(attack.copyWith(
                      gwfVersion: val ? GwfVersion.v2014Reroll : GwfVersion.none,
                    ));
                  },
                ),

              // GWF Style 2024 (1s & 2s ➔ 3)
              if (anythingGoesMode || is2024)
                FilterChip(
                  label: const Text('GWF 2024 (1s & 2s ➔ 3)', style: TextStyle(fontSize: 11)),
                  selected: attack.gwfVersion == GwfVersion.v2024Floor3,
                  selectedColor: Colors.cyan.withValues(alpha: 0.25),
                  onSelected: (val) {
                    onUpdate(attack.copyWith(
                      gwfVersion: val ? GwfVersion.v2024Floor3 : GwfVersion.none,
                    ));
                  },
                ),

              // Dueling (+2 dmg)
              FilterChip(
                label: const Text('Dueling (+2 dmg)', style: TextStyle(fontSize: 11)),
                selected: attack.hasDueling,
                onSelected: (val) => onUpdate(attack.copyWith(hasDueling: val)),
              ),

              // Archery (+2 hit)
              FilterChip(
                label: const Text('Archery (+2 hit)', style: TextStyle(fontSize: 11)),
                selected: attack.hasArchery,
                onSelected: (val) => onUpdate(attack.copyWith(hasArchery: val)),
              ),

              // Bless (+1d4)
              FilterChip(
                label: const Text('Bless (+1d4)', style: TextStyle(fontSize: 11)),
                selected: attack.attackBuffDiceSides == 4,
                onSelected: (val) => onUpdate(attack.copyWith(attackBuffDiceSides: val ? 4 : 0)),
              ),

              // Agonizing Blast / Cantrip Ability Mod (+Mod dmg)
              FilterChip(
                avatar: const Icon(Icons.auto_awesome, size: 12, color: Colors.purpleAccent),
                label: Text('Agonizing Blast (+$abilityModifier dmg)', style: const TextStyle(fontSize: 11)),
                tooltip: 'Add spellcasting ability modifier to cantrip / Eldritch Blast damage',
                selected: attack.hasAgonizingBlast,
                selectedColor: Colors.purple.withValues(alpha: 0.25),
                checkmarkColor: Colors.purpleAccent,
                onSelected: (val) {
                  onUpdate(attack.copyWith(
                    hasAgonizingBlast: val,
                    abilityModForAgonizing: abilityModifier,
                  ));
                },
              ),

              // 2024 Weapon Masteries
              if (anythingGoesMode || is2024) ...[
                FilterChip(
                  label: const Text('Graze (Miss Dmg)', style: TextStyle(fontSize: 11)),
                  selected: attack.weaponMastery == WeaponMastery.graze,
                  selectedColor: Colors.teal.withValues(alpha: 0.25),
                  onSelected: (val) {
                    onUpdate(attack.copyWith(
                      weaponMastery: val ? WeaponMastery.graze : WeaponMastery.none,
                      abilityModForGraze: val ? attack.damageBonus : 0,
                    ));
                  },
                ),
                FilterChip(
                  label: const Text('Vex (Adv on Hit)', style: TextStyle(fontSize: 11)),
                  selected: attack.weaponMastery == WeaponMastery.vex,
                  selectedColor: Colors.teal.withValues(alpha: 0.25),
                  onSelected: (val) {
                    onUpdate(attack.copyWith(
                      weaponMastery: val ? WeaponMastery.vex : WeaponMastery.none,
                    ));
                  },
                ),
              ],

              // Expanded Crit (19-20)
              FilterChip(
                label: const Text('Crit 19-20', style: TextStyle(fontSize: 11)),
                selected: attack.critThreshold == 19,
                onSelected: (val) => onUpdate(attack.copyWith(critThreshold: val ? 19 : 20)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
