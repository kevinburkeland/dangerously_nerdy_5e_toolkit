import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';

void main() {
  group('ObjectSize Extension Tests', () {
    test('Tiny object stats correct', () {
      const size = ObjectSize.tiny;
      expect(size.displayName, 'Tiny');
      expect(size.pointCost, 1);
      expect(size.maxHp, 20);
      expect(size.ac, 18);
      expect(size.attackBonus, 8);
      expect(size.damageDiceCount, 1);
      expect(size.damageDiceSides, 4);
      expect(size.damageBonus, 4);
      expect(size.damageFormula, '1d4+4');
    });

    test('Small object stats correct', () {
      const size = ObjectSize.small;
      expect(size.displayName, 'Small');
      expect(size.pointCost, 1);
      expect(size.maxHp, 10);
      expect(size.ac, 16);
      expect(size.attackBonus, 6);
      expect(size.damageDiceCount, 1);
      expect(size.damageDiceSides, 8);
      expect(size.damageBonus, 2);
      expect(size.damageFormula, '1d8+2');
    });

    test('Medium object stats correct', () {
      const size = ObjectSize.medium;
      expect(size.displayName, 'Medium');
      expect(size.pointCost, 2);
      expect(size.maxHp, 40);
      expect(size.ac, 13);
      expect(size.attackBonus, 5);
      expect(size.damageDiceCount, 1);
      expect(size.damageDiceSides, 10);
      expect(size.damageBonus, 1);
      expect(size.damageFormula, '1d10+1');
    });

    test('Large object stats correct', () {
      const size = ObjectSize.large;
      expect(size.displayName, 'Large');
      expect(size.pointCost, 4);
      expect(size.maxHp, 80);
      expect(size.ac, 10);
      expect(size.attackBonus, 6);
      expect(size.damageDiceCount, 2);
      expect(size.damageDiceSides, 10);
      expect(size.damageBonus, 2);
      expect(size.damageFormula, '2d10+2');
    });

    test('Huge object stats correct', () {
      const size = ObjectSize.huge;
      expect(size.displayName, 'Huge');
      expect(size.pointCost, 8);
      expect(size.maxHp, 100);
      expect(size.ac, 10);
      expect(size.attackBonus, 8);
      expect(size.damageDiceCount, 2);
      expect(size.damageDiceSides, 12);
      expect(size.damageBonus, 4);
      expect(size.damageFormula, '2d12+4');
    });
  });

  group('AnimatedObjectInstance Tests', () {
    test('takeDamage and heal clamp HP correctly', () {
      final obj = AnimatedObjectInstance(
        id: '1',
        name: 'Test Silver Coin',
        size: ObjectSize.tiny,
        currentHp: 20,
        maxHp: 20,
      );

      expect(obj.isDead, false);
      expect(obj.hpPercent, 1.0);

      obj.takeDamage(5);
      expect(obj.currentHp, 15);
      expect(obj.hpPercent, 0.75);

      obj.takeDamage(20);
      expect(obj.currentHp, 0);
      expect(obj.isDead, true);
      expect(obj.hpPercent, 0.0);

      obj.heal(10);
      expect(obj.currentHp, 10);
      expect(obj.isDead, false);

      obj.heal(50);
      expect(obj.currentHp, 20); // Clamped at maxHp
    });

    test('copyWith works correctly', () {
      final obj = AnimatedObjectInstance(
        id: '1',
        name: 'Coin',
        size: ObjectSize.tiny,
        currentHp: 20,
        maxHp: 20,
      );

      final copy = obj.copyWith(name: 'Gold Coin', currentHp: 10);
      expect(copy.id, '1');
      expect(copy.name, 'Gold Coin');
      expect(copy.currentHp, 10);
      expect(copy.maxHp, 20);
    });
  });
}
