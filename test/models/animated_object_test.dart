import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';

void main() {
  group('ObjectSize Enhanced Enum Tests', () {
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
      expect(size.maxHp, 25);
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
      expect(size.damageDiceCount, 2);
      expect(size.damageDiceSides, 6);
      expect(size.damageBonus, 1);
      expect(size.damageFormula, '2d6+1');
    });

    test('Large object stats correct', () {
      const size = ObjectSize.large;
      expect(size.displayName, 'Large');
      expect(size.pointCost, 4);
      expect(size.maxHp, 50);
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
      expect(size.maxHp, 80);
      expect(size.ac, 10);
      expect(size.attackBonus, 8);
      expect(size.damageDiceCount, 2);
      expect(size.damageDiceSides, 12);
      expect(size.damageBonus, 4);
      expect(size.damageFormula, '2d12+4');
    });

    test('fromString resolves size variants and fallbacks', () {
      expect(ObjectSize.fromString('tiny'), ObjectSize.tiny);
      expect(ObjectSize.fromString('Tiny'), ObjectSize.tiny);
      expect(ObjectSize.fromString('Large Beast'), ObjectSize.large);
      expect(ObjectSize.fromString('huge monster'), ObjectSize.huge);
      expect(ObjectSize.fromString('unknown'), ObjectSize.medium);
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

    test('applyDamage and applyHealing return updated immutable copies', () {
      final obj = AnimatedObjectInstance(
        id: '1',
        name: 'Test Silver Coin',
        size: ObjectSize.tiny,
        currentHp: 20,
        maxHp: 20,
      );

      final damaged = obj.applyDamage(8);
      expect(damaged.currentHp, 12);
      expect(obj.currentHp, 20); // Original unchanged

      final healed = damaged.applyHealing(5);
      expect(healed.currentHp, 17);
    });

    test('hpPercent protects against divide by zero', () {
      final obj = AnimatedObjectInstance(
        id: 'zero',
        name: 'Zero HP Object',
        size: ObjectSize.small,
        currentHp: 0,
        maxHp: 0,
      );

      expect(obj.hpPercent.isFinite, true);
      expect(obj.hpPercent.isNaN, false);
      expect(obj.hpPercent, 0.0);
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

    test('Temp HP absorbs damage before current HP in takeDamage and applyDamage', () {
      final obj = AnimatedObjectInstance(
        id: 'temp_1',
        name: 'Warded Wolf',
        size: ObjectSize.medium,
        currentHp: 20,
        maxHp: 20,
        tempHp: 10,
      );

      expect(obj.tempHp, 10);
      expect(obj.currentHp, 20);

      // 1. Partial temp HP depletion
      obj.takeDamage(6);
      expect(obj.tempHp, 4);
      expect(obj.currentHp, 20);

      // 2. Full temp HP depletion + spillover to current HP
      obj.takeDamage(8); // 4 temp HP absorbed, 4 damage to current HP
      expect(obj.tempHp, 0);
      expect(obj.currentHp, 16);

      // 3. Granting new Temp HP
      obj.grantTempHp(15);
      expect(obj.tempHp, 15);

      // 4. Immutable applyDamage pipeline
      final afterDmg = obj.applyDamage(20); // 15 temp absorbed, 5 to HP
      expect(afterDmg.tempHp, 0);
      expect(afterDmg.currentHp, 11);
      expect(obj.tempHp, 15); // Original unchanged
      expect(obj.currentHp, 16);
    });

    test('Serialization toMap and fromMap round-trips cleanly with tempHp', () {
      final obj = AnimatedObjectInstance(
        id: 'inst-99',
        name: 'Elite Berserker',
        size: ObjectSize.medium,
        currentHp: 35,
        maxHp: 45,
        tempHp: 12,
        damageType: 'Slashing',
        isSilvered: true,
        customAc: 15,
        customAttackBonus: 7,
        customDamageDiceCount: 2,
        customDamageDiceSides: 6,
        customDamageBonus: 3,
        hasPackTactics: true,
        specialTrait: 'Reckless Attack',
        customAccentColor: const Color(0xFFFF5722),
      );

      final map = obj.toMap();
      final restored = AnimatedObjectInstance.fromMap(map);

      expect(restored.id, obj.id);
      expect(restored.name, obj.name);
      expect(restored.size, obj.size);
      expect(restored.currentHp, obj.currentHp);
      expect(restored.maxHp, obj.maxHp);
      expect(restored.tempHp, 12);
      expect(restored.damageType, obj.damageType);
      expect(restored.isSilvered, obj.isSilvered);
      expect(restored.customAc, obj.customAc);
      expect(restored.customAttackBonus, obj.customAttackBonus);
      expect(restored.hasPackTactics, obj.hasPackTactics);
      expect(restored.specialTrait, obj.specialTrait);
      expect(restored, equals(obj));
    });
  });
}
