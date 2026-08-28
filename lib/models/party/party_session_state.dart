import 'dart:convert';
import 'party_purse.dart';

/// Root campaign room document state stored at /rooms/{roomCode}
class PartySessionState {
  final String roomCode;
  final String campaignName;
  final String hostKeyHash;
  final PartyPurse partyPurse;
  final List<String> activePlayers;
  final int version;
  final DateTime lastUpdated;
  final DateTime expiresAt;

  const PartySessionState({
    required this.roomCode,
    required this.campaignName,
    required this.hostKeyHash,
    this.partyPurse = const PartyPurse(),
    this.activePlayers = const [],
    this.version = 1,
    required this.lastUpdated,
    required this.expiresAt,
  });

  PartySessionState copyWith({
    String? roomCode,
    String? campaignName,
    String? hostKeyHash,
    PartyPurse? partyPurse,
    List<String>? activePlayers,
    int? version,
    DateTime? lastUpdated,
    DateTime? expiresAt,
  }) {
    return PartySessionState(
      roomCode: roomCode ?? this.roomCode,
      campaignName: campaignName ?? this.campaignName,
      hostKeyHash: hostKeyHash ?? this.hostKeyHash,
      partyPurse: partyPurse ?? this.partyPurse,
      activePlayers: activePlayers ?? this.activePlayers,
      version: version ?? this.version,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'code': roomCode, // Compatibility with legacy room verification
      'campaignName': campaignName,
      'hostKeyHash': hostKeyHash,
      'partyPurse': partyPurse.toMap(),
      'activePlayers': activePlayers,
      'version': version,
      'lastUpdated': lastUpdated.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': lastUpdated.toIso8601String(),
    };
  }

  factory PartySessionState.fromMap(Map<String, dynamic> map) {
    final rawPurse = map['partyPurse'];
    final purse = rawPurse is Map<String, dynamic>
        ? PartyPurse.fromMap(rawPurse)
        : (rawPurse is Map ? PartyPurse.fromMap(Map<String, dynamic>.from(rawPurse)) : const PartyPurse());

    final rawPlayers = map['activePlayers'];
    final players = rawPlayers is List
        ? rawPlayers.map((e) => e.toString()).toList()
        : <String>[];

    return PartySessionState(
      roomCode: (map['roomCode'] ?? map['code']) as String? ?? '',
      campaignName: map['campaignName'] as String? ?? 'Untitled Campaign',
      hostKeyHash: map['hostKeyHash'] as String? ?? '',
      partyPurse: purse,
      activePlayers: players,
      version: (map['version'] as num?)?.toInt() ?? 1,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.tryParse(map['lastUpdated'] as String) ?? DateTime.now()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'] as String) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory PartySessionState.fromJson(String source) =>
      PartySessionState.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
