// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/campaign_profile_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/app_services.dart';
import 'room_sync_orchestrator_test.dart' as h;

CampaignProfile _buildProfile(String id, ReplicaId replicaId, {int gp = 0, String name = ''}) {
  return CampaignProfile(
    id: id,
    name: name.isNotEmpty ? name : 'Campaign $id',
    edition: DmRulesEdition.v2024,
    createdAt: DateTime.utc(2026),
    lastPlayedAt: DateTime.utc(2026),
    partyPurse: const PartyPurse.empty().modifyDenomination('gp', gp, replicaId: replicaId),
    roomState: RoomNodeState(roomId: 'room_$id', roomCode: 'CR-$id', title: 'Title $id'),
    nodeId: replicaId.value,
  );
}

class _RandomDelayedFailingDbService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> writtenData = {};
  final Random rng;
  double failRate;
  bool failIndexWrites = false;
  bool failRecordDeletes = false;
  final Set<String> failKeys = {};

  _RandomDelayedFailingDbService({required this.rng, this.failRate = 0.0})
      : super.custom();

  Future<void> _simulateLatencyAndFailure({bool isIndex = false, String? key}) async {
    final delayMs = rng.nextInt(3) + 1;
    await Future<void>.delayed(Duration(milliseconds: delayMs));

    if (isIndex && failIndexWrites) {
      throw StateError('Simulated index write failure');
    }
    if (key != null && failKeys.contains(key)) {
      throw StateError('Simulated write failure for key $key');
    }
    if (failRate > 0 && rng.nextDouble() < failRate) {
      throw StateError('Simulated random storage write failure');
    }
  }

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    final isIndex = key == LocalCampaignRepository.profileIndexKey;
    await _simulateLatencyAndFailure(isIndex: isIndex, key: key);
    writtenData.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  Future<void> putAll(String boxName, Map<String, dynamic> entries) async {
    for (final key in entries.keys) {
      if (failKeys.contains(key)) {
        final delayMs = rng.nextInt(15) + 1;
        await Future<void>.delayed(Duration(milliseconds: delayMs));
        throw StateError('Simulated write failure for key $key');
      }
    }
    final hasIndex = entries.containsKey(LocalCampaignRepository.profileIndexKey);
    await _simulateLatencyAndFailure(isIndex: hasIndex);
    writtenData.putIfAbsent(boxName, () => {}).addAll(entries);
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    return writtenData[boxName]?[key] ?? defaultValue;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    if (failRecordDeletes && key.startsWith(LocalCampaignRepository.profileKeyPrefix)) {
      throw StateError('Simulated record delete failure');
    }
    final delayMs = rng.nextInt(3) + 1;
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    writtenData[boxName]?.remove(key);
  }

  @override
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    for (final k in keys) {
      await delete(boxName, k);
    }
  }

  @override
  bool isBoxOpen(String boxName) => true;

  @override
  List<String> getKeys(String boxName) =>
      writtenData[boxName]?.keys.toList() ?? [];
}

class _InvertedFakeDbService extends AppDatabaseService {
  final Map<String, Map<String, dynamic>> writtenData = {};
  int _callSeq = 0;

  _InvertedFakeDbService() : super.custom();

  @override
  Future<void> put(String boxName, String key, dynamic value) async {
    final seq = ++_callSeq;
    final delay = Duration(milliseconds: (10 - seq).clamp(1, 10) * 15);
    await Future<void>.delayed(delay);
    writtenData.putIfAbsent(boxName, () => {})[key] = value;
  }

  @override
  Future<void> putAll(String boxName, Map<String, dynamic> entries) async {
    final seq = ++_callSeq;
    final delay = Duration(milliseconds: (10 - seq).clamp(1, 10) * 15);
    await Future<void>.delayed(delay);
    writtenData.putIfAbsent(boxName, () => {}).addAll(entries);
  }

