import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_room_lobby.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/logging_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
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
    rep = ReplicaId('test_node_f2');
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

  group('Cold Iron Birdcage — Pass 9.1 F2: Local Lobby Cache Isolation', () {
    test('Three Table Rows: Step 1 (addCharacterToRoster throws, null lobby, no port write), Step 2 (openRoomProfile throws), Control (openRoomProfile alone throws)', () async {
      // Step 1: addCharacterToRoster on fresh device with no doc
      await expectLater(
        () => service.addCharacterToRoster(
          roomCode: 'CR-W',
          characterName: 'Bob',
          playerName: 'Bob',
        ),
        throwsA(isA<RoomProfileNotFoundError>()),
      );
      expect(repo.allProfiles, isEmpty);
      expect(service.getCachedLobby('CR-W'), isNull);
      expect(recordingPort.createRoomCalls, isEmpty);
      expect(recordingPort.touchRoomLeaseCalls, isEmpty);
      expect(recordingPort.deleteRoomCalls, isEmpty);

      // Step 2: then openRoomProfile('CR-W')
      await expectLater(
        () => service.openRoomProfile('CR-W'),
        throwsA(isA<RoomProfileNotFoundError>()),
      );
      expect(repo.allProfiles, isEmpty);

      // Step 3 (Control): openRoomProfile alone on fresh device
      final freshRepo = _InMemoryCampaignRepo();
      final freshPort = RecordingRoomDocumentPort();
      sl.reset();
      sl.registerSingleton<ReplicaId>(rep);
      sl.registerSingleton<StatefulHlcClock>(clock);
      sl.registerSingleton<ICampaignRepository>(freshRepo);
      sl.registerSingleton<IRoomDocumentPort>(freshPort);
      CampaignProfileService.resetForTesting();
      final freshService = PartyRoomService(replicaId: rep, clock: clock);

      await expectLater(
        () => freshService.openRoomProfile('CR-W'),
        throwsA(isA<RoomProfileNotFoundError>()),
      );
      expect(freshRepo.allProfiles, isEmpty);
    });

    test('Cached lobby with no campaignId and server returns no document: openRoomProfile throws, profiles []', () async {
      service.cacheLobbyForTesting(
        PartyRoomLobby(
          roomCode: 'NO-DOC',
          campaignName: 'Orphan Lobby',
          hostKeyHash: 'dummyhash',
          activePlayers: const [],
          partyTelemetry: const {},
          sharedCharacters: const {},
          version: 1,
          lastUpdated: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      expect(service.getCachedLobby('NO-DOC'), isNotNull);

      await expectLater(
        () => service.openRoomProfile('NO-DOC'),
        throwsA(isA<RoomProfileNotFoundError>()),
      );
      expect(repo.allProfiles, isEmpty);
    });

    test('Cached lobby with no campaignId, server returns real legacy lobby document: openRoomProfile creates campaign_<CODE> and imports legacy ledger', () async {
      service.cacheLobbyForTesting(
        PartyRoomLobby(
          roomCode: 'LEG-1',
          campaignName: 'Local Stale Name',
          hostKeyHash: 'dummyhash',
          activePlayers: const [],
          partyTelemetry: const {},
          sharedCharacters: const {},
          version: 1,
          lastUpdated: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      // Server returns real legacy lobby document (no campaignId, old ledger keys)
      recordingPort.roomDataByCode['LEG-1'] = {
        'roomCode': 'LEG-1',
        'code': 'LEG-1',
        'campaignName': 'Legacy Campaign',
        'hostKeyHash': 'realhash',
        'activePlayers': ['Thorin'],
        'partyPurse': {'gp': 75},
        'characterRoster': ['Thorin'],
        'version': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      final profile = await service.openRoomProfile('LEG-1');
      expect(profile.id, equals('campaign_LEG-1'));
      expect(repo.allProfiles, hasLength(1));
      expect(repo.activeProfileId, equals('campaign_LEG-1'));
      expect(profile.partyPurse.getBalance('gp'), equals(75));
      expect(profile.partyRoster.activeValues, contains('Thorin'));
    });

    test('Server read throws: openRoomProfile throws, exactly one non-fatal logged, profiles []', () async {
      int nonFatalCount = 0;
      dynamic loggedError;
      String? loggedReason;

      LoggingService.onNonFatalForTesting = (err, st, reason) {
        nonFatalCount++;
        loggedError = err;
        loggedReason = reason;
      };
      addTearDown(() {
        LoggingService.onNonFatalForTesting = null;
      });

      recordingPort.shouldThrowOnGet = Exception('Simulated server read crash');

      await expectLater(
        () => service.openRoomProfile('CRASH1'),
        throwsA(isA<RoomProfileNotFoundError>()),
      );
      expect(repo.allProfiles, isEmpty);
      expect(nonFatalCount, equals(1));
      expect(loggedError, isNotNull);
      expect(loggedReason, contains('CRASH1'));
    });

    test('Control: on device where profile already exists for room, openRoomProfile with cached lobby returns profile without creating another and 0 reads', () async {
      // First, create campaign legitimately
      final created = await service.createCampaign(
        campaignName: 'Existing Campaign',
        customRoomCode: 'EXIST1',
        playerName: 'DM',
      );
      final createdProfile = repo.allProfiles.first;
      expect(repo.allProfiles, hasLength(1));
      expect(created.roomCode, equals('EXIST1'));
      final originalReads = recordingPort.getRoomDocumentCalls.length;

      // Ensure lobby is cached
      expect(service.getCachedLobby('EXIST1'), isNotNull);

      // Now call openRoomProfile with cached lobby
      final resolved = await service.openRoomProfile('EXIST1');
      expect(resolved.id, equals(createdProfile.id));
      expect(repo.allProfiles, hasLength(1));
      // Reads should be 0 new reads (same as today: existing profile resolved directly without extra fetch)
      expect(recordingPort.getRoomDocumentCalls.length, equals(originalReads));
    });

    test('Law test: 200 seeded cases of random sequences of 1-6 calls on fresh device with no doc leave profiles empty, getCachedLobby null, zero writes', () async {
      const int caseCount = 200;
      final masterRandom = Random(424242);

      for (int i = 0; i < caseCount; i++) {
        final seed = masterRandom.nextInt(1000000);
        final rng = Random(seed);

        // Setup fresh device for each test sequence
        final freshRepo = _InMemoryCampaignRepo();
        final freshPort = RecordingRoomDocumentPort();
        sl.reset();
        sl.registerSingleton<ReplicaId>(rep);
        sl.registerSingleton<StatefulHlcClock>(clock);
        sl.registerSingleton<ICampaignRepository>(freshRepo);
        sl.registerSingleton<IRoomDocumentPort>(freshPort);
        CampaignProfileService.resetForTesting();
        final testService = PartyRoomService(replicaId: rep, clock: clock);

        final roomCode = 'ROOM_$seed';
        final seqLength = 1 + rng.nextInt(6); // 1 to 6 calls

        final ops = <Future<dynamic> Function()>[
          () => testService.addCharacterToRoster(roomCode: roomCode, characterName: 'Hero', playerName: 'Hero'),
          () => testService.removeCharacterFromRoster(roomCode: roomCode, characterName: 'Hero', playerName: 'Hero'),
          () => testService.updateCharacterRoster(roomCode: roomCode, roster: ['Hero'], playerName: 'Hero'),
          () => testService.depositCoins(roomCode: roomCode, playerName: 'DM', gp: 10),
          () => testService.withdrawCoins(roomCode: roomCode, playerName: 'DM', gp: 10),
          () => testService.updateMemberPurse(roomCode: roomCode, characterName: 'Hero', characterSlug: 'hero', newPurse: PartyPurse(gp: 5), performedBy: 'DM'),
          () => testService.transferMemberToReserve(roomCode: roomCode, characterName: 'Hero', performedBy: 'DM', gp: 5),
          () => testService.transferReserveToMember(roomCode: roomCode, characterName: 'Hero', performedBy: 'DM', gp: 5),
          () => testService.disperseCoinsToParty(roomCode: roomCode, purseToDisperse: PartyPurse(gp: 10), recipientCharacters: ['Hero'], performedBy: 'DM'),
          () => testService.updateCharacterTelemetry(roomCode: roomCode, character: _createHero('hero', 'Hero')),
          () => testService.linkCharacterToCampaign(roomCode: roomCode, character: _createHero('hero', 'Hero')),
          () => testService.getLobby(roomCode),
          () => testService.ensureRoomExists(roomCode: roomCode),
          () => testService.openRoomProfile(roomCode),
        ];

        try {
          for (int step = 0; step < seqLength; step++) {
            final opIndex = rng.nextInt(ops.length);
            try {
              await ops[opIndex]();
            } catch (_) {
              // Expected failure on uninitialized room
            }
          }

          expect(freshRepo.allProfiles, isEmpty,
              reason: 'Failure on seed $seed: repository holds profiles after sequence');
          expect(testService.getCachedLobby(roomCode), isNull,
              reason: 'Failure on seed $seed: getCachedLobby was not null');
          expect(freshPort.createRoomCalls, isEmpty,
              reason: 'Failure on seed $seed: createRoom was called');
          expect(freshPort.touchRoomLeaseCalls, isEmpty,
              reason: 'Failure on seed $seed: touchRoomLease was called');
          expect(freshPort.deleteRoomCalls, isEmpty,
              reason: 'Failure on seed $seed: deleteRoom was called');
        } catch (e) {
          // Explicitly print seed on failure per spec
          // ignore: avoid_print
          print('Law test failed with seed: $seed');
          rethrow;
        }
      }
    });
  });
}
