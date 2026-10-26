import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/grid_geometry.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_token_layer.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_token_panel.dart';
import 'package:dangerously_nerdy_5e_toolkit/presentation/widgets/map/map_view.dart';

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

Offset _sceneToScreen(WidgetTester tester, TransformationController tc, Offset scene) {
  final ivBox = tester.renderObject(find.byType(InteractiveViewer)) as RenderBox;
  final ivTopLeft = ivBox.localToGlobal(Offset.zero);
  final local = MatrixUtils.transformPoint(tc.value, scene);
  return ivTopLeft + local;
}

Offset _tokenCenter(WidgetTester tester, String tokenId) {
  final box = tester.renderObject(find.byKey(ValueKey('map-token-$tokenId'))) as RenderBox;
  return box.localToGlobal(box.size.center(Offset.zero));
}

void main() {
  group('MapTokenViewSuite (TV1 - TV11)', () {
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
      bool withGrid = true,
      bool gridVisible = true,
      List<String> roster = const ['hero'],
      Map<String, String> combatants = const {},
      List<MinionInstance> minions = const [],
      List<({MapToken token, MapTokenCell cell})> tokens = const [],
      Map<String, String> minionOwners = const {},
    }) {
      final t = clock.nextTimestamp();
      var rosterSet = const CrdtOrSet<String>.empty();
      for (final r in roster) {
        rosterSet = rosterSet.add(r, r, t);
      }

      var encounterSet = const CrdtOrSet<EncounterParticipant>.empty();
      for (final entry in combatants.entries) {
        final part = EncounterParticipant(
          participantId: entry.key,
          entityLink: RoomEntityLink(
            entityId: entry.key,
            displayName: entry.value,
          ),
        );
        encounterSet = encounterSet.add(entry.key, part, t);
      }

      var minionSet = const CrdtOrSet<dynamic>.empty();
      for (final m in minions) {
        minionSet = minionSet.add(m.id, m, t);
      }

      var p = CampaignProfile.raw(
        id: campaignId,
        nameRegister: CrdtLwwRegister(value: 'Camp', timestamp: t),
        notesRegister: CrdtLwwRegister(value: '', timestamp: t),
        activeMapRegister: CrdtLwwRegister(value: mapRef, timestamp: t),
        mapGridRegister: withGrid
            ? CrdtLwwRegister(
                value: MapGrid(
                  mapSha256Hex: mapRef.sha256Hex,
                  cellCentiPx: 5000,
                  offsetXCentiPx: 0,
                  offsetYCentiPx: 0,
                  feetPerCell: 5,
                  visible: gridVisible,
                ),
                timestamp: t,
              )
            : const CrdtLwwRegister(value: null, timestamp: HybridLogicalClock(physicalTime: 0, logicalCounter: 0, nodeId: 'n1')),
        partyRoster: rosterSet,
        createdAt: DateTime.utc(2026),
        lastPlayedAt: DateTime.utc(2026),
        roomState: const RoomNodeState.empty().copyWith(
          activeEncounter: encounterSet,
          activeMinions: minionSet,
        ),
      );

      for (final pair in tokens) {
        p = p.withTokenPlaced(pair.token, pair.cell, t);
      }
      for (final entry in minionOwners.entries) {
        p = p.withMinionOwner(entry.key, entry.value, t);
      }
      return p;
    }

    testWidgets('TV1: Drawing 3 tokens, centers within 0.5px, glyph, hidden grid draws, no grid draws none, off-image faded', (tester) async {
      final tokChar = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      final tokMonster = MapToken(
        id: 'tok_00000000000000000000000000000002',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.monster,
        refId: 'part-1',
        label: 'M',
      );
      final tokMinion = MapToken(
        id: 'tok_00000000000000000000000000000003',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.minion,
        refId: 'minion-1',
        label: 'G',
      );
      final tokOffMap = MapToken(
        id: 'tok_00000000000000000000000000000004',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero-2',
        label: 'O',
      );

      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Goblin',
        size: EntitySize.small,
        currentHp: 10,
        maxHp: 10,
      );

      final grid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );

      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        withGrid: true,
        roster: ['hero', 'hero-2'],
        combatants: {'part-1': 'Monster'},
        minions: [minion],
        tokens: [
          (token: tokChar, cell: MapTokenCell(col: 2, row: 3)),
          (token: tokMonster, cell: MapTokenCell(col: 5, row: 5)),
          (token: tokMinion, cell: MapTokenCell(col: 8, row: 8)),
          (token: tokOffMap, cell: MapTokenCell(col: 25, row: 20)),
        ],
      );

      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check existence and centers
      for (final (tok, col, row) in [
        (tokChar, 2, 3),
        (tokMonster, 5, 5),
        (tokMinion, 8, 8),
      ]) {
        expect(find.byKey(ValueKey('map-token-${tok.id}')), findsOneWidget);
        final expectedScene = cellCenter(grid, col, row);
        final expectedScreen = _sceneToScreen(tester, transformController, Offset(expectedScene.x, expectedScene.y));
        final actualScreen = _tokenCenter(tester, tok.id);
        expect((actualScreen - expectedScreen).distance, lessThanOrEqualTo(0.5));
      }

      // Glyph checks
      final minionWidget = tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMinion.id}')));
      expect(minionWidget.showsGlyph, isTrue);

      final charWidget = tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokChar.id}')));
      expect(charWidget.showsGlyph, isFalse);

      final monsterWidget = tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMonster.id}')));
      expect(monsterWidget.showsGlyph, isFalse);

      // Off-image token drawn on nearest square (col 19, row 15) and faded
      final offMapWidget = tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokOffMap.id}')));
      expect(offMapWidget.faded, isTrue);
      final expectedOffMapScene = cellCenter(grid, 19, 15);
      final expectedOffMapScreen = _sceneToScreen(tester, transformController, Offset(expectedOffMapScene.x, expectedOffMapScene.y));
      expect((_tokenCenter(tester, tokOffMap.id) - expectedOffMapScreen).distance, lessThanOrEqualTo(0.5));

      // With grid hidden, tokens are still drawn
      repo.profiles['camp-1'] = profile.copyWith(
        mapGridRegister: CrdtLwwRegister(
          value: MapGrid(
            mapSha256Hex: grid.mapSha256Hex,
            cellCentiPx: grid.cellCentiPx,
            offsetXCentiPx: grid.offsetXCentiPx,
            offsetYCentiPx: grid.offsetYCentiPx,
            feetPerCell: grid.feetPerCell,
            visible: false,
          ),
          timestamp: clock.nextTimestamp(),
        ),
      );
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('map-token-${tokChar.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('map-token-${tokMonster.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('map-token-${tokMinion.id}')), findsOneWidget);

      // With no grid, no tokens drawn
      repo.profiles['camp-1'] = profile.copyWith(
        mapGridRegister: CrdtLwwRegister(value: null, timestamp: clock.nextTimestamp()),
      );
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('map-token-${tokChar.id}')), findsNothing);
      expect(find.byKey(ValueKey('map-token-${tokMonster.id}')), findsNothing);
      expect(find.byKey(ValueKey('map-token-${tokMinion.id}')), findsNothing);
    });

    testWidgets('TV2: Tokens follow the grid in-flight edits before write is sent', (tester) async {
      final tokChar = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        tokens: [(token: tokChar, cell: MapTokenCell(col: 2, row: 3))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Press "Increase size"
      final incBtn = find.byTooltip('Increase size');
      expect(incBtn, findsOneWidget);
      await tester.tap(incBtn);
      await tester.pump(); // Just pump frame without letting write finish

      // Grid cell size in editor is now 50.5 px (5050 centiPx)
      final newGrid = MapGrid(
        mapSha256Hex: mapRef.sha256Hex,
        cellCentiPx: 5050,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
      final expectedScene = cellCenter(newGrid, 2, 3);
      final expectedScreen = _sceneToScreen(tester, transformController, Offset(expectedScene.x, expectedScene.y));
      final actualScreen = _tokenCenter(tester, tokChar.id);
      expect((actualScreen - expectedScreen).distance, lessThanOrEqualTo(0.5));

      await tester.pumpAndSettle();
    });

    testWidgets('TV3: Highlight rules: DM movable all; player movable own char + owned minion; dynamic owner change', (tester) async {
      final tokChar = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      final tokMonster = MapToken(
        id: 'tok_00000000000000000000000000000002',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.monster,
        refId: 'part-1',
        label: 'M',
      );
      final tokMinion = MapToken(
        id: 'tok_00000000000000000000000000000003',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.minion,
        refId: 'minion-1',
        label: 'G',
      );

      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Goblin',
        size: EntitySize.small,
        currentHp: 10,
        maxHp: 10,
      );

      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        combatants: {'part-1': 'Monster'},
        minions: [minion],
        tokens: [
          (token: tokChar, cell: MapTokenCell(col: 2, row: 3)),
          (token: tokMonster, cell: MapTokenCell(col: 5, row: 5)),
          (token: tokMinion, cell: MapTokenCell(col: 8, row: 8)),
        ],
        minionOwners: {'minion-1': 'hero'},
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      // 1. DM view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapView(
              controller: controller,
              canEditMap: true,
              tokenService: tokenService,
              gridService: gridService,
              transformationController: transformController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokChar.id}'))).movable, isTrue);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMonster.id}'))).movable, isTrue);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMinion.id}'))).movable, isTrue);

      // 2. Player view (hero on roster)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapView(
              controller: controller,
              canEditMap: false,
              membershipCharacterId: 'hero',
              tokenService: tokenService,
              gridService: gridService,
              transformationController: transformController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokChar.id}'))).movable, isTrue);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMinion.id}'))).movable, isTrue);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMonster.id}'))).movable, isFalse);

      // 3. Player not on roster
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapView(
              controller: controller,
              canEditMap: false,
              membershipCharacterId: 'stranger',
              tokenService: tokenService,
              gridService: gridService,
              transformationController: transformController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokChar.id}'))).movable, isFalse);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMinion.id}'))).movable, isFalse);
      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMonster.id}'))).movable, isFalse);

      // 4. Reopen as player whose minion was initially unowned, then DM assigns it
      repo.profiles['camp-1'] = profile.withMinionOwner('minion-1', null, clock.nextTimestamp());
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapView(
              controller: controller,
              canEditMap: false,
              membershipCharacterId: 'hero',
              tokenService: tokenService,
              gridService: gridService,
              transformationController: transformController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMinion.id}'))).movable, isFalse);

      // DM sets minion owner to 'hero'
      repo.profiles['camp-1'] = repo.profiles['camp-1']!.withMinionOwner('minion-1', 'hero', clock.nextTimestamp());
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      expect(tester.widget<MapTokenWidget>(find.byKey(ValueKey('map-token-${tokMinion.id}'))).movable, isTrue);
    });

    testWidgets('TV4: Drag moves token, distance label shows, no pan, matrix unchanged', (tester) async {
      final tokChar = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        tokens: [(token: tokChar, cell: MapTokenCell(col: 2, row: 3))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = profile.mapGrid!;
      final startScene = cellCenter(grid, 2, 3);
      final destScene = cellCenter(grid, 7, 5);

      final startScreen = _sceneToScreen(tester, transformController, Offset(startScene.x, startScene.y));
      final destScreen = _sceneToScreen(tester, transformController, Offset(destScene.x, destScene.y));
      final initialMatrix = transformController.value.clone();

      final gesture = await tester.startGesture(startScreen);
      await tester.pump();

      // Move in several steps
      await gesture.moveTo(startScreen + const Offset(50, 20));
      await tester.pump();
      await gesture.moveTo(destScreen);
      await tester.pump();

      // Distance label reads "5 squares · 25 ft"
      expect(find.text('5 squares · 25 ft'), findsOneWidget);

      // Release
      await gesture.up();
      await tester.pumpAndSettle();

      // Check stored cell
      final updated = repo.profiles['camp-1']!;
      expect(updated.tokenCell(tokChar.id), equals(MapTokenCell(col: 7, row: 5)));

      // Token drawn at (7, 5)
      final expectedScreen = _sceneToScreen(tester, transformController, Offset(destScene.x, destScene.y));
      expect((_tokenCenter(tester, tokChar.id) - expectedScreen).distance, lessThanOrEqualTo(0.5));

      // Transformation matrix is identical
      expect(transformController.value, equals(initialMatrix));
    });

    testWidgets('TV5: Drag unmovable token or empty map pans, matrix changes', (tester) async {
      final tokMonster = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.monster,
        refId: 'p1',
        label: 'M',
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        combatants: {'p1': 'Monster'},
        tokens: [(token: tokMonster, cell: MapTokenCell(col: 5, row: 5))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: false, // Player cannot move monster token
                membershipCharacterId: 'hero',
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = profile.mapGrid!;
      final monsterScene = cellCenter(grid, 5, 5);
      final monsterScreen = _sceneToScreen(tester, transformController, Offset(monsterScene.x, monsterScene.y));
      final initialMatrix = transformController.value.clone();

      // Drag on combatant token
      final gesture = await tester.startGesture(monsterScreen);
      await tester.pump();
      await gesture.moveBy(const Offset(100, 100));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Nothing written
      expect(repo.profiles['camp-1']!.tokenCell(tokMonster.id), equals(MapTokenCell(col: 5, row: 5)));
      // Matrix translation changed!
      expect(transformController.value, isNot(equals(initialMatrix)));
    });

    testWidgets('TV6: Second finger cancels token drag, no write, scale changed', (tester) async {
      final tokChar = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        tokens: [(token: tokChar, cell: MapTokenCell(col: 2, row: 3))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = profile.mapGrid!;
      final startScene = cellCenter(grid, 2, 3);
      final startScreen = _sceneToScreen(tester, transformController, Offset(startScene.x, startScene.y));
      final initialScale = transformController.value.getMaxScaleOnAxis();

      // Start drag with finger 1
      final g1 = await tester.startGesture(startScreen);
      await tester.pump();
      await g1.moveBy(const Offset(30, 30));
      await tester.pump();

      // Finger 2 lands and spreads
      final g2 = await tester.startGesture(startScreen + const Offset(100, 100));
      await tester.pump();
      await g2.moveBy(const Offset(150, 150));
      await tester.pump();

      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();

      // No write, stored cell unchanged
      expect(repo.profiles['camp-1']!.tokenCell(tokChar.id), equals(MapTokenCell(col: 2, row: 3)));
      // Scale changed
      expect(transformController.value.getMaxScaleOnAxis(), isNot(equals(initialScale)));
    });

    testWidgets('TV7: Drop past right edge clamps to column 19, no message shown', (tester) async {
      final tokChar = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        tokens: [(token: tokChar, cell: MapTokenCell(col: 2, row: 3))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = profile.mapGrid!;
      final startScene = cellCenter(grid, 2, 3);
      final startScreen = _sceneToScreen(tester, transformController, Offset(startScene.x, startScene.y));
      final pastEdgeScreen = _sceneToScreen(tester, transformController, const Offset(1400, 175));

      final gesture = await tester.startGesture(startScreen);
      await tester.pump();
      await gesture.moveTo(pastEdgeScreen);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Stored cell column is 19
      final updated = repo.profiles['camp-1']!;
      expect(updated.tokenCell(tokChar.id)!.col, equals(19));
      expect(find.text("Tokens must stay on the map."), findsNothing);
    });

    testWidgets('TV8: Refused move reverts, shows message, cleared on next token action', (tester) async {
      final tokMinion = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.minion,
        refId: 'minion-1',
        label: 'G',
      );
      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Goblin',
        size: EntitySize.small,
        currentHp: 10,
        maxHp: 10,
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        minions: [minion],
        tokens: [(token: tokMinion, cell: MapTokenCell(col: 2, row: 2))],
        minionOwners: {'minion-1': 'hero'},
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: false,
                membershipCharacterId: 'hero',
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Queued change clears minion owner just before transform runs
      repo.onBeforeTransform = (current) {
        repo.profiles[current.id] = current.withMinionOwner('minion-1', null, clock.nextTimestamp());
      };

      final grid = profile.mapGrid!;
      final startScene = cellCenter(grid, 2, 2);
      final destScene = cellCenter(grid, 4, 4);
      final startScreen = _sceneToScreen(tester, transformController, Offset(startScene.x, startScene.y));
      final destScreen = _sceneToScreen(tester, transformController, Offset(destScene.x, destScene.y));

      final gesture = await tester.startGesture(startScreen);
      await tester.pump();
      await gesture.moveTo(destScreen);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Token reverted
      expect(repo.profiles['camp-1']!.tokenCell(tokMinion.id), equals(MapTokenCell(col: 2, row: 2)));
      expect(find.text("You can't move that token."), findsOneWidget);

      // Next action clears it (e.g. tap on map)
      final clearScene = cellCenter(grid, 10, 10);
      final g2 = await tester.startGesture(_sceneToScreen(tester, transformController, Offset(clearScene.x, clearScene.y)));
      await g2.up();
      await tester.pumpAndSettle();

      expect(find.text("You can't move that token."), findsNothing);
    });

    testWidgets('TV9: Slow storage shows new square at every 20ms step until emit and after', (tester) async {
      final tokChar = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        tokens: [(token: tokChar, cell: MapTokenCell(col: 2, row: 3))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      repo.futureDelay = const Duration(milliseconds: 10);
      repo.emitDelay = const Duration(milliseconds: 200);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = profile.mapGrid!;
      final startScene = cellCenter(grid, 2, 3);
      final destScene = cellCenter(grid, 5, 5);
      final startScreen = _sceneToScreen(tester, transformController, Offset(startScene.x, startScene.y));
      final destScreen = _sceneToScreen(tester, transformController, Offset(destScene.x, destScene.y));

      final gesture = await tester.startGesture(startScreen);
      await tester.pump();
      await gesture.moveTo(destScreen);
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Check at every 20ms step
      final expectedScreen = _sceneToScreen(tester, transformController, Offset(destScene.x, destScene.y));
      for (int step = 0; step < 12; step++) {
        await tester.pump(const Duration(milliseconds: 20));
        final actual = _tokenCenter(tester, tokChar.id);
        expect((actual - expectedScreen).distance, lessThanOrEqualTo(0.5));
      }

      await tester.pumpAndSettle();
      expect((_tokenCenter(tester, tokChar.id) - expectedScreen).distance, lessThanOrEqualTo(0.5));
    });

    testWidgets('TV10: Tap selects token, panel shows, clears on empty map tap, sync removal clears, on-top selection, Measure does not move token', (tester) async {
      final tokChar1 = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H1',
      );
      final tokChar2 = MapToken(
        id: 'tok_00000000000000000000000000000002',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero-2',
        label: 'H2',
      );

      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero', 'hero-2'],
        tokens: [
          (token: tokChar1, cell: MapTokenCell(col: 2, row: 2)),
          (token: tokChar2, cell: MapTokenCell(col: 2, row: 2)), // sharing square!
        ],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      PlacedMapToken? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
                characterNames: const {'hero': 'Thorin', 'hero-2': 'Bilbo'},
                onTokenSelected: (t) => selected = t,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = profile.mapGrid!;
      final sharedScene = cellCenter(grid, 2, 2);
      final sharedScreen = _sceneToScreen(tester, transformController, Offset(sharedScene.x, sharedScene.y));

      // Tap on shared square: tokChar2 was added second, so drawn last (on top)
      final g1 = await tester.startGesture(sharedScreen);
      await g1.up();
      await tester.pumpAndSettle();

      expect(selected?.token.id, equals(tokChar2.id));
      expect(find.byType(MapTokenPanel), findsOneWidget);
      expect(find.text('H2'), findsWidgets);
      expect(find.text('Bilbo'), findsOneWidget);

      // Tap on empty map clears selection
      final emptyScene = cellCenter(grid, 10, 10);
      final emptyScreen = _sceneToScreen(tester, transformController, Offset(emptyScene.x, emptyScene.y));
      final g2 = await tester.startGesture(emptyScreen);
      await g2.up();
      await tester.pumpAndSettle();

      expect(selected, isNull);
      expect(find.byType(MapTokenPanel), findsNothing);

      // Select again
      final g3 = await tester.startGesture(sharedScreen);
      await g3.up();
      await tester.pumpAndSettle();
      expect(selected, isNotNull);

      // Sync removal of selected token clears selection
      repo.profiles['camp-1'] = repo.profiles['camp-1']!.withTokenRemoved(tokChar2.id, clock.nextTimestamp());
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      expect(selected, isNull);

      // Measure on: dragging measures, no token moves
      await tester.tap(find.widgetWithText(OutlinedButton, 'Measure'));
      await tester.pumpAndSettle();

      final g4 = await tester.startGesture(sharedScreen);
      await tester.pump();
      await g4.moveTo(_sceneToScreen(tester, transformController, Offset(emptyScene.x, emptyScene.y)));
      await tester.pump();
      await g4.up();
      await tester.pumpAndSettle();

      // tokChar1 still at (2, 2)
      expect(repo.profiles['camp-1']!.tokenCell(tokChar1.id), equals(MapTokenCell(col: 2, row: 2)));
    });

    testWidgets('TV11: DM panel can remove token and set/clear owner; player panel has neither', (tester) async {
      final tokMinion = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.minion,
        refId: 'minion-1',
        label: 'G',
      );
      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Goblin',
        size: EntitySize.small,
        currentHp: 10,
        maxHp: 10,
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        minions: [minion],
        tokens: [(token: tokMinion, cell: MapTokenCell(col: 2, row: 2))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      PlacedMapToken? selected;

      // 1. DM view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: true,
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
                characterNames: const {'hero': 'Thorin'},
                onTokenSelected: (t) => selected = t,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final grid = profile.mapGrid!;
      final tokenScreen = _sceneToScreen(tester, transformController, Offset(cellCenter(grid, 2, 2).x, cellCenter(grid, 2, 2).y));

      // Select token
      final g1 = await tester.startGesture(tokenScreen);
      await g1.up();
      await tester.pumpAndSettle();

      expect(selected?.token.id, equals(tokMinion.id));
      expect(find.widgetWithText(OutlinedButton, 'Remove token'), findsOneWidget);
      expect(find.byType(DropdownButton<String?>), findsOneWidget);

      // Select owner 'hero'
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thorin').last);
      await tester.pumpAndSettle();

      expect(repo.profiles['camp-1']!.minionOwner('minion-1'), equals('hero'));

      // Remove token
      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove token'));
      await tester.pumpAndSettle();

      expect(repo.profiles['camp-1']!.activeToken(tokMinion.id), isNull);
      expect(selected, isNull);

      // 2. Player view
      repo.profiles['camp-1'] = profile; // restore token
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 800,
              child: MapView(
                controller: controller,
                canEditMap: false,
                membershipCharacterId: 'hero',
                tokenService: tokenService,
                gridService: gridService,
                transformationController: transformController,
                onTokenSelected: (t) => selected = t,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select token as player
      final playerTokenScreen = _sceneToScreen(tester, transformController, Offset(cellCenter(grid, 2, 2).x, cellCenter(grid, 2, 2).y));
      final g2 = await tester.startGesture(playerTokenScreen);
      await g2.up();
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(find.byType(MapTokenPanel), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Remove token'), findsNothing);
      expect(find.byType(DropdownButton<String?>), findsNothing);
    });
  });
}