  @override
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    return writtenData[boxName]?[key] ?? defaultValue;
  }

  @override
  Future<void> delete(String boxName, String key) async {
    writtenData[boxName]?.remove(key);
  }

  @override
  Future<void> deleteAll(String boxName, Iterable<String> keys) async {
    for (final k in keys) {
      writtenData[boxName]?.remove(k);
    }
  }

  @override
  bool isBoxOpen(String boxName) => true;

  @override
  List<String> getKeys(String boxName) =>
      writtenData[boxName]?.keys.toList() ?? [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppServices.instance.debouncedStorage.flushAll();
  });

  group('Pass 5.1.3: Required Tests', () {
    // 1. X1 as a regression test
    group('1. X1 Index Regression', () {
      test('X1 with inverted fake store: after concurrent writes and restart, all ids A..E preserved', () async {
        final fakeDb = _InvertedFakeDbService();
        final replicaId = ReplicaId('node_x1');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        await repo.loadAllProfiles();

        // Write A, B, C, D concurrently
        await Future.wait([
          repo.putProfile(_buildProfile('A', replicaId)),
          repo.putProfile(_buildProfile('B', replicaId)),
          repo.putProfile(_buildProfile('C', replicaId)),
          repo.putProfile(_buildProfile('D', replicaId)),
        ]);

        // Then update A and B while putting E concurrently
        final uA = repo.updateProfile('A', (p) => p.copyWith(
          name: 'Campaign A Updated',
          nameTimestamp: clock.nextTimestamp(),
        ));
        final uB = repo.updateProfile('B', (p) => p.copyWith(
          name: 'Campaign B Updated',
          nameTimestamp: clock.nextTimestamp(),
        ));
        final fE = repo.putProfile(_buildProfile('E', replicaId));

        await Future.wait([uA, uB, fE]);

        final freshRepo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: StatefulHlcClock(replicaId: replicaId),
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        final reloaded = await freshRepo.loadAllProfiles();
        final reloadedIds = reloaded.map((p) => p.id).toList()..sort();
        expect(reloadedIds, equals(['A', 'B', 'C', 'D', 'E']));

        repo.dispose();
        freshRepo.dispose();
      });

      test('X1 real-Hive control: 20 runs reopen without lost ids', () async {
        final lostIdsAcrossRuns = <String>{};
        final replicaId = ReplicaId('node_hive');

        for (int run = 0; run < 20; run++) {
          final tempDir = await Directory.systemTemp.createTemp('hive_x1_control_');
          try {
            final db = AppDatabaseService.custom(
              hiveInit: () async => Hive.init(tempDir.path),
              hiveBoxOpener: Hive.openBox<dynamic>,
            );
            await db.init();
            final repo = LocalCampaignRepository(
              replicaId: replicaId,
              clock: StatefulHlcClock(replicaId: replicaId),
              db: db,
              characterRepo: LocalCharacterRepository(db: db),
            );
            await repo.loadAllProfiles();

            await Future.wait([
              repo.putProfile(_buildProfile('A', replicaId)),
              repo.putProfile(_buildProfile('B', replicaId)),
              repo.putProfile(_buildProfile('C', replicaId)),
              repo.putProfile(_buildProfile('D', replicaId)),
            ]);
            final uA = repo.updateProfile('A', (p) => p.copyWith(
              name: 'Campaign A Updated',
              nameTimestamp: StatefulHlcClock(replicaId: replicaId).nextTimestamp(),
            ));
            final uB = repo.updateProfile('B', (p) => p.copyWith(
              name: 'Campaign B Updated',
              nameTimestamp: StatefulHlcClock(replicaId: replicaId).nextTimestamp(),
            ));
            final fE = repo.putProfile(_buildProfile('E', replicaId));

            await Future.wait([uA, uB, fE]);
            repo.dispose();
            await db.close();

            final db2 = AppDatabaseService.custom(
              hiveInit: () async {},
              hiveBoxOpener: Hive.openBox<dynamic>,
            );
            await db2.init();
            final freshRepo = LocalCampaignRepository(
              replicaId: replicaId,
              clock: StatefulHlcClock(replicaId: replicaId),
              db: db2,
              characterRepo: LocalCharacterRepository(db: db2),
            );
            final reloaded = await freshRepo.loadAllProfiles();
            final ids = reloaded.map((p) => p.id).toSet();
            for (final expectedId in ['A', 'B', 'C', 'D', 'E']) {
              if (!ids.contains(expectedId)) {
                lostIdsAcrossRuns.add(expectedId);
              }
            }
            freshRepo.dispose();
            await db2.close();
          } finally {
            await tempDir.delete(recursive: true);
          }
        }
        expect(lostIdsAcrossRuns, isEmpty);
      });
    });

    // 2. Law test, multi-campaign (at least 200 seeds)
    group('2. Multi-Campaign Law Test (>= 200 seeds)', () {
      test('220 seeds: cache equals model, fresh repository reloads exactly model state', () async {
        const totalSeeds = 220;

        for (int seed = 0; seed < totalSeeds; seed++) {
          final rng = Random(seed * 7919 + 31);
          // Seed 0: no failures at all (0.0)
          // Seed 1: every write fails (1.0)
          // Others: random 0.0 to 0.20 failure rate
          final double failRate = seed == 0
              ? 0.0
              : (seed == 1 ? 1.0 : rng.nextDouble() * 0.20);

          final fakeDb = _RandomDelayedFailingDbService(rng: rng, failRate: failRate);
          final replicaId = ReplicaId('replica_$seed');
          final clock = StatefulHlcClock(replicaId: replicaId);
          final repo = LocalCampaignRepository(
            replicaId: replicaId,
            clock: clock,
            db: fakeDb,
            characterRepo: LocalCharacterRepository(db: fakeDb),
          );
          await repo.loadAllProfiles();

          // 2 to 5 campaign IDs
          final numCampaigns = rng.nextInt(4) + 2;
          final campaignIds = List.generate(numCampaigns, (i) => 'camp_${String.fromCharCode(65 + i)}');

          // Sequential model tracking: applies in call order every call that returned normally
          final Map<String, CampaignProfile> model = {};

          // Seed with initial profiles
          fakeDb.failRate = 0.0;
          for (final id in campaignIds.take(2)) {
            final p = _buildProfile(id, replicaId, gp: 50);
            await repo.putProfile(p);
            model[id] = p;
          }
          fakeDb.failRate = failRate;

          // 10 to 40 random calls fired without awaiting each other
          final numCalls = rng.nextInt(31) + 10;
          final callFutures = <Future<void>>[];

          // Actions to apply to model if call completes normally
          final callCompletions = <int, void Function()>{};

          for (int callIdx = 0; callIdx < numCalls; callIdx++) {
            final opChoice = rng.nextInt(10);
            final targetId = campaignIds[rng.nextInt(campaignIds.length)];

            // Includes ties: two calls on one id back to back
            if (opChoice < 4) {
              // putProfile (new or existing)
              final gpVal = rng.nextInt(500) + 1;
              final prof = _buildProfile(targetId, replicaId, gp: gpVal);
              final future = repo.putProfile(prof).then((_) {
                callCompletions[callIdx] = () {
                  model[targetId] = prof;
                };
              }).catchError((_) {});
              callFutures.add(future);
            } else if (opChoice < 7) {
              // updateProfile (purse delta or name change)
              final deltaGp = rng.nextInt(50) - 20;
              final changeName = rng.nextBool();
              final future = repo.updateProfile(targetId, (current) {
                var updated = current;
                if (changeName) {
                  updated = updated.copyWith(
                    name: '${current.name} (v$callIdx)',
                    nameTimestamp: clock.nextTimestamp(),
                  );
                }
                if (deltaGp != 0) {
                  updated = updated.copyWith(
                    partyPurse: updated.partyPurse.modifyDenomination('gp', deltaGp, replicaId: replicaId),
                  );
                }
                return updated;
              }).then((result) {
                callCompletions[callIdx] = () {
                  model[targetId] = result;
                };
              }).catchError((_) {});
              callFutures.add(future);
            } else if (opChoice < 9) {
              // deleteProfile
              final future = repo.deleteProfile(targetId).then((_) {
                callCompletions[callIdx] = () {
                  model.remove(targetId);
                };
              }).catchError((_) {});
              callFutures.add(future);
            } else {
              // occasional loadAllProfiles in the middle
              final future = repo.loadAllProfiles().then((_) {}).catchError((_) {});
              callFutures.add(future);
            }
          }

          // Wait for all calls to settle
          await Future.wait(callFutures);

          // Apply all successful calls in call order to build authoritative model
          for (int i = 0; i < numCalls; i++) {
            callCompletions[i]?.call();
          }

          // Invariant 1: Cache equals model
          final cacheProfiles = repo.allProfiles;
          final cacheIds = (cacheProfiles.map((p) => p.id).toList()..sort());
          final modelIds = (model.keys.toList()..sort());
          expect(
            cacheIds,
            equals(modelIds),
            reason: 'Seed $seed (failRate=$failRate): cache IDs do not match model IDs',
          );

          for (final id in modelIds) {
            final cacheProf = cacheProfiles.firstWhere((p) => p.id == id);
            final modelProf = model[id]!;
            expect(
              cacheProf.id,
              equals(modelProf.id),
              reason: 'Seed $seed: ID mismatch for $id',
            );
            expect(
              cacheProf.name,
              equals(modelProf.name),
              reason: 'Seed $seed: name mismatch for $id',
            );
            expect(
              cacheProf.partyPurse.getBalance('gp'),
              equals(modelProf.partyPurse.getBalance('gp')),
              reason: 'Seed $seed: GP balance mismatch for $id',
            );
          }

          // Invariant 2: Fresh repository on the same store loads exactly the model's records
          fakeDb.failRate = 0.0; // read must succeed
          final freshRepo = LocalCampaignRepository(
            replicaId: replicaId,
            clock: StatefulHlcClock(replicaId: replicaId),
            db: fakeDb,
            characterRepo: LocalCharacterRepository(db: fakeDb),
          );
          final reloaded = await freshRepo.loadAllProfiles();
          final reloadedIds = (reloaded.map((p) => p.id).toList()..sort());
          expect(
            reloadedIds,
            equals(modelIds),
            reason: 'Seed $seed: reloaded IDs do not match model IDs',
          );

          for (final id in modelIds) {
            final reloadedProf = reloaded.firstWhere((p) => p.id == id);
            final modelProf = model[id]!;
            expect(
              reloadedProf.name,
              equals(modelProf.name),
              reason: 'Seed $seed: reloaded name mismatch for $id',
            );
            expect(
              reloadedProf.partyPurse.getBalance('gp'),
              equals(modelProf.partyPurse.getBalance('gp')),
              reason: 'Seed $seed: reloaded GP mismatch for $id',
            );
          }

          repo.dispose();
          freshRepo.dispose();
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
    });

    // 3. WF as tests
    group('3. WF Write Failure Invariants', () {
      test('WF putProfile write fails: throws, cache rolled back, activeId restored, streams silent, reload clean', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(1), failRate: 0.0);
        final replicaId = ReplicaId('node_wf_put');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        await repo.putProfile(_buildProfile('A', replicaId, gp: 100));
        await repo.setActiveProfileId('A');

        int activeEmits = 0;
        int allEmits = 0;
        final sub1 = repo.watchActiveProfile().listen((_) => activeEmits++);
        final sub2 = repo.watchAllProfiles().listen((_) => allEmits++);

        fakeDb.failRate = 1.0; // all writes fail

        Object? error;
        try {
          await repo.putProfile(_buildProfile('B', replicaId, gp: 50));
        } catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(repo.activeProfileId, equals('A'));
        expect(repo.allProfiles.map((p) => p.id).toList(), equals(['A']));
        expect(activeEmits, equals(0));
        expect(allEmits, equals(0));

        fakeDb.failRate = 0.0;
        final freshRepo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: StatefulHlcClock(replicaId: replicaId),
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        final reloaded = await freshRepo.loadAllProfiles();
        expect(reloaded.map((p) => p.id).toList(), equals(['A']));

        await sub1.cancel();
        await sub2.cancel();
        repo.dispose();
        freshRepo.dispose();
      });

      test('WF updateProfile write fails: throws, cache rolled back, streams silent, reload clean', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(2), failRate: 0.0);
        final replicaId = ReplicaId('node_wf_update');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        await repo.putProfile(_buildProfile('A', replicaId, gp: 100));

        int activeEmits = 0;
        int allEmits = 0;
        final sub1 = repo.watchActiveProfile().listen((_) => activeEmits++);
        final sub2 = repo.watchAllProfiles().listen((_) => allEmits++);

        fakeDb.failRate = 1.0;

        Object? error;
        try {
          await repo.updateProfile('A', (p) => p.copyWith(
            partyPurse: p.partyPurse.modifyDenomination('gp', 50, replicaId: replicaId),
          ));
        } catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(repo.getProfileSync('A')?.partyPurse.getBalance('gp'), equals(100));
        expect(activeEmits, equals(0));
        expect(allEmits, equals(0));

        fakeDb.failRate = 0.0;
        final freshRepo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: StatefulHlcClock(replicaId: replicaId),
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        final reloaded = await freshRepo.loadAllProfiles();
        expect(reloaded.first.partyPurse.getBalance('gp'), equals(100));

        await sub1.cancel();
        await sub2.cancel();
        repo.dispose();
        freshRepo.dispose();
      });

      test('WF deleteProfile where index write fails: throws, campaign still there everywhere, streams silent', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(3), failRate: 0.0);
        final replicaId = ReplicaId('node_wf_del_idx');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        await repo.putProfile(_buildProfile('A', replicaId));
        await repo.putProfile(_buildProfile('B', replicaId));
        await repo.setActiveProfileId('A');

        int emits = 0;
        final sub = repo.watchAllProfiles().listen((_) => emits++);

        fakeDb.failIndexWrites = true;

        Object? error;
        try {
          await repo.deleteProfile('A');
        } catch (e) {
          error = e;
        }

        expect(error, isNotNull);
        expect(repo.allProfiles.map((p) => p.id).toSet(), equals({'A', 'B'}));
        expect(repo.activeProfileId, equals('A'));
        expect(emits, equals(0));

        fakeDb.failIndexWrites = false;
        final freshRepo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: StatefulHlcClock(replicaId: replicaId),
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        final reloaded = await freshRepo.loadAllProfiles();
        expect(reloaded.map((p) => p.id).toSet(), equals({'A', 'B'}));

        await sub.cancel();
        repo.dispose();
        freshRepo.dispose();
      });

      test('WF deleteProfile where only record delete fails: returns normally, campaign gone after reload', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(4), failRate: 0.0);
        final replicaId = ReplicaId('node_wf_del_rec');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        await repo.putProfile(_buildProfile('A', replicaId));
        await repo.putProfile(_buildProfile('B', replicaId));

        fakeDb.failRecordDeletes = true;

        // Call returns normally because index was already written without A
        await repo.deleteProfile('A');

        expect(repo.allProfiles.map((p) => p.id).toList(), equals(['B']));

        fakeDb.failRecordDeletes = false;
        final freshRepo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: StatefulHlcClock(replicaId: replicaId),
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        final reloaded = await freshRepo.loadAllProfiles();
        expect(reloaded.map((p) => p.id).toList(), equals(['B']));

        repo.dispose();
        freshRepo.dispose();
      });
    });

    // 4. Rollback ordering
    group('4. Rollback Ordering', () {
      test('A write fails while B is queued behind it (B new id): stored index lists B and not A, reload matches cache', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(5), failRate: 0.0);
        final replicaId = ReplicaId('node_rollback_order');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        await repo.loadAllProfiles();

        // Configure next put for A to fail specifically
        fakeDb.failKeys.add('${LocalCampaignRepository.profileKeyPrefix}A');
        final fA = repo.putProfile(_buildProfile('A', replicaId));

        // Queue B behind A immediately (B will succeed)
        final fB = repo.putProfile(_buildProfile('B', replicaId));

        Object? errA;
        try {
          await fA;
        } catch (e) {
          errA = e;
        }
        await fB;

        expect(errA, isNotNull);
        expect(repo.allProfiles.map((p) => p.id).toList(), equals(['B']));

        // Check persistent store index
        final indexOnDisk = fakeDb.get(
          AppDatabaseService.boxCampaignProfiles,
          LocalCampaignRepository.profileIndexKey,
        ) as List?;
        expect(indexOnDisk, equals(['B']));

        final freshRepo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: StatefulHlcClock(replicaId: replicaId),
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        final reloaded = await freshRepo.loadAllProfiles();
        expect(reloaded.map((p) => p.id).toList(), equals(['B']));

        repo.dispose();
        freshRepo.dispose();
      });
    });

    // 5. Callers
    group('5. Caller Failure Tests', () {
      test('Orchestrator inbound apply: failed write is not recorded as applied, next real change applies', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(6), failRate: 0.0);
        final replicaId = ReplicaId('me');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        final profile = _buildProfile('c1', replicaId, gp: 100);
        await repo.putProfile(profile);
        await repo.setActiveProfileId('c1');

        final transport = h.MockTransportPort();
        final clockSync = ClockSyncService(
          networkTimePort: h.MockNetworkTimePort(networkTimeMs: 1700000000500),
          localTimeProvider: () => 1700000000000,
        );
        final reconciler = RoomStateReconciliationService();
        final orchestrator = RoomSyncOrchestrator(
          replicaId: replicaId,
          transportPort: transport,
          campaignRepo: repo,
          payloadMapper: const RoomSyncPayloadMapper(),
          reconciliationService: reconciler,
          clockSyncService: clockSync,
          clock: clock,
          isHost: false,
        );
        orchestrator.startSynchronization();

        final deadLetters = <SyncErrorEvent>[];
        final sub = orchestrator.deadLetterStream.listen((evt) => deadLetters.add(evt));

        // Inbound purse delta from peer
        String purseDelta(int delta, int seq) => jsonEncode({
          'type': 'crdt_purse_delta',
          'origin_node_id': 'peer1',
          'origin_seq': seq,
          'campaign_id': 'c1',
          'payload': const PartyPurse.empty()
              .modifyDenomination('gp', delta, replicaId: ReplicaId('peer1'))
              .toMap(),
          'timestamp': 1700000000000 + seq,
        });

        // 1. Inbound apply fails because disk writes fail
        fakeDb.failRate = 1.0;
        try {
          await orchestrator.handleIncomingPayload(purseDelta(50, 1));
        } catch (_) {}

        expect(deadLetters, isNotEmpty);
        expect(repo.getProfileSync('c1')?.partyPurse.getBalance('gp'), equals(100));

        // 2. Next real change applies successfully when writes recover
        fakeDb.failRate = 0.0;
        await orchestrator.handleIncomingPayload(purseDelta(75, 2));

        expect(repo.getProfileSync('c1')?.partyPurse.getBalance('gp'), equals(175));

        await sub.cancel();
        orchestrator.stopSynchronization();
        repo.dispose();
      });

      test('DmBackupService full system restore: failed profile is reported and returns false', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(7), failRate: 0.0);
        final replicaId = ReplicaId('node_backup');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );

        sl.reset();
        sl.registerSingleton<ReplicaId>(replicaId);
        sl.registerSingleton<StatefulHlcClock>(clock);
        sl.registerSingleton<ICampaignRepository>(repo);

        final backupService = DmBackupService();

        final snapshotJson = jsonEncode({
          'schemaVersion': 2,
          'exportTimestamp': DateTime.now().toUtc().toIso8601String(),
          'application': 'DangerouslyNerdy5eToolkit',
          'exportType': 'fullSystemSnapshot',
          'campaignProfiles': [
            CampaignProfileDto.fromDomain(_buildProfile('c1', replicaId, gp: 100)).toMap(),
            CampaignProfileDto.fromDomain(_buildProfile('c2', replicaId, gp: 200)).toMap(),
          ],
        });

        // Disk writes fail
        fakeDb.failRate = 1.0;
        final result = await backupService.restoreFullSystemSnapshot(snapshotJson);

        expect(result, isFalse);

        repo.dispose();
      });

      test('Reload index rewrite failure: logs non-fatal and still returns profiles', () async {
        final fakeDb = _RandomDelayedFailingDbService(rng: Random(8), failRate: 0.0);
        final replicaId = ReplicaId('node_reload_rewrite');
        final clock = StatefulHlcClock(replicaId: replicaId);
        final repo = LocalCampaignRepository(
          replicaId: replicaId,
          clock: clock,
          db: fakeDb,
          characterRepo: LocalCharacterRepository(db: fakeDb),
        );
        await repo.putProfile(_buildProfile('c1', replicaId, gp: 100));

        // Fail index write during reload
        fakeDb.failIndexWrites = true;

        // loadAllProfiles should still succeed because read succeeded and cache is right
        final profiles = await repo.loadAllProfiles();
        expect(profiles, isNotEmpty);
        expect(profiles.first.id, equals('c1'));
        expect(profiles.first.partyPurse.getBalance('gp'), equals(100));

        repo.dispose();
      });
    });
  });
}

extension on LocalCampaignRepository {
  CampaignProfile? getProfileSync(String id) {
    return allProfiles.where((p) => p.id == id).firstOrNull;
  }
}
