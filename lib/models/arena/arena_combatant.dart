import 'package:flutter/material.dart';
import '../dm_screen_data.dart';
import '../monster_codex_data.dart';
import '../srd_summons/minion_stat_block.dart';

/// Which team the combatant belongs to in the Arena.
enum ArenaTeam {
  teamA('Team Crimson', Color(0xFFEF4444), Icons.shield_moon),
  teamB('Team Cobalt', Color(0xFF3B82F6), Icons.shield_outlined);

  final String label;
  final Color color;
  final IconData icon;
  const ArenaTeam(this.label, this.color, this.icon);

  ArenaTeam get opponent => this == ArenaTeam.teamA ? ArenaTeam.teamB : ArenaTeam.teamA;
}

/// Represents a single active instance of a monster in the Arena.
class ArenaCombatant {
  final String id;
  final MonsterItem monster;
  final ArenaTeam team;
  final String displayName;
  final int maxHp;
  int currentHp;
  int tempHp;
  final int ac;
  final int initiativeBonus;
  int initiative;
  bool isRechargeReady;

  // Tracked combat stats
  int totalDamageDealt;
  int totalDamageTaken;
  int kills;
  int attacksMade;
  int hitsLanded;
  int critsLanded;

  ArenaCombatant({
    required this.id,
    required this.monster,
    required this.team,
    required this.displayName,
    required this.maxHp,
    required this.currentHp,
    this.tempHp = 0,
    required this.ac,
    required this.initiativeBonus,
    this.initiative = 0,
    this.isRechargeReady = true,
    this.totalDamageDealt = 0,
    this.totalDamageTaken = 0,
    this.kills = 0,
    this.attacksMade = 0,
    this.hitsLanded = 0,
    this.critsLanded = 0,
  });

  /// Factory constructor to create a fresh combatant from a [MonsterItem].
  factory ArenaCombatant.fromMonster({
    required String id,
    required MonsterItem monster,
    required ArenaTeam team,
    String? customName,
    DmRulesEdition edition = DmRulesEdition.v2024,
    int? hpOverride,
    int? acOverride,
  }) {
    final sb = monster.getStatBlock(edition);
    final initBonus = sb.dexMod;
    final maxHp = hpOverride ?? sb.maxHp;
    final ac = acOverride ?? sb.ac;
    final name = customName ?? monster.getName(edition);

    return ArenaCombatant(
      id: id,
      monster: monster,
      team: team,
      displayName: name,
      maxHp: maxHp > 0 ? maxHp : 1,
      currentHp: maxHp > 0 ? maxHp : 1,
      ac: ac > 0 ? ac : 10,
      initiativeBonus: initBonus,
      isRechargeReady: true,
    );
  }

  bool get isAlive => currentHp > 0;
  bool get isDefeated => currentHp <= 0;
  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  /// Clones combatant with fresh max HP and reset combat counters.
  ArenaCombatant reset() {
    return ArenaCombatant(
      id: id,
      monster: monster,
      team: team,
      displayName: displayName,
      maxHp: maxHp,
      currentHp: maxHp,
      tempHp: 0,
      ac: ac,
      initiativeBonus: initiativeBonus,
      initiative: 0,
      isRechargeReady: true,
      totalDamageDealt: 0,
      totalDamageTaken: 0,
      kills: 0,
      attacksMade: 0,
      hitsLanded: 0,
      critsLanded: 0,
    );
  }

  /// Deep copy for simulation state snapshots.
  ArenaCombatant clone() {
    return ArenaCombatant(
      id: id,
      monster: monster,
      team: team,
      displayName: displayName,
      maxHp: maxHp,
      currentHp: currentHp,
      tempHp: tempHp,
      ac: ac,
      initiativeBonus: initiativeBonus,
      initiative: initiative,
      isRechargeReady: isRechargeReady,
      totalDamageDealt: totalDamageDealt,
      totalDamageTaken: totalDamageTaken,
      kills: kills,
      attacksMade: attacksMade,
      hitsLanded: hitsLanded,
      critsLanded: critsLanded,
    );
  }

  /// Applies damage with temporary HP buffering.
  int applyDamage(int damage) {
    if (damage <= 0 || isDefeated) return 0;
    int remaining = damage;
    if (tempHp > 0) {
      if (tempHp >= remaining) {
        tempHp -= remaining;
        remaining = 0;
      } else {
        remaining -= tempHp;
        tempHp = 0;
      }
    }
    currentHp = (currentHp - remaining).clamp(0, maxHp);
    totalDamageTaken += damage;
    return damage;
  }

  /// Stat block accessor helper
  MinionStatBlock getStatBlock([DmRulesEdition edition = DmRulesEdition.v2024]) {
    return monster.getStatBlock(edition);
  }
}
