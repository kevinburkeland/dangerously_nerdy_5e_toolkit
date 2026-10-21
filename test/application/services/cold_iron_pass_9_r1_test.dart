import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/entity_reference.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_room_lobby.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/logging_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/room_code_relink.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import '../../test_doubles/fake_room_document_port.dart';

class _InMemoryCampaignRepo implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  CampaignProfile? _activeProfile;

  final _activeController = StreamController<CampaignProfile?>.broadcast();
  final _allController = StreamController<List<CampaignProfile>>.broadcast();

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
      _activeController.add(profile);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final current = profiles[id] ?? (_activeProfile?.id == id ? _activeProfile! : null);
    if (current == null) throw StateError('Profile not found: $id');
    final updated = transform(current);
    await putProfile(updated);
    return updated;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _activeController.add(null);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allController.stream;
}

Character _createHero(String slug, String name, {int gp = 0}) {
  return Character(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
    purse: PartyPurse(gp: gp),
    speciesRef: const EntityReference.empty(
      slug: 'human',
      refType: EntityType.species,
      displayName: 'Human',
    ),
    progression: const CharacterProgression(classes: []),
    baseScores: const AbilityScores.standardArray(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReplicaId rep;
  late StatefulHlcClock clock;
  late _InMemoryCampaignRepo repo;
  late RecordingRoomDocumentPort recordingPort;
  late PartyRoomService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sl.reset();
    rep = ReplicaId('test_node_r1_r2');
    clock = StatefulHlcClock(replicaId: rep);
    repo = _InMemoryCampaignRepo();
    recordingPort = RecordingRoomDocumentPort();

    sl.registerSingleton<ReplicaId>(rep);
    sl.registerSingleton<StatefulHlcClock>(clock);
    sl.registerSingleton<ICampaignRepository>(repo);
    sl.registerSingleton<IRoomDocumentPort>(recordingPort);

    CampaignProfileService.resetForTesting();
    service = PartyRoomService(replicaId: rep, clock: clock);
  });

  group('Part A: R1 Invariant - Only room entry may create a campaign profile', () {
    test('Row 1: openRoomProfile for non-existent room with no lobby throws StateError, profiles remains []', () async {
      expect(
        () => service.openRoomProfile('CR-Y'),
        throwsA(isA<StateError>()),
      );
      expect(repo.allProfiles, isEmpty);
    });

    test('Row 2: addCharacterToRoster for non-existent room with no lobby throws StateError, profiles remains []', () async {
      expect(
        () => service.addCharacterToRoster(
          roomCode: 'CR-Y',
          characterName: 'Bob',
          playerName: 'Bob',
        ),
        throwsA(isA<StateError>()),
      );
      expect(repo.allProfiles, isEmpty);
    });

    test('Row 3: ensureRoomExists for non-existent room with no lobby throws StateError, profiles remains [], nothing written to room port', () async {
      expect(
        () => service.ensureRoomExists(roomCode: 'CR-Z'),
        throwsA(isA<StateError>()),
      );
      expect(repo.allProfiles, isEmpty);
      expect(recordingPort.touchRoomLeaseCalls, isEmpty);
    });

    test('Table-driven: Every ledger and telemetry operation family throws when called on room with no profile/lobby', () async {
      final operations = <String, Future<void> Function()>{
        'addCharacterToRoster': () => service.addCharacterToRoster(roomCode: 'EMPTY1', characterName: 'Hero', playerName: 'Hero'),
        'removeCharacterFromRoster': () => service.removeCharacterFromRoster(roomCode: 'EMPTY1', characterName: 'Hero', playerName: 'Hero'),
        'updateCharacterRoster': () => service.updateCharacterRoster(roomCode: 'EMPTY1', roster: ['Hero'], playerName: 'Hero'),
        'depositCoins': () => service.depositCoins(roomCode: 'EMPTY1', playerName: 'DM', gp: 10),
        'withdrawCoins': () => service.withdrawCoins(roomCode: 'EMPTY1', playerName: 'DM', gp: 10),
        'updateMemberPurse': () => service.updateMemberPurse(roomCode: 'EMPTY1', characterName: 'Hero', newPurse: PartyPurse(gp: 5), performedBy: 'DM'),
        'transferMemberToReserve': () => service.transferMemberToReserve(roomCode: 'EMPTY1', characterName: 'Hero', performedBy: 'DM', gp: 5),
        'transferReserveToMember': () => service.transferReserveToMember(roomCode: 'EMPTY1', characterName: 'Hero', performedBy: 'DM', gp: 5),
        'disperseCoinsToParty': () => service.disperseCoinsToParty(roomCode: 'EMPTY1', purseToDisperse: PartyPurse(gp: 10), recipientCharacters: ['Hero'], performedBy: 'DM'),
        'updateCharacterTelemetry': () => service.updateCharacterTelemetry(roomCode: 'EMPTY1', character: _createHero('hero', 'Hero')),
        'linkCharacterToCampaign': () => service.linkCharacterToCampaign(roomCode: 'EMPTY1', character: _createHero('hero', 'Hero')),
        'leaveCampaign': () => service.leaveCampaign(roomCode: 'EMPTY1', playerName: 'Hero'),
      };

      for (final entry in operations.entries) {
        expect(
          entry.value,
          throwsA(isA<StateError>()),
          reason: '${entry.key} must throw StateError when no profile or lobby exists',
        );
        expect(
          repo.allProfiles,
          isEmpty,
          reason: '${entry.key} must not create any campaign profile in repository',
        );
      }
    });

    test('Control: All operations succeed when campaign is created/opened first', () async {
      await service.createCampaign(
        campaignName: 'Active Campaign',
        customRoomCode: 'ACTIVE1',
        playerName: 'DM',
      );
      expect(repo.allProfiles, hasLength(1));

      final hero = _createHero('aragorn', 'Aragorn', gp: 10);
      await service.addCharacterToRoster(roomCode: 'ACTIVE1', characterName: 'aragorn', playerName: 'DM');
      await service.linkCharacterToCampaign(roomCode: 'ACTIVE1', character: hero);
      await service.depositCoins(roomCode: 'ACTIVE1', playerName: 'DM', gp: 20);
      await service.withdrawCoins(roomCode: 'ACTIVE1', playerName: 'DM', gp: 5);
      await service.updateMemberPurse(roomCode: 'ACTIVE1', characterName: 'aragorn', characterSlug: 'aragorn', newPurse: PartyPurse(gp: 20), performedBy: 'DM');
      await service.updateCharacterTelemetry(roomCode: 'ACTIVE1', character: hero);

      final profile = await repo.getActiveProfile();
      expect(profile, isNotNull);
      expect(profile!.partyPurse.getBalance('gp'), equals(15));
      expect(profile.memberPurses['aragorn']?.getBalance('gp'), equals(20));
    });

    test('Legacy test campaign shape: hosted legacy lobby with old ledger keys and no campaignId joins properly', () async {
      recordingPort.roomDataByCode['LEGACY1'] = {
        'roomCode': 'LEGACY1',
        'code': 'LEGACY1',
        'campaignName': 'Old Campaign',
        'hostKeyHash': 'abc123hash',
        'activePlayers': ['Gimli'],
        'partyPurse': {'gp': 50},
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      final joined = await service.joinCampaign(
        roomCode: 'LEGACY1',
        playerName: 'Gimli',
      );
      expect(joined.roomCode, equals('LEGACY1'));
      expect(repo.activeProfileId, equals('campaign_LEGACY1'));
      expect(repo.allProfiles, hasLength(1));

      await service.depositCoins(
        roomCode: 'LEGACY1',
        playerName: 'DM',
        gp: 10,
      );

      final updated = await repo.getProfile('campaign_LEGACY1');
      expect(updated!.partyPurse.getBalance('gp'), equals(60));
    });

    test('Lobby read failure: a fake that throws on the read produces one logged non-fatal and no profile', () async {
      dynamic loggedError;
      String? loggedReason;
      LoggingService.onNonFatalForTesting = (err, st, reason) {
        loggedError = err;
        loggedReason = reason;
      };
      addTearDown(() {
        LoggingService.onNonFatalForTesting = null;
      });

      recordingPort.shouldThrowOnGet = Exception('Simulated Firestore read timeout');

      await expectLater(
        () => service.openRoomProfile('FAIL1'),
        throwsA(isA<StateError>()),
      );
      expect(repo.allProfiles, isEmpty);
      expect(loggedError, isNotNull);
    });
  });
}

