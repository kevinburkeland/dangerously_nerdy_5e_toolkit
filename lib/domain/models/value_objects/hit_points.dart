import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Immutable Value Object encapsulating Hit Points, Temporary Hit Points,
/// damage absorption (5e RAW), and healing bounded by maximum HP.
@immutable
class HitPoints {
  final int currentHp;
  final int maxHp;
  final int tempHp;

  const HitPoints({
    required int currentHp,
    required int maxHp,
    int tempHp = 0,
  })  : maxHp = maxHp < 1 ? 1 : maxHp,
        currentHp = currentHp < 0 ? 0 : (currentHp > (maxHp < 1 ? 1 : maxHp) ? (maxHp < 1 ? 1 : maxHp) : currentHp),
        tempHp = tempHp < 0 ? 0 : tempHp;

  /// Convenience factory creating full-health hit points.
  factory HitPoints.full(int maxHp, {int tempHp = 0}) {
    final validMax = maxHp < 1 ? 1 : maxHp;
    return HitPoints(
      currentHp: validMax,
      maxHp: validMax,
      tempHp: tempHp,
    );
  }

  /// Whether current HP has reached 0 (unconscious or destroyed).
  bool get isDead => currentHp <= 0;

  /// Safe calculation of remaining HP percentage [0.0, 1.0].
  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  /// Applies damage according to 5e RAW:
  /// Temporary hit points absorb incoming damage first. Any remainder reduces current HP.
  HitPoints takeDamage(int amount) {
    if (amount <= 0) return this;

    int remaining = amount;
    int newTemp = tempHp;

    if (newTemp > 0) {
      if (remaining <= newTemp) {
        newTemp -= remaining;
        remaining = 0;
      } else {
        remaining -= newTemp;
        newTemp = 0;
      }
    }

    final newCurrent = (currentHp - remaining).clamp(0, maxHp);
    return HitPoints(
      currentHp: newCurrent,
      maxHp: maxHp,
      tempHp: newTemp,
    );
  }

  /// Applies healing bounded by [maxHp]. Does not affect temporary hit points.
  HitPoints heal(int amount) {
    if (amount <= 0) return this;
    final newCurrent = (currentHp + amount).clamp(0, maxHp);
    return HitPoints(
      currentHp: newCurrent,
      maxHp: maxHp,
      tempHp: tempHp,
    );
  }

  /// Grants Temporary Hit Points (5e RAW: non-stacking; overrides if higher, or if [forceOverride]).
  HitPoints grantTempHp(int amount, {bool forceOverride = false}) {
    if (amount <= 0 && !forceOverride) return this;
    final newTemp = forceOverride ? math.max(0, amount) : math.max(tempHp, math.max(0, amount));
    return HitPoints(
      currentHp: currentHp,
      maxHp: maxHp,
      tempHp: newTemp,
    );
  }

  /// Overrides Temporary Hit Points explicitly.
  HitPoints setTempHp(int amount) => grantTempHp(amount, forceOverride: true);

  HitPoints copyWith({
    int? currentHp,
    int? maxHp,
    int? tempHp,
  }) {
    return HitPoints(
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      tempHp: tempHp ?? this.tempHp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HitPoints &&
          runtimeType == other.runtimeType &&
          currentHp == other.currentHp &&
          maxHp == other.maxHp &&
          tempHp == other.tempHp;

  @override
  int get hashCode => Object.hash(currentHp, maxHp, tempHp);

  @override
  String toString() => 'HitPoints($currentHp/$maxHp + $tempHp temp)';
}
