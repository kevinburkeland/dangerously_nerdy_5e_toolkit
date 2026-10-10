import 'package:meta/meta.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';

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
    return HybridLogicalClock.fromMap(map);
  }
}
