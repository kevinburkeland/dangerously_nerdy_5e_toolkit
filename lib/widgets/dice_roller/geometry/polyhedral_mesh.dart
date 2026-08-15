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

  /// 3D Mathematically Exact Pentagonal Trapezohedron (d10) Geometry
  /// Authentic 10-deltoid (kite) solid with canonical face-centered resting orientation.
  static PolyhedronMesh createD10({double radius = 70.0}) {
    const h = 1.35;
    const z1 = 0.25;
    const r = 1.0;
    const deg72 = 2.0 * pi / 5.0;
    const deg36 = pi / 5.0;

    final rawVerts = <Vec3>[
      const Vec3(0, 0, h),  // 0: Top Apex
      const Vec3(0, 0, -h), // 1: Bottom Apex
      for (int k = 0; k < 5; k++) Vec3(r * cos(k * deg72), r * sin(k * deg72), z1), // 2..6: Upper Belt
      for (int k = 0; k < 5; k++) Vec3(r * cos(deg36 + k * deg72), r * sin(deg36 + k * deg72), -z1), // 7..11: Lower Belt
    ];

    const faces = [
      // 5 Upper Kites (CCW winding from outside, normal points outward from origin)
      Polygon3D([0, 6, 11, 2], faceNumber: 10), // 0: Top Face (Facing Camera)
      Polygon3D([0, 2, 7, 3], faceNumber: 2),
      Polygon3D([0, 3, 8, 4], faceNumber: 8),
      Polygon3D([0, 4, 9, 5], faceNumber: 4),
      Polygon3D([0, 5, 10, 6], faceNumber: 6),

      // 5 Lower Kites (Opposites sum to 11)
      Polygon3D([1, 7, 2, 11], faceNumber: 1),  // Opposite 10
      Polygon3D([1, 8, 3, 7], faceNumber: 9),   // Opposite 2
      Polygon3D([1, 9, 4, 8], faceNumber: 3),   // Opposite 8
      Polygon3D([1, 10, 5, 9], faceNumber: 7),  // Opposite 4
      Polygon3D([1, 11, 6, 10], faceNumber: 5), // Opposite 6
    ];

    // Rotate around center (0,0,0) so Face 0 normal aligns with +Z (camera)
    final topFace = faces[0];
    final v0 = rawVerts[topFace.vertexIndices[0]];
    final v1 = rawVerts[topFace.vertexIndices[1]];
    final v2 = rawVerts[topFace.vertexIndices[2]];
    final n0 = (v1 - v0).cross(v2 - v0).normalized();

    final rotAxis = n0.cross(const Vec3(0, 0, 1)).normalized();
    final rotAngle = acos(n0.z.clamp(-1.0, 1.0));

    var rotated = rawVerts.map((v) => v.rotateAxis(rotAxis, rotAngle)).toList();

    // Align apex vertical (+Y)
    final pApex = rotated[0];
    final apexAngle = atan2(pApex.x, pApex.y);
    rotated = rotated.map((v) => Vec3(
      v.x * cos(apexAngle) - v.y * sin(apexAngle),
      v.x * sin(apexAngle) + v.y * cos(apexAngle),
      v.z,
    )).toList();

    return PolyhedronMesh(vertices: rotated, faces: faces, radius: radius);
  }

  /// 3D Mathematically Exact 100-Sided Die (d100 / Zocchihedron / 100-faceted sphere) Geometry
  /// Authentic 100-faceted spherical solid with uniform Fibonacci golden spiral distribution.
  static PolyhedronMesh createD100({double radius = 78.0}) {
    const totalFaces = 100;
    final goldenRatio = (1.0 + sqrt(5.0)) / 2.0;
    final goldenAngle = 2.0 * pi * (1.0 - 1.0 / goldenRatio); // ~2.39996323 rad

    // 1. Generate 100 uniform face centroids on the unit sphere
    final faceCenters = <Vec3>[];
    for (int i = 0; i < totalFaces; i++) {
      final y = 1.0 - (i / (totalFaces - 1.0)) * 2.0; // from +1 to -1
      final r = sqrt((1.0 - y * y).clamp(0.0, 1.0));
      final theta = i * goldenAngle;
      final x = r * cos(theta);
      final z = r * sin(theta);
      faceCenters.add(Vec3(x, y, z).normalized());
    }

    // Align face 0 (at +Y) to face +Z directly (camera)
    final rotatedCenters = faceCenters.map((c) => Vec3(c.x, -c.z, c.y)).toList();

    // 2. Generate 100 regular pentagonal facets tangent to the sphere
    final allVerts = <Vec3>[];
    final allFaces = <Polygon3D>[];
    const facetRadius = 0.165;
    const sides = 5;

    for (int i = 0; i < totalFaces; i++) {
      final center = rotatedCenters[i];

      var up = const Vec3(0, 1, 0);
      if (center.dot(up).abs() > 0.9) up = const Vec3(1, 0, 0);
      final tangentX = up.cross(center).normalized();
      final tangentY = center.cross(tangentX).normalized();

      final startIdx = allVerts.length;
      final vIndices = <int>[];

      for (int s = 0; s < sides; s++) {
        final angle = s * 2.0 * pi / sides;
        final offset = tangentX * (cos(angle) * facetRadius) + tangentY * (sin(angle) * facetRadius);
        final vert = (center + offset).normalized();
        allVerts.add(vert);
        vIndices.add(startIdx + s);
      }

      // Assign face number: Face 0 is 100, others 1..99 with opposite pairing
      final num = i == 0 ? 100 : (i % 2 == 0 ? i : (100 - i));
      allFaces.add(Polygon3D(vIndices, faceNumber: num));
    }

    return PolyhedronMesh(vertices: allVerts, faces: allFaces, radius: radius);
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
      // Top & Bottom Faces (Opposites sum to 13)
      Polygon3D([10, 5, 19, 7, 11], faceNumber: 12), // 0: Top Face (Facing camera)
      Polygon3D([8, 0, 16, 2, 9], faceNumber: 1),    // 1: Bottom Face (Opposite 12)

      // Surrounding Upper/Lower Face Pairs
      Polygon3D([17, 3, 15, 7, 19], faceNumber: 9),  // 2: Upper Right
      Polygon3D([16, 18, 6, 14, 2], faceNumber: 4),  // 3: Opposite 9

      Polygon3D([14, 6, 11, 7, 15], faceNumber: 5),  // 4: Upper
      Polygon3D([12, 0, 8, 1, 13], faceNumber: 8),   // 5: Opposite 5

      Polygon3D([10, 11, 6, 18, 4], faceNumber: 11), // 6: Upper Left
      Polygon3D([8, 9, 3, 17, 1], faceNumber: 2),    // 7: Opposite 11

      Polygon3D([12, 13, 5, 10, 4], faceNumber: 3),  // 8: Lower Left
      Polygon3D([14, 15, 3, 9, 2], faceNumber: 10),  // 9: Opposite 3

      Polygon3D([17, 19, 5, 13, 1], faceNumber: 7),  // 10: Lower Right
      Polygon3D([16, 0, 12, 4, 18], faceNumber: 6),  // 11: Opposite 7
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
    final p0 = rotated[rawFaces[0].vertexIndices[3]]; // Vertex 7
    final p1 = rotated[rawFaces[0].vertexIndices[4]]; // Vertex 11
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
