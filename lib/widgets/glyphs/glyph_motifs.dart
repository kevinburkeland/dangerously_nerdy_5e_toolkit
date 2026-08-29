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
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 1.0)) : 0.0;
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
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 1.0)) : 0.0;
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
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 1.0)) : 0.0;
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

      case ItemCategory.adventuringGear:
        // EXPEDITION GEAR PACK & HARNESS SCHEMATIC
        final packRect = Rect.fromCenter(
          center: center + Offset(0, 1.0 * scale),
          width: 9.0 * scale,
          height: 8.0 * scale,
        );
        final rpack = RRect.fromRectAndRadius(packRect, Radius.circular(1.5 * scale));
        canvas.drawRRect(rpack, primaryLine);

        // Flap & strap lines
        canvas.drawLine(
          Offset(center.dx - 4.5 * scale, center.dy - 1.5 * scale),
          Offset(center.dx + 4.5 * scale, center.dy - 1.5 * scale),
          primaryLine,
        );
        canvas.drawLine(
          Offset(center.dx - 2.2 * scale, center.dy - 3.0 * scale),
          Offset(center.dx - 2.2 * scale, center.dy + 4.5 * scale),
          fineLine,
        );
        canvas.drawLine(
          Offset(center.dx + 2.2 * scale, center.dy - 3.0 * scale),
          Offset(center.dx + 2.2 * scale, center.dy + 4.5 * scale),
          fineLine,
        );

        // Buckle and bedroll roll
        canvas.drawCircle(Offset(center.dx - 2.2 * scale, center.dy + 0.5 * scale), 0.8 * scale, nodeFill);
        canvas.drawCircle(Offset(center.dx + 2.2 * scale, center.dy + 0.5 * scale), 0.8 * scale, nodeFill);
        canvas.drawLine(
          Offset(center.dx - 4.0 * scale, center.dy - 4.0 * scale),
          Offset(center.dx + 4.0 * scale, center.dy - 4.0 * scale),
          primaryLine,
        );
        break;

      case ItemCategory.gemstone:
        // FACETED GEMSTONE & REFRACTIVE MATRIX
        final gemPath = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy - 2.0 * scale)
          ..lineTo(center.dx - 2.2 * scale, center.dy - 5.0 * scale)
          ..lineTo(center.dx + 2.2 * scale, center.dy - 5.0 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 2.0 * scale)
          ..lineTo(center.dx, center.dy + 5.5 * scale)
          ..close();
        canvas.drawPath(gemPath, primaryLine);

        // Internal facet lines
        canvas.drawLine(
          Offset(center.dx - 4.5 * scale, center.dy - 2.0 * scale),
          Offset(center.dx + 4.5 * scale, center.dy - 2.0 * scale),
          fineLine,
        );
        canvas.drawLine(
          Offset(center.dx - 2.2 * scale, center.dy - 5.0 * scale),
          Offset(center.dx, center.dy + 5.5 * scale),
          fineLine,
        );
        canvas.drawLine(
          Offset(center.dx + 2.2 * scale, center.dy - 5.0 * scale),
          Offset(center.dx, center.dy + 5.5 * scale),
          fineLine,
        );
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case ItemCategory.artObject:
        // ARTISAN FILIGREE CHALICE & CROWN RELIC
        final chalice = Path()
          ..moveTo(center.dx - 4.0 * scale, center.dy - 4.5 * scale)
          ..lineTo(center.dx + 4.0 * scale, center.dy - 4.5 * scale)
          ..lineTo(center.dx + 3.0 * scale, center.dy)
          ..quadraticBezierTo(center.dx, center.dy + 3.0 * scale, center.dx, center.dy + 3.0 * scale)
          ..lineTo(center.dx, center.dy + 5.0 * scale)
          ..lineTo(center.dx - 3.0 * scale, center.dy + 5.0 * scale)
          ..lineTo(center.dx + 3.0 * scale, center.dy + 5.0 * scale)
          ..moveTo(center.dx, center.dy + 3.0 * scale)
          ..quadraticBezierTo(center.dx, center.dy + 3.0 * scale, center.dx - 3.0 * scale, center.dy)
          ..close();
        canvas.drawPath(chalice, primaryLine);
        canvas.drawCircle(center - Offset(0, 2.0 * scale), 1.0 * scale, nodeFill);
        break;

      case ItemCategory.trinket:
        // CURIOSITY CLOCKWORK & MYSTERY KEYHOLE
        canvas.drawCircle(center, 4.5 * scale, primaryLine);
        canvas.drawCircle(center, 2.0 * scale, fineLine);
        canvas.drawLine(
          center - Offset(0, 5.5 * scale),
          center + Offset(0, 5.5 * scale),
          fineLine,
        );
        canvas.drawLine(
          center - Offset(5.5 * scale, 0),
          center + Offset(5.5 * scale, 0),
          fineLine,
        );
        canvas.drawCircle(center, 0.9 * scale, nodeFill);
        break;
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // CHARACTER CLASS TECHNO-RUNES & HIT DIE GEOMETRY
  // ---------------------------------------------------------------------------

  static void drawClassMotif({
    required Canvas canvas,
    required Size size,
    required DndClassType classType,
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
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 1.0)) : 0.0;
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

    // 1. Draw Hit Die Facet Geometry (d6, d8, d10, d12) in background
    final hitDieRadius = 6.2 * scale;
    final hitSides = classType.hitDieSides;
    final hitPoly = Path();
    for (int i = 0; i < hitSides; i++) {
      final a = (i * (360.0 / hitSides) - 90.0) * pi / 180.0;
      final pt = Offset(
        center.dx + hitDieRadius * cos(a),
        center.dy + hitDieRadius * sin(a),
      );
      if (i == 0) {
        hitPoly.moveTo(pt.dx, pt.dy);
      } else {
        hitPoly.lineTo(pt.dx, pt.dy);
      }
    }
    hitPoly.close();
    canvas.drawPath(hitPoly, fineLine);

    // 2. Draw Class-Specific Cyber-Sigil
    switch (classType) {
      case DndClassType.barbarian:
        // CROSSED BATTLEAXES & PRIMAL RAGE BURST
        canvas.drawLine(
          center - Offset(5.0 * scale, 5.0 * scale),
          center + Offset(5.0 * scale, 5.0 * scale),
          primaryLine,
        );
        canvas.drawLine(
          center - Offset(-5.0 * scale, 5.0 * scale),
          center + Offset(-5.0 * scale, 5.0 * scale),
          primaryLine,
        );
        // Axe blade crescents
        final axeA = Path()
          ..moveTo(center.dx - 5.5 * scale, center.dy - 3.5 * scale)
          ..quadraticBezierTo(center.dx - 3.0 * scale, center.dy - 5.5 * scale, center.dx - 2.0 * scale, center.dy - 3.0 * scale);
        final axeB = Path()
          ..moveTo(center.dx + 5.5 * scale, center.dy - 3.5 * scale)
          ..quadraticBezierTo(center.dx + 3.0 * scale, center.dy - 5.5 * scale, center.dx + 2.0 * scale, center.dy - 3.0 * scale);
        canvas.drawPath(axeA, primaryLine);
        canvas.drawPath(axeB, primaryLine);
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;

      case DndClassType.bard:
        // HARMONIC LYRE & SINE SOUNDWAVE RESONANCE
        final lyre = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy - 4.0 * scale)
          ..cubicTo(center.dx - 4.5 * scale, center.dy + 3.0 * scale, center.dx, center.dy + 5.0 * scale, center.dx, center.dy + 5.0 * scale)
          ..cubicTo(center.dx, center.dy + 5.0 * scale, center.dx + 4.5 * scale, center.dy + 3.0 * scale, center.dx + 4.5 * scale, center.dy - 4.0 * scale);
        canvas.drawPath(lyre, primaryLine);
        // Strings / frequency lines
        canvas.drawLine(Offset(center.dx - 2.0 * scale, center.dy - 3.0 * scale), Offset(center.dx - 2.0 * scale, center.dy + 3.5 * scale), fineLine);
        canvas.drawLine(Offset(center.dx, center.dy - 3.0 * scale), Offset(center.dx, center.dy + 4.5 * scale), fineLine);
        canvas.drawLine(Offset(center.dx + 2.0 * scale, center.dy - 3.0 * scale), Offset(center.dx + 2.0 * scale, center.dy + 3.5 * scale), fineLine);
        canvas.drawCircle(center - Offset(4.5 * scale, 4.0 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(center + Offset(4.5 * scale, -4.0 * scale), 1.0 * scale, nodeFill);
        break;

      case DndClassType.cleric:
        // SACRED SOLAR CROSS & DIVINE HALO RADIANCE
        canvas.drawCircle(center, 3.8 * scale, fineLine);
        canvas.drawLine(center - Offset(0, 5.8 * scale), center + Offset(0, 5.8 * scale), primaryLine);
        canvas.drawLine(center - Offset(4.5 * scale, 1.8 * scale), center + Offset(4.5 * scale, -1.8 * scale), primaryLine);
        // 4 Radiant burst flares
        for (int i = 0; i < 4; i++) {
          final a = (i * 90.0 + 45.0) * pi / 180.0;
          canvas.drawLine(
            Offset(center.dx + 3.8 * scale * cos(a), center.dy + 3.8 * scale * sin(a)),
            Offset(center.dx + 5.5 * scale * cos(a), center.dy + 5.5 * scale * sin(a)),
            fineLine,
          );
        }
        canvas.drawCircle(center - Offset(0, 1.8 * scale), 1.2 * scale, nodeFill);
        break;

      case DndClassType.druid:
        // SACRED OAK LEAF & PRIMAL SPIRAL RUNES
        final leaf = Path()
          ..moveTo(center.dx, center.dy - 5.5 * scale)
          ..quadraticBezierTo(center.dx + 4.5 * scale, center.dy - 1.0 * scale, center.dx, center.dy + 5.5 * scale)
          ..quadraticBezierTo(center.dx - 4.5 * scale, center.dy - 1.0 * scale, center.dx, center.dy - 5.5 * scale);
        canvas.drawPath(leaf, primaryLine);
        // Central vein & spiral arcs
        canvas.drawLine(center - Offset(0, 5.0 * scale), center + Offset(0, 5.0 * scale), fineLine);
        canvas.drawLine(center - Offset(0, 2.0 * scale), center + Offset(2.5 * scale, -0.5 * scale), fineLine);
        canvas.drawLine(center + Offset(0, 1.0 * scale), center - Offset(2.5 * scale, -2.5 * scale), fineLine);
        canvas.drawCircle(center, 1.1 * scale, nodeFill);
        break;

      case DndClassType.fighter:
        // CROSSED LONGSWORDS & VANGUARD RETICLE
        canvas.drawLine(center - Offset(5.0 * scale, 5.0 * scale), center + Offset(5.0 * scale, 5.0 * scale), primaryLine);
        canvas.drawLine(center - Offset(-5.0 * scale, 5.0 * scale), center + Offset(-5.0 * scale, 5.0 * scale), primaryLine);
        // Crossguards
        canvas.drawLine(
          center - Offset(3.5 * scale, 3.5 * scale) - Offset(1.5 * scale, -1.5 * scale),
          center - Offset(3.5 * scale, 3.5 * scale) + Offset(1.5 * scale, -1.5 * scale),
          primaryLine,
        );
        canvas.drawLine(
          center - Offset(-3.5 * scale, 3.5 * scale) - Offset(1.5 * scale, 1.5 * scale),
          center - Offset(-3.5 * scale, 3.5 * scale) + Offset(1.5 * scale, 1.5 * scale),
          primaryLine,
        );
        canvas.drawCircle(center, 1.3 * scale, nodeFill);
        break;

      case DndClassType.monk:
        // CHAKRA FOCAL CIRCLES & INNER KI VECTOR
        canvas.drawCircle(center, 4.8 * scale, primaryLine);
        canvas.drawCircle(center, 2.2 * scale, fineLine);
        // S-curve flowing chi channel
        final chi = Path()
          ..moveTo(center.dx, center.dy - 4.8 * scale)
          ..quadraticBezierTo(center.dx + 2.5 * scale, center.dy - 2.4 * scale, center.dx, center.dy)
          ..quadraticBezierTo(center.dx - 2.5 * scale, center.dy + 2.4 * scale, center.dx, center.dy + 4.8 * scale);
        canvas.drawPath(chi, primaryLine);
        canvas.drawCircle(center - Offset(0, 2.4 * scale), 1.0 * scale, nodeFill);
        canvas.drawCircle(center + Offset(0, 2.4 * scale), 1.0 * scale, nodeHollow);
        break;

      case DndClassType.paladin:
        // RADIANT SMITE SHIELD & SACRED SWORD
        final shield = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy - 4.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 4.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy)
          ..quadraticBezierTo(center.dx, center.dy + 5.5 * scale, center.dx, center.dy + 5.5 * scale)
          ..quadraticBezierTo(center.dx - 4.5 * scale, center.dy, center.dx - 4.5 * scale, center.dy)
          ..close();
        canvas.drawPath(shield, primaryLine);
        // Central holy blade
        canvas.drawLine(center - Offset(0, 3.5 * scale), center + Offset(0, 3.5 * scale), primaryLine);
        canvas.drawLine(center - Offset(2.0 * scale, 1.5 * scale), center + Offset(2.0 * scale, -1.5 * scale), fineLine);
        canvas.drawCircle(center - Offset(0, 1.5 * scale), 1.0 * scale, nodeFill);
        break;

      case DndClassType.ranger:
        // HUNTER'S BOW & RADIAL TRACKING RETICLE
        final bow = Path()
          ..moveTo(center.dx - 4.0 * scale, center.dy - 5.0 * scale)
          ..quadraticBezierTo(center.dx + 4.0 * scale, center.dy, center.dx - 4.0 * scale, center.dy + 5.0 * scale);
        canvas.drawPath(bow, primaryLine);
        canvas.drawLine(center - Offset(4.0 * scale, 5.0 * scale), center - Offset(4.0 * scale, -5.0 * scale), fineLine);
        // Arrow
        canvas.drawLine(center - Offset(4.0 * scale, 0), center + Offset(5.0 * scale, 0), primaryLine);
        canvas.drawLine(center + Offset(3.5 * scale, -1.5 * scale), center + Offset(5.0 * scale, 0), primaryLine);
        canvas.drawLine(center + Offset(3.5 * scale, 1.5 * scale), center + Offset(5.0 * scale, 0), primaryLine);
        break;

      case DndClassType.rogue:
        // SHADOW STILETTO & PRECISION SNEAK ATTACK RETICLE
        final stiletto = Path()
          ..moveTo(center.dx, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 1.2 * scale, center.dy + 2.0 * scale)
          ..lineTo(center.dx - 1.2 * scale, center.dy + 2.0 * scale)
          ..close();
        canvas.drawPath(stiletto, primaryLine);
        canvas.drawLine(center - Offset(3.0 * scale, -2.0 * scale), center + Offset(3.0 * scale, 2.0 * scale), primaryLine);
        canvas.drawLine(center + Offset(0, 2.0 * scale), center + Offset(0, 5.0 * scale), primaryLine);
        // Stealth diamond ticks
        canvas.drawCircle(center - Offset(4.5 * scale, 0), 0.8 * scale, nodeFill);
        canvas.drawCircle(center + Offset(4.5 * scale, 0), 0.8 * scale, nodeFill);
        break;

      case DndClassType.sorcerer:
        // WILD MAGIC CHAOS VORTEX & INNER DRAGON SPARK
        final vortex = Path();
        const vortexPts = 6;
        for (int i = 0; i < vortexPts; i++) {
          final a = (i * 60.0 + (pulseTurns * 120.0)) * pi / 180.0;
          final rOut = (i.isEven ? 5.2 : 3.0) * scale;
          final pt = Offset(center.dx + rOut * cos(a), center.dy + rOut * sin(a));
          if (i == 0) {
            vortex.moveTo(pt.dx, pt.dy);
          } else {
            vortex.lineTo(pt.dx, pt.dy);
          }
        }
        vortex.close();
        canvas.drawPath(vortex, primaryLine);
        canvas.drawCircle(center, 1.6 * scale, nodeFill);
        break;

      case DndClassType.warlock:
        // ELDRITCH EYE & PATRON CONTRACT OCCULT PENTACLE
        final eye = Path()
          ..moveTo(center.dx - 5.0 * scale, center.dy)
          ..quadraticBezierTo(center.dx, center.dy - 3.5 * scale, center.dx + 5.0 * scale, center.dy)
          ..quadraticBezierTo(center.dx, center.dy + 3.5 * scale, center.dx - 5.0 * scale, center.dy);
        canvas.drawPath(eye, primaryLine);
        canvas.drawCircle(center, 1.8 * scale, primaryLine);
        canvas.drawCircle(center, 0.9 * scale, nodeFill);
        // Vertical occult lock lines
        canvas.drawLine(center - Offset(0, 5.0 * scale), center - Offset(0, 3.5 * scale), fineLine);
        canvas.drawLine(center + Offset(0, 3.5 * scale), center + Offset(0, 5.0 * scale), fineLine);
        break;

      case DndClassType.wizard:
        // ARCANE PENTACLE & RUNIC SCRIBE SPIRE
        final star = Path();
        for (int i = 0; i < 5; i++) {
          final a = (i * 144.0 - 90.0) * pi / 180.0;
          final pt = Offset(center.dx + 5.0 * scale * cos(a), center.dy + 5.0 * scale * sin(a));
          if (i == 0) {
            star.moveTo(pt.dx, pt.dy);
          } else {
            star.lineTo(pt.dx, pt.dy);
          }
        }
        star.close();
        canvas.drawPath(star, primaryLine);
        canvas.drawCircle(center, 1.5 * scale, nodeHollow);
        canvas.drawCircle(center, 1.5 * scale, fineLine);
        canvas.drawCircle(center, 0.7 * scale, nodeFill);
        break;

      case DndClassType.artificer:
        // INTERLOCKING CLOCKWORK GEAR & CALIPER RUNES
        final gear = Path();
        const teeth = 8;
        for (int i = 0; i < teeth * 2; i++) {
          final a = (i * (360.0 / (teeth * 2))) * pi / 180.0;
          final r = (i.isEven ? 5.2 : 3.8) * scale;
          final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
          if (i == 0) {
            gear.moveTo(pt.dx, pt.dy);
          } else {
            gear.lineTo(pt.dx, pt.dy);
          }
        }
        gear.close();
        canvas.drawPath(gear, primaryLine);
        canvas.drawCircle(center, 2.0 * scale, nodeHollow);
        canvas.drawCircle(center, 2.0 * scale, fineLine);
        canvas.drawCircle(center, 0.8 * scale, nodeFill);
        break;
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // FEAT & EPIC BOON TECHNO-RUNES
  // ---------------------------------------------------------------------------

  static void drawFeatMotif({
    required Canvas canvas,
    required Size size,
    required FeatCategory category,
    required String featId,
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
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 1.0)) : 0.0;
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

    final lowerId = featId.toLowerCase();

    if (lowerId.contains('alert')) {
      // 360-degree radar sensor & alert diamond
      canvas.drawCircle(center, 5.0 * scale, fineLine);
      canvas.drawCircle(center, 2.5 * scale, primaryLine);
      canvas.drawLine(center, center + Offset(4.8 * scale * cos(pulseTurns * 2 * pi), 4.8 * scale * sin(pulseTurns * 2 * pi)), primaryLine);
      canvas.drawCircle(center, 1.2 * scale, nodeFill);
    } else if (lowerId.contains('war_caster') || lowerId.contains('warcaster')) {
      // Crossed focus wand and concentration shield aegis
      canvas.drawLine(center - Offset(4.5 * scale, 4.5 * scale), center + Offset(4.5 * scale, 4.5 * scale), primaryLine);
      canvas.drawCircle(center, 3.5 * scale, primaryLine);
      canvas.drawCircle(center - Offset(4.5 * scale, 4.5 * scale), 1.0 * scale, nodeFill);
      canvas.drawCircle(center + Offset(4.5 * scale, 4.5 * scale), 1.0 * scale, nodeFill);
      canvas.drawCircle(center, 1.2 * scale, nodeFill);
    } else if (lowerId.contains('great_weapon') || lowerId.contains('heavy')) {
      // Heavy cleave arc & crushing greatsword blade
      final blade = Path()
        ..moveTo(center.dx - 1.5 * scale, center.dy - 5.5 * scale)
        ..lineTo(center.dx + 1.5 * scale, center.dy - 5.5 * scale)
        ..lineTo(center.dx + 2.0 * scale, center.dy + 3.0 * scale)
        ..lineTo(center.dx, center.dy + 5.5 * scale)
        ..lineTo(center.dx - 2.0 * scale, center.dy + 3.0 * scale)
        ..close();
      canvas.drawPath(blade, primaryLine);
      final cleaveArc = Rect.fromCircle(center: center, radius: 4.5 * scale);
      canvas.drawArc(cleaveArc, -pi * 0.8, pi * 1.6, false, fineLine);
      canvas.drawCircle(center, 1.0 * scale, nodeFill);
    } else if (lowerId.contains('sharpshooter') || lowerId.contains('sniper')) {
      // Precision concentric crosshairs & distance scope ticks
      canvas.drawCircle(center, 5.2 * scale, primaryLine);
      canvas.drawCircle(center, 2.8 * scale, fineLine);
      canvas.drawLine(center - Offset(6.0 * scale, 0), center + Offset(6.0 * scale, 0), fineLine);
      canvas.drawLine(center - Offset(0, 6.0 * scale), center + Offset(0, 6.0 * scale), fineLine);
      canvas.drawCircle(center, 1.0 * scale, nodeFill);
    } else if (lowerId.contains('sentinel')) {
      // Halberd restraint anchor & perimeter lockdown brackets
      canvas.drawCircle(center, 4.0 * scale, primaryLine);
      canvas.drawLine(center - Offset(0, 5.5 * scale), center + Offset(0, 5.5 * scale), primaryLine);
      canvas.drawLine(center - Offset(4.0 * scale, 0), center + Offset(4.0 * scale, 0), primaryLine);
      canvas.drawCircle(center, 1.4 * scale, nodeFill);
    } else if (lowerId.contains('lucky')) {
      // 4-Leaf quantum probability clover node
      for (int i = 0; i < 4; i++) {
        final a = (i * 90.0) * pi / 180.0;
        final pt = Offset(center.dx + 2.8 * scale * cos(a), center.dy + 2.8 * scale * sin(a));
        canvas.drawCircle(pt, 1.8 * scale, fineLine);
      }
      canvas.drawCircle(center, 1.2 * scale, nodeFill);
    } else if (category == FeatCategory.epicBoon) {
      // COSMIC STARBURST CORONA & TRANSCENDENT APEX
      final star = Path();
      const pts = 8;
      for (int i = 0; i < pts * 2; i++) {
        final a = (i * (360.0 / (pts * 2))) * pi / 180.0;
        final r = (i.isEven ? 5.8 : 2.6) * scale;
        final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
        if (i == 0) {
          star.moveTo(pt.dx, pt.dy);
        } else {
          star.lineTo(pt.dx, pt.dy);
        }
      }
      star.close();
      canvas.drawPath(star, primaryLine);
      canvas.drawCircle(center, 1.8 * scale, nodeFill);
    } else if (category == FeatCategory.general) {
      // GENERAL FEAT APEX STAR MATRIX
      final diamond = Path()
        ..moveTo(center.dx, center.dy - 5.5 * scale)
        ..lineTo(center.dx + 4.5 * scale, center.dy)
        ..lineTo(center.dx, center.dy + 5.5 * scale)
        ..lineTo(center.dx - 4.5 * scale, center.dy)
        ..close();
      canvas.drawPath(diamond, primaryLine);
      canvas.drawCircle(center, 2.5 * scale, fineLine);
      canvas.drawCircle(center, 1.1 * scale, nodeFill);
    } else {
      // ORIGIN FEAT SEED BEACON
      canvas.drawCircle(center, 4.5 * scale, primaryLine);
      canvas.drawLine(center - Offset(0, 5.5 * scale), center + Offset(0, 5.5 * scale), fineLine);
      canvas.drawLine(center - Offset(5.5 * scale, 0), center + Offset(5.5 * scale, 0), fineLine);
      canvas.drawCircle(center, 1.3 * scale, nodeFill);
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // SPECIES / RACE TECHNO-RUNES
  // ---------------------------------------------------------------------------

  static void drawSpeciesMotif({
    required Canvas canvas,
    required Size size,
    required SpeciesType speciesType,
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
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 1.0)) : 0.0;
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

    switch (speciesType) {
      case SpeciesType.human:
        // 8-POINT VERSATILE COMPASS & NEXUS STAR
        for (int i = 0; i < 8; i++) {
          final a = (i * 45.0) * pi / 180.0;
          final len = (i.isEven ? 5.2 : 3.2) * scale;
          canvas.drawLine(center, Offset(center.dx + len * cos(a), center.dy + len * sin(a)), primaryLine);
          canvas.drawCircle(Offset(center.dx + len * cos(a), center.dy + len * sin(a)), 0.8 * scale, nodeFill);
        }
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;

      case SpeciesType.elf:
        // CRESCENT MOON & SYLVAN STARLIGHT FILIGREE
        final moon = Path()
          ..addArc(Rect.fromCircle(center: center, radius: 4.8 * scale), -pi * 0.45, pi * 0.9)
          ..quadraticBezierTo(center.dx + 1.5 * scale, center.dy, center.dx + 4.8 * scale * cos(-pi * 0.45), center.dy + 4.8 * scale * sin(-pi * 0.45));
        canvas.drawPath(moon, primaryLine);
        // Starlight diamond
        final star = Path()
          ..moveTo(center.dx - 2.0 * scale, center.dy - 3.5 * scale)
          ..lineTo(center.dx - 1.0 * scale, center.dy - 2.0 * scale)
          ..lineTo(center.dx - 2.0 * scale, center.dy - 0.5 * scale)
          ..lineTo(center.dx - 3.0 * scale, center.dy - 2.0 * scale)
          ..close();
        canvas.drawPath(star, fineLine);
        canvas.drawCircle(center, 1.0 * scale, nodeFill);
        break;

      case SpeciesType.dwarf:
        // MOUNTAIN ANVIL & GEOMETRIC STONE-RUNE
        final anvil = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy - 3.0 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 3.0 * scale)
          ..lineTo(center.dx + 3.0 * scale, center.dy - 0.5 * scale)
          ..lineTo(center.dx + 2.0 * scale, center.dy + 3.5 * scale)
          ..lineTo(center.dx - 2.0 * scale, center.dy + 3.5 * scale)
          ..lineTo(center.dx - 3.0 * scale, center.dy - 0.5 * scale)
          ..close();
        canvas.drawPath(anvil, primaryLine);
        canvas.drawLine(center - Offset(3.5 * scale, -3.5 * scale), center + Offset(3.5 * scale, 3.5 * scale), primaryLine);
        canvas.drawCircle(center - Offset(0, 1.5 * scale), 1.0 * scale, nodeFill);
        break;

      case SpeciesType.halfling:
        // 4-PETAL HEARTH RUNESTONE & BRAVE CHEVRON
        for (int i = 0; i < 4; i++) {
          final a = (i * 90.0) * pi / 180.0;
          final p = Offset(center.dx + 2.5 * scale * cos(a), center.dy + 2.5 * scale * sin(a));
          canvas.drawCircle(p, 1.6 * scale, fineLine);
        }
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case SpeciesType.dragonborn:
        // DRACONIC SCALES & BREATH WEAPON DIAMOND
        final crest = Path()
          ..moveTo(center.dx, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 1.0 * scale)
          ..lineTo(center.dx, center.dy + 5.5 * scale)
          ..lineTo(center.dx - 4.5 * scale, center.dy - 1.0 * scale)
          ..close();
        canvas.drawPath(crest, primaryLine);
        canvas.drawLine(center - Offset(0, 5.0 * scale), center + Offset(0, 5.0 * scale), fineLine);
        canvas.drawLine(center - Offset(3.5 * scale, 0), center + Offset(3.5 * scale, 0), fineLine);
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case SpeciesType.gnome:
        // CLOCKWORK ESCAPEMENT GEAR & LENS
        canvas.drawCircle(center, 4.2 * scale, primaryLine);
        for (int i = 0; i < 6; i++) {
          final a = (i * 60.0) * pi / 180.0;
          canvas.drawLine(
            Offset(center.dx + 4.2 * scale * cos(a), center.dy + 4.2 * scale * sin(a)),
            Offset(center.dx + 5.5 * scale * cos(a), center.dy + 5.5 * scale * sin(a)),
            primaryLine,
          );
        }
        canvas.drawCircle(center, 1.8 * scale, fineLine);
        canvas.drawCircle(center, 0.8 * scale, nodeFill);
        break;

      case SpeciesType.tiefling:
        // INFERNAL HORNS & BRIMSTONE CHEVRON
        final hornA = Path()
          ..moveTo(center.dx - 3.5 * scale, center.dy + 4.0 * scale)
          ..quadraticBezierTo(center.dx - 5.0 * scale, center.dy - 1.0 * scale, center.dx - 3.0 * scale, center.dy - 5.0 * scale);
        final hornB = Path()
          ..moveTo(center.dx + 3.5 * scale, center.dy + 4.0 * scale)
          ..quadraticBezierTo(center.dx + 5.0 * scale, center.dy - 1.0 * scale, center.dx + 3.0 * scale, center.dy - 5.0 * scale);
        canvas.drawPath(hornA, primaryLine);
        canvas.drawPath(hornB, primaryLine);
        canvas.drawCircle(center + Offset(0, 2.0 * scale), 1.4 * scale, nodeFill);
        break;

      case SpeciesType.orc:
        // RELENTLESS TUSKS & BATTLE SKULL CREST
        final tuskA = Path()
          ..moveTo(center.dx - 3.5 * scale, center.dy + 4.5 * scale)
          ..lineTo(center.dx - 2.0 * scale, center.dy - 1.5 * scale)
          ..lineTo(center.dx - 1.0 * scale, center.dy + 4.5 * scale);
        final tuskB = Path()
          ..moveTo(center.dx + 3.5 * scale, center.dy + 4.5 * scale)
          ..lineTo(center.dx + 2.0 * scale, center.dy - 1.5 * scale)
          ..lineTo(center.dx + 1.0 * scale, center.dy + 4.5 * scale);
        canvas.drawPath(tuskA, primaryLine);
        canvas.drawPath(tuskB, primaryLine);
        canvas.drawLine(center - Offset(4.0 * scale, 3.0 * scale), center + Offset(4.0 * scale, -3.0 * scale), fineLine);
        canvas.drawCircle(center - Offset(0, 2.0 * scale), 1.2 * scale, nodeFill);
        break;

      case SpeciesType.goliath:
        // MEGALITHIC STONE MONOLITH & PEAK CHEVRON
        final peak = Path()
          ..moveTo(center.dx, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy + 4.5 * scale)
          ..lineTo(center.dx - 4.5 * scale, center.dy + 4.5 * scale)
          ..close();
        canvas.drawPath(peak, primaryLine);
        canvas.drawLine(center - Offset(0, 5.0 * scale), center + Offset(0, 4.0 * scale), fineLine);
        canvas.drawLine(center - Offset(2.5 * scale, 1.0 * scale), center + Offset(2.5 * scale, 1.0 * scale), fineLine);
        canvas.drawCircle(center, 1.2 * scale, nodeFill);
        break;

      case SpeciesType.aasimar:
        // CELESTIAL RADIANT WINGS & HALO
        canvas.drawCircle(center - Offset(0, 3.5 * scale), 1.8 * scale, primaryLine);
        final wingA = Path()
          ..moveTo(center.dx - 1.0 * scale, center.dy - 1.0 * scale)
          ..quadraticBezierTo(center.dx - 5.5 * scale, center.dy - 3.0 * scale, center.dx - 4.5 * scale, center.dy + 4.0 * scale);
        final wingB = Path()
          ..moveTo(center.dx + 1.0 * scale, center.dy - 1.0 * scale)
          ..quadraticBezierTo(center.dx + 5.5 * scale, center.dy - 3.0 * scale, center.dx + 4.5 * scale, center.dy + 4.0 * scale);
        canvas.drawPath(wingA, primaryLine);
        canvas.drawPath(wingB, primaryLine);
        canvas.drawCircle(center + Offset(0, 1.5 * scale), 1.1 * scale, nodeFill);
        break;
    }

    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // GENERIC UI & POLYHEDRAL WIREFRAME MOTIFS
  // ---------------------------------------------------------------------------

  static void drawGenericUiMotif({
    required Canvas canvas,
    required Size size,
    required GenericUiGlyphType uiType,
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
        animatePulse ? (0.5 + 0.5 * sin(pulseTurns * 2.0 * pi * 1.0)) : 0.0;
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

    switch (uiType) {
      case GenericUiGlyphType.d4:
        // WIREFRAME TETRAHEDRON
        final pTop = Offset(center.dx, center.dy - 5.5 * scale);
        final pBL = Offset(center.dx - 5.0 * scale, center.dy + 4.5 * scale);
        final pBR = Offset(center.dx + 5.0 * scale, center.dy + 4.5 * scale);
        final pC = Offset(center.dx, center.dy + 1.0 * scale);
        final tri = Path()..moveTo(pTop.dx, pTop.dy)..lineTo(pBR.dx, pBR.dy)..lineTo(pBL.dx, pBL.dy)..close();
        canvas.drawPath(tri, primaryLine);
        canvas.drawLine(pTop, pC, fineLine);
        canvas.drawLine(pBL, pC, fineLine);
        canvas.drawLine(pBR, pC, fineLine);
        canvas.drawCircle(pC, 0.9 * scale, nodeFill);
        break;

      case GenericUiGlyphType.d6:
        // ISOMETRIC 3D CUBE
        final d6Path = Path()
          ..moveTo(center.dx, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 2.8 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy + 2.8 * scale)
          ..lineTo(center.dx, center.dy + 5.5 * scale)
          ..lineTo(center.dx - 4.5 * scale, center.dy + 2.8 * scale)
          ..lineTo(center.dx - 4.5 * scale, center.dy - 2.8 * scale)
          ..close();
        canvas.drawPath(d6Path, primaryLine);
        canvas.drawLine(center, Offset(center.dx, center.dy - 5.5 * scale), fineLine);
        canvas.drawLine(center, Offset(center.dx + 4.5 * scale, center.dy + 2.8 * scale), fineLine);
        canvas.drawLine(center, Offset(center.dx - 4.5 * scale, center.dy + 2.8 * scale), fineLine);
        canvas.drawCircle(center, 1.0 * scale, nodeFill);
        break;

      case GenericUiGlyphType.d8:
        // WIREFRAME OCTAHEDRON DIAMOND
        final d8Path = Path()
          ..moveTo(center.dx, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy)
          ..lineTo(center.dx, center.dy + 5.5 * scale)
          ..lineTo(center.dx - 4.5 * scale, center.dy)
          ..close();
        canvas.drawPath(d8Path, primaryLine);
        canvas.drawLine(Offset(center.dx - 4.5 * scale, center.dy), Offset(center.dx + 4.5 * scale, center.dy), fineLine);
        canvas.drawLine(Offset(center.dx, center.dy - 5.5 * scale), center, fineLine);
        canvas.drawLine(Offset(center.dx, center.dy + 5.5 * scale), center, fineLine);
        canvas.drawCircle(center, 1.1 * scale, nodeFill);
        break;

      case GenericUiGlyphType.d10:
        // WIREFRAME TRAPEZOHEDRON KITE
        final d10Path = Path()
          ..moveTo(center.dx, center.dy - 5.5 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 1.0 * scale)
          ..lineTo(center.dx + 2.5 * scale, center.dy + 5.0 * scale)
          ..lineTo(center.dx - 2.5 * scale, center.dy + 5.0 * scale)
          ..lineTo(center.dx - 4.5 * scale, center.dy - 1.0 * scale)
          ..close();
        canvas.drawPath(d10Path, primaryLine);
        canvas.drawLine(Offset(center.dx, center.dy - 5.5 * scale), center, fineLine);
        canvas.drawLine(Offset(center.dx + 4.5 * scale, center.dy - 1.0 * scale), center, fineLine);
        canvas.drawLine(Offset(center.dx - 4.5 * scale, center.dy - 1.0 * scale), center, fineLine);
        canvas.drawCircle(center, 1.1 * scale, nodeFill);
        break;

      case GenericUiGlyphType.d12:
        // WIREFRAME DODECAHEDRON
        final d12Path = Path();
        for (int i = 0; i < 10; i++) {
          final a = (i * 36.0 - 90.0) * pi / 180.0;
          final r = (i.isEven ? 5.2 : 4.2) * scale;
          final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
          if (i == 0) {
            d12Path.moveTo(pt.dx, pt.dy);
          } else {
            d12Path.lineTo(pt.dx, pt.dy);
          }
        }
        d12Path.close();
        canvas.drawPath(d12Path, primaryLine);
        canvas.drawCircle(center, 2.0 * scale, fineLine);
        canvas.drawCircle(center, 0.9 * scale, nodeFill);
        break;

      case GenericUiGlyphType.d20:
        // WIREFRAME ICOSAHEDRON
        final hex = Path();
        for (int i = 0; i < 6; i++) {
          final a = (i * 60.0 - 30.0) * pi / 180.0;
          final pt = Offset(center.dx + 5.2 * scale * cos(a), center.dy + 5.2 * scale * sin(a));
          if (i == 0) {
            hex.moveTo(pt.dx, pt.dy);
          } else {
            hex.lineTo(pt.dx, pt.dy);
          }
        }
        hex.close();
        canvas.drawPath(hex, primaryLine);
        // Inverted central triangle
        final innerTri = Path();
        for (int i = 0; i < 3; i++) {
          final a = (i * 120.0 + 90.0) * pi / 180.0;
          final pt = Offset(center.dx + 3.0 * scale * cos(a), center.dy + 3.0 * scale * sin(a));
          if (i == 0) {
            innerTri.moveTo(pt.dx, pt.dy);
          } else {
            innerTri.lineTo(pt.dx, pt.dy);
          }
        }
        innerTri.close();
        canvas.drawPath(innerTri, fineLine);
        canvas.drawCircle(center, 1.1 * scale, nodeFill);
        break;

      case GenericUiGlyphType.d100:
        // DUAL PERCENTILE MATRIX
        canvas.drawCircle(center - Offset(2.2 * scale, 0), 3.2 * scale, primaryLine);
        canvas.drawCircle(center + Offset(2.2 * scale, 0), 3.2 * scale, fineLine);
        canvas.drawCircle(center, 1.0 * scale, nodeFill);
        break;

      case GenericUiGlyphType.advantage:
        // DUAL UPWARD CHEVRONS
        final c1 = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy + 3.0 * scale)
          ..lineTo(center.dx, center.dy - 1.0 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy + 3.0 * scale);
        final c2 = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy - 1.0 * scale)
          ..lineTo(center.dx, center.dy - 5.0 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 1.0 * scale);
        canvas.drawPath(c1, fineLine);
        canvas.drawPath(c2, primaryLine);
        canvas.drawCircle(center - Offset(0, 5.0 * scale), 1.0 * scale, nodeFill);
        break;

      case GenericUiGlyphType.disadvantage:
        // DUAL DOWNWARD CHEVRONS
        final c1 = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy - 3.0 * scale)
          ..lineTo(center.dx, center.dy + 1.0 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy - 3.0 * scale);
        final c2 = Path()
          ..moveTo(center.dx - 4.5 * scale, center.dy + 1.0 * scale)
          ..lineTo(center.dx, center.dy + 5.0 * scale)
          ..lineTo(center.dx + 4.5 * scale, center.dy + 1.0 * scale);
        canvas.drawPath(c1, fineLine);
        canvas.drawPath(c2, primaryLine);
        canvas.drawCircle(center + Offset(0, 5.0 * scale), 1.0 * scale, nodeFill);
        break;

      case GenericUiGlyphType.concentrating:
        // DUAL HARMONIC ORBITAL SATELLITE LOOPS & APEX BEACON NODES
        final orbitA =
            Rect.fromCenter(center: center, width: 11.0 * scale, height: 7.2 * scale);
        final orbitB =
            Rect.fromCenter(center: center, width: 7.2 * scale, height: 11.0 * scale);
        canvas.drawOval(orbitA, primaryLine);
        canvas.drawOval(orbitB, fineLine);
        // 4 Orbital satellite nodes at the apsides with telemetry tangent pulse ticks
        final satEast = Offset(center.dx + 5.5 * scale, center.dy);
        final satWest = Offset(center.dx - 5.5 * scale, center.dy);
        final satNorth = Offset(center.dx, center.dy - 5.5 * scale);
        final satSouth = Offset(center.dx, center.dy + 5.5 * scale);

        canvas.drawCircle(satEast, 1.2 * scale, nodeFill);
        canvas.drawCircle(satWest, 1.2 * scale, nodeFill);
        canvas.drawCircle(satNorth, 1.0 * scale, nodeFill);
        canvas.drawCircle(satSouth, 1.0 * scale, nodeFill);
        canvas.drawCircle(center, 1.4 * scale, nodeFill);

        // Tangent pulse micro-ticks
        canvas.drawLine(satEast - Offset(0, 1.4 * scale),
            satEast + Offset(0, 1.4 * scale), fineLine);
        canvas.drawLine(satWest - Offset(0, 1.4 * scale),
            satWest + Offset(0, 1.4 * scale), fineLine);
        canvas.drawLine(satNorth - Offset(1.4 * scale, 0),
            satNorth + Offset(1.4 * scale, 0), fineLine);
        canvas.drawLine(satSouth - Offset(1.4 * scale, 0),
            satSouth + Offset(1.4 * scale, 0), fineLine);
        break;

      case GenericUiGlyphType.deathSave:
        // CARDIAC TELEMETRY PULSE LINE
        final pulse = Path()
          ..moveTo(center.dx - 5.5 * scale, center.dy)
          ..lineTo(center.dx - 2.5 * scale, center.dy)
          ..lineTo(center.dx - 1.2 * scale, center.dy - 4.5 * scale)
          ..lineTo(center.dx + 0.8 * scale, center.dy + 4.5 * scale)
          ..lineTo(center.dx + 2.2 * scale, center.dy)
          ..lineTo(center.dx + 5.5 * scale, center.dy);
        canvas.drawPath(pulse, primaryLine);
        canvas.drawCircle(center - Offset(1.2 * scale, 4.5 * scale), 0.9 * scale, nodeFill);
        canvas.drawCircle(center + Offset(0.8 * scale, -4.5 * scale), 0.9 * scale, nodeFill);
        break;

      case GenericUiGlyphType.actionEconomyAction:
        // PRIMARY ACTION DIAMOND NODE
        final d = Path()
          ..moveTo(center.dx, center.dy - 4.8 * scale)
          ..lineTo(center.dx + 4.8 * scale, center.dy)
          ..lineTo(center.dx, center.dy + 4.8 * scale)
          ..lineTo(center.dx - 4.8 * scale, center.dy)
          ..close();
        canvas.drawPath(d, primaryLine);
        canvas.drawCircle(center, 2.0 * scale, nodeFill);
        break;

      case GenericUiGlyphType.actionEconomyBonus:
        // TRIPLE SPARK QUICK ACTION NODE
        for (int i = 0; i < 3; i++) {
          final a = (i * 120.0 - 90.0) * pi / 180.0;
          canvas.drawLine(
            center,
            Offset(center.dx + 5.0 * scale * cos(a), center.dy + 5.0 * scale * sin(a)),
            primaryLine,
          );
          canvas.drawCircle(
            Offset(center.dx + 5.0 * scale * cos(a), center.dy + 5.0 * scale * sin(a)),
            1.2 * scale,
            nodeFill,
          );
        }
        canvas.drawCircle(center, 1.4 * scale, nodeFill);
        break;

      case GenericUiGlyphType.actionEconomyReaction:
        // DEFLECTION BRACKET SHIELD
        final bracket = Path()
          ..moveTo(center.dx - 4.0 * scale, center.dy - 4.0 * scale)
          ..lineTo(center.dx + 2.0 * scale, center.dy)
          ..lineTo(center.dx - 4.0 * scale, center.dy + 4.0 * scale);
        canvas.drawPath(bracket, primaryLine);
        canvas.drawLine(center + Offset(4.0 * scale, -4.0 * scale), center + Offset(4.0 * scale, 4.0 * scale), fineLine);
        canvas.drawCircle(center + Offset(2.0 * scale, 0), 1.2 * scale, nodeFill);
        break;
    }

    canvas.restore();
  }
}


