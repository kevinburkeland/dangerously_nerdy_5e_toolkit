import 'dart:math';
import '../services/logging_service.dart';

/// Top-level cryptographically secure random number generator.
final Random secureRandom = _initSecureRandom();

Random _initSecureRandom() {
  try {
    return Random.secure();
  } catch (e) {
    LoggingService().logWarning(
      'Cryptographic secure random unavailable on platform; falling back to standard Random',
      e,
    );
    return Random();
  }
}

/// Backward-compatibility wrapper for legacy call sites.
@Deprecated('Use top-level secureRandom directly instead of SecureRng.instance')
abstract final class SecureRng {
  /// Global cryptographically secure Random instance
  static Random get instance => secureRandom;
}
