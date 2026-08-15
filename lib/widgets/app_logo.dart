import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../services/haptic_service.dart';

/// A pure Flutter, vector-rendered tech + fantasy d20 logo.
/// 100% Vector geometry (no external font dependencies), ensuring pixel-perfect
/// rendering across all platforms, web, and exported icons.
class AppLogo extends StatefulWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool showGlow;
  final bool showRings;
  final bool animated;
  final bool interactive;
  final VoidCallback? onTap;
  final String semanticsLabel;

  /// Default cyber cyan colors for static and branding renders
  static const Color defaultPrimary = Color(0xFF00E5FF); // Electric Cyber Cyan
  static const Color defaultSecondary = Color(0xFF18FFFF); // Luminous Neon Aqua

  const AppLogo({
    super.key,
    this.size = 32,
    this.primaryColor,
    this.secondaryColor,
    this.showGlow = true,
    this.showRings = true,
    this.animated = false,
    this.interactive = true,
    this.onTap,
    this.semanticsLabel = 'DangerouslyNerdy 5e Toolkit Logo',
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AppLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !oldWidget.animated) {
      _controller.repeat();
    } else if (!widget.animated && oldWidget.animated) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hovering) {
    if (!widget.interactive || widget.animated) return;
    setState(() => _isHovered = hovering);

    if (hovering) {
      _controller.repeat();
    } else {
      // Ease gently to a stop
      final currentVal = _controller.value;
      _controller.stop();
      _controller.animateTo(
        (currentVal.ceilToDouble()).toDouble(),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleTap() {
    if (!widget.interactive) return;
    HapticService.selectionTick(context);

    // Smooth, graceful 360-degree momentum spin on tap
    _controller.stop();
    final startVal = _controller.value;
    _controller.animateTo(
      startVal + 1.0,
      duration: const Duration(milliseconds: 1300),
      curve: Curves.easeOutCubic,
    );

    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final secondary = widget.secondaryColor ?? theme.colorScheme.secondary;

    Widget logoContent = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: D20TechPainter(
            primaryColor: primary,
            secondaryColor: secondary,
            showGlow: widget.showGlow,
            showRings: widget.showRings,
            rotation: _controller.value * 2 * math.pi,
          ),
        );
      },
    );

    if (widget.interactive) {
      logoContent = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _handleHover(true),
        onExit: (_) => _handleHover(false),
        child: GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedScale(
            scale: _isHovered ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: logoContent,
          ),
        ),
      );
    }

    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      button: widget.interactive,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: logoContent,
      ),
    );
  }
}

