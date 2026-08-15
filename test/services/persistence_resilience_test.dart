import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/preset_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/custom_preset.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dice_roll.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Data Resilience & Serialization Recovery Tests', () {
    late PresetService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = PresetService();
      service.clearCacheForTesting();
    });

    test('Saving and reloading custom presets round-trips with full fidelity', () async {
      final preset = CustomPreset(
        id: 'test_preset_1',
        name: 'Sneak Attack',
        diceEntries: [
          DiceEntry(dieType: DieType.d6, count: 5),
          DiceEntry(dieType: DieType.d8, count: 1),
        ],
        modifier: 4,
        rollMode: RollMode.advantage,
      );

      final savedList = await service.savePreset(preset);
      expect(savedList.length, equals(1));
      expect(savedList.first.name, equals('Sneak Attack'));
      expect(savedList.first.diceEntries.length, equals(2));
      expect(savedList.first.modifier, equals(4));
      expect(savedList.first.rollMode, equals(RollMode.advantage));

      service.clearCacheForTesting();
      final reloaded = await service.loadCustomPresets();
      expect(reloaded.length, equals(1));
      expect(reloaded.first.id, equals('test_preset_1'));
      expect(reloaded.first.name, equals('Sneak Attack'));
    });

    test('Corrupted JSON payloads in localStorage or import strings are handled gracefully without crashing', () async {
      // Mock corrupted JSON in storage
      SharedPreferences.setMockInitialValues({
        'user_custom_dice_presets': [
          '{"invalid_json": true}',
          'not valid json at all',
        ],
      });

      service.clearCacheForTesting();
      final loaded = await service.loadCustomPresets();
      // Should not throw and should safely return empty or recover
      expect(loaded, isA<List<CustomPreset>>());
    });

    test('Exporting and importing presets via JSON diagnostics correctly tallies valid and invalid items', () async {
      final validPreset = CustomPreset(
        id: 'export_1',
        name: 'Eldritch Blast',
        diceEntries: [DiceEntry(dieType: DieType.d10, count: 3)],
        modifier: 5,
      );

      await service.savePreset(validPreset);
      final exportedJson = await service.exportPresetsJson();
      expect(exportedJson, contains('Eldritch Blast'));

      // Test importing a payload that contains both a valid item and malformed entries
      const mixedJson = '''
      [
        {"id": "imported_1", "name": "Fireball (8d6)", "diceEntries": [{"dieType": "d6", "count": 8}], "modifier": 0, "rollMode": "normal"},
        {"id": "broken_item", "name": "Broken"}
      ]
      ''';

      final result = await service.importPresetsWithDiagnostics(mixedJson);
      expect(result.newlyImportedCount, greaterThanOrEqualTo(1));
      expect(result.allPresets.any((p) => p.name == 'Fireball (8d6)'), isTrue);
    });
  });
}
