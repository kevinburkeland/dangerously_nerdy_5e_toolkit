import 'dart:convert';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_room_sync_payload_port.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import '../../models/room_roll.dart';
import '../../utils/crypto_utils.dart';
import '../dtos/campaign_profile_dto.dart';
import '../dtos/crdt/crdt_or_set_dto.dart';

export 'package:vtt_engine_core/ports/i_room_sync_payload_port.dart';

/// Infrastructure mapper responsible for parsing incoming network sync JSON into
/// strongly-typed messages and serializing domain mutations into transport envelopes.
class RoomSyncPayloadMapper implements IRoomSyncPayloadPort {
  const RoomSyncPayloadMapper();

  /// Computes a deterministic SHA-256 hash string for payload deduplication.
  @override
  String computePayloadHash(String jsonPayload) =>
      CryptoUtils.sha256Hex(jsonPayload);

  /// Parses a raw incoming JSON string into an [IncomingRoomSyncMessage].
  @override
  IncomingRoomSyncMessage parsePayload(String jsonPayload) {
    try {
      final decoded = jsonDecode(jsonPayload);
      if (decoded is! Map<String, dynamic>) return const UnknownSyncMessage();

      final type = decoded['type']?.toString();
      final originNodeId = decoded['origin_node_id']?.toString() ?? '';
      final originSeq = (decoded['origin_seq'] is num)
          ? (decoded['origin_seq'] as num).toInt()
          : (int.tryParse(decoded['origin_seq']?.toString() ?? '') ?? 0);
      final timestamp = (decoded['timestamp'] is num)
          ? (decoded['timestamp'] as num).toInt()
          : (int.tryParse(decoded['timestamp']?.toString() ?? '') ?? 0);

      switch (type) {
        case 'room_sync_full':
          final payloadData = decoded['payload'];
          if (payloadData is! Map) return const UnknownSyncMessage();

          final profileDto = CampaignProfileDto.fromMap(
            Map<String, dynamic>.from(payloadData),
          );
          final domainProfile = profileDto.toDomain();

          CrdtOrSet<String>? remoteRulesSet;
          if (decoded.containsKey('pinned_rules_crdt') &&
              decoded['pinned_rules_crdt'] is Map) {
            try {
              remoteRulesSet = CrdtOrSetDto.fromMap<String>(
                Map<dynamic, dynamic>.from(decoded['pinned_rules_crdt'] as Map),
                (raw) => raw.toString(),
              );
            } catch (_) {}
          }

          PartyPurse? remotePurseDelta;
          if (decoded.containsKey('party_purse_crdt') &&
              decoded['party_purse_crdt'] is Map) {
            try {
              remotePurseDelta = PartyPurse.fromMap(
                Map<String, dynamic>.from(decoded['party_purse_crdt'] as Map),
              );
            } catch (_) {}
          }

          return FullProfileSyncMessage(
            originNodeId: originNodeId,
            originSeq: originSeq,
            timestamp: timestamp,
            profile: domainProfile,
            purseDelta: remotePurseDelta,
            pinnedRulesDelta: remoteRulesSet,
          );

        case 'crdt_purse_delta':
        case 'party_purse_delta':
          final payloadData = decoded['payload'];
          if (payloadData is! Map) return const UnknownSyncMessage();

          final purse = PartyPurse.fromMap(
            Map<String, dynamic>.from(payloadData),
          );
          return PurseDeltaSyncMessage(
            originNodeId: originNodeId,
            originSeq: originSeq,
            timestamp: timestamp,
            campaignId: decoded['campaign_id']?.toString() ?? '',
            purse: purse,
          );

        case 'crdt_or_set_delta':
          final payloadData = decoded['payload'];
          if (payloadData is! Map) return const UnknownSyncMessage();

          final set = CrdtOrSetDto.fromMap<String>(
            Map<dynamic, dynamic>.from(payloadData),
            (raw) => raw.toString(),
          );
          return OrSetDeltaSyncMessage(
            originNodeId: originNodeId,
            originSeq: originSeq,
            timestamp: timestamp,
            campaignId: decoded['campaign_id']?.toString() ?? '',
            rulesSet: set,
          );

        case 'dice_roll':
          final payloadData = decoded['payload'];
          if (payloadData is! Map) return const UnknownSyncMessage();

          final roll = RoomRoll.fromMap(
            Map<String, dynamic>.from(payloadData),
          );
          return DiceRollSyncMessage(
            originNodeId: originNodeId,
            originSeq: originSeq,
            timestamp: timestamp,
            roll: roll,
          );

        default:
          return const UnknownSyncMessage();
      }
    } catch (_) {
      return const UnknownSyncMessage();
    }
  }

  /// Serializes a full campaign profile sync broadcast into an envelope JSON string.
  @override
  String serializeFullProfileSync({
    required CampaignProfile profile,
    required String originNodeId,
    required int originSeq,
    required int timestamp,
    CrdtOrSet<String>? trackedRulesSet,
  }) {
    final dto = CampaignProfileDto.fromDomain(profile);
    final payloadMap = <String, dynamic>{
      'type': 'room_sync_full',
      'origin_node_id': originNodeId,
      'origin_seq': originSeq,
      'payload': dto.toMap(),
      'timestamp': timestamp,
      'party_purse_crdt': profile.partyPurse.toMap(),
    };

    if (trackedRulesSet != null &&
        (trackedRulesSet.items.isNotEmpty ||
            trackedRulesSet.tombstones.isNotEmpty)) {
      payloadMap['pinned_rules_crdt'] = CrdtOrSetDto.toMap<String>(
        trackedRulesSet,
        (val) => val,
      );
    }

    return jsonEncode(payloadMap);
  }

  /// Serializes a focused purse delta broadcast into an envelope JSON string.
  @override
  String serializePurseDelta({
    required String campaignId,
    required PartyPurse purse,
    required String originNodeId,
    required int originSeq,
    required int timestamp,
  }) {
    final deltaMap = <String, dynamic>{
      'type': 'crdt_purse_delta',
      'origin_node_id': originNodeId,
      'origin_seq': originSeq,
      'campaign_id': campaignId,
      'payload': purse.toMap(),
      'timestamp': timestamp,
    };
    return jsonEncode(deltaMap);
  }

  /// Serializes a focused OR-Set delta broadcast into an envelope JSON string.
  @override
  String serializeOrSetDelta({
    required String campaignId,
    required CrdtOrSet<String> rulesSet,
    required String originNodeId,
    required int originSeq,
    required int timestamp,
  }) {
    final deltaMap = <String, dynamic>{
      'type': 'crdt_or_set_delta',
      'origin_node_id': originNodeId,
      'origin_seq': originSeq,
      'campaign_id': campaignId,
      'payload': CrdtOrSetDto.toMap<String>(
        rulesSet,
        (val) => val,
      ),
      'timestamp': timestamp,
    };
    return jsonEncode(deltaMap);
  }
}
