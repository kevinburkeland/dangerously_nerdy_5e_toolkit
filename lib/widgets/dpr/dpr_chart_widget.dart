import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../models/dpr/dpr_models.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// Highly animated, radiant 5e DPR Canvas Chart with multi-curve comparisons,
/// continuous glowing pulse effects, smooth Bezier interpolation, touch/mouse scrubbing,
/// break-even crossover beacons, disadvantage curves, and accuracy/damage breakdown modes.
class DprChartWidget extends StatefulWidget {
  final DprCurveData baselineCurve;
  final DprCurveData? powerAttackCurve;
  final DprCurveData? advantageCurve;
  final DprCurveData? disadvantageCurve;
  final int selectedAc;
  final int? breakEvenAc;
  final ValueChanged<int> onAcChanged;
  final bool showPowerAttack;
  final bool showAdvantage;
  final bool showDisadvantage;
  final DprChartMode chartMode;

  const DprChartWidget({
    super.key,
    required this.baselineCurve,
    this.powerAttackCurve,
    this.advantageCurve,
    this.disadvantageCurve,
    required this.selectedAc,
    this.breakEvenAc,
    required this.onAcChanged,
    this.showPowerAttack = true,
    this.showAdvantage = false,
    this.showDisadvantage = false,
    this.chartMode = DprChartMode.dpr,
  });

  @override
  State<DprChartWidget> createState() => _DprChartWidgetState();
}

