import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/logging_service.dart';

void main() {
  group('LoggingService PII Redaction Tests', () {
    final logger = LoggingService();

    test('Redacts room codes from log messages', () {
      const rawMsg = 'Failed to sync with room ROOM-A1B2C3 in session';
      final sanitized = logger.sanitizeMessage(rawMsg);
      expect(sanitized, 'Failed to sync with room ROOM-[REDACTED] in session');
    });

    test('Redacts email addresses from log messages', () {
      const rawMsg = 'User user.name@example.com encountered connection timeout';
      final sanitized = logger.sanitizeMessage(rawMsg);
      expect(sanitized, 'User [REDACTED_EMAIL] encountered connection timeout');
    });

    test('Leaves non-PII technical log messages unchanged', () {
      const rawMsg = 'Firestore connection retrying in 500ms';
      final sanitized = logger.sanitizeMessage(rawMsg);
      expect(sanitized, 'Firestore connection retrying in 500ms');
    });
  });
}
