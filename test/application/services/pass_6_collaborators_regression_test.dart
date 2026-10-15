import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart' hide Character, CharacterResourcePool, EntityType;
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_sync_orchestrator.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/clock_sync_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/room_state_reconciliation_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/room_sync_payload_mapper.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_validation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';

class _MockP2pTransport implements IP2pTransportPort {
  final List<String> broadcastedPayloads = [];
  final StreamController<String> _incomingController = StreamController<String>.broadcast();
  void Function(String)? onBroadcast;

  @override
  TransportState get currentState => TransportState.webRtc;

  @override
  Map<String, int> get peerLastSeen => const {};

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    broadcastedPayloads.add(jsonPayload);
    onBroadcast?.call(jsonPayload);
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingController.stream;

  void emitIncoming(String payload) => _incomingController.add(payload);

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {}

  @override
  Future<void> disconnect() async {
    await _incomingController.close();
  }

  @override
  Duration get heartbeatTtl => const Duration(seconds: 15);

  @override
  Future<void> prepareSession() async {}

  @override
  Future<bool> probeViability(String roomCode, String localNodeId) async => false;
}

class _MockCampaignRepository implements ICampaignRepository {
  CampaignProfile? _activeProfile;
  final StreamController<CampaignProfile?> _controller = StreamController<CampaignProfile?>.broadcast();

  @override
  List<CampaignProfile> get allProfiles => _activeProfile != null ? [_activeProfile!] : [];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile> updateProfile(String id, CampaignProfile Function(CampaignProfile p) transform) async {
    final updated = transform(_activeProfile!);
    _activeProfile = updated;
    return updated;
  }

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  set activeProfile(CampaignProfile? p) {
    _activeProfile = p;
    _controller.add(p);
  }

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  Future<void> deleteProfile(String id) async {
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _controller.add(null);
    }
  }

  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    _activeProfile = profile;
    _controller.add(profile);
  }

  Future<List<CampaignProfile>> getAllProfiles() async =>
      _activeProfile != null ? [_activeProfile!] : [];

  @override
  Future<CampaignProfile?> getProfile(String id) async =>
      _activeProfile?.id == id ? _activeProfile : null;

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    _activeProfile = profile;
    _controller.add(profile);
  }

  @override
  Future<void> setActiveProfileId(String? id) async {}

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _controller.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() =>
      _controller.stream.map((p) => p != null ? [p] : []);

  void dispose() {
    _controller.close();
  }
}

class _MockNetworkTimePort implements INetworkTimePort {
  Future<int> fetchNetworkTimeMs() async => 1000;

  @override
  Future<int> getNetworkTimeMs() async => 1000;
}

class _CustomCasterClass extends DomainEntity {
  @override
  final EntityId id;
  @override
  final String name;
  @override
  final Map<String, dynamic> customProperties;

  const _CustomCasterClass({
    required this.id,
    required this.name,
    required this.customProperties,
  });

  @override
  EntityType get entityType => EntityType.classDefinition;

  @override
  Map<String, dynamic> toMap() => {
    'id': id.toMap(),
    'name': name,
    'customProperties': customProperties,
  };
}

