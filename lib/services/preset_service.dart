import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_preset.dart';
import '../models/dice_roll.dart';
import 'logging_service.dart';

/// Diagnostic result from a JSON preset import operation
class PresetImportResult {
  final List<CustomPreset> allPresets;
  final int newlyImportedCount;
  final int failedCount;

  const PresetImportResult({
    required this.allPresets,
    this.newlyImportedCount = 0,
    this.failedCount = 0,
  });

  bool get hasErrors => failedCount > 0;
}

class PresetService {
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
  Future<String> exportPresetsJson() async {
    final customList = await loadCustomPresets();
    final jsonList = customList.map((p) => p.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// Imports custom presets from a JSON string with detailed diagnostics
  Future<PresetImportResult> importPresetsWithDiagnostics(String jsonString) async {
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

    int failedCount = 0;
    final List<CustomPreset> imported = [];
    for (final item in itemsList) {
      if (item is Map) {
        try {
          final mapItem = Map<String, dynamic>.from(item);
          final rawPreset = CustomPreset.fromMap(mapItem);

          final cleanName = rawPreset.name.trim();
          final safePreset = rawPreset.copyWith(
            name: cleanName.isNotEmpty
                ? (cleanName.length > 50 ? cleanName.substring(0, 50) : cleanName)
                : 'Custom Preset',
            modifier: rawPreset.modifier.clamp(-100, 100),
          );
          imported.add(safePreset);
        } catch (e, stackTrace) {
          failedCount++;
          LoggingService().logNonFatal(
            e,
            stackTrace,
            reason: 'Skipping malformed individual preset during JSON import',
          );
        }
      } else {
        failedCount++;
      }
    }

    if (imported.isEmpty) {
      final current = await loadCustomPresets();
      return PresetImportResult(
        allPresets: current,
        newlyImportedCount: 0,
        failedCount: failedCount,
      );
    }

    if (_cachedPresets == null) {
      await loadCustomPresets();
    }

    for (final newP in imported) {
      _cachedPresets!.removeWhere((p) => p.id == newP.id);
      _cachedPresets!.insert(0, newP);
    }

    _persistToDisk();
    return PresetImportResult(
      allPresets: List<CustomPreset>.from(_cachedPresets!),
      newlyImportedCount: imported.length,
      failedCount: failedCount,
    );
  }

  /// Imports custom presets from a JSON string with security & payload bounds
  Future<List<CustomPreset>> importPresetsJson(String jsonString) async {
    final result = await importPresetsWithDiagnostics(jsonString);
    return result.allPresets;
  }
}

