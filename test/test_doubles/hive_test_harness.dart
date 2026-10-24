import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';

class _InMemoryTestBox extends Fake implements Box<dynamic> {
  final String _name;
  final Map<dynamic, dynamic> _data = {};
  bool _isOpen = true;

  _InMemoryTestBox(this._name);

  @override
  String get name => _name;

  @override
  bool get isOpen => _isOpen;

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _data[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    _data.addAll(entries);
  }

  @override
  Future<void> delete(dynamic key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final k in keys) {
      _data.remove(k);
    }
  }

  @override
  Iterable<dynamic> get keys => _data.keys;

  @override
  Iterable<dynamic> get values => _data.values;

  @override
  Future<int> clear() async {
    final count = _data.length;
    _data.clear();
    return count;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }
}

/// Shared test double helper that initialises real Hive boxes in a temporary directory
/// or in-memory box doubles for FakeAsync/testWidgets contexts, and binds [AppDatabaseService.instance]
/// through its constructor seams.
class HiveTestHarness {
  Directory? _tempDir;
  Directory get tempDir => _tempDir!;

  /// Initializes real Hive boxes in a fresh temp directory.
  Future<void> setUp([String prefix = 'hive_test_']) async {
    _tempDir = await Directory.systemTemp.createTemp(prefix);
    final db = AppDatabaseService.custom(
      hiveInit: () async => Hive.init(_tempDir!.path),
      hiveBoxOpener: Hive.openBox<dynamic>,
    );
    AppDatabaseService.instance = db;
    await db.init();
  }

  /// Initializes in-memory box doubles to safely run inside `testWidgets` / `FakeAsync` zones
  /// without VM file I/O blocking.
  Future<void> setUpInMemory() async {
    final Map<String, _InMemoryTestBox> boxes = {
      for (final name in [
        AppDatabaseService.boxCharacters,
        AppDatabaseService.boxCampaignProfiles,
        AppDatabaseService.boxHomebrew,
        AppDatabaseService.boxHomebrewRaw,
        AppDatabaseService.boxMetadata,
      ])
        name: _InMemoryTestBox(name)
    };
    final db = AppDatabaseService.custom(
      hiveInit: () async {},
      hiveBoxOpener: (name) async => boxes[name] ?? _InMemoryTestBox(name),
    );
    AppDatabaseService.instance = db;
    await db.init();
  }

  /// Resets boxes, closes Hive, deletes the temp directory, and restores default singleton.
  Future<void> tearDown() async {
    try {
      if (AppDatabaseService.instance.isInitialized) {
        await AppDatabaseService.instance.resetForTesting();
      }
    } catch (_) {}
    await Hive.close();
    if (_tempDir != null && _tempDir!.existsSync()) {
      try {
        await _tempDir!.delete(recursive: true);
      } catch (_) {}
    }
    AppDatabaseService.instance = AppDatabaseService();
  }
}
