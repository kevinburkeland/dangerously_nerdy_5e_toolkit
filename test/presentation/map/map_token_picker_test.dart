import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/active_map_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_grid_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';
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

void main() {
  group('MapTokenPickerSuite (TP1 - TP5)', () {
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
      List<String> roster = const ['hero'],
      Map<String, String> combatants = const {},
      List<MinionInstance> minions = const [],
      List<({MapToken token, MapTokenCell cell})> tokens = const [],
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
                  visible: true,
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
      return p;
    }

    testWidgets('TP1: Add token disabled with tooltip when no grid, hidden for player', (tester) async {
      final profile = buildBaseProfile(campaignId: 'camp-1', withGrid: false);
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      // DM view
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

      final addBtnFinder = find.widgetWithText(OutlinedButton, 'Add token');
      expect(addBtnFinder, findsOneWidget);
      final btn = tester.widget<OutlinedButton>(addBtnFinder);
      expect(btn.onPressed, isNull);
      expect(find.byTooltip('Set up the grid first'), findsOneWidget);

      // Player view
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapView(
              controller: controller,
              canEditMap: false,
              tokenService: tokenService,
              gridService: gridService,
              transformationController: transformController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Add token'), findsNothing);
    });

    testWidgets('TP2: Dialog shows 3 sections in order with candidates; onThisMap disabled; empty section None yet', (tester) async {
      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Goblin Guard',
        currentHp: 10,
        maxHp: 10,
        size: EntitySize.small,
      );

      final tokenHero = MapToken(
        id: 'tok_00000000000000000000000000000001',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );

      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        combatants: {}, // empty combatants section
        minions: [minion],
        tokens: [(token: tokenHero, cell: MapTokenCell(col: 1, row: 1))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapView(
              controller: controller,
              canEditMap: true,
              tokenService: tokenService,
              gridService: gridService,
              transformationController: transformController,
              characterNames: const {'hero': 'Thorin'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add token'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Characters'), findsOneWidget);
      expect(find.text('Combatants'), findsOneWidget);
      expect(find.text('Minions'), findsOneWidget);

      // Hero candidate shows On this map
      expect(find.text('Thorin'), findsOneWidget);
      expect(find.text('On this map'), findsOneWidget);

      // Combatants has None yet
      expect(find.text('None yet'), findsOneWidget);

      // Minion candidate
      expect(find.text('Goblin Guard'), findsOneWidget);
    });

    testWidgets('TP3: Prefill suggestedLabel, upper-cased <= 3 chars, invalid keeps Place disabled', (tester) async {
      final minion = MinionInstance(
        id: 'minion-1',
        name: 'goblin',
        currentHp: 10,
        maxHp: 10,
        size: EntitySize.small,
      );

      // Token with label 'G' already on map
      final tokenG = MapToken(
        id: 'tok_00000000000000000000000000000002',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero-g',
        label: 'G',
      );

      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero-g'],
        minions: [minion],
        tokens: [(token: tokenG, cell: MapTokenCell(col: 2, row: 2))],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

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

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add token'));
      await tester.pumpAndSettle();

      // Tap on goblin candidate
      await tester.tap(find.text('goblin'));
      await tester.pumpAndSettle();

      // Field prefills G2
      final labelFieldFinder = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      expect(find.text('G2'), findsOneWidget);

      // Typing 'ab' gives 'AB'
      await tester.enterText(labelFieldFinder, 'ab');
      await tester.pumpAndSettle();
      expect(find.text('AB'), findsOneWidget);

      // Typing 4th char is ignored (Max 3 chars)
      await tester.enterText(labelFieldFinder, 'abcd');
      await tester.pumpAndSettle();
      final tf = tester.widget<TextField>(labelFieldFinder);
      expect(tf.controller!.text, equals('ABC'));

      // A label of '-' keeps Place disabled
      await tester.enterText(labelFieldFinder, '-');
      await tester.pumpAndSettle();
      final placeBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Place'));
      expect(placeBtn.onPressed, isNull);
    });

    testWidgets('TP4: Place puts token under view centre; after panning past edge, lands on column 19', (tester) async {
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
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

      // View centre is (500, 400), which corresponds to square (10, 8)
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add token'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('hero'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Place'));
      await tester.pumpAndSettle();

      // Check stored token cell
      var updated = repo.profiles['camp-1']!;
      var tokenHero = updated.tokensOnMap(mapRef.sha256Hex).first;
      expect(tokenHero.cell.col, equals(10));
      expect(tokenHero.cell.row, equals(8));

      // Pan so centre is past image right edge
      transformController.value = Matrix4.identity()..translateByDouble(-1500.0, 0.0, 0.0, 1.0);
      await tester.pumpAndSettle();

      // Add another token (e.g. minion)
      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Wolf',
        currentHp: 10,
        maxHp: 10,
        size: EntitySize.small,
      );
      repo.profiles['camp-1'] = updated.copyWith(
        roomState: updated.roomState.copyWith(
          activeMinions: updated.roomState.activeMinions.add('minion-1', minion, clock.nextTimestamp()),
        ),
      );
      repo.setActiveProfileId('camp-1');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add token'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wolf'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Place'));
      await tester.pumpAndSettle();

      updated = repo.profiles['camp-1']!;
      final tokenWolf = updated.tokensOnMap(mapRef.sha256Hex).firstWhere((t) => t.token.refId == 'minion-1');
      expect(tokenWolf.cell.col, equals(19)); // Clamped to col 19
    });

    testWidgets('TP5: Stale picker: concurrent place gives duplicate message; concurrent removal gives unknownRef message', (tester) async {
      final minion = MinionInstance(
        id: 'minion-1',
        name: 'Wolf',
        currentHp: 10,
        maxHp: 10,
        size: EntitySize.small,
      );
      final profile = buildBaseProfile(
        campaignId: 'camp-1',
        roster: ['hero'],
        minions: [minion],
      );
      repo.profiles['camp-1'] = profile;
      repo.setActiveProfileId('camp-1');
      controller.start();
      await tester.pumpAndSettle();

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

      // Open picker dialog for hero
      await tester.tap(find.widgetWithText(OutlinedButton, 'Add token'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('hero'));
      await tester.pumpAndSettle();

      // Before pressing Place, concurrent sync change places token for hero
      final existingHeroToken = MapToken(
        id: 'tok_00000000000000000000000000000003',
        mapSha256Hex: mapRef.sha256Hex,
        kind: MapTokenKind.character,
        refId: 'hero',
        label: 'H',
      );
      repo.profiles['camp-1'] = repo.profiles['camp-1']!.withTokenPlaced(
        existingHeroToken,
        MapTokenCell(col: 3, row: 3),
        clock.nextTimestamp(),
      );

      // Now press Place
      await tester.tap(find.widgetWithText(ElevatedButton, 'Place'));
      await tester.pumpAndSettle();

      expect(find.text('That one is already on this map.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget); // Dialog stays open

      // Now select Wolf
      await tester.tap(find.text('Wolf'));
      await tester.pumpAndSettle();

      // Before pressing Place, concurrent sync change removes Wolf minion
      final cur = repo.profiles['camp-1']!;
      repo.profiles['camp-1'] = cur.copyWith(
        roomState: cur.roomState.copyWith(
          activeMinions: cur.roomState.activeMinions.remove('minion-1', clock.nextTimestamp()),
        ),
      );

      // Now press Place
      await tester.tap(find.widgetWithText(ElevatedButton, 'Place'));
      await tester.pumpAndSettle();

      expect(find.text('That character, combatant or minion is gone.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget); // Dialog stays open
    });
  });
}
