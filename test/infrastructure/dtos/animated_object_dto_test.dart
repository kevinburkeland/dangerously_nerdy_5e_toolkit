import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/animated_object_dto.dart';

void main() {
  group('AnimatedObjectDto Serialization & Clamping Tests', () {
    test('Round-trip serialization preserves all custom traits and stats', () {
      final domain = AnimatedObjectInstance(
        id: 'token_42',
        name: 'Iron Table',
        size: ObjectSize.large,
        currentHp: 40,
        maxHp: 50,
        tempHp: 5,
        damageType: 'bludgeoning',
        isSilvered: true,
        customAc: 15,
        customAttackBonus: 6,
        customDamageDiceCount: 2,
        customDamageDiceSides: 10,
        customDamageBonus: 4,
        hasPackTactics: false,
        specialTrait: 'Heavy Slam',
        customAccentColorValue: 0xFF1E88E5,
      );

      final dto = AnimatedObjectDto.fromDomain(domain);
      final map = dto.toMap();
      final restoredDto = AnimatedObjectDto.fromMap(map);
      final restored = restoredDto.toDomain();

      expect(restored.id, equals('token_42'));
      expect(restored.name, equals('Iron Table'));
      expect(restored.size, equals(ObjectSize.large));
      expect(restored.currentHp, equals(40));
      expect(restored.maxHp, equals(50));
      expect(restored.tempHp, equals(5));
      expect(restored.damageType, equals('bludgeoning'));
      expect(restored.isSilvered, isTrue);
      expect(restored.customAc, equals(15));
      expect(restored.customAttackBonus, equals(6));
      expect(restored.customDamageDiceCount, equals(2));
      expect(restored.customDamageDiceSides, equals(10));
      expect(restored.customDamageBonus, equals(4));
      expect(restored.hasPackTactics, isFalse);
      expect(restored.specialTrait, equals('Heavy Slam'));
      expect(restored.customAccentColorValue, equals(0xFF1E88E5));
    });

    test('Clamps negative HP and temporary HP safely during deserialization', () {
      final raw = {
        'id': 'neg_hp_minion',
        'name': 'Battered Shield',
        'size': 'small',
        'currentHp': -10,
        'maxHp': 0,
        'tempHp': -5,
      };

      final restored = AnimatedObjectDto.fromMap(raw).toDomain();
      expect(restored.currentHp, equals(0));
      expect(restored.maxHp, equals(1)); // maxHp clamped to minimum of 1
      expect(restored.tempHp, equals(0)); // tempHp clamped to minimum of 0
    });
  });
}