class D20TechPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool showGlow;
  final bool showRings;
  final double rotation;

  D20TechPainter({
    this.primaryColor = AppLogo.defaultPrimary,
    this.secondaryColor = AppLogo.defaultSecondary,
    this.showGlow = true,
    this.showRings = true,
    this.rotation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDimension = math.min(size.width, size.height);
    final scale = minDimension / 100.0;

    // Radius constants designed to comfortably fit inside 100x100 space with margin
    final d20Radius = 30.0 * scale;
    final ringRadius = 37.5 * scale;
    final outerRingRadius = 41.5 * scale;

    // 1. Ambient Background Glow
    if (showGlow) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            primaryColor.withValues(alpha: 0.35),
            secondaryColor.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: d20Radius * 1.45));

      canvas.drawCircle(center, d20Radius * 1.45, glowPaint);
    }

    // 2. Arcane-Cyber Tech Reticle Rings & Curved Branding
    if (showRings && scale >= 0.25) {
      _paintTechRings(canvas, center, ringRadius, outerRingRadius, scale);
    }

    // 3. Icosahedron (d20) Geometry Calculation
    final rOut = d20Radius;
    final rIn = d20Radius * 0.55;

    // Outer 6 vertices of the hexagon silhouette (V0 to V5)
    final vOut = List.generate(6, (i) {
      final angle = -math.pi / 2 + (i * math.pi / 3);
      return Offset(
        center.dx + rOut * math.cos(angle),
        center.dy + rOut * math.sin(angle),
      );
    });

    // Inner 3 vertices of the center upward-pointing triangle (A, B, C)
    final vIn = [
      Offset(center.dx, center.dy - rIn),
      Offset(center.dx + rIn * math.cos(math.pi / 6), center.dy + rIn * math.sin(math.pi / 6)),
      Offset(center.dx + rIn * math.cos(5 * math.pi / 6), center.dy + rIn * math.sin(5 * math.pi / 6)),
    ];

    final pA = vIn[0];
    final pB = vIn[1];
    final pC = vIn[2];

    final p0 = vOut[0];
    final p1 = vOut[1];
    final p2 = vOut[2];
    final p3 = vOut[3];
    final p4 = vOut[4];
    final p5 = vOut[5];

    // 4. Draw 10 Facets with dynamic lighting & gradients
    final facets = [
      // 3 Adjacent Inner-to-Outer Facets
      _Facet([pA, p1, pB], 0.70, false), // Upper Right
      _Facet([pB, p3, pC], 0.40, false), // Bottom
      _Facet([pC, p5, pA], 0.85, false), // Upper Left

      // 6 Outer Hexagon Corner Facets
      _Facet([pA, p0, p1], 0.90, false), // Top Right
      _Facet([pA, p5, p0], 0.95, false), // Top Left
      _Facet([pB, p1, p2], 0.60, false), // Right Upper
      _Facet([pB, p2, p3], 0.45, false), // Right Lower
      _Facet([pC, p3, p4], 0.35, false), // Left Lower
      _Facet([pC, p4, p5], 0.65, false), // Left Upper

      // Center Core Facet (Face with DN Crest)
      _Facet([pA, pB, pC], 1.0, true),
    ];

    for (final facet in facets) {
      _drawFacet(canvas, facet, center, scale);
    }

    // 5. High-Tech Wireframe Edges
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.4 * scale)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = primaryColor.withValues(alpha: 0.9);

    final innerEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, 1.8 * scale)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = secondaryColor.withValues(alpha: 0.95);

    // Outer silhouette edges
    final hexPath = Path()..moveTo(p0.dx, p0.dy);
    for (int i = 1; i < 6; i++) {
      hexPath.lineTo(vOut[i].dx, vOut[i].dy);
    }
    hexPath.close();
    canvas.drawPath(hexPath, edgePaint);

    // Inner connecting edges
    final lines = [
      [pA, p0], [pA, p1], [pA, p5],
      [pB, p1], [pB, p2], [pB, p3],
      [pC, p3], [pC, p4], [pC, p5],
    ];

    for (final line in lines) {
      canvas.drawLine(line[0], line[1], edgePaint);
    }

    // Center Triangle (Primary highlight)
    final centerTriPath = Path()
      ..moveTo(pA.dx, pA.dy)
      ..lineTo(pB.dx, pB.dy)
      ..lineTo(pC.dx, pC.dy)
      ..close();
    canvas.drawPath(centerTriPath, innerEdgePaint);

    // 6. Glowing Circuit Nodes at Vertices
    if (scale >= 0.30) {
      final nodePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = secondaryColor;

      final nodeGlow = Paint()
        ..style = PaintingStyle.fill
        ..color = primaryColor.withValues(alpha: 0.6);

      final allVertices = [...vOut, ...vIn];
      final nodeRadius = 1.5 * scale;

      for (final v in allVertices) {
        canvas.drawCircle(v, nodeRadius * 1.8, nodeGlow);
        canvas.drawCircle(v, nodeRadius, nodePaint);
      }
    }

    // 7. Pure Vector "DN" Monogram Crest (100% vector, zero font dependencies)
    _paintVectorDNMonogram(canvas, center, scale);
  }

  void _paintTechRings(
    Canvas canvas,
    Offset center,
    double ringRadius,
    double outerRingRadius,
    double scale,
  ) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, 1.1 * scale)
      ..color = primaryColor.withValues(alpha: 0.35);

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, 1.8 * scale)
      ..strokeCap = StrokeCap.round
      ..color = secondaryColor.withValues(alpha: 0.7);

    // Concentric outer reticle
    canvas.drawCircle(center, ringRadius, ringPaint);

    // 4 Arc segments / Cybernetic reticle brackets
    final arcAngles = [
      rotation + 0.15,
      rotation + math.pi / 2 + 0.15,
      rotation + math.pi + 0.15,
      rotation + 3 * math.pi / 2 + 0.15,
    ];
    const sweep = math.pi / 3.5;

    for (final start in arcAngles) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRingRadius),
        start,
        sweep,
        false,
        dashPaint,
      );
    }

    // Reticle Cardinal Ticks
    if (scale >= 0.45) {
      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale
        ..color = secondaryColor.withValues(alpha: 0.85);

      for (int i = 0; i < 4; i++) {
        // Skip bottom cardinal tick if curved branding is rendered along the bottom
        if (scale >= 0.5 && i == 1) continue;

        final angle = rotation + (i * math.pi / 2);
        final pStart = Offset(
          center.dx + (outerRingRadius - 2 * scale) * math.cos(angle),
          center.dy + (outerRingRadius - 2 * scale) * math.sin(angle),
        );
        final pEnd = Offset(
          center.dx + (outerRingRadius + 3.5 * scale) * math.cos(angle),
          center.dy + (outerRingRadius + 3.5 * scale) * math.sin(angle),
        );
        canvas.drawLine(pStart, pEnd, tickPaint);
      }
    }

    // High-tech curved vector brand lettering along outer arc (pure vector)
    if (scale >= 0.5) {
      _paintVectorCurvedBrandText(canvas, center, outerRingRadius + 4.2 * scale, scale);
    }
  }

  void _paintVectorCurvedBrandText(
    Canvas canvas,
    Offset center,
    double radius,
    double scale,
  ) {
    const brandText = 'DANGEROUSLY NERDY';
    final charH = 3.4 * scale;
    final charW = 2.3 * scale;
    const charSpacing = 0.076; // radians per character
    const totalAngle = (brandText.length - 1) * charSpacing;
    const startAngle = (math.pi / 2) + (totalAngle / 2);

    final textPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = secondaryColor;

    for (int i = 0; i < brandText.length; i++) {
      final char = brandText[i];
      if (char == ' ') continue;

      final angle = startAngle - (i * charSpacing);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle - math.pi / 2);
      canvas.translate(-charW / 2, radius);

      _drawVectorGlyph(canvas, char, charW, charH, textPaint);
      canvas.restore();
    }
  }

  void _drawFacet(
    Canvas canvas,
    _Facet facet,
    Offset center,
    double scale,
  ) {
    final path = Path()..moveTo(facet.points[0].dx, facet.points[0].dy);
    for (int i = 1; i < facet.points.length; i++) {
      path.lineTo(facet.points[i].dx, facet.points[i].dy);
    }
    path.close();

    final cx = (facet.points[0].dx + facet.points[1].dx + facet.points[2].dx) / 3;
    final cy = (facet.points[0].dy + facet.points[1].dy + facet.points[2].dy) / 3;
    final facetCenter = Offset(cx, cy);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    if (facet.isCenter) {
      // Deep obsidian void base with luminous cyber cyan gradient
      fillPaint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(primaryColor, Colors.white, 0.35)!.withValues(alpha: 0.95),
          Color.lerp(primaryColor, const Color(0xFF0F172A), 0.5)!.withValues(alpha: 0.95),
          const Color(0xFF070B14).withValues(alpha: 0.98),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(path.getBounds());
    } else {
      final light = facet.lighting;
      final Color baseShade = Color.lerp(
        const Color(0xFF070B14),
        primaryColor,
        0.15 + 0.55 * light,
      )!;
      final Color highlightShade = Color.lerp(
        baseShade,
        secondaryColor,
        0.35 * light,
      )!;

      fillPaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          highlightShade.withValues(alpha: 0.85),
          baseShade.withValues(alpha: 0.9),
        ],
      ).createShader(Rect.fromCircle(center: facetCenter, radius: 15 * scale));
    }

    canvas.drawPath(path, fillPaint);
  }

  /// Pure Vector DN Monogram - draws stylized D and N vector paths
  void _paintVectorDNMonogram(Canvas canvas, Offset center, double scale) {
    if (scale < 0.16) return;

    final s = scale;
    final cx = center.dx;
    final cy = center.dy + 0.5 * s;

    // Glowing cyan backdrop shadow
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = secondaryColor.withValues(alpha: 0.8);

    // Crisp white foreground vector fill
    final whitePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFFFFF);

    final dPath = Path()
      ..moveTo(cx - 7.5 * s, cy - 5.5 * s)
      ..lineTo(cx - 2.5 * s, cy - 5.5 * s)
      ..lineTo(cx - 0.5 * s, cy - 3.5 * s)
      ..lineTo(cx - 0.5 * s, cy + 3.5 * s)
      ..lineTo(cx - 2.5 * s, cy + 5.5 * s)
      ..lineTo(cx - 7.5 * s, cy + 5.5 * s)
      ..close()
      // Cutout for the D
      ..moveTo(cx - 5.3 * s, cy - 3.3 * s)
      ..lineTo(cx - 3.2 * s, cy - 3.3 * s)
      ..lineTo(cx - 2.4 * s, cy - 2.0 * s)
      ..lineTo(cx - 2.4 * s, cy + 2.0 * s)
      ..lineTo(cx - 3.2 * s, cy + 3.3 * s)
      ..lineTo(cx - 5.3 * s, cy + 3.3 * s)
      ..close();
    dPath.fillType = PathFillType.evenOdd;

    final nPath = Path()
      ..moveTo(cx + 0.8 * s, cy - 5.5 * s)
      ..lineTo(cx + 2.8 * s, cy - 5.5 * s)
      ..lineTo(cx + 5.8 * s, cy + 1.2 * s)
      ..lineTo(cx + 5.8 * s, cy - 5.5 * s)
      ..lineTo(cx + 7.8 * s, cy - 5.5 * s)
      ..lineTo(cx + 7.8 * s, cy + 5.5 * s)
      ..lineTo(cx + 5.8 * s, cy + 5.5 * s)
      ..lineTo(cx + 2.8 * s, cy - 1.2 * s)
      ..lineTo(cx + 2.8 * s, cy + 5.5 * s)
      ..lineTo(cx + 0.8 * s, cy + 5.5 * s)
      ..close();

    // Draw shadow/glow slightly offset
    canvas.save();
    canvas.translate(0.5 * s, 0.5 * s);
    canvas.drawPath(dPath, glowPaint);
    canvas.drawPath(nPath, glowPaint);
    canvas.restore();

    // Draw white foreground paths
    canvas.drawPath(dPath, whitePaint);
    canvas.drawPath(nPath, whitePaint);
  }

  /// Pure vector glyph generator for the 11 characters in "DANGEROUSLY NERDY"
  void _drawVectorGlyph(Canvas canvas, String char, double w, double h, Paint paint) {
    final path = Path();

    switch (char) {
      case 'D':
        path.moveTo(0, 0);
        path.lineTo(w * 0.65, 0);
        path.lineTo(w, h * 0.35);
        path.lineTo(w, h * 0.65);
        path.lineTo(w * 0.65, h);
        path.lineTo(0, h);
        path.close();
        path.moveTo(w * 0.28, h * 0.25);
        path.lineTo(w * 0.55, h * 0.25);
        path.lineTo(w * 0.72, h * 0.4);
        path.lineTo(w * 0.72, h * 0.6);
        path.lineTo(w * 0.55, h * 0.75);
        path.lineTo(w * 0.28, h * 0.75);
        path.close();
        path.fillType = PathFillType.evenOdd;
        break;

      case 'A':
        path.moveTo(w * 0.5, 0);
        path.lineTo(w, h);
        path.lineTo(w * 0.72, h);
        path.lineTo(w * 0.58, h * 0.65);
        path.lineTo(w * 0.42, h * 0.65);
        path.lineTo(w * 0.28, h);
        path.lineTo(0, h);
        path.close();
        path.moveTo(w * 0.5, h * 0.22);
        path.lineTo(w * 0.62, h * 0.48);
        path.lineTo(w * 0.38, h * 0.48);
        path.close();
        path.fillType = PathFillType.evenOdd;
        break;

      case 'N':
        path.moveTo(0, 0);
        path.lineTo(w * 0.28, 0);
        path.lineTo(w * 0.72, h * 0.7);
        path.lineTo(w * 0.72, 0);
        path.lineTo(w, 0);
        path.lineTo(w, h);
        path.lineTo(w * 0.72, h);
        path.lineTo(w * 0.28, h * 0.3);
        path.lineTo(w * 0.28, h);
        path.lineTo(0, h);
        path.close();
        break;

      case 'G':
        path.moveTo(w, h * 0.25);
        path.lineTo(w * 0.75, 0);
        path.lineTo(w * 0.25, 0);
        path.lineTo(0, h * 0.25);
        path.lineTo(0, h * 0.75);
        path.lineTo(w * 0.25, h);
        path.lineTo(w * 0.8, h);
        path.lineTo(w, h * 0.8);
        path.lineTo(w, h * 0.45);
        path.lineTo(w * 0.45, h * 0.45);
        path.lineTo(w * 0.45, h * 0.68);
        path.lineTo(w * 0.75, h * 0.68);
        path.lineTo(w * 0.75, h * 0.78);
        path.lineTo(w * 0.28, h * 0.78);
        path.lineTo(w * 0.24, h * 0.72);
        path.lineTo(w * 0.24, h * 0.28);
        path.lineTo(w * 0.28, h * 0.22);
        path.lineTo(w * 0.72, h * 0.22);
        path.lineTo(w * 0.78, h * 0.28);
        path.lineTo(w, h * 0.25);
        path.close();
        break;

      case 'E':
        path.moveTo(0, 0);
        path.lineTo(w, 0);
        path.lineTo(w, h * 0.22);
        path.lineTo(w * 0.26, h * 0.22);
        path.lineTo(w * 0.26, h * 0.4);
        path.lineTo(w * 0.85, h * 0.4);
        path.lineTo(w * 0.85, h * 0.6);
        path.lineTo(w * 0.26, h * 0.6);
        path.lineTo(w * 0.26, h * 0.78);
        path.lineTo(w, h * 0.78);
        path.lineTo(w, h);
        path.lineTo(0, h);
        path.close();
        break;

      case 'R':
        path.moveTo(0, 0);
        path.lineTo(w * 0.75, 0);
        path.lineTo(w, h * 0.25);
        path.lineTo(w, h * 0.45);
        path.lineTo(w * 0.75, h * 0.6);
        path.lineTo(w, h);
        path.lineTo(w * 0.7, h);
        path.lineTo(w * 0.5, h * 0.62);
        path.lineTo(w * 0.26, h * 0.62);
        path.lineTo(w * 0.26, h);
        path.lineTo(0, h);
        path.close();
        path.moveTo(w * 0.26, h * 0.2);
        path.lineTo(w * 0.62, h * 0.2);
        path.lineTo(w * 0.74, h * 0.3);
        path.lineTo(w * 0.74, h * 0.4);
        path.lineTo(w * 0.62, h * 0.45);
        path.lineTo(w * 0.26, h * 0.45);
        path.close();
        path.fillType = PathFillType.evenOdd;
        break;

      case 'O':
        path.moveTo(w * 0.25, 0);
        path.lineTo(w * 0.75, 0);
        path.lineTo(w, h * 0.25);
        path.lineTo(w, h * 0.75);
        path.lineTo(w * 0.75, h);
        path.lineTo(w * 0.25, h);
        path.lineTo(0, h * 0.75);
        path.lineTo(0, h * 0.25);
        path.close();
        path.moveTo(w * 0.28, h * 0.22);
        path.lineTo(w * 0.72, h * 0.22);
        path.lineTo(w * 0.74, h * 0.3);
        path.lineTo(w * 0.74, h * 0.7);
        path.lineTo(w * 0.72, h * 0.78);
        path.lineTo(w * 0.28, h * 0.78);
        path.lineTo(w * 0.26, h * 0.7);
        path.lineTo(w * 0.26, h * 0.3);
        path.close();
        path.fillType = PathFillType.evenOdd;
        break;

      case 'U':
        path.moveTo(0, 0);
        path.lineTo(w * 0.26, 0);
        path.lineTo(w * 0.26, h * 0.72);
        path.lineTo(w * 0.35, h * 0.78);
        path.lineTo(w * 0.65, h * 0.78);
        path.lineTo(w * 0.74, h * 0.72);
        path.lineTo(w * 0.74, 0);
        path.lineTo(w, 0);
        path.lineTo(w, h * 0.75);
        path.lineTo(w * 0.75, h);
        path.lineTo(w * 0.25, h);
        path.lineTo(0, h * 0.75);
        path.close();
        break;

      case 'S':
        path.moveTo(w * 0.85, 0);
        path.lineTo(w * 0.15, 0);
        path.lineTo(0, h * 0.15);
        path.lineTo(0, h * 0.55);
        path.lineTo(w * 0.74, h * 0.55);
        path.lineTo(w * 0.74, h * 0.78);
        path.lineTo(0, h * 0.78);
        path.lineTo(0, h * 0.85);
        path.lineTo(w * 0.15, h);
        path.lineTo(w * 0.85, h);
        path.lineTo(w, h * 0.85);
        path.lineTo(w, h * 0.45);
        path.lineTo(w * 0.26, h * 0.45);
        path.lineTo(w * 0.26, h * 0.22);
        path.lineTo(w, h * 0.22);
        path.lineTo(w, h * 0.15);
        path.close();
        break;

      case 'L':
        path.moveTo(0, 0);
        path.lineTo(w * 0.26, 0);
        path.lineTo(w * 0.26, h * 0.78);
        path.lineTo(w, h * 0.78);
        path.lineTo(w, h);
        path.lineTo(0, h);
        path.close();
        break;

      case 'Y':
        path.moveTo(0, 0);
        path.lineTo(w * 0.28, 0);
        path.lineTo(w * 0.5, h * 0.42);
        path.lineTo(w * 0.72, 0);
        path.lineTo(w, 0);
        path.lineTo(w * 0.64, h * 0.55);
        path.lineTo(w * 0.64, h);
        path.lineTo(w * 0.36, h);
        path.lineTo(w * 0.36, h * 0.55);
        path.close();
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant D20TechPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.showRings != showRings ||
        oldDelegate.rotation != rotation;
  }
}

class _Facet {
  final List<Offset> points;
  final double lighting;
  final bool isCenter;

  const _Facet(this.points, this.lighting, this.isCenter);
}
