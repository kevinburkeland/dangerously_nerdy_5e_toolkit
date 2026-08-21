import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../models/dpr/dpr_models.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// Highly animated, interactive 5e DPR Canvas Chart with multi-curve comparisons,
/// touch/mouse scrubbing, break-even crossover indicators, and glowing gradient fills.
class DprChartWidget extends StatefulWidget {
  final DprCurveData baselineCurve;
  final DprCurveData? powerAttackCurve;
  final DprCurveData? advantageCurve;
  final int selectedAc;
  final int? breakEvenAc;
  final ValueChanged<int> onAcChanged;
  final bool showPowerAttack;
  final bool showAdvantage;

  const DprChartWidget({
    super.key,
    required this.baselineCurve,
    this.powerAttackCurve,
    this.advantageCurve,
    required this.selectedAc,
    this.breakEvenAc,
    required this.onAcChanged,
    this.showPowerAttack = true,
    this.showAdvantage = false,
  });

  @override
  State<DprChartWidget> createState() => _DprChartWidgetState();
}

class _DprChartWidgetState extends State<DprChartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _curveAnimation;

  int? _hoverAc;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _curveAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(DprChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.baselineCurve.profile.id != widget.baselineCurve.profile.id ||
        oldWidget.showPowerAttack != widget.showPowerAttack ||
        oldWidget.showAdvantage != widget.showAdvantage) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
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

    // Calculate maximum DPR to scale Y axis comfortably
    var maxDpr = widget.baselineCurve.maxDpr;
    if (widget.showPowerAttack && widget.powerAttackCurve != null) {
      maxDpr = math.max(maxDpr, widget.powerAttackCurve!.maxDpr);
    }
    if (widget.showAdvantage && widget.advantageCurve != null) {
      maxDpr = math.max(maxDpr, widget.advantageCurve!.maxDpr);
    }
    // Round max DPR up to nearest 5 or 10 with margin
    final yMax = (math.max(10.0, (maxDpr * 1.15) / 5.0).ceil() * 5).toDouble();

    final activeAc = _hoverAc ?? widget.selectedAc;
    final basePt = widget.baselineCurve.pointAt(activeAc);
    final powerPt = widget.showPowerAttack ? widget.powerAttackCurve?.pointAt(activeAc) : null;
    final advPt = widget.showAdvantage ? widget.advantageCurve?.pointAt(activeAc) : null;

    final baseColor = isDark ? Colors.cyanAccent : const Color(0xFF0284C7);
    final powerColor = isDark ? Colors.amberAccent : const Color(0xFFD97706);
    final advColor = isDark ? const Color(0xFF69F0AE) : const Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Interactive Hover / Selected AC Tooltip Banner
        _buildActiveTooltipBanner(
          activeAc: activeAc,
          basePt: basePt,
          powerPt: powerPt,
          advPt: advPt,
          baseColor: baseColor,
          powerColor: powerColor,
          advColor: advColor,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        // Animated Canvas Chart
        SizedBox(
          height: 240,
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
                  onHorizontalDragStart: (details) => _handleDrag(details.localPosition, constraints.biggest, minAc, maxAc),
                  onHorizontalDragUpdate: (details) => _handleDrag(details.localPosition, constraints.biggest, minAc, maxAc),
                  onTapDown: (details) => _handleDrag(details.localPosition, constraints.biggest, minAc, maxAc),
                  child: AnimatedBuilder(
                    animation: _curveAnimation,
                    builder: (context, _) {
                      return CustomPaint(
                        size: Size(constraints.maxWidth, 240),
                        painter: _DprChartPainter(
                          baselineCurve: widget.baselineCurve,
                          powerCurve: widget.showPowerAttack ? widget.powerAttackCurve : null,
                          advantageCurve: widget.showAdvantage ? widget.advantageCurve : null,
                          minAc: minAc,
                          maxAc: maxAc,
                          yMax: yMax,
                          activeAc: activeAc,
                          breakEvenAc: widget.breakEvenAc,
                          animProgress: _curveAnimation.value,
                          isDark: isDark,
                          baseColor: baseColor,
                          powerColor: powerColor,
                          advColor: advColor,
                          tabletop: tabletop,
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
    required Color baseColor,
    required Color powerColor,
    required Color advColor,
    required bool isDark,
  }) {
    final baseDpr = basePt?.dpr ?? 0.0;
    final powerDpr = powerPt?.dpr ?? 0.0;
    final dprDiff = powerDpr - baseDpr;
    final isGwmBetter = dprDiff > 0.05;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1A2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          // Target AC Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF312E48) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                ),
                child: Text(
                  'Target AC $activeAc',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (widget.breakEvenAc != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (activeAc <= widget.breakEvenAc!)
                        ? (isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.shade100)
                        : (isDark ? Colors.cyan.withValues(alpha: 0.2) : Colors.cyan.shade100),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    activeAc <= widget.breakEvenAc! ? '⚡ GWM Recommended' : '🛡️ Normal Attack Optimal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: activeAc <= widget.breakEvenAc!
                          ? (isDark ? Colors.amberAccent : const Color(0xFFB45309))
                          : (isDark ? Colors.cyanAccent : const Color(0xFF0369A1)),
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Readouts
          Wrap(
            spacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Baseline
              _buildMetricChip(
                label: 'Normal',
                value: '${baseDpr.toStringAsFixed(1)} DPR',
                subtext: '${((basePt?.hitChance ?? 0) * 100).round()}% hit',
                color: baseColor,
              ),

              // GWM / Power Attack
              if (powerPt != null)
                _buildMetricChip(
                  label: 'GWM / SS',
                  value: '${powerDpr.toStringAsFixed(1)} DPR',
                  subtext: isGwmBetter
                      ? '+${dprDiff.toStringAsFixed(1)} (+${((dprDiff / math.max(0.1, baseDpr)) * 100).round()}%)'
                      : '${dprDiff.toStringAsFixed(1)} DPR',
                  color: powerColor,
                ),

              // Advantage
              if (advPt != null)
                _buildMetricChip(
                  label: 'Advantage',
                  value: '${(advPt.dpr).toStringAsFixed(1)} DPR',
                  subtext: '${((advPt.hitChance) * 100).round()}% hit',
                  color: advColor,
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
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
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
  final int minAc;
  final int maxAc;
  final double yMax;
  final int activeAc;
  final int? breakEvenAc;
  final double animProgress;
  final bool isDark;
  final Color baseColor;
  final Color powerColor;
  final Color advColor;
  final TabletopColors tabletop;

  _DprChartPainter({
    required this.baselineCurve,
    this.powerCurve,
    this.advantageCurve,
    required this.minAc,
    required this.maxAc,
    required this.yMax,
    required this.activeAc,
    this.breakEvenAc,
    required this.animProgress,
    required this.isDark,
    required this.baseColor,
    required this.powerColor,
    required this.advColor,
    required this.tabletop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 44.0;
    const rightPadding = 20.0;
    const topPadding = 20.0;
    const bottomPadding = 28.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: isDark ? Colors.white54 : Colors.black45,
      fontSize: 10,
      fontFamily: 'monospace',
    );

    // 1. Draw Horizontal Y Grid Lines & Labels (0, yMax/4, yMax/2, 3*yMax/4, yMax)
    const ySteps = 4;
    for (int i = 0; i <= ySteps; i++) {
      final frac = i / ySteps;
      final y = topPadding + (chartHeight * (1.0 - frac));
      final val = (yMax * frac).round();

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      final span = TextSpan(text: '$val', style: textStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 6, y - (tp.height / 2)));
    }

    // 2. Draw Vertical X Grid Lines & Labels (every 5 ACs: 5, 10, 15, 20, 25, 30)
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
      tp.paint(canvas, Offset(x - (tp.width / 2), topPadding + chartHeight + 6));
    }

    // Helper to map (ac, dpr) to Canvas Offset
    Offset toOffset(int ac, double dpr) {
      final xFrac = (ac - minAc) / (maxAc - minAc);
      final yFrac = (dpr / yMax).clamp(0.0, 1.0);
      final x = leftPadding + (chartWidth * xFrac);
      final y = topPadding + (chartHeight * (1.0 - (yFrac * animProgress)));
      return Offset(x, y);
    }

    // 3. Draw Curves (Advantage -> Baseline -> Power Attack)
    if (advantageCurve != null) {
      _drawSingleCurve(
        canvas: canvas,
        curveData: advantageCurve!,
        chartHeight: chartHeight,
        topPadding: topPadding,
        leftPadding: leftPadding,
        chartWidth: chartWidth,
        color: advColor,
        isDashed: false,
        fillGradient: true,
        toOffset: toOffset,
      );
    }

    _drawSingleCurve(
      canvas: canvas,
      curveData: baselineCurve,
      chartHeight: chartHeight,
      topPadding: topPadding,
      leftPadding: leftPadding,
      chartWidth: chartWidth,
      color: baseColor,
      isDashed: false,
      fillGradient: true,
      toOffset: toOffset,
    );

    if (powerCurve != null) {
      _drawSingleCurve(
        canvas: canvas,
        curveData: powerCurve!,
        chartHeight: chartHeight,
        topPadding: topPadding,
        leftPadding: leftPadding,
        chartWidth: chartWidth,
        color: powerColor,
        isDashed: false,
        fillGradient: true,
        toOffset: toOffset,
      );
    }

    // 4. Break-Even Crossover Beacon & Indicator
    if (breakEvenAc != null && breakEvenAc! >= minAc && breakEvenAc! <= maxAc) {
      final xFrac = (breakEvenAc! - minAc) / (maxAc - minAc);
      final beaconX = leftPadding + (chartWidth * xFrac);

      final beaconPaint = Paint()
        ..color = isDark ? Colors.amber.withValues(alpha: 0.35) : Colors.amber.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(beaconX, topPadding),
        Offset(beaconX, topPadding + chartHeight),
        beaconPaint,
      );

      // Crossover point circle
      final basePt = baselineCurve.pointAt(breakEvenAc!);
      if (basePt != null) {
        final crossPos = toOffset(breakEvenAc!, basePt.dpr);
        final glowPaint = Paint()
          ..color = isDark ? Colors.amberAccent : const Color(0xFFD97706)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(crossPos, 5.0, glowPaint);
        canvas.drawCircle(
          crossPos,
          8.0,
          Paint()
            ..color = (isDark ? Colors.amberAccent : Colors.amber).withValues(alpha: 0.3)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // 5. Active Selected AC Marker Line & Circle Indicators
    if (activeAc >= minAc && activeAc <= maxAc) {
      final xFrac = (activeAc - minAc) / (maxAc - minAc);
      final activeX = leftPadding + (chartWidth * xFrac);

      final activeLinePaint = Paint()
        ..color = isDark ? Colors.white70 : Colors.black87
        ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(activeX, topPadding),
        Offset(activeX, topPadding + chartHeight),
        activeLinePaint,
      );

      // Active Points
      void drawPointMarker(DprPoint? pt, Color color) {
        if (pt == null) return;
        final pos = toOffset(activeAc, pt.dpr);
        canvas.drawCircle(pos, 5, Paint()..color = color);
        canvas.drawCircle(
          pos,
          2.5,
          Paint()..color = isDark ? const Color(0xFF1E1A2E) : Colors.white,
        );
      }

      drawPointMarker(baselineCurve.pointAt(activeAc), baseColor);
      if (powerCurve != null) {
        drawPointMarker(powerCurve!.pointAt(activeAc), powerColor);
      }
      if (advantageCurve != null) {
        drawPointMarker(advantageCurve!.pointAt(activeAc), advColor);
      }
    }
  }

  void _drawSingleCurve({
    required Canvas canvas,
    required DprCurveData curveData,
    required double chartHeight,
    required double topPadding,
    required double leftPadding,
    required double chartWidth,
    required Color color,
    required bool isDashed,
    required bool fillGradient,
    required Offset Function(int ac, double dpr) toOffset,
  }) {
    final path = Path();
    final fillPath = Path();

    bool isFirst = true;
    Offset firstPos = Offset.zero;
    Offset lastPos = Offset.zero;

    for (int ac = minAc; ac <= maxAc; ac++) {
      final pt = curveData.pointAt(ac);
      if (pt == null) continue;

      final pos = toOffset(ac, pt.dpr);
      if (isFirst) {
        path.moveTo(pos.dx, pos.dy);
        fillPath.moveTo(pos.dx, topPadding + chartHeight);
        fillPath.lineTo(pos.dx, pos.dy);
        firstPos = pos;
        isFirst = false;
      } else {
        path.lineTo(pos.dx, pos.dy);
        fillPath.lineTo(pos.dx, pos.dy);
      }
      lastPos = pos;
    }

    if (!isFirst) {
      fillPath.lineTo(lastPos.dx, topPadding + chartHeight);
      fillPath.lineTo(firstPos.dx, topPadding + chartHeight);
      fillPath.close();

      // Subtle translucent gradient under curve
      if (fillGradient) {
        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: isDark ? 0.20 : 0.12),
            color.withValues(alpha: 0.0),
          ],
        );
        final fillPaint = Paint()
          ..shader = gradient.createShader(
            Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
          );
        canvas.drawPath(fillPath, fillPaint);
      }

      // Line Stroke
      final strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DprChartPainter oldDelegate) {
    return oldDelegate.animProgress != animProgress ||
        oldDelegate.activeAc != activeAc ||
        oldDelegate.breakEvenAc != breakEvenAc ||
        oldDelegate.baselineCurve != baselineCurve ||
        oldDelegate.powerCurve != powerCurve ||
        oldDelegate.advantageCurve != advantageCurve ||
        oldDelegate.isDark != isDark;
  }
}
