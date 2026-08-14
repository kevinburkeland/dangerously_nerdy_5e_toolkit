import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/dice_roll.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

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
    int count = 0;
    for (final group in widget.result.groupResults) {
      for (final val in group.rolls) {
        _diceList.add(_Simulated3DDie.create(
          dieType: group.entry.dieType,
          finalValue: val,
          index: count,
          rng: _rng,
        ));
        count++;
        if (count >= 10) break; // Display up to 10 simultaneous 3D tumbling dice
      }
      if (count >= 10) break;
    }

    _physicsController.addListener(() {
      if (mounted) setState(() {});
    });

    _physicsController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
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
    final isSettled = _physicsController.isCompleted;
    final progress = _physicsController.value;
    final res = widget.result;

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Stack(
          children: [
            // 3D Polyhedral Tumbling Canvas
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _Polyhedral3DDicePainter(
                    dice: _diceList,
                    progress: progress,
                    theme: theme,
                    tabletop: tabletop,
                  ),
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
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 260),
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
    );
  }
}

// ---------------------------------------------------------------------------
// 3D Vector & Mesh Data Structures
// ---------------------------------------------------------------------------

class _Vec3 {
  final double x, y, z;
  const _Vec3(this.x, this.y, this.z);

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;

  _Vec3 cross(_Vec3 o) => _Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  _Vec3 normalized() {
    final len = sqrt(x * x + y * y + z * z);
    return len > 0 ? _Vec3(x / len, y / len, z / len) : const _Vec3(0, 0, 1);
  }

  _Vec3 rotateX(double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    return _Vec3(x, y * cosR - z * sinR, y * sinR + z * cosR);
  }

  _Vec3 rotateY(double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    return _Vec3(x * cosR + z * sinR, y, -x * sinR + z * cosR);
  }

  _Vec3 rotateZ(double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    return _Vec3(x * cosR - y * sinR, x * sinR + y * cosR, z);
  }
}

class _Polygon3D {
  final List<int> vertexIndices;
  final int? faceNumber;

  const _Polygon3D(this.vertexIndices, {this.faceNumber});
}

class _PolyhedronMesh {
  final List<_Vec3> vertices;
  final List<_Polygon3D> faces;
  final double radius;

  const _PolyhedronMesh({
    required this.vertices,
    required this.faces,
    required this.radius,
  });

  /// 3D Regular Icosahedron (d20) Geometry with 20 triangular facets
  static _PolyhedronMesh createD20() {
    final phi = (1.0 + sqrt(5.0)) / 2.0; // Golden ratio
    final rawVertices = [
      _Vec3(-1, phi, 0), _Vec3(1, phi, 0), _Vec3(-1, -phi, 0), _Vec3(1, -phi, 0),
      _Vec3(0, -1, phi), _Vec3(0, 1, phi), _Vec3(0, -1, -phi), _Vec3(0, 1, -phi),
      _Vec3(phi, 0, -1), _Vec3(phi, 0, 1), _Vec3(-phi, 0, -1), _Vec3(-phi, 0, 1),
    ].map((v) => v.normalized()).toList();

    const faces = [
      _Polygon3D([0, 11, 5], faceNumber: 20),
      _Polygon3D([0, 5, 1], faceNumber: 14),
      _Polygon3D([0, 1, 7], faceNumber: 6),
      _Polygon3D([0, 7, 10], faceNumber: 18),
      _Polygon3D([0, 10, 11], faceNumber: 4),
      _Polygon3D([1, 5, 9], faceNumber: 8),
      _Polygon3D([5, 11, 4], faceNumber: 16),
      _Polygon3D([11, 10, 2], faceNumber: 12),
      _Polygon3D([10, 7, 6], faceNumber: 10),
      _Polygon3D([7, 1, 8], faceNumber: 2),
      _Polygon3D([3, 9, 4], faceNumber: 19),
      _Polygon3D([3, 4, 2], faceNumber: 3),
      _Polygon3D([3, 2, 6], faceNumber: 17),
      _Polygon3D([3, 6, 8], faceNumber: 7),
      _Polygon3D([3, 8, 9], faceNumber: 15),
      _Polygon3D([4, 9, 5], faceNumber: 1),
      _Polygon3D([2, 4, 11], faceNumber: 9),
      _Polygon3D([6, 2, 10], faceNumber: 5),
      _Polygon3D([8, 6, 7], faceNumber: 13),
      _Polygon3D([9, 8, 1], faceNumber: 11),
    ];

    return _PolyhedronMesh(vertices: rawVertices, faces: faces, radius: 48.0);
  }

