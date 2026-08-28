import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logging_service.dart';

typedef AsyncWriteTask = Future<void> Function();

/// Asynchronous debounced persistence coordinator.
///
/// Prevents main-isolate I/O thrashing during high-frequency UI events
/// (such as slider adjustments, rapid HP changes, or quick form typing)
/// by batching disk writes until an idle window expires.
class DebouncedStorageService {
  static final DebouncedStorageService _instance = DebouncedStorageService._internal();
  factory DebouncedStorageService({LoggingService? logger}) {
    if (logger != null) {
      return DebouncedStorageService.custom(logger: logger);
    }
    return _instance;
  }
  DebouncedStorageService._internal() : _logger = LoggingService();
  DebouncedStorageService.custom({LoggingService? logger}) : _logger = logger ?? LoggingService();

  final LoggingService _logger;
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, AsyncWriteTask> _pendingTasks = {};

  /// Schedules an asynchronous write task with a debounce duration.
  /// Subsequent calls with the same [taskKey] within [duration] replace previous pending writes.
  void scheduleWrite(
    String taskKey,
    AsyncWriteTask task, {
    Duration duration = const Duration(milliseconds: 350),
  }) {
    _pendingTasks[taskKey] = task;
    _debounceTimers[taskKey]?.cancel();

    _debounceTimers[taskKey] = Timer(duration, () async {
      await flushKey(taskKey);
    });
  }

  /// Immediately executes and flushes a specific pending write task to disk.
  Future<void> flushKey(String taskKey) async {
    _debounceTimers[taskKey]?.cancel();
    _debounceTimers.remove(taskKey);

    final task = _pendingTasks.remove(taskKey);
    if (task != null) {
      try {
        await task();
      } catch (e, stackTrace) {
        _logger.logNonFatal(
          e,
          stackTrace,
          reason: 'Failed to execute debounced write task: $taskKey',
        );
      }
    }
  }

  /// Immediately flushes all pending write tasks across the entire application.
  /// Essential when the app pauses or detaches (e.g. `AppLifecycleState.paused`).
  Future<void> flushAll() async {
    final keys = List<String>.from(_pendingTasks.keys);
    for (final key in keys) {
      await flushKey(key);
    }
  }

  /// Cancels all pending tasks without writing (used for test teardown).
  @visibleForTesting
  void cancelAllForTesting() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _pendingTasks.clear();
  }

  /// Returns true if there are pending debounced tasks.
  bool get hasPendingTasks => _pendingTasks.isNotEmpty;
}
