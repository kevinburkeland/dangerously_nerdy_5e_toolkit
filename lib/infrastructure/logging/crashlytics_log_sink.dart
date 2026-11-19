import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../application/ports/log_sink.dart';

/// Concrete [LogSink] that outputs to [debugPrint] in debug builds and forwards
/// non-fatal and fatal errors to Firebase Crashlytics on non-web platforms.
class CrashlyticsLogSink implements LogSink {
  const CrashlyticsLogSink();

  @override
  void info(String sanitizedMessage) {
    if (kDebugMode) {
      debugPrint('[INFO] $sanitizedMessage');
    }
  }

  @override
  void warning(String sanitizedMessage, [Object? error]) {
    if (kDebugMode) {
      debugPrint(
          '[WARNING] $sanitizedMessage ${error != null ? "--> $error" : ""}');
    }
  }

  @override
  void nonFatal(
    Object? exception,
    StackTrace? stackTrace, {
    required String sanitizedReason,
  }) {
    if (kDebugMode) {
      debugPrint('[NON-FATAL] $sanitizedReason: $exception');
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    }
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.recordError(
          exception,
          stackTrace,
          reason: sanitizedReason,
          fatal: false,
        );
      } catch (_) {
        // intentional: Crashlytics not initialized (e.g. headless unit tests or offline run)
      }
    }
  }

  @override
  void fatal(
    Object? exception,
    StackTrace stackTrace, {
    required String sanitizedReason,
  }) {
    if (kDebugMode) {
      debugPrint('[FATAL CRASH] $sanitizedReason: $exception');
      debugPrint(stackTrace.toString());
    }
    if (!kIsWeb) {
      try {
        FirebaseCrashlytics.instance.recordError(
          exception,
          stackTrace,
          reason: sanitizedReason,
          fatal: true,
        );
      } catch (_) {
        // intentional: Crashlytics not initialized during headless tests or offline run
      }
    }
  }
}
