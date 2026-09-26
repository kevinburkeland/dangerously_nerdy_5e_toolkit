import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd_5e_animated_object_adapter.dart';

void main() {
  setUpAll(() {
    AnimatedObjectStats.defaultProvider = Dnd5eAnimatedObjectAdapter.getStats;
  });

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
    test('applyDamage and applyHealing clamp HP correctly via immutable copies',
        () {
      final obj = AnimatedObjectInstance(
        id: '1',
        name: 'Test Silver Coin',
        size: ObjectSize.tiny,
        currentHp: 20,
        maxHp: 20,
      );

      expect(obj.isDead, false);
      expect(obj.hpPercent, 1.0);

      final damaged1 = obj.applyDamage(5);
      expect(damaged1.currentHp, 15);
      expect(damaged1.hpPercent, 0.75);
      expect(obj.currentHp, 20);

      final damaged2 = damaged1.applyDamage(20);
      expect(damaged2.currentHp, 0);
      expect(damaged2.isDead, true);
      expect(damaged2.hpPercent, 0.0);

      // Normal healing cannot revive a destroyed object (0 HP)
      final stillDead = damaged2.applyHealing(10);
      expect(stillDead.currentHp, 0);
      expect(stillDead.isDead, true);

      // Explicit revival reconstructs the destroyed object
      final revived = damaged2.revive(10);
      expect(revived.currentHp, 10);
      expect(revived.isDead, false);

      final healed2 = revived.applyHealing(50);
      expect(healed2.currentHp, 20); // Clamped at maxHp
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

    test('Temp HP absorbs damage before current HP in applyDamage', () {
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
      final step1 = obj.applyDamage(6);
      expect(step1.tempHp, 4);
      expect(step1.currentHp, 20);
      expect(obj.tempHp, 10);

      // 2. Full temp HP depletion + spillover to current HP
      final step2 =
          step1.applyDamage(8); // 4 temp HP absorbed, 4 damage to current HP
      expect(step2.tempHp, 0);
      expect(step2.currentHp, 16);

      // 3. Granting new Temp HP
      final step3 = step2.applyTempHp(15);
      expect(step3.tempHp, 15);
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
        customProperties: const {'isSilvered': true, 'hasPackTactics': true},
        customAc: 15,
        customAttackBonus: 7,
        customDamageDiceCount: 2,
        customDamageDiceSides: 6,
        customDamageBonus: 3,
        specialTrait: 'Reckless Attack',
        marker: MinionMarker.alpha,
      );

      final map = AnimatedObjectDto.fromDomain(obj).toMap();
      final restored = AnimatedObjectDto.fromMap(map).toDomain();

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

    test(
        'Pure copy-transform methods return updated instances while preserving immutability',
        () {
      final obj = AnimatedObjectInstance(
        id: '1',
        name: 'Iron Golem Minion',
        size: ObjectSize.large,
        currentHp: 40,
        maxHp: 50,
      );

      final damaged = obj.applyDamage(10);
      expect(damaged.currentHp, equals(30));
      expect(obj.currentHp, equals(40)); // original unchanged

      final healed = obj.applyHealing(5);
      expect(healed.currentHp, equals(45));
      expect(obj.currentHp, equals(40)); // original unchanged

      final withTemp = obj.applyTempHp(15);
      expect(withTemp.tempHp, equals(15));
      expect(obj.tempHp, equals(0)); // original unchanged
    });
  });
}
