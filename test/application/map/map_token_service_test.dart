import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/grid_geometry.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_rules.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_service.dart';

class _FakeCampaignRepository implements ICampaignRepository {
  CampaignProfile? profile;
  int updateCallCount = 0;
  void Function(CampaignProfile current)? onBeforeTransform;

  _FakeCampaignRepository([this.profile]);

  @override
  Future<CampaignProfile> updateProfile(String id, CampaignProfile Function(CampaignProfile) transform) async {
    updateCallCount++;
    final cur = profile!;
    if (onBeforeTransform != null) {
      onBeforeTransform!(cur);
    }
    profile = transform(profile!);
    return profile!;
  }

  @override
  String? get activeProfileId => profile?.id;

  @override
  List<CampaignProfile> get allProfiles => profile != null ? [profile!] : [];

  @override
  Future<CampaignProfile?> getActiveProfile() async => profile;

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => Stream.value(allProfiles);

  @override
  CampaignProfile? get activeProfile => profile;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profile;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => profile != null ? [profile!] : [];

  @override
  Future<void> putProfile(CampaignProfile p) async {
    profile = p;
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => Stream.value(profile);

  @override
  Future<void> deleteProfile(String id) async {}
}

const _mapSha1 = '1111111111111111111111111111111111111111111111111111111111111111';
const _mapSha2 = '2222222222222222222222222222222222222222222222222222222222222222';

final _sampleMap = BlobRef(
  sha256Hex: _mapSha1,
  byteSize: 50000,
  width: 1000,
  height: 800,
  format: BlobFormat.webp,
);

final _sampleGrid = MapGrid(
  mapSha256Hex: _mapSha1,
  cellCentiPx: 5000,
  offsetXCentiPx: 0,
  offsetYCentiPx: 0,
  feetPerCell: 5,
  visible: true,
);

CampaignProfile _buildBaseProfile({
  List<String> rosterSlugs = const ['thorin', 'bilbo'],
  List<String> minionIds = const ['m1', 'm2'],
  List<String> participantIds = const ['p1', 'p2'],
  MapGrid? grid,
}) {
  const ts = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'node_init');
  var roster = const CrdtOrSet<String>.empty();
  for (final s in rosterSlugs) {
    roster = roster.add(s, s, ts);
  }

  var minions = const CrdtOrSet<dynamic>.empty();
  for (final m in minionIds) {
    minions = minions.add(m, {'id': m, 'name': 'Minion $m'}, ts);
  }

  var encounter = const CrdtOrSet<EncounterParticipant>.empty();
  for (final p in participantIds) {
    encounter = encounter.add(
      p,
      EncounterParticipant(
        participantId: p,
        entityLink: RoomEntityLink(entityId: p, displayName: p),
        currentHp: 10,
        maxHp: 10,
        defense: 10,
        initiativeScore: 10,
      ),
      ts,
    );
  }

