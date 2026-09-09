import 'package:meta/meta.dart';
import '../../../domain/crdt/crdt_lww_register.dart';
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

  static CrdtLwwRegister<T>? fromMap<T>(
    Map<dynamic, dynamic> map,
    T Function(dynamic) valueDecoder,
  ) {
    try {
      final safeMap = Map<String, dynamic>.from(map);
      final rawTs = safeMap['ts'];
      if (rawTs is! Map) return null;

      final safeTs = Map<String, dynamic>.from(rawTs);
      final timestamp = HybridLogicalClockDto.fromMap(safeTs);
      final value = valueDecoder(safeMap['v']);

      return CrdtLwwRegister<T>(value: value, timestamp: timestamp);
    } catch (_) {
      // Non-fatal ACL rejection: return null so corrupted register is safely dropped
      return null;
    }
  }
}
