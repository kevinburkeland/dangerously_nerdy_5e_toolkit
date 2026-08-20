import 'dart:math';
import 'package:flutter/material.dart';
import 'glyph_tokens.dart';

/// Normalized 24x24 Vector Grid Geometry Builders for Glyph Frames & Tier Badging.
class GlyphGeometry {
  static const double baseGrid = 24.0;

  /// Creates the normalized Path in [0..size.width, 0..size.height] for a given container shape.
  static Path getContainerPath(GlyphFrameShape shape, Size size) {
    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final center = Offset(w / 2.0, h / 2.0);
    final scale = s / baseGrid;

    final path = Path();

    switch (shape) {
      case GlyphFrameShape.circle:
        // Abjuration: Circle Shield
        path.addOval(Rect.fromCircle(center: center, radius: 10.0 * scale));
        break;

      case GlyphFrameShape.hexagon:
        // Conjuration: Hexagonal Planar Gate
        final r = 10.0 * scale;
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60.0 - 30.0) * pi / 180.0;
          final pt =
              Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        break;

      case GlyphFrameShape.eye:
        // Divination: Horizontal Eye / Diamond Enclosure
        final rx = 10.5 * scale;
        final ry = 7.5 * scale;
        path.moveTo(center.dx - rx, center.dy);
        path.cubicTo(
            center.dx - rx * 0.5,
            center.dy - ry * 1.25,
            center.dx + rx * 0.5,
            center.dy - ry * 1.25,
            center.dx + rx,
            center.dy);
        path.cubicTo(
            center.dx + rx * 0.5,
            center.dy + ry * 1.25,
            center.dx - rx * 0.5,
            center.dy + ry * 1.25,
            center.dx - rx,
            center.dy);
        path.close();
        break;

      case GlyphFrameShape.softRhombus:
        // Enchantment: Soft Rhombus (Rounded Diamond)
        final r = 9.8 * scale;
        final cr = 2.2 * scale;
        path.moveTo(center.dx, center.dy - r);
        path.lineTo(center.dx + r - cr, center.dy - cr);
        path.quadraticBezierTo(
            center.dx + r, center.dy, center.dx + r - cr, center.dy + cr);
        path.lineTo(center.dx + cr, center.dy + r - cr);
        path.quadraticBezierTo(
            center.dx, center.dy + r, center.dx - cr, center.dy + r - cr);
        path.lineTo(center.dx - r + cr, center.dy + cr);
        path.quadraticBezierTo(
            center.dx - r, center.dy, center.dx - r + cr, center.dy - cr);
        path.lineTo(center.dx - cr, center.dy - r + cr);
        path.quadraticBezierTo(
            center.dx, center.dy - r, center.dx, center.dy - r);
        path.close();
        break;

      case GlyphFrameShape.diamond:
        // Evocation: Sharp Diamond
        final r = 10.2 * scale;
        path.moveTo(center.dx, center.dy - r);
        path.lineTo(center.dx + r, center.dy);
        path.lineTo(center.dx, center.dy + r);
        path.lineTo(center.dx - r, center.dy);
        path.close();
        break;

      case GlyphFrameShape.overlappingCircle:
        // Illusion: Overlapping Mirage Circles (Vesica Piscis Outer Silhouette)
        final r = 7.5 * scale;
        final d = 3.5 * scale;
        final leftPath = Path()
          ..addOval(Rect.fromCircle(center: center - Offset(d, 0), radius: r));
        final rightPath = Path()
          ..addOval(Rect.fromCircle(center: center + Offset(d, 0), radius: r));
        path.addPath(Path.combine(PathOperation.union, leftPath, rightPath),
            Offset.zero);
        break;

      case GlyphFrameShape.invertedTriangle:
        // Necromancy: Inverted Triangle (Point Down)
        final r = 10.2 * scale;
        path.moveTo(center.dx - r * 0.95, center.dy - r * 0.75);
        path.lineTo(center.dx + r * 0.95, center.dy - r * 0.75);
        path.lineTo(center.dx, center.dy + r);
        path.close();
        break;

      case GlyphFrameShape.upwardTriangle:
        // Transmutation: Upward Triangle (Point Up)
        final r = 10.2 * scale;
        path.moveTo(center.dx, center.dy - r);
        path.lineTo(center.dx + r * 0.95, center.dy + r * 0.75);
        path.lineTo(center.dx - r * 0.95, center.dy + r * 0.75);
        path.close();
        break;

      case GlyphFrameShape.octagon:
        // Aberration: Octagonal Eldritch Containment
        final r = 10.0 * scale;
        for (int i = 0; i < 8; i++) {
          final angle = (i * 45.0 - 22.5) * pi / 180.0;
          final pt =
              Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        break;

      case GlyphFrameShape.softShield:
        // Beast: Soft Rounded Shield
        final r = 9.8 * scale;
        path.moveTo(center.dx - r * 0.85, center.dy - r * 0.85);
        path.lineTo(center.dx + r * 0.85, center.dy - r * 0.85);
        path.lineTo(center.dx + r * 0.85, center.dy + r * 0.1);
        path.cubicTo(
          center.dx + r * 0.85,
          center.dy + r * 0.6,
          center.dx + r * 0.4,
          center.dy + r * 0.9,
          center.dx,
          center.dy + r,
        );
        path.cubicTo(
          center.dx - r * 0.4,
          center.dy + r * 0.9,
          center.dx - r * 0.85,
          center.dy + r * 0.6,
          center.dx - r * 0.85,
          center.dy + r * 0.1,
        );
        path.close();
        break;

      case GlyphFrameShape.crest:
        // Celestial: Winged Crest Shield
        final r = 10.0 * scale;
        path.moveTo(center.dx, center.dy - r);
        path.lineTo(center.dx + r * 0.95, center.dy - r * 0.5);
        path.lineTo(center.dx + r * 0.75, center.dy + r * 0.35);
        path.lineTo(center.dx, center.dy + r);
        path.lineTo(center.dx - r * 0.75, center.dy + r * 0.35);
        path.lineTo(center.dx - r * 0.95, center.dy - r * 0.5);
        path.close();
        break;

      case GlyphFrameShape.heavyHex:
        // Construct: Heavy Hex Shield
        final r = 10.0 * scale;
        for (int i = 0; i < 6; i++) {
          final angle = (i * 60.0) * pi / 180.0;
          final pt =
              Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        break;

      case GlyphFrameShape.sharpDiamondShield:
        // Dragon: Sharp Diamond Shield
        final r = 10.5 * scale;
        path.moveTo(center.dx, center.dy - r * 1.05);
        path.lineTo(center.dx + r * 0.9, center.dy - r * 0.2);
        path.lineTo(center.dx, center.dy + r);
        path.lineTo(center.dx - r * 0.9, center.dy - r * 0.2);
        path.close();
        break;

      case GlyphFrameShape.rhombus:
        // Elemental: Rhombus
        final r = 9.8 * scale;
        path.moveTo(center.dx + r * 0.3, center.dy - r);
        path.lineTo(center.dx + r, center.dy + r * 0.3);
        path.lineTo(center.dx - r * 0.3, center.dy + r);
        path.lineTo(center.dx - r, center.dy - r * 0.3);
        path.close();
        break;

      case GlyphFrameShape.filigreeOval:
        // Fey: Sylvan Filigree Oval
        path.addOval(Rect.fromCenter(
            center: center, width: 16.5 * scale, height: 20.5 * scale));
        break;

      case GlyphFrameShape.pointedShield:
        // Fiend: Inverted Pointed Shield
        final r = 10.0 * scale;
        path.moveTo(center.dx - r * 0.9, center.dy - r * 0.8);
        path.lineTo(center.dx + r * 0.9, center.dy - r * 0.8);
        path.lineTo(center.dx + r * 0.75, center.dy + r * 0.2);
        path.lineTo(center.dx, center.dy + r * 1.05);
        path.lineTo(center.dx - r * 0.75, center.dy + r * 0.2);
        path.close();
        break;

      case GlyphFrameShape.heavySquare:
        // Giant: Heavy Square with Beveled Corners
        final r = 9.0 * scale;
        path.addRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: r * 2.0, height: r * 2.0),
            Radius.circular(2.2 * scale)));
        break;

