import 'dart:convert';

enum CampaignRole {
  host('DM / Host'),
  coDm('Co-DM'),
  player('Player');

  final String label;
  const CampaignRole(this.label);

  static CampaignRole fromString(String? val) => switch (val?.toLowerCase()) {
        'host' || 'dm' => CampaignRole.host,
        'codm' || 'co_dm' || 'co-dm' => CampaignRole.coDm,
        _ => CampaignRole.player,
      };
}

class CampaignMembership {
  final String roomCode;
  final String campaignName;
  final CampaignRole role;
  final String? hostKey;
  final String? characterId;
  final DateTime lastPlayed;

  const CampaignMembership({
    required this.roomCode,
    required this.campaignName,
    this.role = CampaignRole.player,
    this.hostKey,
    this.characterId,
    required this.lastPlayed,
  });

  bool get isHost => role == CampaignRole.host;
  bool get isCoDm => role == CampaignRole.coDm;
  bool get isDmOrCoDm => role == CampaignRole.host || role == CampaignRole.coDm;
  bool get hasHostKey => hostKey != null && hostKey!.trim().isNotEmpty;

  CampaignMembership copyWith({
    String? roomCode,
    String? campaignName,
    CampaignRole? role,
    String? hostKey,
    bool clearHostKey = false,
    String? characterId,
    DateTime? lastPlayed,
  }) {
    return CampaignMembership(
      roomCode: roomCode ?? this.roomCode,
      campaignName: campaignName ?? this.campaignName,
      role: role ?? this.role,
      hostKey: clearHostKey ? null : (hostKey ?? this.hostKey),
      characterId: characterId ?? this.characterId,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomCode': roomCode,
      'campaignName': campaignName,
      'role': role.name,
      'hostKey': hostKey,
      'characterId': characterId,
      'lastPlayed': lastPlayed.toIso8601String(),
    };
  }

  factory CampaignMembership.fromMap(Map<String, dynamic> map) {
    return CampaignMembership(
      roomCode: map['roomCode'] as String? ?? '',
      campaignName: map['campaignName'] as String? ?? 'Untitled Campaign',
      role: CampaignRole.fromString(map['role'] as String?),
      hostKey: map['hostKey'] as String?,
      characterId: map['characterId'] as String?,
      lastPlayed: map['lastPlayed'] != null
          ? DateTime.tryParse(map['lastPlayed'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory CampaignMembership.fromJson(String source) =>
      CampaignMembership.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
