import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../logging_service.dart';

/// Exception thrown when local durable storage fails to initialize or a required box is not open.
class StorageUnavailableException implements Exception {
  final Object cause;
  final StackTrace? stackTrace;
  final String? boxName;

  const StorageUnavailableException(this.cause, [this.stackTrace, this.boxName]);

  @override
  String toString() =>
      'StorageUnavailableException: Failed to access durable storage${boxName != null ? ' (box: $boxName)' : ''}: $cause';
}

typedef HiveInitFn = Future<void> Function();
typedef HiveBoxOpener = Future<Box<dynamic>> Function(String name);

/// Centralized local NoSQL database service wrapping Hive (IndexedDB on Web, Disk on Native).
///
/// Bypasses the 5MB browser localStorage quota, providing structured high-capacity storage
/// for Character rosters, Campaign Profiles, and extensive Homebrew Compendiums.
class AppDatabaseService {
  static const String boxCharacters = 'dn_characters_v1';
  static const String boxCampaignProfiles = 'dn_campaign_profiles_v1';
  static const String boxHomebrew = 'dn_homebrew_store_v1';
  static const String boxHomebrewRaw = 'dn_homebrew_raw_v1';
  static const String boxMetadata = 'dn_metadata_v1';

  /// Deprecated historical key for persisted device identity.
  /// Architectural Invariant (Pass 1.3): Must NEVER be used as the active CRDT writer [ReplicaId].
  static const String keyReplicaId = 'dn_replica_id';

  static AppDatabaseService _instance = AppDatabaseService._internal();
  static AppDatabaseService get instance => _instance;

  @visibleForTesting
  static set instance(AppDatabaseService s) => _instance = s;

  factory AppDatabaseService({
    LoggingService? logger,
    HiveInitFn? hiveInit,
    HiveBoxOpener? hiveBoxOpener,
  }) {
    if (logger != null || hiveInit != null || hiveBoxOpener != null) {
      return AppDatabaseService.custom(
        logger: logger,
        hiveInit: hiveInit,
        hiveBoxOpener: hiveBoxOpener,
      );
    }
    return instance;
  }

  AppDatabaseService._internal()
      : _logger = LoggingService(),
        _hiveInit = Hive.initFlutter,
        _hiveBoxOpener = Hive.openBox<dynamic>;

  AppDatabaseService.custom({
    LoggingService? logger,
    HiveInitFn? hiveInit,
    HiveBoxOpener? hiveBoxOpener,
  })  : _logger = logger ?? LoggingService(),
        _hiveInit = hiveInit ?? Hive.initFlutter,
        _hiveBoxOpener = hiveBoxOpener ?? Hive.openBox<dynamic>;

  final LoggingService _logger;
  final HiveInitFn _hiveInit;
  final HiveBoxOpener _hiveBoxOpener;
  final Map<String, Box<dynamic>> _openBoxes = {};
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initializes the local database engine and opens core domain boxes.
  Future<void> init() async {
    if (_initialized) return;

    try {
      await _hiveInit();
      final opened = await Future.wait([
        _hiveBoxOpener(boxCharacters),
        _hiveBoxOpener(boxCampaignProfiles),
        _hiveBoxOpener(boxHomebrew),
        _hiveBoxOpener(boxHomebrewRaw),
        _hiveBoxOpener(boxMetadata),
      ]);
      _openBoxes[boxCharacters] = opened[0];
      _openBoxes[boxCampaignProfiles] = opened[1];
      _openBoxes[boxHomebrew] = opened[2];
      _openBoxes[boxHomebrewRaw] = opened[3];
      _openBoxes[boxMetadata] = opened[4];
      _initialized = true;
      _logger.logInfo(
          'AppDatabaseService initialized successfully with Hive/IndexedDB.');
    } catch (e, st) {
      _initialized = false;
      _logger.logFatal(
        e,
        st,
        reason:
            'Failed to initialize Hive database engine; storage is unavailable',
      );
      throw StorageUnavailableException(e, st);
    }
  }

  /// Returns whether the underlying Hive box is open.
  bool isBoxOpen(String boxName) =>
      (_openBoxes[boxName]?.isOpen ?? false) || Hive.isBoxOpen(boxName);

  Box<dynamic> _requireBox(String boxName) {
    if (!_initialized) {
      throw StorageUnavailableException(
        StateError('Storage is unavailable: box "$boxName" is not open'),
        StackTrace.current,
        boxName,
      );
    }
    final box = _openBoxes[boxName] ??
        (Hive.isBoxOpen(boxName) ? Hive.box<dynamic>(boxName) : null);
    if (box == null || !box.isOpen) {
      throw StorageUnavailableException(
        StateError('Storage is unavailable: box "$boxName" is not open'),
        StackTrace.current,
        boxName,
      );
    }
    return box;
  }

  /// Retrieves a value by [key] from [boxName].
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    final box = _requireBox(boxName);
    return box.get(key, defaultValue: defaultValue);
  }

  /// Asynchronously writes a [key]-[value] pair to [boxName].
  Future<void> put(String boxName, String key, dynamic value) async {
    final box = _requireBox(boxName);
    await box.put(key, value);
  }

  /// Asynchronously writes multiple [entries] to [boxName] atomically.
  Future<void> putAll(String boxName, Map<String, dynamic> entries) async {
    final box = _requireBox(boxName);
    await box.putAll(entries);
  }

  /// Deletes a [key] from [boxName].
  Future<void> delete(String boxName, String key) async {
    final box = _requireBox(boxName);
    await box.delete(key);
  }

  /// Deletes multiple [keys] from [boxName] atomically.
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    final box = _requireBox(boxName);
    await box.deleteAll(keys);
  }

  /// Returns all keys within [boxName].
  List<String> getKeys(String boxName) {
    final box = _requireBox(boxName);
    return box.keys.map((k) => k.toString()).toList();
  }

  /// Returns all values within [boxName].
  List<dynamic> getValues(String boxName) {
    final box = _requireBox(boxName);
    return box.values.toList();
  }

  /// Clears all entries in [boxName].
  Future<void> clearBox(String boxName) async {
    final box = _requireBox(boxName);
    await box.clear();
  }

  /// Closes all open Hive boxes and marks storage as uninitialized.
  Future<void> close() async {
    for (final box in _openBoxes.values) {
      if (box.isOpen) {
        await box.close();
      }
    }
    _openBoxes.clear();
    _initialized = false;
  }

  /// Resets all stores for test isolation.
  @visibleForTesting
  Future<void> resetForTesting() async {
    for (final boxName in [
      boxCharacters,
      boxCampaignProfiles,
      boxHomebrew,
      boxHomebrewRaw,
      boxMetadata,
    ]) {
      final box = _openBoxes[boxName] ??
          (Hive.isBoxOpen(boxName) ? Hive.box<dynamic>(boxName) : null);
      if (box != null && box.isOpen) {
        await box.clear();
      }
    }
  }
}
