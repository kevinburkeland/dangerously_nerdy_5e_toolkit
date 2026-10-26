import 'dart:math';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_mover.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_rules.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/map_token_service.dart';

import '../../test_doubles/delayed_emit_campaign_repository.dart';

String _tokId(int i) => 'tok_${i.toRadixString(16).padLeft(32, '0')}';
const _mapSha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

final _mapRef = BlobRef(
  sha256Hex: _mapSha,
  byteSize: 1000,
  width: 1000,
  height: 800,
  format: BlobFormat.jpeg,
);

final _grid = MapGrid(
  mapSha256Hex: _mapSha,
  cellCentiPx: 5000,
  offsetXCentiPx: 0,
  offsetYCentiPx: 0,
  feetPerCell: 5,
  visible: true,
);

CampaignProfile _buildInitialProfile(StatefulHlcClock clock) {
  const ts100 = HybridLogicalClock(physicalTime: 100, logicalCounter: 0, nodeId: 'n1');

  var roster = const CrdtOrSet<String>.empty();
  roster = roster.add('slug_player', 'slug_player', ts100);

  var minions = const CrdtOrSet<dynamic>.empty();
  minions = minions.add('min_1', {'id': 'min_1', 'name': 'Goblin'}, ts100);

  var profile = CampaignProfile.raw(
    id: 'camp_mover_test',
    nameRegister: const CrdtLwwRegister<String>(value: 'Camp', timestamp: ts100),
    notesRegister: const CrdtLwwRegister<String>(value: 'Notes', timestamp: ts100),
    activeMapRegister: CrdtLwwRegister<BlobRef?>(value: _mapRef, timestamp: ts100),
    mapGridRegister: CrdtLwwRegister<MapGrid?>(value: _grid, timestamp: ts100),
    partyRoster: roster,
    roomState: const RoomNodeState.empty().copyWith(activeMinions: minions),
    createdAt: DateTime.utc(2026, 1, 1),
    lastPlayedAt: DateTime.utc(2026, 1, 1),
  );

  // 3 initial tokens: character, combatant, minion
  profile = profile.withTokenPlaced(
    MapToken(
      id: _tokId(1),
      mapSha256Hex: _mapSha,
      kind: MapTokenKind.character,
      refId: 'slug_player',
      label: 'C1',
    ),
    MapTokenCell(col: 2, row: 2),
    ts100,
  );
  profile = profile.withTokenPlaced(
    MapToken(
      id: _tokId(2),
      mapSha256Hex: _mapSha,
      kind: MapTokenKind.monster,
      refId: 'p_1',
      label: 'M1',
    ),
    MapTokenCell(col: 4, row: 4),
    ts100,
  );
  profile = profile.withTokenPlaced(
    MapToken(
      id: _tokId(3),
      mapSha256Hex: _mapSha,
      kind: MapTokenKind.minion,
      refId: 'min_1',
      label: 'N1',
    ),
    MapTokenCell(col: 6, row: 6),
    ts100,
  );

  return profile;
}

int _nextTokenIndex = 100;
String _genNewTokenId() => 'tok_${(_nextTokenIndex++).toRadixString(16).padLeft(32, '0')}';

