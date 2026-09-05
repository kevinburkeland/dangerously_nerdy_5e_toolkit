import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/action_economy_models.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/room_roll.dart';
import '../../models/spellbook_data.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/dice_room_service.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/character_evaluation_engine.dart';
import '../../utils/secure_random.dart';

class ResolvedCharacterActions {
  final List<CharacterCombatAction> allActions;
  final List<CharacterCombatAction> actions;
  final List<CharacterCombatAction> bonusActions;
  final List<CharacterCombatAction> reactions;
  final List<CharacterCombatAction> specialActions;
  final List<CharacterCombatAction> standardActions;

  const ResolvedCharacterActions({
    required this.allActions,
    required this.actions,
    required this.bonusActions,
    required this.reactions,
    required this.specialActions,
    required this.standardActions,
  });
}

/// Resolves all standard, class, spell, and magic item combat actions available to a character.
class CharacterActionsResolver {
  CharacterActionsResolver._();

  static ResolvedCharacterActions resolve({
    required Character character,
    required EvaluatedCharacterStats stats,
    required CharacterSheetController controller,
  }) {
    final edition = character.id.ruleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;

    final actionList = <CharacterCombatAction>[];
    final bonusActionList = <CharacterCombatAction>[];
    final reactionList = <CharacterCombatAction>[];
    final specialList = <CharacterCombatAction>[];
    final standardList = <CharacterCombatAction>[];

    // Helper: Dispatch dice room roll
    void dispatchRoll(BuildContext context, {required String label, required String formula}) {
      HapticService.lightImpact(context);
      final cleanFormula = formula.replaceAll(' ', '');
      final rollResult = SpellRollEngine.roll(formula: cleanFormula);

      final roomService = DiceRoomService();
      final activeRoom = roomService.activeRoomCode;
      if (activeRoom != null) {
        final roomRoll = RoomRoll(
          id: 'roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
          roomCode: activeRoom,
          playerName: character.name.isNotEmpty ? character.name : 'Player',
          formulaString: formula,
          total: rollResult.total,
          individualRolls: rollResult.individualDice,
          details: [label],
          isCrit: rollResult.individualDice.contains(20),
          isFumble: rollResult.individualDice.contains(1),
          timestamp: DateTime.now(),
        );
        roomService.broadcastRoll(roomRoll);
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          content: Text(
            '${character.name} $label: ${rollResult.total} (${rollResult.formulaDescription})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // ==========================================
    // 1. EQUIPPED WEAPON ATTACKS (ACTIONS)
    // ==========================================
    for (final atk in stats.attackProfiles) {
      final bonusStr = atk.attackBonus >= 0 ? '+${atk.attackBonus}' : '${atk.attackBonus}';
      final isRanged = atk.range.contains('/');
      actionList.add(
        CharacterCombatAction(
          id: 'weapon-${atk.weaponName}',
          name: atk.weaponName,
          actionType: ActionType.action,
          category: CombatActionCategory.weapon,
          subtitle: '${isRanged ? "Ranged" : "Melee"} Weapon • ${atk.damageType.name.toUpperCase()}',
          description: atk.activeMastery != null
              ? 'Weapon Mastery: ${atk.activeMastery!.displayName}. Standard weapon attack using equipped ${atk.weaponName}.'
              : 'Standard weapon attack using equipped ${atk.weaponName}.',
          range: atk.range,
          toHitBonus: atk.attackBonus,
          damageFormula: atk.damageFormula,
          damageType: atk.damageType,
          isAttack: true,
          dealsDamage: true,
          onRollAttack: (ctx) => dispatchRoll(ctx, label: '${atk.weaponName} Attack', formula: '1d20$bonusStr'),
          onRollDamage: (ctx) => dispatchRoll(ctx, label: '${atk.weaponName} Damage', formula: atk.damageFormula),
        ),
      );
    }

    // Unarmed Strike (Always available)
    final strMod = stats.abilityModifiers[AbilityType.strength] ?? 0;
    final unarmedAtk = stats.proficiencyBonus + strMod;
    final unarmedAtkStr = unarmedAtk >= 0 ? '+$unarmedAtk' : '$unarmedAtk';
    final unarmedDmg = 1 + strMod;
    actionList.add(
      CharacterCombatAction(
        id: 'unarmed-strike',
        name: 'Unarmed Strike',
        actionType: ActionType.action,
        category: CombatActionCategory.weapon,
        subtitle: 'Melee Strike • BLUDGEONING',
        description: 'Instead of using a weapon, you punch, kick, or headbutt a target within 5 feet.',
        range: 'Reach 5 ft',
        toHitBonus: unarmedAtk,
        damageFormula: '$unarmedDmg',
        damageType: DamageType.bludgeoning,
        isAttack: true,
        dealsDamage: true,
        onRollAttack: (ctx) => dispatchRoll(ctx, label: 'Unarmed Strike Attack', formula: '1d20$unarmedAtkStr'),
        onRollDamage: (ctx) => dispatchRoll(ctx, label: 'Unarmed Strike Damage', formula: '$unarmedDmg'),
      ),
    );

    // ==========================================
    // 2. COMBAT SPELLS & CANTRIPS (ACTIONS)
    // ==========================================
    final allSpells = <EntityReference<Spell>>[
      ...character.cantrips,
      ...character.spellsPrepared,
      ...character.spellsKnown,
    ];
    final seenSpellSlugs = <String>{};

    for (final s in allSpells) {
      if (seenSpellSlugs.contains(s.slug)) continue;
      seenSpellSlugs.add(s.slug);

      final item = SpellbookLibrary.getSpellById(s.slug);
      final rules = item?.getRules(edition);
      final castingTime = (rules?.castingTime ?? item?.rules2014.castingTime ?? '1 Action').toLowerCase();

      final isBonusAction = castingTime.contains('bonus');
      final isReaction = castingTime.contains('reaction');

      final slug = s.slug.toLowerCase().replaceAll('_', '-');
      final cleanSlug = slug.startsWith('spell-') ? slug.substring(6) : slug;
      final isEB = cleanSlug == 'eldritch-blast' || s.displayName.toLowerCase() == 'eldritch blast';

      // Damage formula
      String? dmgFormula = rules?.rollFormula;
      DamageType? dmgType;
      if (rules?.damageOrHealType != null) {
        dmgType = DamageType.values.firstWhere(
          (d) => d.name.toLowerCase() == rules!.damageOrHealType!.toLowerCase(),
          orElse: () => DamageType.untyped,
        );
      }

      // Agonizing Blast check
      if (isEB && (controller.hasAgonizingBlast || controller.hasCapabilityFlag('eldritchBlastChaDamage') || controller.hasCapabilityFlag('agonizing_blast'))) {
        final chaMod = character.effectiveAbilityScores.getModifier(AbilityType.charisma);
        final chaStr = chaMod >= 0 ? '+ $chaMod' : '- ${chaMod.abs()}';
        dmgFormula = dmgFormula != null && dmgFormula.isNotEmpty ? '$dmgFormula $chaStr' : '1d10 $chaStr';
        dmgType = DamageType.force;
      }

      final hasAtk = isEB || castingTime.contains('attack') || (rules?.description.any((d) => d.toLowerCase().contains('spell attack')) ?? false);
      final dealsDmg = dmgFormula != null && dmgFormula.isNotEmpty && dmgFormula.toLowerCase() != 'none';

      final spellAtk = stats.spellAttackBonus;
      final spellAtkStr = spellAtk >= 0 ? '+$spellAtk' : '$spellAtk';

      final combatAction = CharacterCombatAction(
        id: 'spell-${s.slug}',
        name: s.displayName,
        actionType: isBonusAction
            ? ActionType.bonusAction
            : (isReaction ? ActionType.reaction : ActionType.action),
        category: CombatActionCategory.spell,
        subtitle: '${item?.level == 0 ? "Cantrip" : "Level ${item?.level ?? 1}"} • ${item?.school.displayName ?? "Magic"}',
        description: rules != null && rules.description.isNotEmpty ? rules.description.first : s.displayName,
        range: rules?.range ?? '30 ft',
        toHitBonus: hasAtk ? spellAtk : null,
        damageFormula: dealsDmg ? dmgFormula : null,
        damageType: dmgType,
        isAttack: hasAtk,
        dealsDamage: dealsDmg,
        onRollAttack: hasAtk
            ? (ctx) => dispatchRoll(ctx, label: '${s.displayName} Spell Attack', formula: '1d20$spellAtkStr')
            : null,
        onRollDamage: dealsDmg
            ? (ctx) => dispatchRoll(ctx, label: '${s.displayName} Damage', formula: dmgFormula!)
            : null,
      );

      if (isBonusAction) {
        bonusActionList.add(combatAction);
      } else if (isReaction) {
        reactionList.add(combatAction);
      } else if (hasAtk || dealsDmg) {
        actionList.add(combatAction);
      }
    }

    // ==========================================
    // 3. BONUS ACTIONS (CLASS & DUAL WIELD)
    // ==========================================
    // Off-hand two-weapon fighting
    final weapons = character.equippedItems.where((i) =>
        i.equippedSlot == EquipmentSlot.mainHand ||
        i.equippedSlot == EquipmentSlot.offHand).toList();
    if (weapons.length >= 2) {
      final offWeapon = weapons.last;
      bonusActionList.add(
        CharacterCombatAction(
          id: 'two-weapon-offhand',
          name: 'Off-Hand Two-Weapon Attack',
          actionType: ActionType.bonusAction,
          category: CombatActionCategory.weapon,
          subtitle: 'Bonus Action • Dual-Wielding',
          description: 'When you take the Attack action with a light melee weapon, use a bonus action to attack with your other light weapon (${offWeapon.displayName}).',
          range: 'Reach 5 ft',
          isAttack: true,
          dealsDamage: true,
          onRollAttack: (ctx) => dispatchRoll(ctx, label: 'Off-Hand Attack', formula: '1d20+${stats.proficiencyBonus}'),
          onRollDamage: (ctx) => dispatchRoll(ctx, label: 'Off-Hand Damage', formula: '1d6'),
        ),
      );
    }

    // Class-specific bonus actions
    for (final cls in character.progression.classes) {
      final classSlug = cls.classRef.slug.toLowerCase();
      final lvl = cls.level;

      // Rogue: Cunning Action
      if (classSlug.contains('rogue') && lvl >= 2) {
        bonusActionList.add(
          const CharacterCombatAction(
            id: 'cunning-action',
            name: 'Cunning Action',
            actionType: ActionType.bonusAction,
            category: CombatActionCategory.feature,
            subtitle: 'Rogue Level 2 • Mobility & Stealth',
            description: 'You can take a bonus action on each of your turns to take the Dash, Disengage, or Hide action.',
          ),
        );
      }

      // Fighter: Second Wind
      if (classSlug.contains('fighter') && lvl >= 1) {
        bonusActionList.add(
          CharacterCombatAction(
            id: 'second-wind',
            name: 'Second Wind',
            actionType: ActionType.bonusAction,
            category: CombatActionCategory.feature,
            subtitle: 'Fighter Level $lvl • 1/Short or Long Rest',
            description: 'On your turn, you can use a bonus action to regain hit points equal to 1d10 + your fighter level ($lvl).',
            resourceCost: '1/Short Rest',
            dealsDamage: false,
            onExecute: (ctx) {
              dispatchRoll(ctx, label: 'Second Wind Healing', formula: '1d10+$lvl');
            },
          ),
        );
      }

      // Fighter: Action Surge
      if (classSlug.contains('fighter') && lvl >= 2) {
        specialList.add(
          const CharacterCombatAction(
            id: 'action-surge',
            name: 'Action Surge',
            actionType: ActionType.special,
            category: CombatActionCategory.feature,
            subtitle: 'Fighter Level 2 • 1/Short or Long Rest',
            description: 'On your turn, you can take one additional action on top of your regular action and a possible bonus action.',
            resourceCost: '1/Short Rest',
          ),
        );
      }

      // Barbarian: Rage
      if (classSlug.contains('barbarian') && lvl >= 1) {
        final rageDmg = lvl >= 16 ? 4 : (lvl >= 9 ? 3 : 2);
        bonusActionList.add(
          CharacterCombatAction(
            id: 'barbarian-rage',
            name: 'Rage',
            actionType: ActionType.bonusAction,
            category: CombatActionCategory.feature,
            subtitle: 'Barbarian Level $lvl • Combat Buff',
            description: 'Enter a rage as a bonus action. Gain advantage on STR checks/saves, +$rageDmg melee weapon damage, and resistance to bludgeoning, piercing, and slashing damage.',
            resourceCost: 'Charges based on level',
          ),
        );
      }

      // Bard: Bardic Inspiration
      if (classSlug.contains('bard') && lvl >= 1) {
        final die = lvl >= 15 ? '1d12' : (lvl >= 10 ? '1d10' : (lvl >= 5 ? '1d8' : '1d6'));
        bonusActionList.add(
          CharacterCombatAction(
            id: 'bardic-inspiration',
            name: 'Bardic Inspiration',
            actionType: ActionType.bonusAction,
            category: CombatActionCategory.feature,
            subtitle: 'Bard Level $lvl • Grant $die to Ally',
            description: 'Use a bonus action to inspire one creature within 60 feet. Once within the next 10 minutes, the creature can roll $die and add it to one d20 test.',
            range: '60 ft',
            resourceCost: 'Charisma Mod / Long Rest',
            onExecute: (ctx) => dispatchRoll(ctx, label: 'Bardic Inspiration Die', formula: die),
          ),
        );
      }

      // Monk: Martial Arts, Flurry of Blows, Patient Defense, Step of the Wind
      if (classSlug.contains('monk') && lvl >= 1) {
        bonusActionList.add(
          const CharacterCombatAction(
            id: 'monk-martial-arts-ba',
            name: 'Martial Arts Strike',
            actionType: ActionType.bonusAction,
            category: CombatActionCategory.feature,
            subtitle: 'Monk Bonus Action • Unarmed Strike',
            description: 'When you take the Attack action with an unarmed strike or monk weapon, you can make one unarmed strike as a bonus action.',
          ),
        );
        if (lvl >= 2) {
          bonusActionList.add(
            const CharacterCombatAction(
              id: 'flurry-of-blows',
              name: 'Flurry of Blows',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: '1 Ki / Focus Point • Two Unarmed Strikes',
              description: 'Immediately after you take the Attack action, spend 1 Ki point to make two unarmed strikes as a bonus action.',
              resourceCost: '1 Ki',
            ),
          );
          bonusActionList.add(
            const CharacterCombatAction(
              id: 'patient-defense',
              name: 'Patient Defense',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: '1 Ki / Focus Point • Dodge Action',
              description: 'Spend 1 Ki point to take the Dodge action as a bonus action on your turn.',
              resourceCost: '1 Ki',
            ),
          );
          bonusActionList.add(
            const CharacterCombatAction(
              id: 'step-of-the-wind',
              name: 'Step of the Wind',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: '1 Ki / Focus Point • Disengage or Dash',
              description: 'Spend 1 Ki point to take the Disengage or Dash action as a bonus action on your turn, doubling your jump distance for the turn.',
              resourceCost: '1 Ki',
            ),
          );
        }
      }
    }

    // ==========================================
    // 4. REACTIONS (STANDARD & CLASS)
    // ==========================================
    reactionList.add(
      CharacterCombatAction(
        id: 'opportunity-attack',
        name: 'Opportunity Attack',
        actionType: ActionType.reaction,
        category: CombatActionCategory.standard,
        subtitle: 'Standard Reaction • Melee Attack',
        description: 'You can make an opportunity attack when a hostile creature that you can see moves out of your reach. To make the opportunity attack, you use your reaction to make one melee attack against the provoking creature.',
        isAttack: true,
        onRollAttack: stats.attackProfiles.isNotEmpty
            ? (ctx) {
                final atk = stats.attackProfiles.first;
                final b = atk.attackBonus >= 0 ? '+${atk.attackBonus}' : '${atk.attackBonus}';
                dispatchRoll(ctx, label: 'Opportunity Attack (${atk.weaponName})', formula: '1d20$b');
              }
            : (ctx) => dispatchRoll(ctx, label: 'Opportunity Attack (Unarmed)', formula: '1d20$unarmedAtkStr'),
      ),
    );

    // Rogue: Uncanny Dodge
    final isRogue5 = character.progression.classes.any((c) => c.classRef.slug.toLowerCase().contains('rogue') && c.level >= 5);
    if (isRogue5) {
      reactionList.add(
        const CharacterCombatAction(
          id: 'uncanny-dodge',
          name: 'Uncanny Dodge',
          actionType: ActionType.reaction,
          category: CombatActionCategory.feature,
          subtitle: 'Rogue Level 5 • Defensive Reaction',
          description: 'When an attacker that you can see hits you with an attack, you can use your reaction to halve the attack’s damage against you.',
        ),
      );
    }

    // ==========================================
    // 5. MAGIC ITEM ACTIONS
    // ==========================================
    for (final instance in character.equippedItems) {
      if (instance.requiresAttunement && !instance.isAttuned) continue;
      final nameLower = instance.displayName.toLowerCase();

      // Rod of the Pact Keeper Spell Slot Recovery
      if (nameLower.contains('rod of the pact keeper')) {
        specialList.add(
          CharacterCombatAction(
            id: 'item-pact-keeper-regain-slot',
            name: 'Pact Keeper: Regain Spell Slot',
            actionType: ActionType.action,
            category: CombatActionCategory.magicItem,
            subtitle: '${instance.displayName} • 1/Long Rest',
            description: 'While holding this rod, you can regain one warlock spell slot as an action. You can’t use this property again until you finish a long rest.',
            resourceCost: '1/Long Rest',
            onExecute: (ctx) {
              HapticService.heavyImpact(ctx);
              final pool = controller.character.resources.spellSlots;
              if (pool.pactMagicMax > 0 && pool.pactMagicCurrent < pool.pactMagicMax) {
                controller.togglePactSlot(false); // restores 1 pact slot
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Rod of the Pact Keeper: Restored 1 Warlock spell slot!'),
                    backgroundColor: Colors.purple,
                  ),
                );
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Pact Magic slots are already full!'),
                  ),
                );
              }
            },
          ),
        );
      }
    }

