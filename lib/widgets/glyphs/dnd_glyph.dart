import 'dart:math';
import 'package:flutter/material.dart';
import 'glyph_tokens.dart';
import 'glyph_geometry.dart';
import 'glyph_motifs.dart';

/// Universal Dynamic D&D Vector Glyph Widget for Spells and Monsters.
/// Renders an authentic holographic wireframe techno-rune schematic HUD with
/// dynamic, damage-colored geometric action trait rings.
class DndGlyph extends StatelessWidget {
  final SpellSchool? school;
  final CreatureType? creatureType;
  final GlyphThemeData themeData;
  final int tierLevel; // Spell Level (0-9) or Monster CR Tier (1-4)
  final List<ActionTraitRing> actionRings;
  final DamageAccent? damageAccent; // Legacy support
  final ActionBadge? actionBadge;   // Legacy support
  final double size;
  final bool? isDarkMode;
  final bool isActive;
  final VoidCallback? onTap;
  final String? tooltip;

  const DndGlyph._({
    super.key,
    this.school,
    this.creatureType,
    required this.themeData,
    this.tierLevel = 0,
    this.actionRings = const [],
    this.damageAccent,
    this.actionBadge,
    this.size = 32.0,
    this.isDarkMode,
    this.isActive = false,
    this.onTap,
    this.tooltip,
  });

