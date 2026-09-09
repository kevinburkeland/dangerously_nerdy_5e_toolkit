import 'package:meta/meta.dart';
import '../../../domain/crdt/crdt_lww_register.dart';
import '../../../domain/crdt/crdt_or_set.dart';
import '../../../domain/crdt/hybrid_logical_clock.dart';
import 'crdt_lww_register_dto.dart';
import 'hybrid_logical_clock_dto.dart';

/// Data Transfer Object for [CrdtOrSet], providing fault-tolerant serialization
/// and deserialization that isolates corrupt items and tombstones.
@immutable
class CrdtOrSetDto {
  static Map<String, dynamic> toMap<T>(
    CrdtOrSet<T> orSet,
    dynamic Function(T) valueEncoder,
  ) {
    final itemsMap = <String, dynamic>{};
    orSet.items.forEach((key, reg) {
      itemsMap[key] = CrdtLwwRegisterDto.toMap(reg, valueEncoder);
    });

    final tombstonesMap = <String, dynamic>{};
    orSet.tombstones.forEach((key, ts) {
      tombstonesMap[key] = HybridLogicalClockDto.toMap(ts);
    });

    return {
      'items': itemsMap,
      'tombstones': tombstonesMap,
    };
  }

  static CrdtOrSet<T> fromMap<T>(
    Map<dynamic, dynamic> map,
    T Function(dynamic) valueDecoder,
  ) {
    final items = <String, CrdtLwwRegister<T>>{};
    final tombstones = <String, HybridLogicalClock>{};

    final rawItems = map['items'];
    if (rawItems is Map) {
      rawItems.forEach((key, val) {
        if (val is Map) {
          try {
            final reg = CrdtLwwRegisterDto.fromMap<T>(val, valueDecoder);
            if (reg != null) {
              items[key.toString()] = reg;
            }
          } catch (_) {
            // Skip corrupted item
          }
        }
      });
    }

    final rawTombstones = map['tombstones'];
    if (rawTombstones is Map) {
      rawTombstones.forEach((key, val) {
        if (val is Map) {
          try {
            tombstones[key.toString()] = HybridLogicalClockDto.fromMap(val);
          } catch (_) {
            // Skip corrupted tombstone
          }
        }
      });
    }

    return CrdtOrSet<T>(items: items, tombstones: tombstones);
  }
}
