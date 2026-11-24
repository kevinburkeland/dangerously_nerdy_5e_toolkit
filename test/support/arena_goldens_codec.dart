import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_preset_matchups.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_simulation_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/arena_combat_engine.dart';

const String kArenaGoldensDir = 'test/fixtures/arena_goldens';
const String kPresetMatchesFile = '$kArenaGoldensDir/preset_matches.json';
const String kCreatureDuelsFile = '$kArenaGoldensDir/creature_duels.json';
const String kMonteCarloFile = '$kArenaGoldensDir/monte_carlo.json';
const String kDamageDefenseTableFile =
    '$kArenaGoldensDir/damage_defense_table.json';

const List<String> kSrdDamageTypes = <String>[
  'acid',
  'bludgeoning',
  'cold',
  'fire',
  'force',
  'lightning',
  'necrotic',
  'piercing',
  'poison',
  'psychic',
  'radiant',
  'slashing',
  'thunder',
];

const List<String> kProbedDamageTypes = <String>[
  ...kSrdDamageTypes,
  '',
  'zzz',
];

/// Returns all creatures offered by the arena monster picker (`MonsterCodexLibrary.search`),
/// plus any bundled creature at CR >= 17 if not already included, sorted deterministically
/// by `(challengeRating, id)`.
List<MonsterItem> collectArenaCreatures() {
  final byId = <String, MonsterItem>{};
  for (final m in MonsterCodexLibrary.search('', edition: DmRulesEdition.v2024)) {
    byId[m.id] = m;
  }
  for (final m in MonsterCodexLibrary.allMonsters) {
    if (m.challengeRating >= 17.0) {
      byId.putIfAbsent(m.id, () => m);
    }
  }
  final list = byId.values.toList()
    ..sort((a, b) {
      final crCmp = a.challengeRating.compareTo(b.challengeRating);
      if (crCmp != 0) return crCmp;
      return a.id.compareTo(b.id);
    });
  return list;
}

/// Deterministic opponent selection rule (not by name):
/// the median-index creature in [sortedCreatures] sorted by `(challengeRating, id)`.
MonsterItem selectFixedDuelOpponent(List<MonsterItem> sortedCreatures) {
  return sortedCreatures[sortedCreatures.length ~/ 2];
}

Map<String, Object?> serializeSimulationResult({
  required String matchKey,
  required String matchup,
  required DmRulesEdition edition,
  required ArenaEnvironment environment,
  required ArenaTargetingStrategy strategy,
  required int seed,
  required ArenaSimulationResult result,
}) {
  return <String, Object?>{
    'matchKey': matchKey,
    'matchup': matchup,
    'edition': edition.name,
    'environment': environment.name,
    'strategy': strategy.name,
    'seed': seed,
    'winner': result.winner?.name ?? 'draw',
    'totalRounds': result.totalRounds,
    'mvpName': result.mvpCombatant?.displayName,
    'teamATotalDamage': result.teamATotalDamage,
    'teamBTotalDamage': result.teamBTotalDamage,
    'teamAKills': result.teamAKills,
    'teamBKills': result.teamBKills,
    'steps': <Map<String, Object?>>[
      for (final step in result.steps)
        <String, Object?>{
          'stepSummary': step.specialEventSummary,
          'events': <String>[
            for (final ev in step.attackEvents) ev.summaryText,
          ],
        },
    ],
  };
}

Map<String, Object?> runPresetMatchRecord({
  required ArenaPresetMatchup preset,
  required DmRulesEdition edition,
  required ArenaEnvironment environment,
  required ArenaTargetingStrategy strategy,
  required int seed,
}) {
  final engine = ArenaCombatEngine(rng: Random(seed));
  final fighters = preset.resolveFighters(edition);
  final result = engine.simulateMatch(
    initialTeamA: fighters.teamA,
    initialTeamB: fighters.teamB,
    strategy: strategy,
    edition: edition,
    environment: environment,
  );
  final key =
      'preset:${preset.id}|${edition.name}|${environment.name}|${strategy.name}|seed=$seed';
  return serializeSimulationResult(
    matchKey: key,
    matchup: preset.title,
    edition: edition,
    environment: environment,
    strategy: strategy,
    seed: seed,
    result: result,
  );
}

