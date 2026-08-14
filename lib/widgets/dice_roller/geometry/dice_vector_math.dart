import 'dart:math';
import 'package:flutter/material.dart';

/// 3D Vector with essential vector arithmetic and 3D Euler/axis rotation methods.
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator -() => Vec3(-x, -y, -z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  Vec3 normalized() {
    final len = sqrt(x * x + y * y + z * z);
    return len > 0 ? Vec3(x / len, y / len, z / len) : const Vec3(0, 0, 1);
  }

  Vec3 rotateX(double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    return Vec3(x, y * cosR - z * sinR, y * sinR + z * cosR);
  }

  Vec3 rotateY(double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    return Vec3(x * cosR + z * sinR, y, -x * sinR + z * cosR);
  }

  Vec3 rotateZ(double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    return Vec3(x * cosR - y * sinR, x * sinR + y * cosR, z);
  }

  Vec3 rotateAxis(Vec3 axis, double rad) {
    final cosR = cos(rad);
    final sinR = sin(rad);
    final dotR = dot(axis);
    final crossR = axis.cross(this);
    return this * cosR + crossR * sinR + axis * (dotR * (1.0 - cosR));
  }
}

/// A 3D polygon face indexed into a mesh vertex array.
class Polygon3D {
  final List<int> vertexIndices;
  final int? faceNumber;

  const Polygon3D(this.vertexIndices, {this.faceNumber});
}

/// Computed render metadata for a rasterized 3D polygon face.
class FaceRenderData {
  final int faceIndex;
  final Polygon3D face;
  final Vec3 normal;
  final double depth;
  final Path path;
  final Offset centerPt;
  final double diffuse;

  FaceRenderData({
    required this.faceIndex,
    required this.face,
    required this.normal,
    required this.depth,
    required this.path,
    required this.centerPt,
    required this.diffuse,
  });
}