  /// Factory constructor for Arcane Spell Glyphs.
  factory DndGlyph.spell({
    Key? key,
    required SpellSchool school,
    int level = 0,
    List<ActionTraitRing>? actionRings,
    DamageAccent? damageAccent,
    double size = 32.0,
    bool? isDarkMode,
    bool isActive = false,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final rings = actionRings ?? (damageAccent != null
        ? [ActionTraitRing(ringType: ActionRingType.concentration, damageType: damageAccent)]
        : const <ActionTraitRing>[]);

    return DndGlyph._(
      key: key,
      school: school,
      themeData: GlyphThemeData.fromSchool(school),
      tierLevel: level.clamp(0, 9),
      actionRings: rings,
      damageAccent: damageAccent,
      size: size,
      isDarkMode: isDarkMode,
      isActive: isActive,
      onTap: onTap,
      tooltip: tooltip ?? '${school.displayName} (Level $level)',
    );
  }

  /// Factory constructor for Monster & Creature Glyphs.
  factory DndGlyph.monster({
    Key? key,
    required CreatureType creatureType,
    int crTier = 1,
    List<ActionTraitRing>? actionRings,
    ActionBadge? actionBadge,
    double size = 32.0,
    bool? isDarkMode,
    bool isActive = false,
    VoidCallback? onTap,
    String? tooltip,
  }) {
    final rings = actionRings ?? (actionBadge != null
        ? [_mapLegacyBadge(actionBadge)]
        : const <ActionTraitRing>[]);

    return DndGlyph._(
      key: key,
      creatureType: creatureType,
      themeData: GlyphThemeData.fromCreature(creatureType),
      tierLevel: crTier.clamp(1, 4),
      actionRings: rings,
      actionBadge: actionBadge,
      size: size,
      isDarkMode: isDarkMode,
      isActive: isActive,
      onTap: onTap,
      tooltip: tooltip ?? '${creatureType.displayName} (Tier $crTier)',
    );
  }

  static ActionTraitRing _mapLegacyBadge(ActionBadge badge) {
    switch (badge) {
      case ActionBadge.melee:
        return const ActionTraitRing(ringType: ActionRingType.melee);
      case ActionBadge.ranged:
        return const ActionTraitRing(ringType: ActionRingType.ranged);
      case ActionBadge.recharge:
        return const ActionTraitRing(ringType: ActionRingType.recharge);
      case ActionBadge.legendary:
        return const ActionTraitRing(ringType: ActionRingType.legendary);
      case ActionBadge.lair:
        return const ActionTraitRing(ringType: ActionRingType.reaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode ?? (Theme.of(context).brightness == Brightness.dark);

    Widget glyph = CustomPaint(
      size: Size(size, size),
      painter: _DndHolographicWireframePainter(
        school: school,
        creatureType: creatureType,
        themeData: themeData,
        tierLevel: tierLevel,
        actionRings: actionRings,
        damageAccent: damageAccent,
        actionBadge: actionBadge,
        isDarkMode: isDark,
        isActive: isActive,
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      glyph = Tooltip(
        message: tooltip!,
        child: glyph,
      );
    }

    if (onTap != null) {
      glyph = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: glyph,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: glyph,
    );
  }
}

/// Specialized CustomPainter that renders pure techno-wireframe schematics with HUD blueprints
/// and concentric geometric action trait rings colored by damage types.
class _DndHolographicWireframePainter extends CustomPainter {
  final SpellSchool? school;
  final CreatureType? creatureType;
  final GlyphThemeData themeData;
  final int tierLevel;
  final List<ActionTraitRing> actionRings;
  final DamageAccent? damageAccent;
  final ActionBadge? actionBadge;
  final bool isDarkMode;
  final bool isActive;

  _DndHolographicWireframePainter({
    required this.school,
    required this.creatureType,
    required this.themeData,
    required this.tierLevel,
    required this.actionRings,
    required this.damageAccent,
    required this.actionBadge,
    required this.isDarkMode,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width, size.height) / GlyphGeometry.baseGrid;
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final primary = themeData.primary;

    // -------------------------------------------------------------------------
    // 1. HOLOGRAM NEON PROJECTION GLOW (Multi-Layered Bloom Halo)
    // -------------------------------------------------------------------------
    final containerPath = GlyphGeometry.getContainerPath(themeData.frameShape, size);
    
    // Outer ambient neon aura
    final auraBloom = Paint()
      ..color = primary.withValues(alpha: isDarkMode ? 0.35 : 0.22)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, (tierLevel >= 4 ? 6.0 : 3.5) * scale);
    canvas.drawPath(containerPath, auraBloom);

    // Inner sharp neon glow line
    final rimGlow = Paint()
      ..color = primary.withValues(alpha: isDarkMode ? 0.75 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * scale
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * scale);
    canvas.drawPath(containerPath, rimGlow);

    // -------------------------------------------------------------------------
    // 2. CYBER HUD BACKPLATE (Deep Translucent Glass backing)
    // -------------------------------------------------------------------------
    final bgPaint = Paint()
      ..color = isDarkMode
          ? const Color(0xFF030712).withValues(alpha: 0.92)
          : primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(containerPath, bgPaint);

    // -------------------------------------------------------------------------
    // 3. WIREFRAME SCHEMATIC BLUEPRINT (Grid, Reticle Ticks & Scanlines)
    // -------------------------------------------------------------------------
    canvas.save();
    canvas.clipPath(containerPath);

    // 3a. Fine coordinate grid lines
    final gridPaint = Paint()
      ..color = (isDarkMode ? primary : const Color(0xFF0F172A)).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5 * scale;
    const gridSpacing = 4.0;
    for (double x = 0; x <= size.width; x += gridSpacing * scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += gridSpacing * scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3b. Concentric HUD Reticle & Degree Angle Ticks
    final reticlePaint = Paint()
      ..color = (isDarkMode ? Colors.cyanAccent : primary).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6 * scale;
    canvas.drawCircle(center, 9.2 * scale, reticlePaint);
    canvas.drawCircle(center, 6.2 * scale, reticlePaint);

    // 12 Gimbal telemetry degree ticks around outer ring
    for (int i = 0; i < 12; i++) {
      final a = (i * 30.0) * pi / 180.0;
      final p1 = Offset(center.dx + 8.5 * scale * cos(a), center.dy + 8.5 * scale * sin(a));
      final p2 = Offset(center.dx + 9.5 * scale * cos(a), center.dy + 9.5 * scale * sin(a));
      canvas.drawLine(p1, p2, reticlePaint);
    }

    // 3c. 4 Corner Bracket Coordinates: [ ]
    final bracketPaint = Paint()
      ..color = (isDarkMode ? Colors.white : primary).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 * scale;
    final bOffset = 7.8 * scale;
    final bLen = 2.0 * scale;
    // Top-Left [
    canvas.drawLine(center - Offset(bOffset, bOffset), center - Offset(bOffset - bLen, bOffset), bracketPaint);
    canvas.drawLine(center - Offset(bOffset, bOffset), center - Offset(bOffset, bOffset - bLen), bracketPaint);
    // Top-Right ]
    canvas.drawLine(center + Offset(bOffset, -bOffset), center + Offset(bOffset - bLen, -bOffset), bracketPaint);
    canvas.drawLine(center + Offset(bOffset, -bOffset), center + Offset(bOffset, -bOffset + bLen), bracketPaint);
    // Bottom-Left [
    canvas.drawLine(center + Offset(-bOffset, bOffset), center + Offset(-bOffset + bLen, bOffset), bracketPaint);
    canvas.drawLine(center + Offset(-bOffset, bOffset), center + Offset(-bOffset, bOffset - bLen), bracketPaint);
    // Bottom-Right ]
    canvas.drawLine(center + Offset(bOffset, bOffset), center + Offset(bOffset - bLen, bOffset), bracketPaint);
    canvas.drawLine(center + Offset(bOffset, bOffset), center + Offset(bOffset, bOffset - bLen), bracketPaint);

    // 3d. Holographic Horizontal Raster Scanlines
    final scanlinePaint = Paint()
      ..color = (isDarkMode ? Colors.white : primary).withValues(alpha: 0.08)
      ..strokeWidth = 0.5 * scale;
    for (double y = 0; y <= size.height; y += 2.0 * scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }
    canvas.restore();

    // -------------------------------------------------------------------------
    // 4. WIREFRAME OUTER CONTAINMENT FRAME
    // -------------------------------------------------------------------------
    final outerFramePaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(containerPath, outerFramePaint);

    // -------------------------------------------------------------------------
    // 5. TIER DECORATIONS (Circuit nodes, notches, double frame, filigree crowns)
    // -------------------------------------------------------------------------
    GlyphGeometry.drawTierDecorations(
      canvas: canvas,
      size: size,
      tierLevel: tierLevel,
      shape: themeData.frameShape,
      primaryColor: primary,
      isDarkMode: isDarkMode,
    );

    // -------------------------------------------------------------------------
    // 6. ACTION & ATTACK TRAIT RINGS (Concentric, Geometric, Damage-Colored)
    // -------------------------------------------------------------------------
    if (actionRings.isNotEmpty) {
      GlyphGeometry.drawActionTraitRings(
        canvas: canvas,
        size: size,
        rings: actionRings,
        defaultColor: primary,
        isDarkMode: isDarkMode,
      );
    }

    // -------------------------------------------------------------------------
    // 7. CORE WIREFRAME TECHNO-RUNE MOTIF
    // -------------------------------------------------------------------------
    final motifColor = isDarkMode ? const Color(0xFFF8FAFC) : primary;
    if (school != null) {
      GlyphMotifs.drawSchoolMotif(
        canvas: canvas,
        size: size,
        school: school!,
        color: motifColor,
        isDarkMode: isDarkMode,
      );
    } else if (creatureType != null) {
      GlyphMotifs.drawCreatureMotif(
        canvas: canvas,
        size: size,
        type: creatureType!,
        color: motifColor,
        isDarkMode: isDarkMode,
      );
    }

    // -------------------------------------------------------------------------
    // 8. LEGACY CORNER BADGES (if actionRings was empty)
    // -------------------------------------------------------------------------
    if (actionRings.isEmpty) {
      if (damageAccent != null) {
        GlyphGeometry.drawDamageAccent(
          canvas: canvas,
          size: size,
          accent: damageAccent!,
        );
      }

      if (actionBadge != null) {
        GlyphGeometry.drawActionBadge(
          canvas: canvas,
          size: size,
          badge: actionBadge!,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DndHolographicWireframePainter old) {
    return old.school != school ||
        old.creatureType != creatureType ||
        old.themeData != themeData ||
        old.tierLevel != tierLevel ||
        old.actionRings != actionRings ||
        old.damageAccent != damageAccent ||
        old.actionBadge != actionBadge ||
        old.isDarkMode != isDarkMode ||
        old.isActive != isActive;
  }
}
