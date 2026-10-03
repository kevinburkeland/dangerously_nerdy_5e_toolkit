import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/pn_counter.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/storage/local_replica_identity_store.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/party_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/dm_dashboard_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Birdcage: Replica Identity Hardening Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppDatabaseService.instance.resetForTesting();
      sl.reset();
    });

    tearDown(() async {
      sl.reset();
    });

    test('1. Two independently initialized replicas receive different IDs',
        () async {
      final db = AppDatabaseService.instance;
      final store1 = LocalReplicaIdentityStore(db: db);
      final replica1 = await store1.getOrCreateReplicaId();

      // Simulate a distinct storage namespace / second independent replica
      await db.resetForTesting();
      final store2 = LocalReplicaIdentityStore(db: db);
      final replica2 = await store2.getOrCreateReplicaId();

      expect(replica1.value, isNotEmpty);
      expect(replica2.value, isNotEmpty);
      expect(replica1, isNot(equals(replica2)));
      expect(replica1.value, isNot(equals(replica2.value)));
      expect(replica1.value.toLowerCase(), isNot(equals('local')));
      expect(replica2.value.toLowerCase(), isNot(equals('local')));
    });

    test('2. Reloading the same local persistence/storage instance returns the same ID',
        () async {
      final db = AppDatabaseService.instance;
      final store = LocalReplicaIdentityStore(db: db);
      final originalReplica = await store.getOrCreateReplicaId();

      // Simulate application restart reading from existing persisted database box
      final reloadedStore = LocalReplicaIdentityStore(db: db);
      final reloadedReplica = await reloadedStore.getOrCreateReplicaId();

      expect(reloadedReplica, equals(originalReplica));
      expect(reloadedReplica.value, equals(originalReplica.value));

      // Also verify direct disk persistence key in metadata box
      final persisted = db.get(
        AppDatabaseService.boxMetadata,
        AppDatabaseService.keyReplicaId,
      );
      expect(persisted, equals(originalReplica.value));
    });

    test('3. CRDT mutation APIs cannot operate using an implicit or explicit shared "local" identity',
        () {
      // ReplicaId value object prevents 'local' and empty strings
      expect(() => ReplicaId(''), throwsArgumentError);
      expect(() => ReplicaId('   '), throwsArgumentError);
      expect(() => ReplicaId('local'), throwsArgumentError);
      expect(() => ReplicaId('LOCAL'), throwsArgumentError);
      expect(() => ReplicaId(' Local '), throwsArgumentError);

      // PnCounter mutations reject 'local'
      final counter = PnCounter.withInitialValue(10, nodeId: 'valid_node');
      expect(
        () => counter.increment(5, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => counter.decrement(5, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => PnCounter.withInitialValue(10, nodeId: 'local'),
        throwsArgumentError,
      );

      // PartyPurse mutations reject 'local'
      const purse = PartyPurse(gp: 100);
      expect(
        () => purse.depositCoins(gp: 50, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.withdrawCoins(gp: 50, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.modifyCoin('gp', 50, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.setCoins(gp: 50, nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.add(const PartyPurse(gp: 10), nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.deduct(const PartyPurse(gp: 10), nodeId: 'local'),
        throwsArgumentError,
      );
      expect(
        () => purse.deductGpEquivalent(10, nodeId: 'local'),
        throwsArgumentError,
      );

      // Compatibility: historical persisted 'local' keys are preserved without error
      final legacyMap = {
        'positive': {'local': 100, 'node_a': 50},
        'negative': {'local': 20, 'node_b': 10},
      };
      final deserialized = PnCounter.fromMap(legacyMap);
      expect(deserialized.positive['local'], equals(100));
      expect(deserialized.negative['local'], equals(20));
      expect(deserialized.value, equals(120)); // (100+50) - (20+10) = 120
    });

    test('4. PartyRoomService.removeCharacterFromRoster attributes mutations to injected replica ID',
        () async {
      final authoritativeId = ReplicaId('dm_authoritative_node_99');
      final partyService = PartyRoomService(replicaId: authoritativeId);

      const roomCode = 'ROOM99';
      await partyService.ensureRoomExists(
        roomCode: roomCode,
        campaignName: 'Test Campaign',
      );

      // Add a member with personal coins
      await partyService.updateMemberPurse(
        roomCode: roomCode,
        characterName: 'Valeros',
        newPurse: const PartyPurse(gp: 75, sp: 20),
        performedBy: 'DM',
      );

      // Remove character and sweep purse into party treasury
      await partyService.removeCharacterFromRoster(
        roomCode: roomCode,
        characterName: 'Valeros',
        playerName: 'DM',
      );

      final session = await partyService.streamSession(roomCode).first;
      expect(session, isNotNull);
      final partyPurse = session!.partyPurse;
      expect(partyPurse.gp, equals(75));
      expect(partyPurse.sp, equals(20));

      // Invariant: The GP and SP increment counters MUST be attributed to the injected replica ID, NEVER 'local'
      expect(partyPurse.gpCounter.positive.containsKey('local'), isFalse);
      expect(
        partyPurse.gpCounter.positive[authoritativeId.value],
        equals(75),
      );
      expect(
        partyPurse.spCounter.positive[authoritativeId.value],
        equals(20),
      );
    });

    test('5. Subsystems receiving replica identity through DI receive the exact same authoritative value',
        () async {
      await initServiceLocator();

      expect(sl.isRegistered<ReplicaId>(), isTrue);
      final authoritativeReplica = sl<ReplicaId>();
      final expectedNodeId = authoritativeReplica.value;
      expect(expectedNodeId, isNotEmpty);
      expect(expectedNodeId.toLowerCase(), isNot(equals('local')));

      // CombatEncounterService
      final combatService = sl<CombatEncounterService>();
      expect(combatService.localNodeId, equals(expectedNodeId));

      // PartyRoomService
      final partyService = sl<PartyRoomService>();
      expect(partyService.localNodeId, equals(expectedNodeId));

      // DmDashboardController
      final dmController = DmDashboardController();
      expect(dmController.nodeId, equals(expectedNodeId));
      expect(dmController.combatEncounterService.localNodeId, equals(expectedNodeId));

      // CharacterSheetController
      const testChar = Character(
        id: EntityId(slug: 'hero1', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference(
            slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
      );
      final charController = CharacterSheetController(character: testChar);
      expect(charController.nodeId, equals(expectedNodeId));
      expect(charController.replicaId, equals(authoritativeReplica));
    });
  });
}
