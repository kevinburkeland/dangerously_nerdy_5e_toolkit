/// Abstract port defining room-document persistence operations
/// for lobby creation, lease renewals, and host-proven deletions.
abstract class IRoomDocumentPort {
  /// Writes a new room document. Fails (e.g. throws [RoomAlreadyExistsException])
  /// if a document for [roomCode] already exists in Firestore.
  Future<void> createRoom({
    required String roomCode,
    required Map<String, dynamic> data,
  });

  /// Deletes a room document in a batch. If [hostKey] is provided, writes the
  /// host proof document (`rooms/{roomCode}/hostProof/current`) and deletes
  /// the room in the same batch, then deletes the proof document.
  /// Throws [UnauthorizedHostActionException] if denied by the server or unauthorized.
  Future<void> deleteRoomWithHostProof({
    required String roomCode,
    String? hostKey,
  });

  /// Touches an existing room's lease fields (e.g. `lastUpdated`, `expiresAt`).
  /// If [createIfAbsent] is false, does nothing if the room document does not exist.
  /// If the existing room has no hostKeyHash, never adds one.
  Future<void> touchRoomLease({
    required String roomCode,
    required Map<String, dynamic> data,
    bool createIfAbsent = false,
  });
}

/// Thrown when an attempt is made to create a room whose code is already in use.
class RoomAlreadyExistsException implements Exception {
  final String message;

  RoomAlreadyExistsException([this.message = 'room code already in use']);

  @override
  String toString() => message;
}
