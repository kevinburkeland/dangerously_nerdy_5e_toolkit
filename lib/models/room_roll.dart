export 'package:vtt_engine_core/models/room_roll.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vtt_engine_core/models/room_roll.dart';

// Auto-wire Firestore timestamp encoder for infrastructure / UI writes
final bool firestoreRollEncoderInitialized = () {
  RoomRoll.firestoreTimestampEncoder = (dt) => Timestamp.fromDate(dt);
  return true;
}();
