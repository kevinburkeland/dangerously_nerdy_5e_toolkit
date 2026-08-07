import 'package:flutter/foundation.dart';
import '../models/room_roll.dart';
import 'dice_room_service.dart';

abstract class BaseRoomService {
  ValueNotifier<RoomSession?> get activeSessionNotifier;
  String? get activeRoomCode;
  String? get playerName;

  void joinRoom(String roomCode, String playerName);
  void leaveRoom();
  Stream<List<RoomRoll>> streamRoomRolls(String roomCode);
  Future<void> broadcastRoll(RoomRoll roll);
  String generateRoomCode();
}
