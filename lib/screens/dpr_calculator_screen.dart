import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/dpr/dpr_models.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../services/haptic_service.dart';
import '../services/persistence/dpr_persistence_service.dart';
import '../services/rules/dpr_calculator_engine.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/dpr/dpr_chart_widget.dart';
import '../widgets/dpr/dpr_combatant_configurator.dart';
import '../widgets/dpr/dpr_metrics_card.dart';
import '../widgets/dpr/dpr_weapon_picker_sheet.dart';

/// Full-featured Damage Per Round (DPR) Calculator and Statistical Analysis Screen.
class DprCalculatorScreen extends StatefulWidget {
  final DprCombatantProfile? initialProfile;
  final DmRulesEdition? initialEdition;

  const DprCalculatorScreen({
    super.key,
    this.initialProfile,
    this.initialEdition,
  });

  @override
  State<DprCalculatorScreen> createState() => _DprCalculatorScreenState();
}

class _DprCalculatorScreenState extends State<DprCalculatorScreen> {
  late DprCombatantProfile _profile;
  DmRulesEdition? _localEditionOverride;
  int _selectedAc = 15;
  int _chartMinAc = 8;
  int _chartMaxAc = 25;
  bool _showPowerAttack = true;
  bool _showAdvantage = false;
  bool _showDisadvantage = false;
  DprChartMode _chartMode = DprChartMode.dpr;
  bool _anythingGoesMode = false;

  @override
  void initState() {
    super.initState();
    _localEditionOverride = widget.initialEdition;
    _profile = widget.initialProfile ?? DprCombatantProfile.cleanCustom();
    if (widget.initialProfile == null) {
      _restorePersistedDraft();
    }
  }

  Future<void> _restorePersistedDraft() async {
    final draft = await AppServices.instance.dprPersistence.loadActiveDraft();
    if (draft != null && mounted) {
      setState(() {
        _profile = draft.profile;
        _selectedAc = draft.selectedAc;
        _chartMode = draft.chartMode;
        _anythingGoesMode = draft.anythingGoesMode;
      });
    }
  }

  void _autoSaveDraft() {
    AppServices.instance.dprPersistence.saveActiveDraftDebounced(
      DprActiveDraftState(
        profile: _profile,
        selectedAc: _selectedAc,
        chartMode: _chartMode,
        anythingGoesMode: _anythingGoesMode,
      ),
    );
  }

  DmRulesEdition _resolveEdition(BuildContext context) {
    if (_localEditionOverride != null) return _localEditionOverride!;
    final settingsProvider = SettingsScope.maybeOf(context);
    return settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;
  }

  void _onEditionChanged(DmRulesEdition newEdition) {
    HapticService.selectionTick(context);
    setState(() {
      _localEditionOverride = newEdition;
      // Adjust GWF / Mastery options to match edition
      final updatedAttacks = _profile.attacks.map((a) {
        var gwf = a.gwfVersion;
        if (gwf != GwfVersion.none) {
          gwf = newEdition == DmRulesEdition.v2024
              ? GwfVersion.v2024Floor3
              : GwfVersion.v2014Reroll;
        }
        var mastery = a.weaponMastery;
        if (newEdition == DmRulesEdition.v2014) {
          mastery = WeaponMastery.none;
        }
        return a.copyWith(gwfVersion: gwf, weaponMastery: mastery);
      }).toList();
      _profile = _profile.copyWith(attacks: updatedAttacks);
    });
    SettingsScope.maybeOf(context)?.setRulesEdition(newEdition);
    _autoSaveDraft();
  }

  void _resetToCleanBuild() {
    HapticService.selectionTick(context);
    setState(() {
      _profile = DprCombatantProfile.cleanCustom();
      _selectedAc = 15;
    });
    _autoSaveDraft();
  }

  void _updateProfile(DprCombatantProfile newProfile) {
    setState(() {
      _profile = newProfile;
    });
    _autoSaveDraft();
  }

