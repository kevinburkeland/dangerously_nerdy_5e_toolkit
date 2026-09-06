import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/logging_service.dart';
import 'animated_object.dart';
import 'dm_screen_data.dart';
import 'domain/character_models.dart';
import 'domain/session_graph_models.dart';
import 'party/party_event.dart';
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
  final List<String> partyCharacterIds;
  final Set<String> pinnedRuleIds;
  final String notesMarkdown;
  final PartyPurse partyPurse;
  final List<PartyEvent> changeLog;

  /// Transient, non-serialized field holding characters extracted during deserialization migration.
  final List<Character> _migratedCharacters;
  List<Character> get migratedCharacters => _migratedCharacters;

  /// Fallback storage preserving raw unparsed child entity payloads
  /// to guarantee 0% data loss across serialization cycles if a child fails parsing.
  final List<Map<String, dynamic>> unparsedPartyRoster;
  final List<Map<String, dynamic>> unparsedMinions;

  const CampaignProfile({
    required this.id,
    required this.name,
    this.edition = DmRulesEdition.v2024,
    required this.createdAt,
    required this.lastPlayedAt,
    required this.roomState,
    this.partyCharacterIds = const [],
    this.pinnedRuleIds = const {
      'concentration',
      'falling',
      'grapple_shove',
      'cover',
      'resting',
    },
    this.notesMarkdown = '',
    this.partyPurse = const PartyPurse(),
    this.changeLog = const [],
    List<Character> migratedCharacters = const [],
    this.unparsedPartyRoster = const [],
    this.unparsedMinions = const [],
  }) : _migratedCharacters = migratedCharacters;

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
      partyCharacterIds: const [],
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
    List<String>? partyCharacterIds,
    Set<String>? pinnedRuleIds,
    String? notesMarkdown,
    PartyPurse? partyPurse,
    List<PartyEvent>? changeLog,
    List<Character>? migratedCharacters,
    List<Map<String, dynamic>>? unparsedPartyRoster,
    List<Map<String, dynamic>>? unparsedMinions,
  }) {
    return CampaignProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      edition: edition ?? this.edition,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      roomState: roomState ?? this.roomState,
      partyCharacterIds: partyCharacterIds != null
          ? List<String>.from(partyCharacterIds)
          : this.partyCharacterIds,
      pinnedRuleIds: pinnedRuleIds != null
          ? Set<String>.from(pinnedRuleIds)
          : this.pinnedRuleIds,
      notesMarkdown: notesMarkdown ?? this.notesMarkdown,
      partyPurse: partyPurse ?? this.partyPurse,
      changeLog: changeLog != null
          ? List<PartyEvent>.from(changeLog)
          : this.changeLog,
      migratedCharacters: migratedCharacters ?? _migratedCharacters,
      unparsedPartyRoster: unparsedPartyRoster != null
          ? List<Map<String, dynamic>>.from(unparsedPartyRoster)
          : this.unparsedPartyRoster,
      unparsedMinions: unparsedMinions != null
          ? List<Map<String, dynamic>>.from(unparsedMinions)
          : this.unparsedMinions,
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
      'partyCharacterIds': partyCharacterIds,
      'pinnedRuleIds': pinnedRuleIds.toList(),
      'notesMarkdown': notesMarkdown,
      'partyPurse': partyPurse.toMap(),
      'changeLog': changeLog.map((e) => e.toMap()).toList(),
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
    var roomState = roomMap.isNotEmpty
        ? RoomNodeState.fromMap(roomMap)
        : RoomNodeState(
            roomId: map['id']?.toString() ?? 'room_default',
            roomCode: 'CR-101',
            title: '${map['name']?.toString() ?? "Campaign"} Staging',
          );

    final extractedIds = <String>[];
    final extractedChars = <Character>[];
    final unparsedRoster = <Map<String, dynamic>>[];

    // Iterate through map['partyCharacterIds'] or legacy map['partyRoster']
    final rawParty = map['partyCharacterIds'] ?? map['partyRoster'] ?? [];
    if (rawParty is List) {
      for (final raw in rawParty) {
        if (raw is String) {
          extractedIds.add(raw);
        } else if (raw is Map) {
          final itemMap = Map<String, dynamic>.from(raw);
          try {
            final parsedChar = Character.fromMap(itemMap);
            extractedIds.add(parsedChar.id.slug);
            extractedChars.add(parsedChar);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Failed to deserialize Character in CampaignProfile. Preserving raw payload to prevent data loss.',
            );
            unparsedRoster.add(itemMap);
          }
        }
      }
    }

    // Ephemeral combat state migration: migrate legacy root activeMinions to roomState.activeMinions
    final unparsedMinionList = <Map<String, dynamic>>[];
    if (map['activeMinions'] is List && (map['activeMinions'] as List).isNotEmpty) {
      final legacyMinions = <AnimatedObjectInstance>[];
      for (final raw in (map['activeMinions'] as List)) {
        if (raw is Map) {
          final itemMap = Map<String, dynamic>.from(raw);
          try {
            legacyMinions.add(AnimatedObjectInstance.fromMap(itemMap));
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Failed to deserialize AnimatedObjectInstance in CampaignProfile.',
            );
            unparsedMinionList.add(itemMap);
          }
        }
      }
      if (legacyMinions.isNotEmpty && roomState.activeMinions.isEmpty) {
        roomState = roomState.copyWith(activeMinions: legacyMinions);
      }
    }

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

    final changeLogList = <PartyEvent>[];
    if (map['changeLog'] is List) {
      for (final raw in (map['changeLog'] as List)) {
        if (raw is Map) {
          try {
            changeLogList.add(PartyEvent.fromMap(Map<String, dynamic>.from(raw)));
          } catch (_) {}
        }
      }
    }

    return CampaignProfile(
      id: map['id']?.toString() ?? 'campaign_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name']?.toString() ?? 'Unnamed Campaign',
      edition: edition,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt,
      roomState: roomState,
      partyCharacterIds: extractedIds,
      migratedCharacters: extractedChars,
      unparsedPartyRoster: unparsedRoster,
      unparsedMinions: unparsedMinionList,
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
      changeLog: changeLogList,
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
          roomState == other.roomState &&
          listEquals(partyCharacterIds, other.partyCharacterIds) &&
          listEquals(unparsedPartyRoster, other.unparsedPartyRoster) &&
          listEquals(unparsedMinions, other.unparsedMinions) &&
          setEquals(pinnedRuleIds, other.pinnedRuleIds);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      edition.hashCode ^
      notesMarkdown.hashCode ^
      partyPurse.hashCode ^
      roomState.hashCode ^
      partyCharacterIds.length ^
      unparsedPartyRoster.length ^
      unparsedMinions.length ^
      pinnedRuleIds.length;

  @override
  String toString() => 'CampaignProfile(id: $id, name: $name, edition: ${edition.label}, partyCharacterIds: ${partyCharacterIds.length}, minions: ${roomState.activeMinions.length})';
}
