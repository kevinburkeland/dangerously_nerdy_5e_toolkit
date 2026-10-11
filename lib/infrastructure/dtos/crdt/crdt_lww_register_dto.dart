import 'package:meta/meta.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'hybrid_logical_clock_dto.dart';

/// Data Transfer Object for [CrdtLwwRegister], providing generic serialization
/// and isolated fault tolerance for corrupted inner values.
@immutable
class CrdtLwwRegisterDto {
  static Map<String, dynamic> toMap<T>(
    CrdtLwwRegister<T> register,
    dynamic Function(T) valueEncoder,
  ) {
    return {
      'v': valueEncoder(register.value),
      'ts': HybridLogicalClockDto.toMap(register.timestamp),
    };
  }

  /// Parses [map] into [CrdtLwwRegister] strictly, throwing [FormatException]
  /// if timestamps or value fields are absent or malformed.
  static CrdtLwwRegister<T> parse<T>(
    Map<dynamic, dynamic> map,
    T Function(dynamic) valueDecoder,
  ) {
    final safeMap = Map<String, dynamic>.from(map);
    final rawTs = safeMap['ts'] ?? safeMap['timestamp'];
    if (rawTs is! Map) {
      throw const FormatException('CrdtLwwRegisterDto: missing or invalid timestamp.');
    }

    if (!safeMap.containsKey('v') && !safeMap.containsKey('value')) {
      throw const FormatException('CrdtLwwRegisterDto: missing "v" or "value" field.');
    }

    final safeTs = Map<String, dynamic>.from(rawTs);
    final timestamp = HybridLogicalClockDto.fromMap(safeTs);
    final rawValue =
        safeMap.containsKey('v') ? safeMap['v'] : safeMap['value'];
    final value = valueDecoder(rawValue);

    return CrdtLwwRegister<T>(value: value, timestamp: timestamp);
  }

  static CrdtLwwRegister<T>? fromMap<T>(
    Map<dynamic, dynamic> map,
    T Function(dynamic) valueDecoder,
  ) {
    try {
      return parse<T>(map, valueDecoder);
    } catch (_) {
      // Non-fatal ACL rejection: return null so corrupted register is safely dropped
      return null;
    }
  }
}
