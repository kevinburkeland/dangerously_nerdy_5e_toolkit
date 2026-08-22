import 'arena_combatant.dart';

/// Represents a single attack roll and damage outcome within a turn.
class ArenaAttackEvent {
  final String attackerId;
  final String attackerName;
  final ArenaTeam attackerTeam;
  final String defenderId;
  final String defenderName;
  final ArenaTeam defenderTeam;
  final String attackName;
  final int d20Roll;
  final int attackBonus;
  final int totalAttack;
  final int targetAc;
  final bool isHit;
  final bool isCrit;
  final bool isFumble;
  final bool hadAdvantage;
  final bool hadDisadvantage;
  final int damageDealt;
  final String damageType;
  final bool isKillShot;
  final int defenderRemainingHp;
  final int defenderMaxHp;
  final String summaryText;

  const ArenaAttackEvent({
    required this.attackerId,
    required this.attackerName,
    required this.attackerTeam,
    required this.defenderId,
    required this.defenderName,
    required this.defenderTeam,
    required this.attackName,
    required this.d20Roll,
    required this.attackBonus,
    required this.totalAttack,
    required this.targetAc,
    required this.isHit,
    this.isCrit = false,
    this.isFumble = false,
    this.hadAdvantage = false,
    this.hadDisadvantage = false,
    required this.damageDealt,
    required this.damageType,
    this.isKillShot = false,
    required this.defenderRemainingHp,
    required this.defenderMaxHp,
    required this.summaryText,
  });
}

/// Represents a single turn taken by a combatant, which may contain multiple attacks or recharge events.
class ArenaTurnStep {
  final int stepIndex;
  final int roundNumber;
  final ArenaCombatant activeCombatant;
  final List<ArenaAttackEvent> attackEvents;
  final String? specialEventSummary; // e.g. "Recharge succeeded!" or "Defeated"
  final Map<String, int> combatantHpSnapshot; // combatantId -> currentHp

  const ArenaTurnStep({
    required this.stepIndex,
    required this.roundNumber,
    required this.activeCombatant,
    required this.attackEvents,
    this.specialEventSummary,
    required this.combatantHpSnapshot,
  });

  bool get hasAttacks => attackEvents.isNotEmpty;
  int get totalDamageThisTurn =>
      attackEvents.fold(0, (sum, event) => sum + event.damageDealt);
  int get killsThisTurn =>
      attackEvents.where((e) => e.isKillShot).length;
}
