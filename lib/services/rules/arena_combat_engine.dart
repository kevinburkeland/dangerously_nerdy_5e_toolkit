import 'dart:math';

import '../../models/arena/arena_action_result.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/arena/arena_simulation_models.dart';
import '../../models/dm_screen_data.dart';
import '../../models/dpr/dpr_models.dart';
import 'arena/arena_attack_resolver.dart';
import 'arena/arena_cantrip_resolver.dart';
import 'arena/arena_combat_context.dart';
import 'arena/arena_legendary_action_resolver.dart';
import 'arena/arena_simulation_runner.dart';
import 'arena_combat_engine_async.dart';

export 'arena/arena_challenge_rating_validator.dart'
    show InvalidArenaChallengeRatingException;

/// Comprehensive 5e Combat Resolution & Simulation Engine for the Monster Fighting Arena.
class ArenaCombatEngine {
  final ArenaCombatContext _ctx;
  final ArenaSimulationRunner _runner;
  final ArenaLegendaryActionResolver _legendary;

  factory ArenaCombatEngine({Random? rng}) =>
      ArenaCombatEngine._(ArenaCombatContext(rng: rng));

  ArenaCombatEngine._(this._ctx)
      : _runner = ArenaSimulationRunner(_ctx),
        _legendary = ArenaLegendaryActionResolver(
          _ctx,
          ArenaAttackResolver(_ctx),
          ArenaCantripResolver(_ctx),
        );

  /// Rolls 1d20 + initiative bonus for each combatant and returns sorted order.
  List<ArenaCombatant> rollInitiatives(
    List<ArenaCombatant> combatants,
  ) =>
      _ctx.rollInitiatives(combatants);

  /// Selects the best target for an attacker based on chosen [ArenaTargetingStrategy] and reach validation.
  ArenaCombatant? selectTarget(
    ArenaCombatant attacker,
    List<ArenaCombatant> allCombatants,
    ArenaTargetingStrategy strategy, [
    DprAttackAction? attack,
  ]) =>
      _ctx.selectTarget(attacker, allCombatants, strategy, attack);

  /// Executes a single combatant's turn, returning a structured [ArenaTurnStep].
  ArenaTurnStep executeTurn({
    required int stepIndex,
    required int roundNumber,
    required ArenaCombatant attacker,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) =>
      _runner.executeTurn(
        stepIndex: stepIndex,
        roundNumber: roundNumber,
        attacker: attacker,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );

  /// Evaluates and executes off-turn Legendary Actions for living opposing legendary combatants
  /// at the end of another creature's turn.
  List<ArenaAttackEvent> executeOffTurnLegendaryActions({
    required ArenaCombatant turnCombatant,
    required List<ArenaCombatant> allCombatants,
    required ArenaTargetingStrategy strategy,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
  }) =>
      _legendary.executeOffTurnLegendaryActions(
        turnCombatant: turnCombatant,
        allCombatants: allCombatants,
        strategy: strategy,
        edition: edition,
        environment: environment,
      );

  /// Simulates an entire battle to the end, returning all round steps and final result.
  ArenaSimulationResult simulateMatch({
    required List<ArenaCombatant> initialTeamA,
    required List<ArenaCombatant> initialTeamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int maxRounds = 50,
  }) =>
      _runner.simulateMatch(
        initialTeamA: initialTeamA,
        initialTeamB: initialTeamB,
        strategy: strategy,
        edition: edition,
        environment: environment,
        maxRounds: maxRounds,
      );

  /// High-speed Monte Carlo simulation running [iterations] times to determine exact win rates.
  ArenaMonteCarloResult runMonteCarlo({
    required List<ArenaCombatant> teamA,
    required List<ArenaCombatant> teamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int iterations = 500,
    int maxRounds = 50,
  }) =>
      _runner.runMonteCarlo(
        teamA: teamA,
        teamB: teamB,
        strategy: strategy,
        edition: edition,
        environment: environment,
        iterations: iterations,
        maxRounds: maxRounds,
      );

  /// High-speed Monte Carlo simulation running [iterations] times offloaded to a background isolate.
  Future<ArenaMonteCarloResult> runMonteCarloAsync({
    required List<ArenaCombatant> teamA,
    required List<ArenaCombatant> teamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int iterations = 500,
    int maxRounds = 50,
    int? seed,
  }) =>
      runArenaMonteCarloAsync(
        teamA: teamA,
        teamB: teamB,
        strategy: strategy,
        edition: edition,
        environment: environment,
        iterations: iterations,
        maxRounds: maxRounds,
        seed: seed,
      );

  /// Simulates a complete pit fight match to completion offloaded to a background isolate.
  Future<ArenaSimulationResult> simulateMatchAsync({
    required List<ArenaCombatant> initialTeamA,
    required List<ArenaCombatant> initialTeamB,
    ArenaTargetingStrategy strategy = ArenaTargetingStrategy.focusLowestHp,
    DmRulesEdition edition = DmRulesEdition.v2024,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int maxRounds = 50,
    int? seed,
  }) =>
      simulateArenaMatchAsync(
        initialTeamA: initialTeamA,
        initialTeamB: initialTeamB,
        strategy: strategy,
        edition: edition,
        environment: environment,
        maxRounds: maxRounds,
        seed: seed,
      );
}