      case GlyphFrameShape.heaterShield:
        // Humanoid: Classic Heater Shield
        final r = 9.8 * scale;
        path.moveTo(center.dx - r * 0.85, center.dy - r * 0.95);
        path.lineTo(center.dx + r * 0.85, center.dy - r * 0.95);
        path.lineTo(center.dx + r * 0.85, center.dy);
        path.cubicTo(
          center.dx + r * 0.85,
          center.dy + r * 0.65,
          center.dx + r * 0.4,
          center.dy + r * 0.95,
          center.dx,
          center.dy + r * 1.05,
        );
        path.cubicTo(
          center.dx - r * 0.4,
          center.dy + r * 0.95,
          center.dx - r * 0.85,
          center.dy + r * 0.65,
          center.dx - r * 0.85,
          center.dy,
        );
        path.close();
        break;

      case GlyphFrameShape.jaggedCrest:
        // Monstrosity: Jagged Spiky Crest
        final r = 10.0 * scale;
        path.moveTo(center.dx, center.dy - r);
        path.lineTo(center.dx + r * 0.6, center.dy - r * 0.7);
        path.lineTo(center.dx + r * 0.95, center.dy - r * 0.2);
        path.lineTo(center.dx + r * 0.65, center.dy + r * 0.4);
        path.lineTo(center.dx, center.dy + r);
        path.lineTo(center.dx - r * 0.65, center.dy + r * 0.4);
        path.lineTo(center.dx - r * 0.95, center.dy - r * 0.2);
        path.lineTo(center.dx - r * 0.6, center.dy - r * 0.7);
        path.close();
        break;