  return CampaignProfile.raw(
    id: 'camp_service_test',
    nameRegister: const CrdtLwwRegister<String>(value: 'Campaign', timestamp: ts),
    notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: ts),
    partyRoster: roster,
    activeMapRegister: CrdtLwwRegister<BlobRef?>(value: _sampleMap, timestamp: ts),
    mapGridRegister: CrdtLwwRegister<MapGrid?>(value: grid ?? _sampleGrid, timestamp: ts),
    roomState: const RoomNodeState.empty().copyWith(
      activeMinions: minions,
      activeEncounter: encounter,
    ),
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('Map slice 1.5: Token Service Suite', () {
    test('TS7 place: DM places tokens, handles refusals, removes and places again, another map', () async {
      int idCounter = 0;
      String nextId() => 'tok_${(++idCounter).toRadixString(16).padLeft(32, '0')}';
      final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
      final repo = _FakeCampaignRepository(_buildBaseProfile());
      final service = MapTokenService(campaignRepo: repo, clock: clock, newTokenId: nextId);

      // 1. DM places a character, a combatant, and a minion
      final resChar = await service.placeToken(
        'camp_service_test',
        _sampleMap,
        const MapTokenActor.dm(),
        kind: MapTokenKind.character,
        refId: 'thorin',
        label: 'TH',
        cell: MapTokenCell(col: 0, row: 0),
      );
      expect(resChar, equals(MapTokenWriteResult.written));

      final resMon = await service.placeToken(
        'camp_service_test',
        _sampleMap,
        const MapTokenActor.dm(),
        kind: MapTokenKind.monster,
        refId: 'p1',
        label: 'G1',
        cell: MapTokenCell(col: 1, row: 1),
      );
      expect(resMon, equals(MapTokenWriteResult.written));

      final resMin = await service.placeToken(
        'camp_service_test',
        _sampleMap,
        const MapTokenActor.dm(),
        kind: MapTokenKind.minion,
        refId: 'm1',
        label: 'M1',
        cell: MapTokenCell(col: 2, row: 2),
      );
      expect(resMin, equals(MapTokenWriteResult.written));

      final onMap = repo.profile!.tokensOnMap(_mapSha1);
      expect(onMap.length, equals(3));
      expect(onMap.map((t) => t.token.refId), equals(['thorin', 'p1', 'm1']));

      // Refusals - assert result and profile unchanged
      final beforeRefusals = repo.profile!;

      // Player actor -> notAllowed
      final resPlayer = await service.placeToken(
        'camp_service_test',
        _sampleMap,
        const MapTokenActor.player('thorin'),
        kind: MapTokenKind.character,
        refId: 'bilbo',
        label: 'BI',
        cell: MapTokenCell(col: 5, row: 5),
      );
      expect(resPlayer, equals(MapTokenWriteResult.notAllowed));
      expect(repo.profile, equals(beforeRefusals));

      // No grid / grid for another map -> noGrid
      final mapNoGrid = BlobRef(sha256Hex: _mapSha2, byteSize: 1000, width: 800, height: 600, format: BlobFormat.webp);
      final resNoGrid = await service.placeToken(
        'camp_service_test',
        mapNoGrid,
        const MapTokenActor.dm(),
        kind: MapTokenKind.character,
        refId: 'bilbo',
        label: 'BI',
        cell: MapTokenCell(col: 5, row: 5),
      );
      expect(resNoGrid, equals(MapTokenWriteResult.noGrid));
      expect(repo.profile, equals(beforeRefusals));

      // Unknown refId
      for (final bad in [
        (MapTokenKind.character, 'unknown_char'),
        (MapTokenKind.monster, 'unknown_monster'),
        (MapTokenKind.minion, 'unknown_minion'),
      ]) {
        final res = await service.placeToken(
          'camp_service_test',
          _sampleMap,
          const MapTokenActor.dm(),
          kind: bad.$1,
          refId: bad.$2,
          label: 'X',
          cell: MapTokenCell(col: 5, row: 5),
        );
        expect(res, equals(MapTokenWriteResult.unknownRef));
        expect(repo.profile, equals(beforeRefusals));
      }

      // Duplicate: same kind and refId on this map
      final resDup = await service.placeToken(
        'camp_service_test',
        _sampleMap,
        const MapTokenActor.dm(),
        kind: MapTokenKind.character,
        refId: 'thorin',
        label: 'TH',
        cell: MapTokenCell(col: 3, row: 3),
      );
      expect(resDup, equals(MapTokenWriteResult.duplicate));
      expect(repo.profile, equals(beforeRefusals));

      // Off map: col 20, row 16, col -1 (with grid 50px at 0, map 1000x800 -> cols 0..19, rows 0..15)
      for (final cell in [MapTokenCell(col: 20, row: 0), MapTokenCell(col: 0, row: 16), MapTokenCell(col: -1, row: 0)]) {
        final res = await service.placeToken(
          'camp_service_test',
          _sampleMap,
          const MapTokenActor.dm(),
          kind: MapTokenKind.character,
          refId: 'bilbo',
          label: 'BI',
          cell: cell,
        );
        expect(res, equals(MapTokenWriteResult.offMap));
        expect(repo.profile, equals(beforeRefusals));
      }

      // Invalid label 'ab' throws ArgumentError and updateProfile is not called
      final callsBefore = repo.updateCallCount;
      expect(
        () => service.placeToken(
          'camp_service_test',
          _sampleMap,
          const MapTokenActor.dm(),
          kind: MapTokenKind.character,
          refId: 'bilbo',
          label: 'ab',
          cell: MapTokenCell(col: 0, row: 0),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(repo.updateCallCount, equals(callsBefore));

      // Remove first token and place again -> written with new id
      final firstTokenId = onMap.first.token.id;
      final remRes = await service.removeToken('camp_service_test', const MapTokenActor.dm(), firstTokenId);
      expect(remRes, equals(MapTokenWriteResult.written));

      final resReplaced = await service.placeToken(
        'camp_service_test',
        _sampleMap,
        const MapTokenActor.dm(),
        kind: MapTokenKind.character,
        refId: 'thorin',
        label: 'TH',
        cell: MapTokenCell(col: 0, row: 0),
      );
      expect(resReplaced, equals(MapTokenWriteResult.written));
      final newOnMap = repo.profile!.tokensOnMap(_mapSha1);
      final newThorin = newOnMap.firstWhere((t) => t.token.refId == 'thorin');
      expect(newThorin.token.id, isNot(equals(firstTokenId)));

      // Same thing on another map is written
      final map2 = BlobRef(sha256Hex: _mapSha2, byteSize: 50000, width: 1000, height: 800, format: BlobFormat.webp);
      final grid2 = MapGrid(mapSha256Hex: _mapSha2, cellCentiPx: 5000, offsetXCentiPx: 0, offsetYCentiPx: 0, feetPerCell: 5, visible: true);
      repo.profile = repo.profile!.copyWith(
        activeMapRegister: CrdtLwwRegister<BlobRef?>(value: map2, timestamp: clock.nextTimestamp()),
        mapGridRegister: CrdtLwwRegister<MapGrid?>(value: grid2, timestamp: clock.nextTimestamp()),
      );
      final resMap2 = await service.placeToken(
        'camp_service_test',
        map2,
        const MapTokenActor.dm(),
        kind: MapTokenKind.character,
        refId: 'thorin',
        label: 'TH',
        cell: MapTokenCell(col: 0, row: 0),
      );
      expect(resMap2, equals(MapTokenWriteResult.written));
    });

    test('TS8 move: DM moves all, player rules, permissions, refusals, offMap, unowned/removed minions', () async {
      int idCounter = 0;
      String nextId() => 'tok_${(++idCounter).toRadixString(16).padLeft(32, '0')}';
      final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
      final repo = _FakeCampaignRepository(_buildBaseProfile());
      final service = MapTokenService(campaignRepo: repo, clock: clock, newTokenId: nextId);

      // Place tokens
      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.character, refId: 'thorin', label: 'TH', cell: MapTokenCell(col: 0, row: 0));
      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.character, refId: 'bilbo', label: 'BI', cell: MapTokenCell(col: 1, row: 1));
      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.minion, refId: 'm1', label: 'M1', cell: MapTokenCell(col: 2, row: 2));
      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.minion, refId: 'm2', label: 'M2', cell: MapTokenCell(col: 3, row: 3));
      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.monster, refId: 'p1', label: 'P1', cell: MapTokenCell(col: 4, row: 4));

      // Own minion m1 by thorin
      await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm1', 'thorin');

      final tokens = repo.profile!.tokensOnMap(_mapSha1);
      final tokThorin = tokens.firstWhere((t) => t.token.refId == 'thorin').token.id;
      final tokBilbo = tokens.firstWhere((t) => t.token.refId == 'bilbo').token.id;
      final tokM1 = tokens.firstWhere((t) => t.token.refId == 'm1').token.id;
      final tokM2 = tokens.firstWhere((t) => t.token.refId == 'm2').token.id;
      final tokMonster = tokens.firstWhere((t) => t.token.refId == 'p1').token.id;

      // 1. DM moves every kind -> written
      for (final tid in [tokThorin, tokM1, tokMonster]) {
        final res = await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.dm(), tid, MapTokenCell(col: 8, row: 8));
        expect(res, equals(MapTokenWriteResult.written));
      }

