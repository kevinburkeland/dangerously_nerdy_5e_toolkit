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

  /// 3D Tetrahedron (d4) Geometry (Face-centered flat triangular resting view)
  static PolyhedronMesh createD4({double radius = 64.0}) {
    const zFront = 1.0 / 3.0; // Inscribed center-of-mass depth
    const zApex = -1.0;
    final r = sqrt(8.0 / 9.0); // Exact radius for regular tetrahedron edges

    final vertices = [
      Vec3(0, r, zFront),                              // 0: Top corner (front triangle)
      Vec3(-r * sqrt(3.0) / 2.0, -r / 2.0, zFront),   // 1: Bottom-Left (front triangle)
      Vec3(r * sqrt(3.0) / 2.0, -r / 2.0, zFront),    // 2: Bottom-Right (front triangle)
      const Vec3(0, 0, zApex),                         // 3: Rear Apex
    ];

    const faces = [
      Polygon3D([0, 1, 2], faceNumber: 4), // Front face facing camera (+Z)
      Polygon3D([0, 3, 1], faceNumber: 2), // Left rear slope
      Polygon3D([0, 2, 3], faceNumber: 3), // Right rear slope
      Polygon3D([1, 3, 2], faceNumber: 1), // Bottom rear slope
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

  /// 3D Regular Octahedron (d8) Geometry
  /// Full 8-face solid with canonical face-centered resting orientation.
  static PolyhedronMesh createD8({double radius = 62.0}) {
    // 6 vertices of regular octahedron along coordinate axes
    final rawVerts = [
      const Vec3(1, 0, 0),  // 0: +X
      const Vec3(-1, 0, 0), // 1: -X
      const Vec3(0, 1, 0),  // 2: +Y
      const Vec3(0, -1, 0), // 3: -Y
      const Vec3(0, 0, 1),  // 4: +Z
      const Vec3(0, 0, -1), // 5: -Z
    ];

    const faces = [
      // 4 Upper Octants (+Z) (Winding CCW outward from center)
      Polygon3D([0, 2, 4], faceNumber: 8), // (+X, +Y, +Z) -> Face 0
      Polygon3D([2, 1, 4], faceNumber: 6), // (-X, +Y, +Z)
      Polygon3D([1, 3, 4], faceNumber: 4), // (-X, -Y, +Z)
      Polygon3D([3, 0, 4], faceNumber: 2), // (+X, -Y, +Z)

      // 4 Lower Octants (-Z) (Opposites sum to 9)
      Polygon3D([1, 5, 3], faceNumber: 1), // (-X, -Y, -Z) -> Opposite 8
      Polygon3D([3, 5, 0], faceNumber: 3), // (+X, -Y, -Z) -> Opposite 6
      Polygon3D([0, 5, 2], faceNumber: 5), // (+X, +Y, -Z) -> Opposite 4
      Polygon3D([2, 5, 1], faceNumber: 7), // (-X, +Y, -Z) -> Opposite 2
    ];

    // Rotate so Face 0 normal aligns with +Z (camera)
    final topFace = faces[0];
    final v0 = rawVerts[topFace.vertexIndices[0]];
    final v1 = rawVerts[topFace.vertexIndices[1]];
    final v2 = rawVerts[topFace.vertexIndices[2]];
    final n0 = (v1 - v0).cross(v2 - v0).normalized();

    final rotAxis = n0.cross(const Vec3(0, 0, 1)).normalized();
    final rotAngle = acos(n0.z.clamp(-1.0, 1.0));

    var rotated = rawVerts.map((v) => v.rotateAxis(rotAxis, rotAngle)).toList();

    // Align apex of Face 0 pointing straight up (+Y)
    final r0 = rotated[topFace.vertexIndices[0]];
    final r1 = rotated[topFace.vertexIndices[1]];
    final r2 = rotated[topFace.vertexIndices[2]];
    final centerFace = (r0 + r1 + r2) * (1.0 / 3.0);
    final topVert = [r0, r1, r2].reduce((a, b) => a.y > b.y ? a : b);
    final alignAngle = atan2(topVert.x - centerFace.x, topVert.y - centerFace.y);
    rotated = rotated.map((v) => v.rotateZ(alignAngle)).toList();

    return PolyhedronMesh(vertices: rotated, faces: faces, radius: radius);
  }

  /// 3D Mathematically Exact Pentagonal Trapezohedron (d10) Geometry
  /// Authentic 10-deltoid (kite) solid with canonical face-centered resting orientation.
  static PolyhedronMesh createD10({double radius = 70.0}) {
    const z1 = 0.1055728;
    const r = 0.7038406;
    const h = 1.0; // exact planar ratio: 1.0 / 0.1055728 = 5 + 2*sqrt(5)
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

    // Align kite centerline vertically with +Y
    final rApex = rotated[0];
    final rBottom = rotated[11];
    final centerLine = (rApex - rBottom);
    final alignAngle = atan2(centerLine.x, centerLine.y);
    rotated = rotated.map((v) => v.rotateZ(alignAngle)).toList();

    return PolyhedronMesh(vertices: rotated, faces: faces, radius: radius);
  }

  /// 3D Coin Medallion Mesh (for d100 & Non-Standard / Custom Dice)
  /// Elegant circular medallion with beveled cylindrical rim and prominent face-centered resting view.
  static PolyhedronMesh createMedallion({double radius = 70.0}) {
    const n = 24; // 24-sided smooth circular perimeter
    const thickness = 0.20;
    const zHalf = thickness / 2.0;

    final verts = <Vec3>[
      // 0..23: Front circle vertices (+Z)
      for (int k = 0; k < n; k++)
        Vec3(cos(k * 2 * pi / n), sin(k * 2 * pi / n), zHalf),
      // 24..47: Back circle vertices (-Z)
      for (int k = 0; k < n; k++)
        Vec3(cos(k * 2 * pi / n), sin(k * 2 * pi / n), -zHalf),
    ];

    final faces = <Polygon3D>[
      // 1. Primary Front Face (Face 0: facing +Z directly at camera)
      Polygon3D([for (int k = 0; k < n; k++) k], faceNumber: 100),

      // 2. Back Face (Face 1: facing -Z directly away from camera)
      Polygon3D([for (int k = n - 1; k >= 0; k--) n + k], faceNumber: 1),

      // 3. Rim Quads (24 beveled side facets with outward normals)
      for (int k = 0; k < n; k++)
        Polygon3D([
          k,
          n + k,
          n + ((k + 1) % n),
          (k + 1) % n,
        ]),
    ];

    return PolyhedronMesh(vertices: verts, faces: faces, radius: radius);
  }

  /// 3D 100-Sided Die (d100) Geometry: Coin Medallion
  static PolyhedronMesh createD100({double radius = 70.0}) {
    return createMedallion(radius: radius);
  }

  /// 3D Mesh for Non-Standard & Custom Dice
  static PolyhedronMesh createSphere({double radius = 70.0}) {
    return createMedallion(radius: radius);
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
  /// Exact 20-facet regular icosahedron with canonical face-centered resting orientation.
  static PolyhedronMesh createD20({double radius = 72.0}) {
    final phi = (1.0 + sqrt(5.0)) / 2.0; // Golden ratio ~1.6180339887
    final scale = 1.0 / sqrt(1.0 + phi * phi);

    final rawVerts = [
      Vec3(-scale, 0, phi * scale),  // 0
      Vec3(scale, 0, phi * scale),   // 1
      Vec3(-scale, 0, -phi * scale), // 2
      Vec3(scale, 0, -phi * scale),  // 3
      Vec3(0, phi * scale, scale),   // 4
      Vec3(0, phi * scale, -scale),  // 5
      Vec3(0, -phi * scale, scale),  // 6
      Vec3(0, -phi * scale, -scale), // 7
      Vec3(phi * scale, scale, 0),   // 8
      Vec3(-phi * scale, scale, 0),  // 9
      Vec3(phi * scale, -scale, 0),  // 10
      Vec3(-phi * scale, -scale, 0), // 11
    ];

    const rawFaces = [
      // 5 around vertex 0 (+Z tier)
      Polygon3D([0, 1, 4], faceNumber: 20), // Top Face
      Polygon3D([0, 4, 9], faceNumber: 14),
      Polygon3D([0, 9, 11], faceNumber: 2),
      Polygon3D([0, 11, 6], faceNumber: 8),
      Polygon3D([0, 6, 1], faceNumber: 18),

      // 5 adjacent to above
      Polygon3D([1, 8, 4], faceNumber: 6),
      Polygon3D([4, 5, 9], faceNumber: 12),
      Polygon3D([9, 2, 11], faceNumber: 10),
      Polygon3D([11, 7, 6], faceNumber: 16),
      Polygon3D([6, 10, 1], faceNumber: 4),

      // 5 around vertex 3 (-Z tier) (Opposites sum to 21)
      Polygon3D([3, 2, 5], faceNumber: 1),   // Opposite 20
      Polygon3D([3, 5, 8], faceNumber: 7),   // Opposite 14
      Polygon3D([3, 8, 10], faceNumber: 19), // Opposite 2
      Polygon3D([3, 10, 7], faceNumber: 13), // Opposite 8
      Polygon3D([3, 7, 2], faceNumber: 3),   // Opposite 18

      // 5 adjacent to bottom
      Polygon3D([2, 9, 5], faceNumber: 15),
      Polygon3D([5, 4, 8], faceNumber: 9),
      Polygon3D([8, 1, 10], faceNumber: 11),
      Polygon3D([10, 6, 7], faceNumber: 5),
      Polygon3D([7, 11, 2], faceNumber: 17),
    ];

    // Rotate so Face 0 normal aligns with +Z (camera)
    final topFace = rawFaces[0];
    final v0 = rawVerts[topFace.vertexIndices[0]];
    final v1 = rawVerts[topFace.vertexIndices[1]];
    final v2 = rawVerts[topFace.vertexIndices[2]];
    final n0 = (v1 - v0).cross(v2 - v0).normalized();

    final rotAxis = n0.cross(const Vec3(0, 0, 1)).normalized();
    final rotAngle = acos(n0.z.clamp(-1.0, 1.0));

    var rotated = rawVerts.map((v) => v.rotateAxis(rotAxis, rotAngle)).toList();

    // Align top vertex of Face 0 pointing straight up (+Y)
    final r0 = rotated[topFace.vertexIndices[0]];
    final r1 = rotated[topFace.vertexIndices[1]];
    final r2 = rotated[topFace.vertexIndices[2]];
    final centerFace = (r0 + r1 + r2) * (1.0 / 3.0);
    final topVert = [r0, r1, r2].reduce((a, b) => a.y > b.y ? a : b);
    final alignAngle = atan2(topVert.x - centerFace.x, topVert.y - centerFace.y);
    rotated = rotated.map((v) => v.rotateZ(alignAngle)).toList();

    return PolyhedronMesh(vertices: rotated, faces: rawFaces, radius: radius);
  }
}
