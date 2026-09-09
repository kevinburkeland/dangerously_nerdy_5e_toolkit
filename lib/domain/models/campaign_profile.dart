import 'package:meta/meta.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/character_models.dart';
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
  final String notesMarkdown;
  final PartyPurse partyPurse;
  final List<PartyEvent> changeLog;

  /// Transient, non-serialized field holding characters extracted during deserialization migration.
  final List<Character> _migratedCharacters;
  List<Character> get migratedCharacters => _migratedCharacters;

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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CampaignProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
