import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/models/campaign_profile.dart';
import '../../domain/models/animated_object.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_event.dart';
import '../../models/party/party_purse.dart';
import '../../services/logging_service.dart';
import 'animated_object_dto.dart';
import 'character_dto.dart';

/// Data Transfer Object for [CampaignProfile], isolating JSON serialization,
/// legacy schema migrations, and unparsed fallback payloads to the Infrastructure layer.
@immutable
class CampaignProfileDto {
  final String id;
  final String name;
  final String edition;
  final String createdAt;
  final String lastPlayedAt;
  final Map<String, dynamic> roomState;
  final List<String> partyCharacterIds;
  final List<String> pinnedRuleIds;
  final String notesMarkdown;
  final Map<String, dynamic> partyPurse;
  final List<Map<String, dynamic>> changeLog;
  final List<Character> migratedCharacters;
  final List<Map<String, dynamic>> unparsedPartyRoster;
  final List<Map<String, dynamic>> unparsedMinions;

  const CampaignProfileDto({
    required this.id,
    required this.name,
    required this.edition,
    required this.createdAt,
    required this.lastPlayedAt,
    required this.roomState,
    this.partyCharacterIds = const [],
    this.pinnedRuleIds = const [],
    this.notesMarkdown = '',
    this.partyPurse = const {},
    this.changeLog = const [],
    this.migratedCharacters = const [],
    this.unparsedPartyRoster = const [],
    this.unparsedMinions = const [],
  });

  /// Factory creating a DTO from a pure domain [CampaignProfile].
  factory CampaignProfileDto.fromDomain(CampaignProfile profile) {
    return CampaignProfileDto(
      id: profile.id,
      name: profile.name,
      edition: profile.edition.name,
      createdAt: profile.createdAt.toIso8601String(),
      lastPlayedAt: profile.lastPlayedAt.toIso8601String(),
      roomState: profile.roomState.toMap(),
      partyCharacterIds: List<String>.from(profile.partyCharacterIds),
      pinnedRuleIds: profile.pinnedRuleIds.toList(),
      notesMarkdown: profile.notesMarkdown,
      partyPurse: profile.partyPurse.toMap(),
      changeLog: profile.changeLog.map((e) => e.toMap()).toList(),
      migratedCharacters: List<Character>.from(profile.migratedCharacters),
      unparsedPartyRoster: List<Map<String, dynamic>>.from(profile.unparsedPartyRoster),
      unparsedMinions: List<Map<String, dynamic>>.from(profile.unparsedMinions),
    );
  }

  /// Converts this DTO into a pure domain [CampaignProfile] entity.
  CampaignProfile toDomain() {
    final editionVal = DmRulesEdition.values.firstWhere(
      (e) => e.name == edition,
      orElse: () => DmRulesEdition.v2024,
    );

    final createdDateTime = DateTime.tryParse(createdAt) ?? DateTime.now();
    final lastPlayedDateTime = DateTime.tryParse(lastPlayedAt) ?? createdDateTime;

    final parsedRoom = roomState.isNotEmpty
        ? RoomNodeState.fromMap(roomState)
        : RoomNodeState(
            roomId: 'room_$id',
            roomCode: 'CR-101',
            title: '$name Staging',
          );

    PartyPurse purse = const PartyPurse();
    if (partyPurse.isNotEmpty) {
      try {
        purse = PartyPurse.fromMap(partyPurse);
      } catch (_) {
        purse = const PartyPurse();
      }
    }

    final parsedEvents = <PartyEvent>[];
    for (final raw in changeLog) {
      try {
        parsedEvents.add(PartyEvent.fromMap(raw));
      } catch (_) {}
    }

    final pinned = pinnedRuleIds.isNotEmpty
        ? pinnedRuleIds.toSet()
        : const {
            'concentration',
            'falling',
            'grapple_shove',
            'cover',
            'resting',
          };

    return CampaignProfile(
      id: id,
      name: name,
      edition: editionVal,
      createdAt: createdDateTime,
      lastPlayedAt: lastPlayedDateTime,
      roomState: parsedRoom,
      partyCharacterIds: partyCharacterIds,
      pinnedRuleIds: pinned,
      notesMarkdown: notesMarkdown,
      partyPurse: purse,
      changeLog: parsedEvents,
      migratedCharacters: migratedCharacters,
      unparsedPartyRoster: unparsedPartyRoster,
      unparsedMinions: unparsedMinions,
    );
  }

