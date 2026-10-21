import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';

class CreateRoomCall {
  final String roomCode;
  final Map<String, dynamic> data;

  CreateRoomCall({required this.roomCode, required this.data});
}

class DeleteRoomCall {
  final String roomCode;
  final String? hostKey;

  DeleteRoomCall({required this.roomCode, this.hostKey});
}

class TouchRoomLeaseCall {
  final String roomCode;
  final Map<String, dynamic> data;
  final bool createIfAbsent;

  TouchRoomLeaseCall({
    required this.roomCode,
    required this.data,
    required this.createIfAbsent,
  });
}

/// In-memory recording fake for [IRoomDocumentPort] used in unit and integration tests.
class RecordingRoomDocumentPort implements IRoomDocumentPort {
  final List<CreateRoomCall> createRoomCalls = [];
  final List<DeleteRoomCall> deleteRoomCalls = [];
  final List<TouchRoomLeaseCall> touchRoomLeaseCalls = [];

  final Set<String> existingRooms = {};
  Exception? shouldThrowOnCreate;
  Exception? shouldThrowOnDelete;
  Exception? shouldThrowOnTouch;

  @override
  Future<void> createRoom({
    required String roomCode,
    required Map<String, dynamic> data,
  }) async {
    createRoomCalls.add(CreateRoomCall(roomCode: roomCode, data: data));
    if (shouldThrowOnCreate != null) {
      throw shouldThrowOnCreate!;
    }
    final clean = roomCode.trim().toUpperCase();
    if (existingRooms.contains(clean)) {
      throw RoomAlreadyExistsException('room code already in use: $clean');
    }
    existingRooms.add(clean);
    roomDataByCode[clean] = Map<String, dynamic>.from(data);
  }

  @override
  Future<RoomDeleteOutcome> deleteRoomWithHostProof({
    required String roomCode,
    String? hostKey,
  }) async {
    deleteRoomCalls.add(DeleteRoomCall(roomCode: roomCode, hostKey: hostKey));
    if (shouldThrowOnDelete != null) {
      throw shouldThrowOnDelete!;
    }
    final clean = roomCode.trim().toUpperCase();
    roomDataByCode.remove(clean);
    final wasPresent = existingRooms.remove(clean);
    return wasPresent ? RoomDeleteOutcome.deleted : RoomDeleteOutcome.alreadyGone;
  }

  @override
  Future<void> touchRoomLease({
    required String roomCode,
    required Map<String, dynamic> data,
    bool createIfAbsent = false,
  }) async {
    touchRoomLeaseCalls.add(TouchRoomLeaseCall(
      roomCode: roomCode,
      data: data,
      createIfAbsent: createIfAbsent,
    ));
    if (shouldThrowOnTouch != null) {
      throw shouldThrowOnTouch!;
    }
    final clean = roomCode.trim().toUpperCase();
    if (!existingRooms.contains(clean) && createIfAbsent) {
      existingRooms.add(clean);
      roomDataByCode[clean] = Map<String, dynamic>.from(data);
    }
  }

  final Map<String, Map<String, dynamic>> roomDataByCode = {};
  Exception? shouldThrowOnGet;

  @override
  Future<Map<String, dynamic>?> getRoomDocument({
    required String roomCode,
  }) async {
    if (shouldThrowOnGet != null) {
      throw shouldThrowOnGet!;
    }
    final clean = roomCode.trim().toUpperCase();
    return roomDataByCode[clean];
  }
}
