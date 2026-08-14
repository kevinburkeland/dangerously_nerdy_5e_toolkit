import '../models/custom_preset.dart';

/// Interface defining storage and persistence contract for user custom presets.
abstract class IPresetService {
  /// Loads custom user presets from storage or in-memory cache
  Future<List<CustomPreset>> loadCustomPresets();

  /// Saves a new custom preset to local storage and in-memory cache
  Future<List<CustomPreset>> savePreset(CustomPreset preset);

  /// Deletes a custom preset by ID from local storage and in-memory cache
  Future<List<CustomPreset>> deletePreset(String id);

  /// Exports custom presets to a formatted JSON string
  Future<String> exportPresetsJson();

  /// Imports custom presets from a JSON string with security & payload bounds
  Future<List<CustomPreset>> importPresetsJson(String jsonString);
}
