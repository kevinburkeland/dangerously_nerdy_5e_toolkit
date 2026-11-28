import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();
const V4Options _cryptoV4Options = V4Options(null, CryptoRNG());

/// Generates a cryptographically random UUID v4 string, optionally prefixed
/// with [prefix].
String newOpaqueId([String prefix = '']) {
  final id = _uuid.v4(config: _cryptoV4Options);
  return prefix.isEmpty ? id : '$prefix$id';
}
