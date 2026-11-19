import 'package:dangerously_nerdy_5e_toolkit/application/ports/log_sink.dart';

class RecordedWarning {
  final String sanitizedMessage;
  final Object? error;

  const RecordedWarning(this.sanitizedMessage, this.error);
}

class RecordedError {
  final Object? exception;
  final StackTrace? stackTrace;
  final String sanitizedReason;
  final bool fatal;

  const RecordedError({
    required this.exception,
    required this.stackTrace,
    required this.sanitizedReason,
    required this.fatal,
  });
}

/// Shared recording [LogSink] installed in `test/flutter_test_config.dart`.
class RecordingLogSink implements LogSink {
  final List<String> infoMessages = <String>[];
  final List<RecordedWarning> warnings = <RecordedWarning>[];
  final List<RecordedError> nonFatals = <RecordedError>[];
  final List<RecordedError> fatals = <RecordedError>[];

  void Function(Object? exception, StackTrace? stackTrace, String? reason)?
      onNonFatal;

  void clear() {
    infoMessages.clear();
    warnings.clear();
    nonFatals.clear();
    fatals.clear();
  }

  @override
  void info(String sanitizedMessage) {
    infoMessages.add(sanitizedMessage);
  }

  @override
  void warning(String sanitizedMessage, [Object? error]) {
    warnings.add(RecordedWarning(sanitizedMessage, error));
  }

  @override
  void nonFatal(
    Object? exception,
    StackTrace? stackTrace, {
    required String sanitizedReason,
  }) {
    nonFatals.add(
      RecordedError(
        exception: exception,
        stackTrace: stackTrace,
        sanitizedReason: sanitizedReason,
        fatal: false,
      ),
    );
    onNonFatal?.call(exception, stackTrace, sanitizedReason);
  }

  @override
  void fatal(
    Object? exception,
    StackTrace stackTrace, {
    required String sanitizedReason,
  }) {
    fatals.add(
      RecordedError(
        exception: exception,
        stackTrace: stackTrace,
        sanitizedReason: sanitizedReason,
        fatal: true,
      ),
    );
  }
}

/// Global recording sink installed for tests by `test/flutter_test_config.dart`.
final RecordingLogSink testLogSink = RecordingLogSink();
