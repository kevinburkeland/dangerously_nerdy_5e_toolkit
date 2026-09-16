import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import '../crdt/crdt_lww_register.dart';
import '../crdt/crdt_or_set.dart';
import '../crdt/hybrid_logical_clock.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_event.dart';
import '../../models/party/party_purse.dart';

/// Immutable Campaign Profile representing an isolated campaign / DM workspace state.
/// This is a pure Domain Entity devoid of persistence and serialization concerns.
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
  final CrdtLwwRegister<String> notesRegister;
  final PartyPurse partyPurse;
  final List<PartyEvent> changeLog;

  String get notesMarkdown => notesRegister.value;

  static const _listEquality = ListEquality<String>();
  static const _setEquality = SetEquality<String>();

  const CampaignProfile.raw({
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
    this.notesRegister = const CrdtLwwRegister<String>(
      value: '',
      timestamp: HybridLogicalClock(
        physicalTime: 0,
        logicalCounter: 0,
        nodeId: 'genesis',
      ),
    ),
    this.partyPurse = const PartyPurse(),
    this.changeLog = const [],
  });

  factory CampaignProfile({
    required String id,
    required String name,
    DmRulesEdition edition = DmRulesEdition.v2024,
    required DateTime createdAt,
    required DateTime lastPlayedAt,
    required RoomNodeState roomState,
    List<String> partyCharacterIds = const [],
    Set<String> pinnedRuleIds = const {
      'concentration',
      'falling',
      'grapple_shove',
      'cover',
      'resting',
    },
    CrdtLwwRegister<String>? notesRegister,
    String? notesMarkdown,
    PartyPurse partyPurse = const PartyPurse(),
    List<PartyEvent> changeLog = const [],
  }) {
    final effectiveNotesRegister = notesRegister ??
        (notesMarkdown != null
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

    return CampaignProfile.raw(
      id: id,
      name: name,
      edition: edition,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt,
      roomState: roomState,
      partyCharacterIds: partyCharacterIds,
      pinnedRuleIds: pinnedRuleIds,
      notesRegister: effectiveNotesRegister,
      partyPurse: partyPurse,
      changeLog: changeLog,
    );
  }

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
        activeEncounter: const CrdtOrSet<EncounterParticipant>(),
      ),
      partyCharacterIds: const [],
      pinnedRuleIds: const {
        'concentration',
        'falling',
        'grapple_shove',
        'cover',
        'resting',
      },
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
    CrdtLwwRegister<String>? notesRegister,
    PartyPurse? partyPurse,
    List<PartyEvent>? changeLog,
    HybridLogicalClock? notesTimestamp,
  }) {
    final resolvedNotesRegister = notesRegister ??
        (notesMarkdown != null
            ? CrdtLwwRegister<String>(
                value: notesMarkdown,
                timestamp: notesTimestamp ??
                    HybridLogicalClock(
                      physicalTime: DateTime.now().millisecondsSinceEpoch,
                      logicalCounter: 0,
                      nodeId: id ?? this.id,
                    ),
              )
            : this.notesRegister);

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
      notesRegister: resolvedNotesRegister,
      partyPurse: partyPurse ?? this.partyPurse,
      changeLog: changeLog != null
          ? List<PartyEvent>.from(changeLog)
          : this.changeLog,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampaignProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          edition == other.edition &&
          roomState == other.roomState &&
          _listEquality.equals(partyCharacterIds, other.partyCharacterIds) &&
          _setEquality.equals(pinnedRuleIds, other.pinnedRuleIds) &&
          notesRegister == other.notesRegister &&
          partyPurse == other.partyPurse;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        edition,
        roomState,
        _listEquality.hash(partyCharacterIds),
        _setEquality.hash(pinnedRuleIds),
        notesRegister,
        partyPurse,
      );
}
