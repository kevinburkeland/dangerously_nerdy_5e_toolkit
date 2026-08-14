import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/custom_preset.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dice_roll.dart';

void main() {
  group('CustomPreset Model Tests', () {
    test('Serializes to and from Map correctly', () {
      final preset = CustomPreset(
        id: 'p1',
        name: 'Fireball Boost',
        dieType: DieType.d6,
        count: 10,
        modifier: 5,
        rollMode: RollMode.normal,
      );

      final map = preset.toMap();
      expect(map['id'], 'p1');
      expect(map['name'], 'Fireball Boost');
      expect(map['dieType'], 'd6');
      expect(map['count'], 10);
      expect(map['modifier'], 5);

      final restored = CustomPreset.fromMap(map);
      expect(restored.id, preset.id);
      expect(restored.name, preset.name);
      expect(restored.dieType, preset.dieType);
      expect(restored.count, preset.count);
      expect(restored.modifier, preset.modifier);
    });

    test('Formula string formats properly', () {
      final preset1 = CustomPreset(
        id: 'p1',
        name: 'Sneak Attack',
        dieType: DieType.d6,
        count: 3,
        modifier: 0,
      );
      expect(preset1.formulaString, '3d6');

      final preset2 = CustomPreset(
        id: 'p2',
        name: 'Advantage d20',
        dieType: DieType.d20,
        count: 1,
        modifier: 4,
        rollMode: RollMode.advantage,
      );
      expect(preset2.formulaString, '1d20+4 (Adv)');
    });

    test('Multi-dice preset serializes and formats properly', () {
      final preset = CustomPreset(
        id: 'p_multi',
        name: 'Chaos Strike',
        diceEntries: [
          DiceEntry(dieType: DieType.d6, count: 2),
          DiceEntry(dieType: DieType.custom, count: 1, customSides: 7),
        ],
        modifier: 3,
      );

      expect(preset.formulaString, '2d6+1d7+3');

      final map = preset.toMap();
      final restored = CustomPreset.fromMap(map);

      expect(restored.name, 'Chaos Strike');
      expect(restored.diceEntries.length, 2);
      expect(restored.diceEntries[0].dieType, DieType.d6);
      expect(restored.diceEntries[1].customSides, 7);
      expect(restored.formulaString, '2d6+1d7+3');
    });

    test('Gracefully handles malformed JSON and type mismatches', () {
      final malformedMap = <String, dynamic>{
        'id': 12345, // int instead of string
        'name': 999, // int instead of string
        'diceEntries': [
          'invalid_entry_string',
          {'dieType': 'd8', 'count': 4.0, 'customSides': 8.0},
        ],
        'modifier': 3.5, // double instead of int
        'rollMode': 'unknown_mode',
      };

      final preset = CustomPreset.fromMap(malformedMap);
      expect(preset.id, '12345');
      expect(preset.name, '999');
      expect(preset.diceEntries.length, 1);
      expect(preset.diceEntries.first.dieType, DieType.d8);
      expect(preset.diceEntries.first.count, 4);
      expect(preset.modifier, 3);
      expect(preset.rollMode, RollMode.normal);
    });
  });
}

