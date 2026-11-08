import 'package:meta/meta.dart';

/// Pure Dart representation of an ARGB 32-bit color value.
@immutable
final class Argb {
  const Argb(this.value);

  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Argb && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    final hex = value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return 'Argb(0x$hex)';
  }
}

