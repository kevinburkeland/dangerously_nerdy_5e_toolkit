import '../application/ports/log_sink.dart';

/// Pure Dart logging and crash-reporting facade.
///
/// Redacts PII (emails and room codes) before forwarding to the installed
/// [LogSink]. Calling any logging method before a sink is installed throws
/// [StateError] naming the call.
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  /// Creates a fresh [LoggingService] instance isolated from the singleton.
  LoggingService.isolated([this._sink]);

  LogSink? _sink;

  /// Installs the active [LogSink] on the shared [LoggingService] singleton.
  static void installSink(LogSink? sink) {
    _instance._sink = sink;
  }

  /// Returns the currently installed [LogSink], or `null` if none is installed.
  static LogSink? get installedSink => _instance._sink;

  LogSink _requireSink(String callName) {
    final sink = _sink;
    if (sink == null) {
      throw StateError(
        'LoggingService.$callName called before a LogSink was installed via LoggingService.installSink(...).',
      );
    }
    return sink;
  }

  /// Regex patterns for stripping sensitive user PII from crash logs
  static final RegExp _roomCodeRegex =
      RegExp(r'ROOM-[A-Z0-9]{4,30}', caseSensitive: false);
  static final RegExp _emailRegex =
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');

  /// Redacts sensitive information (room codes, emails, PII) from log messages
  String sanitizeMessage(String input) {
    var clean = input.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    clean = clean.replaceAll(_roomCodeRegex, 'ROOM-[REDACTED]');
    return clean;
  }

  /// Logs informational breadcrumb messages
  void logInfo(String message) {
    final sink = _requireSink('logInfo');
    final sanitized = sanitizeMessage(message);
    sink.info(sanitized);
  }

  /// Logs non-fatal warnings (e.g. network retries, offline sync fallback)
  void logWarning(String message, [dynamic error]) {
    final sink = _requireSink('logWarning');
    final sanitized = sanitizeMessage(message);
    sink.warning(sanitized, error);
  }

  /// Logs non-fatal exceptions (e.g. caught Firestore timeouts or parse failures).
  void logNonFatal(dynamic exception, StackTrace? stackTrace,
      {String? reason}) {
    final sink = _requireSink('logNonFatal');
    final sanitizedReason =
        reason != null ? sanitizeMessage(reason) : 'Non-fatal error caught';
    sink.nonFatal(
      exception,
      stackTrace,
      sanitizedReason: sanitizedReason,
    );
  }

  /// Logs critical unhandled crashes captured by global error zones.
  void logFatal(dynamic exception, StackTrace stackTrace, {String? reason}) {
    final sink = _requireSink('logFatal');
    final sanitizedReason =
        reason != null ? sanitizeMessage(reason) : 'Unhandled fatal error';
    sink.fatal(
      exception,
      stackTrace,
      sanitizedReason: sanitizedReason,
    );
  }
}
