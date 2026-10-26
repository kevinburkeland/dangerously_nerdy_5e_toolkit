import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import '../../test_doubles/hive_test_harness.dart';
import 'cold_iron_pass_11_sync_liveness_test.dart';

String _tokId(int n) => 'tok_${n.toRadixString(16).padLeft(32, '0')}';
const _dummyMapSha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

MapToken _sampleToken({
  String? id,
  String mapSha256Hex = _dummyMapSha,
  MapTokenKind kind = MapTokenKind.character,
  String refId = 'aria',
  String label = 'A',
}) {
  return MapToken(
    id: id ?? _tokId(1),
    mapSha256Hex: mapSha256Hex,
    kind: kind,
    refId: refId,
    label: label,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Map slice 1.5: Token Sync, Storage, and Durability Suite', () {
    group('TS2 (fault isolation)', () {
      final reconciler = RoomStateReconciliationService();
      const collisionStamp = HybridLogicalClock(
        physicalTime: 1700000000000,
        logicalCounter: 0,
        nodeId: 'node_local',
      );
      const newerRemoteStamp = HybridLogicalClock(
        physicalTime: 1700000001000,
        logicalCounter: 0,
        nodeId: 'node_remote',
      );

      test('divergent mapTokens at same non-zero timestamp produces exactly one fault on mapTokens, keeps local set, takes remote notes', () {
        final tokA = _sampleToken(id: _tokId(1), label: 'A');
        final tokB = _sampleToken(id: _tokId(1), label: 'B');

        final localSet = const CrdtOrSet<MapToken>.empty().add(_tokId(1), tokA, collisionStamp);
        final remoteSet = const CrdtOrSet<MapToken>.empty().add(_tokId(1), tokB, collisionStamp);

        final localProfile = CampaignProfile.raw(
          id: 'camp_fault_tokens',
          nameRegister: const CrdtLwwRegister<String>(value: 'Name', timestamp: collisionStamp),
          notesRegister: const CrdtLwwRegister<String>(value: 'Old Notes', timestamp: collisionStamp),
          mapTokens: localSet,
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        );

        final remoteProfile = CampaignProfile.raw(
          id: 'camp_fault_tokens',
          nameRegister: const CrdtLwwRegister<String>(value: 'Name', timestamp: collisionStamp),
          notesRegister: const CrdtLwwRegister<String>(value: 'New Remote Notes', timestamp: newerRemoteStamp),
          mapTokens: remoteSet,
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        );

        final result = reconciler.reconcileProfileSafely(local: localProfile, remote: remoteProfile);
        expect(result.fieldFaults.length, equals(1));
        expect(result.fieldFaults.first.field, equals('mapTokens'));
        expect(result.profile.mapTokens, equals(localSet));
        expect(result.profile.notesMarkdown, equals('New Remote Notes'));
      });

      test('divergent mapTokenCells at same non-zero timestamp produces exactly one fault on mapTokenCells, keeps local set, takes remote notes', () {
        final cellA = MapTokenCell(col: 1, row: 1);
        final cellB = MapTokenCell(col: 2, row: 2);

        final localSet = const CrdtOrSet<MapTokenCell>.empty().add(_tokId(1), cellA, collisionStamp);
        final remoteSet = const CrdtOrSet<MapTokenCell>.empty().add(_tokId(1), cellB, collisionStamp);

        final localProfile = CampaignProfile.raw(
          id: 'camp_fault_cells',
          nameRegister: const CrdtLwwRegister<String>(value: 'Name', timestamp: collisionStamp),
          notesRegister: const CrdtLwwRegister<String>(value: 'Old Notes', timestamp: collisionStamp),
          mapTokenCells: localSet,
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        );

        final remoteProfile = CampaignProfile.raw(
          id: 'camp_fault_cells',
          nameRegister: const CrdtLwwRegister<String>(value: 'Name', timestamp: collisionStamp),
          notesRegister: const CrdtLwwRegister<String>(value: 'New Remote Notes', timestamp: newerRemoteStamp),
          mapTokenCells: remoteSet,
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        );

        final result = reconciler.reconcileProfileSafely(local: localProfile, remote: remoteProfile);
        expect(result.fieldFaults.length, equals(1));
        expect(result.fieldFaults.first.field, equals('mapTokenCells'));
        expect(result.profile.mapTokenCells, equals(localSet));
        expect(result.profile.notesMarkdown, equals('New Remote Notes'));
      });

      test('divergent minionOwners at same non-zero timestamp produces exactly one fault on minionOwners, keeps local set, takes remote notes', () {
        final localSet = const CrdtOrSet<String>.empty().add('minion_1', 'aria', collisionStamp);
        final remoteSet = const CrdtOrSet<String>.empty().add('minion_1', 'bram', collisionStamp);

        final localProfile = CampaignProfile.raw(
          id: 'camp_fault_owners',
          nameRegister: const CrdtLwwRegister<String>(value: 'Name', timestamp: collisionStamp),
          notesRegister: const CrdtLwwRegister<String>(value: 'Old Notes', timestamp: collisionStamp),
          minionOwners: localSet,
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        );

        final remoteProfile = CampaignProfile.raw(
          id: 'camp_fault_owners',
          nameRegister: const CrdtLwwRegister<String>(value: 'Name', timestamp: collisionStamp),
          notesRegister: const CrdtLwwRegister<String>(value: 'New Remote Notes', timestamp: newerRemoteStamp),
          minionOwners: remoteSet,
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        );

        final result = reconciler.reconcileProfileSafely(local: localProfile, remote: remoteProfile);
        expect(result.fieldFaults.length, equals(1));
        expect(result.fieldFaults.first.field, equals('minionOwners'));
        expect(result.profile.minionOwners, equals(localSet));
        expect(result.profile.notesMarkdown, equals('New Remote Notes'));
      });
    });

    group('TS3 (storage and wire format)', () {
      test('round trip through DTO and JSON preserves empty, placed, moved, removed, and owners', () {
        const t1 = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');
        const t2 = HybridLogicalClock(physicalTime: 200, logicalCounter: 0, nodeId: 'n1');
        const t3 = HybridLogicalClock(physicalTime: 300, logicalCounter: 0, nodeId: 'n1');

        final clk = StatefulHlcClock(replicaId: ReplicaId('n1'));
        final base = createBaseProfile('ROOM_TS3', clk, 'n1');

        final tok1 = _sampleToken(id: _tokId(1), label: 'A');
        final tok2 = _sampleToken(id: _tokId(2), kind: MapTokenKind.minion, refId: 'm1', label: 'M1');
        final cell1 = MapTokenCell(col: 3, row: 4);
        final cell2 = MapTokenCell(col: 10, row: 12);
        final cell1Moved = MapTokenCell(col: 5, row: 6);

        final placed = base
            .withTokenPlaced(tok1, cell1, t1)
            .withTokenPlaced(tok2, cell2, t1)
            .withMinionOwner('m1', 'aria', t1);

        final movedAndRemoved = placed
            .withTokenMoved(_tokId(1), cell1Moved, t2)
            .withTokenRemoved(_tokId(2), t2)
            .withMinionOwner('m1', null, t3);

        final cases = <CampaignProfile>[
          base,
          placed,
          movedAndRemoved,
        ];

        for (final profile in cases) {
          final dto = CampaignProfileDto.fromDomain(profile);
          final map = dto.toMap();
          final jsonStr = json.encode(map);
          final decodedMap = json.decode(jsonStr) as Map<String, dynamic>;
          final parsedDto = CampaignProfileDto.fromMap(decodedMap);
          final roundTripped = parsedDto.toDomain();

          expect(roundTripped, equals(profile));
          expect(roundTripped.mapTokens, equals(profile.mapTokens));
          expect(roundTripped.mapTokenCells, equals(profile.mapTokenCells));
          expect(roundTripped.minionOwners, equals(profile.minionOwners));
        }
      });

      test('format 2be5406 writes without token keys loads empty and keeps grid and map', () {
        final legacyMap = <String, dynamic>{
          'id': 'legacy_camp_2be5406',
          'name': 'Legacy 2be5406 Campaign',
          'notes': 'Legacy Notes',
          'nameRegister': {
            'v': 'Legacy 2be5406 Campaign',
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'notesRegister': {
            'v': 'Legacy Notes',
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'activeMapRegister': {
            'v': {
              'sha256Hex': 'a' * 64,
              'byteSize': 1024,
              'width': 800,
              'height': 600,
              'format': 'webp',
            },
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'mapGridRegister': {
            'v': {
              'mapSha256Hex': 'a' * 64,
              'cellCentiPx': 5000,
              'offsetXCentiPx': 0,
              'offsetYCentiPx': 0,
              'feetPerCell': 5,
              'visible': true,
            },
            'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
          },
          'nodeId': 'n1',
          'recordVersion': 1,
        };

        final dto = CampaignProfileDto.fromMap(legacyMap);
        final profile = dto.toDomain();
        expect(profile.mapTokens.items, isEmpty);
        expect(profile.mapTokenCells.items, isEmpty);
        expect(profile.minionOwners.items, isEmpty);
        expect(profile.activeMap, isNotNull);
        expect(profile.activeMap!.sha256Hex, equals('a' * 64));
        expect(profile.mapGrid, isNotNull);
        expect(profile.mapGrid!.cellCentiPx, equals(5000));
      });

      test('fromMap throws FormatException on invalid token keys, values, and MT1 violations', () {
        Map<String, dynamic> makeBase() => {
          'id': 'bad_camp',
          'recordVersion': 1,
        };

        // 1. String instead of map for each key
        expect(() => CampaignProfileDto.fromMap(makeBase()..['mapTokens_crdt'] = 'not a map'), throwsA(isA<FormatException>()));
        expect(() => CampaignProfileDto.fromMap(makeBase()..['mapTokenCells_crdt'] = 'not a map'), throwsA(isA<FormatException>()));
        expect(() => CampaignProfileDto.fromMap(makeBase()..['minionOwners_crdt'] = 'not a map'), throwsA(isA<FormatException>()));

        // 2. Token value is a string
        expect(() => CampaignProfileDto.fromMap(makeBase()..['mapTokens_crdt'] = {
          'items': {
            _tokId(1): {
              'v': 'a string',
              'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
            }
          }
        }), throwsA(isA<FormatException>()));

        // 3. Token whose key differs from its id
        expect(() => CampaignProfileDto.fromMap(makeBase()..['mapTokens_crdt'] = {
          'items': {
            _tokId(1): {
              'v': _sampleToken(id: _tokId(2)).toMap(),
              'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
            }
          }
        }), throwsA(isA<FormatException>()));

        // 4. Empty owner slug
        expect(() => CampaignProfileDto.fromMap(makeBase()..['minionOwners_crdt'] = {
          'items': {
            'm1': {
              'v': '',
              'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
            }
          }
        }), throwsA(isA<FormatException>()));

        // 5. Owner is a number
        expect(() => CampaignProfileDto.fromMap(makeBase()..['minionOwners_crdt'] = {
          'items': {
            'm1': {
              'v': 123,
              'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
            }
          }
        }), throwsA(isA<FormatException>()));

        // Helper to test a bad token value
        void expectBadToken(Map<String, dynamic> tokenMap) {
          final id = tokenMap['id'] is String ? tokenMap['id'] as String : _tokId(1);
          expect(() => CampaignProfileDto.fromMap(makeBase()..['mapTokens_crdt'] = {
            'items': {
              id: {
                'v': tokenMap,
                'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
              }
            }
          }), throwsA(isA<FormatException>()));
        }

        // Helper to test a bad cell value
        void expectBadCell(Map<String, dynamic> cellMap) {
          expect(() => CampaignProfileDto.fromMap(makeBase()..['mapTokenCells_crdt'] = {
            'items': {
              _tokId(1): {
                'v': cellMap,
                'ts': {'pt': 100, 'lc': 0, 'node': 'n1'},
              }
            }
          }), throwsA(isA<FormatException>()));
        }

        // MT1 token rejections:
        // - id with 31 or 33 hex digits, upper-case hex, or without tok_
        expectBadToken({'id': 'tok_${'a' * 31}', 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'A'});
        expectBadToken({'id': 'tok_${'a' * 33}', 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'A'});
        expectBadToken({'id': 'tok_${'A' * 32}', 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'A'});
        expectBadToken({'id': 'abc_${'a' * 32}', 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'A'});

        // - hash failure
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': 'a' * 63, 'kind': 'character', 'refId': 'a', 'label': 'A'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': '${'a' * 63}A', 'kind': 'character', 'refId': 'a', 'label': 'A'});

        // - refId empty, 129 code units, \n, \u007F
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': '', 'label': 'A'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a' * 129, 'label': 'A'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a\nb', 'label': 'A'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a\u007Fb', 'label': 'A'});

        // - label empty, ab, ABCD, A B, É, -
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': ''});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'ab'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'ABCD'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'A B'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'É'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': '-'});

        // - fromMap alone rejects: missing key, extra key, kind: "npc", kind: 0
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a'}); // missing label
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'character', 'refId': 'a', 'label': 'A', 'extra': 1});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 'npc', 'refId': 'a', 'label': 'A'});
        expectBadToken({'id': _tokId(1), 'mapSha256Hex': _dummyMapSha, 'kind': 0, 'refId': 'a', 'label': 'A'});

        // MT1 cell rejections:
        // - col/row -2 or 4096
        expectBadCell({'col': -2, 'row': 0});
        expectBadCell({'col': 0, 'row': -2});
        expectBadCell({'col': 4096, 'row': 0});
        expectBadCell({'col': 0, 'row': 4096});

        // - missing key, extra key, col: "3", col: null
        expectBadCell({'col': 0}); // missing row
        expectBadCell({'col': 0, 'row': 0, 'extra': 1});
        expectBadCell({'col': '3', 'row': 0});
        expectBadCell({'col': null, 'row': 0});
      });

      test('RoomSyncPayloadMapper preserves tokens, cells, and minionOwners with recordVersion == 1', () {
        const t = HybridLogicalClock(physicalTime: 1000, logicalCounter: 0, nodeId: 'node_dm');
        final tok = _sampleToken(id: _tokId(1));
        final cell = MapTokenCell(col: 2, row: 3);

        final profile = CampaignProfile.raw(
          id: 'camp_sync_tokens',
          nameRegister: const CrdtLwwRegister<String>(value: 'Room', timestamp: t),
          notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: t),
          createdAt: DateTime.utc(2026, 1, 1),
          lastPlayedAt: DateTime.utc(2026, 1, 1),
          roomState: const RoomNodeState.empty(),
        ).withTokenPlaced(tok, cell, t).withMinionOwner('minion_1', 'aria', t);

        const mapper = RoomSyncPayloadMapper();
        final serialized = mapper.serializeFullProfileSync(
          profile: profile,
          originNodeId: 'node_dm',
          originSeq: 1,
          timestamp: 1000,
        );

        final decoded = json.decode(serialized) as Map<String, dynamic>;
        final campaignPayload = decoded['payload'] as Map<String, dynamic>;
        expect(campaignPayload['recordVersion'], equals(1));

        final msg = mapper.parsePayload(serialized);
        expect(msg, isA<FullProfileSyncMessage>());
        final parsed = (msg as FullProfileSyncMessage).profile;
        expect(parsed.mapTokens, equals(profile.mapTokens));
        expect(parsed.mapTokenCells, equals(profile.mapTokenCells));
        expect(parsed.minionOwners, equals(profile.minionOwners));
      });
    });

    group('TS4 (backup)', () {
      final harness = HiveTestHarness();
      late StatefulHlcClock clock;
      late DmBackupService dmBackupService;
      late CampaignProfileService campaignService;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await harness.setUpInMemory();
        await initServiceLocator();
        clock = sl<StatefulHlcClock>();
        campaignService = CampaignProfileService();
        campaignService.clearCacheForTesting();
        dmBackupService = DmBackupService(clock: clock);
      });

      tearDown(() async {
        sl.reset();
        await harness.tearDown();
      });

      test('exportProfileJson then validateAndImportProfile keeps tokens, cells, and owners', () async {
        final t = clock.nextTimestamp();
        final tok = _sampleToken(id: _tokId(1));
        final cell = MapTokenCell(col: 5, row: 7);
        final base = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Original Token Campaign',
        ).withTokenPlaced(tok, cell, t).withMinionOwner('minion_1', 'aria', t);

        final jsonExport = dmBackupService.exportProfileJson(base);
        final imported = await dmBackupService.validateAndImportProfile(jsonExport);

        expect(imported, isNotNull);
        expect(imported!.id, isNot(equals(base.id)));
        expect(imported.mapTokens, equals(base.mapTokens));
        expect(imported.mapTokenCells, equals(base.mapTokenCells));
        expect(imported.minionOwners, equals(base.minionOwners));
      });

      test('full system snapshot export and restore keeps tokens, cells, and owners', () async {
        final t = clock.nextTimestamp();
        final tok1 = _sampleToken(id: _tokId(1));
        final cell1 = MapTokenCell(col: 2, row: 3);
        final tok2 = _sampleToken(id: _tokId(2), kind: MapTokenKind.minion, refId: 'm2', label: 'M2');
        final cell2 = MapTokenCell(col: 4, row: 5);

        final camp1 = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Camp 1 Tokens',
        ).copyWith(id: 'c1').withTokenPlaced(tok1, cell1, t).withMinionOwner('m1', 'slug1', t);

        final camp2 = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Camp 2 Tokens',
        ).copyWith(id: 'c2').withTokenPlaced(tok2, cell2, t).withMinionOwner('m2', 'slug2', t);

        await campaignService.saveProfileImmediate(camp1);
        await campaignService.saveProfileImmediate(camp2);

        final snapshotJson = await dmBackupService.exportFullSystemSnapshot();

        // Overwrite locally to verify restore brings them back
        final tRemove = clock.nextTimestamp();
        await campaignService.saveProfileImmediate(camp1.withTokenRemoved(tok1.id, tRemove));
        await campaignService.saveProfileImmediate(camp2.withTokenRemoved(tok2.id, tRemove));
        expect((await campaignService.getProfile('c1'))!.mapTokens.items, isEmpty);

        final restored = await dmBackupService.restoreFullSystemSnapshot(snapshotJson);
        expect(restored, isTrue);

        final loaded = await campaignService.loadAllProfiles();
        final loadedC1 = loaded.firstWhere((p) => p.id == 'c1');
        final loadedC2 = loaded.firstWhere((p) => p.id == 'c2');

        expect(loadedC1.mapTokens, equals(camp1.mapTokens));
        expect(loadedC1.mapTokenCells, equals(camp1.mapTokenCells));
        expect(loadedC1.minionOwners, equals(camp1.minionOwners));
        expect(loadedC2.mapTokens, equals(camp2.mapTokens));
        expect(loadedC2.mapTokenCells, equals(camp2.mapTokenCells));
        expect(loadedC2.minionOwners, equals(camp2.minionOwners));
      });

      test('future timestamp (+10 years) in each field is refused and futureTimestampViolations names the field', () async {
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final tenYearsMs = nowMs + const Duration(days: 3650).inMilliseconds;
        final farFutureStamp = HybridLogicalClock(
          physicalTime: tenYearsMs,
          logicalCounter: 0,
          nodeId: 'future_node',
        );

        final base = CampaignProfile.defaultProfile(
          nodeId: clock.replicaId.value,
          clock: clock,
          name: 'Future Token Campaign',
        );

        // 1. Future mapTokens
        final tokFuture = base.copyWith(
          mapTokens: const CrdtOrSet<MapToken>.empty().add(_tokId(1), _sampleToken(id: _tokId(1)), farFutureStamp),
        );
        expect(futureTimestampViolations(tokFuture, nowMs, const Duration(minutes: 5)), contains('mapTokens'));
        expect(await dmBackupService.validateAndImportProfile(dmBackupService.exportProfileJson(tokFuture)), isNull);

        // 2. Future mapTokenCells
        final cellFuture = base.copyWith(
          mapTokenCells: const CrdtOrSet<MapTokenCell>.empty().add(_tokId(1), MapTokenCell(col: 0, row: 0), farFutureStamp),
        );
        expect(futureTimestampViolations(cellFuture, nowMs, const Duration(minutes: 5)), contains('mapTokenCells'));
        expect(await dmBackupService.validateAndImportProfile(dmBackupService.exportProfileJson(cellFuture)), isNull);

        // 3. Future minionOwners
        final ownerFuture = base.copyWith(
          minionOwners: const CrdtOrSet<String>.empty().add('m1', 'aria', farFutureStamp),
        );
        expect(futureTimestampViolations(ownerFuture, nowMs, const Duration(minutes: 5)), contains('minionOwners'));
        expect(await dmBackupService.validateAndImportProfile(dmBackupService.exportProfileJson(ownerFuture)), isNull);
      });
    });

    test('TS5 (late joiner): detached player attaches, converges tokens within two anti-entropy intervals; DM moves and removes, player follows', () async {
      final bus = TestP2pBus(seed: 77);
      const shortTick = Duration(milliseconds: 10);
      const fastAntiEntropy = Duration(milliseconds: 30);

      final dm = DeviceHarness.create(
        nodeId: 'dm',
        bus: bus,
        roomCode: 'TOKEN_ROOM',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastAntiEntropy,
        isHost: true,
      );

      final base = createBaseProfile('TOKEN_ROOM', dm.clock, 'dm');
      final mapRef = BlobRef(
        sha256Hex: _dummyMapSha,
        byteSize: 1024,
        width: 800,
        height: 600,
        format: BlobFormat.webp,
      );
      final grid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );

      final tok1 = _sampleToken(id: _tokId(1), label: 'T1');
      final tok2 = _sampleToken(id: _tokId(2), kind: MapTokenKind.minion, refId: 'm1', label: 'M1');
      final cell1 = MapTokenCell(col: 2, row: 3);
      final cell2 = MapTokenCell(col: 5, row: 6);

      final dmStamp = dm.clock.nextTimestamp();
      final dmInitial = base
          .withActiveMap(mapRef, dmStamp)
          .withMapGrid(grid, dmStamp)
          .withTokenPlaced(tok1, cell1, dmStamp)
          .withTokenPlaced(tok2, cell2, dmStamp)
          .withMinionOwner('m1', 'aria', dmStamp);

      await dm.repo.putProfile(dmInitial);
      dm.orchestrator.startSynchronization();

      // Player is detached initially
      final player = DeviceHarness.create(
        nodeId: 'player',
        bus: bus,
        roomCode: 'TOKEN_ROOM',
        telemetryInterval: shortTick,
        antiEntropyInterval: fastAntiEntropy,
      );
      player.node.isAttached = false;
      await player.repo.putProfile(base);
      player.orchestrator.startSynchronization();

      expect(player.repo.activeProfile!.mapTokens.items, isEmpty);

      // Player attaches
      player.node.isAttached = true;

      // Within two antiEntropyIntervals (2 * 30ms = 60ms + buffer), player's fields equal DM's
      await Future<void>.delayed(fastAntiEntropy * 2 + const Duration(milliseconds: 20));

      expect(player.repo.activeProfile!.mapTokens, equals(dm.repo.activeProfile!.mapTokens));
      expect(player.repo.activeProfile!.mapTokenCells, equals(dm.repo.activeProfile!.mapTokenCells));
      expect(player.repo.activeProfile!.minionOwners, equals(dm.repo.activeProfile!.minionOwners));

      // DM moves one token (tok1) and removes the other (tok2)
      final moveStamp = dm.clock.nextTimestamp();
      final removeStamp = dm.clock.nextTimestamp();
      final cell1Moved = MapTokenCell(col: 7, row: 8);

      await dm.repo.updateProfile(base.id, (c) => c
          .withTokenMoved(tok1.id, cell1Moved, moveStamp)
          .withTokenRemoved(tok2.id, removeStamp));

      // Within two antiEntropyIntervals, player follows
      await Future<void>.delayed(fastAntiEntropy * 2 + const Duration(milliseconds: 20));

      expect(player.repo.activeProfile!.mapTokens, equals(dm.repo.activeProfile!.mapTokens));
      expect(player.repo.activeProfile!.mapTokenCells, equals(dm.repo.activeProfile!.mapTokenCells));
      expect(player.repo.activeProfile!.minionOwners, equals(dm.repo.activeProfile!.minionOwners));

      // tok1 is active with cell1Moved, tok2 is removed
      final playerTokens = player.repo.activeProfile!.tokensOnMap(_dummyMapSha);
      expect(playerTokens.length, equals(1));
      expect(playerTokens.first.token.id, equals(tok1.id));
      expect(playerTokens.first.cell, equals(cell1Moved));

      dm.dispose();
      player.dispose();
    });
  });
}
