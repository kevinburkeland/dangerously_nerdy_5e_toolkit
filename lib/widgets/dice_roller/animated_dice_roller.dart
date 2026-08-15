import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import 'geometry/dice_vector_math.dart';
import 'geometry/polyhedral_mesh.dart';

/// Authentic 3D Polyhedral Dice Rolling Simulation with real 3D mesh rendering & physics
class AnimatedDiceRollOverlay extends StatefulWidget {
  final DiceRollResult result;
  final VoidCallback onDismiss;

  const AnimatedDiceRollOverlay({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  @override
  State<AnimatedDiceRollOverlay> createState() => _AnimatedDiceRollOverlayState();
}

class _AnimatedDiceRollOverlayState extends State<AnimatedDiceRollOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _physicsController;
  late final List<_Simulated3DDie> _diceList;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Initialize 3D physics state for each die in the roll
    _diceList = [];
    final totalDice = widget.result.groupResults
        .fold<int>(0, (acc, g) => acc + g.rolls.length)
        .clamp(1, 10);

    int count = 0;
    for (final group in widget.result.groupResults) {
      for (final val in group.rolls) {
        _diceList.add(_Simulated3DDie.create(
          dieType: group.entry.dieType,
          finalValue: val,
          index: count,
          totalCount: totalDice,
          rng: _rng,
        ));
        count++;
        if (count >= 10) break; // Display up to 10 simultaneous 3D tumbling dice
      }
      if (count >= 10) break;
    }

    _physicsController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() {});
        HapticService.heavyImpact(context);
      }
    });

    _physicsController.forward();
  }

  @override
  void dispose() {
    _physicsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>();
    final systemDisableAnimations = MediaQuery.disableAnimationsOf(context);
    final isSettled = _physicsController.isCompleted || systemDisableAnimations;
    final res = widget.result;

    final bannerLabel =
        'Dice Roll Result: ${res.total}. Formula: ${res.formulaString}.${res.isCrit ? " Natural 20 Critical Hit!" : ""}${res.isFumble ? " Natural 1 Critical Fumble!" : ""} Tap anywhere to return to table.';

    return Semantics(
      label: bannerLabel,
      button: true,
      onTap: widget.onDismiss,
      child: GestureDetector(
        onTap: widget.onDismiss,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Stack(
            children: [
              // 3D Polyhedral Tumbling Canvas (hidden if system animations disabled)
              if (!systemDisableAnimations)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _physicsController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _Polyhedral3DDicePainter(
                            dice: _diceList,
                            progress: _physicsController.value,
                            theme: theme,
                            tabletop: tabletop,
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Roll Result Banner (Springs up when dice come to rest)
              if (isSettled)
                Positioned(
                  bottom: 40,
                  left: 20,
                  right: 20,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: systemDisableAnimations ? 1.0 : 0.0, end: 1.0),
                    duration: systemDisableAnimations ? Duration.zero : const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    builder: (context, val, child) => Transform.scale(
                      scale: val,
                      child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
                    ),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: res.isCrit
                                ? (tabletop?.critGold ?? Colors.amber)
                                : (res.isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (res.isCrit
                                      ? (tabletop?.critGold ?? Colors.amber)
                                      : (res.isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary))
                                  .withValues(alpha: 0.4),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              res.formulaString,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${res.total}',
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                color: res.isCrit
                                    ? (tabletop?.critGold ?? Colors.amber)
                                    : (res.isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary),
                              ),
                            ),
                            if (res.isCrit) ...[
                              const SizedBox(height: 4),
                              const Text('🔥 NATURAL 20! CRITICAL HIT 🔥',
                                  style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w900, fontSize: 13)),
                            ],
                            if (res.isFumble) ...[
                              const SizedBox(height: 4),
                              const Text('💀 NATURAL 1! CRITICAL FUMBLE 💀',
                                  style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w900, fontSize: 13)),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              'Tap anywhere to return to table',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simulated 3D Die Entity
// ---------------------------------------------------------------------------

class _Simulated3DDie {
  final DieType dieType;
  final int finalValue;
  final PolyhedronMesh mesh;
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final double rotSpeedX;
  final double rotSpeedY;
  final double rotSpeedZ;
  final double bounceHeight;

  _Simulated3DDie({
    required this.dieType,
    required this.finalValue,
    required this.mesh,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.rotSpeedX,
    required this.rotSpeedY,
    required this.rotSpeedZ,
    required this.bounceHeight,
  });

  factory _Simulated3DDie.create({
    required DieType dieType,
    required int finalValue,
    required int index,
    required int totalCount,
    required Random rng,
  }) {
    final isSingle = totalCount == 1;
    final dieRadius = isSingle ? 74.0 : (totalCount <= 3 ? 58.0 : 46.0);

    PolyhedronMesh mesh;
    switch (dieType) {
      case DieType.d4:
        mesh = PolyhedronMesh.createD4(radius: dieRadius);
        break;
      case DieType.d6:
        mesh = PolyhedronMesh.createD6(radius: dieRadius);
        break;
      case DieType.d8:
        mesh = PolyhedronMesh.createD8(radius: dieRadius);
        break;
      case DieType.d10:
        mesh = PolyhedronMesh.createD10(radius: dieRadius);
        break;
      case DieType.d100:
        mesh = PolyhedronMesh.createD100(radius: isSingle ? 80.0 : (totalCount <= 3 ? 62.0 : 48.0));
        break;
      case DieType.d12:
        mesh = PolyhedronMesh.createD12(radius: dieRadius);
        break;
      case DieType.d20:
        mesh = PolyhedronMesh.createD20(radius: dieRadius);
        break;
      case DieType.custom:
        mesh = PolyhedronMesh.createSphere(radius: dieRadius);
        break;
    }

    // Precise centering based on total number of rolled dice
    double targetX;
    double targetY;

    if (totalCount == 1) {
      targetX = 0.50; // Screen dead center
      targetY = 0.40;
    } else if (totalCount == 2) {
      targetX = index == 0 ? 0.36 : 0.64;
      targetY = 0.40;
    } else {
      final cols = totalCount <= 4 ? 2 : 3;
      final row = index ~/ cols;
      final col = index % cols;
      final totalRows = (totalCount / cols).ceil();

      final colSpacing = 0.70 / cols;
      final rowSpacing = 0.32 / totalRows;

      targetX = 0.15 + (col + 0.5) * colSpacing;
      targetY = 0.24 + (row + 0.5) * rowSpacing;
    }

    // Launch trajectory entering with natural spin from top of screen
    final startX = targetX + (rng.nextDouble() - 0.5) * 0.35;
    final startY = -0.15 - (index * 0.05);

    return _Simulated3DDie(
      dieType: dieType,
      finalValue: finalValue,
      mesh: mesh,
      startX: startX,
      startY: startY,
      targetX: targetX,
      targetY: targetY,
      rotSpeedX: 5.0 + rng.nextDouble() * 5.0,
      rotSpeedY: 6.0 + rng.nextDouble() * 6.0,
      rotSpeedZ: 3.0 + rng.nextDouble() * 4.0,
      bounceHeight: 240.0 + rng.nextDouble() * 60.0,
    );
  }
}

// ---------------------------------------------------------------------------
// 3D Polyhedral Rasterizer Painter
// ---------------------------------------------------------------------------

class _Polyhedral3DDicePainter extends CustomPainter {
  final List<_Simulated3DDie> dice;
  final double progress;
  final ThemeData theme;
  final TabletopColors? tabletop;

  final Vec3 _lightDir = const Vec3(-0.5, -0.7, 1.0).normalized();
  final Paint _facetPaint = Paint()..style = PaintingStyle.fill;
  final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..isAntiAlias = true;

  _Polyhedral3DDicePainter({
    required this.dice,
    required this.progress,
    required this.theme,
    required this.tabletop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isSettled = progress >= 1.0;

    for (final die in dice) {
      // 1. Calculate trajectory position and bounce damping
      final currentX = (die.startX + (die.targetX - die.startX) * Curves.easeOutCubic.transform(progress)) * size.width;
      final linearY = (die.startY + (die.targetY - die.startY) * Curves.easeOutCubic.transform(progress)) * size.height;

      // Realistic multi-bounce dampening curve
      double bounceOffset = 0.0;
      if (!isSettled) {
        final bounce1 = sin(progress * pi * 3.5).abs() * die.bounceHeight * (1.0 - progress);
        bounceOffset = -bounce1;
      }
      final currentY = linearY + bounceOffset;

      // 2. Compute 3D rotation angles
      final angleX = isSettled ? 0.0 : (progress * die.rotSpeedX * 2 * pi);
      final angleY = isSettled ? 0.0 : (progress * die.rotSpeedY * 2 * pi);
      final angleZ = isSettled ? 0.0 : (progress * die.rotSpeedZ * 2 * pi);

      // 3. Shadow projection on the felt tray
      final shadowScale = (1.0 - (bounceOffset.abs() / (die.bounceHeight + 1.0))).clamp(0.3, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(currentX, linearY + 36),
          width: die.mesh.radius * 2.0 * shadowScale,
          height: die.mesh.radius * 0.9 * shadowScale,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45 * shadowScale),
      );

      // 4. Transform all 3D mesh vertices
      final transformedVertices = <Vec3>[];
      for (final v in die.mesh.vertices) {
        var tv = v.rotateX(angleX).rotateY(angleY).rotateZ(angleZ);
        transformedVertices.add(tv);
      }

      // 5. Compute outward face normals and filter visible front-facing facets
      final visibleFaces = <FaceRenderData>[];
      int winningFaceIndex = -1;
      double maxNormalZ = -999.0;

      for (int i = 0; i < die.mesh.faces.length; i++) {
        final face = die.mesh.faces[i];
        final v0 = transformedVertices[face.vertexIndices[0]];
        final v1 = transformedVertices[face.vertexIndices[1]];
        final v2 = transformedVertices[face.vertexIndices[2]];

        final centroid = face.vertexIndices
            .map((idx) => transformedVertices[idx])
            .reduce((a, b) => a + b) * (1.0 / face.vertexIndices.length);
        var normal = (v1 - v0).cross(v2 - v0).normalized();

        // Ensure normal vector points strictly OUTWARD from die center (0,0,0)
        if (normal.dot(centroid) < 0) {
          normal = -normal;
        }

        // Backface Culling: ONLY render facets facing the camera (normal.z > 0.02)
        if (normal.z > 0.02) {
          if (normal.z > maxNormalZ) {
            maxNormalZ = normal.z;
            winningFaceIndex = i;
          }

          final diffuse = (normal.dot(_lightDir)).clamp(0.20, 1.0);
          final path = Path();
          final screenPoints = <Offset>[];

          for (int vi = 0; vi < face.vertexIndices.length; vi++) {
            final tv = transformedVertices[face.vertexIndices[vi]];
            final px = currentX + tv.x * die.mesh.radius;
            final py = currentY + tv.y * die.mesh.radius;
            final pt = Offset(px, py);
            screenPoints.add(pt);
            if (vi == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          path.close();

          final centerPt = screenPoints.reduce((a, b) => a + b) / screenPoints.length.toDouble();

          visibleFaces.add(FaceRenderData(
            faceIndex: i,
            face: face,
            normal: normal,
            depth: centroid.z,
            path: path,
            centerPt: centerPt,
            diffuse: diffuse,
          ));
        }
      }

      // 6. Depth sort: Painter's algorithm (farthest depth drawn first, closest drawn last on top)
      visibleFaces.sort((a, b) => a.depth.compareTo(b.depth));

      final isCrit = die.dieType == DieType.d20 && die.finalValue == 20;
      final isFumble = die.dieType == DieType.d20 && die.finalValue == 1;

      final baseColor = isCrit
          ? (tabletop?.critGold ?? Colors.amber)
          : (isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary);

      final isSphere = die.dieType == DieType.d100 || die.dieType == DieType.custom;
      final totalFaces = die.mesh.faces.length;

      // 7. Render sorted 3D facets
      for (final faceData in visibleFaces) {
        final isWinningFace = (faceData.faceIndex == winningFaceIndex);
        final faceColor = Color.lerp(Colors.black, baseColor, faceData.diffuse * 0.9 + 0.1)!;

        // Draw shaded 3D facet
        _facetPaint.color = faceColor;
        canvas.drawPath(faceData.path, _facetPaint);

        // Draw beveled facet boundary edge (winning face receives elevated highlight)
        _edgePaint.color = isWinningFace && isSettled && !isSphere
            ? (isCrit ? Colors.amberAccent : Colors.white.withValues(alpha: 0.85))
            : Colors.white.withValues(alpha: isSphere ? 0.20 : (0.35 + (faceData.diffuse * 0.45)));
        _edgePaint.strokeWidth = (isWinningFace && isSettled && !isSphere) ? 2.4 : (isSphere ? 1.0 : 1.6);
        canvas.drawPath(faceData.path, _edgePaint);

        // Draw facet numbers:
        // When settled: EXCLUSIVELY the winning face displays the result number (sphere dice draw centered medallion below).
        // When rolling: Front-facing facets display numbers to convey rolling motion.
        final shouldDrawNumber = isSettled
            ? (isWinningFace && !isSphere)
            : (isWinningFace || faceData.normal.z > 0.50);

        if (shouldDrawNumber) {
          String faceDisplayText;
          if (isWinningFace) {
            faceDisplayText = '${die.finalValue}';
          } else {
            int num = faceData.face.faceNumber ?? (faceData.faceIndex + 1);
            if (num == die.finalValue) {
              num = (num % totalFaces) + 1;
              if (num == die.finalValue) num = (num % totalFaces) + 1;
            }
            faceDisplayText = '$num';
          }

          final textSpan = TextSpan(
            text: faceDisplayText,
            style: TextStyle(
              color: isWinningFace
                  ? (faceData.diffuse > 0.5 ? Colors.black : Colors.white)
                  : Colors.white60,
              fontSize: isWinningFace ? (die.mesh.radius * 0.44) : (die.mesh.radius * 0.28),
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: isWinningFace
                      ? (isCrit ? Colors.amberAccent : Colors.white.withValues(alpha: 0.8))
                      : Colors.black45,
                  blurRadius: isWinningFace ? 4 : 1,
                ),
              ],
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(
            canvas,
            faceData.centerPt - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
      }

      // 8. For Sphere Dice (d100 & custom) when settled, draw the centered target face medallion with the result number
      if (isSphere && isSettled) {
        final center = Offset(currentX, currentY);
        final discRadius = die.mesh.radius * 0.54;

        // Medallion background
        final discPaint = Paint()
          ..color = Color.lerp(Colors.black, baseColor, 0.45)!.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, discRadius, discPaint);

        // Medallion outer glowing ring
        final rimPaint = Paint()
          ..color = isCrit ? Colors.amberAccent : Colors.white.withValues(alpha: 0.90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        canvas.drawCircle(center, discRadius, rimPaint);

        // Inner accent ring
        final innerRimPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(center, discRadius * 0.85, innerRimPaint);

        // Result Number
        final textStr = '${die.finalValue}';
        final fontSize = textStr.length >= 3
            ? (die.mesh.radius * 0.40)
            : (textStr.length == 2 ? (die.mesh.radius * 0.50) : (die.mesh.radius * 0.60));

        final textSpan = TextSpan(
          text: textStr,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 4),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          center - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Polyhedral3DDicePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.dice != dice ||
        oldDelegate.theme != theme ||
        oldDelegate.tabletop != tabletop;
  }
}
