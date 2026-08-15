import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Logging and crash reporting wrapper.
/// Outputs to [debugPrint] in debug builds. Forwards errors to
/// FirebaseCrashlytics on non-web platforms (Crashlytics does not support web).
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  /// Regex patterns for stripping sensitive user PII from crash logs
  static final RegExp _roomCodeRegex = RegExp(r'ROOM-[A-Z0-9]{4,30}', caseSensitive: false);
  static final RegExp _emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');

  /// Redacts sensitive information (room codes, emails, PII) from log messages
  String sanitizeMessage(String input) {
    var clean = input.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    clean = clean.replaceAll(_roomCodeRegex, 'ROOM-[REDACTED]');
    return clean;
  }

  /// Logs informational breadcrumb messages
  void logInfo(String message) {
    final sanitized = sanitizeMessage(message);
    if (kDebugMode) {
      debugPrint('[INFO] $sanitized');
    }
  }

  /// Logs non-fatal warnings (e.g. network retries, offline sync fallback)
  void logWarning(String message, [dynamic error]) {
    final sanitized = sanitizeMessage(message);
    if (kDebugMode) {
      debugPrint('[WARNING] $sanitized ${error != null ? "--> $error" : ""}');
    }
  }

  /// Logs non-fatal exceptions (e.g. caught Firestore timeouts or parse failures).
  /// Forwards to FirebaseCrashlytics on non-web platforms.
  void logNonFatal(dynamic exception, StackTrace? stackTrace, {String? reason}) {
    final sanitizedReason = reason != null ? sanitizeMessage(reason) : 'Non-fatal error caught';
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
        // Crashlytics not initialized (e.g. headless unit tests or offline run)
      }
    }
  }

  /// Logs critical unhandled crashes captured by global error zones.
  /// Forwards to FirebaseCrashlytics on non-web platforms.
  void logFatal(dynamic exception, StackTrace stackTrace, {String? reason}) {
    final sanitizedReason = reason != null ? sanitizeMessage(reason) : 'Unhandled fatal error';
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
        // Crashlytics not initialized
      }
    }
  }
}
