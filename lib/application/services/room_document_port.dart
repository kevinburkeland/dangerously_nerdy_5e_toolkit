/// Decision planned for a room deletion request.
enum RoomDeletePlan {
  none,
  plainDelete,
  proofAndDelete,
  unauthorized,
}

/// Final outcome of a room deletion operation.
enum RoomDeleteOutcome {
  deleted,
  alreadyGone,
}

/// Decides the deletion plan based on existing server room data and the provided host key.
///
/// Invariants:
/// - Absent room (`existingRoomData == null`): returns [RoomDeletePlan.none].
/// - Hostless room (`hostKeyHash` absent or `''`): returns [RoomDeletePlan.plainDelete].
/// - Hosted room (`hostKeyHash` non-empty):
///   - If [hostKey] is present and non-empty: returns [RoomDeletePlan.proofAndDelete].
///   - If [hostKey] is null or empty: returns [RoomDeletePlan.unauthorized].
RoomDeletePlan planRoomDelete(
  Map<String, dynamic>? existingRoomData,
  String? hostKey,
) {
  if (existingRoomData == null) {
    return RoomDeletePlan.none;
  }
  final rawHash = existingRoomData['hostKeyHash'];
  final hasHash = rawHash is String && rawHash.isNotEmpty;
  if (!hasHash) {
    return RoomDeletePlan.plainDelete;
  }
  final hasKey = hostKey != null && hostKey.isNotEmpty;
  if (!hasKey) {
    return RoomDeletePlan.unauthorized;
  }
  return RoomDeletePlan.proofAndDelete;
}

/// Abstract port defining room-document persistence operations
/// for lobby creation, lease renewals, and host-proven deletions.
abstract class IRoomDocumentPort {
  /// Writes a new room document. Fails (e.g. throws [RoomAlreadyExistsException])
  /// if a document for [roomCode] already exists in Firestore.
  Future<void> createRoom({
    required String roomCode,
    required Map<String, dynamic> data,
  });

  /// Deletes a room document in a transaction according to the room's server state.
  /// If the room is absent, writes nothing and returns [RoomDeleteOutcome.alreadyGone].
  /// If the room is hostless, performs a plain delete and returns [RoomDeleteOutcome.deleted].
  /// If the room is hosted and [hostKey] is provided, writes fresh host proof and deletes
  /// the room in the transaction, returning [RoomDeleteOutcome.deleted].
  /// Throws [UnauthorizedHostActionException] if the room is hosted and no key is given,
  /// or if server denies deletion.
  Future<RoomDeleteOutcome> deleteRoomWithHostProof({
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
