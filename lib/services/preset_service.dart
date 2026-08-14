import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_preset.dart';
import '../models/dice_roll.dart';
import 'logging_service.dart';
import 'preset_service_interface.dart';

class PresetService implements IPresetService {
  static const String _storageKey = 'user_custom_dice_presets';

  static final PresetService _instance = PresetService._internal();
  factory PresetService() => _instance;
  PresetService._internal();

  List<CustomPreset>? _cachedPresets;

  /// Clears in-memory cache (primarily for unit tests)
  void clearCacheForTesting() {
    _cachedPresets = null;
  }

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

  /// Loads custom user presets from SharedPreferences or in-memory cache
  @override
  Future<List<CustomPreset>> loadCustomPresets() async {
    if (_cachedPresets != null) {
      return List<CustomPreset>.from(_cachedPresets!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? jsonList = prefs.getStringList(_storageKey);
      if (jsonList == null || jsonList.isEmpty) {
        _cachedPresets = [];
        return [];
      }
      final List<CustomPreset> loaded = [];
      for (final str in jsonList) {
        try {
          final preset = CustomPreset.fromJson(str);
          loaded.add(preset);
        } catch (e, stackTrace) {
          LoggingService().logNonFatal(
            e,
            stackTrace,
            reason: 'Skipping corrupted custom dice preset string',
          );
        }
      }
      _cachedPresets = loaded;
      return List<CustomPreset>.from(_cachedPresets!);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to load custom dice presets from SharedPreferences',
      );
      _cachedPresets = [];
      return [];
    }
  }

  /// Saves a new custom preset to local storage and in-memory cache
  @override
  Future<List<CustomPreset>> savePreset(CustomPreset preset) async {
    if (_cachedPresets == null) {
      await loadCustomPresets();
    }
    _cachedPresets!.removeWhere((p) => p.id == preset.id);
    _cachedPresets!.insert(0, preset);

    _persistToDisk();
    return List<CustomPreset>.from(_cachedPresets!);
  }

  /// Deletes a custom preset by ID from local storage and in-memory cache
  @override
  Future<List<CustomPreset>> deletePreset(String id) async {
    if (_cachedPresets == null) {
      await loadCustomPresets();
    }
    _cachedPresets!.removeWhere((p) => p.id == id);

    _persistToDisk();
    return List<CustomPreset>.from(_cachedPresets!);
  }

  /// Helper to persist current cache to SharedPreferences in background
  Future<void> _persistToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = (_cachedPresets ?? []).map((p) => p.toJson()).toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to persist custom dice presets to SharedPreferences',
      );
    }
  }

  /// Exports custom presets to a formatted JSON string
  @override
  Future<String> exportPresetsJson() async {
    final customList = await loadCustomPresets();
    final jsonList = customList.map((p) => p.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// Imports custom presets from a JSON string with security & payload bounds
  @override
  Future<List<CustomPreset>> importPresetsJson(String jsonString) async {
    final cleanInput = jsonString.trim();
    if (cleanInput.length > 50000) {
      throw const FormatException('JSON import payload exceeds maximum size limit (50KB)');
    }

    final decoded = json.decode(cleanInput);
    List<dynamic> itemsList;
    if (decoded is List) {
      itemsList = decoded;
    } else if (decoded is Map<String, dynamic>) {
      itemsList = [decoded];
    } else {
      throw const FormatException('Invalid JSON format for presets');
    }

    if (itemsList.length > 50) {
      itemsList = itemsList.take(50).toList();
    }

    final List<CustomPreset> imported = [];
    for (final item in itemsList) {
      if (item is Map) {
        try {
          final mapItem = Map<String, dynamic>.from(item);
          final rawPreset = CustomPreset.fromMap(mapItem);

          final boundedName = rawPreset.name.trim().length > 50
              ? rawPreset.name.trim().substring(0, 50)
              : rawPreset.name.trim();
          final boundedMod = rawPreset.modifier.clamp(-100, 100);

          final boundedEntries = rawPreset.diceEntries.map((e) {
            final boundedCount = e.count.clamp(1, 100);
            final boundedSides = e.customSides.clamp(2, 1000);
            return e.copyWith(count: boundedCount, customSides: boundedSides);
          }).toList();

          final safePreset = rawPreset.copyWith(
            name: boundedName.isNotEmpty ? boundedName : 'Custom Preset',
            modifier: boundedMod,
            diceEntries: boundedEntries,
          );
          imported.add(safePreset);
        } catch (_) {
          // Skip corrupt or unparseable individual preset
        }
      }
    }

    if (imported.isEmpty) return await loadCustomPresets();

    if (_cachedPresets == null) {
      await loadCustomPresets();
    }

    for (final newP in imported) {
      _cachedPresets!.removeWhere((p) => p.id == newP.id);
      _cachedPresets!.insert(0, newP);
    }

    _persistToDisk();
    return List<CustomPreset>.from(_cachedPresets!);
  }
}
