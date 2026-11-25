import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/arena/arena_combatant.dart';
import '../../models/arena/arena_simulation_models.dart';
import '../../models/dm_screen_data.dart';
import 'arena/arena_challenge_rating_validator.dart';
import 'arena/arena_combat_context.dart';
import 'arena/arena_simulation_runner.dart';

ArenaMonteCarloResult _isolateMonteCarloRunner(
  _ArenaMonteCarloPayload payload,
) {
  final ctx = ArenaCombatContext(
    rng: payload.seed != null ? Random(payload.seed) : null,
  );
  return ArenaSimulationRunner(ctx).runMonteCarlo(
    teamA: payload.teamA,
    teamB: payload.teamB,
    strategy: payload.strategy,
    edition: payload.edition,
    environment: payload.environment,
    iterations: payload.iterations,
    maxRounds: payload.maxRounds,
  );
}

ArenaSimulationResult _isolateMatchRunner(
  _ArenaMatchSimulationPayload payload,
) {
  final ctx = ArenaCombatContext(
    rng: payload.seed != null ? Random(payload.seed) : null,
  );
  return ArenaSimulationRunner(ctx).simulateMatch(
    initialTeamA: payload.teamA,
    initialTeamB: payload.teamB,
    strategy: payload.strategy,
    edition: payload.edition,
    environment: payload.environment,
    maxRounds: payload.maxRounds,
  );
}

/// High-speed Monte Carlo simulation running [iterations] times offloaded to a background isolate.
Future<ArenaMonteCarloResult> runArenaMonteCarloAsync({
  required List<ArenaCombatant> teamA,
  required List<ArenaCombatant> teamB,
  ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
  DmRulesEdition edition = DmRulesEdition.v2024,
  ArenaEnvironment environment = ArenaEnvironment.colosseum,
  int iterations = 500,
  int maxRounds = 50,
  int? seed,
}) async {
  validateArenaCombatantsChallengeRatings([...teamA, ...teamB]);
  final payload = _ArenaMonteCarloPayload(
    teamA: teamA.map((c) => c.clone()).toList(),
    teamB: teamB.map((c) => c.clone()).toList(),
    strategy: strategy,
    edition: edition,
    environment: environment,
    iterations: iterations,
    maxRounds: maxRounds,
    seed: seed,
  );
  return compute(_isolateMonteCarloRunner, payload);
}

/// Simulates a complete pit fight match to completion offloaded to a background isolate.
Future<ArenaSimulationResult> simulateArenaMatchAsync({
  required List<ArenaCombatant> initialTeamA,
  required List<ArenaCombatant> initialTeamB,
  ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
  DmRulesEdition edition = DmRulesEdition.v2024,
  ArenaEnvironment environment = ArenaEnvironment.colosseum,
  int maxRounds = 50,
  int? seed,
}) async {
  validateArenaCombatantsChallengeRatings([...initialTeamA, ...initialTeamB]);
  final payload = _ArenaMatchSimulationPayload(
    teamA: initialTeamA.map((c) => c.clone()).toList(),
    teamB: initialTeamB.map((c) => c.clone()).toList(),
    strategy: strategy,
    edition: edition,
    environment: environment,
    maxRounds: maxRounds,
    seed: seed,
  );
  return compute(_isolateMatchRunner, payload);
}

class _ArenaMonteCarloPayload {
  final List<ArenaCombatant> teamA;
  final List<ArenaCombatant> teamB;
  final ArenaTargetingStrategy strategy;
  final DmRulesEdition edition;
  final ArenaEnvironment environment;
  final int iterations;
  final int maxRounds;
  final int? seed;

  const _ArenaMonteCarloPayload({
    required this.teamA,
    required this.teamB,
    required this.strategy,
    required this.edition,
    required this.environment,
    required this.iterations,
    required this.maxRounds,
    this.seed,
  });
}

class _ArenaMatchSimulationPayload {
  final List<ArenaCombatant> teamA;
  final List<ArenaCombatant> teamB;
  final ArenaTargetingStrategy strategy;
  final DmRulesEdition edition;
  final ArenaEnvironment environment;
  final int maxRounds;
  final int? seed;

  const _ArenaMatchSimulationPayload({
    required this.teamA,
    required this.teamB,
    required this.strategy,
    required this.edition,
    required this.environment,
    required this.maxRounds,
    this.seed,
  });
}
