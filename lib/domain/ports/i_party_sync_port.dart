import 'dart:async';
import '../../infrastructure/dtos/character_telemetry_dto.dart';
import '../../models/party/party_session_state.dart';

/// Port (interface) defining remote room synchronization operations in the Domain layer.
///
/// Deprecated in favor of [RoomSyncOrchestrator] and [IP2pTransportPort].
@Deprecated('Use RoomSyncOrchestrator and IP2pTransportPort instead.')
abstract class IPartySyncPort {
  /// Creates a new campaign room on the remote network and returns the generated room code.
  Future<String> createCampaignRoom(String roomName, String dmPasskey);

  /// Joins an existing campaign room using the room code.
  Future<void> joinCampaignRoom(String roomCode, String playerName);

  /// Broadcasts minified character combat telemetry to room participants.
  Future<void> broadcastTelemetry(String roomCode, CharacterTelemetryDto telemetry);

  /// Subscribes to real-time party session updates for the given room code.
  Stream<PartySessionState?> watchRoomSession(String roomCode);

  /// Closes and archives an active campaign room.
  Future<void> closeCampaignRoom(String roomCode, String dmPasskey);
}