List<Map<String, Object?>> buildAllPresetMatchRecords() {
  final records = <Map<String, Object?>>[];
  for (final preset in ArenaPresetMatchup.defaultPresets) {
    for (final edition in DmRulesEdition.values) {
      for (final env in ArenaEnvironment.values) {
        for (final strategy in ArenaTargetingStrategy.values) {
          for (final seed in const [1, 2]) {
            records.add(
              runPresetMatchRecord(
                preset: preset,
                edition: edition,
                environment: env,
                strategy: strategy,
                seed: seed,
              ),
            );
          }
        }
      }
    }
  }
  return records;
}

List<Map<String, Object?>> buildAllCreatureDuelRecords() {
  final creatures = collectArenaCreatures();
  final opponent = selectFixedDuelOpponent(creatures);
  final records = <Map<String, Object?>>[];
  for (final creature in creatures) {
    final engine = ArenaCombatEngine(rng: Random(3));
    final teamA = <ArenaCombatant>[
      ArenaCombatant.fromMonster(
        id: 'duel_a_${creature.id}',
        monster: creature,
        team: ArenaTeam.teamA,
        edition: DmRulesEdition.v2024,
      ),
    ];
    final teamB = <ArenaCombatant>[
      ArenaCombatant.fromMonster(
        id: 'duel_b_${opponent.id}',
        monster: opponent,
        team: ArenaTeam.teamB,
        edition: DmRulesEdition.v2024,
      ),
    ];
    final result = engine.simulateMatch(
      initialTeamA: teamA,
      initialTeamB: teamB,
      strategy: ArenaTargetingStrategy.focusLowestHp,
      edition: DmRulesEdition.v2024,
      environment: ArenaEnvironment.colosseum,
    );
    records.add(
      serializeSimulationResult(
        matchKey: 'duel:${creature.id}_vs_${opponent.id}|v2024|colosseum|focusLowestHp|seed=3',
        matchup: '${creature.name} vs ${opponent.name}',
        edition: DmRulesEdition.v2024,
        environment: ArenaEnvironment.colosseum,
        strategy: ArenaTargetingStrategy.focusLowestHp,
        seed: 3,
        result: result,
      ),
    );
  }
  return records;
}

List<Map<String, Object?>> buildAllMonteCarloRecords() {
  final records = <Map<String, Object?>>[];
  for (final preset in ArenaPresetMatchup.defaultPresets) {
    final engine = ArenaCombatEngine(rng: Random(11));
    final fighters = preset.resolveFighters(DmRulesEdition.v2024);
    final res = engine.runMonteCarlo(
      teamA: fighters.teamA,
      teamB: fighters.teamB,
      strategy: ArenaTargetingStrategy.focusLowestHp,
      edition: DmRulesEdition.v2024,
      environment: ArenaEnvironment.colosseum,
      iterations: 200,
    );
    records.add(<String, Object?>{
      'matchKey': 'mc:${preset.id}|v2024|colosseum|iter=200|seed=11',
      'matchup': preset.title,
      'iterations': res.iterations,
      'teamAWins': res.teamAWins,
      'teamBWins': res.teamBWins,
      'draws': res.draws,
      'averageRounds': res.averageRounds,
      'minRounds': res.minRounds,
      'maxRounds': res.maxRounds,
      'avgTeamASurvivors': res.avgTeamASurvivors,
      'avgTeamBSurvivors': res.avgTeamBSurvivors,
      'avgTeamASurvivingHpPercent': res.avgTeamASurvivingHpPercent,
      'avgTeamBSurvivingHpPercent': res.avgTeamBSurvivingHpPercent,
    });
  }
  return records;
}

