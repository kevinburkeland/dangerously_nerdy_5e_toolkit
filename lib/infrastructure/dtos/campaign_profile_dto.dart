import 'dart:convert';
import 'package:meta/meta.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';
import '../../models/animated_object.dart';
import '../modules/dnd5e/rules/ruleset_edition.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_event.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import '../../services/logging_service.dart';
import 'character_dto.dart';
import 'crdt/crdt_lww_register_dto.dart';

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
  final Map<String, dynamic> pinnedRulesCrdt;
  final String notesMarkdown;
  final Map<String, dynamic> notesRegister;
  final Map<String, dynamic> partyPurse;
  final List<Map<String, dynamic>> changeLog;
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
    this.pinnedRulesCrdt = const {},
    this.notesMarkdown = '',
    this.notesRegister = const {},
    this.partyPurse = const {},
    this.changeLog = const [],
    this.unparsedPartyRoster = const [],
    this.unparsedMinions = const [],
  });

  /// Factory creating a DTO from a pure domain [CampaignProfile], optionally attaching unparsed infrastructure payloads.
  factory CampaignProfileDto.fromDomain(
    CampaignProfile profile, {
    List<Map<String, dynamic>> unparsedPartyRoster = const [],
    List<Map<String, dynamic>> unparsedMinions = const [],
  }) {
    return CampaignProfileDto(
      id: profile.id,
      name: profile.name,
      edition: profile.edition is Enum ? (profile.edition as Enum).name : profile.edition.toString(),
      createdAt: profile.createdAt.toIso8601String(),
      lastPlayedAt: profile.lastPlayedAt.toIso8601String(),
      roomState: profile.roomState.toMap(),
      partyCharacterIds: List<String>.from(profile.partyCharacterIds),
      pinnedRuleIds: profile.pinnedRuleIds.toList(),
      pinnedRulesCrdt: profile.pinnedRules.toMap((v) => v),
      notesMarkdown: profile.notesMarkdown,
      notesRegister: CrdtLwwRegisterDto.toMap(profile.notesRegister, (v) => v),
      partyPurse: profile.partyPurse.toMap(),
      changeLog: profile.changeLog.map((e) => e.toMap()).toList(),
      unparsedPartyRoster: List<Map<String, dynamic>>.from(unparsedPartyRoster),
      unparsedMinions: List<Map<String, dynamic>>.from(unparsedMinions),
    );
  }

  /// Converts this DTO into a pure domain [CampaignProfile] entity.
  CampaignProfile toDomain() {
    final createdDateTime = DateTime.tryParse(createdAt) ?? DateTime.now();
    final lastPlayedDateTime =
        DateTime.tryParse(lastPlayedAt) ?? createdDateTime;

    final parsedRoom = roomState.isNotEmpty
        ? RoomNodeState.fromMap(
            roomState,
            minionParser: (m) => AnimatedObjectDto.fromMap(m).toDomain(),
          )
        : RoomNodeState(
            roomId: 'room_$id',
            roomCode: 'CR-101',
            title: '$name Staging',
          );

    PartyPurse purse = const PartyPurse.empty();
    if (partyPurse.isNotEmpty) {
      try {
        purse = PartyPurse.fromMap(partyPurse);
      } catch (_) {
        purse = const PartyPurse.empty();
      }
    }

    final parsedEvents = <PartyEvent>[];
    for (final raw in changeLog) {
      try {
        parsedEvents.add(PartyEvent.fromMap(raw));
      } catch (_) {}
    }

    CrdtOrSet<String>? parsedPinnedRules;
    if (pinnedRulesCrdt.isNotEmpty) {
      try {
        parsedPinnedRules = CrdtOrSet<String>.fromMap(
          pinnedRulesCrdt,
          (v) => v.toString(),
        );
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

    final parsedNotesRegister = notesRegister.isNotEmpty
        ? CrdtLwwRegisterDto.fromMap<String>(notesRegister, (v) => v.toString())
        : (notesMarkdown.isNotEmpty
            ? CrdtLwwRegister<String>(
                value: notesMarkdown,
                timestamp: const HybridLogicalClock(
                  physicalTime: 0,
                  logicalCounter: 0,
                  nodeId: 'genesis',
                ),
              )
            : const CrdtLwwRegister<String>(
                value: '',
                timestamp: HybridLogicalClock(
                  physicalTime: 0,
                  logicalCounter: 0,
                  nodeId: 'genesis',
                ),
              ));

    final dynamic parsedEdition;
    final cleanEdition = edition.trim().toLowerCase();
    if (cleanEdition.contains('2024') ||
        cleanEdition == 'srd5.2.1' ||
        cleanEdition == 'srd5.2' ||
        cleanEdition == 'srd2024' ||
        cleanEdition == 'srd521' ||
        cleanEdition == 'srd52' ||
        cleanEdition == '5e-2024' ||
        cleanEdition == 'v2024' ||
        cleanEdition.contains('5.2')) {
      parsedEdition = RulesetEdition.v2024;
    } else if (cleanEdition.contains('2014') ||
        cleanEdition == 'srd5.1' ||
        cleanEdition == 'srd51' ||
        cleanEdition == '5e-2014' ||
        cleanEdition == 'v2014' ||
        cleanEdition.contains('5.1')) {
      parsedEdition = RulesetEdition.v2014;
    } else {
      parsedEdition = RulesetIdentifier(edition);
    }

    return CampaignProfile.raw(
      id: id,
      name: name,
      edition: parsedEdition,
      createdAt: createdDateTime,
      lastPlayedAt: lastPlayedDateTime,
      roomState: parsedRoom,
      partyCharacterIds: partyCharacterIds,
      pinnedRules: parsedPinnedRules,
      pinnedRuleIds: parsedPinnedRules == null ? pinned : null,
      notesRegister: parsedNotesRegister ??
          const CrdtLwwRegister<String>(
            value: '',
            timestamp: HybridLogicalClock(
              physicalTime: 0,
              logicalCounter: 0,
              nodeId: 'genesis',
            ),
          ),
      partyPurse: purse,
      changeLog: parsedEvents,
    );
  }

  /// Deserializes a raw Map payload into [CampaignProfileDto] with complete legacy schema migrations.
  factory CampaignProfileDto.fromMap(Map<String, dynamic> map) {
    final editionStr = map['edition']?.toString() ?? 'v2024';
    final createdAtStr =
        map['createdAt']?.toString() ?? DateTime.now().toIso8601String();
    final lastPlayedAtStr = map['lastPlayedAt']?.toString() ?? createdAtStr;

    final roomMap = map['roomState'] is Map
        ? Map<String, dynamic>.from(map['roomState'] as Map)
        : <String, dynamic>{};

    final extractedIds = <String>[];
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
            if (itemMap.containsKey('invalid_schema') ||
                (!itemMap.containsKey('speciesRef') &&
                    !itemMap.containsKey('progression') &&
                    !itemMap.containsKey('baseScores'))) {
              throw const FormatException(
                  'Incomplete or corrupt character payload');
            }
            final parsedChar = CharacterDto.fromMap(itemMap).toDomain();
            extractedIds.add(parsedChar.id.slug);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason:
                  'Failed to deserialize Character in CampaignProfileDto. Preserving raw payload to prevent data loss.',
            );
            unparsedRoster.add(itemMap);
          }
        }
      }
    }

    if (map['unparsedPartyRoster'] is List) {
      for (final raw in (map['unparsedPartyRoster'] as List)) {
        if (raw is Map) {
          unparsedRoster.add(Map<String, dynamic>.from(raw));
        }
      }
    }

    // Ephemeral combat state migration: migrate legacy root activeMinions to roomState.activeMinions
    final unparsedMinionList = <Map<String, dynamic>>[];
    if (map['activeMinions'] is List &&
        (map['activeMinions'] as List).isNotEmpty) {
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
              reason:
                  'Failed to deserialize AnimatedObjectInstance in CampaignProfileDto.',
            );
            unparsedMinionList.add(itemMap);
          }
        }
      }
      if (legacyMinions.isNotEmpty &&
          (roomMap['activeMinions'] == null ||
              (roomMap['activeMinions'] as List).isEmpty)) {
        roomMap['activeMinions'] = legacyMinions
            .map((m) => AnimatedObjectDto.fromDomain(m).toMap())
            .toList();
      }
    }
    if (map['unparsedMinions'] is List) {
      for (final raw in (map['unparsedMinions'] as List)) {
        if (raw is Map) {
          unparsedMinionList.add(Map<String, dynamic>.from(raw));
        }
      }
    }

    final pinned =
        (map['pinnedRuleIds'] as List? ?? []).whereType<String>().toList();

    final pinnedCrdtMap = map['pinnedRules_crdt'] is Map
        ? Map<String, dynamic>.from(map['pinnedRules_crdt'] as Map)
        : (map['pinnedRules'] is Map
            ? Map<String, dynamic>.from(map['pinnedRules'] as Map)
            : const <String, dynamic>{});

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
      id: map['id']?.toString() ??
          'campaign_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name']?.toString() ?? 'Unnamed Campaign',
      edition: editionStr,
      createdAt: createdAtStr,
      lastPlayedAt: lastPlayedAtStr,
      roomState: roomMap,
      partyCharacterIds: extractedIds,
      pinnedRuleIds: pinned,
      pinnedRulesCrdt: pinnedCrdtMap,
      notesMarkdown: map['notesMarkdown']?.toString() ?? '',
      notesRegister: map['notesRegister'] is Map
          ? Map<String, dynamic>.from(map['notesRegister'] as Map)
          : const {},
      partyPurse: purseMap,
      changeLog: changeLogList,
      unparsedPartyRoster: unparsedRoster,
      unparsedMinions: unparsedMinionList,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'edition': edition,
      'createdAt': createdAt,
      'lastPlayedAt': lastPlayedAt,
      'roomState': roomState,
      'partyCharacterIds': partyCharacterIds,
      'pinnedRuleIds': pinnedRuleIds,
      if (pinnedRulesCrdt.isNotEmpty) 'pinnedRules_crdt': pinnedRulesCrdt,
      'notesMarkdown': notesMarkdown,
      'notesRegister': notesRegister,
      'partyPurse': partyPurse,
      'changeLog': changeLog,
    };
    if (unparsedPartyRoster.isNotEmpty) {
      map['unparsedPartyRoster'] = unparsedPartyRoster;
    }
    if (unparsedMinions.isNotEmpty) {
      map['unparsedMinions'] = unparsedMinions;
    }
    return map;
  }

  String toJson() => json.encode(toMap());

  factory CampaignProfileDto.fromJson(String source) =>
      CampaignProfileDto.fromMap(
          Map<String, dynamic>.from(json.decode(source) as Map));

  /// Explicit service-layer helper to extract legacy embedded characters from a raw map.
  static List<Character> extractLegacyCharacters(Map<String, dynamic> map) {
    final rawParty = map['partyCharacterIds'] ?? map['partyRoster'] ?? [];
    final characters = <Character>[];
    if (rawParty is List) {
      for (final raw in rawParty) {
        if (raw is Map) {
          try {
            final itemMap = Map<String, dynamic>.from(raw);
            if (!itemMap.containsKey('invalid_schema')) {
              characters.add(CharacterDto.fromMap(itemMap).toDomain());
            }
          } catch (_) {}
        }
      }
    }
    return characters;
  }
}