  /// 3D Cube (d6) Geometry
  static _PolyhedronMesh createD6() {
    const s = 1.0;
    final vertices = [
      const _Vec3(-s, -s, -s), const _Vec3(s, -s, -s), const _Vec3(s, s, -s), const _Vec3(-s, s, -s),
      const _Vec3(-s, -s, s), const _Vec3(s, -s, s), const _Vec3(s, s, s), const _Vec3(-s, s, s),
    ].map((v) => v.normalized()).toList();

    const faces = [
      _Polygon3D([4, 5, 6, 7], faceNumber: 6), // Front
      _Polygon3D([1, 0, 3, 2], faceNumber: 1), // Back
      _Polygon3D([0, 4, 7, 3], faceNumber: 2), // Left
      _Polygon3D([5, 1, 2, 6], faceNumber: 5), // Right
      _Polygon3D([7, 6, 2, 3], faceNumber: 3), // Top
      _Polygon3D([0, 1, 5, 4], faceNumber: 4), // Bottom
    ];

    return _PolyhedronMesh(vertices: vertices, faces: faces, radius: 44.0);
  }

  /// 3D Regular Octahedron (d8) Geometry
  static _PolyhedronMesh createD8() {
    final vertices = [
      const _Vec3(1, 0, 0), const _Vec3(-1, 0, 0), const _Vec3(0, 1, 0),
      const _Vec3(0, -1, 0), const _Vec3(0, 0, 1), const _Vec3(0, 0, -1),
    ];

    const faces = [
      _Polygon3D([4, 0, 2], faceNumber: 8),
      _Polygon3D([4, 2, 1], faceNumber: 6),
      _Polygon3D([4, 1, 3], faceNumber: 4),
      _Polygon3D([4, 3, 0], faceNumber: 2),
      _Polygon3D([5, 2, 0], faceNumber: 7),
      _Polygon3D([5, 1, 2], faceNumber: 5),
      _Polygon3D([5, 3, 1], faceNumber: 3),
      _Polygon3D([5, 0, 3], faceNumber: 1),
    ];

    return _PolyhedronMesh(vertices: vertices, faces: faces, radius: 46.0);
  }
}

// ---------------------------------------------------------------------------
// Simulated 3D Die Entity
// ---------------------------------------------------------------------------

