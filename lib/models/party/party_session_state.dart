import 'dart:convert';
import 'party_purse.dart';

/// Root campaign room document state stored at /rooms/{roomCode}
class PartySessionState {
  final String roomCode;
  final String campaignName;
  final String hostKeyHash;
  final PartyPurse partyPurse;
  final Map<String, PartyPurse> memberPurses;
  final List<String> activePlayers;
  final List<String> characterRoster;
  final int version;
  final DateTime lastUpdated;
  final DateTime expiresAt;

  const PartySessionState({
    required this.roomCode,
    required this.campaignName,
    required this.hostKeyHash,
    this.partyPurse = const PartyPurse(),
    this.memberPurses = const {},
    this.activePlayers = const [],
    this.characterRoster = const [],
    this.version = 1,
    required this.lastUpdated,
    required this.expiresAt,
  });

  /// Helper to retrieve or initialize a character's personal coin store
  PartyPurse getMemberPurse(String characterName) {
    return memberPurses[characterName] ?? const PartyPurse();
  }

  PartySessionState copyWith({
    String? roomCode,
    String? campaignName,
    String? hostKeyHash,
    PartyPurse? partyPurse,
    Map<String, PartyPurse>? memberPurses,
    List<String>? activePlayers,
    List<String>? characterRoster,
    int? version,
    DateTime? lastUpdated,
    DateTime? expiresAt,
  }) {
    return PartySessionState(
      roomCode: roomCode ?? this.roomCode,
      campaignName: campaignName ?? this.campaignName,
      hostKeyHash: hostKeyHash ?? this.hostKeyHash,
      partyPurse: partyPurse ?? this.partyPurse,
      memberPurses: memberPurses ?? this.memberPurses,
      activePlayers: activePlayers ?? this.activePlayers,
      characterRoster: characterRoster ?? this.characterRoster,
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
      'memberPurses': memberPurses.map((k, v) => MapEntry(k, v.toMap())),
      'activePlayers': activePlayers,
      'characterRoster': characterRoster,
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

    final rawMemberPurses = map['memberPurses'];
    final Map<String, PartyPurse> memberPurses = {};
    if (rawMemberPurses is Map) {
      rawMemberPurses.forEach((k, v) {
        if (v is Map) {
          memberPurses[k.toString()] = PartyPurse.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    final rawPlayers = map['activePlayers'];
    final players = rawPlayers is List
        ? rawPlayers.map((e) => e.toString()).toList()
        : <String>[];

    final rawRoster = map['characterRoster'];
    final roster = rawRoster is List
        ? rawRoster.map((e) => e.toString()).toList()
        : <String>[];

    return PartySessionState(
      roomCode: (map['roomCode'] ?? map['code']) as String? ?? '',
      campaignName: map['campaignName'] as String? ?? 'Untitled Campaign',
      hostKeyHash: map['hostKeyHash'] as String? ?? '',
      partyPurse: purse,
      memberPurses: memberPurses,
      activePlayers: players,
      characterRoster: roster,
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
