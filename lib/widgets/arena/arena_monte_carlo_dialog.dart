import 'package:dangerously_nerdy_5e_toolkit/theme/domain_ui_extensions.dart';
import 'package:flutter/material.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/arena/arena_simulation_models.dart';
import '../../models/dm_screen_data.dart';
import '../../services/rules/arena_combat_engine.dart';

/// Modal dialog showing Monte Carlo probability outcomes and statistical breakdown.
class ArenaMonteCarloDialog extends StatefulWidget {
  final List<ArenaCombatant> teamA;
  final List<ArenaCombatant> teamB;
  final ArenaTargetingStrategy strategy;
  final DmRulesEdition edition;
  final ArenaEnvironment environment;
  final int initialIterations;

  const ArenaMonteCarloDialog({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.strategy,
    required this.edition,
    this.environment = ArenaEnvironment.colosseum,
    this.initialIterations = 500,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ArenaCombatant> teamA,
    required List<ArenaCombatant> teamB,
    required ArenaTargetingStrategy strategy,
    required DmRulesEdition edition,
    ArenaEnvironment environment = ArenaEnvironment.colosseum,
    int initialIterations = 500,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ArenaMonteCarloDialog(
        teamA: teamA,
        teamB: teamB,
        strategy: strategy,
        edition: edition,
        environment: environment,
        initialIterations: initialIterations,
      ),
    );
  }

  @override
  State<ArenaMonteCarloDialog> createState() => _ArenaMonteCarloDialogState();
}

class _ArenaMonteCarloDialogState extends State<ArenaMonteCarloDialog> {
  final ArenaCombatEngine _engine = ArenaCombatEngine();
  ArenaMonteCarloResult? _result;
  bool _isCalculating = false;
  late int _iterations;

  @override
  void initState() {
    super.initState();
    _iterations = widget.initialIterations;
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    setState(() {
      _isCalculating = true;
    });

    ArenaMonteCarloResult res;
    try {
      res = await _engine.runMonteCarloAsync(
        teamA: widget.teamA,
        teamB: widget.teamB,
        strategy: widget.strategy,
        edition: widget.edition,
        environment: widget.environment,
        iterations: _iterations,
      ).timeout(const Duration(milliseconds: 300));
    } catch (_) {
      // Fallback to synchronous simulation if isolate fails or times out
      res = _engine.runMonteCarlo(
        teamA: widget.teamA,
        teamB: widget.teamB,
        strategy: widget.strategy,
        edition: widget.edition,
        environment: widget.environment,
        iterations: _iterations,
      );
    }

    if (mounted) {
      setState(() {
        _result = res;
        _isCalculating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final res = _result;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF13151F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFCBD5E1),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC084FC).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_outlined, color: Color(0xFFC084FC), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monte Carlo Win Probabilities',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Simulating $_iterations pit fights in seconds',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              if (_isCalculating || res == null) ...[
                const SizedBox(height: 60),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const Center(child: Text('Simulating high-speed combat rounds...')),
                const SizedBox(height: 60),
              ] else ...[
                // Win Probability Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${ArenaTeam.teamA.label}: ${res.teamAWinRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ArenaTeam.teamA.color,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${ArenaTeam.teamB.label}: ${res.teamBWinRate.toStringAsFixed(1)}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ArenaTeam.teamB.color,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 20,
                        child: Row(
                          children: [
                            if (res.teamAWinRate > 0)
                              Expanded(
                                flex: (res.teamAWinRate * 10).round(),
                                child: Container(color: ArenaTeam.teamA.color),
                              ),
                            if (res.drawRate > 0)
                              Expanded(
                                flex: (res.drawRate * 10).round(),
                                child: Container(color: Colors.grey),
                              ),
                            if (res.teamBWinRate > 0)
                              Expanded(
                                flex: (res.teamBWinRate * 10).round(),
                                child: Container(color: ArenaTeam.teamB.color),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Statistics Grid
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow('Total Iterations', '${res.iterations} fights'),
                      _buildStatRow('Average Combat Length', '${res.averageRounds.toStringAsFixed(1)} rounds (Min: ${res.minRounds}, Max: ${res.maxRounds})'),
                      _buildStatRow('Team Crimson Wins', '${res.teamAWins} (${res.teamAWinRate.toStringAsFixed(1)}%)'),
                      _buildStatRow('Team Cobalt Wins', '${res.teamBWins} (${res.teamBWinRate.toStringAsFixed(1)}%)'),
                      if (res.draws > 0)
                        _buildStatRow('Draws / Round Caps', '${res.draws} (${res.drawRate.toStringAsFixed(1)}%)'),
                      _buildStatRow('Avg Surviving HP %', 'Crimson: ${res.avgTeamASurvivingHpPercent.toStringAsFixed(1)}% • Cobalt: ${res.avgTeamBSurvivingHpPercent.toStringAsFixed(1)}%'),
                      _buildStatRow('Compute Duration', '${res.calculationDuration.inMilliseconds} ms'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Iteration Buttons & Rerun
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 6,
                    children: [200, 500, 1000].map((count) {
                      final isSelected = _iterations == count;
                      return ChoiceChip(
                        label: Text('$count Fights'),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _iterations = count);
                            _runSimulation();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Re-run'),
                    onPressed: _isCalculating ? null : _runSimulation,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