  void _updateAttack(int index, DprAttackAction updated) {
    final newAttacks = List<DprAttackAction>.from(_profile.attacks);
    newAttacks[index] = updated;
    setState(() {
      _profile = _profile.copyWith(attacks: newAttacks);
    });
    _autoSaveDraft();
  }

  void _openWeaponPicker(int attackIndex) {
    HapticService.selectionTick(context);
    DprWeaponPickerSheet.show(
      context,
      onSelected: (preset) {
        final current = _profile.attacks[attackIndex];
        final abilityMod = _profile.abilityModifier;
        final pb = _profile.proficiencyBonus;

        final updated = current.copyWith(
          name: preset.name.split(' (').first,
          diceCount: preset.diceCount,
          diceSides: preset.diceSides,
          damageType: preset.damageType,
          attacksPerRound: preset.defaultAttacksPerRound,
          // For damage cantrips, baseline damage does not add ability modifier
          damageBonus: preset.isCantrip ? preset.flatBonus : (abilityMod + preset.flatBonus),
          attackBonus: abilityMod + pb + preset.flatBonus + (preset.isRanged && current.hasArchery ? 2 : 0),
          secondaryDiceCount: preset.secondaryDiceCount,
          secondaryDiceSides: preset.secondaryDiceSides,
          secondaryDamageType: preset.secondaryDamageType,
          weaponMastery: (!preset.isCantrip && _resolveEdition(context) == DmRulesEdition.v2024)
              ? preset.defaultMastery
              : WeaponMastery.none,
          abilityModForGraze: (!preset.isCantrip && preset.defaultMastery == WeaponMastery.graze)
              ? abilityMod
              : 0,
          abilityModForAgonizing: abilityMod,
          hasArchery: preset.isRanged ? current.hasArchery : false,
        );
        _updateAttack(attackIndex, updated);
      },
    );
  }