/// Probes `_applyDefensiveModifiers` via the public `ArenaCombatEngine.executeTurn`
/// path using a guaranteed non-crit weapon hit dealing raw damage 101:
/// 0 -> 'immune', 50 -> 'resistant', 202 -> 'vulnerable',
/// 100 -> 'resistant+vulnerable', 101 -> 'none'.
String probeDefenseCategory({
  required MonsterItem monster,
  required DmRulesEdition edition,
  required String damageType,
  required ArenaEnvironment environment,
}) {
  final rawSb = monster.getStatBlock(edition);
  // Clone only the defense text fields onto a clean defender with high HP, low AC,
  // no spells/reactions/riders so executeTurn always lands a clean 101-damage hit.
  final probeDefenderSb = MinionStatBlock(
    id: 'probe_def_${monster.id}',
    name: monster.name,
    sizeDisplay: rawSb.sizeDisplay,
    crDisplay: rawSb.crDisplay,
    ac: 1,
    maxHp: 5000,
    attackBonus: 0,
    damageDiceCount: 0,
    damageDiceSides: 0,
    damageBonus: 0,
    damageType: 'bludgeoning',
    damageImmunities: rawSb.damageImmunities,
    damageResistances: rawSb.damageResistances,
    damageVulnerabilities: rawSb.damageVulnerabilities,
  );
  final probeDefenderMob = MonsterItem(
    id: 'probe_def_${monster.id}',
    name: monster.name,
    statBlock2014: probeDefenderSb,
    statBlock2024: probeDefenderSb,
  );

  // With actions: const [], ArenaCombatant builds a single weapon attack
  // directly from attackBonus + damageDiceCount/Sides/Bonus + damageType
  // (so even empty '' and 'zzz' damage types reach _applyDefensiveModifiers verbatim).
  // With Random(2): first nextInt(20)+1 == 13 (normal hit), next nextInt(2)+1 == 1 -> 1 + 100 = 101.
  final probeAttackerSb = MinionStatBlock(
    id: 'probe_att',
    name: 'Probe Attacker',
    sizeDisplay: 'Medium',
    crDisplay: '1',
    ac: 10,
    maxHp: 500,
    attackBonus: 1000,
    damageDiceCount: 1,
    damageDiceSides: 2,
    damageBonus: 100,
    damageType: damageType,
    actions: const [],
  );
  final probeAttackerMob = MonsterItem(
    id: 'probe_att',
    name: 'Probe Attacker',
    statBlock2014: probeAttackerSb,
    statBlock2024: probeAttackerSb,
  );

  // Always roll 11 on d20 (normal hit even with disadvantage) and 1 on 1d2 (raw = 101).
  final engine = ArenaCombatEngine(rng: _FixedNormalHitRandom());
  final attacker = ArenaCombatant.fromMonster(
    id: 'probe_att_0',
    monster: probeAttackerMob,
    team: ArenaTeam.teamA,
    edition: edition,
  );
  final defender = ArenaCombatant.fromMonster(
    id: 'probe_def_0',
    monster: probeDefenderMob,
    team: ArenaTeam.teamB,
    edition: edition,
  );

  final step = engine.executeTurn(
    stepIndex: 0,
    roundNumber: 1,
    attacker: attacker,
    allCombatants: [attacker, defender],
    strategy: ArenaTargetingStrategy.focusLowestHp,
    edition: edition,
    environment: environment,
  );

  if (step.attackEvents.isEmpty || !step.attackEvents.first.isHit || step.attackEvents.first.isCrit) {
    throw StateError(
      'Defense probe did not land a normal hit for ${monster.id} (${edition.name}, "$damageType"): '
      'events=${step.attackEvents.length}',
    );
  }

  final dmg = step.attackEvents.first.damageDealt;
  return switch (dmg) {
    0 => 'immune',
    50 => 'resistant',
    202 => 'vulnerable',
    100 => 'resistant+vulnerable',
    101 => 'none',
    _ => throw StateError(
        'Unexpected probe damage $dmg for ${monster.id} (${edition.name}, "$damageType", ${environment.name})',
      ),
  };
}

