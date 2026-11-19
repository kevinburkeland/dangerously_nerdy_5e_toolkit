/// Pure Dart sink port for [LoggingService].
///
/// Every message or reason passed to this port has already been sanitized by
/// [LoggingService.sanitizeMessage].
abstract class LogSink {
  void info(String sanitizedMessage);

  void warning(String sanitizedMessage, [Object? error]);

  void nonFatal(
    Object? exception,
    StackTrace? stackTrace, {
    required String sanitizedReason,
  });

  void fatal(
    Object? exception,
    StackTrace stackTrace, {
    required String sanitizedReason,
  });
}
