import 'dart:math';

class SecureRng {
  static final Random _rng = _init();

  static Random _init() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Global cryptographically secure Random instance
  static Random get instance => _rng;
}
