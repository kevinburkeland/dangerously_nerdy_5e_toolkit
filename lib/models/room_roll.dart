import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dice_roll.dart';

class RoomRoll {
  final String id;
  final String roomCode;
  final String playerName;
  final DateTime timestamp;
  final String formulaString;
  final int total;
  final List<int> individualRolls;
  final List<int>? droppedRolls;
  final bool isCrit;
  final bool isFumble;

  RoomRoll({
    required this.id,
    required this.roomCode,
    required this.playerName,
    required this.timestamp,
    required this.formulaString,
    required this.total,
    required this.individualRolls,
    this.droppedRolls,
    required this.isCrit,
    required this.isFumble,
  });

  factory RoomRoll.fromDiceRollResult({
    required String id,
    required String roomCode,
    required String playerName,
    required DiceRollResult result,
  }) {
    return RoomRoll(
      id: id,
      roomCode: roomCode,
      playerName: playerName,
      timestamp: result.timestamp,
      formulaString: result.formulaString,
      total: result.total,
      individualRolls: result.individualRolls,
      droppedRolls: result.droppedRolls,
      isCrit: result.isCrit,
      isFumble: result.isFumble,
    );
  }

  Map<String, dynamic> toMap({bool useFirestoreTimestamp = true}) {
    final expireDate = timestamp.add(const Duration(hours: 24));
    return {
      'id': id,
      'roomCode': roomCode,
      'playerName': playerName,
      'timestamp': useFirestoreTimestamp ? Timestamp.fromDate(timestamp) : timestamp.millisecondsSinceEpoch,
      'expireAt': useFirestoreTimestamp ? Timestamp.fromDate(expireDate) : expireDate.millisecondsSinceEpoch,
      'formulaString': formulaString,
      'total': total,
      'individualRolls': individualRolls,
      'droppedRolls': droppedRolls,
      'isCrit': isCrit,
      'isFumble': isFumble,
    };
  }

  factory RoomRoll.fromMap(Map<String, dynamic> map) {
    DateTime ts;
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is DateTime) {
      ts = rawTs;
    } else {
      ts = DateTime.now();
    }

    return RoomRoll(
      id: map['id'] as String? ?? '',
      roomCode: map['roomCode'] as String? ?? '',
      playerName: map['playerName'] as String? ?? 'Anonymous',
      timestamp: ts,
      formulaString: map['formulaString'] as String? ?? '',
      total: map['total'] as int? ?? 0,
      individualRolls: List<int>.from(map['individualRolls'] as List? ?? []),
      droppedRolls: map['droppedRolls'] != null ? List<int>.from(map['droppedRolls'] as List) : null,
      isCrit: map['isCrit'] as bool? ?? false,
      isFumble: map['isFumble'] as bool? ?? false,
    );
  }
}
