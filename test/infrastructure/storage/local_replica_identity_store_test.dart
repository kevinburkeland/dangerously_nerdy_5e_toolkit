import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/pn_counter.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
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
import 'package:dangerously_nerdy_5e_toolkit/application/services/party_room_service.dart'
    as app_party;
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/inventory_transaction_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/loot_models.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/ports/i_network_time_port.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cold Iron Birdcage: Replica Identity Hardening Suite (Pass 1.3)', () {
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

    test('1. One application bootstrap creates one ReplicaId', () async {
      await initServiceLocator();

      expect(sl.isRegistered<ReplicaId>(), isTrue);
      final replica = sl<ReplicaId>();
      expect(replica.value, isNotEmpty);
      expect(replica.value.toLowerCase(), isNot(equals('local')));
      // UUID format validation (8-4-4-4-12)
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(uuidRegex.hasMatch(replica.value), isTrue);
    });

    test(
        '2. All services constructed during that bootstrap receive exactly that same runtime ReplicaId',
        () async {
      await initServiceLocator();
      final authoritativeReplica = sl<ReplicaId>();
      final expectedNodeId = authoritativeReplica.value;

      final combatService = sl<CombatEncounterService>();
      expect(combatService.localNodeId, equals(expectedNodeId));

      final partyService = sl<PartyRoomService>();
      expect(partyService.localNodeId, equals(expectedNodeId));
      expect(partyService.replicaId, equals(authoritativeReplica));

      final dmController = DmDashboardController(
        replicaId: authoritativeReplica,
      );
      expect(dmController.nodeId, equals(expectedNodeId));
      expect(dmController.replicaId, equals(authoritativeReplica));
      expect(dmController.combatEncounterService.localNodeId, equals(expectedNodeId));

      const testChar = Character(
        id: EntityId(slug: 'hero1', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference.empty(
            slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
      );
      final charController = CharacterSheetController(
        character: testChar,
        replicaId: authoritativeReplica,
      );
      expect(charController.nodeId, equals(expectedNodeId));
      expect(charController.replicaId, equals(authoritativeReplica));
    });

    test(
        '3. A second independent bootstrap/runtime sharing the same durable storage receives a DIFFERENT ReplicaId',
        () async {
      await initServiceLocator();
      final runtime1 = sl<ReplicaId>();

      // Reset service locator for second application bootstrap/tab (same storage)
      sl.reset();
      await initServiceLocator();
      final runtime2 = sl<ReplicaId>();

      expect(runtime1.value, isNotEmpty);
      expect(runtime2.value, isNotEmpty);
      expect(runtime1, isNot(equals(runtime2)));
      expect(runtime1.value, isNot(equals(runtime2.value)));
    });

    test('4. Historical persisted state remains readable', () {
      final legacyMap = {
        'positive': {'local': 100, 'node_old': 50},
        'negative': {'local': 20, 'node_old': 10},
      };
      final counter = PnCounter.fromMap(legacyMap);
      expect(counter.positive['local'], equals(100));
      expect(counter.positive['node_old'], equals(50));
      expect(counter.negative['local'], equals(20));
      expect(counter.negative['node_old'], equals(10));
      expect(counter.value, equals(120)); // (100 + 50) - (20 + 10) = 120
    });

    test(
        '5. Existing old dn_replica_id metadata does not become the active writer ID after migration',
        () async {
      final db = AppDatabaseService.instance;
      // Pre-seed historical dn_replica_id in database box
      await db.put(
        AppDatabaseService.boxMetadata,
        AppDatabaseService.keyReplicaId,
        'old_historical_persisted_uuid_9999',
      );

      final store = LocalReplicaIdentityStore(db: db);
      final runtimeReplica = await store.getOrCreateReplicaId();

      // Invariant: The active runtime writer ID MUST NOT equal the historical persisted device ID
      expect(runtimeReplica.value, isNot(equals('old_historical_persisted_uuid_9999')));
      expect(runtimeReplica.value, isNotEmpty);

      // Verify historical device ID is safely readable as durable metadata if needed
      expect(
        store.deprecatedPersistedDeviceId,
        equals('old_historical_persisted_uuid_9999'),
      );
    });

    test('6. No active mutation produces a "local" component', () {
      expect(() => ReplicaId(''), throwsArgumentError);
      expect(() => ReplicaId('   '), throwsArgumentError);
      expect(() => ReplicaId('local'), throwsArgumentError);
      expect(() => ReplicaId('LOCAL'), throwsArgumentError);
      expect(() => ReplicaId(' Local '), throwsArgumentError);

      final runtimeId = ReplicaId('active_writer_1');
      final counter = PnCounter.withInitialValue(10, replicaId: runtimeId);
      final next = counter.increment(5, replicaId: runtimeId);

      expect(next.positive.containsKey('local'), isFalse);
      expect(next.negative.containsKey('local'), isFalse);
      expect(next.positive[runtimeId.value], equals(15));
    });

    test('7. Sequential mutations by one runtime accumulate in that runtime component',
        () {
      final runtimeId = ReplicaId('writer_seq');
      var counter = PnCounter.withInitialValue(10, replicaId: runtimeId);
      counter = counter.increment(5, replicaId: runtimeId);
      counter = counter.increment(7, replicaId: runtimeId);
      counter = counter.decrement(3, replicaId: runtimeId);

      expect(counter.positive[runtimeId.value], equals(22)); // 10 + 5 + 7
      expect(counter.negative[runtimeId.value], equals(3));
      expect(counter.value, equals(19));
    });

    test('8. Independent mutations by two runtime IDs survive CvRDT merge',
        () {
      final base = PnCounter.fromMap({
        'positive': {'historical_node': 10},
        'negative': {},
      });

      final replicaA = ReplicaId('runtime_tab_A');
      final replicaB = ReplicaId('runtime_tab_B');

      final stateA = base.increment(5, replicaId: replicaA);
      final stateB = base.increment(8, replicaId: replicaB);

      final merged = stateA.merge(stateB);

      expect(replicaA, isNot(equals(replicaB)));
      expect(merged.value, equals(23));
      expect(merged.positive[replicaA.value], equals(5));
      expect(merged.positive[replicaB.value], equals(8));
      expect(merged.positive['historical_node'], equals(10));

      // Contrast with failure-shape if writer IDs had collided:
      // If both runtimes had shared writer ID 'shared_id', stateA would have
      // positive['shared_id'] = 5, stateB would have positive['shared_id'] = 8,
      // and max(5, 8) = 8, resulting in merged value 18 (losing 5).
      final sharedId = ReplicaId('shared_id');
      final stateSharedA = base.increment(5, replicaId: sharedId);
      final stateSharedB = base.increment(8, replicaId: sharedId);
      final mergedCollided = stateSharedA.merge(stateSharedB);
      expect(mergedCollided.value, equals(18)); // Corrupt / lost update!
    });

    test(
        '9. PartyRoomService.removeCharacterFromRoster attributes mutations to injected replica ID',
        () async {
      final authoritativeId = ReplicaId('dm_authoritative_node_99');
      final partyService = PartyRoomService(
        replicaId: authoritativeId,
        clock: StatefulHlcClock(replicaId: authoritativeId),
      );

      const roomCode = 'ROOM99';
      await partyService.ensureRoomExists(
        roomCode: roomCode,
        campaignName: 'Test Campaign',
      );

      // Add a member with personal coins
      await partyService.updateMemberPurse(
        roomCode: roomCode,
        characterName: 'Valeros',
        newPurse: PartyPurse(gp: 75, sp: 20),
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

    test('10. Migration-created profiles use authoritative replica ID, not room code',
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

    test(
        '11. Replicated-state writers fail loudly when DI is absent and no replica ID is provided',
        () {
      sl.reset();
      CampaignProfileService.resetForTesting();
      expect(sl.isRegistered<ReplicaId>(), isFalse);

      const testChar = Character(
        id: EntityId(slug: 'hero1', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference.empty(
            slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: CharacterProgression(classes: []),
        baseScores: AbilityScores.standardArray(),
      );

      // Services with optional or fallback replicaId throw StateError when DI is absent
      // PartyRoomService (persistence) fails loudly
      expect(() => PartyRoomService(), throwsStateError);
      expect(() => PartyRoomService.newInstance(), throwsStateError);

      // CampaignProfileService fails loudly
      expect(() => CampaignProfileService().createProfile(name: 'Camp'), throwsStateError);

      // InventoryTransactionService currency transfer fails loudly
      final container = LootContainer(
        containerId: 'cont_1',
        name: 'Chest',
        purse: PartyPurse(gp: 50),
        items: [
          InventoryItemInstance(
            instanceId: 'item_1',
            itemRef: const EntityReference.empty(
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
          currency: PartyPurse(gp: 10),
        ),
        throwsStateError,
      );
    });

    test(
        '12. Source tree verification: No production CRDT-writing callsite uses hard-coded identities',
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

    test(
        '13. Replicated-state writers consume authoritative ReplicaId via type-safe constructors/methods',
        () {
      final authoritativeId = ReplicaId('dm_prod_replica_99');
      sl.registerSingleton<ReplicaId>(authoritativeId);
      final sharedClock = StatefulHlcClock(replicaId: authoritativeId);
      sl.registerSingleton<StatefulHlcClock>(sharedClock);

      // DmDashboardController
      final dmController = DmDashboardController(replicaId: authoritativeId);
      expect(dmController.replicaId, equals(authoritativeId));
      expect(dmController.nodeId, equals(authoritativeId.value));
      expect(dmController.combatEncounterService.replicaId, equals(authoritativeId));
      expect(dmController.combatEncounterService.localNodeId, equals(authoritativeId.value));

      // RoomSyncOrchestrator
      final orchestrator = RoomSyncOrchestrator(
        replicaId: authoritativeId,
        campaignRepo: _TestMockCampaignRepo(),
        reconciliationService: RoomStateReconciliationService(
          networkTimeProvider: () => 1000,
        ),
        clockSyncService: ClockSyncService(
          networkTimePort: _TestMockTimePort(),
        ),
        transportPort: _TestMockTransportPort(),
        payloadMapper: const RoomSyncPayloadMapper(),
      );
      expect(orchestrator.replicaId, equals(authoritativeId));
      expect(orchestrator.localNodeId, equals(authoritativeId.value));

      // Application PartyRoomService
      final appPartyService = app_party.PartyRoomService(
        replicaId: authoritativeId,
        clock: sharedClock,
      );
      expect(appPartyService.replicaId, equals(authoritativeId));
      expect(appPartyService.localNodeId, equals(authoritativeId.value));

      // Persistence PartyRoomService
      final persistencePartyService = PartyRoomService(replicaId: authoritativeId);
      expect(persistencePartyService.replicaId, equals(authoritativeId));
      expect(persistencePartyService.localNodeId, equals(authoritativeId.value));

      // InventoryTransactionService
      final testChar = Character(
        id: const EntityId(slug: 'hero_inv_1', ruleset: RulesetVersion.v2024),
        name: 'Hero Inv',
        speciesRef: const EntityReference.empty(
            slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: const CharacterProgression(classes: []),
        baseScores: const AbilityScores.standardArray(),
        purse: PartyPurse(gp: 10),
      );
      final container = LootContainer(
        containerId: 'chest_inv_1',
        name: 'Chest Inv',
        purse: PartyPurse(gp: 50),
        items: [
          InventoryItemInstance(
            instanceId: 'item_inv_1',
            itemRef: const EntityReference.empty(
              slug: 'potion',
              refType: EntityType.equipment,
              displayName: 'Potion',
            ),
          ),
        ],
      );

      final transferResult = InventoryTransactionService.transferFromContainerToCharacter(
        sourceContainer: container,
        destinationCharacter: testChar,
        instanceId: 'item_inv_1',
        currency: PartyPurse(gp: 15),
        replicaId: authoritativeId,
      );
      expect(transferResult.updatedCharacter.purse.gp, equals(25));
      expect(transferResult.updatedContainer.purse.gp, equals(35));
    });

    test(
        '14. CombatEncounterService requires ReplicaId and stamps HLC timestamps containing replicaId.value',
        () async {
      final authoritativeId = ReplicaId('combat_writer_replica_77');
      final mockRepo = _TestMockCampaignRepo();
      final combatService = CombatEncounterService(
        characterRepo: _TestMockCharRepo(),
        campaignRepo: mockRepo,
        replicaId: authoritativeId,
        combatResolver: const Dnd5eCombatResolver(),
        clock: StatefulHlcClock(replicaId: authoritativeId),
      );

      expect(combatService.replicaId, equals(authoritativeId));
      expect(combatService.localNodeId, equals(authoritativeId.value));

      final baseProfile = CampaignProfile.defaultProfile(nodeId: authoritativeId.value);
      final updatedProfile = await combatService.addMinion(
        profile: baseProfile,
        minion: MinionInstance(
          id: 'minion_1',
          name: 'Skeleton',
          size: EntitySize.medium,
          maxHp: 13,
          currentHp: 13,
        ),
      );

      // Verify that HLC timestamp emitted on activeMinions has nodeId == authoritativeId.value
      expect(updatedProfile.roomState.activeMinions.items.length, equals(1));
      final reg = updatedProfile.roomState.activeMinions.items.values.first;
      expect(reg.timestamp.nodeId, equals(authoritativeId.value));
    });

    test(
        '15. Separately constructed production mutation services share the exact same injected ReplicaId without secret discovery',
        () {
      final authoritativeId = ReplicaId('shared_runtime_replica_123');
      final sharedClock = StatefulHlcClock(replicaId: authoritativeId);

      final orch = RoomSyncOrchestrator(
        replicaId: authoritativeId,
        campaignRepo: _TestMockCampaignRepo(),
        reconciliationService: RoomStateReconciliationService(
          networkTimeProvider: () => 1000,
        ),
        clockSyncService: ClockSyncService(
          networkTimePort: _TestMockTimePort(),
        ),
        transportPort: _TestMockTransportPort(),
        payloadMapper: const RoomSyncPayloadMapper(),
      );

      final combat = CombatEncounterService(
        characterRepo: _TestMockCharRepo(),
        campaignRepo: _TestMockCampaignRepo(),
        replicaId: authoritativeId,
        combatResolver: const Dnd5eCombatResolver(),
        clock: sharedClock,
      );

      final party = PartyRoomService(
        replicaId: authoritativeId,
        clock: sharedClock,
      );

      expect(orch.replicaId, equals(authoritativeId));
      expect(combat.replicaId, equals(authoritativeId));
      expect(party.replicaId, equals(authoritativeId));
    });

    test(
        '16. InventoryTransactionService currency transfers require ReplicaId in both directions',
        () {
      final testChar = Character(
        id: const EntityId(slug: 'hero_both_dir', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: const EntityReference.empty(
            slug: 'human', refType: EntityType.species, displayName: 'Human'),
        progression: const CharacterProgression(classes: []),
        baseScores: const AbilityScores.standardArray(),
        purse: PartyPurse(gp: 50),
        inventory: [
          InventoryItemInstance(
            instanceId: 'char_item_1',
            itemRef: const EntityReference.empty(
              slug: 'potion',
              refType: EntityType.equipment,
              displayName: 'Potion',
            ),
          ),
        ],
      );

      final container = LootContainer(
        containerId: 'chest_both_dir',
        name: 'Chest',
        purse: PartyPurse(gp: 50),
        items: [
          InventoryItemInstance(
            instanceId: 'chest_item_1',
            itemRef: const EntityReference.empty(
              slug: 'gem',
              refType: EntityType.equipment,
              displayName: 'Gem',
            ),
          ),
        ],
      );

      // Container to character with currency and null replicaId -> StateError
      expect(
        () => InventoryTransactionService.transferFromContainerToCharacter(
          sourceContainer: container,
          destinationCharacter: testChar,
          instanceId: 'chest_item_1',
          currency: PartyPurse(gp: 10),
          replicaId: null,
        ),
        throwsStateError,
      );

      // Character to container with currency and null replicaId -> StateError
      expect(
        () => InventoryTransactionService.transferFromCharacterToContainer(
          sourceCharacter: testChar,
          destinationContainer: container,
          instanceId: 'char_item_1',
          currency: PartyPurse(gp: 10),
          replicaId: null,
        ),
        throwsStateError,
      );
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

class _TestMockCharRepo implements ICharacterRepository<Character> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestMockCampaignRepo implements ICampaignRepository {
  CampaignProfile? savedProfile;

  @override
  CampaignProfile? get activeProfile => savedProfile;

  @override
  String? get activeProfileId => savedProfile?.id;

  @override
  List<CampaignProfile> get allProfiles =>
      savedProfile != null ? [savedProfile!] : [];

  @override
  Stream<CampaignProfile?> watchActiveProfile() => const Stream.empty();

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => const Stream.empty();

  @override
  Future<CampaignProfile?> getActiveProfile() async => savedProfile;

  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      savedProfile?.id == id ? savedProfile : null;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async =>
      savedProfile != null ? [savedProfile!] : [];

  @override
  Future<void> saveProfile(CampaignProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Future<void> deleteProfile(String profileId) async {
    if (savedProfile?.id == profileId) savedProfile = null;
  }
}