  /// Deserializes a raw Map payload into [CampaignProfileDto] with complete legacy schema migrations.
  factory CampaignProfileDto.fromMap(Map<String, dynamic> map) {
    final editionStr = map['edition']?.toString() ?? 'v2024';
    final createdAtStr = map['createdAt']?.toString() ?? DateTime.now().toIso8601String();
    final lastPlayedAtStr = map['lastPlayedAt']?.toString() ?? createdAtStr;

    final roomMap = map['roomState'] is Map
        ? Map<String, dynamic>.from(map['roomState'] as Map)
        : <String, dynamic>{};

    final extractedIds = <String>[];
    final extractedChars = <Character>[];
    final unparsedRoster = <Map<String, dynamic>>[];

    // Migrate partyCharacterIds or legacy partyRoster
    final rawParty = map['partyCharacterIds'] ?? map['partyRoster'] ?? [];
    if (rawParty is List) {
      for (final raw in rawParty) {
        if (raw is String) {
          extractedIds.add(raw);
        } else if (raw is Map) {
          final itemMap = Map<String, dynamic>.from(raw);
          try {
            final parsedChar = CharacterDto.fromMap(itemMap).toDomain();
            extractedIds.add(parsedChar.id.slug);
            extractedChars.add(parsedChar);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Failed to deserialize Character in CampaignProfileDto. Preserving raw payload to prevent data loss.',
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
            legacyMinions.add(AnimatedObjectDto.fromMap(itemMap).toDomain());
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Failed to deserialize AnimatedObjectInstance in CampaignProfileDto.',
            );
            unparsedMinionList.add(itemMap);
          }
        }
      }
      if (legacyMinions.isNotEmpty &&
          (roomMap['activeMinions'] == null || (roomMap['activeMinions'] as List).isEmpty)) {
        roomMap['activeMinions'] = legacyMinions.map((m) => AnimatedObjectDto.fromDomain(m).toMap()).toList();
      }
    }

    final pinned = (map['pinnedRuleIds'] as List? ?? [])
        .whereType<String>()
        .toList();

    final purseMap = map['partyPurse'] is Map
        ? Map<String, dynamic>.from(map['partyPurse'] as Map)
        : <String, dynamic>{};

    final changeLogList = <Map<String, dynamic>>[];
    if (map['changeLog'] is List) {
      for (final raw in (map['changeLog'] as List)) {
        if (raw is Map) {
          changeLogList.add(Map<String, dynamic>.from(raw));
        }
      }
    }

    return CampaignProfileDto(
      id: map['id']?.toString() ?? 'campaign_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name']?.toString() ?? 'Unnamed Campaign',
      edition: editionStr,
      createdAt: createdAtStr,
      lastPlayedAt: lastPlayedAtStr,
      roomState: roomMap,
      partyCharacterIds: extractedIds,
      pinnedRuleIds: pinned,
      notesMarkdown: map['notesMarkdown']?.toString() ?? '',
      partyPurse: purseMap,
      changeLog: changeLogList,
      migratedCharacters: extractedChars,
      unparsedPartyRoster: unparsedRoster,
      unparsedMinions: unparsedMinionList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'edition': edition,
      'createdAt': createdAt,
      'lastPlayedAt': lastPlayedAt,
      'roomState': roomState,
      'partyCharacterIds': partyCharacterIds,
      'pinnedRuleIds': pinnedRuleIds,
      'notesMarkdown': notesMarkdown,
      'partyPurse': partyPurse,
      'changeLog': changeLog,
    };
  }

  String toJson() => json.encode(toMap());

  factory CampaignProfileDto.fromJson(String source) =>
      CampaignProfileDto.fromMap(Map<String, dynamic>.from(json.decode(source) as Map));
}
