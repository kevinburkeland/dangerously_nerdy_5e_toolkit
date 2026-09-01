import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../logging_service.dart';

/// Centralized local NoSQL database service wrapping Hive (IndexedDB on Web, Disk on Native).
///
/// Bypasses the 5MB browser localStorage quota, providing structured high-capacity storage
/// for Character rosters, Campaign Profiles, and extensive Homebrew Compendiums.
class AppDatabaseService {
  static const String boxCharacters = 'dn_characters_v1';
  static const String boxCampaignProfiles = 'dn_campaign_profiles_v1';
  static const String boxHomebrew = 'dn_homebrew_store_v1';
  static const String boxHomebrewRaw = 'dn_homebrew_raw_v1';

  static final AppDatabaseService instance = AppDatabaseService._internal();
  factory AppDatabaseService({LoggingService? logger}) {
    if (logger != null) {
      return AppDatabaseService.custom(logger: logger);
    }
    return instance;
  }
  AppDatabaseService._internal() : _logger = LoggingService();
  AppDatabaseService.custom({LoggingService? logger})
      : _logger = logger ?? LoggingService();

  final LoggingService _logger;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  // In-memory fallback stores for test isolation or uninitialized edge cases
  final Map<String, Map<String, dynamic>> _inMemoryFallback = {};

  /// Initializes the local database engine and opens core domain boxes.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();
      await Future.wait([
        Hive.openBox<dynamic>(boxCharacters),
        Hive.openBox<dynamic>(boxCampaignProfiles),
        Hive.openBox<dynamic>(boxHomebrew),
        Hive.openBox<dynamic>(boxHomebrewRaw),
      ]);
      _initialized = true;
      _logger.logInfo('AppDatabaseService initialized successfully with Hive/IndexedDB.');
    } catch (e, st) {
      _logger.logFatal(
        e,
        st,
        reason: 'Failed to initialize Hive database engine; falling back to in-memory store',
      );
      _initialized = true;
    }
  }

  /// Returns whether the underlying Hive box is open.
  bool isBoxOpen(String boxName) => Hive.isBoxOpen(boxName);

  /// Synchronously or asynchronously retrieves a box by name, with safe in-memory fallback.
  Box<dynamic>? _getBox(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<dynamic>(boxName);
    }
    return null;
  }

  /// Retrieves a value by [key] from [boxName].
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    final box = _getBox(boxName);
    if (box != null) {
      return box.get(key, defaultValue: defaultValue);
    }
    return _inMemoryFallback[boxName]?[key] ?? defaultValue;
  }

  /// Asynchronously writes a [key]-[value] pair to [boxName].
  Future<void> put(String boxName, String key, dynamic value) async {
    final box = _getBox(boxName);
    if (box != null) {
      await box.put(key, value);
    } else {
      _inMemoryFallback.putIfAbsent(boxName, () => {})[key] = value;
    }
  }

  /// Deletes a [key] from [boxName].
  Future<void> delete(String boxName, String key) async {
    final box = _getBox(boxName);
    if (box != null) {
      await box.delete(key);
    } else {
      _inMemoryFallback[boxName]?.remove(key);
    }
  }

  /// Returns all keys within [boxName].
  List<String> getKeys(String boxName) {
    final box = _getBox(boxName);
    if (box != null) {
      return box.keys.map((k) => k.toString()).toList();
    }
    return _inMemoryFallback[boxName]?.keys.toList() ?? <String>[];
  }

  /// Returns all values within [boxName].
  List<dynamic> getValues(String boxName) {
    final box = _getBox(boxName);
    if (box != null) {
      return box.values.toList();
    }
    return _inMemoryFallback[boxName]?.values.toList() ?? <dynamic>[];
  }

  /// Clears all entries in [boxName].
  Future<void> clearBox(String boxName) async {
    final box = _getBox(boxName);
    if (box != null) {
      await box.clear();
    }
    _inMemoryFallback[boxName]?.clear();
  }

  /// Resets all stores for test isolation.
  @visibleForTesting
  Future<void> resetForTesting() async {
    _inMemoryFallback.clear();
    for (final boxName in [
      boxCharacters,
      boxCampaignProfiles,
      boxHomebrew,
      boxHomebrewRaw,
    ]) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<dynamic>(boxName).clear();
      }
    }
  }
}