class _DprChartWidgetState extends State<DprChartWidget>
    with TickerProviderStateMixin {
  late final AnimationController _enterAnimController;
  late final Animation<double> _curveAnimation;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  int? _hoverAc;

  @override
  void initState() {
    super.initState();
    // Entry / curve morph animation
    _enterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _curveAnimation = CurvedAnimation(
      parent: _enterAnimController,
      curve: Curves.easeOutCubic,
    );
    _enterAnimController.forward();

    // Continuous ambient breathing pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    if (_isTestEnvironment) {
      _pulseController.forward(from: 0.0);
    } else {
      _pulseController.repeat(reverse: true);
    }

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  bool get _isTestEnvironment {
    return WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  @override
  void didUpdateWidget(DprChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baselineCurve.profile.id != widget.baselineCurve.profile.id ||
        oldWidget.showPowerAttack != widget.showPowerAttack ||
        oldWidget.showAdvantage != widget.showAdvantage ||
        oldWidget.showDisadvantage != widget.showDisadvantage ||
        oldWidget.chartMode != widget.chartMode) {
      _enterAnimController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _enterAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleDrag(Offset localPos, Size size, int minAc, int maxAc) {
    const leftPadding = 44.0;
    const rightPadding = 20.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    if (chartWidth <= 0) return;

    final xRel = (localPos.dx - leftPadding).clamp(0.0, chartWidth);
    final frac = xRel / chartWidth;
    final ac = (minAc + (frac * (maxAc - minAc))).round().clamp(minAc, maxAc);

    if (_hoverAc != ac) {
      setState(() {
        _hoverAc = ac;
      });
      HapticService.selectionTick(context);
      widget.onAcChanged(ac);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabletop = theme.extension<TabletopColors>() ??
        (isDark ? TabletopColors.dark : TabletopColors.createLight(FantasyAccent.paladinGold));

    const minAc = 5;
    const maxAc = 30;

    // Calculate dynamic Y-axis maximum depending on mode
    double yMax;
    if (widget.chartMode == DprChartMode.accuracy) {
      yMax = 100.0; // 0% to 100%
    } else if (widget.chartMode == DprChartMode.damageBreakdown) {
      final maxCritDamage = widget.baselineCurve.points.values.fold<double>(
        0.0,
        (prev, pt) => math.max<double>(prev, pt.expectedDamageOnCrit),
      );
      yMax = (math.max(10.0, (maxCritDamage * 1.15) / 5.0).ceil() * 5).toDouble();
    } else {
      var maxDpr = widget.baselineCurve.maxDpr;
      if (widget.showPowerAttack && widget.powerAttackCurve != null) {
        maxDpr = math.max(maxDpr, widget.powerAttackCurve!.maxDpr);
      }
      if (widget.showAdvantage && widget.advantageCurve != null) {
        maxDpr = math.max(maxDpr, widget.advantageCurve!.maxDpr);
      }
      if (widget.showDisadvantage && widget.disadvantageCurve != null) {
        maxDpr = math.max(maxDpr, widget.disadvantageCurve!.maxDpr);
      }
      yMax = (math.max(10.0, (maxDpr * 1.18) / 5.0).ceil() * 5).toDouble();
    }

    final activeAc = _hoverAc ?? widget.selectedAc;
    final basePt = widget.baselineCurve.pointAt(activeAc);
    final powerPt = widget.showPowerAttack ? widget.powerAttackCurve?.pointAt(activeAc) : null;
    final advPt = widget.showAdvantage ? widget.advantageCurve?.pointAt(activeAc) : null;
    final disPt = widget.showDisadvantage ? widget.disadvantageCurve?.pointAt(activeAc) : null;

    // Radiant neon palette
    final baseColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7);
    final powerColor = isDark ? const Color(0xFFFFB300) : const Color(0xFFD97706);
    final advColor = isDark ? const Color(0xFF00E676) : const Color(0xFF16A34A);
    final disColor = isDark ? const Color(0xFFFF5252) : const Color(0xFFDC2626);
    final critColor = isDark ? const Color(0xFFFFD700) : const Color(0xFFB45309);
    final missColor = isDark ? const Color(0xFFB388FF) : const Color(0xFF7C3AED);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Interactive Hover / Selected AC Tooltip Banner
        _buildActiveTooltipBanner(
          activeAc: activeAc,
          basePt: basePt,
          powerPt: powerPt,
          advPt: advPt,
          disPt: disPt,
          baseColor: baseColor,
          powerColor: powerColor,
          advColor: advColor,
          disColor: disColor,
          critColor: critColor,
          missColor: missColor,
          isDark: isDark,
          mode: widget.chartMode,
        ),
        const SizedBox(height: 12),

        // Animated Canvas Chart in a Neon-Framed Container
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B0A14) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.cyanAccent.withValues(alpha: 0.18)
                  : Colors.cyan.withValues(alpha: 0.25),
              width: 1.2,
            ),
            boxShadow: [
              if (isDark)
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.05),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onHover: (event) => _handleDrag(event.localPosition, constraints.biggest, minAc, maxAc),
                onExit: (_) {
                  setState(() {
                    _hoverAc = null;
                  });
                },
                child: GestureDetector(
                  onHorizontalDragStart: (details) =>
                      _handleDrag(details.localPosition, constraints.biggest, minAc, maxAc),
                  onHorizontalDragUpdate: (details) =>
                      _handleDrag(details.localPosition, constraints.biggest, minAc, maxAc),
                  onTapDown: (details) =>
                      _handleDrag(details.localPosition, constraints.biggest, minAc, maxAc),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_curveAnimation, _pulseAnimation]),
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, 250),
                        painter: _DprChartPainter(
                          baselineCurve: widget.baselineCurve,
                          powerCurve: widget.showPowerAttack ? widget.powerAttackCurve : null,
                          advantageCurve: widget.showAdvantage ? widget.advantageCurve : null,
                          disadvantageCurve: widget.showDisadvantage ? widget.disadvantageCurve : null,
                          minAc: minAc,
                          maxAc: maxAc,
                          yMax: yMax,
                          activeAc: activeAc,
                          breakEvenAc: widget.breakEvenAc,
                          animProgress: _curveAnimation.value,
                          pulseValue: _pulseAnimation.value,
                          isDark: isDark,
                          baseColor: baseColor,
                          powerColor: powerColor,
                          advColor: advColor,
                          disColor: disColor,
                          critColor: critColor,
                          missColor: missColor,
                          tabletop: tabletop,
                          chartMode: widget.chartMode,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTooltipBanner({
    required int activeAc,
    required DprPoint? basePt,
    required DprPoint? powerPt,
    required DprPoint? advPt,
    required DprPoint? disPt,
    required Color baseColor,
    required Color powerColor,
    required Color advColor,
    required Color disColor,
    required Color critColor,
    required Color missColor,
    required bool isDark,
    required DprChartMode mode,
  }) {
    final baseDpr = basePt?.dpr ?? 0.0;
    final powerDpr = powerPt?.dpr ?? 0.0;
    final dprDiff = powerDpr - baseDpr;
    final isGwmBetter = dprDiff > 0.05;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141224) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          // Target AC Pill + Recommendation
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF262338), const Color(0xFF1B182B)]
                        : [Colors.white, const Color(0xFFE2E8F0)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.black12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield, size: 14, color: Colors.cyanAccent),
                    const SizedBox(width: 5),
                    Text(
                      'Target AC $activeAc',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (mode == DprChartMode.dpr && widget.breakEvenAc != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (activeAc <= widget.breakEvenAc!)
                        ? (isDark ? Colors.amber.withValues(alpha: 0.22) : Colors.amber.shade100)
                        : (isDark ? Colors.cyan.withValues(alpha: 0.22) : Colors.cyan.shade100),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: (activeAc <= widget.breakEvenAc!)
                          ? Colors.amber.withValues(alpha: 0.5)
                          : Colors.cyan.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    activeAc <= widget.breakEvenAc! ? '⚡ GWM Optimal' : '🛡️ Normal Attack Optimal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: activeAc <= widget.breakEvenAc!
                          ? (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                          : (isDark ? Colors.cyanAccent : const Color(0xFF0369A1)),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Readouts based on Chart Mode
          if (mode == DprChartMode.dpr)
            Wrap(
              spacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMetricChip(
                  label: 'Normal',
                  value: '${baseDpr.toStringAsFixed(1)} DPR',
                  subtext: '${((basePt?.hitChance ?? 0) * 100).round()}% hit',
                  color: baseColor,
                ),
                if (powerPt != null)
                  _buildMetricChip(
                    label: 'GWM / SS',
                    value: '${powerDpr.toStringAsFixed(1)} DPR',
                    subtext: isGwmBetter
                        ? '+${dprDiff.toStringAsFixed(1)} (+${((dprDiff / math.max(0.1, baseDpr)) * 100).round()}%)'
                        : '${dprDiff.toStringAsFixed(1)} DPR',
                    color: powerColor,
                  ),
                if (advPt != null)
                  _buildMetricChip(
                    label: 'Advantage',
                    value: '${(advPt.dpr).toStringAsFixed(1)} DPR',
                    subtext: '${((advPt.hitChance) * 100).round()}% hit',
                    color: advColor,
                  ),
                if (disPt != null)
                  _buildMetricChip(
                    label: 'Disadvantage',
                    value: '${(disPt.dpr).toStringAsFixed(1)} DPR',
                    subtext: '${((disPt.hitChance) * 100).round()}% hit',
                    color: disColor,
                  ),
              ],
            )
          else if (mode == DprChartMode.accuracy)
            Wrap(
              spacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMetricChip(
                  label: 'Hit Rate',
                  value: '${((basePt?.hitChance ?? 0) * 100).round()}%',
                  subtext: 'Normal d20',
                  color: baseColor,
                ),
                if (advPt != null)
                  _buildMetricChip(
                    label: 'Advantage',
                    value: '${((advPt.hitChance) * 100).round()}%',
                    subtext: 'Highest of 2',
                    color: advColor,
                  ),
                if (disPt != null)
                  _buildMetricChip(
                    label: 'Disadvantage',
                    value: '${((disPt.hitChance) * 100).round()}%',
                    subtext: 'Lowest of 2',
                    color: disColor,
                  ),
                _buildMetricChip(
                  label: 'Crit Chance',
                  value: '${((basePt?.critChance ?? 0) * 100).round()}%',
                  subtext: 'Nat 20 / Crit',
                  color: critColor,
                ),
              ],
            )
          else
            Wrap(
              spacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildMetricChip(
                  label: 'Hit Damage',
                  value: '${(basePt?.expectedDamageOnHit ?? 0).toStringAsFixed(1)} dmg',
                  subtext: 'Base + Flat',
                  color: baseColor,
                ),
                _buildMetricChip(
                  label: 'Crit Damage',
                  value: '${(basePt?.expectedDamageOnCrit ?? 0).toStringAsFixed(1)} dmg',
                  subtext: 'Double Dice',
                  color: critColor,
                ),
                if ((basePt?.expectedDamageOnMiss ?? 0) > 0)
                  _buildMetricChip(
                    label: 'Miss (Graze)',
                    value: '${(basePt!.expectedDamageOnMiss).toStringAsFixed(1)} dmg',
                    subtext: 'Guaranteed',
                    color: missColor,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$label: ', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color)),
              ],
            ),
            Text(subtext, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _DprChartPainter extends CustomPainter {
  final DprCurveData baselineCurve;
  final DprCurveData? powerCurve;
  final DprCurveData? advantageCurve;
  final DprCurveData? disadvantageCurve;
  final int minAc;
  final int maxAc;
  final double yMax;
  final int activeAc;
  final int? breakEvenAc;
  final double animProgress;
  final double pulseValue;
  final bool isDark;
  final Color baseColor;
  final Color powerColor;
  final Color advColor;
  final Color disColor;
  final Color critColor;
  final Color missColor;
  final TabletopColors tabletop;
  final DprChartMode chartMode;

  _DprChartPainter({
    required this.baselineCurve,
    this.powerCurve,
    this.advantageCurve,
    this.disadvantageCurve,
    required this.minAc,
    required this.maxAc,
    required this.yMax,
    required this.activeAc,
    this.breakEvenAc,
    required this.animProgress,
    required this.pulseValue,
    required this.isDark,
    required this.baseColor,
    required this.powerColor,
    required this.advColor,
    required this.disColor,
    required this.critColor,
    required this.missColor,
    required this.tabletop,
    required this.chartMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 44.0;
    const rightPadding = 20.0;
    const topPadding = 24.0;
    const bottomPadding = 30.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: isDark ? Colors.white60 : Colors.black54,
      fontSize: 10,
      fontFamily: 'monospace',
      fontWeight: FontWeight.w600,
    );

    // 1. Draw Horizontal Y Grid Lines & Labels
    const ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      final frac = i / ySteps;
      final y = topPadding + (chartHeight * (1.0 - frac));
      final val = (yMax * frac).round();
      final labelText = chartMode == DprChartMode.accuracy ? '$val%' : '$val';

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final span = TextSpan(text: labelText, style: textStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 8, y - (tp.height / 2)));
    }

    // 2. Draw Vertical X Grid Lines & Labels (every 5 ACs)
    for (int ac = minAc; ac <= maxAc; ac += 5) {
      final xFrac = (ac - minAc) / (maxAc - minAc);
      final x = leftPadding + (chartWidth * xFrac);

      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, topPadding + chartHeight),
        gridPaint,
      );

      final span = TextSpan(text: 'AC $ac', style: textStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - (tp.width / 2), topPadding + chartHeight + 8));
    }

    // Helper to map (ac, val) to Canvas Offset
    Offset toOffset(int ac, double val) {
      final xFrac = (ac - minAc) / (maxAc - minAc);
      final yFrac = (val / yMax).clamp(0.0, 1.0);
      final x = leftPadding + (chartWidth * xFrac);
      final y = topPadding + (chartHeight * (1.0 - (yFrac * animProgress)));
      return Offset(x, y);
    }

    // 3. Draw Curves According to Chart Mode
    if (chartMode == DprChartMode.dpr) {
      // Disadvantage -> Advantage -> Baseline -> Power Attack
      if (disadvantageCurve != null) {
        _drawSmoothCurve(
          canvas: canvas,
          curvePoints: [
            for (int ac = minAc; ac <= maxAc; ac++)
              Offset(ac.toDouble(), disadvantageCurve!.pointAt(ac)?.dpr ?? 0.0),
          ],
          chartHeight: chartHeight,
          topPadding: topPadding,
          leftPadding: leftPadding,
          chartWidth: chartWidth,
          color: disColor,
          fillGradient: true,
          toOffset: toOffset,
        );
      }

      if (advantageCurve != null) {
        _drawSmoothCurve(
          canvas: canvas,
          curvePoints: [
            for (int ac = minAc; ac <= maxAc; ac++)
              Offset(ac.toDouble(), advantageCurve!.pointAt(ac)?.dpr ?? 0.0),
          ],
          chartHeight: chartHeight,
          topPadding: topPadding,
          leftPadding: leftPadding,
          chartWidth: chartWidth,
          color: advColor,
          fillGradient: true,
          toOffset: toOffset,
        );
      }

      _drawSmoothCurve(
        canvas: canvas,
        curvePoints: [
          for (int ac = minAc; ac <= maxAc; ac++)
            Offset(ac.toDouble(), baselineCurve.pointAt(ac)?.dpr ?? 0.0),
        ],
        chartHeight: chartHeight,
        topPadding: topPadding,
        leftPadding: leftPadding,
        chartWidth: chartWidth,
        color: baseColor,
        fillGradient: true,
        toOffset: toOffset,
      );

      if (powerCurve != null) {
        _drawSmoothCurve(
          canvas: canvas,
          curvePoints: [
            for (int ac = minAc; ac <= maxAc; ac++)
              Offset(ac.toDouble(), powerCurve!.pointAt(ac)?.dpr ?? 0.0),
          ],
          chartHeight: chartHeight,
          topPadding: topPadding,
          leftPadding: leftPadding,
          chartWidth: chartWidth,
          color: powerColor,
          fillGradient: true,
          toOffset: toOffset,
        );
      }
    } else if (chartMode == DprChartMode.accuracy) {
      // Draw Hit Chance Curves (Disadvantage, Advantage, Normal) & Crit Chance
      if (disadvantageCurve != null) {
        _drawSmoothCurve(
          canvas: canvas,
          curvePoints: [
            for (int ac = minAc; ac <= maxAc; ac++)
              Offset(ac.toDouble(), (disadvantageCurve!.pointAt(ac)?.hitChance ?? 0.0) * 100),
          ],
          chartHeight: chartHeight,
          topPadding: topPadding,
          leftPadding: leftPadding,
          chartWidth: chartWidth,
          color: disColor,
          fillGradient: false,
          toOffset: toOffset,
        );
      }

      if (advantageCurve != null) {
        _drawSmoothCurve(
          canvas: canvas,
          curvePoints: [
            for (int ac = minAc; ac <= maxAc; ac++)
              Offset(ac.toDouble(), (advantageCurve!.pointAt(ac)?.hitChance ?? 0.0) * 100),
          ],
          chartHeight: chartHeight,
          topPadding: topPadding,
          leftPadding: leftPadding,
          chartWidth: chartWidth,
          color: advColor,
          fillGradient: false,
          toOffset: toOffset,
        );
      }

      _drawSmoothCurve(
        canvas: canvas,
        curvePoints: [
          for (int ac = minAc; ac <= maxAc; ac++)
            Offset(ac.toDouble(), (baselineCurve.pointAt(ac)?.hitChance ?? 0.0) * 100),
        ],
        chartHeight: chartHeight,
        topPadding: topPadding,
        leftPadding: leftPadding,
        chartWidth: chartWidth,
        color: baseColor,
        fillGradient: true,
        toOffset: toOffset,
      );

      _drawSmoothCurve(
        canvas: canvas,
        curvePoints: [
          for (int ac = minAc; ac <= maxAc; ac++)
            Offset(ac.toDouble(), (baselineCurve.pointAt(ac)?.critChance ?? 0.0) * 100),
        ],
        chartHeight: chartHeight,
        topPadding: topPadding,
        leftPadding: leftPadding,
        chartWidth: chartWidth,
        color: critColor,
        fillGradient: false,
        toOffset: toOffset,
      );
    } else {
      // Damage Breakdown: Hit Damage, Crit Damage, Miss/Graze Damage
      _drawSmoothCurve(
        canvas: canvas,
        curvePoints: [
          for (int ac = minAc; ac <= maxAc; ac++)
            Offset(ac.toDouble(), baselineCurve.pointAt(ac)?.expectedDamageOnCrit ?? 0.0),
        ],
        chartHeight: chartHeight,
        topPadding: topPadding,
        leftPadding: leftPadding,
        chartWidth: chartWidth,
        color: critColor,
        fillGradient: true,
        toOffset: toOffset,
      );

      _drawSmoothCurve(
        canvas: canvas,
        curvePoints: [
          for (int ac = minAc; ac <= maxAc; ac++)
            Offset(ac.toDouble(), baselineCurve.pointAt(ac)?.expectedDamageOnHit ?? 0.0),
        ],
        chartHeight: chartHeight,
        topPadding: topPadding,
        leftPadding: leftPadding,
        chartWidth: chartWidth,
        color: baseColor,
        fillGradient: true,
        toOffset: toOffset,
      );

      if (baselineCurve.points.values.any((p) => p.expectedDamageOnMiss > 0)) {
        _drawSmoothCurve(
          canvas: canvas,
          curvePoints: [
            for (int ac = minAc; ac <= maxAc; ac++)
              Offset(ac.toDouble(), baselineCurve.pointAt(ac)?.expectedDamageOnMiss ?? 0.0),
          ],
          chartHeight: chartHeight,
          topPadding: topPadding,
          leftPadding: leftPadding,
          chartWidth: chartWidth,
          color: missColor,
          fillGradient: false,
          toOffset: toOffset,
        );
      }
    }

    // 4. Break-Even Crossover Beacon & Indicator (in DPR mode)
    if (chartMode == DprChartMode.dpr &&
        breakEvenAc != null &&
        breakEvenAc! >= minAc &&
        breakEvenAc! <= maxAc) {
      final xFrac = (breakEvenAc! - minAc) / (maxAc - minAc);
      final beaconX = leftPadding + (chartWidth * xFrac);

      // Glowing dashed vertical beacon line
      final beaconPaint = Paint()
        ..color = isDark
            ? Colors.amberAccent.withValues(alpha: 0.4 + (pulseValue * 0.25))
            : Colors.amber.shade400
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      // Draw dashed beacon
      const dashHeight = 5.0;
      const dashSpace = 4.0;
      double startY = topPadding;
      while (startY < topPadding + chartHeight) {
        canvas.drawLine(
          Offset(beaconX, startY),
          Offset(beaconX, math.min(startY + dashHeight, topPadding + chartHeight)),
          beaconPaint,
        );
        startY += dashHeight + dashSpace;
      }

      // Crossover beacon diamond
      final basePt = baselineCurve.pointAt(breakEvenAc!);
      if (basePt != null) {
        final crossPos = toOffset(breakEvenAc!, basePt.dpr);

        // Pulsing halo
        final haloRadius = 7.0 + (pulseValue * 5.0);
        canvas.drawCircle(
          crossPos,
          haloRadius,
          Paint()
            ..color = Colors.amber.withValues(alpha: 0.35 * (1.0 - (pulseValue * 0.5)))
            ..style = PaintingStyle.fill,
        );

        // Center diamond marker
        final diamondPath = Path()
          ..moveTo(crossPos.dx, crossPos.dy - 6)
          ..lineTo(crossPos.dx + 6, crossPos.dy)
          ..lineTo(crossPos.dx, crossPos.dy + 6)
          ..lineTo(crossPos.dx - 6, crossPos.dy)
          ..close();

        canvas.drawPath(
          diamondPath,
          Paint()
            ..color = isDark ? Colors.amberAccent : const Color(0xFFD97706)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // 5. Active Selected AC Scanner Beam & Pulsing Nodes
    if (activeAc >= minAc && activeAc <= maxAc) {
      final xFrac = (activeAc - minAc) / (maxAc - minAc);
      final activeX = leftPadding + (chartWidth * xFrac);

      // Glowing vertical scanner line
      final scannerGlow = Paint()
        ..color = (isDark ? Colors.cyanAccent : Colors.cyan).withValues(alpha: 0.35)
        ..strokeWidth = 3.5;
      canvas.drawLine(
        Offset(activeX, topPadding),
        Offset(activeX, topPadding + chartHeight),
        scannerGlow,
      );

      final scannerLine = Paint()
        ..color = isDark ? Colors.white : Colors.black87
        ..strokeWidth = 1.6;
      canvas.drawLine(
        Offset(activeX, topPadding),
        Offset(activeX, topPadding + chartHeight),
        scannerLine,
      );

      // Draw glowing nodes on each active curve
      void drawGlowingNode(double? val, Color color) {
        if (val == null) return;
        final pos = toOffset(activeAc, val);

        // Outer pulsing radar wave
        final pulseRadius = 6.0 + (pulseValue * 6.0);
        canvas.drawCircle(
          pos,
          pulseRadius,
          Paint()
            ..color = color.withValues(alpha: 0.4 * (1.0 - (pulseValue * 0.7)))
            ..style = PaintingStyle.fill,
        );

        // Core solid node
        canvas.drawCircle(pos, 5.5, Paint()..color = color);
        canvas.drawCircle(
          pos,
          2.5,
          Paint()..color = isDark ? const Color(0xFF0B0A14) : Colors.white,
        );
      }

      if (chartMode == DprChartMode.dpr) {
        drawGlowingNode(baselineCurve.pointAt(activeAc)?.dpr, baseColor);
        if (powerCurve != null) {
          drawGlowingNode(powerCurve!.pointAt(activeAc)?.dpr, powerColor);
        }
        if (advantageCurve != null) {
          drawGlowingNode(advantageCurve!.pointAt(activeAc)?.dpr, advColor);
        }
        if (disadvantageCurve != null) {
          drawGlowingNode(disadvantageCurve!.pointAt(activeAc)?.dpr, disColor);
        }
      } else if (chartMode == DprChartMode.accuracy) {
        drawGlowingNode((baselineCurve.pointAt(activeAc)?.hitChance ?? 0) * 100, baseColor);
        if (advantageCurve != null) {
          drawGlowingNode((advantageCurve!.pointAt(activeAc)?.hitChance ?? 0) * 100, advColor);
        }
        if (disadvantageCurve != null) {
          drawGlowingNode((disadvantageCurve!.pointAt(activeAc)?.hitChance ?? 0) * 100, disColor);
        }
        drawGlowingNode((baselineCurve.pointAt(activeAc)?.critChance ?? 0) * 100, critColor);
      } else {
        drawGlowingNode(baselineCurve.pointAt(activeAc)?.expectedDamageOnHit, baseColor);
        drawGlowingNode(baselineCurve.pointAt(activeAc)?.expectedDamageOnCrit, critColor);
        if ((baselineCurve.pointAt(activeAc)?.expectedDamageOnMiss ?? 0) > 0) {
          drawGlowingNode(baselineCurve.pointAt(activeAc)?.expectedDamageOnMiss, missColor);
        }
      }
    }
  }

  void _drawSmoothCurve({
    required Canvas canvas,
    required List<Offset> curvePoints,
    required double chartHeight,
    required double topPadding,
    required double leftPadding,
    required double chartWidth,
    required Color color,
    required bool fillGradient,
    required Offset Function(int ac, double val) toOffset,
  }) {
    final points = <Offset>[];
    for (final pt in curvePoints) {
      points.add(toOffset(pt.dx.toInt(), pt.dy));
    }

    if (points.length < 2) return;

    // Construct smooth cubic Bezier path
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    final fillPath = Path()..moveTo(points.first.dx, topPadding + chartHeight);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      // Catmull-Rom to Cubic Bezier conversion
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      fillPath.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    fillPath.lineTo(points.last.dx, topPadding + chartHeight);
    fillPath.close();

    // 1. Under-Curve Radiant Gradient
    if (fillGradient) {
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isDark ? 0.28 : 0.16),
          color.withValues(alpha: 0.0),
        ],
      );
      final fillPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
        );
      canvas.drawPath(fillPath, fillPaint);
    }

    // 2. Soft Outer Neon Glow Pass
    final glowPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.35 : 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    // 3. Crisp Core Line Pass
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _DprChartPainter oldDelegate) {
    return oldDelegate.animProgress != animProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.activeAc != activeAc ||
        oldDelegate.breakEvenAc != breakEvenAc ||
        oldDelegate.baselineCurve != baselineCurve ||
        oldDelegate.powerCurve != powerCurve ||
        oldDelegate.advantageCurve != advantageCurve ||
        oldDelegate.disadvantageCurve != disadvantageCurve ||
        oldDelegate.chartMode != chartMode ||
        oldDelegate.isDark != isDark;
  }
}