void main() {
  group('MapTokenMoverSuite (TM1 - TM5, TML1)', () {
    test('TM1: DM move shows new square at once, while write runs, and after emit (both emit orders)', () {
      void runCase({required Duration futureDelay, required Duration emitDelay}) {
        fakeAsync((async) {
          final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
          final repo = DelayedEmitCampaignRepository(
            _buildInitialProfile(clock),
            futureDelay,
            emitDelay,
          );
          final service = MapTokenService(
            campaignRepo: repo,
            clock: clock,
            newTokenId: _genNewTokenId,
          );
          final mover = MapTokenMover(
            service: service,
            campaignId: 'camp_mover_test',
            map: _mapRef,
            actor: const MapTokenActor.dm(),
          );

          final sub = repo.watchActiveProfile().listen((_) {
            mover.latestArrived();
          });

          final tokenId = _tokId(1);
          final storedCell = repo.activeProfile!.mapTokenCells.items[tokenId]!.value;
          final newCell = MapTokenCell(col: 10, row: 10);

          // Before move
          expect(mover.shownCell(tokenId, storedCell), equals(storedCell));

          // Call move
          mover.move(tokenId, newCell);

          // Shown at once
          expect(mover.shownCell(tokenId, storedCell), equals(newCell));

          // 10 ms later
          async.elapse(const Duration(milliseconds: 10));
          expect(mover.shownCell(tokenId, storedCell), equals(newCell));

          // Advance until idle
          while (!repo.isIdle) {
            async.elapse(const Duration(milliseconds: 10));
            final currentStored = repo.activeProfile?.mapTokenCells.items[tokenId]?.value ?? storedCell;
            expect(mover.shownCell(tokenId, currentStored), equals(newCell));
          }

          async.elapse(const Duration(milliseconds: 1));

          final finalStored = repo.activeProfile!.mapTokenCells.items[tokenId]!.value;
          expect(finalStored, equals(newCell));
          expect(mover.shownCell(tokenId, finalStored), equals(newCell));

          sub.cancel();
          mover.dispose();
        });
      }

      // Emit before write finishes
      runCase(
        futureDelay: const Duration(milliseconds: 100),
        emitDelay: const Duration(milliseconds: 30),
      );

      // Emit after write finishes
      runCase(
        futureDelay: const Duration(milliseconds: 30),
        emitDelay: const Duration(milliseconds: 100),
      );
    });

    test('TM2 (queued, Q1 shape): two quick moves of same token show second move square at every 10 ms step until idle', () {
      fakeAsync((async) {
        final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
        final repo = DelayedEmitCampaignRepository(
          _buildInitialProfile(clock),
        );

        final futureDelays = [const Duration(milliseconds: 300), const Duration(milliseconds: 10)];
        final emitDelays = [const Duration(milliseconds: 50), const Duration(milliseconds: 200)];
        int fIdx = 0;
        int eIdx = 0;
        repo.futureDelayProvider = () => futureDelays[fIdx++];
        repo.emitDelayProvider = () => emitDelays[eIdx++];

        final service = MapTokenService(
          campaignRepo: repo,
          clock: clock,
          newTokenId: _genNewTokenId,
        );
        final mover = MapTokenMover(
          service: service,
          campaignId: 'camp_mover_test',
          map: _mapRef,
          actor: const MapTokenActor.dm(),
        );

        final tokenId = _tokId(1);
        final stored = repo.activeProfile!.mapTokenCells.items[tokenId]!.value;
        MapTokenCell viewStored = stored;
        final sub = repo.watchActiveProfile().listen((p) {
          viewStored = p?.mapTokenCells.items[tokenId]?.value ?? viewStored;
          mover.latestArrived();
        });

        final cell1 = MapTokenCell(col: 7, row: 7);
        final cell2 = MapTokenCell(col: 9, row: 9);

        final f1 = mover.move(tokenId, cell1);
        final f2 = mover.move(tokenId, cell2);

        expect(mover.shownCell(tokenId, viewStored), equals(cell2));

        bool allDone = false;
        Future.wait([f1, f2]).then((_) => allDone = true);

        while (!allDone || !repo.isIdle) {
          async.elapse(const Duration(milliseconds: 10));
          expect(mover.shownCell(tokenId, viewStored), equals(cell2));
        }

        final finalStored = repo.activeProfile!.mapTokenCells.items[tokenId]!.value;
        expect(finalStored, equals(cell2));

        sub.cancel();
        mover.dispose();
      });
    });

    test('TM3: refusal reverts square, sets lastRefusal to notAllowed, and clearMessages clears it', () {
      fakeAsync((async) {
        final clock = StatefulHlcClock(replicaId: ReplicaId('player_node'));
        final repo = DelayedEmitCampaignRepository(_buildInitialProfile(clock));
        final service = MapTokenService(
          campaignRepo: repo,
          clock: clock,
          newTokenId: _genNewTokenId,
        );
        final mover = MapTokenMover(
          service: service,
          campaignId: 'camp_mover_test',
          map: _mapRef,
          actor: const MapTokenActor.player('slug_player'),
        );

        final sub = repo.watchActiveProfile().listen((_) {
          mover.latestArrived();
        });

        // Token 3 is an unowned minion -> player actor is refused with notAllowed
        final minionTokenId = _tokId(3);
        final storedCell = repo.activeProfile!.mapTokenCells.items[minionTokenId]!.value;
        final targetCell = MapTokenCell(col: 12, row: 12);

        mover.move(minionTokenId, targetCell);
        expect(mover.shownCell(minionTokenId, storedCell), equals(targetCell));

        async.elapse(const Duration(milliseconds: 10));

        expect(mover.lastRefusal, equals(MapTokenWriteResult.notAllowed));
        expect(mover.shownCell(minionTokenId, storedCell), equals(storedCell));
        expect(repo.serviceWritesCount, equals(0));

        mover.clearMessages();
        expect(mover.lastRefusal, isNull);

        sub.cancel();
        mover.dispose();
      });
    });

    test('TM4: failure in repository sets lastWriteError, reverts square, allows next write, no uncaught error', () {
      fakeAsync((async) {
        final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
        final repo = DelayedEmitCampaignRepository(_buildInitialProfile(clock));
        final service = MapTokenService(
          campaignRepo: repo,
          clock: clock,
          newTokenId: _genNewTokenId,
        );
        final mover = MapTokenMover(
          service: service,
          campaignId: 'camp_mover_test',
          map: _mapRef,
          actor: const MapTokenActor.dm(),
        );

        final sub = repo.watchActiveProfile().listen((_) {
          mover.latestArrived();
        });

        final tokenId = _tokId(1);
        final storedCell = repo.activeProfile!.mapTokenCells.items[tokenId]!.value;
        final badCell = MapTokenCell(col: 15, row: 15);
        final goodCell = MapTokenCell(col: 16, row: 14);

        repo.nextUpdateError = Exception('Storage failure');

        mover.move(tokenId, badCell);
        expect(mover.shownCell(tokenId, storedCell), equals(badCell));

        async.elapse(const Duration(milliseconds: 10));

        expect(mover.lastWriteError, isNotNull);
        expect(mover.shownCell(tokenId, storedCell), equals(storedCell));

        // Next move succeeds
        bool goodDone = false;
        mover.move(tokenId, goodCell).then((res) {
          goodDone = true;
        });
        while (!goodDone || !repo.isIdle) {
          async.elapse(const Duration(milliseconds: 10));
        }

        final finalStored = repo.activeProfile!.mapTokenCells.items[tokenId]!.value;
        expect(finalStored, equals(goodCell));

        sub.cancel();
        mover.dispose();
      });
    });

    test('TM5: removal crossing drag results in notFound and token not in tokensOnMap', () {
      fakeAsync((async) {
        final clock = StatefulHlcClock(replicaId: ReplicaId('dm_node'));
        final repo = DelayedEmitCampaignRepository(
          _buildInitialProfile(clock),
          const Duration(milliseconds: 100),
          const Duration(milliseconds: 20),
        );
        final service = MapTokenService(
          campaignRepo: repo,
          clock: clock,
          newTokenId: _genNewTokenId,
        );
        final mover = MapTokenMover(
          service: service,
          campaignId: 'camp_mover_test',
          map: _mapRef,
          actor: const MapTokenActor.dm(),
        );

        final sub = repo.watchActiveProfile().listen((_) {
          mover.latestArrived();
        });

        final tokenId = _tokId(1);
        final newCell = MapTokenCell(col: 18, row: 10);

        repo.onBeforeTransform = (cur) {
          repo.profiles['camp_mover_test'] = cur.withTokenRemoved(tokenId, clock.nextTimestamp());
        };

        bool moveDone = false;
        mover.move(tokenId, newCell).then((res) {
          moveDone = true;
        });

        while (!moveDone || !repo.isIdle) {
          async.elapse(const Duration(milliseconds: 10));
        }

        expect(mover.lastRefusal, equals(MapTokenWriteResult.notFound));
        final stored = MapTokenCell(col: 2, row: 2);
        expect(mover.shownCell(tokenId, stored), equals(stored));
        final onMap = repo.activeProfile!.tokensOnMap(_mapSha);
        expect(onMap.any((t) => t.token.id == tokenId), isFalse);

        sub.cancel();
        mover.dispose();
      });
    });

    test('TML1 (law, at least 200 seeds): randomized mover moves and concurrent sync steps', () {
      int dropsWhileInFlightCount = 0;
      int emitAfterWriteFinishedCount = 0;

      for (int seed = 0; seed < 200; seed++) {
        fakeAsync((async) {
          final rng = Random(seed + 8888);
          final dmClock = StatefulHlcClock(replicaId: ReplicaId('dm_$seed'));
          final coDmClock = StatefulHlcClock(replicaId: ReplicaId('codm_$seed'));

          final repo = DelayedEmitCampaignRepository(
            _buildInitialProfile(dmClock),
          );
          Duration? lastFDelay;
          repo.futureDelayProvider = () {
            final d = Duration(milliseconds: rng.nextInt(101));
            lastFDelay = d;
            return d;
          };
          repo.emitDelayProvider = () {
            final d = Duration(milliseconds: rng.nextInt(101));
            if (lastFDelay != null && d > lastFDelay!) {
              emitAfterWriteFinishedCount++;
            }
            return d;
          };

          final service = MapTokenService(
            campaignRepo: repo,
            clock: dmClock,
            newTokenId: _genNewTokenId,
          );
          final mover = MapTokenMover(
            service: service,
            campaignId: 'camp_mover_test',
            map: _mapRef,
            actor: const MapTokenActor.dm(),
          );

          final sub = repo.watchActiveProfile().listen((_) {
            mover.latestArrived();
          });

          // Tokens partitioned:
          // DM-only: tok_1 (character)
          // Shared: tok_2 (monster), tok_3 (minion)
          final dmOnlyId = _tokId(1);
          final sharedIds = [_tokId(2), _tokId(3)];

          // Pure test bookkeeping for DM-only token
          MapTokenCell? dmLastDrop;
          final stepLog = <String>[];
          final moveFutures = <Future<MapTokenWriteResult?>>[];

          final stepCount = rng.nextInt(21) + 10; // 10 to 30 steps
          for (int s = 0; s < stepCount; s++) {
            final gap = rng.nextInt(151); // 0 to 150 ms
            async.elapse(Duration(milliseconds: gap));

            final isDmDrop = rng.nextBool();
            if (isDmDrop) {
              final chosenId = rng.nextInt(3) == 0 ? dmOnlyId : sharedIds[rng.nextInt(sharedIds.length)];
              final cell = MapTokenCell(col: rng.nextInt(20), row: rng.nextInt(16));

              if (repo.inFlightWrites > 0) {
                dropsWhileInFlightCount++;
              }

              if (chosenId == dmOnlyId) {
                dmLastDrop = cell;
              }

              stepLog.add('step $s: DM drop $chosenId to (${cell.col}, ${cell.row})');
              moveFutures.add(mover.move(chosenId, cell));
            } else {
              // Sync step written directly to repository on shared tokens
              final sharedId = sharedIds[rng.nextInt(sharedIds.length)];
              final isRemoval = rng.nextInt(4) == 0;
              final ts = coDmClock.nextTimestamp();
              stepLog.add('step $s: Sync step on $sharedId (removal=$isRemoval)');

              repo.updateProfile('camp_mover_test', (p) {
                if (isRemoval) {
                  return p.withTokenRemoved(sharedId, ts);
                } else {
                  final newCell = MapTokenCell(col: rng.nextInt(20), row: rng.nextInt(16));
                  return p.withTokenMoved(sharedId, newCell, ts);
                }
              });
            }

            // Check DM-only token invariant at every step
            if (dmLastDrop != null) {
              final stored = repo.activeProfile?.mapTokenCells.items[dmOnlyId]?.value ?? MapTokenCell(col: 2, row: 2);
              final shown = mover.shownCell(dmOnlyId, stored);
              if (shown != dmLastDrop) {
                fail('Seed $seed failure at step $s:\nExpected DM-only $dmOnlyId to be $dmLastDrop, got $shown\nLog:\n${stepLog.join('\n')}');
              }
            }
          }

          // Advance until all moves complete and repository is idle
          bool allMovesDone = false;
          Future.wait(moveFutures).then((_) => allMovesDone = true);
          while (!allMovesDone || !repo.isIdle) {
            async.elapse(const Duration(milliseconds: 10));
          }

          // In real storage, when repository is idle and writes settle, the final active profile reaches the view
          repo.setActiveProfileId('camp_mover_test');
          async.elapse(const Duration(milliseconds: 10));

          // Whenever repository is idle, shownCell equals stored square for all active tokens
          for (final placed in repo.activeProfile!.tokensOnMap(_mapSha)) {
            final stored = repo.activeProfile!.mapTokenCells.items[placed.token.id]!.value;
            final shown = mover.shownCell(placed.token.id, stored);
            expect(shown, equals(stored), reason: 'Seed $seed idle mismatch for ${placed.token.id}');
          }

          // At the end, DM-only token stored square is DM's last drop
          if (dmLastDrop != null) {
            final finalStored = repo.activeProfile!.mapTokenCells.items[dmOnlyId]!.value;
            expect(finalStored, equals(dmLastDrop), reason: 'Seed $seed final stored mismatch');
          }

          sub.cancel();
          mover.dispose();
        });
      }

      // ignore: avoid_print
      print('TML1 coverage counts: dropsWhileInFlight=$dropsWhileInFlightCount, emitAfterWriteFinished=$emitAfterWriteFinishedCount');
      expect(dropsWhileInFlightCount, greaterThanOrEqualTo(30));
      expect(emitAfterWriteFinishedCount, greaterThanOrEqualTo(30));
    });
  });
}
