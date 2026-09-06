import 'package:flutter/material.dart';
import '../../models/characters/srd_classes_library.dart';
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

    // ==========================================
    // 3. CLASS FEATURES, SUBCLASSES & HOMEBREW ACTIONS
    // ==========================================
    final registeredActionKeys = <String>{};
    for (final a in actionList) {
      registeredActionKeys.add(a.name.toLowerCase().trim());
    }
    for (final a in bonusActionList) {
      registeredActionKeys.add(a.name.toLowerCase().trim());
    }
    for (final a in reactionList) {
      registeredActionKeys.add(a.name.toLowerCase().trim());
    }

    void registerAction(CharacterCombatAction action) {
      final key = action.name.toLowerCase().trim();
      if (registeredActionKeys.contains(key)) return;
      registeredActionKeys.add(key);

      switch (action.actionType) {
        case ActionType.action:
          actionList.add(action);
        case ActionType.bonusAction:
          bonusActionList.add(action);
        case ActionType.reaction:
          reactionList.add(action);
        case ActionType.special:
        default:
          specialList.add(action);
      }
    }

    for (final cls in character.progression.classes) {
      final classSlug = cls.classRef.slug.toLowerCase();
      final lvl = cls.level;

      // --- BARBARIAN ---
      if (classSlug.contains('barbarian')) {
        if (lvl >= 1) {
          final rageDmg = lvl >= 16 ? 4 : (lvl >= 9 ? 3 : 2);
          registerAction(
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
        if (lvl >= 2) {
          registerAction(
            const CharacterCombatAction(
              id: 'reckless-attack',
              name: 'Reckless Attack',
              actionType: ActionType.special,
              category: CombatActionCategory.feature,
              subtitle: 'Barbarian Level 2 • Attack Buff',
              description: 'When making your first attack on your turn, gain advantage on melee weapon attack rolls using STR, but attack rolls against you have advantage until your next turn.',
            ),
          );
        }
      }

      // --- BARD ---
      if (classSlug.contains('bard')) {
        if (lvl >= 1) {
          final die = lvl >= 15 ? '1d12' : (lvl >= 10 ? '1d10' : (lvl >= 5 ? '1d8' : '1d6'));
          registerAction(
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
        if (lvl >= 6) {
          registerAction(
            const CharacterCombatAction(
              id: 'countercharm',
              name: 'Countercharm',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Bard Level 6 • 30 ft Friendly Aura',
              description: 'Start a performance that lasts until the end of your next turn. You and friendly creatures within 30 feet have advantage on saving throws against being frightened or charmed.',
              range: '30 ft',
            ),
          );
        }
        if (lvl >= 3 && (cls.subclassRef?.slug.toLowerCase().contains('lore') ?? false)) {
          registerAction(
            const CharacterCombatAction(
              id: 'cutting-words',
              name: 'Cutting Words',
              actionType: ActionType.reaction,
              category: CombatActionCategory.feature,
              subtitle: 'College of Lore • Disruption',
              description: 'When a creature within 60 feet rolls an attack roll, ability check, or damage roll, use your reaction and expend one Bardic Inspiration die to subtract the roll from the creature\'s total.',
              range: '60 ft',
              resourceCost: '1 Bardic Inspiration',
            ),
          );
        }
      }

      // --- CLERIC ---
      if (classSlug.contains('cleric')) {
        if (lvl >= 2) {
          registerAction(
            CharacterCombatAction(
              id: 'channel-divinity-turn-undead',
              name: 'Channel Divinity: Turn Undead',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Cleric Level $lvl • 30 ft Aura',
              description: 'Present your holy symbol and speak a prayer. Each undead that can see or hear you within 30 feet must make a Wisdom saving throw or be turned for 1 minute or until it takes damage.',
              range: '30 ft',
              resourceCost: '1 Channel Divinity',
            ),
          );
          registerAction(
            CharacterCombatAction(
              id: 'channel-divinity-harness-divine-power',
              name: 'Channel Divinity: Harness Divine Power',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Cleric Level $lvl • Regain Spell Slot',
              description: 'Touch your holy symbol and expend a use of Channel Divinity to regain one expended spell slot (up to half your proficiency bonus rounded up).',
              resourceCost: '1 Channel Divinity',
            ),
          );
        }

        final subSlug = cls.subclassRef?.slug.toLowerCase() ?? '';
        if (lvl >= 2 && subSlug.contains('life')) {
          final preserveHp = lvl * 5;
          registerAction(
            CharacterCombatAction(
              id: 'channel-divinity-preserve-life',
              name: 'Channel Divinity: Preserve Life',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Life Domain • Heal up to $preserveHp HP',
              description: 'Present your holy symbol and evoke healing energy that can restore up to $preserveHp hit points divided among bloodied creatures within 30 feet (cannot heal above half max HP).',
              range: '30 ft',
              resourceCost: '1 Channel Divinity',
            ),
          );
        }

        if (subSlug.contains('light')) {
          if (lvl >= 1) {
            registerAction(
              const CharacterCombatAction(
                id: 'warding-flare',
                name: 'Warding Flare',
                actionType: ActionType.reaction,
                category: CombatActionCategory.feature,
                subtitle: 'Light Domain • Impose Disadvantage',
                description: 'When you are attacked by a creature within 30 feet that you can see, use your reaction to interpose divine light, imposing disadvantage on the attack roll.',
                range: '30 ft',
                resourceCost: 'Wisdom Mod / Long Rest',
              ),
            );
          }
          if (lvl >= 2) {
            registerAction(
              CharacterCombatAction(
                id: 'channel-divinity-radiance-of-the-dawn',
                name: 'Channel Divinity: Radiance of the Dawn',
                actionType: ActionType.action,
                category: CombatActionCategory.feature,
                subtitle: 'Light Domain Level $lvl • 30 ft Burst',
                description: 'Dispel magical darkness within 30 feet. Hostile creatures within 30 feet must make a Constitution saving throw or take 2d10 + $lvl radiant damage (half on success).',
                range: '30 ft',
                damageFormula: '2d10+$lvl',
                damageType: DamageType.radiant,
                dealsDamage: true,
                resourceCost: '1 Channel Divinity',
                onRollDamage: (ctx) => dispatchRoll(ctx, label: 'Radiance of the Dawn Damage', formula: '2d10+$lvl'),
              ),
            );
          }
        }

        if (lvl >= 1 && subSlug.contains('tempest')) {
          registerAction(
            CharacterCombatAction(
              id: 'wrath-of-the-storm',
              name: 'Wrath of the Storm',
              actionType: ActionType.reaction,
              category: CombatActionCategory.feature,
              subtitle: 'Tempest Domain • Thunder/Lightning Rebuke',
              description: 'When a creature within 5 feet that you can see hits you with an attack, use your reaction to cause it to make a Dexterity save or take 2d8 lightning or thunder damage (half on success).',
              range: '5 ft',
              damageFormula: '2d8',
              dealsDamage: true,
              resourceCost: 'Wisdom Mod / Long Rest',
              onRollDamage: (ctx) => dispatchRoll(ctx, label: 'Wrath of the Storm Damage', formula: '2d8'),
            ),
          );
        }

        if (lvl >= 10) {
          registerAction(
            CharacterCombatAction(
              id: 'divine-intervention',
              name: 'Divine Intervention',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Cleric Level $lvl • Roll d100 <= $lvl',
              description: 'Implore your deity for aid. Roll percentile dice (d100); if you roll a number equal to or lower than your cleric level ($lvl), your deity intervenes.',
              resourceCost: '1/7 Days if successful',
              onExecute: (ctx) => dispatchRoll(ctx, label: 'Divine Intervention Check', formula: '1d100'),
            ),
          );
        }
      }

      // --- DRUID ---
      if (classSlug.contains('druid')) {
        if (lvl >= 2) {
          final isMoonDruid = cls.subclassRef?.slug.toLowerCase().contains('moon') ?? false;
          registerAction(
            CharacterCombatAction(
              id: 'wild-shape',
              name: isMoonDruid ? 'Combat Wild Shape' : 'Wild Shape',
              actionType: isMoonDruid ? ActionType.bonusAction : ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Druid Level $lvl • Beast Transformation',
              description: isMoonDruid
                  ? 'As a bonus action, magically assume the shape of a beast that you have seen before.'
                  : 'As an action, magically assume the shape of a beast that you have seen before.',
              resourceCost: '2/Short Rest',
            ),
          );
          if (isMoonDruid) {
            registerAction(
              const CharacterCombatAction(
                id: 'combat-wild-shape-heal',
                name: 'Combat Wild Shape: Spell Slot Healing',
                actionType: ActionType.bonusAction,
                category: CombatActionCategory.feature,
                subtitle: 'Circle of the Moon • Regain HP',
                description: 'While transformed by Wild Shape, you can use a bonus action to expend one spell slot to regain 1d8 hit points per level of the spell slot expended.',
              ),
            );
          }
          registerAction(
            CharacterCombatAction(
              id: 'wild-companion',
              name: 'Wild Companion',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Druid Level $lvl • Summon Familiar',
              description: 'As an action, expend a use of Wild Shape to cast the find familiar spell without material components.',
              resourceCost: '1 Wild Shape Use',
            ),
          );
        }
      }

      // --- FIGHTER ---
      if (classSlug.contains('fighter')) {
        if (lvl >= 1) {
          registerAction(
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
        if (lvl >= 2) {
          registerAction(
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
        if (lvl >= 9) {
          registerAction(
            CharacterCombatAction(
              id: 'indomitable',
              name: 'Indomitable',
              actionType: ActionType.special,
              category: CombatActionCategory.feature,
              subtitle: 'Fighter Level $lvl • Save Reroll',
              description: 'Reroll a saving throw that you fail. You must use the new roll.',
              resourceCost: '1/Long Rest',
            ),
          );
        }
      }

      // --- MONK ---
      if (classSlug.contains('monk')) {
        if (lvl >= 1) {
          registerAction(
            const CharacterCombatAction(
              id: 'monk-martial-arts-ba',
              name: 'Martial Arts Strike',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Monk Bonus Action • Unarmed Strike',
              description: 'When you take the Attack action with an unarmed strike or monk weapon, you can make one unarmed strike as a bonus action.',
            ),
          );
        }
        if (lvl >= 2) {
          registerAction(
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
          registerAction(
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
          registerAction(
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
        if (lvl >= 3) {
          final dexMod = stats.abilityModifiers[AbilityType.dexterity] ?? 0;
          registerAction(
            CharacterCombatAction(
              id: 'deflect-missiles',
              name: 'Deflect Missiles',
              actionType: ActionType.reaction,
              category: CombatActionCategory.feature,
              subtitle: 'Monk Level $lvl • Ranged Defense',
              description: 'You can use your reaction to deflect or catch a missile when you are hit by a ranged weapon attack. Damage is reduced by 1d10 + $dexMod + $lvl. If reduced to 0, spend 1 Ki to make a ranged attack with it.',
              resourceCost: 'Reaction (1 Ki to throw)',
              onExecute: (ctx) => dispatchRoll(ctx, label: 'Deflect Missiles Reduction', formula: '1d10+$dexMod+$lvl'),
            ),
          );
        }
        if (lvl >= 5) {
          registerAction(
            const CharacterCombatAction(
              id: 'stunning-strike',
              name: 'Stunning Strike',
              actionType: ActionType.special,
              category: CombatActionCategory.feature,
              subtitle: 'Monk Level 5 • 1 Ki Point',
              description: 'When you hit another creature with a melee weapon attack, spend 1 Ki point to attempt to stun the target. It must make a Constitution saving throw or be stunned until the end of your next turn.',
              resourceCost: '1 Ki',
            ),
          );
        }
      }

      // --- PALADIN ---
      if (classSlug.contains('paladin')) {
        if (lvl >= 1) {
          final pool = lvl * 5;
          registerAction(
            CharacterCombatAction(
              id: 'lay-on-hands',
              name: 'Lay on Hands',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Paladin Level $lvl • Healing Pool ($pool HP)',
              description: 'As an action, touch a creature and draw power from your pool to restore up to $pool hit points, or expend 5 hit points to cure one disease or neutralize one poison.',
              range: 'Touch',
              resourceCost: '$pool HP / Long Rest',
            ),
          );
          final chaMod = character.effectiveAbilityScores.getModifier(AbilityType.charisma);
          final senseUses = (1 + chaMod).clamp(1, 10);
          registerAction(
            CharacterCombatAction(
              id: 'divine-sense',
              name: 'Divine Sense',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Paladin Level $lvl • 60 ft Detection',
              description: 'As an action, detect the location of any celestial, fiend, or undead within 60 feet that is not behind total cover, and sense consecrated or desecrated ground.',
              range: '60 ft',
              resourceCost: '$senseUses / Long Rest',
            ),
          );
        }
        if (lvl >= 2) {
          final is2024Smite = character.id.ruleset == RulesetVersion.v2024;
          registerAction(
            CharacterCombatAction(
              id: 'divine-smite',
              name: 'Divine Smite',
              actionType: is2024Smite ? ActionType.bonusAction : ActionType.special,
              category: CombatActionCategory.feature,
              subtitle: is2024Smite ? 'Paladin Level $lvl • Bonus Action' : 'Paladin Level $lvl • On-Hit Special',
              description: is2024Smite
                  ? 'Immediately after hitting a target with a melee weapon or unarmed strike, use a bonus action and expend a spell slot to deal extra radiant damage (2d8 for 1st level slot + 1d8 per higher slot, max 5d8).'
                  : 'When you hit a creature with a melee weapon attack, you can expend one spell slot to deal radiant damage to the target in addition to weapon damage (2d8 for 1st level + 1d8 per higher slot, +1d8 vs fiends/undead).',
              damageFormula: '2d8',
              damageType: DamageType.radiant,
              dealsDamage: true,
              onRollDamage: (ctx) => dispatchRoll(ctx, label: 'Divine Smite (1st Level Slot)', formula: '2d8'),
            ),
          );
        }
        if (lvl >= 3) {
          registerAction(
            CharacterCombatAction(
              id: 'paladin-channel-divinity-sacred-weapon',
              name: 'Channel Divinity: Sacred Weapon',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Paladin Level $lvl • Weapon Buff',
              description: 'As an action, imbue one weapon that you are holding with positive energy for 1 minute. Add your Charisma modifier to attack rolls made with that weapon, and it emits bright light in a 20-foot radius.',
              resourceCost: '1 Channel Divinity',
            ),
          );
          registerAction(
            CharacterCombatAction(
              id: 'paladin-channel-divinity-turn-the-unholy',
              name: 'Channel Divinity: Turn the Unholy',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Paladin Level $lvl • 30 ft Radiance',
              description: 'As an action, present your holy symbol. Each fiend or undead within 30 feet of you that can see or hear you must make a Wisdom saving throw or be turned for 1 minute or until it takes damage.',
              range: '30 ft',
              resourceCost: '1 Channel Divinity',
            ),
          );
        }
        if (lvl >= 14) {
          registerAction(
            const CharacterCombatAction(
              id: 'cleansing-touch',
              name: 'Cleansing Touch',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Paladin Level 14 • End 1 Spell',
              description: 'As an action, end one spell on yourself or on one willing creature that you touch.',
              range: 'Touch',
              resourceCost: 'Charisma Mod / Long Rest',
            ),
          );
        }
      }

      // --- RANGER ---
      if (classSlug.contains('ranger')) {
        if (lvl >= 1) {
          registerAction(
            CharacterCombatAction(
              id: 'hunters-mark',
              name: "Hunter's Mark",
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Ranger Level $lvl • 90 ft Range',
              description: 'Choose a creature you can see within 90 feet and mark it as your quarry. Deal an extra 1d6 damage to the target whenever you hit it with a weapon attack.',
              range: '90 ft',
              damageFormula: '1d6',
              dealsDamage: true,
              onRollDamage: (ctx) => dispatchRoll(ctx, label: "Hunter's Mark Extra Damage", formula: '1d6'),
            ),
          );
        }
        if (lvl >= 3) {
          registerAction(
            CharacterCombatAction(
              id: 'primeval-awareness',
              name: 'Primeval Awareness',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Ranger Level $lvl • Sense Creatures',
              description: 'As an action, expend one ranger spell slot to sense whether aberrations, celestials, dragons, elementals, fey, fiends, or undead are present within 1 mile (or 6 miles in favored terrain).',
              resourceCost: '1 Ranger Spell Slot',
            ),
          );
        }
      }

      // --- ROGUE ---
      if (classSlug.contains('rogue')) {
        if (lvl >= 1) {
          final sneakD6 = (lvl + 1) ~/ 2;
          registerAction(
            CharacterCombatAction(
              id: 'sneak-attack',
              name: 'Sneak Attack',
              actionType: ActionType.special,
              category: CombatActionCategory.feature,
              subtitle: 'Rogue Level $lvl • ${sneakD6}d6 Extra Damage',
              description: 'Once per turn, you can deal an extra ${sneakD6}d6 damage to one creature you hit with an attack if you have advantage on the attack roll, or if an ally is within 5 feet of the target.',
              damageFormula: '${sneakD6}d6',
              dealsDamage: true,
              onRollDamage: (ctx) => dispatchRoll(ctx, label: 'Sneak Attack Damage', formula: '${sneakD6}d6'),
            ),
          );
        }
        if (lvl >= 2) {
          registerAction(
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
        if (lvl >= 3) {
          registerAction(
            CharacterCombatAction(
              id: 'steady-aim',
              name: 'Steady Aim',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Rogue Level $lvl • Advantage on Next Attack',
              description: 'As a bonus action, give yourself advantage on your next attack roll on the current turn. Usable only if you haven\'t moved this turn, and your speed becomes 0 until the end of the turn.',
            ),
          );
        }
        if (lvl >= 5) {
          registerAction(
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
      }

      // --- SORCERER ---
      if (classSlug.contains('sorcerer')) {
        if (edition == DmRulesEdition.v2024 && lvl >= 1) {
          registerAction(
            CharacterCombatAction(
              id: 'innate-sorcery',
              name: 'Innate Sorcery',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Sorcerer Level $lvl • 1 Minute Surge',
              description: 'As a bonus action, unleash an aura of sorcery for 1 minute. Your spell save DC increases by 1 and you have advantage on sorcerer spell attack rolls.',
              resourceCost: '2/Long Rest',
            ),
          );
        }
        if (lvl >= 2) {
          registerAction(
            CharacterCombatAction(
              id: 'font-of-magic-flexible-casting',
              name: 'Font of Magic: Flexible Casting',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Sorcerer Level $lvl • Convert Points/Slots',
              description: 'As a bonus action, transform unexpended sorcery points into one spell slot, or expend a spell slot to gain sorcery points equal to the slot level.',
            ),
          );
        }
        if (lvl >= 3) {
          registerAction(
            const CharacterCombatAction(
              id: 'metamagic-quickened-spell',
              name: 'Metamagic: Quickened Spell',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Metamagic • 2 Sorcery Points',
              description: 'When you cast a spell that has a casting time of 1 action, you can spend 2 sorcery points to change the casting time to 1 bonus action for this casting.',
              resourceCost: '2 Sorcery Points',
            ),
          );
        }
      }

      // --- WARLOCK ---
      if (classSlug.contains('warlock')) {
        final subSlug = cls.subclassRef?.slug.toLowerCase() ?? '';
        if (subSlug.contains('hexblade')) {
          registerAction(
            CharacterCombatAction(
              id: 'hexblades-curse',
              name: "Hexblade's Curse",
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Hexblade • 30 ft Range',
              description: 'As a bonus action, curse a creature within 30 feet for 1 minute. Add +${stats.proficiencyBonus} to damage rolls, critical hit on 19-20, and heal when target dies.',
              range: '30 ft',
              resourceCost: '1/Short Rest',
            ),
          );
        }
        if (subSlug.contains('archfey')) {
          registerAction(
            const CharacterCombatAction(
              id: 'fey-presence',
              name: 'Fey Presence',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Archfey • 10 ft Cube',
              description: 'As an action, cause each creature in a 10-foot cube originating from you to make a Wisdom saving throw or become charmed or frightened until the end of your next turn.',
              resourceCost: '1/Short Rest',
            ),
          );
          if (lvl >= 6) {
            registerAction(
              const CharacterCombatAction(
                id: 'misty-escape',
                name: 'Misty Escape',
                actionType: ActionType.reaction,
                category: CombatActionCategory.feature,
                subtitle: 'Archfey • When Taking Damage',
                description: 'In response to taking damage, use your reaction to turn invisible and teleport up to 60 feet to an unoccupied space you can see.',
                range: '60 ft',
                resourceCost: '1/Short Rest',
              ),
            );
          }
        }
        final hasPactBlade = controller.hasCapabilityFlag('pact_of_the_blade') ||
            character.progression.getAllSelectedFeatureOptions().values.any((opts) => opts.any((o) => o.toLowerCase().contains('blade')));
        if (hasPactBlade) {
          registerAction(
            const CharacterCombatAction(
              id: 'pact-of-the-blade',
              name: 'Pact of the Blade: Create Pact Weapon',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Pact Boon • Magic Weapon',
              description: 'You can use your action to create a pact weapon in your empty hand. You are proficient with it while you wield it, and it counts as magical for overcoming resistance.',
            ),
          );
        }
      }

      // --- WIZARD ---
      if (classSlug.contains('wizard')) {
        if (lvl >= 1) {
          final recoveryMax = (lvl / 2).ceil();
          registerAction(
            CharacterCombatAction(
              id: 'arcane-recovery',
              name: 'Arcane Recovery',
              actionType: ActionType.action,
              category: CombatActionCategory.feature,
              subtitle: 'Wizard Level $lvl • 1/Day During Short Rest',
              description: 'Once per day when you finish a short rest, you can choose expended spell slots to recover with a combined level equal to or less than $recoveryMax (no slot can be 6th level or higher).',
              resourceCost: '1/Day (Short Rest)',
            ),
          );
        }
        final subSlug = cls.subclassRef?.slug.toLowerCase() ?? '';
        if (subSlug.contains('bladesing')) {
          registerAction(
            CharacterCombatAction(
              id: 'bladesong',
              name: 'Bladesong',
              actionType: ActionType.bonusAction,
              category: CombatActionCategory.feature,
              subtitle: 'Bladesinging • 1 Minute Song',
              description: 'You can use a bonus action to start the Bladesong for 1 minute. Gain bonus to AC equal to INT mod, walking speed +10 ft, advantage on Acrobatics checks, and bonus to CON concentration saves.',
              resourceCost: '${stats.proficiencyBonus}/Long Rest',
            ),
          );
        }
        if (subSlug.contains('divination')) {
          registerAction(
            const CharacterCombatAction(
              id: 'portent',
              name: 'Portent',
              actionType: ActionType.special,
              category: CombatActionCategory.feature,
              subtitle: 'School of Divination • Foretold Rolls',
              description: 'When you or a creature you can see makes an attack roll, saving throw, or ability check, you can replace the roll with one of your foretold portent dice before the roll is made.',
              resourceCost: '2/Long Rest',
            ),
          );
        }
      }
    }

    // ==========================================
    // 4. FIGHTING STYLE REACTIONS
    // ==========================================
    final hasProtection = controller.hasCapabilityFlag('hasProtectionReaction') ||
        character.progression.classes.any((cls) {
          final classSlug = cls.classRef.slug.toLowerCase();
          final isFightingStyleClass = classSlug == 'fighter' || classSlug == 'paladin' || classSlug == 'ranger';
          if (!isFightingStyleClass) return false;
          return cls.selectedFeatureOptions.entries.any((entry) =>
              (entry.key.toLowerCase().contains('fighting-style') || entry.key.toLowerCase().contains('fighting_style')) &&
              entry.value.any((v) => v.toLowerCase() == 'protection' || v.toLowerCase() == 'fighting_style_protection'));
        }) ||
        character.feats.any((f) {
          final slug = f.slug.toLowerCase();
          final name = f.displayName.toLowerCase();
          return slug == 'fighting-style-protection' ||
              slug == 'fighting_style_protection' ||
              name == 'fighting style: protection' ||
              name == 'fighting style (protection)';
        });

    if (hasProtection) {
      registerAction(
        const CharacterCombatAction(
          id: 'fighting-style-protection',
          name: 'Fighting Style: Protection',
          actionType: ActionType.reaction,
          category: CombatActionCategory.feature,
          subtitle: 'Fighting Style • Reaction (Requires Shield)',
          description: 'When a creature you can see attacks a target other than you that is within 5 feet of you, you can use your reaction to impose disadvantage on the attack roll.',
        ),
      );
    }

    final hasInterception = controller.hasCapabilityFlag('hasInterceptionReaction') ||
        character.progression.classes.any((cls) {
          final classSlug = cls.classRef.slug.toLowerCase();
          final isFightingStyleClass = classSlug == 'fighter' || classSlug == 'paladin' || classSlug == 'ranger';
          if (!isFightingStyleClass) return false;
          return cls.selectedFeatureOptions.entries.any((entry) =>
              (entry.key.toLowerCase().contains('fighting-style') || entry.key.toLowerCase().contains('fighting_style')) &&
              entry.value.any((v) => v.toLowerCase() == 'interception' || v.toLowerCase() == 'fighting_style_interception'));
        }) ||
        character.feats.any((f) {
          final slug = f.slug.toLowerCase();
          final name = f.displayName.toLowerCase();
          return slug == 'fighting-style-interception' ||
              slug == 'fighting_style_interception' ||
              name == 'fighting style: interception' ||
              name == 'fighting style (interception)';
        });

    if (hasInterception) {
      registerAction(
        CharacterCombatAction(
          id: 'fighting-style-interception',
          name: 'Fighting Style: Interception',
          actionType: ActionType.reaction,
          category: CombatActionCategory.feature,
          subtitle: 'Fighting Style • Reaction (Requires Shield or Weapon)',
          description: 'When a creature you can see hits a target within 5 feet of you with an attack, you can use your reaction to reduce the damage by 1d10 + ${stats.proficiencyBonus}.',
          damageFormula: '1d10+${stats.proficiencyBonus}',
          onExecute: (ctx) => dispatchRoll(ctx, label: 'Interception Damage Reduction', formula: '1d10+${stats.proficiencyBonus}'),
        ),
      );
    }

    // ==========================================
    // 5. DYNAMIC HOMEBREW, SUBCLASS & CUSTOM FEATURE EXTRACTION
    // ==========================================
    for (final cls in character.progression.classes) {
      // 1. Resolve Class
      final srdClass = SrdClassesLibrary.findBySlug(cls.classRef.slug) ??
          SrdClassesLibrary.allClasses.where((c) =>
              c.id.slug == cls.classRef.slug ||
              c.name.toLowerCase() == cls.classRef.displayName.toLowerCase(),
          ).firstOrNull;

      if (srdClass != null && srdClass.featuresMarkdown.isNotEmpty) {
        _extractActionsFromMarkdown(
          markdown: srdClass.featuresMarkdown,
          classLevel: cls.level,
          sourceName: cls.classRef.displayName,
          dispatchRoll: dispatchRoll,
          registerAction: registerAction,
        );
      }

      // Check class rawJson
      if (srdClass?.customProperties['rawJson'] != null) {
        _extractActionsFromJson(
          rawJson: srdClass!.customProperties['rawJson'],
          classLevel: cls.level,
          sourceName: cls.classRef.displayName,
          dispatchRoll: dispatchRoll,
          registerAction: registerAction,
        );
      }

      // 2. Resolve Subclass (if selected)
      if (cls.subclassRef != null) {
        final subSlug = cls.subclassRef!.slug.toLowerCase().trim();
        final subDisplayName = cls.subclassRef!.displayName.trim();
        final subNameLower = subDisplayName.toLowerCase();

        final resolvedSubclass = SrdClassesLibrary.allSubclasses.where((s) =>
            s.id.slug.toLowerCase().trim() == subSlug ||
            s.name.toLowerCase().trim() == subNameLower ||
            s.shortName.toLowerCase().trim() == subNameLower,
        ).firstOrNull;

        final subName = resolvedSubclass?.name ?? subDisplayName;
        if (resolvedSubclass != null && resolvedSubclass.featuresMarkdown.isNotEmpty) {
          _extractActionsFromMarkdown(
            markdown: resolvedSubclass.featuresMarkdown,
            classLevel: cls.level,
            sourceName: subName,
            dispatchRoll: dispatchRoll,
            registerAction: registerAction,
          );
        }

        // Check subclass rawJson
        if (resolvedSubclass?.customProperties['rawJson'] != null) {
          _extractActionsFromJson(
            rawJson: resolvedSubclass!.customProperties['rawJson'],
            classLevel: cls.level,
            sourceName: subName,
            dispatchRoll: dispatchRoll,
            registerAction: registerAction,
          );
        }
      }

      // 3. Selected Feature Options (Invocations, Metamagic, Custom options)
      for (final optionIdList in cls.selectedFeatureOptions.values) {
        for (final optId in optionIdList) {
          final opt = SrdFeatureOptions.allOptions.where(
            (o) => o.id == optId || o.id == optId.replaceAll('-', '_') || o.name.toLowerCase() == optId.toLowerCase(),
          ).firstOrNull;

          if (opt != null && opt.descriptionMarkdown.isNotEmpty) {
            _extractActionsFromMarkdown(
              markdown: '**${opt.name}.** ${opt.descriptionMarkdown}',
              classLevel: cls.level,
              sourceName: opt.name,
              dispatchRoll: dispatchRoll,
              registerAction: registerAction,
            );
          }
        }
      }
    }

    // 4. Character-level custom properties / homebrew entries
    if (character.customProperties['rawJson'] != null) {
      _extractActionsFromJson(
        rawJson: character.customProperties['rawJson'],
        classLevel: character.totalLevel,
        sourceName: 'Custom Feature',
        dispatchRoll: dispatchRoll,
        registerAction: registerAction,
      );
    }

    // ==========================================
    // 6. STANDARD REACTIONS (OPPORTUNITY ATTACK)
    // ==========================================
    registerAction(
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

  static ActionType? _detectActionType(String title, String body) {
    final combined = '$title\n$body'.toLowerCase();

    // 1. Bonus Action patterns
    final baRegex = RegExp(
      r'\b(?:as\s+a|takes?\s+a|use\s+(?:your\s+)?a?)\s*bonus\s*action\b|\bbonus\s*action\s*(?::|to\b)|\ba\s*bonus\s*action\s*on\s*each\s*of\s*your\s*turns\b|\bcasting\s*time:\s*1\s*bonus\s*action\b',
    );
    if (baRegex.hasMatch(combined) || title.toLowerCase().contains('(bonus action)')) {
      return ActionType.bonusAction;
    }

    // 2. Reaction patterns
    final rxRegex = RegExp(
      r'\b(?:as\s+a|takes?\s+a|use\s+(?:your\s+)?a?)\s*reaction\b|\breaction\s*(?::|when\b|to\b)|\bin\s*response\s*to\b|\bwhen\s+a\s+creature\b.*\breaction\b|\bwhen\s+you\s+(?:are\s+hit|take\s+damage)\b|\bcasting\s*time:\s*1\s*reaction\b',
    );
    if (rxRegex.hasMatch(combined) || title.toLowerCase().contains('(reaction)')) {
      return ActionType.reaction;
    }

    // 3. Action patterns
    final actRegex = RegExp(
      r'\b(?:as\s+an|takes?\s+an|use\s+(?:your\s+)?an?)\s*action\b|\baction\s*(?::|to\b)|\b1\s*action\b|\byou\s*can\s*use\s*your\s*action\b|\byou\s+can\s+cast\b',
    );
    if (actRegex.hasMatch(combined) || title.toLowerCase().contains('(action)')) {
      return ActionType.action;
    }

    // 4. Special / Free / On-Hit patterns
    final spRegex = RegExp(
      r'\bonce\s+(?:per|on\s+each\s+of\s+your)\s+turn\b|\bwhen\s+you\s+hit\b|\bfree\s+action\b|\bno\s+action\s+required\b',
    );
    if (spRegex.hasMatch(combined)) {
      return ActionType.special;
    }

    return null;
  }

  static void _extractActionsFromMarkdown({
    required String markdown,
    required int classLevel,
    required String sourceName,
    required void Function(BuildContext context, {required String label, required String formula}) dispatchRoll,
    required void Function(CharacterCombatAction action) registerAction,
  }) {
    if (markdown.trim().isEmpty) return;

    // Pattern 1: Header blocks (### Feature Name (Level X) or ## Feature Name)
    if (markdown.contains(RegExp(r'(?:^|\n)#{1,4}\s+'))) {
      final blocks = markdown.split(RegExp(r'(?=(?:^|\n)#{1,4}\s+)'));
      for (final block in blocks) {
        final trimmed = block.trim();
        if (trimmed.isEmpty) continue;
        final lines = trimmed.split('\n');
        final headerLine = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();

        // Extract level if present in header
        final levelMatch = RegExp(r'^(.*?)(?:\s*\((?:Level|Lvl)?\s*(\d+)(?:st|nd|rd|th)?(?:\s*Level)?\))?(?:\s*:\s*)?$', caseSensitive: false).firstMatch(headerLine);
        final name = levelMatch?.group(1)?.trim() ?? headerLine;
        final headerLevel = levelMatch?.group(2) != null ? int.tryParse(levelMatch!.group(2)!) : null;
        final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';

        _processExtractedBlock(
          rawName: name,
          body: body.isNotEmpty ? body : trimmed,
          explicitLevel: headerLevel,
          classLevel: classLevel,
          sourceName: sourceName,
          dispatchRoll: dispatchRoll,
          registerAction: registerAction,
        );
      }
      return;
    }

    // Pattern 2: Bold lead-in blocks: **Feature Name.** Description...
    final boldRegex = RegExp(r'(?:^|\n)\s*(?:[-*]\s*)?\*\*([^*]+?)(?:\.|\:)?\*\*\s*([\s\S]*?)(?=(?:\n\s*(?:[-*]\s*)?\*\*[^*]+?(?:\.|\:)?\*\*)|$)');
    final boldMatches = boldRegex.allMatches(markdown).toList();
    if (boldMatches.isNotEmpty) {
      for (final match in boldMatches) {
        final rawTitle = match.group(1)?.trim() ?? '';
        final body = match.group(2)?.trim() ?? '';
        _processExtractedBlock(
          rawName: rawTitle,
          body: body,
          explicitLevel: null,
          classLevel: classLevel,
          sourceName: sourceName,
          dispatchRoll: dispatchRoll,
          registerAction: registerAction,
        );
      }
      return;
    }

    // Pattern 3: Colon / Dash list items: Feature Name: Description or - Feature Name: Description
    final listRegex = RegExp(r"""(?:^|\n)\s*(?:[-*]\s*)?([A-Z][A-Za-z0-9\s\(\)'-]+?):\s*([^\n]+(?:\n(?!\s*(?:[-*]\s*)?[A-Z][A-Za-z0-9\s\(\)'-]+?:)[^\n]+)*)""");
    final listMatches = listRegex.allMatches(markdown).toList();
    if (listMatches.isNotEmpty) {
      for (final match in listMatches) {
        final rawTitle = match.group(1)?.trim() ?? '';
        final body = match.group(2)?.trim() ?? '';
        _processExtractedBlock(
          rawName: rawTitle,
          body: body,
          explicitLevel: null,
          classLevel: classLevel,
          sourceName: sourceName,
          dispatchRoll: dispatchRoll,
          registerAction: registerAction,
        );
      }
    }
  }

  static void _processExtractedBlock({
    required String rawName,
    required String body,
    int? explicitLevel,
    required int classLevel,
    required String sourceName,
    required void Function(BuildContext context, {required String label, required String formula}) dispatchRoll,
    required void Function(CharacterCombatAction action) registerAction,
  }) {
    if (rawName.isEmpty || body.isEmpty) return;

    // Clean up name
    var cleanName = rawName.replaceAll(RegExp(r'[:#*]'), '').trim();
    int? detectedLevel = explicitLevel;

    // Check level in name: e.g. "Astral Jaunt (Level 3)" or "Astral Jaunt (3rd Level)"
    final nameLvlMatch = RegExp(r'(.*?)(?:\s*\((?:Level|Lvl)?\s*(\d+)(?:st|nd|rd|th)?(?:\s*Level)?\))', caseSensitive: false).firstMatch(cleanName);
    if (nameLvlMatch != null) {
      cleanName = nameLvlMatch.group(1)?.trim() ?? cleanName;
      detectedLevel ??= int.tryParse(nameLvlMatch.group(2) ?? '');
    }

    // Check level in body: e.g. "starting at 3rd level"
    if (detectedLevel == null) {
      final bodyLvlMatch = RegExp(r'(?:starting at|beginning at|at|when you reach)\s+(\d+)(?:st|nd|rd|th)\s+level', caseSensitive: false).firstMatch(body);
      if (bodyLvlMatch != null) {
        detectedLevel = int.tryParse(bodyLvlMatch.group(1) ?? '');
      }
    }

    // Level-gate check: if level required is higher than current class level, skip
    if (detectedLevel != null && detectedLevel > classLevel) {
      return;
    }

    // Passive names filter
    final lowerName = cleanName.toLowerCase();
    const passiveFilter = {
      'hit points',
      'proficiencies',
      'equipment',
      'ability score improvement',
      'spellcasting',
      'pact magic',
      'jack of all trades',
      'unarmored defense',
      'danger sense',
      'extra attack',
      'aura of protection',
      'aura of courage',
      'fast movement',
      'feral instinct',
      'brutal critical',
      'indomitable might',
      'primal champion',
      'song of rest',
      'magical secrets',
      'destroy undead',
      'timeless body',
      'purity of body',
      'diamond soul',
      'reliable talent',
      'blindsense',
      'slippery mind',
      'stroke of luck',
      'feral senses',
      'foe slayer',
    };
    if (passiveFilter.contains(lowerName)) return;

    final actionType = _detectActionType(cleanName, body);
    if (actionType == null) return;

    // Extract damage formula if present
    final dmgMatch = RegExp(r'(\d+d\d+(?:\s*[+-]\s*\d+)?)').firstMatch(body);
    final formula = dmgMatch?.group(1);

    // Extract damage type if present (prioritize "<type> damage" over loose words)
    DamageType dmgType = DamageType.untyped;
    final lowerBody = body.toLowerCase();
    for (final dt in DamageType.values) {
      if (dt == DamageType.untyped) continue;
      if (RegExp('\\b${dt.name}\\s+damage\\b', caseSensitive: false).hasMatch(lowerBody)) {
        dmgType = dt;
        break;
      }
    }
    if (dmgType == DamageType.untyped) {
      for (final dt in DamageType.values) {
        if (dt == DamageType.untyped) continue;
        if (RegExp('\\b${dt.name}\\b', caseSensitive: false).hasMatch(lowerBody)) {
          dmgType = dt;
          break;
        }
      }
    }

    // Extract resource cost if present
    String? resourceCost;
    final resMatch = RegExp(r'\b(1\/(?:short\s+or\s+long\s+rest|short\s+rest|long\s+rest|day))\b', caseSensitive: false).firstMatch(body);
    if (resMatch != null) {
      resourceCost = resMatch.group(1);
    }

    final slug = cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final lvlSubtitle = detectedLevel != null ? 'Level $detectedLevel' : 'Level $classLevel';
    final typeLabel = actionType == ActionType.bonusAction
        ? 'Bonus Action'
        : (actionType == ActionType.reaction ? 'Reaction' : (actionType == ActionType.special ? 'Special' : 'Action'));

    registerAction(
      CharacterCombatAction(
        id: 'feature-$slug',
        name: cleanName,
        actionType: actionType,
        category: CombatActionCategory.feature,
        subtitle: '$sourceName • $typeLabel • $lvlSubtitle',
        description: body.trim(),
        damageFormula: formula,
        damageType: formula != null ? dmgType : null,
        dealsDamage: formula != null,
        resourceCost: resourceCost,
        onRollDamage: formula != null
            ? (ctx) => dispatchRoll(ctx, label: '$cleanName Damage', formula: formula)
            : null,
      ),
    );
  }

  static void _extractActionsFromJson({
    required dynamic rawJson,
    required int classLevel,
    required String sourceName,
    required void Function(BuildContext context, {required String label, required String formula}) dispatchRoll,
    required void Function(CharacterCombatAction action) registerAction,
  }) {
    if (rawJson == null) return;

    List entriesList = [];
    if (rawJson is Map) {
      final cf = rawJson['classFeatures'] ?? rawJson['subclassFeatures'] ?? rawJson['entries'];
      if (cf is List) entriesList = cf;
    } else if (rawJson is List) {
      entriesList = rawJson;
    }

    for (final entry in entriesList) {
      if (entry is Map) {
        final name = entry['name']?.toString() ?? '';
        final level = (entry['level'] as num?)?.toInt() ?? (entry['subclassLevel'] as num?)?.toInt();
        final rawBody = entry['entries'];
        String bodyText = '';
        if (rawBody is List) {
          bodyText = rawBody.map((e) => e is Map ? (e['name'] != null ? '${e['name']}: ${e['entries'] ?? ''}' : e.toString()) : e.toString()).join('\n');
        } else if (rawBody != null) {
          bodyText = rawBody.toString();
        }

        if (name.isNotEmpty && bodyText.isNotEmpty) {
          _processExtractedBlock(
            rawName: name,
            body: bodyText,
            explicitLevel: level,
            classLevel: classLevel,
            sourceName: sourceName,
            dispatchRoll: dispatchRoll,
            registerAction: registerAction,
          );
        }
      }
    }
  }
}
