import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/dpr/dpr_models.dart';
import '../../services/haptic_service.dart';
import '../../utils/dice_formatters.dart';
import '../common/numeric_stepper.dart';
import 'dpr_attack_editor_card.dart';

/// Card configurator for combatant ability scores, proficiency bonus, advantage, and attack actions.
class DprCombatantConfigurator extends StatelessWidget {
  final DprCombatantProfile profile;
  final bool anythingGoesMode;
  final DmRulesEdition edition;
  final ValueChanged<DprCombatantProfile> onProfileChanged;
  final ValueChanged<bool> onAnythingGoesChanged;
  final void Function(int index) onOpenWeaponPicker;

  const DprCombatantConfigurator({
    super.key,
    required this.profile,
    required this.anythingGoesMode,
    required this.edition,
    required this.onProfileChanged,
    required this.onAnythingGoesChanged,
    required this.onOpenWeaponPicker,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  'Attacks, Weapons & Cantrips',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.casino, size: 14),
                      label: const Text('Halfling Luck', style: TextStyle(fontSize: 11)),
                      tooltip: 'Reroll natural 1s on attack rolls (Halfling Luck / Lucky trait)',
                      selected: profile.hasHalflingLuck,
                      selectedColor: Colors.amber.withValues(alpha: 0.25),
                      checkmarkColor: Colors.amber,
                      onSelected: (val) {
                        HapticService.selectionTick(context);
                        onProfileChanged(profile.copyWith(hasHalflingLuck: val));
                      },
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: const Icon(Icons.shuffle, size: 14),
                      label: const Text('Anything Goes', style: TextStyle(fontSize: 11)),
                      tooltip: 'Unlock and mix all 2014 & 2024 feats, fighting styles, and weapon masteries',
                      selected: anythingGoesMode,
                      selectedColor: Colors.purple.withValues(alpha: 0.25),
                      checkmarkColor: Colors.purpleAccent,
                      onSelected: (val) {
                        HapticService.selectionTick(context);
                        onAnythingGoesChanged(val);
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: 'Add Attack / Cantrip Action',
                      onPressed: () {
                        HapticService.selectionTick(context);
                        final newAttacks = List<DprAttackAction>.from(profile.attacks)
                          ..add(
                            DprAttackAction(
                              id: 'attack_${DateTime.now().millisecondsSinceEpoch}',
                              name: 'Attack #${profile.attacks.length + 1}',
                              attackBonus: profile.abilityModifier + profile.proficiencyBonus,
                              diceCount: 1,
                              diceSides: 6,
                              damageBonus: profile.abilityModifier,
                              damageType: 'slashing',
                              attacksPerRound: 1,
                            ),
                          );
                        onProfileChanged(profile.copyWith(attacks: newAttacks));
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Character Level & Ability Mod Adjuster
            Row(
              children: [
                Expanded(
                  child: NumericStepper(
                    label: 'Level',
                    value: profile.level,
                    display: 'Lv ${profile.level}',
                    min: 1,
                    max: 20,
                    onChanged: (val) {
                      final pb = Dnd5eScoreMath.levelToProficiencyBonus(val);
                      onProfileChanged(profile.copyWith(level: val, proficiencyBonus: pb));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumericStepper(
                    label: 'Ability Score',
                    value: profile.abilityScore,
                    display: Dnd5eScoreMath.formatScoreWithModifier(profile.abilityScore),
                    min: 1,
                    max: 30,
                    onChanged: (val) {
                      final newMod = Dnd5eScoreMath.scoreToModifier(val);
                      final updatedAttacks = profile.attacks.map((a) {
                        return a.copyWith(
                          abilityModForAgonizing: a.hasAgonizingBlast ? newMod : a.abilityModForAgonizing,
                          abilityModForGraze: a.weaponMastery == WeaponMastery.graze ? newMod : a.abilityModForGraze,
                        );
                      }).toList();
                      onProfileChanged(profile.copyWith(abilityScore: val, attacks: updatedAttacks));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumericStepper(
                    label: 'Prof. Bonus',
                    value: profile.proficiencyBonus,
                    display: '+${profile.proficiencyBonus}',
                    min: 2,
                    max: 6,
                    onChanged: (val) {
                      onProfileChanged(profile.copyWith(proficiencyBonus: val));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Advantage State Selector
            DropdownButtonFormField<AdvantageType>(
              key: ValueKey(profile.defaultAdvantage),
              initialValue: profile.defaultAdvantage,
              decoration: InputDecoration(
                labelText: 'Accuracy & Advantage State',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: AdvantageType.values.map((adv) {
                return DropdownMenuItem(
                  value: adv,
                  child: Text(adv.label, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  onProfileChanged(profile.copyWith(defaultAdvantage: val));
                }
              },
            ),
            const SizedBox(height: 16),

            // Rogue Sneak Attack / Once per turn proc slider
            Row(
              children: [
                const Icon(Icons.flash_on, size: 16, color: Colors.purpleAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sneak Attack (Once/Turn): ${profile.sneakAttackDiceCount}d${profile.sneakAttackDiceSides}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: profile.sneakAttackDiceCount > 0
                      ? () => onProfileChanged(profile.copyWith(sneakAttackDiceCount: profile.sneakAttackDiceCount - 1))
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: profile.sneakAttackDiceCount < 10
                      ? () => onProfileChanged(profile.copyWith(sneakAttackDiceCount: profile.sneakAttackDiceCount + 1))
                      : null,
                ),
              ],
            ),
            const Divider(height: 24),

            // List of Attack Actions
            ...List.generate(profile.attacks.length, (index) {
              final attack = profile.attacks[index];
              return DprAttackEditorCard(
                attack: attack,
                index: index,
                totalAttacks: profile.attacks.length,
                abilityModifier: profile.abilityModifier,
                proficiencyBonus: profile.proficiencyBonus,
                anythingGoesMode: anythingGoesMode,
                edition: edition,
                onUpdate: (updated) {
                  final newAttacks = List<DprAttackAction>.from(profile.attacks)..[index] = updated;
                  onProfileChanged(profile.copyWith(attacks: newAttacks));
                },
                onEquipPreset: () => onOpenWeaponPicker(index),
                onDelete: () {
                  final newAttacks = List<DprAttackAction>.from(profile.attacks)..removeAt(index);
                  onProfileChanged(profile.copyWith(attacks: newAttacks));
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
