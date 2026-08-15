import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dice_roller/geometry/polyhedral_mesh.dart';

void main() {
  group('PolyhedronMesh Geometry Tests', () {
    test('createD4 produces a valid tetrahedron mesh', () {
      final mesh = PolyhedronMesh.createD4(radius: 60.0);
      expect(mesh.vertices.length, equals(4));
      expect(mesh.faces.length, equals(4));
      for (final face in mesh.faces) {
        expect(face.vertexIndices.length, equals(3));
      }
    });

    test('createD6 produces a valid cube mesh', () {
      final mesh = PolyhedronMesh.createD6(radius: 60.0);
      expect(mesh.vertices.length, equals(8));
      expect(mesh.faces.length, equals(6));
      for (final face in mesh.faces) {
        expect(face.vertexIndices.length, equals(4));
      }
    });

    test('createD8 produces a valid octahedron mesh', () {
      final mesh = PolyhedronMesh.createD8(radius: 62.0);
      expect(mesh.vertices.length, equals(6));
      expect(mesh.faces.length, equals(8));
      for (final face in mesh.faces) {
        expect(face.vertexIndices.length, equals(3));
      }
    });

    test('createD10 produces a mathematically exact pentagonal trapezohedron mesh', () {
      final mesh = PolyhedronMesh.createD10(radius: 70.0);
      expect(mesh.vertices.length, equals(12));
      expect(mesh.faces.length, equals(10));
      for (final face in mesh.faces) {
        expect(face.vertexIndices.length, equals(4));
      }
      // Check Face 0 vertical symmetry
      final topFace = mesh.faces[0];
      final vLeft = mesh.vertices[topFace.vertexIndices[1]];
      final vRight = mesh.vertices[topFace.vertexIndices[3]];
      expect(vLeft.x, closeTo(-vRight.x, 1e-4));
      expect(vLeft.y, closeTo(vRight.y, 1e-4));
    });

    test('createD100 and createMedallion produce a 3D coin medallion mesh for d100 and custom dice', () {
      final mesh = PolyhedronMesh.createD100(radius: 70.0);
      expect(mesh.vertices.length, equals(48));
      expect(mesh.faces.length, equals(26));
      expect(mesh.faces[0].faceNumber, equals(100));

      final medallionMesh = PolyhedronMesh.createMedallion(radius: 65.0);
      expect(medallionMesh.vertices.length, equals(48));
      expect(medallionMesh.faces.length, equals(26));
    });

    test('createD12 produces a mathematically exact regular dodecahedron mesh', () {
      final mesh = PolyhedronMesh.createD12(radius: 68.0);
      expect(mesh.vertices.length, equals(20));
      expect(mesh.faces.length, equals(12));

      // Each face must be a 5-sided regular pentagon
      for (final face in mesh.faces) {
        expect(face.vertexIndices.length, equals(5));
      }

      // Check visible front-facing facets along top-down resting orientation
      int frontFacingCount = 0;
      bool hasDirectTopFace = false;

      for (int i = 0; i < mesh.faces.length; i++) {
        final f = mesh.faces[i];
        final v0 = mesh.vertices[f.vertexIndices[0]];
        final v1 = mesh.vertices[f.vertexIndices[1]];
        final v2 = mesh.vertices[f.vertexIndices[2]];
        final c = f.vertexIndices.map((idx) => mesh.vertices[idx]).reduce((a, b) => a + b) * 0.2;
        var n = (v1 - v0).cross(v2 - v0).normalized();
        if (n.dot(c) < 0) n = -n;

        if (n.z > 0.02) {
          frontFacingCount++;
          if (n.z > 0.99) {
            hasDirectTopFace = true;
          }
        }
      }

      // In resting orientation, exactly 6 faces are front-facing (1 center + 5 surrounding)
      expect(frontFacingCount, equals(6));
      expect(hasDirectTopFace, isTrue);
    });

    test('createD20 produces a valid icosahedron mesh', () {
      final mesh = PolyhedronMesh.createD20(radius: 72.0);
      expect(mesh.vertices.length, equals(12));
      expect(mesh.faces.length, equals(20));
      for (final face in mesh.faces) {
        expect(face.vertexIndices.length, equals(3));
      }
    });
  });
}
