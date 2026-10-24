import 'dart:math';
import 'package:meta/meta.dart';

/// Overridable factory function for secure random instances (for testing platform failure).
@visibleForTesting
Random Function() secureRandomFactory = () => Random.secure();

/// Creates a cryptographically secure [Random] instance or fails closed.
Random createSecureRandom([Random Function()? factory]) {
  final create = factory ?? secureRandomFactory;
  try {
    return create();
  } catch (e) {
    throw UnsupportedError(
      'Secure random number generator is unavailable on this platform: $e',
    );
  }
}

/// Top-level cryptographically secure random number generator.
final Random secureRandom = createSecureRandom();