      case GlyphFrameShape.blob:
        // Ooze: Amorphous Liquid Blob
        final r = 10.0 * scale;
        path.moveTo(center.dx, center.dy - r * 0.9);
        path.cubicTo(center.dx + r * 0.8, center.dy - r * 0.85, center.dx + r,
            center.dy - r * 0.2, center.dx + r * 0.9, center.dy + r * 0.3);
        path.cubicTo(
            center.dx + r * 0.8,
            center.dy + r * 0.8,
            center.dx + r * 0.3,
            center.dy + r,
            center.dx - r * 0.1,
            center.dy + r * 0.95);
        path.cubicTo(
            center.dx - r * 0.6,
            center.dy + r * 0.9,
            center.dx - r * 0.95,
            center.dy + r * 0.5,
            center.dx - r * 0.9,
            center.dy);
        path.cubicTo(
            center.dx - r * 0.85,
            center.dy - r * 0.5,
            center.dx - r * 0.5,
            center.dy - r * 0.95,
            center.dx,
            center.dy - r * 0.9);
        path.close();
        break;

      case GlyphFrameShape.teardrop:
        // Plant: Leaf Teardrop
        final r = 10.0 * scale;
        path.moveTo(center.dx, center.dy - r);
        path.cubicTo(
          center.dx + r * 0.95,
          center.dy - r * 0.1,
          center.dx + r * 0.85,
          center.dy + r * 0.85,
          center.dx,
          center.dy + r * 0.95,
        );
        path.cubicTo(
          center.dx - r * 0.85,
          center.dy + r * 0.85,
          center.dx - r * 0.95,
          center.dy - r * 0.1,
          center.dx,
          center.dy - r,
        );
        path.close();
        break;

