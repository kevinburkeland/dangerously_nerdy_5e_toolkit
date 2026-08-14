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
    final isSettled = _physicsController.isCompleted;
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
  _Vec3 operator -() => _Vec3(-x, -y, -z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

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

  _Vec3 rotateAxis(_Vec3 axis, double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    final dotR = dot(axis);
    final crossR = axis.cross(this);
    return this * cosR + crossR * sinR + axis * (dotR * (1.0 - cosR));
  }
}

class _Polygon3D {
  final List<int> vertexIndices;
  final int? faceNumber;

  const _Polygon3D(this.vertexIndices, {this.faceNumber});
}

class _FaceRenderData {
  final int faceIndex;
  final _Polygon3D face;
  final _Vec3 normal;
  final double depth;
  final Path path;
  final Offset centerPt;
  final double diffuse;

  _FaceRenderData({
    required this.faceIndex,
    required this.face,
    required this.normal,
    required this.depth,
    required this.path,
    required this.centerPt,
    required this.diffuse,
  });
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

  /// 3D Canonical Top-Down Regular Icosahedron (d20) Geometry
  /// Full 20-facet 3D solid with canonical C3 face-centered orientation.
  static _PolyhedronMesh createD20({double radius = 72.0}) {
    final r1 = sqrt(2.0 * (5.0 - sqrt(5.0)) / 15.0); // ~0.607062 (top face vertex radius)
    final z1 = sqrt((5.0 + 2.0 * sqrt(5.0)) / 15.0); // ~0.794654 (top face depth)
    final r2 = sqrt(2.0 * (5.0 + sqrt(5.0)) / 15.0); // ~0.982247 (mid-belt vertex radius)
    final z2 = sqrt((5.0 - 2.0 * sqrt(5.0)) / 15.0); // ~0.187592 (mid-belt depth)

    const deg90 = pi / 2.0;
    const deg210 = 7.0 * pi / 6.0;
    const deg330 = 11.0 * pi / 6.0;
    const deg30 = pi / 6.0;
    const deg150 = 5.0 * pi / 6.0;
    const deg270 = 3.0 * pi / 2.0;

    final vertices = [
      // Tier 1: Top Face Equilateral Triangle (Vertices 0, 1, 2)
      _Vec3(r1 * cos(deg90), r1 * sin(deg90), z1),   // 0: Top-Center
      _Vec3(r1 * cos(deg210), r1 * sin(deg210), z1), // 1: Bottom-Left
      _Vec3(r1 * cos(deg330), r1 * sin(deg330), z1), // 2: Bottom-Right

      // Tier 2: Upper-Middle Ring (Vertices 3, 4, 5)
      _Vec3(r2 * cos(deg330 + deg60(1)), r2 * sin(deg330 + deg60(1)), z2), // 3: Right
      _Vec3(r2 * cos(deg90 + deg60(1)), r2 * sin(deg90 + deg60(1)), z2),   // 4: Top-Left
      _Vec3(r2 * cos(deg210 + deg60(1)), r2 * sin(deg210 + deg60(1)), z2), // 5: Bottom

      // Tier 3: Lower-Middle Ring (Vertices 6, 7, 8)
      _Vec3(r2 * cos(deg90), r2 * sin(deg90), -z2),   // 6: Top
      _Vec3(r2 * cos(deg210), r2 * sin(deg210), -z2), // 7: Bottom-Left
      _Vec3(r2 * cos(deg330), r2 * sin(deg330), -z2), // 8: Bottom-Right

      // Tier 4: Bottom Face Equilateral Triangle (Vertices 9, 10, 11)
      _Vec3(r1 * cos(deg270), r1 * sin(deg270), -z1), // 9: Bottom
      _Vec3(r1 * cos(deg30), r1 * sin(deg30), -z1),   // 10: Top-Right
      _Vec3(r1 * cos(deg150), r1 * sin(deg150), -z1), // 11: Top-Left
    ];

    const faces = [
      // 1. PRIMARY TOP-DOWN FACE: Centered equilateral triangle facing viewer (Face 20)
      _Polygon3D([0, 1, 2], faceNumber: 20),

      // 2. Three closest adjacent faces directly connected to the top face
      _Polygon3D([0, 2, 3], faceNumber: 14), // Right slope
      _Polygon3D([0, 4, 1], faceNumber: 2),  // Left slope
      _Polygon3D([1, 5, 2], faceNumber: 8),  // Bottom slope

      // 3. Outer upper corner faces (rendered as shaded 3D facets without text crowding)
      _Polygon3D([0, 3, 4], faceNumber: 18),
      _Polygon3D([2, 5, 3], faceNumber: 6),
      _Polygon3D([1, 4, 5], faceNumber: 12),

      // 4. Middle belt triangles
      _Polygon3D([4, 6, 0], faceNumber: 10),
      _Polygon3D([3, 8, 2], faceNumber: 16),
      _Polygon3D([5, 7, 1], faceNumber: 4),

      _Polygon3D([4, 3, 6], faceNumber: 15),
      _Polygon3D([3, 5, 8], faceNumber: 7),
      _Polygon3D([5, 4, 7], faceNumber: 11),

      _Polygon3D([6, 8, 3], faceNumber: 19),
      _Polygon3D([8, 7, 5], faceNumber: 3),
      _Polygon3D([7, 6, 4], faceNumber: 17),

      // 5. Lower adjacent faces
      _Polygon3D([6, 10, 8], faceNumber: 9),
      _Polygon3D([8, 9, 7], faceNumber: 13),
      _Polygon3D([7, 11, 6], faceNumber: 5),

      // 6. Bottom Face
      _Polygon3D([9, 10, 11], faceNumber: 1),
    ];

    return _PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  static double deg60(int count) => count * pi / 3.0;

  /// 3D Tetrahedron (d4) Geometry (Canonical 3-facet apex top-down view)
  static _PolyhedronMesh createD4({double radius = 64.0}) {
    const h = 0.8165; // sqrt(2/3)
    const r = 0.8660; // sqrt(3)/2
    final vertices = [
      const _Vec3(0, 0, 1.0), // 0: Top Apex
      const _Vec3(0, r, -h / 2),    // 1: Top-Center
      _Vec3(-r * sqrt(3) / 2, -r / 2, -h / 2), // 2: Bottom-Left
      _Vec3(r * sqrt(3) / 2, -r / 2, -h / 2),  // 3: Bottom-Right
    ];

    const faces = [
      _Polygon3D([0, 1, 3], faceNumber: 4),
      _Polygon3D([0, 2, 1], faceNumber: 2),
      _Polygon3D([0, 3, 2], faceNumber: 3),
      _Polygon3D([1, 2, 3], faceNumber: 1), // Base
    ];

    return _PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Cube (d6) Geometry (Canonical top-down square face)
  static _PolyhedronMesh createD6({double radius = 56.0}) {
    const s = 0.57735; // 1 / sqrt(3)
    final vertices = [
      const _Vec3(-s, -s, -s), const _Vec3(s, -s, -s), const _Vec3(s, s, -s), const _Vec3(-s, s, -s),
      const _Vec3(-s, -s, s), const _Vec3(s, -s, s), const _Vec3(s, s, s), const _Vec3(-s, s, s),
    ];

    const faces = [
      _Polygon3D([4, 5, 6, 7], faceNumber: 6), // Top Face
      _Polygon3D([1, 0, 3, 2], faceNumber: 1), // Bottom Face
      _Polygon3D([0, 4, 7, 3], faceNumber: 2), // Left Face
      _Polygon3D([5, 1, 2, 6], faceNumber: 5), // Right Face
      _Polygon3D([7, 6, 2, 3], faceNumber: 3), // Upper Face
      _Polygon3D([0, 1, 5, 4], faceNumber: 4), // Lower Face
    ];

    return _PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Regular Octahedron (d8) Geometry (Canonical top-down face)
  static _PolyhedronMesh createD8({double radius = 62.0}) {
    final r1 = sqrt(2.0 / 3.0);
    final z1 = 1.0 / sqrt(3.0);
    final vertices = [
      _Vec3(0, r1, z1),
      _Vec3(-r1 * sqrt(3) / 2, -r1 / 2, z1),
      _Vec3(r1 * sqrt(3) / 2, -r1 / 2, z1),
      _Vec3(0, -r1, -z1),
      _Vec3(r1 * sqrt(3) / 2, r1 / 2, -z1),
      _Vec3(-r1 * sqrt(3) / 2, r1 / 2, -z1),
    ];

    const faces = [
      _Polygon3D([0, 1, 2], faceNumber: 8), // Top center face
      _Polygon3D([0, 2, 4], faceNumber: 6), // Right slope
      _Polygon3D([0, 5, 1], faceNumber: 4), // Left slope
      _Polygon3D([1, 3, 2], faceNumber: 2), // Bottom slope
    ];

    return _PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Iconic Pentagonal Trapezohedron (d10 & d100) Geometry
  static _PolyhedronMesh createD10({double radius = 70.0, bool isD100 = false}) {
    const zFront = 0.40;
    const zBack = -0.45;
    const zApex = -0.60;

    final vertices = [
      // Primary Face 0: Front-facing flat kite (Vertices 0, 1, 2, 3)
      const _Vec3(0.0, 0.90, zFront),   // 0: Top corner of front kite
      const _Vec3(0.68, 0.12, zFront),  // 1: Right corner of front kite
      const _Vec3(0.0, -0.68, zFront),  // 2: Bottom corner of front kite
      const _Vec3(-0.68, 0.12, zFront), // 3: Left corner of front kite

      // Outer belt vertices (sloping away to back)
      const _Vec3(0.78, 0.65, zBack),   // 4: Upper-right outer
      const _Vec3(0.82, -0.42, zBack),  // 5: Lower-right outer
      const _Vec3(-0.82, -0.42, zBack), // 6: Lower-left outer
      const _Vec3(-0.78, 0.65, zBack),  // 7: Upper-left outer

      // Top and Bottom Back Apexes
      const _Vec3(0.0, 1.05, zApex),    // 8: Top polar apex
      const _Vec3(0.0, -0.98, zApex),   // 9: Bottom polar apex
      const _Vec3(0.0, 0.0, -0.85),     // 10: Rear center
    ];

    final faces = [
      // 1. PRIMARY TOP-DOWN FACE: Centered kite facing viewer (Face 0)
      _Polygon3D(const [0, 1, 2, 3], faceNumber: isD100 ? 0 : 10),

      // 2. Front-visible sloping side facets
      _Polygon3D(const [0, 8, 4, 1], faceNumber: isD100 ? 20 : 2),
      _Polygon3D(const [1, 4, 5, 2], faceNumber: isD100 ? 40 : 4),
      _Polygon3D(const [2, 5, 9, 6], faceNumber: isD100 ? 60 : 6),
      _Polygon3D(const [3, 2, 6, 7], faceNumber: isD100 ? 80 : 8),
      _Polygon3D(const [0, 3, 7, 8], faceNumber: isD100 ? 10 : 1),

      // 3. Rear facets
      _Polygon3D(const [8, 7, 10, 4], faceNumber: isD100 ? 30 : 3),
      _Polygon3D(const [4, 10, 5], faceNumber: isD100 ? 50 : 5),
      _Polygon3D(const [9, 5, 10, 6], faceNumber: isD100 ? 70 : 7),
      _Polygon3D(const [7, 6, 10], faceNumber: isD100 ? 90 : 9),
    ];

    return _PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Mathematically Exact Regular Dodecahedron (d12) Geometry
  static _PolyhedronMesh createD12({double radius = 68.0}) {
    final phi = (1.0 + sqrt(5.0)) / 2.0; // Golden ratio ~1.6180339887
    final invPhi = 1.0 / phi;

    // 20 vertices of regular dodecahedron: (±1, ±1, ±1), (0, ±1/phi, ±phi), (±1/phi, ±phi, 0), (±phi, 0, ±1/phi) normalized
    final scale = 1.0 / sqrt(3.0);
    final rawVertices = <_Vec3>[
      // 8 cube vertices (indices 0..7)
      _Vec3(-scale, -scale, -scale), _Vec3(scale, -scale, -scale),
      _Vec3(-scale, scale, -scale), _Vec3(scale, scale, -scale),
      _Vec3(-scale, -scale, scale), _Vec3(scale, -scale, scale),
      _Vec3(-scale, scale, scale), _Vec3(scale, scale, scale),

      // 4 vertices in YZ plane (indices 8..11)
      _Vec3(0, -invPhi * scale, -phi * scale), _Vec3(0, invPhi * scale, -phi * scale),
      _Vec3(0, -invPhi * scale, phi * scale), _Vec3(0, invPhi * scale, phi * scale),

      // 4 vertices in XY plane (indices 12..15)
      _Vec3(-invPhi * scale, -phi * scale, 0), _Vec3(invPhi * scale, -phi * scale, 0),
      _Vec3(-invPhi * scale, phi * scale, 0), _Vec3(invPhi * scale, phi * scale, 0),

      // 4 vertices in XZ plane (indices 16..19)
      _Vec3(-phi * scale, 0, -invPhi * scale), _Vec3(phi * scale, 0, -invPhi * scale),
      _Vec3(-phi * scale, 0, invPhi * scale), _Vec3(phi * scale, 0, invPhi * scale),
    ];

    const rawFaces = [
      _Polygon3D([11, 10, 4, 18, 6], faceNumber: 12),
      _Polygon3D([10, 11, 7, 19, 5], faceNumber: 9),
      _Polygon3D([11, 6, 14, 2, 9], faceNumber: 3),
      _Polygon3D([10, 5, 13, 0, 8], faceNumber: 7),
      _Polygon3D([4, 10, 8, 12, 18], faceNumber: 2),
      _Polygon3D([7, 11, 9, 15, 19], faceNumber: 6),
      _Polygon3D([6, 18, 16, 14, 2], faceNumber: 4),
      _Polygon3D([5, 19, 17, 13, 0], faceNumber: 10),
      _Polygon3D([2, 14, 15, 3, 9], faceNumber: 5),
      _Polygon3D([0, 13, 12, 1, 8], faceNumber: 11),
      _Polygon3D([18, 12, 1, 16, 4], faceNumber: 8),
      _Polygon3D([19, 15, 3, 17, 7], faceNumber: 1),
    ];

    // Compute normal of Face 0 and rotate entire dodecahedron so Face 0 is flat facing +Z
    final v0 = rawVertices[rawFaces[0].vertexIndices[0]];
    final v1 = rawVertices[rawFaces[0].vertexIndices[1]];
    final v2 = rawVertices[rawFaces[0].vertexIndices[2]];
    final c0 = rawFaces[0].vertexIndices.map((i) => rawVertices[i]).reduce((a, b) => a + b) * 0.2;

    var n0 = (v1 - v0).cross(v2 - v0).normalized();
    if (n0.dot(c0) < 0) n0 = -n0;

    final rotAxis = n0.cross(const _Vec3(0, 0, 1)).normalized();
    final rotAngle = acos(n0.z.clamp(-1.0, 1.0));

    var rotated = rawVertices.map((v) => v.rotateAxis(rotAxis, rotAngle)).toList();

    // Align top edge horizontally
    final p0 = rotated[rawFaces[0].vertexIndices[0]];
    final p1 = rotated[rawFaces[0].vertexIndices[1]];
    final edgeAngle = atan2(p1.y - p0.y, p1.x - p0.x);
    rotated = rotated.map((v) => v.rotateZ(-edgeAngle)).toList();

    return _PolyhedronMesh(vertices: rotated, faces: rawFaces, radius: radius);
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
    required int totalCount,
    required Random rng,
  }) {
    final isSingle = totalCount == 1;
    final dieRadius = isSingle ? 74.0 : (totalCount <= 3 ? 58.0 : 46.0);

    _PolyhedronMesh mesh;
    switch (dieType) {
      case DieType.d4:
        mesh = _PolyhedronMesh.createD4(radius: dieRadius);
        break;
      case DieType.d6:
        mesh = _PolyhedronMesh.createD6(radius: dieRadius);
        break;
      case DieType.d8:
        mesh = _PolyhedronMesh.createD8(radius: dieRadius);
        break;
      case DieType.d10:
        mesh = _PolyhedronMesh.createD10(radius: dieRadius, isD100: false);
        break;
      case DieType.d100:
        mesh = _PolyhedronMesh.createD10(radius: dieRadius, isD100: true);
        break;
      case DieType.d12:
        mesh = _PolyhedronMesh.createD12(radius: dieRadius);
        break;
      case DieType.d20:
      case DieType.custom:
        mesh = _PolyhedronMesh.createD20(radius: dieRadius);
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

      // 5. Compute outward face normals and filter visible front-facing facets
      final visibleFaces = <_FaceRenderData>[];
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

          visibleFaces.add(_FaceRenderData(
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

      final totalFaces = die.mesh.faces.length;

      // 7. Render sorted 3D facets
      for (final faceData in visibleFaces) {
        final isWinningFace = (faceData.faceIndex == winningFaceIndex);
        final faceColor = Color.lerp(Colors.black, baseColor, faceData.diffuse * 0.9 + 0.1)!;

        // Draw shaded 3D facet
        _facetPaint.color = faceColor;
        canvas.drawPath(faceData.path, _facetPaint);

        // Draw beveled facet boundary edge (winning face receives elevated highlight)
        _edgePaint.color = isWinningFace && isSettled
            ? (isCrit ? Colors.amberAccent : Colors.white.withValues(alpha: 0.85))
            : Colors.white.withValues(alpha: 0.35 + (faceData.diffuse * 0.45));
        _edgePaint.strokeWidth = (isWinningFace && isSettled) ? 2.4 : 1.6;
        canvas.drawPath(faceData.path, _edgePaint);

        // Draw facet numbers:
        // When settled: EXCLUSIVELY the winning face displays the result number.
        // When rolling: Front-facing facets display numbers to convey rolling motion.
        final shouldDrawNumber = isSettled
            ? isWinningFace
            : (isWinningFace || faceData.normal.z > 0.50);

        if (shouldDrawNumber) {
          String faceDisplayText;
          if (isWinningFace) {
            if (die.dieType == DieType.d100) {
              final val = die.finalValue == 100 ? 0 : die.finalValue;
              faceDisplayText = val.toString().padLeft(2, '0');
            } else {
              faceDisplayText = '${die.finalValue}';
            }
          } else {
            int num = faceData.face.faceNumber ?? (faceData.faceIndex + 1);
            if (num == die.finalValue) {
              num = (num % totalFaces) + 1;
              if (num == die.finalValue) num = (num % totalFaces) + 1;
            }
            if (die.dieType == DieType.d100) {
              faceDisplayText = (num * 10 % 100).toString().padLeft(2, '0');
            } else {
              faceDisplayText = '$num';
            }
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
    }
  }

  @override
  bool shouldRepaint(covariant _Polyhedral3DDicePainter oldDelegate) => true;
}
