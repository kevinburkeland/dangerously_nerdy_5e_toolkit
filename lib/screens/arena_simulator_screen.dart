import 'dart:async';
import 'package:flutter/material.dart';
import '../models/arena/arena_action_result.dart';
import '../models/arena/arena_combatant.dart';
import '../models/arena/arena_preset_matchups.dart';
import '../models/arena/arena_simulation_models.dart';
import '../models/dm_screen_data.dart';
import '../models/monster_codex_data.dart';
import '../services/haptic_service.dart';
import '../services/rules/arena_combat_engine.dart';
import '../widgets/arena/arena_clash_stage.dart';
import '../widgets/arena/arena_combat_log_view.dart';
import '../widgets/arena/arena_combatant_card.dart';
import '../widgets/arena/arena_monster_picker_sheet.dart';
import '../widgets/arena/arena_monte_carlo_dialog.dart';
import '../widgets/fx/critical_effect_overlay.dart';

/// Monster Fighting Arena Screen under Tools for Nerds.
class ArenaSimulatorScreen extends StatefulWidget {
  const ArenaSimulatorScreen({super.key});

  @override
  State<ArenaSimulatorScreen> createState() => _ArenaSimulatorScreenState();
}

class _ArenaSimulatorScreenState extends State<ArenaSimulatorScreen> {
  final ArenaCombatEngine _engine = ArenaCombatEngine();
  final CriticalEffectController _critController = CriticalEffectController();

  // Arena Setup State
  final List<ArenaCombatant> _teamA = [];
  final List<ArenaCombatant> _teamB = [];
  DmRulesEdition _edition = DmRulesEdition.v2024;
  ArenaTargetingStrategy _strategy = ArenaTargetingStrategy.focusLowestHp;
  ArenaEnvironment _environment = ArenaEnvironment.colosseum;

  // Battle Simulation State
  ArenaSimulationStatus _status = ArenaSimulationStatus.setup;
  List<ArenaCombatant> _activeCombatants = [];
  final List<ArenaTurnStep> _turnHistory = [];
  int _currentStepIndex = 0;
  int _currentRound = 1;
  int _turnOrderIndex = 0;
  ArenaTurnStep? _currentStep;
  ArenaCombatant? _activeAttacker;
  ArenaCombatant? _activeDefender;

  // Playback timer & speed
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPreset(ArenaPresetMatchup.defaultPresets.first);
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _loadPreset(ArenaPresetMatchup preset) {
    _playbackTimer?.cancel();
    final resolved = preset.resolveFighters();
    setState(() {
      _teamA
        ..clear()
        ..addAll(resolved.teamA);
      _teamB
        ..clear()
        ..addAll(resolved.teamB);
      _status = ArenaSimulationStatus.setup;
      _turnHistory.clear();
      _currentStep = null;
      _activeAttacker = null;
      _activeDefender = null;
    });
  }

  void _addMonsterToTeam(MonsterItem monster, int count, ArenaTeam team) {
    setState(() {
      final targetList = team == ArenaTeam.teamA ? _teamA : _teamB;
      final existingCount = targetList.where((c) => c.monster.id == monster.id).length;

      for (int i = 0; i < count; i++) {
        final totalIndex = existingCount + i + 1;
        final name = count > 1 || existingCount > 0
            ? '${monster.getName(_edition)} #$totalIndex'
            : monster.getName(_edition);

        targetList.add(
          ArenaCombatant.fromMonster(
            id: '${team.name}_${monster.id}_${DateTime.now().microsecondsSinceEpoch}_$i',
            monster: monster,
            team: team,
            customName: name,
            edition: _edition,
          ),
        );
      }
    });
  }

  void _startBattle() {
    if (_teamA.isEmpty || _teamB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both teams must have at least 1 monster to fight!')),
      );
      return;
    }

    _playbackTimer?.cancel();

    // Reset & clone all fighters
    final freshCombatants = [
      ..._teamA.map((c) => c.reset()),
      ..._teamB.map((c) => c.reset()),
    ];

    _engine.rollInitiatives(freshCombatants);