      case GlyphFrameShape.tombstone:
        // Undead: Tombstone Arch
        final r = 9.8 * scale;
        path.moveTo(center.dx - r * 0.85, center.dy + r * 0.95);
        path.lineTo(center.dx - r * 0.85, center.dy - r * 0.2);
        path.arcToPoint(
          Offset(center.dx + r * 0.85, center.dy - r * 0.2),
          radius: Radius.circular(r * 0.85),
        );
        path.lineTo(center.dx + r * 0.85, center.dy + r * 0.95);
        path.close();
        break;
    }

    return path;
  }

  /// Draws tier decorations (notches, circuit nodes, scanlines, corner studs, double borders, golden filigree crowns).
  static void drawTierDecorations({
    required Canvas canvas,
    required Size size,
    required int tierLevel, // Spell Level (0-9) or Monster CR Tier (1-4)
    required GlyphFrameShape shape,
    required Color primaryColor,
    required bool isDarkMode,
    double pulseTurns = 0.0,
    bool animatePulse = false,
  }) {
    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final center = Offset(w / 2.0, h / 2.0);
    final scale = s / baseGrid;
    final pulse =
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 2.2)) : 0.0;

    // Tier 2 (Adept / Levels 3-5 / CR 5-10): instrument-panel brace, not a cluster. The visual reads as a refined, advanced glyph.
    if (tierLevel == 2) {
      final bracePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.72 + pulse * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * scale
        ..strokeCap = StrokeCap.round;

      final nodePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.82 + pulse * 0.18)
        ..style = PaintingStyle.fill;

      final barY = center.dy +
          9.0 * scale +
          sin(pulseTurns * 2.0 * pi * 2.0) * 0.6 * scale;
      final barLeft = center.dx - 6.0 * scale;
      final barRight = center.dx + 6.0 * scale;

      canvas.drawLine(
          Offset(barLeft, barY), Offset(barRight, barY), bracePaint);
      canvas.drawLine(Offset(center.dx - 2.3 * scale, center.dy + 6.4 * scale),
          Offset(center.dx - 2.3 * scale, barY), bracePaint);
      canvas.drawLine(Offset(center.dx + 2.3 * scale, center.dy + 6.4 * scale),
          Offset(center.dx + 2.3 * scale, barY), bracePaint);

      final nodeOffset = 4.4 * scale;
      final nodeYs = [
        center.dy + 5.5 * scale,
        barY,
      ];
      for (final ny in nodeYs) {
        canvas.drawCircle(Offset(center.dx - nodeOffset, ny),
            (0.62 + pulse * 0.18) * scale, nodePaint);
        canvas.drawCircle(Offset(center.dx + nodeOffset, ny),
            (0.62 + pulse * 0.18) * scale, nodePaint);
      }

      final trimPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.34 + pulse * 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * scale
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center - Offset(6.5 * scale, 0),
          center - Offset(4.1 * scale, 2.5 * scale), trimPaint);
      canvas.drawLine(center + Offset(6.5 * scale, 0),
          center + Offset(4.1 * scale, 2.5 * scale), trimPaint);
    }

    // Tier 3 & Tier 4: progression ladder. Each rung adds a higher level of structural reinforcement.
    if (tierLevel >= 3) {
      final activePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.72 + pulse * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * scale
        ..strokeCap = StrokeCap.round;

      final nodePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.82 + pulse * 0.18)
        ..style = PaintingStyle.fill;

      final verticalX = center.dx;
      final rungY = center.dy + (tierLevel == 4 ? 7.8 : 8.5) * scale;
      final rungSpread = (tierLevel == 4 ? 6.5 : 5.6) * scale;
      final rungCount = tierLevel == 4 ? 3 : 2;

      for (int i = 0; i < rungCount; i++) {
        final y = rungY - i * (2.6 * scale);
        canvas.drawLine(
          Offset(verticalX - rungSpread, y),
          Offset(verticalX + rungSpread, y),
          activePaint,
        );
        canvas.drawCircle(Offset(verticalX - rungSpread, y),
            (0.55 + pulse * 0.22) * scale, nodePaint);
        canvas.drawCircle(Offset(verticalX + rungSpread, y),
            (0.55 + pulse * 0.22) * scale, nodePaint);
      }

      canvas.drawLine(
        Offset(verticalX, center.dy - 8.8 * scale),
        Offset(verticalX, center.dy + 9.4 * scale),
        activePaint,
      );
    }

    // Tier 4 ONLY: extend the ladder with a crown-like cap, still reading as the same progression system.
    if (tierLevel == 4) {
      const goldColor = Color(0xFFCA8A04);
      final crownPaint = Paint()
        ..color = goldColor.withValues(alpha: 0.72 + pulse * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale
        ..strokeCap = StrokeCap.round;

      final crownY = center.dy - 11.2 * scale;
      final archPath = Path();
      archPath.moveTo(center.dx - 6.0 * scale, crownY);
      archPath.quadraticBezierTo(
          center.dx, center.dy - 13.6 * scale, center.dx + 6.0 * scale, crownY);
      canvas.drawPath(archPath, crownPaint);

      final diamondFill = Paint()
        ..color = goldColor.withValues(alpha: 0.8 + pulse * 0.2)
        ..style = PaintingStyle.fill;
      final crownDiamond = Path();
      crownDiamond.moveTo(center.dx, center.dy - 14.0 * scale);
      crownDiamond.lineTo(center.dx + 1.6 * scale, center.dy - 12.2 * scale);
      crownDiamond.lineTo(center.dx, center.dy - 10.4 * scale);
      crownDiamond.lineTo(center.dx - 1.6 * scale, center.dy - 12.2 * scale);
      crownDiamond.close();
      canvas.drawPath(crownDiamond, diamondFill);
    }
  }

  /// Draws the secondary damage type accent indicator dot in the upper-right quadrant.
  static void drawDamageAccent({
    required Canvas canvas,
    required Size size,
    required DamageAccent accent,
  }) {
    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final scale = s / baseGrid;
    final dotCenter = Offset(w - 3.2 * scale, 3.2 * scale);

    // Glowing halo
    final glowPaint = Paint()
      ..color = accent.color.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * scale);
    canvas.drawCircle(dotCenter, 2.4 * scale, glowPaint);

    // Core accent dot
    final dotPaint = Paint()
      ..color = accent.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotCenter, 1.6 * scale, dotPaint);

    // Outer white rim for contrast
    final rimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * scale;
    canvas.drawCircle(dotCenter, 1.6 * scale, rimPaint);
  }

  /// Draws multiple concentric geometric action/attack trait rings around the glyph symbol.
  /// Each ring has a distinct geometric shape (melee diamond, ranged crosshairs, recharge hex, etc.)
  /// and is illuminated with the specific damage type's neon color.
  static void drawActionTraitRings({
    required Canvas canvas,
    required Size size,
    required List<ActionTraitRing> rings,
    required Color defaultColor,
    required bool isDarkMode,
    double rotationTurns = 0.0,
    bool animateRotation = false,
    int tierLevel = 1,
  }) {
    if (rings.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final center = Offset(w / 2.0, h / 2.0);
    final scale = s / baseGrid;

    // Determine concentric radii dynamically based on ring count (supports arbitrary number of rings)
    final count = rings.length;
    final radii = <double>[];
    if (count == 1) {
      radii.add(8.5 * scale);
    } else if (count == 2) {
      radii.addAll([9.4 * scale, 7.0 * scale]);
    } else {
      final maxR = 9.6 * scale;
      final minR = max(4.4 * scale, 9.6 * scale - (count - 1) * (1.5 * scale));
      final step = (maxR - minR) / (count - 1);
      for (int i = 0; i < count; i++) {
        radii.add(maxR - (i * step));
      }
    }

    final tierPulse = switch (tierLevel) {
      1 => 0.18,
      2 => 0.38,
      3 => 0.66,
      _ => 1.0,
    };

    for (int idx = 0; idx < rings.length; idx++) {
      final ring = rings[idx];
      final r = radii[idx];
      final normalizedTurns = rotationTurns % 1.0;
      final colorCyclesPerLoop = switch (idx % 4) {
        0 => 1,
        1 => 2,
        2 => 3,
        _ => 2,
      };
      final colorPhase = animateRotation
          ? (normalizedTurns * colorCyclesPerLoop + idx * 0.17)
          : 0.0;
      final ringColor = ring.getAnimatedColor(
        defaultColor,
        isDarkMode: isDarkMode,
        phase: colorPhase,
      );
      final direction = idx.isEven ? 1.0 : -1.0;
      // Use whole-number cycles per controller loop so orientation matches at wrap.
      final speedFactor = switch (tierLevel) {
        1 => 1.0,
        2 => (idx + 1).toDouble(),
        3 => (idx + 2).toDouble(),
        _ => (idx + 2).toDouble(),
      };
      final breathFrequency = switch (tierLevel) {
        1 => (idx % 3) + 1,
        2 => (idx % 3) + 2,
        3 => (idx % 3) + 3,
        _ => (idx % 3) + 4,
      };
      final breathPhase = idx * 1.37 + tierPulse * 2.2;
      final breathSin = animateRotation
          ? ((sin((normalizedTurns * 2.0 * pi * breathFrequency) +
                      breathPhase) *
                  (0.72 + tierPulse * 0.55)) +
              (sin((normalizedTurns * 2.0 * pi * (breathFrequency + 1)) +
                      (breathPhase * 0.63)) *
                  (0.28 + tierPulse * 0.30)))
          : 0.0;
      final breathWave = 0.5 + 0.5 * breathSin;
      final breathAmplitude =
          scale * (0.95 + ((idx % 3) * 0.22) + (tierPulse * 1.7));
      final breathingRadius = r + (breathSin * breathAmplitude);
      final rotationAngle = animateRotation
          ? (rotationTurns * 2.0 * pi * direction * speedFactor)
          : 0.0;

      // 1. Dark contrast underlay outline to prevent visual clutter and separate adjacent rings
      final underlayPaint = Paint()
        ..color = isDarkMode
            ? const Color(0xFF030712).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // 2. Razor-sharp precision wireframe stroke
      final strokePaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.95 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // 3. Ultra-fine secondary trace lines
      final finePaint = Paint()
        ..color = ringColor.withValues(alpha: isDarkMode ? 0.75 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.55 * scale;

      // 4. Compact terminal nodes
      final nodeFill = Paint()
        ..color = ringColor
        ..style = PaintingStyle.fill;

      // 5. Tight, controlled holographic laser glow (prevents diffuse blurring)
      final glowAlphaBase = ring.hasElementalDamageAccent
          ? (isDarkMode ? 0.35 : 0.22)
          : (isDarkMode ? 0.18 : 0.10);
      final glowAlpha =
          glowAlphaBase * (0.85 + breathWave * 0.40 + tierPulse * 0.70);

      final glowPaint = Paint()
        ..color = ringColor.withValues(alpha: glowAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.0 * scale);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotationAngle);
      canvas.translate(-center.dx, -center.dy);

      // Render: Underlay Outline -> Glow Halo -> Sharp Wireframe & Nodes
      _drawRingPath(canvas, center, breathingRadius, ring.ringType, scale,
          underlayPaint, finePaint, nodeFill,
          isGlow: true);
      _drawRingPath(canvas, center, breathingRadius, ring.ringType, scale,
          glowPaint, finePaint, nodeFill,
          isGlow: true);
      _drawRingPath(canvas, center, breathingRadius, ring.ringType, scale,
          strokePaint, finePaint, nodeFill,
          isGlow: false);

      canvas.restore();
    }
  }

  static void _drawRingPath(
    Canvas canvas,
    Offset center,
    double r,
    ActionRingType type,
    double scale,
    Paint mainPaint,
    Paint finePaint,
    Paint nodeFill, {
    required bool isGlow,
  }) {
    switch (type) {
      case ActionRingType.melee:
        // Faceted Octagonal / Diamond Ring with Blade Notch Ticks
        final oct = Path();
        const numPts = 8;
        for (int i = 0; i < numPts; i++) {
          final a = (i * 45.0) * pi / 180.0;
          final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
          if (i == 0) {
            oct.moveTo(pt.dx, pt.dy);
          } else {
            oct.lineTo(pt.dx, pt.dy);
          }
        }
        oct.close();
        canvas.drawPath(oct, mainPaint);

        if (!isGlow) {
          // 4 Cardinal blade notch ticks
          for (int i = 0; i < 4; i++) {
            final a = (i * 90.0) * pi / 180.0;
            final p1 = Offset(center.dx + (r - 1.2 * scale) * cos(a),
                center.dy + (r - 1.2 * scale) * sin(a));
            final p2 = Offset(center.dx + (r + 1.2 * scale) * cos(a),
                center.dy + (r + 1.2 * scale) * sin(a));
            canvas.drawLine(p1, p2, mainPaint);
            canvas.drawCircle(p2, 0.9 * scale, nodeFill);
          }
        }
        break;

      case ActionRingType.ranged:
        // Circular Crosshair Reticle Ring with 4-Axis Targeting Ticks
        canvas.drawCircle(center, r, mainPaint);

        if (!isGlow) {
          // 4 Precision crosshair ticks extending outward
          for (int i = 0; i < 4; i++) {
            final a = (i * 90.0 + 45.0) * pi / 180.0;
            final p1 = Offset(center.dx + (r - 1.0 * scale) * cos(a),
                center.dy + (r - 1.0 * scale) * sin(a));
            final p2 = Offset(center.dx + (r + 2.0 * scale) * cos(a),
                center.dy + (r + 2.0 * scale) * sin(a));
            canvas.drawLine(p1, p2, finePaint);
            canvas.drawCircle(p2, 0.8 * scale, nodeFill);
          }
        }
        break;

      case ActionRingType.recharge:
        // Segmented Hexagonal Pulse Ring with Discharge Gaps
        const segs = 6;
        for (int i = 0; i < segs; i++) {
          final aStart = (i * 60.0 + 8.0) * pi / 180.0;
          final aEnd = (i * 60.0 + 52.0) * pi / 180.0;
          final seg = Path();
          seg.moveTo(center.dx + r * cos(aStart), center.dy + r * sin(aStart));
          seg.lineTo(center.dx + r * cos(aEnd), center.dy + r * sin(aEnd));
          canvas.drawPath(seg, mainPaint);

          if (!isGlow) {
            // Energy discharge node at middle of segment
            final aMid = (i * 60.0 + 30.0) * pi / 180.0;
            final pMid =
                Offset(center.dx + r * cos(aMid), center.dy + r * sin(aMid));
            canvas.drawCircle(pMid, 0.9 * scale, nodeFill);
          }
        }
        break;

      case ActionRingType.reaction:
        // Shielded Square Ring with Corner Deflection Brackets
        final sq = Path();
        for (int i = 0; i < 4; i++) {
          final a = (i * 90.0 + 45.0) * pi / 180.0;
          final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
          if (i == 0) {
            sq.moveTo(pt.dx, pt.dy);
          } else {
            sq.lineTo(pt.dx, pt.dy);
          }
        }
        sq.close();
        canvas.drawPath(sq, mainPaint);

        if (!isGlow) {
          for (int i = 0; i < 4; i++) {
            final a = (i * 90.0 + 45.0) * pi / 180.0;
            final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
            canvas.drawCircle(pt, 1.0 * scale, nodeFill);
          }
        }
        break;

      case ActionRingType.control:
        // Tri-node restraint lattice ring for control and disable effects.
        canvas.drawCircle(center, r, mainPaint);
        if (!isGlow) {
          for (int i = 0; i < 3; i++) {
            final a = (i * 120.0 - 90.0) * pi / 180.0;
            final p = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
            canvas.drawCircle(p, 1.0 * scale, nodeFill);
          }

          final triangle = Path();
          for (int i = 0; i < 3; i++) {
            final a = (i * 120.0 - 90.0) * pi / 180.0;
            final p = Offset(center.dx + (r - 1.0 * scale) * cos(a),
                center.dy + (r - 1.0 * scale) * sin(a));
            if (i == 0) {
              triangle.moveTo(p.dx, p.dy);
            } else {
              triangle.lineTo(p.dx, p.dy);
            }
          }
          triangle.close();
          canvas.drawPath(triangle, finePaint);
        }
        break;

      case ActionRingType.sustain:
        // Harmonic cradle ring for healing, barriers, and regeneration.
        final outer =
            Rect.fromCenter(center: center, width: r * 2.0, height: r * 1.45);
        final inner =
            Rect.fromCenter(center: center, width: r * 1.4, height: r * 2.0);
        canvas.drawOval(outer, mainPaint);
        canvas.drawOval(inner, finePaint);
        if (!isGlow) {
          final nodeA = Offset(center.dx - r * 0.55, center.dy + r * 0.35);
          final nodeB = Offset(center.dx + r * 0.55, center.dy + r * 0.35);
          final apex = Offset(center.dx, center.dy - r * 0.55);
          canvas.drawLine(nodeA, apex, finePaint);
          canvas.drawLine(apex, nodeB, finePaint);
          canvas.drawCircle(nodeA, 0.9 * scale, nodeFill);
          canvas.drawCircle(nodeB, 0.9 * scale, nodeFill);
          canvas.drawCircle(apex, 0.9 * scale, nodeFill);
        }
        break;

      case ActionRingType.legendary:
        // Spiked Starburst Crown Ring with Radiating Apex Rays
        final star = Path();
        const pts = 8;
        for (int i = 0; i < pts * 2; i++) {
          final rad = (i % 2 == 0) ? (r + 1.2 * scale) : (r - 0.8 * scale);
          final a = (i * pi / pts) - pi / 2.0;
          final pt = Offset(center.dx + rad * cos(a), center.dy + rad * sin(a));
          if (i == 0) {
            star.moveTo(pt.dx, pt.dy);
          } else {
            star.lineTo(pt.dx, pt.dy);
          }
        }
        star.close();
        canvas.drawPath(star, mainPaint);
        break;

      case ActionRingType.concentration:
        // Dual-Harmonic Orbital Wireframe Loop Ring
        canvas.drawCircle(center, r, mainPaint);
        canvas.drawCircle(center, r - 1.2 * scale, finePaint);
        if (!isGlow) {
          for (int i = 0; i < 6; i++) {
            final a = (i * 60.0) * pi / 180.0;
            final p1 = Offset(center.dx + (r - 1.2 * scale) * cos(a),
                center.dy + (r - 1.2 * scale) * sin(a));
            final p2 = Offset(
                center.dx + r * cos(a + 0.2), center.dy + r * sin(a + 0.2));
            canvas.drawLine(p1, p2, finePaint);
            canvas.drawCircle(p2, 0.7 * scale, nodeFill);
          }
        }
        break;

      case ActionRingType.attunement:
        // Sacred Tether Ring with Intersecting Attunement Knot Nodes
        canvas.drawCircle(center, r, mainPaint);
        if (!isGlow) {
          // 4 Cardinal tether links with orbital nexus loops
          for (int i = 0; i < 4; i++) {
            final a = (i * 90.0) * pi / 180.0;
            final pOuter = Offset(center.dx + (r + 1.2 * scale) * cos(a),
                center.dy + (r + 1.2 * scale) * sin(a));
            final pInner = Offset(center.dx + (r - 1.2 * scale) * cos(a),
                center.dy + (r - 1.2 * scale) * sin(a));
            canvas.drawLine(pInner, pOuter, finePaint);
            canvas.drawCircle(pOuter, 0.85 * scale, nodeFill);
          }
          final diamond = Path();
          for (int i = 0; i < 4; i++) {
            final a = (i * 90.0 + 45.0) * pi / 180.0;
            final pt = Offset(center.dx + (r - 0.8 * scale) * cos(a),
                center.dy + (r - 0.8 * scale) * sin(a));
            if (i == 0) {
              diamond.moveTo(pt.dx, pt.dy);
            } else {
              diamond.lineTo(pt.dx, pt.dy);
            }
          }
          diamond.close();
          canvas.drawPath(diamond, finePaint);
        }
        break;
    }
  }

  /// Draws the monster action / trait modifier sub-badge in the lower-right quadrant (legacy).
  static void drawActionBadge({
    required Canvas canvas,
    required Size size,
    required ActionBadge badge,
  }) {
    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final scale = s / baseGrid;
    final badgeCenter = Offset(w - 4.0 * scale, h - 4.0 * scale);
    final badgeRadius = 3.6 * scale;

    final bgPaint = Paint()
      ..color = badge.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, bgPaint);

    final rimPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75 * scale;
    canvas.drawCircle(badgeCenter, badgeRadius, rimPaint);

    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85 * scale
      ..strokeCap = StrokeCap.round;

    switch (badge) {
      case ActionBadge.melee:
        canvas.drawLine(badgeCenter - Offset(1.6 * scale, 1.6 * scale),
            badgeCenter + Offset(1.6 * scale, 1.6 * scale), iconPaint);
        canvas.drawLine(badgeCenter - Offset(-1.6 * scale, 1.6 * scale),
            badgeCenter + Offset(-1.6 * scale, 1.6 * scale), iconPaint);
        break;
      case ActionBadge.ranged:
        final bow = Path()
          ..arcTo(Rect.fromCircle(center: badgeCenter, radius: 1.8 * scale),
              -pi / 2, pi, false);
        canvas.drawPath(bow, iconPaint);
        canvas.drawLine(badgeCenter - Offset(1.8 * scale, 0),
            badgeCenter + Offset(1.8 * scale, 0), iconPaint);
        break;
      case ActionBadge.recharge:
        final bolt = Path()
          ..moveTo(badgeCenter.dx, badgeCenter.dy - 1.8 * scale)
          ..lineTo(badgeCenter.dx - 1.0 * scale, badgeCenter.dy)
          ..lineTo(badgeCenter.dx + 0.4 * scale, badgeCenter.dy)
          ..lineTo(badgeCenter.dx - 0.2 * scale, badgeCenter.dy + 1.8 * scale)
          ..lineTo(badgeCenter.dx + 1.2 * scale, badgeCenter.dy - 0.2 * scale)
          ..lineTo(badgeCenter.dx - 0.2 * scale, badgeCenter.dy - 0.2 * scale)
          ..close();
        canvas.drawPath(
            bolt,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill);
        break;
      case ActionBadge.legendary:
        final crown = Path()
          ..moveTo(badgeCenter.dx - 1.8 * scale, badgeCenter.dy + 1.2 * scale)
          ..lineTo(badgeCenter.dx - 1.8 * scale, badgeCenter.dy - 1.0 * scale)
          ..lineTo(badgeCenter.dx - 0.8 * scale, badgeCenter.dy)
          ..lineTo(badgeCenter.dx, badgeCenter.dy - 1.5 * scale)
          ..lineTo(badgeCenter.dx + 0.8 * scale, badgeCenter.dy)
          ..lineTo(badgeCenter.dx + 1.8 * scale, badgeCenter.dy - 1.0 * scale)
          ..lineTo(badgeCenter.dx + 1.8 * scale, badgeCenter.dy + 1.2 * scale)
          ..close();
        canvas.drawPath(
            crown,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill);
        break;
      case ActionBadge.lair:
        canvas.drawRect(
            Rect.fromCenter(
                center: badgeCenter, width: 2.4 * scale, height: 2.4 * scale),
            iconPaint);
        canvas.drawCircle(
            badgeCenter,
            0.5 * scale,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill);
        break;
    }
  }
}
