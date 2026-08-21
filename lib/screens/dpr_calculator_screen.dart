import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/dpr/dpr_models.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../services/rules/dpr_calculator_engine.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/dpr/dpr_chart_widget.dart';

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
  bool _showPowerAttack = true;
  bool _showAdvantage = false;
  bool _anythingGoesMode = false;

  @override
  void initState() {
    super.initState();
    _localEditionOverride = widget.initialEdition;
    _profile = widget.initialProfile ?? DprCombatantProfile.cleanCustom();
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
  }

  void _resetToCleanBuild() {
    HapticService.selectionTick(context);
    setState(() {
      _profile = DprCombatantProfile.cleanCustom();
    });
  }

  void _updateProfile(DprCombatantProfile newProfile) {
    setState(() {
      _profile = newProfile;
    });
  }

  void _updateAttack(int index, DprAttackAction updated) {
    final newAttacks = List<DprAttackAction>.from(_profile.attacks);
    if (index >= 0 && index < newAttacks.length) {
      newAttacks[index] = updated;
      _updateProfile(_profile.copyWith(attacks: newAttacks));
    }
  }

  void _openWeaponPicker(int attackIndex) {
    HapticService.selectionTick(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WeaponPickerSheet(
        onSelected: (preset) {
          final current = _profile.attacks[attackIndex];
          final abilityMod = _profile.abilityModifier;
          final pb = _profile.proficiencyBonus;

          final updated = current.copyWith(
            name: preset.name.split(' (').first,
            diceCount: preset.diceCount,
            diceSides: preset.diceSides,
            damageType: preset.damageType,
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
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showInfoDialog() {
    HapticService.selectionTick(context);
    final edition = _resolveEdition(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.cyanAccent),
              const SizedBox(width: 10),
              Text('5e DPR Math Guide (${edition == DmRulesEdition.v2024 ? '2024' : '2014'})'),
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
                  '• DPR = (P_hit - P_crit) × HitDamage + P_crit × CritDamage + P_miss × MissDamage.\n'
                  '• Hit Probability: Required d20 roll = Target AC - Attack Bonus (clamped to Nat 20 = 95% and Nat 1 = 5%).\n'
                  '• Advantage: 1 - (1 - P)^2\n'
                  '• Disadvantage: P^2\n'
                  '• Elven Accuracy: 1 - (1 - P)^3\n'
                  '• Great Weapon Master 2014 (-5 to hit / +10 dmg): Higher per-hit damage vs lower accuracy.\n'
                  '• Great Weapon Master 2024 (+PB dmg): Flat damage bonus to heavy weapons on hits.\n'
                  '• Great Weapon Fighting 2014: Rerolls 1s and 2s (2d6 avg = 8.33).\n'
                  '• Great Weapon Fighting 2024: 1s and 2s count as 3 (2d6 avg = 8.00).\n'
                  '• Weapon Masteries (2024): Graze deals ability mod on miss; Vex gives advantage on hit; Nick provides extra light attack without bonus action.\n'
                  '• Break-Even Point: The target AC where GWM/SS switches from optimal to suboptimal.',
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
    final edition = _resolveEdition(context);

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
                            breakEvenAnalysis.maxOptimalAcForGwm,
                          ),
                          const SizedBox(height: 12),
                          _buildAcSliderCard(theme),
                          const SizedBox(height: 12),
                          _buildMetricsSummaryCard(theme, activePoint, breakEvenAnalysis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Right Column: Full Combatant Profile & Attack Configurator
                    Expanded(
                      flex: 5,
                      child: _buildCombatantConfigurator(theme, isDark, edition),
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
                  breakEvenAnalysis.maxOptimalAcForGwm,
                ),
                const SizedBox(height: 12),
                _buildAcSliderCard(theme),
                const SizedBox(height: 12),
                _buildMetricsSummaryCard(theme, activePoint, breakEvenAnalysis),
                const SizedBox(height: 16),
                _buildCombatantConfigurator(theme, isDark, edition),
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
    int? breakEvenAc,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Animated DPR Curve vs Target AC',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Drag along the chart to inspect damage output across AC 5 to 30.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Animated interactive canvas
            DprChartWidget(
              baselineCurve: baselineCurve,
              powerAttackCurve: powerCurve,
              advantageCurve: advantageCurve,
              selectedAc: _selectedAc,
              breakEvenAc: breakEvenAc,
              showPowerAttack: _showPowerAttack,
              showAdvantage: _showAdvantage,
              onAcChanged: (ac) {
                HapticService.selectionTick(context);
                setState(() => _selectedAc = ac);
              },
            ),
            const SizedBox(height: 12),

            // Curve toggles & Legend
            Wrap(
              spacing: 12,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                _buildLegendItem('Baseline DPR', const Color(0xFF00E5FF)),
                FilterChip(
                  label: const Text('GWM / SS Curve', style: TextStyle(fontSize: 11)),
                  selected: _showPowerAttack,
                  selectedColor: const Color(0xFFFFB300).withValues(alpha: 0.3),
                  checkmarkColor: const Color(0xFFFFB300),
                  onSelected: (val) => setState(() => _showPowerAttack = val),
                ),
                FilterChip(
                  label: const Text('Advantage Curve', style: TextStyle(fontSize: 11)),
                  selected: _showAdvantage,
                  selectedColor: const Color(0xFF00E676).withValues(alpha: 0.3),
                  checkmarkColor: const Color(0xFF00E676),
                  onSelected: (val) => setState(() => _showAdvantage = val),
                ),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Target Armor Class (AC):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  onPressed: _selectedAc > 5
                      ? () {
                          HapticService.selectionTick(context);
                          setState(() => _selectedAc--);
                        }
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: _selectedAc.toDouble(),
                    min: 5,
                    max: 30,
                    divisions: 25,
                    label: 'AC $_selectedAc',
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) {
                      setState(() => _selectedAc = val.round());
                    },
                  ),
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
      ),
    );
  }

  Widget _buildMetricsSummaryCard(
    ThemeData theme,
    DprPoint point,
    DprBreakEvenAnalysis breakEven,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final hitPercent = (point.hitChance * 100).toStringAsFixed(1);
    final critPercent = (point.critChance * 100).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E0C1B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.cyanAccent.withValues(alpha: 0.25) : Colors.cyan.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: -2,
            ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Giant DPR Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt, color: Colors.cyanAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMBAT STATS (AC $_selectedAc)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        'Expected Damage Output',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF00E5FF).withValues(alpha: 0.2), const Color(0xFF7C3AED).withValues(alpha: 0.2)]
                        : [Colors.cyan.shade100, Colors.purple.shade100],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.cyan.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      point.dpr.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'DPR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Grid Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildHudTile(
                  icon: Icons.track_changes,
                  title: 'Accuracy',
                  value: '$hitPercent%',
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHudTile(
                  icon: Icons.whatshot,
                  title: 'Crit Rate',
                  value: '$critPercent%',
                  color: isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHudTile(
                  icon: Icons.shield_outlined,
                  title: 'Avg on Hit',
                  value: point.expectedDamageOnHit.toStringAsFixed(1),
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHudTile(
                  icon: Icons.auto_awesome,
                  title: 'Avg on Crit',
                  value: point.expectedDamageOnCrit.toStringAsFixed(1),
                  color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tactical Recommendation Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF261E08), const Color(0xFF191307)]
                    : [Colors.amber.shade50, Colors.amber.shade100],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.amber.withValues(alpha: 0.5) : Colors.amber.shade400,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology, color: Colors.amberAccent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    breakEven.recommendation,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171427) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombatantConfigurator(ThemeData theme, bool isDark, DmRulesEdition edition) {
    return Card(
      elevation: 2,
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
                Text(
                  'Attacks, Weapons & Cantrips',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.casino, size: 14),
                      label: const Text('Halfling Luck', style: TextStyle(fontSize: 11)),
                      tooltip: 'Reroll natural 1s on attack rolls (Halfling Luck / Lucky trait)',
                      selected: _profile.hasHalflingLuck,
                      selectedColor: Colors.amber.withValues(alpha: 0.25),
                      checkmarkColor: Colors.amber,
                      onSelected: (val) {
                        HapticService.selectionTick(context);
                        _updateProfile(_profile.copyWith(hasHalflingLuck: val));
                      },
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      avatar: const Icon(Icons.shuffle, size: 14),
                      label: const Text('Anything Goes', style: TextStyle(fontSize: 11)),
                      tooltip: 'Unlock and mix all 2014 & 2024 feats, fighting styles, and weapon masteries',
                      selected: _anythingGoesMode,
                      selectedColor: Colors.purple.withValues(alpha: 0.25),
                      checkmarkColor: Colors.purpleAccent,
                      onSelected: (val) {
                        HapticService.selectionTick(context);
                        setState(() => _anythingGoesMode = val);
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: 'Add Attack / Cantrip Action',
                      onPressed: () {
                        HapticService.selectionTick(context);
                        final newAttacks = List<DprAttackAction>.from(_profile.attacks)
                          ..add(
                            DprAttackAction(
                              id: 'attack_${DateTime.now().millisecondsSinceEpoch}',
                              name: 'Attack #${_profile.attacks.length + 1}',
                              attackBonus: _profile.abilityModifier + _profile.proficiencyBonus,
                              diceCount: 1,
                              diceSides: 6,
                              damageBonus: _profile.abilityModifier,
                              damageType: 'slashing',
                              attacksPerRound: 1,
                            ),
                          );
                        _updateProfile(_profile.copyWith(attacks: newAttacks));
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Character Level & Ability Mod Adjuster
            Row(
              children: [
                Expanded(
                  child: _buildNumberAdjuster(
                    label: 'Level',
                    value: _profile.level,
                    display: 'Lv ${_profile.level}',
                    min: 1,
                    max: 20,
                    onChanged: (val) {
                      final pb = ((val - 1) ~/ 4) + 2;
                      _updateProfile(_profile.copyWith(level: val, proficiencyBonus: pb));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNumberAdjuster(
                    label: 'Ability Score',
                    value: _profile.abilityScore,
                    display: '${_profile.abilityScore} (+${_profile.abilityModifier})',
                    min: 1,
                    max: 30,
                    onChanged: (val) {
                      final newMod = ((val - 10) / 2).floor();
                      final updatedAttacks = _profile.attacks.map((a) {
                        return a.copyWith(
                          abilityModForAgonizing: a.hasAgonizingBlast ? newMod : a.abilityModForAgonizing,
                          abilityModForGraze: a.weaponMastery == WeaponMastery.graze ? newMod : a.abilityModForGraze,
                        );
                      }).toList();
                      _updateProfile(_profile.copyWith(abilityScore: val, attacks: updatedAttacks));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildNumberAdjuster(
                    label: 'Prof. Bonus',
                    value: _profile.proficiencyBonus,
                    display: '+${_profile.proficiencyBonus}',
                    min: 2,
                    max: 6,
                    onChanged: (val) {
                      _updateProfile(_profile.copyWith(proficiencyBonus: val));
                    },
                  ),
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
                Expanded(
                  child: Text(
                    'Sneak Attack (Once/Turn): ${_profile.sneakAttackDiceCount}d${_profile.sneakAttackDiceSides}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: _profile.sneakAttackDiceCount > 0
                      ? () => _updateProfile(_profile.copyWith(sneakAttackDiceCount: _profile.sneakAttackDiceCount - 1))
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
              return _buildAttackEditor(attack, index, isDark, edition);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttackEditor(DprAttackAction attack, int index, bool isDark, DmRulesEdition edition) {
    final is2024 = edition == DmRulesEdition.v2024;
    final damageTypeLower = attack.damageType.toLowerCase();

    Color auraColor = Colors.cyanAccent;
    if (damageTypeLower.contains('fire')) {
      auraColor = const Color(0xFFFF5722);
    } else if (damageTypeLower.contains('cold')) {
      auraColor = const Color(0xFF00E5FF);
    } else if (damageTypeLower.contains('radiant') || damageTypeLower.contains('holy')) {
      auraColor = const Color(0xFFFFC107);
    } else if (damageTypeLower.contains('necrotic')) {
      auraColor = const Color(0xFFA855F7);
    } else if (damageTypeLower.contains('force')) {
      auraColor = const Color(0xFFE040FB);
    } else if (damageTypeLower.contains('lightning') || damageTypeLower.contains('thunder')) {
      auraColor = const Color(0xFF38BDF8);
    } else if (damageTypeLower.contains('poison') || damageTypeLower.contains('acid')) {
      auraColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161327) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: auraColor.withValues(alpha: isDark ? 0.35 : 0.4),
          width: 1.2,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: auraColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Equip Preset Weapon / Cantrip / Magic Item Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Equip Weapon / Cantrip', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onPressed: () => _openWeaponPicker(index),
                ),
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
          const SizedBox(height: 10),

          // Custom Weapon/Cantrip Name Free-Form Text Field
          TextFormField(
            key: ValueKey('${attack.id}_${attack.name}'),
            initialValue: attack.name,
            decoration: InputDecoration(
              labelText: 'Attack / Weapon / Cantrip Name',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            onChanged: (text) {
              _updateAttack(index, attack.copyWith(name: text));
            },
          ),
          const SizedBox(height: 10),

          // Attack Bonus & Primary Damage Dice Inputs
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

          // Secondary / Rider Damage (Smite, Hunter's Mark, Flame Tongue, Poison)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildNumberAdjuster(
                  label: 'Rider Dice',
                  value: attack.secondaryDiceCount,
                  display: '${attack.secondaryDiceCount}',
                  min: 0,
                  max: 10,
                  onChanged: (val) {
                    _updateAttack(index, attack.copyWith(secondaryDiceCount: val));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  key: ValueKey('${attack.id}_sec_${attack.secondaryDiceSides}'),
                  initialValue: attack.secondaryDiceSides > 0 ? attack.secondaryDiceSides : 6,
                  decoration: InputDecoration(
                    labelText: 'Rider Die',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [4, 6, 8, 10, 12].map((sides) {
                    return DropdownMenuItem(
                      value: sides,
                      child: Text('d$sides', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _updateAttack(index, attack.copyWith(secondaryDiceSides: val));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('${attack.id}_sec_type'),
                  initialValue: attack.secondaryDamageType ?? '',
                  decoration: InputDecoration(
                    labelText: 'Rider Type (Fire, Radiant...)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (text) {
                    _updateAttack(index, attack.copyWith(secondaryDamageType: text));
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

          // Modifiers & Style Chips Wrap (strictly filtered to active edition unless Anything Goes is enabled)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // GWM 2014 Power Attack (-5/+10)
              if (_anythingGoesMode || !is2024)
                FilterChip(
                  label: const Text('GWM 2014 (-5/+10)', style: TextStyle(fontSize: 11)),
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

              // GWM 2024 (+PB flat damage on hit)
              if (_anythingGoesMode || is2024)
                FilterChip(
                  label: Text('GWM 2024 (+${_profile.proficiencyBonus} dmg)', style: const TextStyle(fontSize: 11)),
                  selected: attack.gwmMode == GwmMode.v2024ProficiencyBonus,
                  selectedColor: Colors.cyan.withValues(alpha: 0.25),
                  onSelected: (val) {
                    _updateAttack(
                      index,
                      attack.copyWith(
                        gwmMode: val ? GwmMode.v2024ProficiencyBonus : GwmMode.none,
                      ),
                    );
                  },
                ),

              // GWF Style 2014 (Reroll 1s & 2s)
              if (_anythingGoesMode || !is2024)
                FilterChip(
                  label: const Text('GWF 2014 (Reroll 1s & 2s)', style: TextStyle(fontSize: 11)),
                  selected: attack.gwfVersion == GwfVersion.v2014Reroll,
                  selectedColor: Colors.amber.withValues(alpha: 0.25),
                  onSelected: (val) {
                    _updateAttack(
                      index,
                      attack.copyWith(
                        gwfVersion: val ? GwfVersion.v2014Reroll : GwfVersion.none,
                      ),
                    );
                  },
                ),

              // GWF Style 2024 (1s & 2s ➔ 3)
              if (_anythingGoesMode || is2024)
                FilterChip(
                  label: const Text('GWF 2024 (1s & 2s ➔ 3)', style: TextStyle(fontSize: 11)),
                  selected: attack.gwfVersion == GwfVersion.v2024Floor3,
                  selectedColor: Colors.cyan.withValues(alpha: 0.25),
                  onSelected: (val) {
                    _updateAttack(
                      index,
                      attack.copyWith(
                        gwfVersion: val ? GwfVersion.v2024Floor3 : GwfVersion.none,
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

              // Agonizing Blast / Cantrip Ability Mod (+Mod dmg)
              FilterChip(
                avatar: const Icon(Icons.auto_awesome, size: 12, color: Colors.purpleAccent),
                label: Text('Agonizing Blast (+${_profile.abilityModifier} dmg)', style: const TextStyle(fontSize: 11)),
                tooltip: 'Add spellcasting ability modifier to cantrip / Eldritch Blast damage',
                selected: attack.hasAgonizingBlast,
                selectedColor: Colors.purple.withValues(alpha: 0.25),
                checkmarkColor: Colors.purpleAccent,
                onSelected: (val) {
                  _updateAttack(
                    index,
                    attack.copyWith(
                      hasAgonizingBlast: val,
                      abilityModForAgonizing: _profile.abilityModifier,
                    ),
                  );
                },
              ),

              // 2024 Weapon Masteries
              if (_anythingGoesMode || is2024) ...[
                FilterChip(
                  label: const Text('Graze (Miss Dmg)', style: TextStyle(fontSize: 11)),
                  selected: attack.weaponMastery == WeaponMastery.graze,
                  selectedColor: Colors.teal.withValues(alpha: 0.25),
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
                FilterChip(
                  label: const Text('Vex (Adv on Hit)', style: TextStyle(fontSize: 11)),
                  selected: attack.weaponMastery == WeaponMastery.vex,
                  selectedColor: Colors.teal.withValues(alpha: 0.25),
                  onSelected: (val) {
                    _updateAttack(
                      index,
                      attack.copyWith(
                        weaponMastery: val ? WeaponMastery.vex : WeaponMastery.none,
                      ),
                    );
                  },
                ),
              ],

              // Expanded Crit (19-20)
              FilterChip(
                label: const Text('Crit 19-20', style: TextStyle(fontSize: 11)),
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

  Widget _buildNumberAdjuster({
    required String label,
    required int value,
    required String display,
    int? min,
    int? max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: (min == null || value > min) ? () => onChanged(value - 1) : null,
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.remove, size: 14),
                ),
              ),
              Text(display, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: (max == null || value < max) ? () => onChanged(value + 1) : null,
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(Icons.add, size: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom Sheet for selecting Standard & Magic Weapons
class _WeaponPickerSheet extends StatefulWidget {
  final ValueChanged<DprWeaponPreset> onSelected;

  const _WeaponPickerSheet({required this.onSelected});

  @override
  State<_WeaponPickerSheet> createState() => _WeaponPickerSheetState();
}

class _WeaponPickerSheetState extends State<_WeaponPickerSheet> {
  String _search = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = ['All', 'Standard Melee', 'Standard Ranged', 'Damage Cantrip', 'Magic Weapon'];

    final filtered = DprWeaponPreset.allPresets.where((p) {
      if (_selectedCategory != 'All' && p.category != _selectedCategory) {
        return false;
      }
      if (_search.isNotEmpty && !p.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high, color: Colors.cyanAccent),
                  const SizedBox(width: 10),
                  Text(
                    'Select Weapon, Cantrip, or Magic Item',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Greatsword, Fire Bolt, Rapier, Eldritch Blast...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
            ),
            const SizedBox(height: 10),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 16),

            // Weapon Preset List
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, index) {
                  final item = filtered[index];
                  final isMagic = item.category == 'Magic Weapon';
                  final isCantrip = item.isCantrip || item.category == 'Damage Cantrip';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMagic
                          ? Colors.purpleAccent.withValues(alpha: 0.2)
                          : isCantrip
                              ? Colors.amberAccent.withValues(alpha: 0.2)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      child: Icon(
                        isMagic
                            ? Icons.auto_awesome
                            : isCantrip
                                ? Icons.local_fire_department
                                : (item.isRanged ? Icons.gps_fixed : Icons.colorize),
                        color: isMagic
                            ? Colors.purpleAccent
                            : isCantrip
                                ? Colors.amberAccent
                                : (isDark ? Colors.white70 : Colors.black87),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isMagic
                            ? Colors.purpleAccent
                            : isCantrip
                                ? Colors.amberAccent
                                : null,
                      ),
                    ),
                    subtitle: Text(
                      '${item.diceCount}d${item.diceSides} ${item.damageType}'
                      '${item.flatBonus > 0 ? ' (+${item.flatBonus} magic)' : ''}'
                      '${item.secondaryDiceCount > 0 ? ' + ${item.secondaryDiceCount}d${item.secondaryDiceSides} ${item.secondaryDamageType ?? ""}' : ''}'
                      '${item.defaultMastery != WeaponMastery.none ? ' • Mastery: ${item.defaultMastery.label.split(" ").first}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => widget.onSelected(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