List<Map<String, Object?>> buildDamageDefenseTableRows() {
  final monsters = MonsterCodexLibrary.allMonsters.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final rows = <Map<String, Object?>>[];
  for (final monster in monsters) {
    for (final edition in DmRulesEdition.values) {
      for (final dmgType in kProbedDamageTypes) {
        final colosseum = probeDefenseCategory(
          monster: monster,
          edition: edition,
          damageType: dmgType,
          environment: ArenaEnvironment.colosseum,
        );
        final row = <String, Object?>{
          'monsterId': monster.id,
          'edition': edition.name,
          'damageType': dmgType,
          'colosseum': colosseum,
        };
        if (dmgType == 'fire') {
          final flooded = probeDefenseCategory(
            monster: monster,
            edition: edition,
            damageType: 'fire',
            environment: ArenaEnvironment.floodedAbyss,
          );
          row['floodedAbyssFire'] = flooded;
          row['floodedAbyssChangesFire'] = flooded != colosseum;
        }
        rows.add(row);
      }
    }
  }
  return rows;
}

/// Compares two match record maps field by field and returns null if identical,
/// or a descriptive mismatch message naming the matchKey, step index, and first differing text.
String? compareMatchRecords(
  Map<String, Object?> expected,
  Map<String, Object?> actual,
) {
  final key = expected['matchKey']?.toString() ?? '<unknown>';
  const scalarFields = <String>[
    'matchKey',
    'matchup',
    'edition',
    'environment',
    'strategy',
    'seed',
    'winner',
    'totalRounds',
    'mvpName',
    'teamATotalDamage',
    'teamBTotalDamage',
    'teamAKills',
    'teamBKills',
  ];
  for (final field in scalarFields) {
    if (expected[field] != actual[field]) {
      return 'Mismatch in $key field "$field": expected=${expected[field]}, actual=${actual[field]}';
    }
  }
  final expSteps = expected['steps'] as List<Object?>;
  final actSteps = actual['steps'] as List<Object?>;
  if (expSteps.length != actSteps.length) {
    return 'Mismatch in $key step count: expected=${expSteps.length}, actual=${actSteps.length}';
  }
  for (var i = 0; i < expSteps.length; i++) {
    final es = expSteps[i] as Map<String, Object?>;
    final asMap = actSteps[i] as Map<String, Object?>;
    if (es['stepSummary'] != asMap['stepSummary']) {
      return 'Mismatch in $key step $i stepSummary:\n  expected: ${es['stepSummary']}\n  actual:   ${asMap['stepSummary']}';
    }
    final eEvents = es['events'] as List<Object?>;
    final aEvents = asMap['events'] as List<Object?>;
    if (eEvents.length != aEvents.length) {
      return 'Mismatch in $key step $i event count: expected=${eEvents.length}, actual=${aEvents.length}';
    }
    for (var j = 0; j < eEvents.length; j++) {
      if (eEvents[j] != aEvents[j]) {
        return 'Mismatch in $key step $i event $j:\n  expected: ${eEvents[j]}\n  actual:   ${aEvents[j]}';
      }
    }
  }
  return null;
}

List<Map<String, Object?>> readJsonListFixture(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Missing required golden fixture file: $path');
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! List<Object?>) {
    throw FormatException('Golden fixture $path must be a JSON list');
  }
  return decoded.cast<Map<String, Object?>>();
}

class _FixedNormalHitRandom implements Random {
  @override
  int nextInt(int max) => max == 20 ? 10 : 0;

  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;
}