class _Simulated3DDie {
  final DieType dieType;
  final int finalValue;
  final _PolyhedronMesh mesh;
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
    required Random rng,
  }) {
    _PolyhedronMesh mesh;
    switch (dieType) {
      case DieType.d6:
        mesh = _PolyhedronMesh.createD6();
        break;
      case DieType.d8:
        mesh = _PolyhedronMesh.createD8();
        break;
      case DieType.d20:
      default:
        mesh = _PolyhedronMesh.createD20();
        break;
    }

    final startX = 0.2 + rng.nextDouble() * 0.6;
    final startY = -0.15 - (index * 0.08);
    final targetX = 0.3 + ((index % 3) * 0.2) + (rng.nextDouble() - 0.5) * 0.08;
    final targetY = 0.38 + ((index ~/ 3) * 0.16) + (rng.nextDouble() - 0.5) * 0.06;

    return _Simulated3DDie(
      dieType: dieType,
      finalValue: finalValue,
      mesh: mesh,
      startX: startX,
      startY: startY,
      targetX: targetX,
      targetY: targetY,
      rotSpeedX: 5.0 + rng.nextDouble() * 7.0,
      rotSpeedY: 6.0 + rng.nextDouble() * 8.0,
      rotSpeedZ: 3.0 + rng.nextDouble() * 5.0,
      bounceHeight: 220.0 + rng.nextDouble() * 80.0,
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

  final _Vec3 _lightDir = const _Vec3(-0.5, -0.7, 1.0).normalized();
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
      final transformedVertices = <_Vec3>[];
      for (final v in die.mesh.vertices) {
        var tv = v.rotateX(angleX).rotateY(angleY).rotateZ(angleZ);
        transformedVertices.add(tv);
      }

      // 5. Compute face normals and determine the single primary front-facing winning face
      int winningFaceIndex = -1;
      double maxNormalZ = -999.0;
      final faceNormals = <_Vec3>[];

      for (int i = 0; i < die.mesh.faces.length; i++) {
        final face = die.mesh.faces[i];
        final v0 = transformedVertices[face.vertexIndices[0]];
        final v1 = transformedVertices[face.vertexIndices[1]];
        final v2 = transformedVertices[face.vertexIndices[2]];

        final normal = (v1 - v0).cross(v2 - v0).normalized();
        faceNormals.add(normal);

        if (normal.z > maxNormalZ) {
          maxNormalZ = normal.z;
          winningFaceIndex = i;
        }
      }

      final isCrit = die.dieType == DieType.d20 && die.finalValue == 20;
      final isFumble = die.dieType == DieType.d20 && die.finalValue == 1;

      final baseColor = isCrit
          ? (tabletop?.critGold ?? Colors.amber)
          : (isFumble ? (tabletop?.fumbleRed ?? Colors.red) : theme.colorScheme.primary);

      final totalFaces = die.mesh.faces.length;

      // 6. Render visible 3D facets with backface culling
      for (int f = 0; f < die.mesh.faces.length; f++) {
        final face = die.mesh.faces[f];
        final normal = faceNormals[f];

        // Backface culling: camera looks down Z+ (normal.z > 0 faces camera)
        if (normal.z > 0.05) {
          final isWinningFace = (f == winningFaceIndex);

          // Diffuse lighting intensity: N . L
          final diffuse = (normal.dot(_lightDir)).clamp(0.18, 1.0);
          final faceColor = Color.lerp(Colors.black, baseColor, diffuse * 0.9 + 0.1)!;

          final path = Path();
          final screenPoints = <Offset>[];
          for (int i = 0; i < face.vertexIndices.length; i++) {
            final tv = transformedVertices[face.vertexIndices[i]];
            final px = currentX + tv.x * die.mesh.radius;
            final py = currentY + tv.y * die.mesh.radius;
            final pt = Offset(px, py);
            screenPoints.add(pt);
            if (i == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          path.close();

          // Draw shaded 3D facet
          _facetPaint.color = faceColor;
          canvas.drawPath(path, _facetPaint);

          // Draw beveled facet boundary edge
          _edgePaint.color = Colors.white.withValues(alpha: 0.35 + (diffuse * 0.45));
          canvas.drawPath(path, _edgePaint);

          // Draw facet numbers: EXACTLY ONE FACE (the winning face) shows die.finalValue
          if (normal.z > 0.32) {
            final centerPt = screenPoints.reduce((a, b) => a + b) / screenPoints.length.toDouble();

            int faceDisplayVal;
            if (isWinningFace) {
              faceDisplayVal = die.finalValue;
            } else {
              int num = face.faceNumber ?? (f + 1);
              if (num == die.finalValue) {
                num = (num % totalFaces) + 1;
                if (num == die.finalValue) num = (num % totalFaces) + 1;
              }
              faceDisplayVal = num;
            }

            final textSpan = TextSpan(
              text: '$faceDisplayVal',
              style: TextStyle(
                color: diffuse > 0.5 ? Colors.black : Colors.white70,
                fontSize: isWinningFace ? (die.mesh.radius * 0.40) : (die.mesh.radius * 0.32),
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 2),
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
              centerPt - Offset(textPainter.width / 2, textPainter.height / 2),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Polyhedral3DDicePainter oldDelegate) => true;
}
