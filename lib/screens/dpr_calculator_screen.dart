import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/dpr/dpr_models.dart';
import '../services/haptic_service.dart';
import '../services/rules/dpr_calculator_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/dpr/dpr_chart_widget.dart';

/// Full-featured Damage Per Round (DPR) Calculator and Statistical Analysis Screen.
class DprCalculatorScreen extends StatefulWidget {
  final DprCombatantProfile? initialProfile;

  const DprCalculatorScreen({
    super.key,
    this.initialProfile,
  });

  @override
  State<DprCalculatorScreen> createState() => _DprCalculatorScreenState();
}

class _DprCalculatorScreenState extends State<DprCalculatorScreen> {
  late DprCombatantProfile _profile;
  int _selectedAc = 15;
  bool _showPowerAttack = true;
  bool _showAdvantage = false;
  String _selectedPresetId = 'barbarian_gwm';

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile!;
      _selectedPresetId = 'custom';
    } else {
      _profile = DprCalculatorEngine.defaultPresets.first;
      _selectedPresetId = _profile.id;
    }
  }

  void _loadPreset(DprCombatantProfile preset) {
    HapticService.selectionTick(context);
    setState(() {
      _profile = preset;
      _selectedPresetId = preset.id;
    });
  }

  void _updateProfile(DprCombatantProfile newProfile) {
    setState(() {
      _profile = newProfile;
      _selectedPresetId = 'custom';
    });
  }

  void _showInfoDialog() {
    HapticService.selectionTick(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text('5e DPR Math Guide'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'How Damage Per Round (DPR) is Calculated:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '• DPR = (P_hit - P_crit) × HitDamage + P_crit × CritDamage + P_miss × MissDamage (Graze).\n'
                  '• Hit Probability: Required roll on d20 = Target AC - Attack Bonus. Clamped to 5% (Nat 20) and 95% (Nat 1).\n'
                  '• Advantage: 1 - (1 - P)^2\n'
                  '• Disadvantage: P^2\n'
                  '• Elven Accuracy: 1 - (1 - P)^3\n'
                  '• Great Weapon Master / Sharpshooter (-5 to hit / +10 dmg): Increases damage per hit at the cost of 25% lower base accuracy.\n'
                  '• Break-Even Point: The exact AC threshold where GWM deals more average damage than standard attacks.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got It'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabletop = theme.extension<TabletopColors>() ??
        (isDark ? TabletopColors.dark : TabletopColors.createLight(FantasyAccent.paladinGold));

    // Calculate curves and break-even analysis
    final baselineCurve = DprCalculatorEngine.generateCurve(_profile, minAc: 5, maxAc: 30);
    final breakEvenAnalysis = DprCalculatorEngine.calculateGwmBreakEven(_profile, minAc: 5, maxAc: 30);
    final powerCurve = breakEvenAnalysis.powerAttackCurve;
    final advantageCurve = DprCalculatorEngine.generateCurve(
      _profile,
      advantageOverride: AdvantageType.advantage,
      minAc: 5,
      maxAc: 30,
    );

    final activePoint = baselineCurve.pointAt(_selectedAc) ??
        const DprPoint(
          ac: 15,
          dpr: 0,
          hitChance: 0,
          critChance: 0,
          expectedDamageOnHit: 0,
          expectedDamageOnCrit: 0,
          expectedDamageOnMiss: 0,
        );

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_graph, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text('DPR Calculator & Graph'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'DPR Calculation Guide',
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Archetype Preset Selector Chips
                _buildPresetSelector(isDark),
                const SizedBox(height: 16),

                // 2. Main Content (Dual pane on desktop, column on mobile)
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Interactive Graph & Stats
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildChartCard(
                              baselineCurve: baselineCurve,
                              powerCurve: powerCurve,
                              advantageCurve: advantageCurve,
                              breakEvenAc: breakEvenAnalysis.maxOptimalAcForGwm,
                              tabletop: tabletop,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _buildAcSliderCard(isDark, breakEvenAnalysis.maxOptimalAcForGwm),
                            const SizedBox(height: 16),
                            _buildMetricsRow(activePoint, isDark),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Right Column: Attack Configurator & Feats
                      Expanded(
                        flex: 5,
                        child: _buildCombatantConfigurator(isDark),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildChartCard(
                        baselineCurve: baselineCurve,
                        powerCurve: powerCurve,
                        advantageCurve: advantageCurve,
                        breakEvenAc: breakEvenAnalysis.maxOptimalAcForGwm,
                        tabletop: tabletop,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildAcSliderCard(isDark, breakEvenAnalysis.maxOptimalAcForGwm),
                      const SizedBox(height: 16),
                      _buildMetricsRow(activePoint, isDark),
                      const SizedBox(height: 20),
                      _buildCombatantConfigurator(isDark),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetSelector(bool isDark) {
    final presets = DprCalculatorEngine.defaultPresets;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...presets.map((p) {
            final isSelected = _selectedPresetId == p.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(p.name),
                selected: isSelected,
                selectedColor: isDark ? Colors.cyanAccent.withValues(alpha: 0.25) : Colors.cyan.shade100,
                onSelected: (_) => _loadPreset(p),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune, size: 16),
                  SizedBox(width: 6),
                  Text('Custom Build'),
                ],
              ),
              selected: _selectedPresetId == 'custom',
              onSelected: (_) {
                setState(() {
                  _selectedPresetId = 'custom';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required DprCurveData baselineCurve,
    required DprCurveData powerCurve,
    required DprCurveData advantageCurve,
    required int? breakEvenAc,
    required TabletopColors tabletop,
    required bool isDark,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Chart Title and Curve Visibility Toggles
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timeline, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'DPR Curve Across Target AC',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('GWM/SS', style: TextStyle(fontSize: 11)),
                      selected: _showPowerAttack,
                      selectedColor: isDark ? Colors.amber.withValues(alpha: 0.25) : Colors.amber.shade100,
                      onSelected: (val) {
                        HapticService.selectionTick(context);
                        setState(() => _showPowerAttack = val);
                      },
                    ),
                    FilterChip(
                      label: const Text('Advantage', style: TextStyle(fontSize: 11)),
                      selected: _showAdvantage,
                      selectedColor: isDark ? Colors.green.withValues(alpha: 0.25) : Colors.green.shade100,
                      onSelected: (val) {
                        HapticService.selectionTick(context);
                        setState(() => _showAdvantage = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Animated Interactive Chart Widget
            DprChartWidget(
              baselineCurve: baselineCurve,
              powerAttackCurve: powerCurve,
              advantageCurve: advantageCurve,
              selectedAc: _selectedAc,
              breakEvenAc: breakEvenAc,
              showPowerAttack: _showPowerAttack,
              showAdvantage: _showAdvantage,
              onAcChanged: (newAc) {
                setState(() {
                  _selectedAc = newAc;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcSliderCard(bool isDark, int? breakEvenAc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 18, color: Colors.cyanAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Target Armor Class (AC): $_selectedAc',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: _selectedAc > 5
                        ? () {
                            HapticService.selectionTick(context);
                            setState(() => _selectedAc--);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: _selectedAc < 30
                        ? () {
                            HapticService.selectionTick(context);
                            setState(() => _selectedAc++);
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.cyanAccent,
              thumbColor: Colors.cyanAccent,
              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
            ),
            child: Slider(
              value: _selectedAc.toDouble(),
              min: 5.0,
              max: 30.0,
              divisions: 25,
              label: 'AC $_selectedAc',
              onChanged: (val) {
                setState(() => _selectedAc = val.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(DprPoint activePoint, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            title: 'Round DPR',
            value: activePoint.dpr.toStringAsFixed(1),
            subtitle: 'Average dmg per turn',
            icon: Icons.bolt,
            accentColor: Colors.cyanAccent,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Hit Chance',
            value: '${(activePoint.hitChance * 100).round()}%',
            subtitle: 'vs AC $_selectedAc',
            icon: Icons.gps_fixed,
            accentColor: const Color(0xFF69F0AE),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            title: 'Crit Chance',
            value: '${(activePoint.critChance * 100).toStringAsFixed(1)}%',
            subtitle: 'Critical hit odds',
            icon: Icons.star,
            accentColor: Colors.amberAccent,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231F34) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x2EFFFFFF) : const Color(0x1F000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          Text(
            subtitle,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCombatantConfigurator(bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Configurator Title
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Combatant & Attack Profile',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Attack'),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    final newAttacks = List<DprAttackAction>.from(_profile.attacks)
                      ..add(
                        DprAttackAction(
                          id: 'attack_${DateTime.now().millisecondsSinceEpoch}',
                          name: 'Bonus Attack',
                          attackBonus: 7,
                          diceCount: 1,
                          diceSides: 6,
                          damageBonus: 4,
                        ),
                      );
                    _updateProfile(_profile.copyWith(attacks: newAttacks));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Advantage State Selector
            DropdownButtonFormField<AdvantageType>(
              key: ValueKey(_profile.defaultAdvantage),
              initialValue: _profile.defaultAdvantage,
              decoration: InputDecoration(
                labelText: 'Accuracy & Advantage State',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: AdvantageType.values.map((adv) {
                return DropdownMenuItem(
                  value: adv,
                  child: Text(adv.label, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  _updateProfile(_profile.copyWith(defaultAdvantage: val));
                }
              },
            ),
            const SizedBox(height: 16),

            // Rogue Sneak Attack / Once per turn proc slider
            Row(
              children: [
                const Icon(Icons.flash_on, size: 16, color: Colors.purpleAccent),
                const SizedBox(width: 8),
                Text(
                  'Sneak Attack: ${_profile.sneakAttackDiceCount}d6',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: _profile.sneakAttackDiceCount > 0
                      ? () => _updateProfile(_profile.copyWith(sneakAttackDiceCount: _profile.sneakAttackDiceCount - 1))
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: _profile.sneakAttackDiceCount < 10
                      ? () => _updateProfile(_profile.copyWith(sneakAttackDiceCount: _profile.sneakAttackDiceCount + 1))
                      : null,
                ),
              ],
            ),
            const Divider(height: 24),

            // List of Attack Actions
            ...List.generate(_profile.attacks.length, (index) {
              final attack = _profile.attacks[index];
              return _buildAttackEditor(attack, index, isDark);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttackEditor(DprAttackAction attack, int index, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Attack Name & Delete Row
          Row(
            children: [
              Expanded(
                child: Text(
                  attack.name.isNotEmpty ? attack.name : 'Attack #${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Text(
                '${attack.attacksPerRound}x per round',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (_profile.attacks.length > 1) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    final newAttacks = List<DprAttackAction>.from(_profile.attacks)..removeAt(index);
                    _updateProfile(_profile.copyWith(attacks: newAttacks));
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Attack Bonus & Dice Inputs
          Row(
            children: [
              // To-Hit Bonus
              Expanded(
                child: _buildNumberAdjuster(
                  label: 'To-Hit',
                  value: attack.attackBonus,
                  display: attack.attackBonus >= 0 ? '+${attack.attackBonus}' : '${attack.attackBonus}',
                  onChanged: (val) {
                    _updateAttack(index, attack.copyWith(attackBonus: val));
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Dice Count & Sides
              Expanded(
                child: _buildNumberAdjuster(
                  label: 'Dice Count',
                  value: attack.diceCount,
                  display: '${attack.diceCount}',
                  min: 0,
                  max: 10,
                  onChanged: (val) {
                    _updateAttack(index, attack.copyWith(diceCount: val));
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Die Sides (d4, d6, d8, d10, d12)
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('${attack.id}_${attack.diceSides}'),
                  initialValue: attack.diceSides > 0 ? attack.diceSides : 6,
                  decoration: InputDecoration(
                    labelText: 'Die',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [4, 6, 8, 10, 12, 20].map((sides) {
                    return DropdownMenuItem(
                      value: sides,
                      child: Text('d$sides', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _updateAttack(index, attack.copyWith(diceSides: val));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Flat Damage Bonus
              Expanded(
                child: _buildNumberAdjuster(
                  label: 'Dmg Mod',
                  value: attack.damageBonus,
                  display: attack.damageBonus >= 0 ? '+${attack.damageBonus}' : '${attack.damageBonus}',
                  onChanged: (val) {
                    _updateAttack(index, attack.copyWith(damageBonus: val));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Attacks per round counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Attacks with this weapon:', style: TextStyle(fontSize: 12)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: attack.attacksPerRound > 1
                        ? () => _updateAttack(index, attack.copyWith(attacksPerRound: attack.attacksPerRound - 1))
                        : null,
                  ),
                  Text('${attack.attacksPerRound}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: attack.attacksPerRound < 8
                        ? () => _updateAttack(index, attack.copyWith(attacksPerRound: attack.attacksPerRound + 1))
                        : null,
                  ),
                ],
              ),
            ],
          ),

          // Modifiers & Style Chips Wrap
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // GWM / Sharpshooter (-5 / +10)
              FilterChip(
                label: const Text('GWM / SS (-5/+10)', style: TextStyle(fontSize: 11)),
                selected: attack.gwmMode == GwmMode.v2014PowerAttack,
                selectedColor: Colors.amber.withValues(alpha: 0.25),
                onSelected: (val) {
                  _updateAttack(
                    index,
                    attack.copyWith(
                      gwmMode: val ? GwmMode.v2014PowerAttack : GwmMode.none,
                    ),
                  );
                },
              ),

              // GWF Style (Reroll 1s & 2s)
              FilterChip(
                label: const Text('GWF Rerolls', style: TextStyle(fontSize: 11)),
                selected: attack.gwfVersion == GwfVersion.v2014Reroll,
                onSelected: (val) {
                  _updateAttack(
                    index,
                    attack.copyWith(
                      gwfVersion: val ? GwfVersion.v2014Reroll : GwfVersion.none,
                    ),
                  );
                },
              ),

              // Dueling (+2 dmg)
              FilterChip(
                label: const Text('Dueling (+2 dmg)', style: TextStyle(fontSize: 11)),
                selected: attack.hasDueling,
                onSelected: (val) {
                  _updateAttack(index, attack.copyWith(hasDueling: val));
                },
              ),

              // Archery (+2 hit)
              FilterChip(
                label: const Text('Archery (+2 hit)', style: TextStyle(fontSize: 11)),
                selected: attack.hasArchery,
                onSelected: (val) {
                  _updateAttack(index, attack.copyWith(hasArchery: val));
                },
              ),

              // Bless (+1d4)
              FilterChip(
                label: const Text('Bless (+1d4)', style: TextStyle(fontSize: 11)),
                selected: attack.attackBuffDiceSides == 4,
                onSelected: (val) {
                  _updateAttack(
                    index,
                    attack.copyWith(attackBuffDiceSides: val ? 4 : 0),
                  );
                },
              ),

              // Graze Mastery
              FilterChip(
                label: const Text('Graze (Miss Dmg)', style: TextStyle(fontSize: 11)),
                selected: attack.weaponMastery == WeaponMastery.graze,
                onSelected: (val) {
                  _updateAttack(
                    index,
                    attack.copyWith(
                      weaponMastery: val ? WeaponMastery.graze : WeaponMastery.none,
                      abilityModForGraze: val ? attack.damageBonus : 0,
                    ),
                  );
                },
              ),

              // Expanded Crit (19-20)
              FilterChip(
                label: const Text('Crit on 19-20', style: TextStyle(fontSize: 11)),
                selected: attack.critThreshold == 19,
                onSelected: (val) {
                  _updateAttack(
                    index,
                    attack.copyWith(critThreshold: val ? 19 : 20),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateAttack(int index, DprAttackAction updatedAttack) {
    HapticService.selectionTick(context);
    final newAttacks = List<DprAttackAction>.from(_profile.attacks);
    newAttacks[index] = updatedAttack;
    _updateProfile(_profile.copyWith(attacks: newAttacks));
  }

  Widget _buildNumberAdjuster({
    required String label,
    required int value,
    required String display,
    int min = -20,
    int max = 30,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: value > min ? () => onChanged(value - 1) : null,
                child: const Icon(Icons.arrow_drop_down, size: 18),
              ),
              Text(
                display,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              InkWell(
                onTap: value < max ? () => onChanged(value + 1) : null,
                child: const Icon(Icons.arrow_drop_up, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