      // 2. Player with slug 'thorin':
      // Moves own character -> written
      final mOwn = await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokThorin, MapTokenCell(col: 9, row: 9));
      expect(mOwn, equals(MapTokenWriteResult.written));

      // Moves minion owned by thorin (m1) -> written
      final mMin = await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokM1, MapTokenCell(col: 9, row: 9));
      expect(mMin, equals(MapTokenWriteResult.written));

      // Not allowed for player:
      // another player's character (bilbo)
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokBilbo, MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notAllowed));
      // unowned minion (m2)
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokM2, MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notAllowed));
      // minion owned by someone else (own m2 by bilbo)
      await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm2', 'bilbo');
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokM2, MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notAllowed));
      // combatant
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokMonster, MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notAllowed));

      // Player whose slug isn't on the roster -> notAllowed
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('off_roster'), tokThorin, MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notAllowed));

      // MapTokenActor.player(null) -> notAllowed for every token
      for (final tid in [tokThorin, tokBilbo, tokM1, tokMonster]) {
        expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player(null), tid, MapTokenCell(col: 5, row: 5)),
            equals(MapTokenWriteResult.notAllowed));
      }

      // Removed token -> notFound
      await service.removeToken('camp_service_test', const MapTokenActor.dm(), tokBilbo);
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.dm(), tokBilbo, MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notFound));

      // Unknown id -> notFound
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.dm(), 'tok_unknown000000000000000000000000', MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notFound));

      // Token of another map -> notFound
      final map2 = BlobRef(sha256Hex: _mapSha2, byteSize: 50000, width: 1000, height: 800, format: BlobFormat.webp);
      expect(await service.moveToken('camp_service_test', map2, const MapTokenActor.dm(), tokThorin, MapTokenCell(col: 5, row: 5)),
          equals(MapTokenWriteResult.notFound));

      // Same cell -> unchanged (cell is 9, 9 from previous move)
      final profBeforeSame = repo.profile!;
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.dm(), tokThorin, MapTokenCell(col: 9, row: 9)),
          equals(MapTokenWriteResult.unchanged));
      expect(repo.profile, equals(profBeforeSame));

      // Column 20 -> offMap
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.dm(), tokThorin, MapTokenCell(col: 20, row: 0)),
          equals(MapTokenWriteResult.offMap));

      // Minion owned by thorin (m1) whose minion was removed from activeMinions -> notAllowed
      repo.profile = repo.profile!.copyWith(
        roomState: repo.profile!.roomState.copyWith(
          activeMinions: repo.profile!.roomState.activeMinions.remove('m1', clock.nextTimestamp()),
        ),
      );
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokM1, MapTokenCell(col: 2, row: 2)),
          equals(MapTokenWriteResult.notAllowed));
    });

    test('TS9 decisions use latest profile with queued changes', () async {
      int idCounter = 0;
      String nextId() => 'tok_${(++idCounter).toRadixString(16).padLeft(32, '0')}';
      final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
      final repo = _FakeCampaignRepository(_buildBaseProfile());
      final service = MapTokenService(campaignRepo: repo, clock: clock, newTokenId: nextId);

      // Place a character and a minion
      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.character, refId: 'thorin', label: 'TH', cell: MapTokenCell(col: 0, row: 0));
      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.minion, refId: 'm1', label: 'M1', cell: MapTokenCell(col: 1, row: 1));
      await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm1', 'thorin');

      final tokMinion = repo.profile!.tokensOnMap(_mapSha1).firstWhere((t) => t.token.refId == 'm1').token.id;
      final tokChar = repo.profile!.tokensOnMap(_mapSha1).firstWhere((t) => t.token.refId == 'thorin').token.id;

      // Case 1: queued change clears minion owner -> player's move is notAllowed
      repo.onBeforeTransform = (cur) {
        repo.profile = cur.withMinionOwner('m1', null, clock.nextTimestamp());
      };
      final res1 = await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokMinion, MapTokenCell(col: 5, row: 5));
      expect(res1, equals(MapTokenWriteResult.notAllowed));
      expect(repo.profile!.tokenCell(tokMinion), equals(MapTokenCell(col: 1, row: 1)));

      // Case 2: queued change sets owner to thorin -> player's move is written
      repo.onBeforeTransform = (cur) {
        repo.profile = cur.withMinionOwner('m1', 'thorin', clock.nextTimestamp());
      };
      final res2 = await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.player('thorin'), tokMinion, MapTokenCell(col: 5, row: 5));
      expect(res2, equals(MapTokenWriteResult.written));
      expect(repo.profile!.tokenCell(tokMinion), equals(MapTokenCell(col: 5, row: 5)));

      // Case 3: queued change removes token -> DM's move is notFound
      repo.onBeforeTransform = (cur) {
        repo.profile = cur.withTokenRemoved(tokChar, clock.nextTimestamp());
      };
      final res3 = await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.dm(), tokChar, MapTokenCell(col: 7, row: 7));
      expect(res3, equals(MapTokenWriteResult.notFound));

      // Case 4: queued change places a token for bilbo -> DM's place of bilbo is duplicate
      repo.onBeforeTransform = (cur) {
        final tokBilbo = MapToken(id: nextId(), mapSha256Hex: _mapSha1, kind: MapTokenKind.character, refId: 'bilbo', label: 'BI');
        repo.profile = cur.withTokenPlaced(tokBilbo, MapTokenCell(col: 2, row: 2), clock.nextTimestamp());
      };
      final res4 = await service.placeToken(
        'camp_service_test',
        _sampleMap,
        const MapTokenActor.dm(),
        kind: MapTokenKind.character,
        refId: 'bilbo',
        label: 'BI',
        cell: MapTokenCell(col: 3, row: 3),
      );
      expect(res4, equals(MapTokenWriteResult.duplicate));

      repo.onBeforeTransform = null;
    });

    test('TS10 remove and never back: DM removes, later move on replica does not resurrect, player notAllowed', () async {
      int idCounter = 0;
      String nextId() => 'tok_${(++idCounter).toRadixString(16).padLeft(32, '0')}';
      final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
      final repo = _FakeCampaignRepository(_buildBaseProfile());
      final service = MapTokenService(campaignRepo: repo, clock: clock, newTokenId: nextId);

      await service.placeToken('camp_service_test', _sampleMap, const MapTokenActor.dm(),
          kind: MapTokenKind.character, refId: 'thorin', label: 'TH', cell: MapTokenCell(col: 0, row: 0));
      final tokId = repo.profile!.tokensOnMap(_mapSha1).first.token.id;

      // Player remove -> notAllowed
      expect(await service.removeToken('camp_service_test', const MapTokenActor.player('thorin'), tokId),
          equals(MapTokenWriteResult.notAllowed));

      // Snapshot before removal
      final beforeRemoval = repo.profile!;

      // DM removes -> written
      final remRes = await service.removeToken('camp_service_test', const MapTokenActor.dm(), tokId);
      expect(remRes, equals(MapTokenWriteResult.written));

      // Then a DM move of it -> notFound
      expect(await service.moveToken('camp_service_test', _sampleMap, const MapTokenActor.dm(), tokId, MapTokenCell(col: 1, row: 1)),
          equals(MapTokenWriteResult.notFound));

      // Second replica moves token with a NEWER timestamp
      const newerStamp = HybridLogicalClock(physicalTime: 99999999, logicalCounter: 0, nodeId: 'replica_node');
      final replicaProfile = beforeRemoval.withTokenMoved(tokId, MapTokenCell(col: 10, row: 10), newerStamp);

      // Join replica with first
      final joined = CampaignProfile.join(repo.profile!, replicaProfile);
      expect(joined.activeToken(tokId), isNull);
      expect(joined.tokensOnMap(_mapSha1).any((t) => t.token.id == tokId), isFalse);
    });

    test('TS11 owners: DM sets, changes, clears, unknown ref, same owner unchanged, player notAllowed', () async {
      int idCounter = 0;
      String nextId() => 'tok_${(++idCounter).toRadixString(16).padLeft(32, '0')}';
      final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
      final repo = _FakeCampaignRepository(_buildBaseProfile());
      final service = MapTokenService(campaignRepo: repo, clock: clock, newTokenId: nextId);

      // DM sets owner -> written
      final s1 = await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm1', 'thorin');
      expect(s1, equals(MapTokenWriteResult.written));
      expect(repo.profile!.minionOwner('m1'), equals('thorin'));

      // Setting same owner again -> unchanged
      final sSame = await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm1', 'thorin');
      expect(sSame, equals(MapTokenWriteResult.unchanged));

      // Changes owner -> written
      final s2 = await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm1', 'bilbo');
      expect(s2, equals(MapTokenWriteResult.written));
      expect(repo.profile!.minionOwner('m1'), equals('bilbo'));

      // Clears owner -> written
      final s3 = await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm1', null);
      expect(s3, equals(MapTokenWriteResult.written));
      expect(repo.profile!.minionOwner('m1'), isNull);

      // Unknown minion -> unknownRef
      expect(await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'unknown_m', 'thorin'),
          equals(MapTokenWriteResult.unknownRef));

      // Unknown owner slug -> unknownRef
      expect(await service.setMinionOwner('camp_service_test', const MapTokenActor.dm(), 'm1', 'unknown_slug'),
          equals(MapTokenWriteResult.unknownRef));

      // Player actor -> notAllowed
      expect(await service.setMinionOwner('camp_service_test', const MapTokenActor.player('thorin'), 'm1', 'thorin'),
          equals(MapTokenWriteResult.notAllowed));
    });

    test('TL1 (law over 200 seeds): randomized service operations, invariant checks, coverage counts >= 20', () async {
      final counts = <MapTokenWriteResult, int>{
        for (final val in MapTokenWriteResult.values) val: 0,
      };

      for (int seed = 0; seed < 200; seed++) {
        final rand = Random(seed);
        int tokSeq = 0;
        String nextTokId() => 'tok_${(++tokSeq).toRadixString(16).padLeft(32, '0')}';
        final clock = StatefulHlcClock(replicaId: ReplicaId('node_$seed'));

        var startProfile = _buildBaseProfile(
          rosterSlugs: ['char_0', 'char_1'],
          minionIds: ['min_0', 'min_1'],
          participantIds: ['mon_0'],
        );
        startProfile = startProfile
            .withTokenPlaced(MapToken(id: nextTokId(), mapSha256Hex: _mapSha1, kind: MapTokenKind.character, refId: 'char_0', label: 'C0'), MapTokenCell(col: 1, row: 1), clock.nextTimestamp())
            .withTokenPlaced(MapToken(id: nextTokId(), mapSha256Hex: _mapSha1, kind: MapTokenKind.minion, refId: 'min_0', label: 'M0'), MapTokenCell(col: 2, row: 2), clock.nextTimestamp());

        CampaignProfile? lastSeenProfile;
        final repo = _FakeCampaignRepository(startProfile);
        final service = MapTokenService(campaignRepo: repo, clock: clock, newTokenId: nextTokId);

        final removedTokenIds = <String>{};
        final stepCount = 10 + rand.nextInt(21); // 10..30

        for (int step = 0; step < stepCount; step++) {
          final action = rand.nextInt(5);

          // Actors: DM or player (valid or invalid slug)
          final actorKind = rand.nextInt(4);
          final MapTokenActor actor = switch (actorKind) {
            0 => const MapTokenActor.dm(),
            1 => const MapTokenActor.player('char_0'),
            2 => const MapTokenActor.player('char_off'),
            _ => const MapTokenActor.player(null),
          };

          MapTokenWriteResult? result;
          CampaignProfile beforeCall = repo.profile!;
          String lastMovedTokenId = '';

          switch (action) {
            case 0:
              // Place
              final onMap = repo.profile!.tokensOnMap(_mapSha1);
              final MapTokenKind kind;
              final String refId;
              final BlobRef map;
              final MapTokenActor placeActor;

              if (onMap.isNotEmpty && rand.nextInt(3) != 0) {
                final existing = onMap[rand.nextInt(onMap.length)].token;
                kind = existing.kind;
                refId = existing.refId;
                map = _sampleMap;
                placeActor = const MapTokenActor.dm();
              } else {
                kind = MapTokenKind.values[rand.nextInt(MapTokenKind.values.length)];
                refId = rand.nextBool()
                    ? (kind == MapTokenKind.character ? 'char_0' : (kind == MapTokenKind.monster ? 'mon_0' : 'min_0'))
                    : 'bad_ref';
                map = rand.nextBool() ? _sampleMap : BlobRef(sha256Hex: _mapSha2, byteSize: 1000, width: 800, height: 600, format: BlobFormat.webp);
                placeActor = rand.nextBool() ? const MapTokenActor.dm() : actor;
              }
              final label = 'T$step';
              final cell = MapTokenCell(
                col: rand.nextBool() ? rand.nextInt(20) : (rand.nextBool() ? 20 : -1),
                row: rand.nextBool() ? rand.nextInt(16) : (rand.nextBool() ? 16 : -1),
              );

              repo.onBeforeTransform = (p) => lastSeenProfile = p;
              result = await service.placeToken(startProfile.id, map, placeActor, kind: kind, refId: refId, label: label, cell: cell);

            case 1:
              // Move
              final tokens = repo.profile!.tokensOnMap(_mapSha1);
              final String tokenId;
              if (tokens.isNotEmpty && rand.nextBool()) {
                tokenId = tokens[rand.nextInt(tokens.length)].token.id;
              } else {
                tokenId = 'tok_unknown000000000000000000000000';
              }
              final cell = MapTokenCell(
                col: rand.nextBool() ? rand.nextInt(20) : 25,
                row: rand.nextBool() ? rand.nextInt(16) : 25,
              );
              final map = rand.nextBool() ? _sampleMap : BlobRef(sha256Hex: _mapSha2, byteSize: 1000, width: 800, height: 600, format: BlobFormat.webp);

              repo.onBeforeTransform = (p) => lastSeenProfile = p;
              lastMovedTokenId = tokenId;
              result = await service.moveToken(startProfile.id, map, actor, tokenId, cell);

            case 2:
              // Remove
              final tokens = repo.profile!.tokensOnMap(_mapSha1);
              final String tokenId;
              if (tokens.isNotEmpty && rand.nextBool()) {
                tokenId = tokens[rand.nextInt(tokens.length)].token.id;
              } else {
                tokenId = 'tok_unknown000000000000000000000000';
              }
              repo.onBeforeTransform = (p) => lastSeenProfile = p;
              result = await service.removeToken(startProfile.id, actor, tokenId);
              if (result == MapTokenWriteResult.written) {
                removedTokenIds.add(tokenId);
              }

            case 3:
              // Set Minion Owner
              final minionId = rand.nextBool() ? 'min_0' : 'unknown_min';
              final ownerSlug = rand.nextInt(3) == 0 ? null : (rand.nextBool() ? 'char_0' : 'bad_slug');
              repo.onBeforeTransform = (p) => lastSeenProfile = p;
              result = await service.setMinionOwner(startProfile.id, actor, minionId, ownerSlug);

            case 4:
              // Sync step directly modifying repo (co-DM write)
              final syncKind = rand.nextInt(3);
              final syncStamp = clock.nextTimestamp();
              if (syncKind == 0) {
                // remove random token
                final tokens = repo.profile!.tokensOnMap(_mapSha1);
                if (tokens.isNotEmpty) {
                  final t = tokens.first.token.id;
                  repo.profile = repo.profile!.withTokenRemoved(t, syncStamp);
                  removedTokenIds.add(t);
                }
              } else if (syncKind == 1) {
                // move random token
                final tokens = repo.profile!.tokensOnMap(_mapSha1);
                if (tokens.isNotEmpty) {
                  final t = tokens.first.token.id;
                  repo.profile = repo.profile!.withTokenMoved(t, MapTokenCell(col: 3, row: 3), syncStamp);
                }
              } else {
                // remove min_1 from activeMinions
                repo.profile = repo.profile!.copyWith(
                  roomState: repo.profile!.roomState.copyWith(
                    activeMinions: repo.profile!.roomState.activeMinions.remove('min_1', syncStamp),
                  ),
                );
              }
          }

          if (result != null) {
            counts[result] = counts[result]! + 1;

            if (result != MapTokenWriteResult.written) {
              expect(repo.profile, equals(beforeCall),
                  reason: 'Profile mutated when result was $result at seed $seed step $step');
            } else if (actor is PlayerActor) {
              // Player write must have had permission according to reference rule
              final seen = lastSeenProfile!;
              if (action == 1) {
                // move
                final tok = seen.activeToken(lastMovedTokenId);
                if (tok != null) {
                  bool refCanMove(CampaignProfile p, MapToken t, PlayerActor a) {
                    final slug = a.rosterSlug;
                    if (slug == null || !p.partyRoster.activeValues.contains(slug)) return false;
                    if (t.kind == MapTokenKind.character) return t.refId == slug;
                    if (t.kind == MapTokenKind.minion) {
                      return p.roomState.activeMinions.items.containsKey(t.refId) &&
                          p.minionOwner(t.refId) == slug;
                    }
                    return false;
                  }
                  expect(refCanMove(seen, tok, actor as PlayerActor), isTrue,
                      reason: 'Player move written without permission at seed $seed step $step');
                }
              }
            }
          }
        }

        // Invariants at end of run:
        // 1. A token id that was ever removed is not active
        for (final remId in removedTokenIds) {
          expect(repo.profile!.activeToken(remId), isNull, reason: 'Removed token $remId active at seed $seed');
        }

        // 2. Every active token's cell is on the map
        for (final pt in repo.profile!.tokensOnMap(_mapSha1)) {
          expect(isCellOnMap(_sampleGrid, _sampleMap.width, _sampleMap.height, pt.cell), isTrue,
              reason: 'Cell ${pt.cell} off map at seed $seed');
        }

        // 3. No two active tokens on the map share kind and refId
        final onMap = repo.profile!.tokensOnMap(_mapSha1);
        final seenKeys = <String>{};
        for (final pt in onMap) {
          final key = '${pt.token.kind.name}:${pt.token.refId}';
          expect(seenKeys.contains(key), isFalse, reason: 'Duplicate token $key at seed $seed');
          seenKeys.add(key);
        }
      }

      // ignore: avoid_print
      print('TL1 Coverage Counts: $counts');

      for (final entry in counts.entries) {
        expect(entry.value, greaterThanOrEqualTo(20),
            reason: 'Coverage for ${entry.key} was ${entry.value} < 20');
      }
    });
  });
}