void main() {
  setUp(() {
    installRulesetCatalog();
  });

  group('Pass 6: Committed Collaborator Regression Tests', () {
    test('N1: RoomSyncOrchestrator with wired payloadMapper applies inbound purse deltas and broadcasts non-empty payloads', () async {
      final transport = _MockP2pTransport();
      final clockSync = ClockSyncService(
        networkTimePort: _MockNetworkTimePort(),
        localTimeProvider: () => 1000,
      );
      final reconciliation = RoomStateReconciliationService(
        networkTimeProvider: () => clockSync.currentNetworkTimeMs,
      );
      final repo = _MockCampaignRepository();
      final clock = StatefulHlcClock(replicaId: ReplicaId('node-1'));
      final initialProfile = CampaignProfile.defaultProfile(
        id: 'camp-1',
        name: 'Campaign 1',
        clock: clock,
        nodeId: 'node-1',
      );
      repo.activeProfile = initialProfile;

      int deadLetters = 0;
      final orchestrator = RoomSyncOrchestrator(
        replicaId: ReplicaId('node-1'),
        transportPort: transport,
        campaignRepo: repo,
        reconciliationService: reconciliation,
        clockSyncService: clockSync,
        clock: clock,
        payloadMapper: const RoomSyncPayloadMapper(),
      );
      orchestrator.deadLetterStream.listen((_) => deadLetters++);

      int broadcasts = 0;
      int emptyBroadcasts = 0;
      transport.onBroadcast = (payload) {
        broadcasts++;
        if (payload.isEmpty) emptyBroadcasts++;
      };

      orchestrator.startSynchronization();

      // Inbound purse delta (100 gp)
      final incomingPurse = PartyPurse(
        denominationCounters: {
          'gp': PnCounter(
            positive: {'node-2': 100},
          ),
        },
      );
      final inboundPayload = const RoomSyncPayloadMapper().serializePurseDelta(
        campaignId: 'camp-1',
        purse: incomingPurse,
        originNodeId: 'node-2',
        originSeq: 1,
        timestamp: 1000,
      );
      transport.emitIncoming(inboundPayload);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final updatedProfile = await repo.getProfile('camp-1');
      final inboundGp = updatedProfile?.partyPurse.getBalance('gp') ?? 0;

      // Trigger outbound broadcast
      await orchestrator.handleLocalProfileChange(initialProfile.copyWith(
        notesMarkdown: 'new note',
        notesTimestamp: clock.nextTimestamp(),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      orchestrator.stopSynchronization();
      repo.dispose();

      expect(inboundGp, equals(100));
      expect(broadcasts, equals(1));
      expect(emptyBroadcasts, equals(0));
      expect(deadLetters, equals(0));
    });

    test('L1: RoomRoll.toFirestoreMap writes expireAt as Timestamp', () {
      final roll = RoomRoll(
        id: 'r1',
        roomCode: 'room1',
        playerName: 'User',
        formulaString: '1d20',
        total: 20,
        individualRolls: const [20],
        isCrit: true,
        isFumble: false,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      final fsMap = roll.toFirestoreMap(Timestamp.fromDate);
      expect(fsMap['expireAt'], isA<Timestamp>());
      expect(fsMap['timestamp'], isA<Timestamp>());

      final jsonMap = roll.toJsonMap();
      expect(jsonMap['expireAt'], isA<int>());
      expect(jsonMap['timestamp'], isA<int>());
    });

    test('L2: Spell.fromMap extracts riders via installed catalog', () {
      const spellDesc = 'Target must make a DC 13 Dexterity saving throw or be knocked prone.';
      final spell = Spell.fromMap(const {
        'name': 'Trip Spell',
        'descriptionMarkdown': spellDesc,
      });
      expect(spell.riders.length, equals(1));
      expect((spell.riders.first as ConditionRider).condition.toString(), contains('prone'));
    });

    test('L3: feat prerequisite checked via SrdFeatsLibrary without hard-coded fallback', () {
      SrdFeatsLibrary.addCustomFeat(const Feat(
        id: EntityId(slug: 'heavy-armor-master', ruleset: RulesetVersion.v2024),
        name: 'Heavy Armor Master',
        prerequisite: 'Strength 15+',
        descriptionMarkdown: 'Prerequisite: Strength 15+',
      ));

      final draft = CharacterDraft(
        characterName: 'Draft Hero',
        baseScores: const AbilityScores(strength: 12),
        originFeats: [
          const EntityReference<DomainEntity>.empty(
            refType: EntityType.feat,
            slug: 'heavy-armor-master',
            displayName: 'Heavy Armor Master',
          ),
        ],
      );

      final issues = CharacterValidationEngine.validateDraft(draft);
      expect(issues.any((i) => i.code == 'feat_prereq_unmet'), isTrue);
    });

    test('S1: Character holding level-less spell reference resolves level via catalog immediately', () {
      const s1Char = Character(
        id: EntityId(slug: 's1-char', ruleset: RulesetVersion.v2024),
        name: 'S1 Char',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        allocatedSpells: {
          'spells': [
            EntityReference<Spell>.empty(
              refType: EntityType.spell,
              slug: 'fire-bolt',
              displayName: 'Fire Bolt',
            ),
          ],
        },
      );

      expect(s1Char.cantrips.length, equals(1));
      expect(s1Char.spellsKnown.length, equals(0));
    });

    test('H1: Telemetry and evaluation engine agree on Tough fighter max HP', () {
      for (final tough in [false, true]) {
        final h1Char = Character(
          id: EntityId(slug: 'h1-$tough', ruleset: RulesetVersion.v2024),
          name: 'Fighter',
          speciesRef: const EntityReference<DomainEntity>.empty(
            refType: EntityType.species,
            slug: 'human',
            displayName: 'Human',
          ),
          baseScores: const AbilityScores(constitution: 14), // mod +2
          resources: const CharacterResourcePool(
            vitals: EntityVitals(currentHp: 36, maxHp: 36),
          ),
          progression: const CharacterProgression(
            classes: [
              ClassLevelProgression(
                classRef: EntityReference<DomainEntity>.empty(
                  refType: EntityType.classDefinition,
                  slug: 'fighter',
                  displayName: 'Fighter',
                ),
                level: 4,
                hitDie: 'd10',
              ),
            ],
          ),
          feats: tough
              ? [
                  const EntityReference<DomainEntity>.empty(
                    refType: EntityType.feat,
                    slug: 'tough',
                    displayName: 'Tough',
                  ),
                ]
              : const [],
        );
        final engineHp = CharacterEvaluationEngine.evaluate(h1Char).maxHp;
        final telemetryHp = h1Char.toTelemetryDto().maxHp;
        expect(engineHp, equals(telemetryHp));
        if (tough) {
          expect(engineHp, equals(44));
        } else {
          expect(engineHp, equals(36));
        }
      }
    });

    test('H3: MulticlassSlotMatrix computes slots via installed catalog findClass', () {
      const character = Character(
        id: EntityId(slug: 'test-char', ruleset: RulesetVersion.v2024),
        name: 'Custom Caster',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>.empty(
                refType: EntityType.classDefinition,
                slug: 'custom-mage',
                displayName: 'Custom Mage',
              ),
              level: 3,
              hitDie: 'd6',
            ),
          ],
        ),
      );

      // Temporarily install catalog with custom-mage class
      Dnd5eRuleset.resetForTesting();
      Dnd5eRuleset.install(_CustomCasterCatalog());
      final wiredSlots = MulticlassSlotMatrix.calculateSpellSlots(character);

      expect(wiredSlots.maxSlots[1], equals(4));
      expect(wiredSlots.maxSlots[2], equals(2));

      // Restore production catalog
      Dnd5eRuleset.resetForTesting();
      installRulesetCatalog();
    });
  });
}

class _CustomCasterCatalog extends AppDnd5eCatalog {
  @override
  dynamic findClass(String slug) {
    if (slug == 'custom-mage') {
      return const _CustomCasterClass(
        id: EntityId(slug: 'custom-mage', ruleset: RulesetVersion.v2024),
        name: 'Custom Mage',
        customProperties: {'spellcastingProgression': 'full'},
      );
    }
    return super.findClass(slug);
  }
}
