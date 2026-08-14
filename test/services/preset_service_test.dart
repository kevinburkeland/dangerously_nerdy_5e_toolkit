import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/custom_preset.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dice_roll.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/preset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PresetService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PresetService().clearCacheForTesting();
    });

    test('Loads default presets list', () {
      final defaults = PresetService.defaultPresets;
      expect(defaults.isNotEmpty, true);
      expect(defaults.any((p) => p.name == 'Fireball'), true);
    });

    test('Saves and loads custom user presets', () async {
      final service = PresetService();

      final initial = await service.loadCustomPresets();
      expect(initial.isEmpty, true);

      final newPreset = CustomPreset(
        id: 'user_p1',
        name: 'Thunderwave',
        dieType: DieType.d8,
        count: 2,
        modifier: 0,
      );

      final savedList = await service.savePreset(newPreset);
      expect(savedList.length, 1);
      expect(savedList.first.name, 'Thunderwave');

      final loadedList = await service.loadCustomPresets();
      expect(loadedList.length, 1);
      expect(loadedList.first.name, 'Thunderwave');
      expect(loadedList.first.count, 2);
    });

    test('Deletes custom user preset', () async {
      final service = PresetService();

      final preset1 = CustomPreset(id: 'p1', name: 'Preset 1', dieType: DieType.d6, count: 1, modifier: 0);
      final preset2 = CustomPreset(id: 'p2', name: 'Preset 2', dieType: DieType.d8, count: 2, modifier: 1);

      await service.savePreset(preset1);
      await service.savePreset(preset2);

      final loadedBefore = await service.loadCustomPresets();
      expect(loadedBefore.length, 2);

      await service.deletePreset('p1');

      final loadedAfter = await service.loadCustomPresets();
      expect(loadedAfter.length, 1);
      expect(loadedAfter.first.id, 'p2');
    });

    test('Exports and imports presets JSON string', () async {
      final service = PresetService();

      final preset = CustomPreset(id: 'p_exp', name: 'Lightning Bolt', dieType: DieType.d6, count: 8, modifier: 0);
      await service.savePreset(preset);

      final jsonStr = await service.exportPresetsJson();
      expect(jsonStr.contains('Lightning Bolt'), true);

      // Clear preferences to test import into clean state
      SharedPreferences.setMockInitialValues({});
      PresetService().clearCacheForTesting();
      final cleared = await service.loadCustomPresets();
      expect(cleared.isEmpty, true);

      final imported = await service.importPresetsJson(jsonStr);
      expect(imported.length, 1);
      expect(imported.first.name, 'Lightning Bolt');
      expect(imported.first.dieType, DieType.d6);
      expect(imported.first.count, 8);
    });

    test('Rejects JSON import exceeding maximum size limit', () async {
      final service = PresetService();
      final hugeJson = 'a' * 50001;
      expect(() => service.importPresetsJson(hugeJson), throwsFormatException);
    });

    test('Clamps preset count, modifier, and custom sides during JSON import', () async {
      final service = PresetService();
      const malformedJson = '''
      [{
        "id": "p_malformed",
        "name": "Very Super Long Name Beyond Fifty Characters Limit Allowed Test",
        "dieType": "custom",
        "count": 999,
        "modifier": 500,
        "customSides": 9999
      }]
      ''';

      final imported = await service.importPresetsJson(malformedJson);
      expect(imported.length, 1);
      final item = imported.first;
      expect(item.name.length, 50);
      expect(item.count, 100);
      expect(item.modifier, 100);
      expect(item.diceEntries.first.customSides, 1000);
    });

    test('Imports valid presets even when batch contains malformed items', () async {
      final service = PresetService();
      const mixedBatchJson = '''
      [
        {"id": "valid_1", "name": "Valid Preset", "dieType": "d6", "count": 2},
        "bad_primitive_string_entry",
        {"id": "valid_2", "name": "Second Valid", "dieType": "d20", "count": 1}
      ]
      ''';

      final imported = await service.importPresetsJson(mixedBatchJson);
      expect(imported.length, 2);
      expect(imported.any((p) => p.id == 'valid_1'), true);
      expect(imported.any((p) => p.id == 'valid_2'), true);
    });
  });
}