    setState(() {
      _status = ArenaSimulationStatus.playing;
      _activeCombatants = freshCombatants;
      _turnHistory.clear();
      _currentStepIndex = 0;
      _currentRound = 1;
      _turnOrderIndex = 0;
      _currentStep = null;
      _activeAttacker = null;
      _activeDefender = null;
    });

    _startPlaybackTimer();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    final intervalMs = (1000 / _playbackSpeed).round().clamp(100, 3000);
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _advanceSingleStep();
    });
  }

  void _togglePlayPause() {
    if (_status == ArenaSimulationStatus.playing) {
      _playbackTimer?.cancel();
      setState(() {
        _status = ArenaSimulationStatus.paused;
      });
    } else if (_status == ArenaSimulationStatus.paused) {
      setState(() {
        _status = ArenaSimulationStatus.playing;
      });
      _startPlaybackTimer();
    } else if (_status == ArenaSimulationStatus.setup || _status == ArenaSimulationStatus.finished) {
      _startBattle();
    }
  }

  void _setPlaybackSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    if (_status == ArenaSimulationStatus.playing) {
      _startPlaybackTimer();
    }
  }

  /// Advances the simulation by exactly 1 monster turn.
  void _advanceSingleStep() {
    if (_status == ArenaSimulationStatus.finished) {
      _playbackTimer?.cancel();
      return;
    }

    // Check if one team is already defeated
    final livingTeamA = _activeCombatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
    final livingTeamB = _activeCombatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;

    if (livingTeamA == 0 || livingTeamB == 0) {
      _concludeBattle();
      return;
    }

    // Find next living combatant in initiative order
    ArenaCombatant? nextAttacker;
    int safetyCounter = 0;

    while (safetyCounter < _activeCombatants.length) {
      if (_turnOrderIndex >= _activeCombatants.length) {
        _turnOrderIndex = 0;
        _currentRound++;
      }

      final candidate = _activeCombatants[_turnOrderIndex];
      _turnOrderIndex++;
      safetyCounter++;

      if (candidate.isAlive) {
        nextAttacker = candidate;
        break;
      }
    }

    if (nextAttacker == null) {
      _concludeBattle();
      return;
    }

    final target = _engine.selectTarget(nextAttacker, _activeCombatants, _strategy);

    final step = _engine.executeTurn(
      stepIndex: _currentStepIndex++,
      roundNumber: _currentRound,
      attacker: nextAttacker,
      allCombatants: _activeCombatants,
      strategy: _strategy,
      edition: _edition,
      environment: _environment,
    );

    // Particle FX & Haptic trigger if crit landed
    if (step.attackEvents.any((e) => e.isCrit)) {
      _critController.trigger(CritEffectType.critSuccess);
    } else if (step.attackEvents.any((e) => e.isFumble)) {
      _critController.trigger(CritEffectType.critFumble);
    }

    setState(() {
      _turnHistory.add(step);
      _currentStep = step;
      _activeAttacker = nextAttacker;
      _activeDefender = target;
    });

    // Check if victory reached right after this step
    final postA = _activeCombatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
    final postB = _activeCombatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;

    if (postA == 0 || postB == 0 || _currentRound > 50) {
      _concludeBattle();
    }
  }

  void _skipToEnd() {
    _playbackTimer?.cancel();

    final simResult = _engine.simulateMatch(
      initialTeamA: _teamA,
      initialTeamB: _teamB,
      strategy: _strategy,
      edition: _edition,
      environment: _environment,
    );

    setState(() {
      _activeCombatants = simResult.finalCombatants;
      _turnHistory
        ..clear()
        ..addAll(simResult.steps);
      _currentStep = simResult.steps.isNotEmpty ? simResult.steps.last : null;
      _status = ArenaSimulationStatus.finished;
      _activeAttacker = null;
      _activeDefender = null;
    });

    _showVictoryDialog(simResult);
  }

  void _concludeBattle() {
    _playbackTimer?.cancel();
    setState(() {
      _status = ArenaSimulationStatus.finished;
    });

    final livingA = _activeCombatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length;
    final livingB = _activeCombatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length;

    ArenaTeam? winner;
    if (livingA > 0 && livingB == 0) winner = ArenaTeam.teamA;
    if (livingB > 0 && livingA == 0) winner = ArenaTeam.teamB;

    final teamADamage = _activeCombatants
        .where((c) => c.team == ArenaTeam.teamA)
        .fold(0, (sum, c) => sum + c.totalDamageDealt);
    final teamBDamage = _activeCombatants
        .where((c) => c.team == ArenaTeam.teamB)
        .fold(0, (sum, c) => sum + c.totalDamageDealt);

    ArenaCombatant? mvp;
    int highestScore = -1;
    for (final c in _activeCombatants) {
      final score = c.totalDamageDealt + (c.kills * 25);
      if (score > highestScore) {
        highestScore = score;
        mvp = c;
      }
    }

    final result = ArenaSimulationResult(
      winner: winner,
      totalRounds: _currentRound,
      steps: _turnHistory,
      finalCombatants: _activeCombatants,
      mvpCombatant: mvp,
      teamATotalDamage: teamADamage,
      teamBTotalDamage: teamBDamage,
      teamAKills: _activeCombatants.where((c) => c.team == ArenaTeam.teamA).fold(0, (sum, c) => sum + c.kills),
      teamBKills: _activeCombatants.where((c) => c.team == ArenaTeam.teamB).fold(0, (sum, c) => sum + c.kills),
    );

    _showVictoryDialog(result);
  }

  void _showVictoryDialog(ArenaSimulationResult result) {
    HapticService.critRumble(context);

    final winner = result.winner;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF13151F) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: winner != null ? winner.color : Colors.purpleAccent,
            width: 2,
          ),
        ),
        title: Row(
          children: [
            Icon(
              winner != null ? Icons.emoji_events : Icons.handshake,
              color: winner != null ? winner.color : Colors.amber,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              winner != null ? '${winner.label} Victorious!' : 'Draw Match',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: winner?.color,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Match concluded in ${result.totalRounds} rounds.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (result.mvpCombatant != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFD700).withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MATCH MVP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                          Text(
                            '${result.mvpCombatant!.displayName} (${result.mvpCombatant!.totalDamageDealt} dmg, ${result.mvpCombatant!.kills} kills)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ArenaTeam.teamA.label} Damage:',
                  style: TextStyle(color: ArenaTeam.teamA.color, fontSize: 12),
                ),
                Text('${result.teamATotalDamage} dmg (${result.teamAKills} kills)'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ArenaTeam.teamB.label} Damage:',
                  style: TextStyle(color: ArenaTeam.teamB.color, fontSize: 12),
                ),
                Text('${result.teamBTotalDamage} dmg (${result.teamBKills} kills)'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _status = ArenaSimulationStatus.setup;
              });
            },
            child: const Text('Edit Roster'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: winner?.color ?? Colors.purpleAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _startBattle();
            },
            child: const Text('Rematch'),
          ),
        ],
      ),
    );
  }

  void _resetToSetup() {
    _playbackTimer?.cancel();
    setState(() {
      _status = ArenaSimulationStatus.setup;
      _turnHistory.clear();
      _currentStep = null;
      _activeAttacker = null;
      _activeDefender = null;
    });
  }

  void _openMonteCarlo() {
    if (_teamA.isEmpty || _teamB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add monsters to both teams to calculate win probabilities!')),
      );
      return;
    }

    ArenaMonteCarloDialog.show(
      context,
      teamA: _teamA,
      teamB: _teamB,
      strategy: _strategy,
      edition: _edition,
      environment: _environment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;
    final isSetup = _status == ArenaSimulationStatus.setup;

    return CriticalEffectOverlay(
      controller: _critController,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monster Fighting Arena'),
          actions: [
            // Environment Battleground Picker Menu
            PopupMenuButton<ArenaEnvironment>(
              icon: Icon(_environment.icon, color: _environment.themeColor),
              tooltip: 'Arena Battleground: ${_environment.label}',
              onSelected: (env) => setState(() => _environment = env),
              itemBuilder: (context) => ArenaEnvironment.values.map((env) {
                return PopupMenuItem(
                  value: env,
                  child: Row(
                    children: [
                      Icon(env.icon, color: env.themeColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(env.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              env.description,
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Presets Menu Button
            PopupMenuButton<ArenaPresetMatchup>(
              icon: const Icon(Icons.bookmark_outline),
              tooltip: 'Load Pit Fight Preset',
              onSelected: _loadPreset,
              itemBuilder: (context) => ArenaPresetMatchup.defaultPresets.map((preset) {
                return PopupMenuItem(
                  value: preset,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(preset.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(preset.subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Rules Edition Switch
            PopupMenuButton<DmRulesEdition>(
              icon: const Icon(Icons.rule_folder_outlined),
              tooltip: 'Rules Edition (${_edition.name.toUpperCase()})',
              onSelected: (ed) => setState(() => _edition = ed),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: DmRulesEdition.v2024,
                  child: Text('2024 Revised SRD'),
                ),
                const PopupMenuItem(
                  value: DmRulesEdition.v2014,
                  child: Text('2014 Original RAW'),
                ),
              ],
            ),

            // Monte Carlo Sim Button
            IconButton(
              icon: const Icon(Icons.analytics_outlined, color: Color(0xFFC084FC)),
              tooltip: 'Run 500x Monte Carlo Sim',
              onPressed: _openMonteCarlo,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top Arena Stage Area (if in battle or playing)
              if (!isSetup)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: ArenaClashStage(
                    currentStep: _currentStep,
                    activeAttacker: _activeAttacker,
                    activeDefender: _activeDefender,
                    isPlaying: _status == ArenaSimulationStatus.playing,
                    playbackSpeed: _playbackSpeed,
                    edition: _edition,
                    environment: _environment,
                    onTogglePlay: _togglePlayPause,
                    onStepForward: _advanceSingleStep,
                    onSkipToEnd: _skipToEnd,
                    onResetMatch: _resetToSetup,
                    onSpeedChanged: _setPlaybackSpeed,
                  ),
                ),

              // Targeting Strategy & Battleground Strip (in Setup mode)
              if (isSetup)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Battleground Quick Pill
                      PopupMenuButton<ArenaEnvironment>(
                        tooltip: 'Change Arena Battleground',
                        onSelected: (env) => setState(() => _environment = env),
                        itemBuilder: (context) => ArenaEnvironment.values.map((env) {
                          return PopupMenuItem(
                            value: env,
                            child: Row(
                              children: [
                                Icon(env.icon, color: env.themeColor, size: 18),
                                const SizedBox(width: 8),
                                Text(env.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _environment.themeColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _environment.themeColor.withAlpha(80)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_environment.icon, size: 14, color: _environment.themeColor),
                              const SizedBox(width: 4),
                              Text(
                                _environment.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _environment.themeColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_drop_down, size: 16, color: _environment.themeColor),
                            ],
                          ),
                        ),
                      ),

                      // Targeting strategy dropdown
                      DropdownButton<ArenaTargetingStrategy>(
                        value: _strategy,
                        isDense: true,
                        underline: const SizedBox(),
                        items: ArenaTargetingStrategy.values.map((s) {
                          return DropdownMenuItem(
                            value: s,
                            child: Text(s.label, style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _strategy = val);
                        },
                      ),

                      // Monte Carlo Quick Button
                      TextButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFC084FC)),
                        label: const Text('Simulate 500x Odds', style: TextStyle(fontSize: 12)),
                        onPressed: _openMonteCarlo,
                      ),
                    ],
                  ),
                ),

              // Roster Area (Team A vs Team B)
              Expanded(
                child: isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildTeamColumn(
                              context,
                              team: ArenaTeam.teamA,
                              combatants: isSetup ? _teamA : _activeCombatants.where((c) => c.team == ArenaTeam.teamA).toList(),
                              isSetup: isSetup,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _buildTeamColumn(
                              context,
                              team: ArenaTeam.teamB,
                              combatants: isSetup ? _teamB : _activeCombatants.where((c) => c.team == ArenaTeam.teamB).toList(),
                              isSetup: isSetup,
                            ),
                          ),
                        ],
                      )
                    : DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              tabs: [
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(ArenaTeam.teamA.icon, color: ArenaTeam.teamA.color, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${ArenaTeam.teamA.label} (${isSetup ? _teamA.length : _activeCombatants.where((c) => c.team == ArenaTeam.teamA && c.isAlive).length})',
                                        style: TextStyle(color: ArenaTeam.teamA.color, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(ArenaTeam.teamB.icon, color: ArenaTeam.teamB.color, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${ArenaTeam.teamB.label} (${isSetup ? _teamB.length : _activeCombatants.where((c) => c.team == ArenaTeam.teamB && c.isAlive).length})',
                                        style: TextStyle(color: ArenaTeam.teamB.color, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildTeamColumn(
                                    context,
                                    team: ArenaTeam.teamA,
                                    combatants: isSetup ? _teamA : _activeCombatants.where((c) => c.team == ArenaTeam.teamA).toList(),
                                    isSetup: isSetup,
                                  ),
                                  _buildTeamColumn(
                                    context,
                                    team: ArenaTeam.teamB,
                                    combatants: isSetup ? _teamB : _activeCombatants.where((c) => c.team == ArenaTeam.teamB).toList(),
                                    isSetup: isSetup,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Bottom Combat Log (in battle mode) or Start Battle Bar (in setup mode)
              if (!isSetup)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: ArenaCombatLogView(steps: _turnHistory),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF13151F) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.analytics_outlined),
                          label: const Text('Monte Carlo Odds'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _openMonteCarlo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.sports_kabaddi, size: 22),
                          label: const Text('Start Battle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC084FC),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _startBattle,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamColumn(
    BuildContext context, {
    required ArenaTeam team,
    required List<ArenaCombatant> combatants,
    required bool isSetup,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalHp = combatants.fold(0, (sum, c) => sum + c.maxHp);
    final livingCount = combatants.where((c) => c.isAlive).length;

    return Column(
      children: [
        // Team Header Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: team.color.withAlpha(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(team.icon, color: team.color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    team.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: team.color,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                isSetup
                    ? '${combatants.length} fighters • $totalHp total HP'
                    : '$livingCount/${combatants.length} alive',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),

        // List of Combatants
        Expanded(
          child: combatants.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(team.icon, size: 36, color: Colors.grey.withAlpha(80)),
                        const SizedBox(height: 8),
                        Text(
                          'No monsters in ${team.label}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: combatants.length,
                  itemBuilder: (context, index) {
                    final fighter = combatants[index];
                    final isCurrentTurn = _activeAttacker?.id == fighter.id;
                    final isTargeted = _activeDefender?.id == fighter.id;

                    return ArenaCombatantCard(
                      combatant: fighter,
                      isCurrentTurn: isCurrentTurn,
                      isTargeted: isTargeted,
                      isSetupMode: isSetup,
                      edition: _edition,
                      onRemove: () {
                        setState(() {
                          final list = team == ArenaTeam.teamA ? _teamA : _teamB;
                          list.removeWhere((c) => c.id == fighter.id);
                        });
                      },
                      onDuplicate: () {
                        setState(() {
                          final list = team == ArenaTeam.teamA ? _teamA : _teamB;
                          list.add(
                            ArenaCombatant.fromMonster(
                              id: '${team.name}_${fighter.monster.id}_${DateTime.now().microsecondsSinceEpoch}',
                              monster: fighter.monster,
                              team: team,
                              customName: '${fighter.monster.getName(_edition)} #${list.length + 1}',
                              edition: _edition,
                            ),
                          );
                        });
                      },
                    );
                  },
                ),
        ),

        // Add Monster Button (Setup mode)
        if (isSetup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add to ${team.label}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: team.color,
                  side: BorderSide(color: team.color.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  ArenaMonsterPickerSheet.show(
                    context,
                    team: team,
                    edition: _edition,
                    onMonstersSelected: (monster, count) {
                      _addMonsterToTeam(monster, count, team);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
