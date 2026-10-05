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
    final rawNodeId = map['node'] ?? map['nodeId'];
    if (rawNodeId == null || rawNodeId.toString().trim().isEmpty) {
      throw const FormatException('Missing required nodeId in HLC payload');
    }

    final rawPt = map['pt'] ?? map['physicalTime'];
    if (rawPt == null) {
      throw const FormatException('Missing required physicalTime in HLC payload');
    }

    final int pt;
    if (rawPt is num) {
      pt = rawPt.toInt();
    } else if (rawPt is String) {
      final parsed = int.tryParse(rawPt);
      if (parsed == null) {
        throw FormatException('Malformed physicalTime in HLC payload: $rawPt');
      }
      pt = parsed;
    } else {
      throw FormatException('Malformed physicalTime in HLC payload: $rawPt');
    }

    int parseLc(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return HybridLogicalClock(
      physicalTime: pt,
      logicalCounter: parseLc(map['lc'] ?? map['logicalCounter']),
      nodeId: rawNodeId.toString(),
    );
  }
}
