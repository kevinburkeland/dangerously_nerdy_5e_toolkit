import 'package:meta/meta.dart';
import '../../infrastructure/dtos/character_telemetry_dto.dart';
import 'package:vtt_engine_core/utils/deep_immutable.dart';

/// Pure Firestore lobby record representing the room document at `/rooms/{roomCode}`.
///
/// Under Cold Iron Pass 7, the lobby is strictly a discovery, presence, and projection record.
/// Authoritative ledger state (party reserve, roster, member purses) is owned exclusively
/// by the CRDT [CampaignProfile].
@immutable
class PartyRoomLobby {
  final String roomCode;
  final String? campaignId;
  final String? rulesetId;
  final String campaignName;
  final String hostKeyHash;
  final List<String> activePlayers;
  final Map<String, CharacterTelemetryDto> partyTelemetry;
  final Map<String, Map<String, dynamic>> sharedCharacters;
  final int version;
  final DateTime createdAt;
  final DateTime lastUpdated;
  final DateTime expiresAt;

  PartyRoomLobby({
    required this.roomCode,
    this.campaignId,
    this.rulesetId,
    required this.campaignName,
    required this.hostKeyHash,
    List<String> activePlayers = const [],
    Map<String, CharacterTelemetryDto> partyTelemetry = const {},
    Map<String, Map<String, dynamic>> sharedCharacters = const {},
    this.version = 1,
    DateTime? createdAt,
    required this.lastUpdated,
    required this.expiresAt,
  })  : activePlayers = List<String>.unmodifiable(activePlayers),
        partyTelemetry = Map<String, CharacterTelemetryDto>.unmodifiable(
          Map<String, CharacterTelemetryDto>.from(partyTelemetry),
        ),
        sharedCharacters = Map<String, Map<String, dynamic>>.unmodifiable(
          sharedCharacters.map((k, v) => MapEntry(k, deepFreezeMap(v))),
        ),
        createdAt = createdAt ?? lastUpdated;

  PartyRoomLobby copyWith({
    String? roomCode,
    String? rulesetId,
    String? campaignName,
    String? hostKeyHash,
    List<String>? activePlayers,
    Map<String, CharacterTelemetryDto>? partyTelemetry,
    Map<String, Map<String, dynamic>>? sharedCharacters,
    int? version,
    DateTime? createdAt,
    DateTime? lastUpdated,
    DateTime? expiresAt,
  }) {
    return PartyRoomLobby(
      roomCode: roomCode ?? this.roomCode,
      campaignId: campaignId,
      rulesetId: rulesetId ?? this.rulesetId,
      campaignName: campaignName ?? this.campaignName,
      hostKeyHash: hostKeyHash ?? this.hostKeyHash,
      activePlayers: activePlayers ?? this.activePlayers,
      partyTelemetry: partyTelemetry ?? this.partyTelemetry,
      sharedCharacters: sharedCharacters ?? this.sharedCharacters,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'code': roomCode,
      if (campaignId != null && campaignId!.trim().isNotEmpty)
        'campaignId': campaignId!.trim(),
      if (rulesetId != null && rulesetId!.trim().isNotEmpty)
        'rulesetId': rulesetId!.trim(),
      'campaignName': campaignName,
      'hostKeyHash': hostKeyHash,
      'activePlayers': activePlayers,
      'partyTelemetry': partyTelemetry.map((k, v) => MapEntry(k, v.toMap())),
      'sharedCharacters': sharedCharacters,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory PartyRoomLobby.fromMap(Map<String, dynamic> map) {
    final rawCode = (map['roomCode'] ?? map['code'] ?? '').toString().trim().toUpperCase();
    final rawCampaignId = map['campaignId'] as String?;
    final rawRulesetId = map['rulesetId'] as String?;

    final active = (map['activePlayers'] as List? ?? [])
        .whereType<String>()
        .toList();

    final telemetryMap = <String, CharacterTelemetryDto>{};
    if (map['partyTelemetry'] is Map) {
      final rawTele = Map<String, dynamic>.from(map['partyTelemetry'] as Map);
      for (final entry in rawTele.entries) {
        if (entry.value is Map) {
          try {
            telemetryMap[entry.key] = CharacterTelemetryDto.fromMap(
                Map<String, dynamic>.from(entry.value as Map));
          } catch (_) {
            // intentional: corrupted peer telemetry entry dropped during lobby deserialization
          }
        }
      }
    }

    final sharedMap = <String, Map<String, dynamic>>{};
    if (map['sharedCharacters'] is Map) {
      final rawShared = Map<String, dynamic>.from(map['sharedCharacters'] as Map);
      for (final entry in rawShared.entries) {
        if (entry.value is Map) {
          sharedMap[entry.key] = Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }

    final now = DateTime.now();
    DateTime lastUp = now;
    if (map.containsKey('lastUpdated')) {
      final parsed = DateTime.tryParse(map['lastUpdated']?.toString() ?? '');
      if (parsed != null) lastUp = parsed;
    }

    DateTime exp = now.add(const Duration(days: 30));
    if (map.containsKey('expiresAt')) {
      final parsed = DateTime.tryParse(map['expiresAt']?.toString() ?? '');
      if (parsed != null) exp = parsed;
    }

    DateTime cr = lastUp;
    if (map.containsKey('createdAt')) {
      final parsed = DateTime.tryParse(map['createdAt']?.toString() ?? '');
      if (parsed != null) cr = parsed;
    }

    return PartyRoomLobby(
      roomCode: rawCode,
      campaignId: rawCampaignId != null && rawCampaignId.trim().isNotEmpty
          ? rawCampaignId.trim()
          : null,
      rulesetId: rawRulesetId != null && rawRulesetId.trim().isNotEmpty
          ? rawRulesetId.trim()
          : null,
      campaignName: map['campaignName']?.toString() ?? 'Party Campaign',
      hostKeyHash: map['hostKeyHash']?.toString() ?? '',
      activePlayers: active,
      partyTelemetry: telemetryMap,
      sharedCharacters: sharedMap,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: cr,
      lastUpdated: lastUp,
      expiresAt: exp,
    );
  }
}
