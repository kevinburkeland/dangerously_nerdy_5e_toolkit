import 'package:meta/meta.dart';
import '../../../domain/crdt/hybrid_logical_clock.dart';

/// Data Transfer Object for [HybridLogicalClock], handling serialization and fault-tolerant parsing.
@immutable
class HybridLogicalClockDto {
  static Map<String, dynamic> toMap(HybridLogicalClock hlc) {
    return {
      'pt': hlc.physicalTime,
      'lc': hlc.logicalCounter,
      'node': hlc.nodeId,
    };
  }

  static HybridLogicalClock fromMap(Map<dynamic, dynamic> map) {
    return HybridLogicalClock(
      physicalTime: _asInt(map['pt'], fallback: DateTime.now().toUtc().millisecondsSinceEpoch),
      logicalCounter: _asInt(map['lc'], fallback: 0),
      nodeId: map['node']?.toString() ?? 'unknown_node',
    );
  }

  static int _asInt(dynamic val, {required int fallback}) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }
}
