import 'package:flutter/material.dart';
import 'arena_action_result.dart';
import 'arena_combatant.dart';

/// Interactive environmental battlegrounds altering combat rules and mobility.
enum ArenaEnvironment {
  colosseum(
    'Open Colosseum',
    'Open-air arena with standard ground and unobstructed airspace.',
    Icons.stadium_outlined,
    Color(0xFFC084FC),
    [
      '☀️ Open Airspace',
      '🦅 Full Flight Mobility',
      '⚔️ Standard Combat Rules',
    ],
  ),
  cageMatch(
    'Iron Cage Match',
    'Enclosed iron cage with a 10-ft ceiling. Flight is grounded, close-quarters melee is prioritized, and ranged attacks suffer disadvantage.',
    Icons.grid_4x4,
    Color(0xFF94A3B8),
    [
      '🚫 Flight Grounded',
      '⚔️ Close-Quarters Melee Focused',
      '🎯 Close Combat Ranged Disadvantage',
    ],
  ),
  floodedAbyss(
    'Flooded Abyss (Water Match)',
    'Submerged aquatic arena. Creatures with Swim speed gain Advantage; non-swimmers suffer Disadvantage and fire damage is halved.',
    Icons.water,
    Color(0xFF38BDF8),
    [
      '🏊 Swim Speed Advantage',
      '⚠️ Non-Swimmer Disadvantage',
      '🛡️ Submerged Fire Resistance',
    ],
  ),
  volcanicPit(
    'Volcanic Caldera',
    'Lava-surrounded pit. Extreme elemental heat favors fire-resistant and immune combatants.',
    Icons.local_fire_department,
    Color(0xFFF97316),
    [
      '🌋 Magma Pit Hazard',
      '🔥 Elemental Fire Aura',
    ],
  );

  final String label;
  final String description;
  final IconData icon;
  final Color themeColor;
  final List<String> mechanicTags;

  const ArenaEnvironment(
    this.label,
    this.description,
    this.icon,
    this.themeColor,
    this.mechanicTags,
  );
}

/// Targeting strategy used by AI combatants in the Arena.
enum ArenaTargetingStrategy {
  focusLowestHp('Focus Fire (Lowest HP)', 'Focuses attacks on the weakest living enemy to eliminate them quickly.'),
  randomEnemy('Random Target', 'Attacks a random living enemy combatant each round.'),
  highestThreat('Highest Threat (Highest CR)', 'Targets the most dangerous enemy with the highest Challenge Rating or max HP.');

  final String label;
  final String description;
  const ArenaTargetingStrategy(this.label, this.description);
}

/// Simulation run state.
enum ArenaSimulationStatus {
  setup,
  playing,
  paused,
  finished,
}

/// Final outcome of a single simulated battle.
class ArenaSimulationResult {
  final ArenaTeam? winner; // null if draw / round cap reached
  final int totalRounds;
  final List<ArenaTurnStep> steps;
  final List<ArenaCombatant> finalCombatants;
  final ArenaCombatant? mvpCombatant;
  final int teamATotalDamage;
  final int teamBTotalDamage;
  final int teamAKills;
  final int teamBKills;

  const ArenaSimulationResult({
    required this.winner,
    required this.totalRounds,
    required this.steps,
    required this.finalCombatants,
    this.mvpCombatant,
    required this.teamATotalDamage,
    required this.teamBTotalDamage,
    required this.teamAKills,
    required this.teamBKills,
  });

  bool get isDraw => winner == null;
  List<ArenaCombatant> get survivingTeamA =>
      finalCombatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).toList();
  List<ArenaCombatant> get survivingTeamB =>
      finalCombatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).toList();
}

/// Statistical outcome aggregated across many Monte Carlo iterations.
class ArenaMonteCarloResult {
  final int iterations;
  final int teamAWins;
  final int teamBWins;
  final int draws;
  final double averageRounds;
  final int minRounds;
  final int maxRounds;
  final double avgTeamASurvivors;
  final double avgTeamBSurvivors;
  final double avgTeamASurvivingHpPercent;
  final double avgTeamBSurvivingHpPercent;
  final Duration calculationDuration;

  const ArenaMonteCarloResult({
    required this.iterations,
    required this.teamAWins,
    required this.teamBWins,
    required this.draws,
    required this.averageRounds,
    required this.minRounds,
    required this.maxRounds,
    required this.avgTeamASurvivors,
    required this.avgTeamBSurvivors,
    required this.avgTeamASurvivingHpPercent,
    required this.avgTeamBSurvivingHpPercent,
    required this.calculationDuration,
  });

  double get teamAWinRate => iterations > 0 ? (teamAWins / iterations) * 100 : 0.0;
  double get teamBWinRate => iterations > 0 ? (teamBWins / iterations) * 100 : 0.0;
  double get drawRate => iterations > 0 ? (draws / iterations) * 100 : 0.0;
}
