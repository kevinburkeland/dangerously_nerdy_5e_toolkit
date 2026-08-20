import 'dart:math';
import 'package:flutter/material.dart';
import 'glyph_tokens.dart';

/// Pure Wireframe Techno-Rune Vector Engine.
/// All motifs are abstract magical-circuit runes, schematic lattices, and sacred geometry.
/// 100% procedurally drawn in Flutter CustomPainter with zero SVG or image assets.
class GlyphMotifs {
  static const double baseGrid = 24.0;

  // ---------------------------------------------------------------------------
  // 8 ARCANE SPELL SCHOOL TECHNO-RUNES
  // ---------------------------------------------------------------------------

  static void drawSchoolMotif({
    required Canvas canvas,
    required Size size,
    required SpellSchool school,
    required Color color,
    required bool isDarkMode,
    double pulseTurns = 0.0,
    bool animatePulse = false,
  }) {
    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final center = Offset(w / 2.0, h / 2.0);
    final scale = s / baseGrid;
    final pulseWave =
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 2.2)) : 0.0;
    final pulseScale = animatePulse ? (1.0 + 0.045 * pulseWave) : 1.0;
    final primaryAlpha = animatePulse ? (0.88 + 0.12 * pulseWave) : 1.0;
    final fineBaseAlpha = isDarkMode ? 0.70 : 0.55;
    final fineAlpha =
        animatePulse ? (fineBaseAlpha + 0.20 * pulseWave) : fineBaseAlpha;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulseScale, pulseScale);
    canvas.translate(-center.dx, -center.dy);

    final primaryLine = Paint()
      ..color = color.withValues(alpha: primaryAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fineLine = Paint()
      ..color = color.withValues(alpha: fineAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85 * scale
      ..strokeCap = StrokeCap.round;

    final nodeFill = Paint()
      ..color = color.withValues(alpha: primaryAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    final nodeHollow = Paint()
      ..color = isDarkMode ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.fill;

    switch (school) {
      case SpellSchool.abjuration:
        // WARDING AEGIS CIRCUIT-RUNE
        // Outer nested warding diamond and concentric barrier ring
        canvas.drawCircle(center, 5.8 * scale, fineLine);

        final diamond = Path();
        diamond.moveTo(center.dx, center.dy - 6.2 * scale);
        diamond.lineTo(center.dx + 6.2 * scale, center.dy);
        diamond.lineTo(center.dx, center.dy + 6.2 * scale);
        diamond.lineTo(center.dx - 6.2 * scale, center.dy);
        diamond.close();
        canvas.drawPath(diamond, primaryLine);

        // Cardinal barrier lock bars
        canvas.drawLine(center - Offset(0, 7.0 * scale),
            center + Offset(0, 7.0 * scale), primaryLine);
        canvas.drawLine(center - Offset(7.0 * scale, 0),
            center + Offset(7.0 * scale, 0), primaryLine);

        // Diagonal circuit traces
        canvas.drawLine(center - Offset(3.5 * scale, 3.5 * scale),
            center + Offset(3.5 * scale, 3.5 * scale), fineLine);
        canvas.drawLine(center - Offset(-3.5 * scale, 3.5 * scale),
            center + Offset(-3.5 * scale, 3.5 * scale), fineLine);

        // Terminal solder nodes
        final nodes = [
          center - Offset(0, 6.2 * scale),
          center + Offset(0, 6.2 * scale),
          center - Offset(6.2 * scale, 0),
          center + Offset(6.2 * scale, 0),
        ];
        for (final pt in nodes) {
          canvas.drawCircle(pt, 1.1 * scale, nodeFill);
        }
        canvas.drawCircle(center, 1.6 * scale, nodeHollow);
        canvas.drawCircle(center, 1.6 * scale, primaryLine);
        canvas.drawCircle(center, 0.7 * scale, nodeFill);
        break;

      case SpellSchool.conjuration:
        // PLANAR GATE / SUMMONING VECTOR MATRIX
        // Concentric counter-rotating summoning hexagrams
        final rOuter = 6.2 * scale;
        final hex1 = Path();
        final hex2 = Path();
        for (int i = 0; i < 6; i++) {
          final a1 = (i * 60.0) * pi / 180.0;
          final a2 = (i * 60.0 + 30.0) * pi / 180.0;
          final p1 = Offset(
              center.dx + rOuter * cos(a1), center.dy + rOuter * sin(a1));
          final p2 = Offset(center.dx + (rOuter * 0.65) * cos(a2),
              center.dy + (rOuter * 0.65) * sin(a2));
          if (i == 0) {
            hex1.moveTo(p1.dx, p1.dy);
            hex2.moveTo(p2.dx, p2.dy);
          } else {
            hex1.lineTo(p1.dx, p1.dy);
            hex2.lineTo(p2.dx, p2.dy);
          }
          // Dimensional vortex vector lines connecting rings
          canvas.drawLine(p1, p2, fineLine);
        }
        hex1.close();
        hex2.close();
        canvas.drawPath(hex1, primaryLine);
        canvas.drawPath(hex2, fineLine);

        // Central portal core node
        canvas.drawCircle(center, 1.8 * scale, nodeHollow);
        canvas.drawCircle(center, 1.8 * scale, primaryLine);
        canvas.drawCircle(center, 0.8 * scale, nodeFill);
        break;

      case SpellSchool.divination:
        // OCULAR RETICLE / ALL-SEEING RADIAL SCANNER
        // Concentric focal coordinate arcs
        canvas.drawCircle(center, 6.2 * scale, fineLine);
        canvas.drawCircle(center, 3.2 * scale, primaryLine);

        // Ocular rhombus vector envelope
        final eyePath = Path();
        eyePath.moveTo(center.dx - 7.5 * scale, center.dy);
        eyePath.quadraticBezierTo(center.dx, center.dy - 4.5 * scale,
            center.dx + 7.5 * scale, center.dy);
        eyePath.quadraticBezierTo(center.dx, center.dy + 4.5 * scale,
            center.dx - 7.5 * scale, center.dy);
        canvas.drawPath(eyePath, primaryLine);

        // Crosshair reticle ticks
        canvas.drawLine(center - Offset(8.0 * scale, 0),
            center - Offset(4.0 * scale, 0), fineLine);
        canvas.drawLine(center + Offset(4.0 * scale, 0),
            center + Offset(8.0 * scale, 0), fineLine);
        canvas.drawLine(center - Offset(0, 7.5 * scale),
            center - Offset(0, 4.0 * scale), fineLine);
        canvas.drawLine(center + Offset(0, 4.0 * scale),
            center + Offset(0, 7.5 * scale), fineLine);

        // Cardinal sensor nodes
        canvas.drawCircle(
            center - Offset(7.5 * scale, 0), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(7.5 * scale, 0), 1.0 * scale, nodeFill);
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case SpellSchool.enchantment:
        // HARMONIC RESONANCE & CROWN FREQUENCY RUNE
        // Interlaced sine wave harmonic rings & crown telemetry nodes
        final r = 6.0 * scale;
        canvas.drawCircle(center, r, fineLine);

        // 3-Point crowned neural antenna vectors
        final crownPath = Path();
        crownPath.moveTo(center.dx - 5.5 * scale, center.dy + 4.0 * scale);
        crownPath.lineTo(center.dx - 5.5 * scale, center.dy - 3.5 * scale);
        crownPath.lineTo(center.dx - 2.5 * scale, center.dy);
        crownPath.lineTo(center.dx, center.dy - 6.5 * scale);
        crownPath.lineTo(center.dx + 2.5 * scale, center.dy);
        crownPath.lineTo(center.dx + 5.5 * scale, center.dy - 3.5 * scale);
        crownPath.lineTo(center.dx + 5.5 * scale, center.dy + 4.0 * scale);
        canvas.drawPath(crownPath, primaryLine);

        // Horizontal frequency modulation bars
        canvas.drawLine(center - Offset(4.5 * scale, -2.0 * scale),
            center + Offset(4.5 * scale, 2.0 * scale), fineLine);
        canvas.drawLine(center - Offset(3.5 * scale, -4.0 * scale),
            center + Offset(3.5 * scale, 4.0 * scale), fineLine);

        // Neural emitter nodes
        canvas.drawCircle(
            center - Offset(5.5 * scale, 3.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(0, 6.5 * scale), 1.3 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(5.5 * scale, -3.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(0, 1.5 * scale), 1.0 * scale, nodeFill);
        break;

      case SpellSchool.evocation:
        // HIGH-ENERGY PLASMA STARBURST & DIRECTED DISCHARGE
        // 8-Directional explosive discharge vector rays
        const pts = 8;
        for (int i = 0; i < pts; i++) {
          final angle = (i * 45.0) * pi / 180.0;
          final outerLen = (i % 2 == 0) ? 7.5 * scale : 4.8 * scale;
          final start = Offset(center.dx + 2.0 * scale * cos(angle),
              center.dy + 2.0 * scale * sin(angle));
          final end = Offset(center.dx + outerLen * cos(angle),
              center.dy + outerLen * sin(angle));
          canvas.drawLine(start, end, primaryLine);
          canvas.drawCircle(
              end, (i % 2 == 0) ? 1.1 * scale : 0.8 * scale, nodeFill);
        }

        // Concentric energetic capacitor diamond
        final capDiamond = Path();
        capDiamond.moveTo(center.dx, center.dy - 3.5 * scale);
        capDiamond.lineTo(center.dx + 3.5 * scale, center.dy);
        capDiamond.lineTo(center.dx, center.dy + 3.5 * scale);
        capDiamond.lineTo(center.dx - 3.5 * scale, center.dy);
        capDiamond.close();
        canvas.drawPath(capDiamond, fineLine);

        // Central ignition core
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;

      case SpellSchool.illusion:
        // PHASE-SHIFTED INTERFERENCE MATRIX / MIRAGE RINGS
        // Two intersecting wireframe circles creating interference fringes
        final d = 3.2 * scale;
        final rRing = 5.2 * scale;
        canvas.drawCircle(center - Offset(d, 0), rRing, primaryLine);
        canvas.drawCircle(center + Offset(d, 0), rRing, primaryLine);

        // Vertical interference coordinate lines
        canvas.drawLine(center - Offset(0, 4.0 * scale),
            center + Offset(0, 4.0 * scale), fineLine);
        canvas.drawLine(center - Offset(1.5 * scale, 3.2 * scale),
            center - Offset(1.5 * scale, -3.2 * scale), fineLine);
        canvas.drawLine(center + Offset(1.5 * scale, -3.2 * scale),
            center + Offset(1.5 * scale, 3.2 * scale), fineLine);

        // Optical focal sensor nodes
        canvas.drawCircle(center - Offset(d, 0), 1.1 * scale, nodeFill);
        canvas.drawCircle(center + Offset(d, 0), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(0, 4.0 * scale), 0.9 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(0, 4.0 * scale), 0.9 * scale, nodeFill);
        break;

      case SpellSchool.necromancy:
        // ENTROPY TRIAD / SOUL DRAIN SIPHON RUNE
        // Inverted entropy triangle with inner recursive delta
        final rTri = 6.8 * scale;
        final tri1 = Path();
        final tri2 = Path();
        for (int i = 0; i < 3; i++) {
          final a1 = (i * 120.0 + 90.0) * pi / 180.0;
          final a2 = (i * 120.0 - 90.0) * pi / 180.0;
          final p1 =
              Offset(center.dx + rTri * cos(a1), center.dy + rTri * sin(a1));
          final p2 = Offset(center.dx + (rTri * 0.5) * cos(a2),
              center.dy + (rTri * 0.5) * sin(a2));
          if (i == 0) {
            tri1.moveTo(p1.dx, p1.dy);
            tri2.moveTo(p2.dx, p2.dy);
          } else {
            tri1.lineTo(p1.dx, p1.dy);
            tri2.lineTo(p2.dx, p2.dy);
          }
          canvas.drawLine(p1, center, fineLine);
        }
        tri1.close();
        tri2.close();
        canvas.drawPath(tri1, primaryLine);
        canvas.drawPath(tri2, fineLine);

        // Entropy siphon vertices
        for (int i = 0; i < 3; i++) {
          final a1 = (i * 120.0 + 90.0) * pi / 180.0;
          final p1 =
              Offset(center.dx + rTri * cos(a1), center.dy + rTri * sin(a1));
          canvas.drawCircle(p1, 1.2 * scale, nodeFill);
        }
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;

      case SpellSchool.transmutation:
        // CHRONO-VECTOR HOURGLASS & METAMORPHIC FLUX LATTICE
        // Precision wireframe hourglass vectors
        final hg = Path();
        hg.moveTo(center.dx - 5.5 * scale, center.dy - 6.0 * scale);
        hg.lineTo(center.dx + 5.5 * scale, center.dy - 6.0 * scale);
        hg.lineTo(center.dx - 5.5 * scale, center.dy + 6.0 * scale);
        hg.lineTo(center.dx + 5.5 * scale, center.dy + 6.0 * scale);
        hg.close();
        canvas.drawPath(hg, primaryLine);

        // Horizontal flux planes
        canvas.drawLine(center - Offset(4.0 * scale, 3.0 * scale),
            center + Offset(4.0 * scale, -3.0 * scale), fineLine);
        canvas.drawLine(center - Offset(4.0 * scale, -3.0 * scale),
            center + Offset(4.0 * scale, 3.0 * scale), fineLine);

        // Central transmutation catalyst node & vector tick rings
        canvas.drawCircle(center, 4.2 * scale, fineLine);
        canvas.drawCircle(center, 1.6 * scale, nodeHollow);
        canvas.drawCircle(center, 1.6 * scale, primaryLine);
        canvas.drawCircle(center, 0.8 * scale, nodeFill);

        // 4 Terminal flux points
        canvas.drawCircle(
            center - Offset(5.5 * scale, 6.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(5.5 * scale, -6.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(5.5 * scale, -6.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(5.5 * scale, 6.0 * scale), 1.0 * scale, nodeFill);
        break;
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // 14 CREATURE CLASSIFICATION TECHNO-RUNES
  // ---------------------------------------------------------------------------

  static void drawCreatureMotif({
    required Canvas canvas,
    required Size size,
    required CreatureType type,
    required Color color,
    required bool isDarkMode,
    double pulseTurns = 0.0,
    bool animatePulse = false,
  }) {
    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final center = Offset(w / 2.0, h / 2.0);
    final scale = s / baseGrid;
    final pulseWave =
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 2.2)) : 0.0;
    final pulseScale = animatePulse ? (1.0 + 0.038 * pulseWave) : 1.0;
    final primaryAlpha = animatePulse ? (0.86 + 0.14 * pulseWave) : 1.0;
    final fineBaseAlpha = isDarkMode ? 0.70 : 0.55;
    final fineAlpha =
        animatePulse ? (fineBaseAlpha + 0.20 * pulseWave) : fineBaseAlpha;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulseScale, pulseScale);
    canvas.translate(-center.dx, -center.dy);

    final primaryLine = Paint()
      ..color = color.withValues(alpha: primaryAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fineLine = Paint()
      ..color = color.withValues(alpha: fineAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85 * scale
      ..strokeCap = StrokeCap.round;

    final nodeFill = Paint()
      ..color = color.withValues(alpha: primaryAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    switch (type) {
      case CreatureType.aberration:
        // PSIONIC OCTAGON LATTICE & TENTACLE TRACES
        canvas.drawCircle(center, 3.0 * scale, primaryLine);
        canvas.drawCircle(center, 5.8 * scale, fineLine);
        for (int i = 0; i < 4; i++) {
          final a = (i * 90.0 + 45.0) * pi / 180.0;
          final start = Offset(center.dx + 3.0 * scale * cos(a),
              center.dy + 3.0 * scale * sin(a));
          final mid = Offset(center.dx + 5.5 * scale * cos(a + 0.3),
              center.dy + 5.5 * scale * sin(a + 0.3));
          final end = Offset(center.dx + 7.5 * scale * cos(a + 0.1),
              center.dy + 7.5 * scale * sin(a + 0.1));
          final p = Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(end.dx, end.dy);
          canvas.drawPath(p, primaryLine);
          canvas.drawCircle(end, 1.0 * scale, nodeFill);
        }
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case CreatureType.beast:
        // KINETIC TRIAD CLAW & BIO-VECTOR CHEVRONS
        // 3 Kinetic diagonal claw vectors
        canvas.drawLine(center - Offset(4.5 * scale, 5.5 * scale),
            center - Offset(1.5 * scale, -5.5 * scale), primaryLine);
        canvas.drawLine(center - Offset(0, 6.0 * scale),
            center + Offset(0, 6.0 * scale), primaryLine);
        canvas.drawLine(center + Offset(4.5 * scale, -5.5 * scale),
            center + Offset(1.5 * scale, 5.5 * scale), primaryLine);

        // Lower instinctual apex chevron
        final chev = Path();
        chev.moveTo(center.dx - 5.0 * scale, center.dy + 2.0 * scale);
        chev.lineTo(center.dx, center.dy + 6.0 * scale);
        chev.lineTo(center.dx + 5.0 * scale, center.dy + 2.0 * scale);
        canvas.drawPath(chev, fineLine);

        canvas.drawCircle(
            center - Offset(4.5 * scale, 5.5 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(0, 6.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(4.5 * scale, -5.5 * scale), 1.0 * scale, nodeFill);
        break;

      case CreatureType.celestial:
        // RADIANT SERAPH WINGS & TRANSCENDENT HALO VECTOR
        // Top transcendent halo ring
        canvas.drawOval(
            Rect.fromCenter(
                center: center - Offset(0, 5.0 * scale),
                width: 7.0 * scale,
                height: 2.2 * scale),
            primaryLine);

        // Wing vector rays
        final wings = Path();
        wings.moveTo(center.dx - 7.0 * scale, center.dy - 2.0 * scale);
        wings.lineTo(center.dx - 3.5 * scale, center.dy + 5.5 * scale);
        wings.lineTo(center.dx, center.dy + 2.0 * scale);
        wings.lineTo(center.dx + 3.5 * scale, center.dy + 5.5 * scale);
        wings.lineTo(center.dx + 7.0 * scale, center.dy - 2.0 * scale);
        canvas.drawPath(wings, primaryLine);

        canvas.drawLine(center - Offset(0, 2.0 * scale),
            center + Offset(0, 6.5 * scale), fineLine);
        canvas.drawCircle(
            center - Offset(0, 5.0 * scale), 0.9 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(7.0 * scale, 2.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(7.0 * scale, -2.0 * scale), 1.0 * scale, nodeFill);
        break;

      case CreatureType.construct:
        // COG SCHEMATIC & STRUCTURAL BLUEPRINT
        final rGear = 5.8 * scale;
        final gear = Path();
        const teeth = 6;
        for (int i = 0; i < teeth * 2; i++) {
          final rad = (i % 2 == 0) ? rGear : (rGear - 1.6 * scale);
          final angle = (i * pi / teeth);
          final pt = Offset(
              center.dx + rad * cos(angle), center.dy + rad * sin(angle));
          if (i == 0) {
            gear.moveTo(pt.dx, pt.dy);
          } else {
            gear.lineTo(pt.dx, pt.dy);
          }
        }
        gear.close();
        canvas.drawPath(gear, primaryLine);

        // Internal axle square
        canvas.drawRect(
            Rect.fromCenter(
                center: center, width: 3.2 * scale, height: 3.2 * scale),
            fineLine);
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case CreatureType.dragon:
        // WYRM CREST CHEVRON & INFERNAL HORN VECTORS
        final crest = Path();
        crest.moveTo(center.dx, center.dy - 6.5 * scale);
        crest.lineTo(center.dx + 5.5 * scale, center.dy - 1.5 * scale);
        crest.lineTo(center.dx + 3.5 * scale, center.dy + 5.5 * scale);
        crest.lineTo(center.dx, center.dy + 7.0 * scale);
        crest.lineTo(center.dx - 3.5 * scale, center.dy + 5.5 * scale);
        crest.lineTo(center.dx - 5.5 * scale, center.dy - 1.5 * scale);
        crest.close();
        canvas.drawPath(crest, primaryLine);

        // Horn vector spikes
        canvas.drawLine(center - Offset(3.5 * scale, 3.5 * scale),
            center - Offset(6.8 * scale, 7.5 * scale), primaryLine);
        canvas.drawLine(center + Offset(3.5 * scale, -3.5 * scale),
            center + Offset(6.8 * scale, -7.5 * scale), primaryLine);
        canvas.drawCircle(
            center - Offset(6.8 * scale, 7.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(6.8 * scale, -7.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;

      case CreatureType.elemental:
        // PRISMATIC CYCLONE VORTEX
        final vortex = Path();
        const numPts = 24;
        for (int i = 0; i < numPts; i++) {
          final t = i / numPts;
          final rad = 1.2 * scale + (5.5 * scale * t);
          final angle = t * 3.5 * pi;
          final pt = Offset(
              center.dx + rad * cos(angle), center.dy + rad * sin(angle));
          if (i == 0) {
            vortex.moveTo(pt.dx, pt.dy);
          } else {
            vortex.lineTo(pt.dx, pt.dy);
          }
        }
        canvas.drawPath(vortex, primaryLine);

        // Orbital particle nodes
        canvas.drawCircle(
            center + Offset(5.5 * scale, 0), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(4.0 * scale, 3.0 * scale), 0.9 * scale, nodeFill);
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;

      case CreatureType.fey:
        // SYLVAN LUNAR CRESCENT & BUTTERFLY VECTOR
        final moon = Path();
        moon.moveTo(center.dx - 4.5 * scale, center.dy - 5.5 * scale);
        moon.arcToPoint(
            Offset(center.dx - 4.5 * scale, center.dy + 5.5 * scale),
            radius: Radius.circular(5.5 * scale));
        moon.arcToPoint(
            Offset(center.dx - 4.5 * scale, center.dy - 5.5 * scale),
            radius: Radius.circular(3.8 * scale),
            clockwise: false);
        canvas.drawPath(moon, primaryLine);

        // Resonance wing vectors
        final wing = Path();
        wing.moveTo(center.dx + 0.5 * scale, center.dy);
        wing.lineTo(center.dx + 6.0 * scale, center.dy - 4.5 * scale);
        wing.lineTo(center.dx + 4.5 * scale, center.dy);
        wing.lineTo(center.dx + 6.0 * scale, center.dy + 4.5 * scale);
        wing.close();
        canvas.drawPath(wing, fineLine);

        canvas.drawCircle(
            center + Offset(6.0 * scale, -4.5 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(6.0 * scale, 4.5 * scale), 1.0 * scale, nodeFill);
        break;

      case CreatureType.fiend:
        // ABYSSAL POINTED HORNS & TRIDENT LATTICE
        final horns = Path();
        horns.moveTo(center.dx - 6.0 * scale, center.dy - 6.0 * scale);
        horns.quadraticBezierTo(center.dx - 3.0 * scale,
            center.dy + 3.0 * scale, center.dx, center.dy + 6.0 * scale);
        horns.quadraticBezierTo(
            center.dx + 3.0 * scale,
            center.dy + 3.0 * scale,
            center.dx + 6.0 * scale,
            center.dy - 6.0 * scale);
        canvas.drawPath(horns, primaryLine);

        // Trident shaft & barbed prongs
        canvas.drawLine(center - Offset(0, 7.0 * scale),
            center + Offset(0, 6.0 * scale), primaryLine);
        canvas.drawLine(center - Offset(2.8 * scale, 4.0 * scale),
            center - Offset(2.8 * scale, 0), fineLine);
        canvas.drawLine(center + Offset(2.8 * scale, -4.0 * scale),
            center + Offset(2.8 * scale, 0), fineLine);

        canvas.drawCircle(
            center - Offset(6.0 * scale, 6.0 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(6.0 * scale, -6.0 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(0, 7.0 * scale), 1.2 * scale, nodeFill);
        break;

      case CreatureType.giant:
        // TECTONIC MOUNTAIN & MONOLITH VECTOR BLOCKS
        final mtn = Path();
        mtn.moveTo(center.dx - 6.5 * scale, center.dy + 5.5 * scale);
        mtn.lineTo(center.dx, center.dy - 5.5 * scale);
        mtn.lineTo(center.dx + 6.5 * scale, center.dy + 5.5 * scale);
        mtn.close();
        canvas.drawPath(mtn, primaryLine);

        // Heavy vertical monolithic pillar vectors
        canvas.drawLine(center - Offset(2.5 * scale, -1.0 * scale),
            center - Offset(2.5 * scale, -5.5 * scale), fineLine);
        canvas.drawLine(center, center + Offset(0, 5.5 * scale), primaryLine);
        canvas.drawLine(center + Offset(2.5 * scale, 1.0 * scale),
            center + Offset(2.5 * scale, 5.5 * scale), fineLine);

        canvas.drawCircle(
            center - Offset(0, 5.5 * scale), 1.3 * scale, nodeFill);
        break;

      case CreatureType.humanoid:
        // CHIVALRIC VISOR RETICLE & CROSSED SWORD BARS
        canvas.drawRect(
            Rect.fromCenter(
                center: center, width: 8.5 * scale, height: 7.0 * scale),
            primaryLine);

        // Crossed sword coordinate vectors
        canvas.drawLine(center - Offset(5.5 * scale, 5.5 * scale),
            center + Offset(5.5 * scale, 5.5 * scale), fineLine);
        canvas.drawLine(center - Offset(-5.5 * scale, 5.5 * scale),
            center + Offset(-5.5 * scale, 5.5 * scale), fineLine);

        // T-slit tactical ocular
        canvas.drawLine(center - Offset(3.5 * scale, 0),
            center + Offset(3.5 * scale, 0), primaryLine);
        canvas.drawLine(center, center + Offset(0, 3.5 * scale), primaryLine);
        canvas.drawCircle(center, 1.0 * scale, nodeFill);
        break;

      case CreatureType.monstrosity:
        // SERRATED LACERATION & APEX JAWS
        canvas.drawLine(center - Offset(5.5 * scale, 6.0 * scale),
            center - Offset(2.0 * scale, -6.0 * scale), primaryLine);
        canvas.drawLine(center - Offset(1.8 * scale, 6.0 * scale),
            center + Offset(1.8 * scale, 6.0 * scale), primaryLine);
        canvas.drawLine(center + Offset(2.0 * scale, -6.0 * scale),
            center + Offset(5.5 * scale, 6.0 * scale), primaryLine);

        // Apex serrated zig-zag
        final jaw = Path();
        jaw.moveTo(center.dx - 5.0 * scale, center.dy + 2.0 * scale);
        jaw.lineTo(center.dx - 2.5 * scale, center.dy + 4.5 * scale);
        jaw.lineTo(center.dx, center.dy + 2.0 * scale);
        jaw.lineTo(center.dx + 2.5 * scale, center.dy + 4.5 * scale);
        jaw.lineTo(center.dx + 5.0 * scale, center.dy + 2.0 * scale);
        canvas.drawPath(jaw, fineLine);

        canvas.drawCircle(
            center - Offset(5.5 * scale, 6.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(5.5 * scale, -6.0 * scale), 1.0 * scale, nodeFill);
        break;

      case CreatureType.ooze:
        // CELLULAR AMORPHOUS NODES & TENSION RINGS
        canvas.drawCircle(center - Offset(1.8 * scale, 1.8 * scale),
            3.4 * scale, primaryLine);
        canvas.drawCircle(center + Offset(2.8 * scale, 2.5 * scale),
            2.2 * scale, primaryLine);
        canvas.drawCircle(
            center - Offset(2.2 * scale, -3.2 * scale), 1.6 * scale, fineLine);

        // Fluid tension bridge lines
        canvas.drawLine(center - Offset(1.8 * scale, 1.8 * scale),
            center + Offset(2.8 * scale, 2.5 * scale), fineLine);
        canvas.drawCircle(
            center - Offset(1.8 * scale, 1.8 * scale), 1.2 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(2.8 * scale, 2.5 * scale), 0.9 * scale, nodeFill);
        break;

      case CreatureType.plant:
        // PHYTOGENIC BOTANICAL MATRIX & NODAL BRANCHES
        final stem = Path();
        stem.moveTo(center.dx, center.dy + 6.5 * scale);
        stem.lineTo(center.dx, center.dy - 6.5 * scale);
        canvas.drawPath(stem, primaryLine);

        // Branching diagonal leaf vectors
        canvas.drawLine(center + Offset(0, 3.0 * scale),
            center + Offset(4.5 * scale, 0), primaryLine);
        canvas.drawLine(center + Offset(0, -1.0 * scale),
            center - Offset(4.5 * scale, 4.0 * scale), primaryLine);
        canvas.drawLine(center + Offset(0, -3.0 * scale),
            center + Offset(4.0 * scale, -6.0 * scale), fineLine);

        canvas.drawCircle(
            center + Offset(4.5 * scale, 0), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(4.5 * scale, 4.0 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(0, 6.5 * scale), 1.2 * scale, nodeFill);
        break;

      case CreatureType.undead:
        // SEPULCHRAL CROSS & ENERGY DECAY LINES
        // Tombstone cross arch
        canvas.drawLine(center - Offset(0, 6.5 * scale),
            center + Offset(0, 6.5 * scale), primaryLine);
        canvas.drawLine(center - Offset(5.0 * scale, 2.0 * scale),
            center + Offset(5.0 * scale, -2.0 * scale), primaryLine);

        // Diagonal decay energy lines
        canvas.drawLine(center - Offset(4.0 * scale, -3.5 * scale),
            center + Offset(4.0 * scale, 4.5 * scale), fineLine);
        canvas.drawLine(center - Offset(-4.0 * scale, -3.5 * scale),
            center + Offset(-4.0 * scale, 4.5 * scale), fineLine);

        // 4 Sepulchral terminal nodes
        canvas.drawCircle(
            center - Offset(0, 6.5 * scale), 1.2 * scale, nodeFill);
        canvas.drawCircle(
            center - Offset(5.0 * scale, 2.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(
            center + Offset(5.0 * scale, -2.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // 9 MAGIC ITEM & EQUIPMENT TECHNO-RUNES
  // ---------------------------------------------------------------------------

  static void drawItemMotif({
    required Canvas canvas,
    required Size size,
    required ItemCategory category,
    required Color color,
    required bool isDarkMode,
    double pulseTurns = 0.0,
    bool animatePulse = false,
  }) {
    final w = size.width;
    final h = size.height;
    final s = min(w, h);
    final center = Offset(w / 2.0, h / 2.0);
    final scale = s / baseGrid;
    final pulseWave =
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 2.2)) : 0.0;
    final pulseScale = animatePulse ? (1.0 + 0.045 * pulseWave) : 1.0;
    final primaryAlpha = animatePulse ? (0.88 + 0.12 * pulseWave) : 1.0;
    final fineBaseAlpha = isDarkMode ? 0.70 : 0.55;
    final fineAlpha =
        animatePulse ? (fineBaseAlpha + 0.20 * pulseWave) : fineBaseAlpha;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulseScale, pulseScale);
    canvas.translate(-center.dx, -center.dy);

    final primaryLine = Paint()
      ..color = color.withValues(alpha: primaryAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fineLine = Paint()
      ..color = color.withValues(alpha: fineAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.85 * scale
      ..strokeCap = StrokeCap.round;

    final nodeFill = Paint()
      ..color = color.withValues(alpha: primaryAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    final nodeHollow = Paint()
      ..color = isDarkMode ? const Color(0xFF0F172A) : Colors.white
      ..style = PaintingStyle.fill;

    switch (category) {
      case ItemCategory.weapon:
        // CROSSED BLADES & APEX THRUST VECTOR
        final blade1 = Path()
          ..moveTo(center.dx - 5.5 * scale, center.dy + 5.5 * scale)
          ..lineTo(center.dx + 5.5 * scale, center.dy - 5.5 * scale);
        final blade2 = Path()
          ..moveTo(center.dx + 5.5 * scale, center.dy + 5.5 * scale)
          ..lineTo(center.dx - 5.5 * scale, center.dy - 5.5 * scale);
        canvas.drawPath(blade1, primaryLine);
        canvas.drawPath(blade2, primaryLine);

        // Crossguard tick bars
        canvas.drawLine(
          center - Offset(2.2 * scale, 0),
          center + Offset(2.2 * scale, 0),
          primaryLine,
        );
        canvas.drawLine(
          center - Offset(0, 2.2 * scale),
          center + Offset(0, 2.2 * scale),
          primaryLine,
        );

        // Apex thrust point & pommel nodes
        canvas.drawCircle(center - Offset(5.5 * scale, 5.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(center + Offset(5.5 * scale, -5.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(center + Offset(5.5 * scale, 5.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(center - Offset(5.5 * scale, -5.5 * scale), 1.1 * scale, nodeFill);
        canvas.drawCircle(center, 1.5 * scale, nodeHollow);
        canvas.drawCircle(center, 1.5 * scale, primaryLine);
        break;

      case ItemCategory.armor:
        // INTERLOCKING CHEVRON CARAPACE PLATES
        final shieldPath = Path()
          ..moveTo(center.dx - 5.0 * scale, center.dy - 5.0 * scale)
          ..lineTo(center.dx + 5.0 * scale, center.dy - 5.0 * scale)
          ..lineTo(center.dx + 4.0 * scale, center.dy + 1.0 * scale)
          ..lineTo(center.dx, center.dy + 6.0 * scale)
          ..lineTo(center.dx - 4.0 * scale, center.dy + 1.0 * scale)
          ..close();
        canvas.drawPath(shieldPath, primaryLine);

        // Internal chevron plate reinforcement
        final chevron = Path()
          ..moveTo(center.dx - 3.2 * scale, center.dy - 1.5 * scale)
          ..lineTo(center.dx, center.dy + 2.0 * scale)
          ..lineTo(center.dx + 3.2 * scale, center.dy - 1.5 * scale);
        canvas.drawPath(chevron, fineLine);

        // Vertical spine strut
        canvas.drawLine(
          center - Offset(0, 5.0 * scale),
          center + Offset(0, 6.0 * scale),
          fineLine,
        );

        // Deflection rivets
        canvas.drawCircle(center - Offset(3.5 * scale, 4.0 * scale), 0.9 * scale, nodeFill);
        canvas.drawCircle(center + Offset(3.5 * scale, -4.0 * scale), 0.9 * scale, nodeFill);
        canvas.drawCircle(center + Offset(0, 1.8 * scale), 1.1 * scale, nodeFill);
        break;

      case ItemCategory.potion:
        // ALCHEMICAL CRUCIBLE FLASK & CATALYTIC NODES
        final flask = Path()
          // Neck lip
          ..moveTo(center.dx - 2.2 * scale, center.dy - 6.0 * scale)
          ..lineTo(center.dx + 2.2 * scale, center.dy - 6.0 * scale)
          // Neck
          ..moveTo(center.dx - 1.5 * scale, center.dy - 6.0 * scale)
          ..lineTo(center.dx - 1.5 * scale, center.dy - 2.5 * scale)
          // Bulb left
          ..lineTo(center.dx - 5.2 * scale, center.dy + 3.5 * scale)
          // Bottom
          ..quadraticBezierTo(
              center.dx - 3.5 * scale, center.dy + 6.0 * scale, center.dx, center.dy + 6.0 * scale)
          ..quadraticBezierTo(center.dx + 3.5 * scale, center.dy + 6.0 * scale,
              center.dx + 5.2 * scale, center.dy + 3.5 * scale)
          // Bulb right
          ..lineTo(center.dx + 1.5 * scale, center.dy - 2.5 * scale)
          ..lineTo(center.dx + 1.5 * scale, center.dy - 6.0 * scale);
        canvas.drawPath(flask, primaryLine);

        // Meniscus level line
        canvas.drawLine(
          center - Offset(3.8 * scale, -1.0 * scale),
          center + Offset(3.8 * scale, 1.0 * scale),
          fineLine,
        );

        // Catalytic bubble nodes
        canvas.drawCircle(center + Offset(0, 3.2 * scale), 1.2 * scale, nodeFill);
        canvas.drawCircle(center - Offset(1.8 * scale, -2.0 * scale), 0.9 * scale, nodeFill);
        canvas.drawCircle(center + Offset(2.0 * scale, 1.5 * scale), 0.8 * scale, nodeFill);
        break;

      case ItemCategory.ring:
        // CONCENTRIC TORUS & GEMSTONE SETTING
        canvas.drawCircle(center, 5.5 * scale, primaryLine);
        canvas.drawCircle(center, 3.2 * scale, fineLine);

        // Top gemstone bezel diamond
        final gem = Path()
          ..moveTo(center.dx, center.dy - 7.0 * scale)
          ..lineTo(center.dx + 2.2 * scale, center.dy - 5.0 * scale)
          ..lineTo(center.dx, center.dy - 3.2 * scale)
          ..lineTo(center.dx - 2.2 * scale, center.dy - 5.0 * scale)
          ..close();
        canvas.drawPath(gem, primaryLine);

        // Radiating prong rays
        canvas.drawLine(center - Offset(0, 5.5 * scale), center - Offset(0, 7.5 * scale), primaryLine);
        canvas.drawCircle(center - Offset(0, 5.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(center + Offset(0, 5.5 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(center - Offset(5.5 * scale, 0), 1.0 * scale, nodeFill);
        canvas.drawCircle(center + Offset(5.5 * scale, 0), 1.0 * scale, nodeFill);
        break;

      case ItemCategory.rod:
        // SOVEREIGN FOCUS PILLAR & FLANGES
        // Vertical shaft
        canvas.drawLine(
          center - Offset(0, 6.5 * scale),
          center + Offset(0, 6.5 * scale),
          primaryLine,
        );

        // Channeled focus brackets
        final leftFlange = Path()
          ..moveTo(center.dx - 3.5 * scale, center.dy - 4.5 * scale)
          ..lineTo(center.dx - 1.2 * scale, center.dy - 2.0 * scale)
          ..lineTo(center.dx - 1.2 * scale, center.dy + 2.0 * scale)
          ..lineTo(center.dx - 3.5 * scale, center.dy + 4.5 * scale);
        final rightFlange = Path()
          ..moveTo(center.dx + 3.5 * scale, center.dy - 4.5 * scale)
          ..lineTo(center.dx + 1.2 * scale, center.dy - 2.0 * scale)
          ..lineTo(center.dx + 1.2 * scale, center.dy + 2.0 * scale)
          ..lineTo(center.dx + 3.5 * scale, center.dy + 4.5 * scale);
        canvas.drawPath(leftFlange, primaryLine);
        canvas.drawPath(rightFlange, primaryLine);

        // Terminal crown nodes
        canvas.drawCircle(center - Offset(0, 6.5 * scale), 1.3 * scale, nodeFill);
        canvas.drawCircle(center + Offset(0, 6.5 * scale), 1.3 * scale, nodeFill);
        canvas.drawCircle(center, 1.4 * scale, nodeHollow);
        canvas.drawCircle(center, 1.4 * scale, primaryLine);
        break;

      case ItemCategory.scroll:
        // DUAL SCROLL CYLINDERS & INSCRIBED CIPHER LATTICE
        final parchment = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy + 5.5 * scale)
          ..lineTo(center.dx - 4.5 * scale, center.dy + 5.5 * scale)
          ..close();
        canvas.drawPath(parchment, primaryLine);

        // Scroll roll curl cylinders
        canvas.drawLine(
          center - Offset(5.5 * scale, 5.5 * scale),
          center - Offset(5.5 * scale, -5.5 * scale),
          primaryLine,
        );
        canvas.drawLine(
          center + Offset(5.5 * scale, -5.5 * scale),
          center + Offset(5.5 * scale, 5.5 * scale),
          primaryLine,
        );

        // Horizontal runic cipher lines
        canvas.drawLine(center - Offset(3.0 * scale, 2.5 * scale),
            center + Offset(3.0 * scale, -2.5 * scale), fineLine);
        canvas.drawLine(center - Offset(3.0 * scale, 0),
            center + Offset(3.0 * scale, 0), fineLine);
        canvas.drawLine(center - Offset(3.0 * scale, -2.5 * scale),
            center + Offset(3.0 * scale, 2.5 * scale), fineLine);

        // Seal node
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case ItemCategory.staff:
        // PRISMATIC FOCUS SPIRE & HELICAL RINGS
        canvas.drawLine(
          center - Offset(0, 7.0 * scale),
          center + Offset(0, 7.0 * scale),
          primaryLine,
        );

        // Crown crystal headpiece
        final headpiece = Path()
          ..moveTo(center.dx, center.dy - 7.0 * scale)
          ..lineTo(center.dx + 3.0 * scale, center.dy - 3.5 * scale)
          ..lineTo(center.dx, center.dy - 1.5 * scale)
          ..lineTo(center.dx - 3.0 * scale, center.dy - 3.5 * scale)
          ..close();
        canvas.drawPath(headpiece, primaryLine);

        // Helical cross traces
        canvas.drawLine(center - Offset(2.0 * scale, -1.0 * scale),
            center + Offset(2.0 * scale, 2.5 * scale), fineLine);
        canvas.drawLine(center - Offset(2.0 * scale, -4.0 * scale),
            center + Offset(2.0 * scale, -0.5 * scale), fineLine);

        // Focus nodes
        canvas.drawCircle(center - Offset(0, 4.0 * scale), 1.2 * scale, nodeFill);
        canvas.drawCircle(center + Offset(0, 7.0 * scale), 1.1 * scale, nodeFill);
        break;

      case ItemCategory.wand:
        // TAPERED CONDUCTOR NEEDLE & EMITTER TIP
        final wandPath = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy + 6.0 * scale)
          ..lineTo(center.dx + 5.5 * scale, center.dy - 5.5 * scale);
        canvas.drawPath(wandPath, primaryLine);

        // Grip collar
        canvas.drawLine(
          center + Offset(-3.2 * scale, 4.8 * scale) - Offset(1.2 * scale, 1.2 * scale),
          center + Offset(-3.2 * scale, 4.8 * scale) + Offset(1.2 * scale, 1.2 * scale),
          primaryLine,
        );

        // Radiating tip sparks
        canvas.drawLine(
          center + Offset(5.5 * scale, -5.5 * scale),
          center + Offset(7.2 * scale, -5.5 * scale),
          fineLine,
        );
        canvas.drawLine(
          center + Offset(5.5 * scale, -5.5 * scale),
          center + Offset(5.5 * scale, -7.2 * scale),
          fineLine,
        );
        canvas.drawLine(
          center + Offset(5.5 * scale, -5.5 * scale),
          center + Offset(7.0 * scale, -7.0 * scale),
          fineLine,
        );

        canvas.drawCircle(center + Offset(5.5 * scale, -5.5 * scale), 1.2 * scale, nodeFill);
        canvas.drawCircle(center - Offset(4.5 * scale, -6.0 * scale), 1.0 * scale, nodeFill);
        break;

      case ItemCategory.wondrousItem:
        // 8-POINT ASTRAL STAR RELIC & COMPASS NEXUS
        final rStarOuter = 6.2 * scale;
        final rStarInner = 2.5 * scale;
        final star = Path();
        for (int i = 0; i < 8; i++) {
          final aOuter = (i * 45.0) * pi / 180.0;
          final aInner = (i * 45.0 + 22.5) * pi / 180.0;
          final pOuter = Offset(
              center.dx + rStarOuter * cos(aOuter), center.dy + rStarOuter * sin(aOuter));
          final pInner = Offset(
              center.dx + rStarInner * cos(aInner), center.dy + rStarInner * sin(aInner));
          if (i == 0) {
            star.moveTo(pOuter.dx, pOuter.dy);
          } else {
            star.lineTo(pOuter.dx, pOuter.dy);
          }
          star.lineTo(pInner.dx, pInner.dy);
        }
        star.close();
        canvas.drawPath(star, primaryLine);

        // Concentric relic ring
        canvas.drawCircle(center, 4.0 * scale, fineLine);

        // Central astral nexus
        canvas.drawCircle(center, 1.4 * scale, nodeHollow);
        canvas.drawCircle(center, 1.4 * scale, primaryLine);
        canvas.drawCircle(center, 0.7 * scale, nodeFill);
        break;
    }

    canvas.restore();
  }
}