    // ==========================================
    // 6. STANDARD 5E COMBAT ACTIONS (RULES)
    // ==========================================
    standardList.addAll([
      const CharacterCombatAction(
        id: 'std-attack',
        name: 'Attack',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Weapon / Unarmed Attack',
        description: 'Make one melee or ranged attack with an equipped weapon or unarmed strike. If you have the Extra Attack feature, you can make additional attacks with this action.',
      ),
      CharacterCombatAction(
        id: 'std-dash',
        name: 'Dash',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Gain +${stats.speedFeet} ft Movement',
        description: 'You gain extra movement for the current turn equal to your speed (${stats.speedFeet} feet) after applying any modifiers.',
      ),
      const CharacterCombatAction(
        id: 'std-disengage',
        name: 'Disengage',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Prevent Opportunity Attacks',
        description: 'Your movement doesn’t provoke opportunity attacks for the rest of the turn.',
      ),
      const CharacterCombatAction(
        id: 'std-dodge',
        name: 'Dodge',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Disadvantage on Attacks Against You',
        description: 'Until the start of your next turn, any attack roll made against you has disadvantage if you can see the attacker, and you make Dexterity saving throws with advantage. You lose this benefit if you are incapacitated.',
      ),
      const CharacterCombatAction(
        id: 'std-help',
        name: 'Help',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Grant Advantage to an Ally',
        description: 'You lend your aid to another creature in the completion of a task. When you use the Help action, the creature you aid gains advantage on the next ability check it makes, or advantage on the next attack roll against a creature within 5 ft of you.',
      ),
      CharacterCombatAction(
        id: 'std-hide',
        name: 'Hide',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Roll Stealth Check',
        description: 'You make a Dexterity (Stealth) check in an attempt to become hidden, provided you are unseen and have cover.',
        onExecute: (ctx) {
          final stealthMod = stats.skillModifiers[SkillType.stealth] ?? stats.abilityModifiers[AbilityType.dexterity] ?? 0;
          final strMod = stealthMod >= 0 ? '+$stealthMod' : '$stealthMod';
          dispatchRoll(ctx, label: 'Dexterity (Stealth) Check', formula: '1d20$strMod');
        },
      ),
      const CharacterCombatAction(
        id: 'std-ready',
        name: 'Ready',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Prepare a Triggered Reaction',
        description: 'You wait for a particular circumstance before you act. Decide what perceivable circumstance will trigger your reaction and the action you will take in response.',
      ),
      CharacterCombatAction(
        id: 'std-search',
        name: 'Search',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Roll Perception / Investigation',
        description: 'You devote your attention to finding something. Make a Wisdom (Perception) check or an Intelligence (Investigation) check.',
        onExecute: (ctx) {
          final percMod = stats.skillModifiers[SkillType.perception] ?? stats.abilityModifiers[AbilityType.wisdom] ?? 0;
          final strMod = percMod >= 0 ? '+$percMod' : '$percMod';
          dispatchRoll(ctx, label: 'Wisdom (Perception) Check', formula: '1d20$strMod');
        },
      ),
      const CharacterCombatAction(
        id: 'std-use-object',
        name: 'Use an Object',
        actionType: ActionType.action,
        category: CombatActionCategory.standard,
        subtitle: '1 Action • Interact with Complex Item',
        description: 'You normally interact with an object while doing something else. When an object requires your action for its use, you take the Use an Object action.',
      ),
    ]);

    final all = <CharacterCombatAction>[
      ...actionList,
      ...bonusActionList,
      ...reactionList,
      ...specialList,
      ...standardList,
    ];

    return ResolvedCharacterActions(
      allActions: all,
      actions: actionList,
      bonusActions: bonusActionList,
      reactions: reactionList,
      specialActions: specialList,
      standardActions: standardList,
    );
  }
}
