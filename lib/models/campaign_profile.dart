import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'animated_object.dart';
import 'dm_screen_data.dart';
import 'domain/character_models.dart';
import 'domain/session_graph_models.dart';
import 'party/party_purse.dart';

/// Immutable Campaign Profile representing an isolated campaign / DM workspace state.
@immutable
class CampaignProfile {
  final String id;
  final String name;
  final DmRulesEdition edition;
  final DateTime createdAt;
  final DateTime lastPlayedAt;
  final RoomNodeState roomState;
  final List<Character> partyRoster;
  final List<AnimatedObjectInstance> activeMinions;
  final Set<String> pinnedRuleIds;
  final String notesMarkdown;
  final PartyPurse partyPurse;

  const CampaignProfile({
    required this.id,
    required this.name,
    this.edition = DmRulesEdition.v2024,
    required this.createdAt,
    required this.lastPlayedAt,
    required this.roomState,
    this.partyRoster = const [],
    this.activeMinions = const [],
    this.pinnedRuleIds = const {
      'concentration',
      'falling',
      'grapple_shove',
      'cover',
      'resting',
    },
    this.notesMarkdown = '',
    this.partyPurse = const PartyPurse(),
  });

  /// Factory creating a fresh default campaign profile.
  factory CampaignProfile.defaultProfile({
    String? id,
    String? name,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) {
    final now = DateTime.now();
    final profileId = id ?? 'campaign_${now.millisecondsSinceEpoch}';
    final campaignName = name ?? 'My Campaign';

    return CampaignProfile(
      id: profileId,
      name: campaignName,
      edition: edition,
      createdAt: now,
      lastPlayedAt: now,
      roomState: RoomNodeState(
        roomId: 'room_$profileId',
        roomCode: 'CR-101',
        title: '$campaignName - Staging Area',
        description: 'Active DM session staging node.',
        entityLinks: const [],
        containers: const [],
        activeEncounter: const [],
      ),
      partyRoster: const [],
      activeMinions: const [],
      pinnedRuleIds: const {
        'concentration',
        'falling',
        'grapple_shove',
        'cover',
        'resting',
      },
      notesMarkdown: '',
      partyPurse: const PartyPurse(),
    );
  }

  CampaignProfile copyWith({
    String? id,
    String? name,
    DmRulesEdition? edition,
    DateTime? createdAt,
    DateTime? lastPlayedAt,
    RoomNodeState? roomState,
    List<Character>? partyRoster,
    List<AnimatedObjectInstance>? activeMinions,
    Set<String>? pinnedRuleIds,
    String? notesMarkdown,
    PartyPurse? partyPurse,
  }) {
    return CampaignProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      edition: edition ?? this.edition,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      roomState: roomState ?? this.roomState,
      partyRoster: partyRoster != null ? List<Character>.from(partyRoster) : this.partyRoster,
      activeMinions: activeMinions != null ? List<AnimatedObjectInstance>.from(activeMinions) : this.activeMinions,
      pinnedRuleIds: pinnedRuleIds != null ? Set<String>.from(pinnedRuleIds) : this.pinnedRuleIds,
      notesMarkdown: notesMarkdown ?? this.notesMarkdown,
      partyPurse: partyPurse ?? this.partyPurse,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'edition': edition.name,
      'createdAt': createdAt.toIso8601String(),
      'lastPlayedAt': lastPlayedAt.toIso8601String(),
      'roomState': roomState.toMap(),
      'partyRoster': partyRoster.map((c) => c.toMap()).toList(),
      'activeMinions': activeMinions.map((m) => m.toMap()).toList(),
      'pinnedRuleIds': pinnedRuleIds.toList(),
      'notesMarkdown': notesMarkdown,
      'partyPurse': partyPurse.toMap(),
    };
  }

  factory CampaignProfile.fromMap(Map<String, dynamic> map) {
    final editionStr = map['edition']?.toString() ?? 'v2024';
    final edition = DmRulesEdition.values.firstWhere(
      (e) => e.name == editionStr,
      orElse: () => DmRulesEdition.v2024,
    );

    final createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now();
    final lastPlayedAt = DateTime.tryParse(map['lastPlayedAt']?.toString() ?? '') ?? createdAt;

    final roomMap = map['roomState'] is Map ? Map<String, dynamic>.from(map['roomState'] as Map) : <String, dynamic>{};
    final roomState = roomMap.isNotEmpty
        ? RoomNodeState.fromMap(roomMap)
        : RoomNodeState(
            roomId: map['id']?.toString() ?? 'room_default',
            roomCode: 'CR-101',
            title: '${map['name']?.toString() ?? "Campaign"} Staging',
          );

    final rosterList = (map['partyRoster'] as List? ?? [])
        .whereType<Map>()
        .map((m) {
          try {
            return Character.fromMap(Map<String, dynamic>.from(m));
          } catch (_) {
            return null;
          }
        })
        .whereType<Character>()
        .toList();

    final minionsList = (map['activeMinions'] as List? ?? [])
        .whereType<Map>()
        .map((m) {
          try {
            return AnimatedObjectInstance.fromMap(Map<String, dynamic>.from(m));
          } catch (_) {
            return null;
          }
        })
        .whereType<AnimatedObjectInstance>()
        .toList();

    final pinned = (map['pinnedRuleIds'] as List? ?? [])
        .whereType<String>()
        .toSet();

    PartyPurse purse = const PartyPurse();
    if (map['partyPurse'] is Map) {
      try {
        purse = PartyPurse.fromMap(Map<String, dynamic>.from(map['partyPurse'] as Map));
      } catch (_) {
        purse = const PartyPurse();
      }
    }

    return CampaignProfile(
      id: map['id']?.toString() ?? 'campaign_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name']?.toString() ?? 'Unnamed Campaign',
      edition: edition,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt,
      roomState: roomState,
      partyRoster: rosterList,
      activeMinions: minionsList,
      pinnedRuleIds: pinned.isNotEmpty
          ? pinned
          : const {
              'concentration',
              'falling',
              'grapple_shove',
              'cover',
              'resting',
            },
      notesMarkdown: map['notesMarkdown']?.toString() ?? '',
      partyPurse: purse,
    );
  }

  String toJson() => json.encode(toMap());

  factory CampaignProfile.fromJson(String source) =>
      CampaignProfile.fromMap(Map<String, dynamic>.from(json.decode(source) as Map));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampaignProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          edition == other.edition &&
          notesMarkdown == other.notesMarkdown &&
          partyPurse == other.partyPurse &&
          listEquals(partyRoster, other.partyRoster) &&
          listEquals(activeMinions, other.activeMinions) &&
          setEquals(pinnedRuleIds, other.pinnedRuleIds);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      edition.hashCode ^
      notesMarkdown.hashCode ^
      partyPurse.hashCode ^
      partyRoster.length ^
      activeMinions.length ^
      pinnedRuleIds.length;

  @override
  String toString() => 'CampaignProfile(id: $id, name: $name, edition: ${edition.label}, roster: ${partyRoster.length}, minions: ${activeMinions.length})';
}
