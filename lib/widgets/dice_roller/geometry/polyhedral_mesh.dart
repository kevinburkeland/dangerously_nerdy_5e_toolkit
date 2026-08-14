import 'dart:math';
import 'dice_vector_math.dart';

/// 3D Polyhedral solid geometry generator for standard RPG dice (d4, d6, d8, d10, d12, d20, d100).
class PolyhedronMesh {
  final List<Vec3> vertices;
  final List<Polygon3D> faces;
  final double radius;

  const PolyhedronMesh({
    required this.vertices,
    required this.faces,
    required this.radius,
  });

  static double deg60(int count) => count * pi / 3.0;

  /// 3D Tetrahedron (d4) Geometry (Canonical 3-facet apex top-down view)
  static PolyhedronMesh createD4({double radius = 64.0}) {
    const h = 0.8165; // sqrt(2/3)
    const r = 0.8660; // sqrt(3)/2
    final vertices = [
      const Vec3(0, 0, 1.0), // 0: Top Apex
      const Vec3(0, r, -h / 2),    // 1: Top-Center
      Vec3(-r * sqrt(3) / 2, -r / 2, -h / 2), // 2: Bottom-Left
      Vec3(r * sqrt(3) / 2, -r / 2, -h / 2),  // 3: Bottom-Right
    ];

    const faces = [
      Polygon3D([0, 1, 3], faceNumber: 4),
      Polygon3D([0, 2, 1], faceNumber: 2),
      Polygon3D([0, 3, 2], faceNumber: 3),
      Polygon3D([1, 2, 3], faceNumber: 1), // Base
    ];

    return PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Cube (d6) Geometry (Canonical top-down square face)
  static PolyhedronMesh createD6({double radius = 56.0}) {
    const s = 0.57735; // 1 / sqrt(3)
    final vertices = [
      const Vec3(-s, -s, -s), const Vec3(s, -s, -s), const Vec3(s, s, -s), const Vec3(-s, s, -s),
      const Vec3(-s, -s, s), const Vec3(s, -s, s), const Vec3(s, s, s), const Vec3(-s, s, s),
    ];

    const faces = [
      Polygon3D([4, 5, 6, 7], faceNumber: 6), // Top Face
      Polygon3D([1, 0, 3, 2], faceNumber: 1), // Bottom Face
      Polygon3D([0, 4, 7, 3], faceNumber: 2), // Left Face
      Polygon3D([5, 1, 2, 6], faceNumber: 5), // Right Face
      Polygon3D([7, 6, 2, 3], faceNumber: 3), // Upper Face
      Polygon3D([0, 1, 5, 4], faceNumber: 4), // Lower Face
    ];

    return PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Regular Octahedron (d8) Geometry (Canonical top-down face)
  static PolyhedronMesh createD8({double radius = 62.0}) {
    final r1 = sqrt(2.0 / 3.0);
    final z1 = 1.0 / sqrt(3.0);
    final vertices = [
      Vec3(0, r1, z1),
      Vec3(-r1 * sqrt(3) / 2, -r1 / 2, z1),
      Vec3(r1 * sqrt(3) / 2, -r1 / 2, z1),
      Vec3(0, -r1, -z1),
      Vec3(r1 * sqrt(3) / 2, r1 / 2, -z1),
      Vec3(-r1 * sqrt(3) / 2, r1 / 2, -z1),
    ];

    const faces = [
      Polygon3D([0, 1, 2], faceNumber: 8), // Top center face
      Polygon3D([0, 2, 4], faceNumber: 6), // Right slope
      Polygon3D([0, 5, 1], faceNumber: 4), // Left slope
      Polygon3D([1, 3, 2], faceNumber: 2), // Bottom slope
    ];

    return PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Iconic Pentagonal Trapezohedron (d10 & d100) Geometry
  static PolyhedronMesh createD10({double radius = 70.0, bool isD100 = false}) {
    const zFront = 0.40;
    const zBack = -0.45;
    const zApex = -0.60;

    final vertices = [
      // Primary Face 0: Front-facing flat kite (Vertices 0, 1, 2, 3)
      const Vec3(0.0, 0.90, zFront),   // 0: Top corner of front kite
      const Vec3(0.68, 0.12, zFront),  // 1: Right corner of front kite
      const Vec3(0.0, -0.68, zFront),  // 2: Bottom corner of front kite
      const Vec3(-0.68, 0.12, zFront), // 3: Left corner of front kite

      // Outer belt vertices (sloping away to back)
      const Vec3(0.78, 0.65, zBack),   // 4: Upper-right outer
      const Vec3(0.82, -0.42, zBack),  // 5: Lower-right outer
      const Vec3(-0.82, -0.42, zBack), // 6: Lower-left outer
      const Vec3(-0.78, 0.65, zBack),  // 7: Upper-left outer

      // Top and Bottom Back Apexes
      const Vec3(0.0, 1.05, zApex),    // 8: Top polar apex
      const Vec3(0.0, -0.98, zApex),   // 9: Bottom polar apex
      const Vec3(0.0, 0.0, -0.85),     // 10: Rear center
    ];

    final faces = [
      // 1. PRIMARY TOP-DOWN FACE: Centered kite facing viewer (Face 0)
      Polygon3D(const [0, 1, 2, 3], faceNumber: isD100 ? 0 : 10),

      // 2. Front-visible sloping side facets
      Polygon3D(const [0, 8, 4, 1], faceNumber: isD100 ? 20 : 2),
      Polygon3D(const [1, 4, 5, 2], faceNumber: isD100 ? 40 : 4),
      Polygon3D(const [2, 5, 9, 6], faceNumber: isD100 ? 60 : 6),
      Polygon3D(const [3, 2, 6, 7], faceNumber: isD100 ? 80 : 8),
      Polygon3D(const [0, 3, 7, 8], faceNumber: isD100 ? 10 : 1),

      // 3. Rear facets
      Polygon3D(const [8, 7, 10, 4], faceNumber: isD100 ? 30 : 3),
      Polygon3D(const [4, 10, 5], faceNumber: isD100 ? 50 : 5),
      Polygon3D(const [9, 5, 10, 6], faceNumber: isD100 ? 70 : 7),
      Polygon3D(const [7, 6, 10], faceNumber: isD100 ? 90 : 9),
    ];

    return PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }

  /// 3D Mathematically Exact Regular Dodecahedron (d12) Geometry
  static PolyhedronMesh createD12({double radius = 68.0}) {
    final phi = (1.0 + sqrt(5.0)) / 2.0; // Golden ratio ~1.6180339887
    final invPhi = 1.0 / phi;

    // 20 vertices of regular dodecahedron: (±1, ±1, ±1), (0, ±1/phi, ±phi), (±1/phi, ±phi, 0), (±phi, 0, ±1/phi) normalized
    final scale = 1.0 / sqrt(3.0);
    final rawVertices = <Vec3>[
      // 8 cube vertices (indices 0..7)
      Vec3(-scale, -scale, -scale), Vec3(scale, -scale, -scale),
      Vec3(-scale, scale, -scale), Vec3(scale, scale, -scale),
      Vec3(-scale, -scale, scale), Vec3(scale, -scale, scale),
      Vec3(-scale, scale, scale), Vec3(scale, scale, scale),

      // 4 vertices in YZ plane (indices 8..11)
      Vec3(0, -invPhi * scale, -phi * scale), Vec3(0, invPhi * scale, -phi * scale),
      Vec3(0, -invPhi * scale, phi * scale), Vec3(0, invPhi * scale, phi * scale),

      // 4 vertices in XY plane (indices 12..15)
      Vec3(-invPhi * scale, -phi * scale, 0), Vec3(invPhi * scale, -phi * scale, 0),
      Vec3(-invPhi * scale, phi * scale, 0), Vec3(invPhi * scale, phi * scale, 0),

      // 4 vertices in XZ plane (indices 16..19)
      Vec3(-phi * scale, 0, -invPhi * scale), Vec3(phi * scale, 0, -invPhi * scale),
      Vec3(-phi * scale, 0, invPhi * scale), Vec3(phi * scale, 0, invPhi * scale),
    ];

    const rawFaces = [
      Polygon3D([11, 10, 4, 18, 6], faceNumber: 12),
      Polygon3D([10, 11, 7, 19, 5], faceNumber: 9),
      Polygon3D([11, 6, 14, 2, 9], faceNumber: 3),
      Polygon3D([10, 5, 13, 0, 8], faceNumber: 7),
      Polygon3D([4, 10, 8, 12, 18], faceNumber: 2),
      Polygon3D([7, 11, 9, 15, 19], faceNumber: 6),
      Polygon3D([6, 18, 16, 14, 2], faceNumber: 4),
      Polygon3D([5, 19, 17, 13, 0], faceNumber: 10),
      Polygon3D([2, 14, 15, 3, 9], faceNumber: 5),
      Polygon3D([0, 13, 12, 1, 8], faceNumber: 11),
      Polygon3D([18, 12, 1, 16, 4], faceNumber: 8),
      Polygon3D([19, 15, 3, 17, 7], faceNumber: 1),
    ];

    // Compute normal of Face 0 and rotate entire dodecahedron so Face 0 is flat facing +Z
    final v0 = rawVertices[rawFaces[0].vertexIndices[0]];
    final v1 = rawVertices[rawFaces[0].vertexIndices[1]];
    final v2 = rawVertices[rawFaces[0].vertexIndices[2]];
    final c0 = rawFaces[0].vertexIndices.map((i) => rawVertices[i]).reduce((a, b) => a + b) * 0.2;

    var n0 = (v1 - v0).cross(v2 - v0).normalized();
    if (n0.dot(c0) < 0) n0 = -n0;

    final rotAxis = n0.cross(const Vec3(0, 0, 1)).normalized();
    final rotAngle = acos(n0.z.clamp(-1.0, 1.0));

    var rotated = rawVertices.map((v) => v.rotateAxis(rotAxis, rotAngle)).toList();

    // Align top edge horizontally
    final p0 = rotated[rawFaces[0].vertexIndices[0]];
    final p1 = rotated[rawFaces[0].vertexIndices[1]];
    final edgeAngle = atan2(p1.y - p0.y, p1.x - p0.x);
    rotated = rotated.map((v) => v.rotateZ(-edgeAngle)).toList();

    return PolyhedronMesh(vertices: rotated, faces: rawFaces, radius: radius);
  }

  /// 3D Canonical Top-Down Regular Icosahedron (d20) Geometry
  /// Full 20-facet 3D solid with canonical C3 face-centered orientation.
  static PolyhedronMesh createD20({double radius = 72.0}) {
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
      Vec3(r1 * cos(deg90), r1 * sin(deg90), z1),   // 0: Top-Center
      Vec3(r1 * cos(deg210), r1 * sin(deg210), z1), // 1: Bottom-Left
      Vec3(r1 * cos(deg330), r1 * sin(deg330), z1), // 2: Bottom-Right

      // Tier 2: Upper-Middle Ring (Vertices 3, 4, 5)
      Vec3(r2 * cos(deg330 + deg60(1)), r2 * sin(deg330 + deg60(1)), z2), // 3: Right
      Vec3(r2 * cos(deg90 + deg60(1)), r2 * sin(deg90 + deg60(1)), z2),   // 4: Top-Left
      Vec3(r2 * cos(deg210 + deg60(1)), r2 * sin(deg210 + deg60(1)), z2), // 5: Bottom

      // Tier 3: Lower-Middle Ring (Vertices 6, 7, 8)
      Vec3(r2 * cos(deg90), r2 * sin(deg90), -z2),   // 6: Top
      Vec3(r2 * cos(deg210), r2 * sin(deg210), -z2), // 7: Bottom-Left
      Vec3(r2 * cos(deg330), r2 * sin(deg330), -z2), // 8: Bottom-Right

      // Tier 4: Bottom Face Equilateral Triangle (Vertices 9, 10, 11)
      Vec3(r1 * cos(deg270), r1 * sin(deg270), -z1), // 9: Bottom
      Vec3(r1 * cos(deg30), r1 * sin(deg30), -z1),   // 10: Top-Right
      Vec3(r1 * cos(deg150), r1 * sin(deg150), -z1), // 11: Top-Left
    ];

    const faces = [
      // 1. PRIMARY TOP-DOWN FACE: Centered equilateral triangle facing viewer (Face 20)
      Polygon3D([0, 1, 2], faceNumber: 20),

      // 2. Three closest adjacent faces directly connected to the top face
      Polygon3D([0, 2, 3], faceNumber: 14), // Right slope
      Polygon3D([0, 4, 1], faceNumber: 2),  // Left slope
      Polygon3D([1, 5, 2], faceNumber: 8),  // Bottom slope

      // 3. Outer upper corner faces (rendered as shaded 3D facets without text crowding)
      Polygon3D([0, 3, 4], faceNumber: 18),
      Polygon3D([2, 5, 3], faceNumber: 6),
      Polygon3D([1, 4, 5], faceNumber: 12),

      // 4. Middle belt triangles
      Polygon3D([4, 6, 0], faceNumber: 10),
      Polygon3D([3, 8, 2], faceNumber: 16),
      Polygon3D([5, 7, 1], faceNumber: 4),

      Polygon3D([4, 3, 6], faceNumber: 15),
      Polygon3D([3, 5, 8], faceNumber: 7),
      Polygon3D([5, 4, 7], faceNumber: 11),

      Polygon3D([6, 8, 3], faceNumber: 19),
      Polygon3D([8, 7, 5], faceNumber: 3),
      Polygon3D([7, 6, 4], faceNumber: 17),

      // 5. Lower adjacent faces
      Polygon3D([6, 10, 8], faceNumber: 9),
      Polygon3D([8, 9, 7], faceNumber: 13),
      Polygon3D([7, 11, 6], faceNumber: 5),

      // 6. Bottom Face
      Polygon3D([9, 10, 11], faceNumber: 1),
    ];

    return PolyhedronMesh(vertices: vertices, faces: faces, radius: radius);
  }
}
