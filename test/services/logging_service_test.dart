import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/logging_service.dart';
import '../test_doubles/recording_log_sink.dart';

void main() {
  group('LoggingService PII Redaction Tests', () {
    final logger = LoggingService();

    test('Redacts room codes from log messages', () {
      const rawMsg = 'Failed to sync with room ROOM-A1B2C3 in session';
      final sanitized = logger.sanitizeMessage(rawMsg);
      expect(sanitized, 'Failed to sync with room ROOM-[REDACTED] in session');
    });

    test('Redacts email addresses from log messages', () {
      const rawMsg =
          'User user.name@example.com encountered connection timeout';
      final sanitized = logger.sanitizeMessage(rawMsg);
      expect(sanitized, 'User [REDACTED_EMAIL] encountered connection timeout');
    });

    test('Leaves non-PII technical log messages unchanged', () {
      const rawMsg = 'Firestore connection retrying in 500ms';
      final sanitized = logger.sanitizeMessage(rawMsg);
      expect(sanitized, 'Firestore connection retrying in 500ms');
    });
  });

  group('Fix 6.2: LoggingService pure LogSink port contract', () {
    test('fresh LoggingService with no sink throws StateError naming the call', () {
      final fresh = LoggingService.isolated();
      expect(
        () => fresh.logInfo('hello'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('logInfo'),
          ),
        ),
      );
      expect(
        () => fresh.logWarning('warn'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('logWarning'),
          ),
        ),
      );
      expect(
        () => fresh.logNonFatal(Exception('e'), StackTrace.current),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('logNonFatal'),
          ),
        ),
      );
      expect(
        () => fresh.logFatal(Exception('e'), StackTrace.current),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('logFatal'),
          ),
        ),
      );
    });

    test('with a recording sink, each level reaches the sink once with room code and email sanitized', () {
      final sink = RecordingLogSink();
      final logger = LoggingService.isolated(sink);
      const raw = 'Room ROOM-ABCD12 failed for player alice@example.com';
      const expected = 'Room ROOM-[REDACTED] failed for player [REDACTED_EMAIL]';
      final err = StateError('boom');
      final st = StackTrace.current;

      logger.logInfo(raw);
      logger.logWarning(raw, err);
      logger.logNonFatal(err, st, reason: raw);
      logger.logFatal(err, st, reason: raw);

      expect(sink.infoMessages, equals([expected]));
      expect(sink.warnings, hasLength(1));
      expect(sink.warnings.single.sanitizedMessage, equals(expected));
      expect(sink.warnings.single.error, same(err));

      expect(sink.nonFatals, hasLength(1));
      expect(sink.nonFatals.single.sanitizedReason, equals(expected));
      expect(sink.nonFatals.single.exception, same(err));
      expect(sink.nonFatals.single.fatal, isFalse);

      expect(sink.fatals, hasLength(1));
      expect(sink.fatals.single.sanitizedReason, equals(expected));
      expect(sink.fatals.single.exception, same(err));
      expect(sink.fatals.single.fatal, isTrue);
    });
  });
}
