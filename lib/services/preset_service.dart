import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_preset.dart';
import '../models/dice_roll.dart';

class PresetService {
  static const String _storageKey = 'user_custom_dice_presets';

  static final PresetService _instance = PresetService._internal();
  factory PresetService() => _instance;
  PresetService._internal();

  /// Built-in default presets for quick access
  static List<CustomPreset> get defaultPresets => [
        CustomPreset(id: 'def_d20', name: 'd20 Check', dieType: DieType.d20, count: 1, modifier: 0),
        CustomPreset(id: 'def_adv', name: 'Advantage', dieType: DieType.d20, count: 1, modifier: 0, rollMode: RollMode.advantage),
        CustomPreset(id: 'def_fireball', name: 'Fireball', dieType: DieType.d6, count: 8, modifier: 0),
        CustomPreset(id: 'def_greatsword', name: 'Greatsword', dieType: DieType.d6, count: 2, modifier: 4),
        CustomPreset(id: 'def_dagger', name: 'Dagger', dieType: DieType.d4, count: 1, modifier: 3),
        CustomPreset(id: 'def_cure', name: 'Cure Wounds', dieType: DieType.d8, count: 1, modifier: 4),
        CustomPreset(id: 'def_stats', name: 'Stats (4d6)', dieType: DieType.d6, count: 4, modifier: 0),
      ];

  /// Loads custom user presets from SharedPreferences
  Future<List<CustomPreset>> loadCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? jsonList = prefs.getStringList(_storageKey);
      if (jsonList == null || jsonList.isEmpty) {
        return [];
      }
      return jsonList.map((str) => CustomPreset.fromJson(str)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Saves a new custom preset to local storage
  Future<List<CustomPreset>> savePreset(CustomPreset preset) async {
    final current = await loadCustomPresets();
    current.removeWhere((p) => p.id == preset.id);
    current.insert(0, preset);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((p) => p.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);
    return current;
  }

  /// Deletes a custom preset by ID from local storage
  Future<List<CustomPreset>> deletePreset(String id) async {
    final current = await loadCustomPresets();
    current.removeWhere((p) => p.id == id);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((p) => p.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);
    return current;
  }

  /// Exports custom presets to a formatted JSON string
  Future<String> exportPresetsJson() async {
    final customList = await loadCustomPresets();
    final jsonList = customList.map((p) => p.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// Imports custom presets from a JSON string
  Future<List<CustomPreset>> importPresetsJson(String jsonString) async {
    final decoded = json.decode(jsonString);
    List<dynamic> itemsList;
    if (decoded is List) {
      itemsList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      itemsList = [decoded];
    } else {
      throw const FormatException('Invalid JSON format for presets');
    }

    final imported = itemsList.map((item) => CustomPreset.fromMap(item as Map<String, dynamic>)).toList();
    if (imported.isEmpty) return await loadCustomPresets();

    final current = await loadCustomPresets();
    for (final newP in imported) {
      current.removeWhere((p) => p.id == newP.id);
      current.insert(0, newP);
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonList = current.map((p) => p.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);
    return current;
  }
}
