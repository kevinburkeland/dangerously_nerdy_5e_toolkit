import 'dart:math';
import '../services/logging_service.dart';

/// Top-level cryptographically secure random number generator.
final Random secureRandom = _initSecureRandom();

Random _initSecureRandom() {
  try {
    return Random.secure();
  } catch (e, stackTrace) {
    LoggingService().logNonFatal(
      e,
      stackTrace,
      reason: 'Cryptographic Random.secure() unavailable on platform; falling back to standard Random',
    );
    return Random();
  }
}