  void _showInfoDialog() {
    HapticService.selectionTick(context);
    final edition = _resolveEdition(context);
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
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Core Formula for Damage Per Round (DPR):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Text(
                    'DPR = (P(Hit) × E(Hit Dmg)) + (P(Crit) × E(Crit Extra Dmg)) + (P(Miss) × Graze Dmg)',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.cyanAccent),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rules Engine Highlights:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '• Bounded Accuracy: Rolls of 1 always miss and 20 always hit/crit.\n'
                  '• 2014 Great Weapon Master / Sharpshooter: -5 to hit for +10 flat damage.\n'
                  '• 2024 Great Weapon Master: Adds Proficiency Bonus (+PB) damage without -5 penalty.\n'
                  '• 2024 Graze Mastery: Deals Ability Modifier damage even on a missed strike.\n'
                  '• 2024 Vex Mastery: Automatically factors in chained advantage upon hitting.\n'
                  '• Sneak Attack: Calculated accurately as a once-per-turn trigger across all strikes.\n'
                  '• Current Mode: ${edition == DmRulesEdition.v2024 ? "2024 Revised Rules" : "2014 RAW Rules"}.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edition = _resolveEdition(context);

    // Calculate curves and break-even analysis across full potential spectrum (AC 5..30)
    final baselineCurve = DprCalculatorEngine.generateCurve(_profile, minAc: 5, maxAc: 30);
    final breakEvenAnalysis = DprCalculatorEngine.calculateGwmBreakEven(_profile, minAc: 5, maxAc: 30);
    final powerCurve = breakEvenAnalysis.powerAttackCurve;
    final advantageCurve = DprCalculatorEngine.generateCurve(
      _profile,
      advantageOverride: AdvantageType.advantage,
      minAc: 5,
      maxAc: 30,
    );
    final disadvantageCurve = DprCalculatorEngine.generateCurve(
      _profile,
      advantageOverride: AdvantageType.disadvantage,
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to Clean Custom Build',
            onPressed: _resetToCleanBuild,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'DPR Calculation Guide',
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Rules Edition Segmented Selector
              _buildEditionHeader(theme, edition),
              const SizedBox(height: 16),

              if (isWide) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Interactive Graph & Summary Cards
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildChartCard(
                            theme,
                            baselineCurve,
                            powerCurve,
                            advantageCurve,
                            disadvantageCurve,
                            breakEvenAnalysis.maxOptimalAcForGwm,
                          ),
                          const SizedBox(height: 12),
                          _buildAcSliderCard(theme),
                          const SizedBox(height: 12),
                          DprMetricsCard(
                            selectedAc: _selectedAc,
                            point: activePoint,
                            breakEven: breakEvenAnalysis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right Column: Full Combatant Profile & Attack Configurator
                    Expanded(
                      flex: 5,
                      child: DprCombatantConfigurator(
                        profile: _profile,
                        anythingGoesMode: _anythingGoesMode,
                        edition: edition,
                        onProfileChanged: _updateProfile,
                        onAnythingGoesChanged: (val) => setState(() => _anythingGoesMode = val),
                        onOpenWeaponPicker: _openWeaponPicker,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Mobile layout: Stacked
                _buildChartCard(
                  theme,
                  baselineCurve,
                  powerCurve,
                  advantageCurve,
                  disadvantageCurve,
                  breakEvenAnalysis.maxOptimalAcForGwm,
                ),
                const SizedBox(height: 12),
                _buildAcSliderCard(theme),
                const SizedBox(height: 12),
                DprMetricsCard(
                  selectedAc: _selectedAc,
                  point: activePoint,
                  breakEven: breakEvenAnalysis,
                ),
                const SizedBox(height: 16),
                DprCombatantConfigurator(
                  profile: _profile,
                  anythingGoesMode: _anythingGoesMode,
                  edition: edition,
                  onProfileChanged: _updateProfile,
                  onAnythingGoesChanged: (val) => setState(() => _anythingGoesMode = val),
                  onOpenWeaponPicker: _openWeaponPicker,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditionHeader(ThemeData theme, DmRulesEdition edition) {
    final is2024 = edition == DmRulesEdition.v2024;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: is2024
            ? Colors.cyan.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: is2024 ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                is2024 ? Icons.auto_awesome : Icons.history_edu,
                color: is2024 ? Colors.cyanAccent : Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                is2024 ? 'Active: 2024 Revised Rules' : 'Active: 2014 5e RAW',
                style: TextStyle(
                  color: is2024 ? Colors.cyanAccent : Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          RulesEditionToggle(
            currentEdition: edition,
            onEditionChanged: _onEditionChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
    ThemeData theme,
    DprCurveData baselineCurve,
    DprCurveData powerCurve,
    DprCurveData advantageCurve,
    DprCurveData disadvantageCurve,
    int? breakEvenAc,
  ) {
    final hasGraze = baselineCurve.points.values.any((p) => p.expectedDamageOnMiss > 0);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.show_chart, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _chartMode == DprChartMode.dpr
                          ? 'DPR Curve vs Target AC'
                          : _chartMode == DprChartMode.accuracy
                              ? 'Accuracy & Hit Rate % vs AC'
                              : 'Damage on Hit vs Miss (Breakdown)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // Graph Mode Segmented Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<DprChartMode>(
                    segments: const [
                      ButtonSegment(
                        value: DprChartMode.dpr,
                        icon: Icon(Icons.auto_graph, size: 14),
                        label: Text('DPR', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: DprChartMode.accuracy,
                        icon: Icon(Icons.percent, size: 14),
                        label: Text('Accuracy', style: TextStyle(fontSize: 11)),
                      ),
                      ButtonSegment(
                        value: DprChartMode.damageBreakdown,
                        icon: Icon(Icons.stacked_bar_chart, size: 14),
                        label: Text('Breakdown', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                    selected: {_chartMode},
                    onSelectionChanged: (newSelection) {
                      HapticService.selectionTick(context);
                      setState(() => _chartMode = newSelection.first);
                    },
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _chartMode == DprChartMode.dpr
                  ? 'Drag along the chart to inspect DPR output across active AC scale.'
                  : _chartMode == DprChartMode.accuracy
                      ? 'Inspect exact hit, crit, and miss probabilities against enemy AC.'
                      : 'Compare expected damage on normal hits, crits, and miss graze damage.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // Scale & Dynamic Zoom Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten, size: 14, color: Colors.cyanAccent),
                  const SizedBox(width: 6),
                  const Text('Scale:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('8–25 5e', style: TextStyle(fontSize: 10)),
                            selected: _chartMinAc == 8 && _chartMaxAc == 25,
                            visualDensity: VisualDensity.compact,
                            onSelected: (sel) {
                              if (sel) {
                                HapticService.selectionTick(context);
                                setState(() {
                                  _chartMinAc = 8;
                                  _chartMaxAc = 25;
                                  _selectedAc = _selectedAc.clamp(8, 25);
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('10–20 Focus', style: TextStyle(fontSize: 10)),
                            selected: _chartMinAc == 10 && _chartMaxAc == 20,
                            visualDensity: VisualDensity.compact,
                            onSelected: (sel) {
                              if (sel) {
                                HapticService.selectionTick(context);
                                setState(() {
                                  _chartMinAc = 10;
                                  _chartMaxAc = 20;
                                  _selectedAc = _selectedAc.clamp(10, 20);
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          ChoiceChip(
                            label: const Text('5–30 Epic', style: TextStyle(fontSize: 10)),
                            selected: _chartMinAc == 5 && _chartMaxAc == 30,
                            visualDensity: VisualDensity.compact,
                            onSelected: (sel) {
                              if (sel) {
                                HapticService.selectionTick(context);
                                setState(() {
                                  _chartMinAc = 5;
                                  _chartMaxAc = 30;
                                  _selectedAc = _selectedAc.clamp(5, 30);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.zoom_in, size: 18),
                    tooltip: 'Zoom In (Narrow AC range)',
                    visualDensity: VisualDensity.compact,
                    onPressed: (_chartMaxAc - _chartMinAc > 6)
                        ? () {
                            HapticService.selectionTick(context);
                            setState(() {
                              if (_chartMinAc < _selectedAc - 2) _chartMinAc++;
                              if (_chartMaxAc > _selectedAc + 2) _chartMaxAc--;
                            });
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_out, size: 18),
                    tooltip: 'Zoom Out (Widen AC range)',
                    visualDensity: VisualDensity.compact,
                    onPressed: (_chartMinAc > 5 || _chartMaxAc < 30)
                        ? () {
                            HapticService.selectionTick(context);
                            setState(() {
                              if (_chartMinAc > 5) _chartMinAc--;
                              if (_chartMaxAc < 30) _chartMaxAc++;
                            });
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    tooltip: 'Center on Target AC',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticService.selectionTick(context);
                      setState(() {
                        _chartMinAc = math.max(5, _selectedAc - 5);
                        _chartMaxAc = math.min(30, _selectedAc + 5);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Animated interactive canvas
            DprChartWidget(
              baselineCurve: baselineCurve,
              powerAttackCurve: powerCurve,
              advantageCurve: advantageCurve,
              disadvantageCurve: disadvantageCurve,
              minAc: _chartMinAc,
              maxAc: _chartMaxAc,
              selectedAc: _selectedAc,
              breakEvenAc: breakEvenAc,
              showPowerAttack: _showPowerAttack,
              showAdvantage: _showAdvantage,
              showDisadvantage: _showDisadvantage,
              chartMode: _chartMode,
              onAcChanged: (ac) {
                HapticService.selectionTick(context);
                setState(() => _selectedAc = ac);
                _autoSaveDraft();
              },
            ),
            const SizedBox(height: 12),

            // Dynamic Curve toggles & Legend based on Mode
            if (_chartMode == DprChartMode.dpr)
              Wrap(
                spacing: 10,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildLegendItem('Baseline', const Color(0xFF00E5FF)),
                  FilterChip(
                    label: const Text('GWM / SS', style: TextStyle(fontSize: 11)),
                    selected: _showPowerAttack,
                    selectedColor: const Color(0xFFFFB300).withValues(alpha: 0.3),
                    checkmarkColor: const Color(0xFFFFB300),
                    onSelected: (val) => setState(() => _showPowerAttack = val),
                  ),
                  FilterChip(
                    label: const Text('Advantage', style: TextStyle(fontSize: 11)),
                    selected: _showAdvantage,
                    selectedColor: const Color(0xFF00E676).withValues(alpha: 0.3),
                    checkmarkColor: const Color(0xFF00E676),
                    onSelected: (val) => setState(() => _showAdvantage = val),
                  ),
                  FilterChip(
                    label: const Text('Disadvantage', style: TextStyle(fontSize: 11)),
                    selected: _showDisadvantage,
                    selectedColor: const Color(0xFFFF5252).withValues(alpha: 0.3),
                    checkmarkColor: const Color(0xFFFF5252),
                    onSelected: (val) => setState(() => _showDisadvantage = val),
                  ),
                ],
              )
            else if (_chartMode == DprChartMode.accuracy)
              Wrap(
                spacing: 10,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildLegendItem('Normal Hit %', const Color(0xFF00E5FF)),
                  FilterChip(
                    label: const Text('Advantage %', style: TextStyle(fontSize: 11)),
                    selected: _showAdvantage,
                    selectedColor: const Color(0xFF00E676).withValues(alpha: 0.3),
                    checkmarkColor: const Color(0xFF00E676),
                    onSelected: (val) => setState(() => _showAdvantage = val),
                  ),
                  FilterChip(
                    label: const Text('Disadvantage %', style: TextStyle(fontSize: 11)),
                    selected: _showDisadvantage,
                    selectedColor: const Color(0xFFFF5252).withValues(alpha: 0.3),
                    checkmarkColor: const Color(0xFFFF5252),
                    onSelected: (val) => setState(() => _showDisadvantage = val),
                  ),
                  _buildLegendItem('Crit %', const Color(0xFFFFD700)),
                ],
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildLegendItem('Regular Hit Damage', const Color(0xFF00E5FF)),
                  _buildLegendItem('Critical Hit Damage', const Color(0xFFFFD700)),
                  if (hasGraze)
                    _buildLegendItem('Miss Damage (Graze)', const Color(0xFFB388FF)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAcSliderCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield, size: 16, color: Colors.cyanAccent),
                    SizedBox(width: 6),
                    Text(
                      'Target Armor Class (AC):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent, width: 1),
                  ),
                  child: Text(
                    'AC $_selectedAc',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _selectedAc > _chartMinAc
                      ? () {
                          HapticService.selectionTick(context);
                          setState(() => _selectedAc--);
                        }
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: _selectedAc.toDouble().clamp(_chartMinAc.toDouble(), _chartMaxAc.toDouble()),
                    min: _chartMinAc.toDouble(),
                    max: _chartMaxAc.toDouble(),
                    divisions: math.max(1, _chartMaxAc - _chartMinAc),
                    label: 'AC $_selectedAc',
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) {
                      setState(() => _selectedAc = val.round());
                      _autoSaveDraft();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _selectedAc < _chartMaxAc
                      ? () {
                          HapticService.selectionTick(context);
                          setState(() => _selectedAc++);
                          _autoSaveDraft();
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Monster CR Benchmarks Quick-Select
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'CR Targets: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  ...DprMonsterAcPreset.standardPresets.map((preset) {
                    final isSelected = _selectedAc == preset.typicalAc;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text('CR ${preset.crDisplay} (AC ${preset.typicalAc})', style: const TextStyle(fontSize: 10.5)),
                        tooltip: '${preset.label}: ${preset.examples}',
                        selected: isSelected,
                        visualDensity: VisualDensity.compact,
                        onSelected: (selected) {
                          if (selected) {
                            HapticService.selectionTick(context);
                            setState(() {
                              _selectedAc = preset.typicalAc.clamp(_chartMinAc, _chartMaxAc);
                            });
                            _autoSaveDraft();
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

