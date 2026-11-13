import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_document_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/shared_room_campaign_opener.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import '../../test_doubles/fake_room_document_port.dart';
import '../../test_doubles/service_test_configurator.dart';

class _InMemoryCampaignRepo implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  CampaignProfile? _activeProfile;
  int putProfileCalls = 0;
  int updateProfileCalls = 0;
  int setActiveProfileIdCalls = 0;

  final _activeController = StreamController<CampaignProfile?>.broadcast();
  final _allController = StreamController<List<CampaignProfile>>.broadcast();

  void seedProfile(CampaignProfile profile) {
    profiles[profile.id] = profile;
  }

  void seedActiveProfile(CampaignProfile? profile) {
    _activeProfile = profile;
  }

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
    putProfileCalls++;
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
    updateProfileCalls++;
    final current =
        profiles[id] ?? (_activeProfile?.id == id ? _activeProfile : null);
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
    setActiveProfileIdCalls++;
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allController.stream;
}

CampaignProfile _makeProfile({
  required String id,
  required String roomCode,
  String name = 'Campaign',
}) {
  final now = DateTime.utc(2026, 11, 12, 12, 0, 0);
  return CampaignProfile.placeholder(
    id: id,
    roomCode: roomCode,
    name: name,
    stagingTitle: '$name Staging',
    createdAt: now,
    lastPlayedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReplicaId rep;
  late StatefulHlcClock clock;
  late _InMemoryCampaignRepo repo;
  late RecordingRoomDocumentPort port;
  late PartyRoomService party;
  late SharedRoomCampaignOpener opener;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetTestServices();
    sl.reset();
    rep = ReplicaId('node_opener_test');
    clock = StatefulHlcClock(replicaId: rep);
    repo = _InMemoryCampaignRepo();
    port = RecordingRoomDocumentPort();

    sl.registerSingleton<ReplicaId>(rep);
    sl.registerSingleton<StatefulHlcClock>(clock);
    sl.registerSingleton<ICampaignRepository>(repo);
    sl.registerSingleton<IRoomDocumentPort>(port);

    CampaignProfileService.resetForTesting();
    configureTestServices(repository: repo, replicaId: rep, clock: clock);
    party = PartyRoomService(replicaId: rep, clock: clock);
    opener = SharedRoomCampaignOpener(
      party: party,
      campaignRepo: repo,
      roomDocPort: port,
    );
  });

  tearDown(() {
    resetTestServices();
    sl.reset();
  });

  group('SharedRoomCampaignOpener — Fix 1.1 examples and law', () {
    test('(a) New dice room with no room document yet returns null, writes no profile, leaves active unchanged', () async {
      final result = await opener.openIfCampaign('ROOM-AAA111');

      expect(result, isNull);
      expect(repo.allProfiles, isEmpty);
      expect(repo.activeProfileId, isNull);
      expect(repo.putProfileCalls, equals(0));
      expect(repo.setActiveProfileIdCalls, equals(0));
      expect(port.createRoomCalls, isEmpty);
      expect(port.touchRoomLeaseCalls, isEmpty);
      expect(port.deleteRoomCalls, isEmpty);
    });

    test('(b) Existing dice room document (no campaignId) with cmp_home active returns null, creates no profile, keeps cmp_home active', () async {
      final home = _makeProfile(
        id: 'cmp_home',
        roomCode: 'ROOM-HOME01',
        name: 'Home Campaign',
      );
      repo.seedProfile(home);
      repo.seedActiveProfile(home);

      final now = DateTime.utc(2026, 11, 12, 12, 0, 0);
      port.roomDataByCode['ROOM-BBB222'] = {
        'roomCode': 'ROOM-BBB222',
        'code': 'ROOM-BBB222',
        'campaignName': 'Dice Room ROOM-BBB222',
        'activePlayers': ['Valen'],
        'lastUpdated': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      };

      final result = await opener.openIfCampaign('ROOM-BBB222');

      expect(result, isNull);
      expect(repo.allProfiles.map((p) => p.id).toList(), equals(['cmp_home']));
      expect(repo.activeProfileId, equals('cmp_home'));
      expect(repo.putProfileCalls, equals(0));
      expect(repo.setActiveProfileIdCalls, equals(0));
      expect(port.createRoomCalls, isEmpty);
      expect(port.touchRoomLeaseCalls, isEmpty);
      expect(port.deleteRoomCalls, isEmpty);
    });

    test('(c) Control: room document with campaignId cmp_abc opens cmp_abc and makes it active', () async {
      final now = DateTime.utc(2026, 11, 12, 12, 0, 0);
      port.roomDataByCode['ROOM-CCC333'] = {
        'roomCode': 'ROOM-CCC333',
        'code': 'ROOM-CCC333',
        'campaignId': 'cmp_abc',
        'campaignName': 'Dragon Heist',
        'hostKeyHash': 'a' * 64,
        'activePlayers': ['Valen'],
        'lastUpdated': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      };

      final result = await opener.openIfCampaign('ROOM-CCC333');

      expect(result, isNotNull);
      expect(result!.id, equals('cmp_abc'));
      expect(repo.activeProfileId, equals('cmp_abc'));
      expect(repo.allProfiles.map((p) => p.id), contains('cmp_abc'));
    });

    test('(d) Legacy-shaped document (no campaignId) for a code claimed by a local profile returns that profile and makes it active', () async {
      final other = _makeProfile(
        id: 'cmp_other',
        roomCode: 'ROOM-OTH999',
        name: 'Other Campaign',
      );
      final mine = _makeProfile(
        id: 'cmp_mine',
        roomCode: 'ROOM-MINE01',
        name: 'My Campaign',
      );
      repo.seedProfile(other);
      repo.seedProfile(mine);
      repo.seedActiveProfile(other);

      final now = DateTime.utc(2026, 11, 12, 12, 0, 0);
      port.roomDataByCode['ROOM-MINE01'] = {
        'roomCode': 'ROOM-MINE01',
        'code': 'ROOM-MINE01',
        'campaignName': 'My Campaign',
        'hostKeyHash': 'b' * 64,
        'activePlayers': ['DM'],
        'lastUpdated': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
      };

      final result = await opener.openIfCampaign('  room-mine01  ');

      expect(result, isNotNull);
      expect(result!.id, equals('cmp_mine'));
      expect(repo.activeProfileId, equals('cmp_mine'));
      expect(repo.allProfiles, hasLength(2));
    });

    test('(e) Blank or whitespace-only campaignId counts as no campaign id', () async {
      final now = DateTime.utc(2026, 11, 12, 12, 0, 0);
      for (final blankId in ['', '   ', '\t\n ']) {
        port.roomDataByCode['ROOM-BLANK'] = {
          'roomCode': 'ROOM-BLANK',
          'code': 'ROOM-BLANK',
          'campaignId': blankId,
          'campaignName': 'Dice Room ROOM-BLANK',
          'activePlayers': ['Valen'],
          'lastUpdated': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
        };

        final result = await opener.openIfCampaign('ROOM-BLANK');
        expect(result, isNull, reason: 'Failed for blankId="$blankId"');
        expect(repo.allProfiles, isEmpty);
        expect(repo.activeProfileId, isNull);
        expect(repo.putProfileCalls, equals(0));
        expect(repo.setActiveProfileIdCalls, equals(0));
      }
    });

    test('(f) Port whose getRoomDocument throws propagates error and writes no profile', () async {
      port.shouldThrowOnGet = Exception('Firestore unavailable');

      await expectLater(
        () => opener.openIfCampaign('ROOM-ERR999'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'toString()',
            contains('Firestore unavailable'),
          ),
        ),
      );

      expect(repo.allProfiles, isEmpty);
      expect(repo.activeProfileId, isNull);
      expect(repo.putProfileCalls, equals(0));
      expect(repo.setActiveProfileIdCalls, equals(0));
    });

    test('Law: 500 seeded random cases obey campaign vs plain dice room invariants', () async {
      const int seed = 20261112;
      const int caseCount = 500;
      final rng = Random(seed);
      const codePool = [
        'ROOM-POOL1',
        'ROOM-POOL2',
        'ROOM-POOL3',
        'ROOM-POOL4',
        'ROOM-POOL5',
      ];
      final baseTime = DateTime.utc(2026, 11, 12, 15, 0, 0);

      for (int i = 0; i < caseCount; i++) {
        final caseRepo = _InMemoryCampaignRepo();
        final casePort = RecordingRoomDocumentPort();
        final caseRep = ReplicaId('law_node_$i');
        final caseClock = StatefulHlcClock(replicaId: caseRep);

        sl.reset();
        sl.registerSingleton<ReplicaId>(caseRep);
        sl.registerSingleton<StatefulHlcClock>(caseClock);
        sl.registerSingleton<ICampaignRepository>(caseRepo);
        sl.registerSingleton<IRoomDocumentPort>(casePort);
        CampaignProfileService.resetForTesting();
        configureTestServices(
          repository: caseRepo,
          replicaId: caseRep,
          clock: caseClock,
        );
        final caseParty = PartyRoomService(
          replicaId: caseRep,
          clock: caseClock,
          roomDocumentPort: casePort,
        );
        final caseOpener = SharedRoomCampaignOpener(
          party: caseParty,
          campaignRepo: caseRepo,
          roomDocPort: casePort,
        );

        final targetCode = codePool[rng.nextInt(codePool.length)];
        final queryCode = rng.nextBool()
            ? targetCode
            : '  ${targetCode.toLowerCase()} ';

        // Draw 0 to 3 local profiles with distinct room codes from codePool
        final profileCount = rng.nextInt(4);
        final shuffledCodes = List<String>.from(codePool)..shuffle(rng);
        final initialProfiles = <CampaignProfile>[];
        CampaignProfile? claimingProfile;

        for (int pIdx = 0; pIdx < profileCount; pIdx++) {
          final pCode = shuffledCodes[pIdx];
          final profile = _makeProfile(
            id: 'cmp_local_${i}_$pIdx',
            roomCode: pCode,
            name: 'Local Campaign $pIdx',
          );
          caseRepo.seedProfile(profile);
          initialProfiles.add(profile);
          if (pCode == targetCode) {
            claimingProfile = profile;
          }
        }

        // Random active profile, or none
        CampaignProfile? initialActive;
        if (initialProfiles.isNotEmpty && rng.nextBool()) {
          initialActive = initialProfiles[rng.nextInt(initialProfiles.length)];
        }
        caseRepo.seedActiveProfile(initialActive);

        // Draw room document: absent or subset of lobby keys
        final bool docPresent = rng.nextBool();
        String? drawnCampaignIdKind;
        String? nonBlankCampaignId;
        Map<String, dynamic>? doc;

        if (docPresent) {
          doc = <String, dynamic>{};
          if (rng.nextBool()) doc['roomCode'] = targetCode;
          if (rng.nextBool()) doc['code'] = targetCode;
          if (rng.nextBool()) doc['campaignName'] = 'Room $targetCode';
          if (rng.nextBool()) {
            doc['hostKeyHash'] = rng.nextBool() ? '' : ('a' * 64);
          }
          if (rng.nextBool()) doc['activePlayers'] = ['Player1'];
          if (rng.nextBool()) doc['isStateless'] = rng.nextBool();
          if (rng.nextBool()) {
            doc['rulesetId'] = rng.nextBool() ? 'dnd5e_2024' : 'dnd5e_2014';
          }
          if (rng.nextBool()) doc['createdAt'] = baseTime.toIso8601String();
          if (rng.nextBool()) doc['lastUpdated'] = baseTime.toIso8601String();
          if (rng.nextBool()) {
            doc['expiresAt'] =
                baseTime.add(const Duration(days: 30)).toIso8601String();
          }

          // campaignId: absent, null, '', whitespace, or a real id
          final cidChoice = rng.nextInt(5);
          if (cidChoice == 0) {
            drawnCampaignIdKind = 'absent';
          } else if (cidChoice == 1) {
            drawnCampaignIdKind = 'null';
            doc['campaignId'] = null;
          } else if (cidChoice == 2) {
            drawnCampaignIdKind = 'empty';
            doc['campaignId'] = '';
          } else if (cidChoice == 3) {
            drawnCampaignIdKind = 'whitespace';
            doc['campaignId'] = '   \t ';
          } else {
            drawnCampaignIdKind = 'real';
            final realId = claimingProfile?.id ?? 'cmp_remote_$i';
            doc['campaignId'] = realId;
            nonBlankCampaignId = realId;
          }

          casePort.roomDataByCode[targetCode] = doc;
        } else {
          drawnCampaignIdKind = 'no_doc';
        }

        final beforeProfilesById = Map<String, CampaignProfile>.from(
          caseRepo.profiles,
        );
        final beforeActiveId = caseRepo.activeProfileId;

        final caseDescription =
            'case=$i seed=$seed targetCode=$targetCode '
            'localProfiles=${initialProfiles.map((p) => '${p.id}:${p.roomState.roomCode}').toList()} '
            'initialActive=${initialActive?.id} docPresent=$docPresent '
            'campaignIdKind=$drawnCampaignIdKind doc=$doc';

        try {
          final result = await caseOpener.openIfCampaign(queryCode);

          final bool isPlainDiceRoom =
              claimingProfile == null && nonBlankCampaignId == null;

          if (isPlainDiceRoom) {
            expect(result, isNull, reason: 'Expected null for $caseDescription');
            expect(
              caseRepo.profiles.keys.toSet(),
              equals(beforeProfilesById.keys.toSet()),
              reason: 'Profile IDs changed for $caseDescription',
            );
            for (final id in beforeProfilesById.keys) {
              expect(
                caseRepo.profiles[id],
                equals(beforeProfilesById[id]),
                reason: 'Profile $id mutated for $caseDescription',
              );
            }
            expect(
              caseRepo.activeProfileId,
              equals(beforeActiveId),
              reason: 'Active profile ID changed for $caseDescription',
            );
            expect(
              caseRepo.putProfileCalls,
              equals(0),
              reason: 'putProfile called for $caseDescription',
            );
            expect(
              caseRepo.updateProfileCalls,
              equals(0),
              reason: 'updateProfile called for $caseDescription',
            );
            expect(
              caseRepo.setActiveProfileIdCalls,
              equals(0),
              reason: 'setActiveProfileId called for $caseDescription',
            );
            expect(
              casePort.createRoomCalls,
              isEmpty,
              reason: 'createRoom called for $caseDescription',
            );
            expect(
              casePort.touchRoomLeaseCalls,
              isEmpty,
              reason: 'touchRoomLease called for $caseDescription',
            );
            expect(
              casePort.deleteRoomCalls,
              isEmpty,
              reason: 'deleteRoom called for $caseDescription',
            );
          } else {
            expect(
              result,
              isNotNull,
              reason: 'Expected non-null profile for $caseDescription',
            );
            expect(
              caseRepo.activeProfileId,
              equals(result!.id),
              reason: 'Active profile ID != result.id for $caseDescription',
            );
          }
        } catch (e) {
          stdout.writeln(
            'SharedRoomCampaignOpener law failed on $caseDescription: $e',
          );
          rethrow;
        }
      }

      stdout.writeln(
        'SharedRoomCampaignOpener law passed: seed=$seed, cases=$caseCount',
      );
    });
  });
}
