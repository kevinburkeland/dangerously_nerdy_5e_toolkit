import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/a11y_service.dart';
import '../../services/haptic_service.dart';
import '../../utils/secure_random.dart';

/// Interactive tool widget for calculating Concentration Saving Throw DCs & rolling tests.
class ConcentrationCalculatorWidget extends StatefulWidget {
  const ConcentrationCalculatorWidget({super.key});

  @override
  State<ConcentrationCalculatorWidget> createState() => _ConcentrationCalculatorWidgetState();
}

class _ConcentrationCalculatorWidgetState extends State<ConcentrationCalculatorWidget> {
  int _incomingDamage = 22;
  int _conModifier = 2;
  bool _hasAdvantage = false;
  String? _lastRollResult;
  bool? _lastRollSuccess;

  int get _requiredDc {
    final halfDamage = _incomingDamage ~/ 2;
    return halfDamage > 10 ? halfDamage : 10;
  }

  void _rollConSave() {
    HapticService.selectionTick(context);
    final d1 = secureRandom.nextInt(20) + 1;
    int roll = d1;
    String rollDesc = 'Rolled $d1';

    if (_hasAdvantage) {
      final d2 = secureRandom.nextInt(20) + 1;
      roll = d1 > d2 ? d1 : d2;
      rollDesc = 'Rolled ($d1, $d2) -> $roll';
    }

    final total = roll + _conModifier;
    final success = total >= _requiredDc;
    final modSign = _conModifier >= 0 ? '+$_conModifier' : '$_conModifier';

    A11yService.announce(
      'Concentration test: $rollDesc $modSign = $total vs DC $_requiredDc. Result: ${success ? "Maintained Concentration!" : "Concentration Broken!"}',
    );

    setState(() {
      _lastRollSuccess = success;
      _lastRollResult = '$rollDesc $modSign = $total vs DC $_requiredDc (${success ? "PASS" : "FAIL"})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.purpleAccent : const Color(0xFF7E22CE);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Concentration DC Calculator',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Incoming Damage:', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStepButton(Icons.remove, () {
                          if (_incomingDamage > 1) {
                            setState(() => _incomingDamage -= 2);
                          }
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$_incomingDamage',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                        ),
                        _buildStepButton(Icons.add, () {
                          setState(() => _incomingDamage += 2);
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text('CON SAVE DC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
                    Text(
                      'DC $_requiredDc',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accentColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('CON Mod:', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              _buildModChip(theme, -1),
              _buildModChip(theme, 0),
              _buildModChip(theme, 2),
              _buildModChip(theme, 3),
              _buildModChip(theme, 5),
              FilterChip(
                label: const Text('Advantage', style: TextStyle(fontSize: 11)),
                selected: _hasAdvantage,
                onSelected: (v) => setState(() => _hasAdvantage = v),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size.fromHeight(34),
            ),
            onPressed: _rollConSave,
            icon: const Icon(Icons.casino, size: 16),
            label: Text(
              'Roll CON Save (${_conModifier >= 0 ? "+$_conModifier" : _conModifier}) vs DC $_requiredDc',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_lastRollResult != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _lastRollSuccess == true
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _lastRollSuccess == true ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                _lastRollResult!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _lastRollSuccess == true ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }

  Widget _buildModChip(ThemeData theme, int mod) {
    final isSelected = _conModifier == mod;
    return ChoiceChip(
      label: Text(mod >= 0 ? '+$mod' : '$mod', style: const TextStyle(fontSize: 10)),
      selected: isSelected,
      onSelected: (_) => setState(() => _conModifier = mod),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

/// Interactive tool widget for calculating Falling Damage & creature landing damage.
class FallingDamageCalculatorWidget extends StatefulWidget {
  const FallingDamageCalculatorWidget({super.key});

  @override
  State<FallingDamageCalculatorWidget> createState() => _FallingDamageCalculatorWidgetState();
}

class _FallingDamageCalculatorWidgetState extends State<FallingDamageCalculatorWidget> {
  int _fallFeet = 30;
  bool _fallOnCreature = false;
  List<int>? _rolledDice;
  int? _totalDamage;

  int get _diceCount {
    final count = _fallFeet ~/ 10;
    return count > 20 ? 20 : (count < 1 ? 1 : count);
  }

  void _rollFallingDamage() {
    HapticService.selectionTick(context);
    final count = _diceCount;
    final dice = List.generate(count, (_) => secureRandom.nextInt(6) + 1);
    final sum = dice.fold(0, (a, b) => a + b);

    final msg = 'Fell $_fallFeet ft: Rolled ${count}d6 -> [${dice.join(", ")}] = $sum bludgeoning damage.';
    A11yService.announce(msg);

    setState(() {
      _rolledDice = dice;
      _totalDamage = sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.deepOrangeAccent : const Color(0xFFC2410C);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.south, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Falling Damage Calculator',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fall Distance: $_fallFeet feet', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
                    Slider(
                      value: _fallFeet.toDouble(),
                      min: 10,
                      max: 200,
                      divisions: 19,
                      label: '$_fallFeet ft (${_diceCount}d6)',
                      activeColor: accentColor,
                      onChanged: (v) => setState(() => _fallFeet = v.toInt()),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text('DICE POOL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
                    Text('${_diceCount}d6', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: accentColor)),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              Checkbox(
                value: _fallOnCreature,
                activeColor: accentColor,
                onChanged: (v) => setState(() => _fallOnCreature = v ?? false),
              ),
              Expanded(
                child: Text(
                  'Landing on another creature (2024 DC 15 DEX save to split)',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size.fromHeight(34),
            ),
            onPressed: _rollFallingDamage,
            icon: const Icon(Icons.casino, size: 16),
            label: Text('Roll ${_diceCount}d6 Impact Damage', overflow: TextOverflow.ellipsis),
          ),
          if (_totalDamage != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accentColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rolled: [${_rolledDice?.join(", ")}] = $_totalDamage bludgeoning damage.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                  if (_fallOnCreature) ...[
                    const SizedBox(height: 2),
                    Text(
                      '• Target creature makes DC 15 DEX save.\n• On Fail: Damage is split (${(_totalDamage! / 2).floor()} dmg each) and both land Prone.\n• On Success: Falling creature takes full $_totalDamage dmg and lands Prone.',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.9), height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive tool widget for calculating Grapple & Shove Save DCs (2024) vs Contested checks (2014).
class GrappleShoveCalculatorWidget extends StatefulWidget {
  const GrappleShoveCalculatorWidget({super.key});

  @override
  State<GrappleShoveCalculatorWidget> createState() => _GrappleShoveCalculatorWidgetState();
}

class _GrappleShoveCalculatorWidgetState extends State<GrappleShoveCalculatorWidget> {
  int _strModifier = 3;
  int _proficiencyBonus = 2;

  int get _saveDc2024 => 8 + _strModifier + _proficiencyBonus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.deepOrangeAccent : const Color(0xFFC2410C);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_mma, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Grapple / Shove DC Engine',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STR Modifier:', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    Wrap(
                      spacing: 4,
                      children: [0, 1, 2, 3, 4, 5].map((m) {
                        return ChoiceChip(
                          label: Text('+$m', style: const TextStyle(fontSize: 10)),
                          selected: _strModifier == m,
                          onSelected: (_) => setState(() => _strModifier = m),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    Text('Proficiency Bonus:', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                    Wrap(
                      spacing: 4,
                      children: [2, 3, 4, 5, 6].map((pb) {
                        return ChoiceChip(
                          label: Text('+$pb', style: const TextStyle(fontSize: 10)),
                          selected: _proficiencyBonus == pb,
                          onSelected: (_) => setState(() => _proficiencyBonus = pb),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text('2024 SAVE DC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
                    Text('DC $_saveDc2024', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accentColor)),
                    Text('8 + STR + PB', style: TextStyle(fontSize: 9, color: accentColor.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• 2024: Target rolls STR or DEX saving throw vs DC $_saveDc2024. Escapes at end of its turn with same DC save.\n• 2014: Attacker rolls Athletics (+${_strModifier + _proficiencyBonus}) contested by target\'s Athletics or Acrobatics.',
            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.85), height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Interactive tool widget for inspecting and copying Difficulty Class benchmarks.
class DcBenchmarkSelectorWidget extends StatelessWidget {
  const DcBenchmarkSelectorWidget({super.key});

  static const List<(int, String, String)> benchmarks = [
    (5, 'Very Easy', 'Noticing loud noise, climbing knotted rope'),
    (10, 'Easy', 'Hearing guard steps, climbing rough wall'),
    (15, 'Medium', 'Picking standard lock, spotting concealed door'),
    (20, 'Hard', 'Tracking across solid rock, swimming through stormy sea'),
    (25, 'Very Hard', 'Deciphering ancient cyphers, leaping 30ft chasm'),
    (30, 'Nearly Impossible', 'Tracking invisible flyer, surviving volcano dive'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.lightGreenAccent : const Color(0xFF15803D);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'DC Quick Benchmarks (Tap to copy)',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...benchmarks.map((b) {
            final dc = b.$1;
            final label = b.$2;
            final example = b.$3;
            return InkWell(
              onTap: () {
                HapticService.selectionTick(context);
                Clipboard.setData(ClipboardData(text: 'DC $dc ($label): $example'));
                A11yService.announce('Copied DC $dc $label to clipboard');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied DC $dc ($label) to clipboard!'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('DC $dc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: accentColor)),
                    ),
                    const SizedBox(width: 8),
                    Text('$label: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: theme.colorScheme.onSurface)),
                    Expanded(
                      child: Text(
                        example,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    Icon(Icons.copy, size: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
