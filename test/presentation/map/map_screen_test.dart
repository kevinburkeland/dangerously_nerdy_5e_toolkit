import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/screens/map/map_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_token_layer.dart';

import '../../test_doubles/delayed_emit_campaign_repository.dart';
import '../../test_doubles/fake_blob_network.dart';
import '../../test_doubles/fake_blob_store.dart';

Uint8List _makeValidJpeg() {
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
    0x00, 0x7F, 0x00, 0xFF, 0xD9,
  ]);
}

CharacterTelemetryDto _makeTelemetry({required String id, required String name}) {
  return CharacterTelemetryDto(
    id: id,
    name: name,
    speciesSlug: 'human',
    classPointers: const [],
    currentHp: 20,
    maxHp: 20,
    tempHp: 0,
    armorClass: 14,
    speed: 30,
    level: 1,
    passivePerception: 10,
    exhaustionLevel: 0,
    deathSaveSuccesses: 0,
    deathSaveFailures: 0,
    conditions: const [],
    spellSlots: const {},
    featSlugs: const [],
  );
}

void main() {
  group('MapScreenSuite (MS1 - MS3)', () {
    late FakeBlobStore store;
    late DelayedEmitCampaignRepository repo;
    late StatefulHlcClock clock;
    late MapTokenService tokenService;
    late MapGridService gridService;
    late BlobTransferService transfer;
    late ActiveMapController controller;
    late TransformationController transformController;

    late BlobRef mapRef;
    int nextId = 1;

    setUp(() async {
      store = FakeBlobStore();
      final mapBytes = _makeValidJpeg();
      mapRef = BlobRef(
        sha256Hex: sha256.convert(mapBytes).toString().toLowerCase(),
        byteSize: mapBytes.length,
        width: 1000,
        height: 800,
        format: BlobFormat.jpeg,
      );
      store.put(mapRef, mapBytes, campaignId: 'camp-1');

      clock = StatefulHlcClock(replicaId: ReplicaId('node-1'));
      repo = DelayedEmitCampaignRepository();
      tokenService = MapTokenService(
        campaignRepo: repo,
        clock: clock,
        newTokenId: () => 'tok_${(nextId++).toString().padLeft(32, '0')}',
      );
      gridService = MapGridService(
        campaignRepo: repo,
        clock: clock,
      );

      final network = FakeBlobNetwork();
      final channel = network.createChannel('me');
      transfer = BlobTransferService(
        channel: channel,
        store: store,
        servableRefs: () => activeMapServableRefs(repo),
      );

      controller = ActiveMapController(
        campaignRepo: repo,
        transfer: transfer,
        store: store,
        channel: channel,
        transportState: () => TransportState.webRtc,
      );
      transformController = TransformationController();
    });

    tearDown(() {
      controller.dispose();
      transformController.dispose();
    });

    CampaignProfile buildBaseProfile({
      required String campaignId,
      List<String> roster = const ['thorin', 'bilbo'],
      List<({MapToken token, MapTokenCell cell})> tokens = const [],
    }) {
      final t = clock.nextTimestamp();
      var rosterSet = const CrdtOrSet<String>.empty();
      for (final r in roster) {
        rosterSet = rosterSet.add(r, r, t);
      }

      var p = CampaignProfile.raw(
        id: campaignId,
        nameRegister: CrdtLwwRegister(value: 'Camp', timestamp: t),
        notesRegister: CrdtLwwRegister(value: '', timestamp: t),
        activeMapRegister: CrdtLwwRegister(value: mapRef, timestamp: t),
        mapGridRegister: CrdtLwwRegister(
          value: MapGrid(
            mapSha256Hex: mapRef.sha256Hex,
            cellCentiPx: 5000,
            offsetXCentiPx: 0,
            offsetYCentiPx: 0,
            feetPerCell: 5,
            visible: true,
          ),
          timestamp: t,
        ),
        partyRoster: rosterSet,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: const RoomNodeState.empty(),
      );

      for (final pair in tokens) {
        p = p.withTokenPlaced(pair.token, pair.cell, t);
      }
      return p;
    }

    test('MS1: characterNamesFromTelemetry trims and filters id mismatch / blank names', () {
      final telemetry = {
        'thorin': _makeTelemetry(id: 'thorin', name: '  Thorin Oakenshield  '),
        'mismatch': _makeTelemetry(id: 'different_id', name: 'Valid Name'),
        'blank': _makeTelemetry(id: 'blank', name: '   '),
        'bilbo': _makeTelemetry(id: 'bilbo', name: 'Bilbo Baggins'),
      };

      final names = characterNamesFromTelemetry(telemetry);
      expect(names, equals({
        'thorin': 'Thorin Oakenshield',
        'bilbo': 'Bilbo Baggins',
      }));
    });

    testWidgets('MS2: Player MapScreen drags own token and not others based on membership, playerName, and localCharacters', (tester) async {
      final tokThorin = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'thorin',
        label: 'T',
      );
      final tokBilbo = MapToken(
        id: 'tok_00000000000000000000000000000002',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'bilbo',
        label: 'B',
      );

      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['thorin', 'bilbo'],
        tokens: [
          (token: tokThorin, cell: MapTokenCell(col: 2, row: 2)),
          (token: tokBilbo, cell: MapTokenCell(col: 4, row: 4)),
        ],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      // 1. Player whose membershipCharacterId is 'thorin' on roster
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            canEditMap: false,
            membershipCharacterId: 'thorin',
            tokenService: tokenService,
            gridService: gridService,
            transformationController: transformController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokThorin.id}'))).movable, isTrue);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokBilbo.id}'))).movable, isFalse);

      // 2. Player whose membershipCharacterId is off-roster ('other'), but playerName matches localCharacter on roster ('  thorin ' vs 'Thorin')
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            canEditMap: false,
            membershipCharacterId: 'other',
            playerName: '  thorin ',
            localCharacters: const [(slug: 'thorin', name: 'Thorin')],
            tokenService: tokenService,
            gridService: gridService,
            transformationController: transformController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokThorin.id}'))).movable, isTrue);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokBilbo.id}'))).movable, isFalse);

      // 3. Player with playerName: 'DM' and no match on roster can drag nothing
      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            canEditMap: false,
            membershipCharacterId: null,
            playerName: 'DM',
            localCharacters: const [],
            tokenService: tokenService,
            gridService: gridService,
            transformationController: transformController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokThorin.id}'))).movable, isFalse);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokBilbo.id}'))).movable, isFalse);
    });

    testWidgets('MS3: Roster change while map is open updates token movable without reopening', (tester) async {
      final tokThorin = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'thorin',
        label: 'T',
      );

      // Thorin is NOT on the roster initially
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['bilbo'],
        tokens: [(token: tokThorin, cell: MapTokenCell(col: 2, row: 2))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: MapScreen(
            controller: controller,
            canEditMap: false,
            membershipCharacterId: 'thorin',
            tokenService: tokenService,
            gridService: gridService,
            transformationController: transformController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially not movable because 'thorin' is not on the roster
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokThorin.id}'))).movable, isFalse);

      // Add 'thorin' to roster while map is open
      final cur = repo.profiles['camp-1']!;
      repo.profiles['camp-1'] = cur.copyWith(
        partyRoster: cur.partyRoster.add('thorin', 'thorin', clock.nextTimestamp()),
      );
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      // Becomes movable without reopening
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokThorin.id}'))).movable, isTrue);
    });
  });
}
