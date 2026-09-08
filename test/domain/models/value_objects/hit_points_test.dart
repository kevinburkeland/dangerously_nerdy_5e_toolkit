import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/value_objects/hit_points.dart';

void main() {
  group('HitPoints Value Object Tests', () {
    test('initializes with bounds clamping', () {
      const hp = HitPoints(currentHp: 15, maxHp: 10, tempHp: -5);
      expect(hp.maxHp, equals(10));
      expect(hp.currentHp, equals(10)); // clamped to maxHp
      expect(hp.tempHp, equals(0)); // clamped to >= 0
      expect(hp.isDead, isFalse);
      expect(hp.hpPercent, equals(1.0));
    });

    test('takeDamage absorbs temp HP first per 5e RAW', () {
      const hp = HitPoints(currentHp: 20, maxHp: 20, tempHp: 5);

      // Damage smaller than tempHp
      final after3 = hp.takeDamage(3);
      expect(after3.tempHp, equals(2));
      expect(after3.currentHp, equals(20));

      // Damage exceeding tempHp
      final after8 = hp.takeDamage(8);
      expect(after8.tempHp, equals(0));
      expect(after8.currentHp, equals(17)); // 20 - (8 - 5) = 17

      // Massive lethal damage
      final lethal = hp.takeDamage(50);
      expect(lethal.tempHp, equals(0));
      expect(lethal.currentHp, equals(0));
      expect(lethal.isDead, isTrue);
      expect(lethal.hpPercent, equals(0.0));
    });

    test('heal increases current HP up to maxHp and does not affect tempHp', () {
      const hp = HitPoints(currentHp: 10, maxHp: 25, tempHp: 4);

      final healed = hp.heal(8);
      expect(healed.currentHp, equals(18));
      expect(healed.tempHp, equals(4)); // unchanged

      final overHealed = hp.heal(30);
      expect(overHealed.currentHp, equals(25)); // clamped to maxHp
      expect(overHealed.tempHp, equals(4));
    });

    test('grantTempHp does not stack and takes highest unless forceOverride', () {
      const hp = HitPoints(currentHp: 15, maxHp: 20, tempHp: 5);

      // Lower grant ignored
      final lower = hp.grantTempHp(3);
      expect(lower.tempHp, equals(5));

      // Higher grant taken
      final higher = hp.grantTempHp(8);
      expect(higher.tempHp, equals(8));

      // Force override sets lower
      final forced = hp.setTempHp(2);
      expect(forced.tempHp, equals(2));
    });

    test('supports value equality and copyWith', () {
      const hp1 = HitPoints(currentHp: 12, maxHp: 15, tempHp: 3);
      const hp2 = HitPoints(currentHp: 12, maxHp: 15, tempHp: 3);
      final hp3 = hp1.copyWith(currentHp: 14);

      expect(hp1, equals(hp2));
      expect(hp1.hashCode, equals(hp2.hashCode));
      expect(hp1, isNot(equals(hp3)));
    });
  });
}
