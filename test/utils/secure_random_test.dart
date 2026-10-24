import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/utils/secure_random.dart';

void main() {
  group('SecureRandom fail-closed enforcement', () {
    tearDown(() {
      // Restore default factory after any override test
      secureRandomFactory = () => Random.secure();
    });

    test('injecting a throwing factory fails closed with UnsupportedError', () {
      final customError = StateError('Entropy generator missing');
      expect(
        () => createSecureRandom(() => throw customError),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('Secure random number generator is unavailable on this platform'),
          ),
        ),
      );
    });

    test('overriding secureRandomFactory fails closed with UnsupportedError', () {
      secureRandomFactory = () => throw Exception('OS crypto device failure');
      expect(
        () => createSecureRandom(),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('Secure random number generator is unavailable on this platform'),
          ),
        ),
      );
    });

    test('default factory produces a valid Random instance', () {
      final rng = createSecureRandom();
      expect(rng, isNotNull);
      final val = rng.nextInt(100);
      expect(val, inInclusiveRange(0, 99));
    });

    test('source check: lib/utils/secure_random.dart contains zero non-secure Random() instantiations', () {
      final file = File('lib/utils/secure_random.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/utils/secure_random.dart must exist');
      final lines = file.readAsLinesSync();

      // Matches standalone invocation of Random(...) without .secure
      final insecureRandomPattern = RegExp(r'(?<![a-zA-Z0-9_\.])Random\s*\(');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().startsWith('import ')) continue;

        expect(
          insecureRandomPattern.hasMatch(line),
          isFalse,
          reason: 'Line ${i + 1} contains an insecure Random() invocation: "$line"',
        );
      }

      // Negative check verifying pattern catches insecure fallback
      const insecureSample = 'return Random();';
      expect(insecureRandomPattern.hasMatch(insecureSample), isTrue);
    });
  });
}
