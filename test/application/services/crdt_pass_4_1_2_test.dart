import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/aggregate_hlc_extractor.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_event.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Birdcage — Pass 4.1.2: Authoritative Presence & Re-addable Roster', () {
    late RoomStateReconciliationService reconciliationService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppServices.reset();
      sl.reset();
      reconciliationService = RoomStateReconciliationService();
    });

    tearDown(() {
      sl.reset();
    });

    CampaignProfile createSampleProfile({
      String id = 'camp-pass412',
      String name = 'Pass 4.1.2 Campaign',
      CrdtOrSet<String>? partyRoster,
      List<String>? partyCharacterIds,
      CrdtOrSet<String>? pinnedRules,
      CrdtLwwRegister<String>? notesRegister,
      RoomNodeState? roomState,
      PartyPurse? partyPurse,
      List<PartyEvent> changeLog = const [],
    }) {
      final now = DateTime.utc(2026, 1, 1, 12, 0);
      return CampaignProfile.raw(
        id: id,
        name: name,
        edition: RulesetEdition.v2024,
        createdAt: now,
        lastPlayedAt: now,
        roomState: roomState ??
            RoomNodeState(
              roomId: 'room-1',
              roomCode: 'RC-101',
              title: 'Main Hall',
            ),
        partyRoster: partyRoster,
        partyCharacterIds: partyCharacterIds,
        pinnedRules: pinnedRules,
        notesRegister: notesRegister ??
            const CrdtLwwRegister<String>(
              value: 'Default Notes',
              timestamp: HybridLogicalClock(
                physicalTime: 100,
                logicalCounter: 0,
                nodeId: 'genesis',
              ),
            ),
        partyPurse: partyPurse ?? const PartyPurse.empty(),
        changeLog: changeLog,
      );
    }

    group('A. Strict Authoritative notesRegister Presence', () {
      test('1. notesRegister absent + notesMarkdown present -> deterministic legacy genesis migration succeeds', () {
        final map = {
          'id': 'c1',
          'name': 'Legacy Notes Campaign',
          'notesMarkdown': 'Historical campaign notes.',
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.notesMarkdown, equals('Historical campaign notes.'));
        expect(profile.notesRegister.value, equals('Historical campaign notes.'));
        expect(profile.notesRegister.timestamp.nodeId, equals('genesis'));
        expect(profile.notesRegister.timestamp.physicalTime, equals(0));
      });

      test('2. notesRegister present valid -> authoritative register used', () {
        final map = {
          'id': 'c1',
          'notesRegister': {
            'v': 'Authoritative Notes',
            'ts': {'pt': 2000, 'lc': 1, 'node': 'peer-1'},
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.notesRegister.value, equals('Authoritative Notes'));
        expect(profile.notesRegister.timestamp.physicalTime, equals(2000));
        expect(profile.notesRegister.timestamp.logicalCounter, equals(1));
        expect(profile.notesRegister.timestamp.nodeId, equals('peer-1'));
      });

      test('3. notesRegister present null -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'notesRegister': null,
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('4. notesRegister present wrong type -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'notesRegister': 'not-a-map',
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('5. notesRegister present malformed internal HLC/register -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'notesRegister': {
            'v': 'Malformed Notes',
            'ts': 'not-a-map-hlc',
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('6. both notesRegister and notesMarkdown present -> authoritative register validates and wins', () {
        final map = {
          'id': 'c1',
          'notesMarkdown': 'Legacy text that should lose',
          'notesRegister': {
            'v': 'Authoritative winning text',
            'ts': {'pt': 5000, 'lc': 2, 'node': 'winning-node'},
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.notesRegister.value, equals('Authoritative winning text'));
        expect(profile.notesRegister.timestamp.nodeId, equals('winning-node'));
      });
    });

    group('B. Strict Authoritative roomState Presence', () {
      test('1. roomState absent -> deterministic legacy/default room migration occurs', () {
        final map = {
          'id': 'c-no-room',
          'name': 'Default Room Campaign',
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.roomState.roomId, equals('room_c-no-room'));
        expect(profile.roomState.roomCode, equals('CR-101'));
        expect(profile.roomState.title, equals('Default Room Campaign Staging'));
      });

      test('2. roomState present valid -> authoritative roomState used', () {
        final map = {
          'id': 'c1',
          'roomState': {
            'roomId': 'room-99',
            'roomCode': 'RC-99',
            'title': 'Dungeon Depth',
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.roomState.roomId, equals('room-99'));
        expect(profile.roomState.roomCode, equals('RC-99'));
        expect(profile.roomState.title, equals('Dungeon Depth'));
      });

      test('3. roomState present null -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'roomState': null,
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('4. roomState present wrong type -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'roomState': 'not-a-map',
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('5. roomState present malformed nested CRDT -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'roomState': {
            'roomId': 'room-bad',
            'roomCode': 'RC-BAD',
            'entityLinks_crdt': 'invalid-crdt-string',
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });
    });

    group('C & X. Strict Authoritative partyRoster_crdt Presence', () {
      test('1. partyRoster_crdt absent + legacy partyCharacterIds present -> deterministic genesis migration succeeds', () {
        final map = {
          'id': 'c-legacy-party',
          'partyCharacterIds': ['fighter-1', 'wizard-1'],
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.partyCharacterIds, equals(['fighter-1', 'wizard-1']));
        expect(profile.partyRoster.activeValues, containsAll(['fighter-1', 'wizard-1']));
        for (final entry in profile.partyRoster.items.values) {
          expect(entry.timestamp.nodeId, equals('genesis'));
          expect(entry.timestamp.physicalTime, equals(0));
        }
      });

      test('2. partyRoster_crdt present valid -> authoritative CRDT used', () {
        final map = {
          'id': 'c1',
          'partyRoster_crdt': {
            'items': {
              'cleric-1': {
                'v': 'cleric-1',
                'ts': {'pt': 1500, 'lc': 0, 'node': 'node-1'},
              },
            },
            'tombstones': {},
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.partyCharacterIds, equals(['cleric-1']));
        expect(profile.partyRoster.items['cleric-1']!.timestamp.physicalTime, equals(1500));
        expect(profile.partyRoster.items['cleric-1']!.timestamp.nodeId, equals('node-1'));
      });

      test('3. partyRoster_crdt present null -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'partyRoster_crdt': null,
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('4. partyRoster_crdt present wrong type -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'partyRoster_crdt': ['not-a-map'],
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('5. partyRoster_crdt present malformed item or tombstone -> fails loud with FormatException', () {
        final map = {
          'id': 'c1',
          'partyRoster_crdt': {
            'items': {
              'cleric-1': 'invalid-register-shape',
            },
          },
        };
        expect(() => CampaignProfileDto.fromMap(map), throwsA(isA<FormatException>()));
      });

      test('6. both partyRoster_crdt and partyCharacterIds present -> authoritative CRDT validates and wins', () {
        final map = {
          'id': 'c1',
          'partyCharacterIds': ['should-lose-char'],
          'partyRoster_crdt': {
            'items': {
              'winning-char': {
                'v': 'winning-char',
                'ts': {'pt': 2000, 'lc': 0, 'node': 'authoritative-node'},
              },
            },
            'tombstones': {},
          },
        };
        final dto = CampaignProfileDto.fromMap(map);
        final profile = dto.toDomain();

        expect(profile.partyCharacterIds, equals(['winning-char']));
        expect(profile.partyCharacterIds.contains('should-lose-char'), isFalse);
      });
    });

    group('L. Roster HLC Extraction', () {
      test('extractCampaignProfileTimestamps extracts 11 distinct timestamps', () {
        final profile = CampaignProfile.raw(
          id: 'camp-11-ts',
          name: '11 Timestamps Profile',
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: RoomNodeState(
            roomId: 'room-1',
            roomCode: 'RC-101',
            title: 'Main Hall',
            entityLinksCrdt: const CrdtOrSet<RoomEntityLink>.empty()
                .add('link-1', RoomEntityLink(entityId: 'link-1', displayName: 'Link 1'), const HybridLogicalClock(physicalTime: 101, logicalCounter: 0, nodeId: 'n1'))
                .remove('link-2', const HybridLogicalClock(physicalTime: 102, logicalCounter: 0, nodeId: 'n1')),
            activeMinions: const CrdtOrSet<dynamic>.empty()
                .add('min-1', {'id': 'min-1'}, const HybridLogicalClock(physicalTime: 201, logicalCounter: 0, nodeId: 'n1'))
                .remove('min-2', const HybridLogicalClock(physicalTime: 202, logicalCounter: 0, nodeId: 'n1')),
            activeEncounter: const CrdtOrSet<EncounterParticipant>.empty()
                .add('p-1', EncounterParticipant(participantId: 'p-1', entityLink: RoomEntityLink(entityId: 'p-1', displayName: 'P1')), const HybridLogicalClock(physicalTime: 301, logicalCounter: 0, nodeId: 'n1'))
                .remove('p-2', const HybridLogicalClock(physicalTime: 302, logicalCounter: 0, nodeId: 'n1')),
          ),
          notesRegister: const CrdtLwwRegister<String>(
            value: 'Notes',
            timestamp: HybridLogicalClock(physicalTime: 401, logicalCounter: 0, nodeId: 'n1'),
          ),
          pinnedRules: const CrdtOrSet<String>.empty()
              .add('rule-1', 'rule-1', const HybridLogicalClock(physicalTime: 501, logicalCounter: 0, nodeId: 'n1'))
              .remove('rule-2', const HybridLogicalClock(physicalTime: 502, logicalCounter: 0, nodeId: 'n1')),
          partyRoster: const CrdtOrSet<String>.empty()
              .add('hero-1', 'hero-1', const HybridLogicalClock(physicalTime: 601, logicalCounter: 0, nodeId: 'n1'))
              .remove('hero-2', const HybridLogicalClock(physicalTime: 602, logicalCounter: 0, nodeId: 'n1')),
        );

        final extracted = extractCampaignProfileTimestamps(profile);
        expect(extracted.length, equals(11));

        final physicalTimes = extracted.map((e) => e.physicalTime).toSet();
        expect(physicalTimes, containsAll([101, 102, 201, 202, 301, 302, 401, 501, 502, 601, 602]));
      });
    });

    group('M. Remote Drift Test for Roster CRDT', () {
      test('Remote profile with partyRoster item HLC = T + 10 years fails remote drift validation', () {
        final clock = StatefulHlcClock(
          replicaId: ReplicaId('local-node'),
          timeProvider: () => 1700000000000,
        );
        final farFutureItemTs = HybridLogicalClock(
          physicalTime: 1700000000000 + const Duration(days: 3650).inMilliseconds,
          logicalCounter: 0,
          nodeId: 'remote-malicious',
        );

        final remoteProfile = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty().add('hacked-hero', 'hacked-hero', farFutureItemTs),
        );

        final timestamps = extractCampaignProfileTimestamps(remoteProfile);
        final initialClockState = clock.latest;

        expect(
          () => clock.validateAllRemote(timestamps),
          throwsA(isA<HlcFutureDriftException>()),
        );

        // Assert clock was NOT advanced:
        expect(clock.latest, equals(initialClockState));
      });

      test('Remote profile with partyRoster tombstone HLC = T + 10 years fails remote drift validation', () {
        final clock = StatefulHlcClock(
          replicaId: ReplicaId('local-node'),
          timeProvider: () => 1700000000000,
        );
        final farFutureTombstoneTs = HybridLogicalClock(
          physicalTime: 1700000000000 + const Duration(days: 3650).inMilliseconds,
          logicalCounter: 0,
          nodeId: 'remote-malicious',
        );

        final remoteProfile = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty().remove('tombstone-hero', farFutureTombstoneTs),
        );

        final timestamps = extractCampaignProfileTimestamps(remoteProfile);
        final initialClockState = clock.latest;

        expect(
          () => clock.validateAllRemote(timestamps),
          throwsA(isA<HlcFutureDriftException>()),
        );

        // Assert clock was NOT advanced:
        expect(clock.latest, equals(initialClockState));
      });
    });

    group('N. Trusted Local Roster History Observation', () {
      test('Local profile with roster history (item T+4h, tombstone T+6h) observed monotonically', () {
        const wallClockT = 1700000000000;
        final clock = StatefulHlcClock(
          replicaId: ReplicaId('current-replica'),
          timeProvider: () => wallClockT,
        );

        final itemTs = HybridLogicalClock(
          physicalTime: wallClockT + const Duration(hours: 4).inMilliseconds,
          logicalCounter: 5,
          nodeId: 'past-node-1',
        );
        final tombstoneTs = HybridLogicalClock(
          physicalTime: wallClockT + const Duration(hours: 6).inMilliseconds,
          logicalCounter: 10,
          nodeId: 'past-node-2',
        );

        final localProfile = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty()
              .add('char-1', 'char-1', itemTs)
              .remove('char-2', tombstoneTs),
        );

        // Load & observe trusted history
        final timestamps = extractCampaignProfileTimestamps(localProfile);
        expect(() => clock.observeAllTrustedHistory(timestamps), returnsNormally);

        // Next local timestamp must tick strictly ahead of T + 6h:
        final nextTs = clock.nextTimestamp();
        expect(nextTs.physicalTime, greaterThanOrEqualTo(tombstoneTs.physicalTime));
        expect(nextTs.nodeId, equals('current-replica'));
      });
    });

    group('O, P & Q. Roster Re-add, Stale Peer & Three-Replica Convergence', () {
      test('Remove -> stale peer -> re-add regression: cleric-1 remains ACTIVE', () {
        // Base: roster contains cleric-1 at HLC 10
        final base = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty().add(
            'cleric-1',
            'cleric-1',
            const HybridLogicalClock(physicalTime: 10, logicalCounter: 0, nodeId: 'genesis'),
          ),
        );
        expect(base.partyCharacterIds, equals(['cleric-1']));

        // Replica A: removes cleric-1 at HLC 20
        final repA = base.copyWith(
          partyRoster: base.partyRoster.remove(
            'cleric-1',
            const HybridLogicalClock(physicalTime: 20, logicalCounter: 0, nodeId: 'replica-a'),
          ),
        );
        expect(repA.partyCharacterIds, isEmpty);

        // Replica B: offline, still has add at HLC 10
        final repB = base;

        // Join A and B: tombstone at HLC 20 beats add at HLC 10 -> cleric-1 absent
        final joinedAB = CampaignProfile.join(repA, repB);
        expect(joinedAB.partyCharacterIds, isEmpty);

        // Later: Replica A intentionally re-adds cleric-1 at HLC 30
        final repAReadded = joinedAB.copyWith(
          partyRoster: joinedAB.partyRoster.add(
            'cleric-1',
            'cleric-1',
            const HybridLogicalClock(physicalTime: 30, logicalCounter: 0, nodeId: 'replica-a'),
          ),
        );
        expect(repAReadded.partyCharacterIds, equals(['cleric-1']));

        // Join against stale B (which only knows add at HLC 10):
        final joinedFinal = CampaignProfile.join(repAReadded, repB);
        expect(joinedFinal.partyCharacterIds, equals(['cleric-1']));

        // Join against old removal state (repA with tombstone at HLC 20):
        final joinedWithTombstone = CampaignProfile.join(repAReadded, repA);
        expect(joinedWithTombstone.partyCharacterIds, equals(['cleric-1']));
      });

      test('Three-replica roster scenario: converges under all reconnection permutations', () {
        final base = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty().add(
            'cleric-1',
            'cleric-1',
            const HybridLogicalClock(physicalTime: 10, logicalCounter: 0, nodeId: 'genesis'),
          ),
        );

        // Replica A removes cleric-1 at HLC 20
        final repA = base.copyWith(
          partyRoster: base.partyRoster.remove(
            'cleric-1',
            const HybridLogicalClock(physicalTime: 20, logicalCounter: 0, nodeId: 'replica-a'),
          ),
        );

        // Replica B remains stale (add at HLC 10)
        final repB = base;

        // Replica C saw removal (tombstone at 20) and later intentionally re-adds at HLC 30
        final repC = repA.copyWith(
          partyRoster: repA.partyRoster.add(
            'cleric-1',
            'cleric-1',
            const HybridLogicalClock(physicalTime: 30, logicalCounter: 0, nodeId: 'replica-c'),
          ),
        );

        // Permutation 1: (A + B) + C
        final ab = CampaignProfile.join(repA, repB);
        final abc = CampaignProfile.join(ab, repC);

        // Permutation 2: (C + B) + A
        final cb = CampaignProfile.join(repC, repB);
        final cba = CampaignProfile.join(cb, repA);

        // Permutation 3: (B + C) + A
        final bc = CampaignProfile.join(repB, repC);
        final bca = CampaignProfile.join(bc, repA);

        expect(abc.partyCharacterIds, equals(['cleric-1']));
        expect(cba.partyCharacterIds, equals(['cleric-1']));
        expect(bca.partyCharacterIds, equals(['cleric-1']));
        expect(abc, equals(cba));
        expect(abc, equals(bca));
      });
    });

    group('K & Y. Roster Serialization & Roundtrip', () {
      test('Full roster CRDT roundtrip preserves active elements, tombstones, and re-add history', () {
        var roster = const CrdtOrSet<String>.empty();
        roster = roster.add('cleric', 'cleric', const HybridLogicalClock(physicalTime: 10, logicalCounter: 0, nodeId: 'n1'));
        roster = roster.remove('cleric', const HybridLogicalClock(physicalTime: 20, logicalCounter: 0, nodeId: 'n1'));
        roster = roster.add('cleric', 'cleric', const HybridLogicalClock(physicalTime: 30, logicalCounter: 0, nodeId: 'n1'));
        roster = roster.add('rogue', 'rogue', const HybridLogicalClock(physicalTime: 15, logicalCounter: 0, nodeId: 'n2'));
        roster = roster.add('wizard', 'wizard', const HybridLogicalClock(physicalTime: 5, logicalCounter: 0, nodeId: 'n3'));
        roster = roster.remove('wizard', const HybridLogicalClock(physicalTime: 25, logicalCounter: 0, nodeId: 'n3'));

        final profile = createSampleProfile(partyRoster: roster);
        final dto = CampaignProfileDto.fromDomain(profile);
        final map = dto.toMap();

        expect(map.containsKey('partyRoster_crdt'), isTrue);

        final restoredDto = CampaignProfileDto.fromMap(map);
        final restored = restoredDto.toDomain();

        expect(restored, equals(profile));
        expect(restored.partyCharacterIds, equals(['cleric', 'rogue']));
        expect(restored.partyRoster.tombstones['wizard']!.physicalTime, equals(25));
        expect(restored.partyRoster.items['cleric']!.timestamp.physicalTime, equals(30));
        expect(restored.partyRoster.items['rogue']!.timestamp.physicalTime, equals(15));
        expect(CampaignProfile.join(profile, restored), equals(profile));
      });
    });

    group('T. Safe Reconciliation Parity', () {
      test('reconcileProfileSafely equals CampaignProfile.join on valid state with zero faults', () {
        final clockA = StatefulHlcClock(replicaId: ReplicaId('nodeA'), timeProvider: () => 1000);
        final clockB = StatefulHlcClock(replicaId: ReplicaId('nodeB'), timeProvider: () => 2000);

        final pA = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty().add('fighter', 'fighter', clockA.nextTimestamp()),
        );
        final pB = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty().add('wizard', 'wizard', clockB.nextTimestamp()),
        );

        final reconResult = reconciliationService.reconcileProfileSafely(local: pA, remote: pB);
        final canonicalJoined = CampaignProfile.join(pA, pB);

        expect(reconResult.fieldFaults, isEmpty);
        expect(reconResult.profile, equals(canonicalJoined));
        expect(reconResult.profile.partyCharacterIds, equals(['fighter', 'wizard']));
      });
    });

    group('F, G & V. Production Writer Audit', () {
      test('DmDashboardController.addCharacterToParty authors partyRoster add with clock timestamp', () async {
        final clock = StatefulHlcClock(
          replicaId: ReplicaId('dm-test-node'),
          timeProvider: () => 1700000000000,
        );
        final charRepo = CharacterPersistenceService();
        final campRepo = CampaignProfileService();

        final initialProfile = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty(),
        );
        await campRepo.saveProfileImmediate(initialProfile);

        final controller = DmDashboardController(
          replicaId: ReplicaId('dm-test-node'),
          clock: clock,
          campaignProfileService: campRepo,
          characterPersistenceService: charRepo,
        );
        await controller.loadData(initialCampaignId: initialProfile.id);

        const testChar = Character(
          id: EntityId(slug: 'paladin-1', ruleset: RulesetVersion.v2024),
          name: 'Sir Gareth',
          speciesRef: EntityReference.empty(slug: 'human', refType: EntityType.species, displayName: 'Human'),
          progression: CharacterProgression(classes: []),
          baseScores: AbilityScores.standardArray(),
          resources: CharacterResourcePool(currentHp: 45),
        );

        await controller.addCharacterToParty(testChar);

        final updated = controller.activeProfile!;
        expect(updated.partyCharacterIds, equals(['paladin-1']));
        expect(updated.partyRoster.activeValues, contains('paladin-1'));
        expect(updated.partyRoster.items['paladin-1']!.timestamp.nodeId, equals('dm-test-node'));
      });

      test('DmDashboardController.removeCharacterFromParty authors partyRoster remove tombstone and audit event', () async {
        final clock = StatefulHlcClock(
          replicaId: ReplicaId('dm-test-node'),
          timeProvider: () => 1700000000000,
        );
        final charRepo = CharacterPersistenceService();
        final campRepo = CampaignProfileService();

        const testChar = Character(
          id: EntityId(slug: 'paladin-1', ruleset: RulesetVersion.v2024),
          name: 'Sir Gareth',
          speciesRef: EntityReference.empty(slug: 'human', refType: EntityType.species, displayName: 'Human'),
          progression: CharacterProgression(classes: []),
          baseScores: AbilityScores.standardArray(),
          resources: CharacterResourcePool(currentHp: 45),
        );
        await charRepo.saveCharacter(testChar);

        final initialProfile = createSampleProfile(
          partyRoster: const CrdtOrSet<String>.empty().add(
            'paladin-1',
            'paladin-1',
            const HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'genesis'),
          ),
        );
        await campRepo.saveProfileImmediate(initialProfile);

        final controller = DmDashboardController(
          replicaId: ReplicaId('dm-test-node'),
          clock: clock,
          campaignProfileService: campRepo,
          characterPersistenceService: charRepo,
        );
        await controller.loadData(initialCampaignId: initialProfile.id);

        await controller.removeCharacterFromParty('paladin-1');

        final updated = controller.activeProfile!;
        expect(updated.partyCharacterIds, isEmpty);
        expect(updated.partyRoster.tombstones.containsKey('paladin-1'), isTrue);
        expect(updated.partyRoster.tombstones['paladin-1']!.nodeId, equals('dm-test-node'));
        expect(updated.changeLog.any((e) => e.type == 'characterRemove' && e.entityId == 'paladin-1'), isTrue);
      });
    });
  });
}
