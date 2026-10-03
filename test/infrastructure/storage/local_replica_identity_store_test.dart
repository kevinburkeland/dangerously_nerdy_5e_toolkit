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
import 'dart:io';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/campaign_profile_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart'
    as app_party;
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/inventory_transaction_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/loot_models.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Birdcage: Replica Identity Hardening Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppDatabaseService.instance.resetForTesting();
      CampaignProfileService.resetForTesting();
      sl.reset();
    });

    tearDown(() async {
      CampaignProfileService.resetForTesting();
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

    test('6. Migration-created profiles use authoritative replica ID, not room code',
        () async {
      final authoritativeId = ReplicaId('dm_migration_node_77');
      sl.registerSingleton<ReplicaId>(authoritativeId);

      final registry = CampaignRegistryService();
      await registry.saveMembership(
        CampaignMembership(
          roomCode: 'ROOM_MIGRATION',
          campaignName: 'Migrated Campaign',
          role: CampaignRole.host,
          hostKey: 'secret_key',
          characterId: 'dm',
          lastPlayed: DateTime.now(),
        ),
      );

      final service = CampaignProfileService(replicaId: authoritativeId);
      final profiles = await service.loadAllProfiles();
      final migrated = profiles.firstWhere(
        (p) => p.roomState.roomCode == 'ROOM_MIGRATION',
      );

      // Invariant: MUST use authoritative replica ID, NEVER the room code
      expect(migrated.notesRegister.timestamp.nodeId, equals(authoritativeId.value));
      expect(migrated.notesRegister.timestamp.nodeId, isNot(equals('ROOM_MIGRATION')));
    });

    test('7. DmDashboardController and fallback collaborators cannot receive different replica IDs',
        () {
      final explicitId = ReplicaId('dm_explicit_node_88');
      final controller = DmDashboardController(replicaId: explicitId);

      expect(controller.nodeId, equals('dm_explicit_node_88'));
      expect(controller.combatEncounterService.localNodeId, equals('dm_explicit_node_88'));

      final defaultProfile = controller.activeProfile;
      if (defaultProfile != null) {
        expect(defaultProfile.notesRegister.timestamp.nodeId, equals('dm_explicit_node_88'));
        expect(defaultProfile.notesRegister.timestamp.nodeId, isNot(equals('dm_dashboard')));
      }
    });

    test('8. Replicated-state writers fail loudly and cannot fabricate an identity when DI is absent',
        () {
      sl.reset();
      CampaignProfileService.resetForTesting();
      expect(sl.isRegistered<ReplicaId>(), isFalse);

      const testChar = Character(
        id: EntityId(slug: 'hero1', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference(
            slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
      );

      // CharacterSheetController fails loudly
      expect(() => CharacterSheetController(character: testChar), throwsStateError);

      // DmDashboardController fails loudly
      expect(() => DmDashboardController(), throwsStateError);

      // PartyRoomService (persistence) fails loudly
      expect(() => PartyRoomService(), throwsStateError);
      expect(() => PartyRoomService.newInstance(), throwsStateError);

      // PartyRoomService (application) fails loudly
      expect(() => app_party.PartyRoomService(), throwsStateError);

      // RoomSyncOrchestrator fails loudly
      expect(
        () => RoomSyncOrchestrator(
          campaignRepo: _TestMockCampaignRepo(),
          reconciliationService: RoomStateReconciliationService(
            networkTimeProvider: () => 1000,
          ),
          clockSyncService: ClockSyncService(
            networkTimePort: _TestMockTimePort(),
          ),
          transportPort: _TestMockTransportPort(),
        ),
        throwsStateError,
      );

      // CampaignProfileService fails loudly
      expect(() => CampaignProfileService().createProfile(name: 'Camp'), throwsStateError);

      // LocalCampaignRepository fails loudly
      expect(() => LocalCampaignRepository().loadAllProfiles(), throwsStateError);

      // InventoryTransactionService currency transfer fails loudly
      const container = LootContainer(
        containerId: 'cont_1',
        name: 'Chest',
        purse: PartyPurse(gp: 50),
        items: [
          InventoryItemInstance(
            instanceId: 'item_1',
            itemRef: EntityReference(
              slug: 'potion',
              refType: EntityType.equipment,
              displayName: 'Potion',
            ),
          ),
        ],
      );
      expect(
        () => InventoryTransactionService.transferFromContainerToCharacter(
          sourceContainer: container,
          destinationCharacter: testChar,
          instanceId: 'item_1',
          currency: const PartyPurse(gp: 10),
        ),
        throwsStateError,
      );
    });

    test('9. Source tree verification: No production CRDT-writing callsite uses hard-coded identities',
        () {
      final libDir = Directory('lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final forbiddenIdentities = [
        'dm_dashboard',
        'campaign_service',
        'local_repo',
        'inventory_transfer',
        'character_controller',
      ];

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        for (final forbidden in forbiddenIdentities) {
          final regex = RegExp("nodeId:\\s*['\"]$forbidden['\"]");
          expect(
            regex.hasMatch(content),
            isFalse,
            reason:
                'Found forbidden hard-coded replica identity "$forbidden" in ${file.path}',
          );
        }
      }
    });
  });
}

class _TestMockTimePort implements INetworkTimePort {
  @override
  Future<int> getNetworkTimeMs() async => 1000;
}

class _TestMockTransportPort implements IP2pTransportPort {
  @override
  TransportState currentState = TransportState.webRtc;

  @override
  Map<String, int> peerLastSeen = const {};

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => true;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> broadcastPayload(String jsonPayload) async {}

  @override
  Stream<String> watchIncomingPayloads() => const Stream.empty();

  @override
  Future<void> disconnect() async {}
}

class _TestMockCampaignRepo implements ICampaignRepository {
  @override
  CampaignProfile? get activeProfile => null;

  @override
  String? get activeProfileId => null;

  @override
  List<CampaignProfile> get allProfiles => [];

  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();

  @override
  Future<CampaignProfile?> getActiveProfile() async => null;

  @override
  Future<CampaignProfile?> getProfile(String id) async => null;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => [];

  @override
  Future<void> saveProfile(CampaignProfile profile) async {}

  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {}

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Future<void> deleteProfile(String profileId) async {}
}

