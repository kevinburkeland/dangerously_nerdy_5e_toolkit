import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/services/combat_encounter_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/session_graph_models.dart';

class _FakeCharRepo implements ICharacterRepository {
  final Map<String, Character> storage = {};

  @override
  Future<List<Character>> loadCharacters() async => storage.values.toList();

  @override
  Future<List<Character>> saveCharacter(Character character) async {
    storage[character.id.slug] = character;
    return storage.values.toList();
  }

  @override
  Future<List<Character>> deleteCharacter(String characterSlug) async {
    storage.remove(characterSlug);
    return storage.values.toList();
  }

  @override
  Future<Character?> getCharacter(String id) async => storage[id];

  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async =>
      ids.map((id) => storage[id]).whereType<Character>().toList();

  @override
  Future<void> saveCharacters(List<Character> characters) async {
    for (final c in characters) {
      storage[c.id.slug] = c;
    }
  }

  @override
  Future<void> saveRoster(List<Character> roster) async {
    storage.clear();
    for (final c in roster) {
      storage[c.id.slug] = c;
    }
  }

  @override
  Future<String?> loadActiveCharacterId() async => storage.keys.firstOrNull;

  @override
  Future<void> saveActiveCharacterId(String slug) async {}

  @override
  Future<void> clearActiveCharacterId() async {}

  @override
  Future<Character> reparseCharacter(Character character) async => character;

  @override
  Future<List<Character>> reparseAllCharacters() async => storage.values.toList();
}

class _FakeCampaignRepo implements ICampaignRepository {
  CampaignProfile? currentProfile;

  @override
  String? get activeProfileId => currentProfile?.id;

  @override
  CampaignProfile? get activeProfile => currentProfile;

  @override
  List<CampaignProfile> get allProfiles => currentProfile != null ? [currentProfile!] : [];

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile?> getProfile(String id) async => currentProfile?.id == id ? currentProfile : null;

  @override
  Future<CampaignProfile?> getActiveProfile() async => currentProfile;

  @override
  Future<void> saveProfile(CampaignProfile profile) async {
    currentProfile = profile;
  }

  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    currentProfile = profile;
  }

  @override
  Future<void> deleteProfile(String id) async {
    if (currentProfile?.id == id) currentProfile = null;
  }

  @override
  Future<void> setActiveProfileId(String id) async {}

  @override
  Stream<CampaignProfile?> watchActiveProfile() => Stream.value(currentProfile);

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => Stream.value(allProfiles);
}

void main() {
  group('CombatEncounterService Tests', () {
    late _FakeCharRepo charRepo;
    late _FakeCampaignRepo campaignRepo;
    late CombatEncounterService service;
    late Character testChar;

    setUp(() {
      charRepo = _FakeCharRepo();
      campaignRepo = _FakeCampaignRepo();
      service = CombatEncounterService(
        characterRepo: charRepo,
        campaignRepo: campaignRepo,
        localNodeId: 'node-test-1',
      );

      testChar = const Character(
        id: EntityId(slug: 'fighter_bob', ruleset: RulesetVersion.v2024),
        name: 'Bob the Fighter',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        baseScores: AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 3,
              hitDie: 'd10',
            ),
          ],
        ),
        resources: CharacterResourcePool(
          currentHp: 20,
          tempHp: 5,
        ),
      );
      charRepo.storage[testChar.id.slug] = testChar;
    });

    test('applyCharacterDamage absorbs temp HP first', () async {
      // 8 damage: absorbs 5 temp HP, 3 damage to current HP (20 - 3 = 17)
      final updated = await service.applyCharacterDamage(
        character: testChar,
        amount: 8,
      );

      expect(updated.resources.tempHp, equals(0));
      expect(updated.resources.currentHp, equals(17));
      expect(charRepo.storage[testChar.id.slug]?.resources.currentHp, equals(17));
    });

    test('applyCharacterDamage absorbs partial temp HP when damage < tempHp', () async {
      // 3 damage: absorbs 3 temp HP, 2 temp HP remains, current HP unchanged
      final updated = await service.applyCharacterDamage(
        character: testChar,
        amount: 3,
      );

      expect(updated.resources.tempHp, equals(2));
      expect(updated.resources.currentHp, equals(20));
    });

    test('applyCharacterHealing clamps to effectiveMaxHp', () async {
      final updated = await service.applyCharacterHealing(
        character: testChar,
        amount: 15,
        maxHp: 25,
      );

      expect(updated.resources.currentHp, equals(25));
      expect(charRepo.storage[testChar.id.slug]?.resources.currentHp, equals(25));
    });

    test('modifyCharacterHp routes negative delta to damage and positive to healing', () async {
      final damaged = await service.modifyCharacterHp(
        character: testChar,
        delta: -10, // 5 absorbed by tempHp, 5 damage -> 15 hp
      );
      expect(damaged.resources.currentHp, equals(15));
      expect(damaged.resources.tempHp, equals(0));

      final healed = await service.modifyCharacterHp(
        character: damaged,
        delta: 4,
        maxHp: 30,
      );
      expect(healed.resources.currentHp, equals(19));
    });

    test('modifyMinionHp reduces and heals minion HP safely', () async {
      final minion = AnimatedObjectInstance(
        id: 'minion_1',
        name: 'Flying Sword',
        size: ObjectSize.small,
        currentHp: 10,
        maxHp: 10,
      );
      final profile = CampaignProfile.defaultProfile().copyWith(
        roomState: RoomNodeState.fromLists(
          roomId: 'r1',
          roomCode: 'R1',
          title: 'Dungeon Room',
          activeMinions: [minion],
        ),
      );
      campaignRepo.currentProfile = profile;

      // Damage minion
      final damagedProfile = await service.modifyMinionHp(
        profile: profile,
        minionId: 'minion_1',
        delta: -4,
      );
      expect(damagedProfile.roomState.activeMinions.length, equals(1));
      expect(damagedProfile.roomState.activeMinions.first.currentHp, equals(6));

      // Heal minion
      final healedProfile = await service.modifyMinionHp(
        profile: damagedProfile,
        minionId: 'minion_1',
        delta: 2,
      );
      expect(healedProfile.roomState.activeMinions.first.currentHp, equals(8));

      // Remove minion
      final removedProfile = await service.removeMinion(
        profile: healedProfile,
        minionId: 'minion_1',
      );
      expect(removedProfile.roomState.activeMinions.isEmpty, isTrue);
    });

    test('modifyMinionHp returns a new instance of AnimatedObjectInstance leaving original instance unmodified', () async {
      final originalMinion = AnimatedObjectInstance(
        id: 'minion_immutable_test',
        name: 'Animated Shield',
        size: ObjectSize.small,
        currentHp: 20,
        maxHp: 20,
        tempHp: 5,
      );
      final profile = CampaignProfile.defaultProfile().copyWith(
        roomState: RoomNodeState.fromLists(
          roomId: 'r_immutable',
          roomCode: 'IMMUTABLE',
          title: 'Testing Vault',
          activeMinions: [originalMinion],
        ),
      );
      campaignRepo.currentProfile = profile;

      final updatedProfile = await service.modifyMinionHp(
        profile: profile,
        minionId: 'minion_immutable_test',
        delta: -10,
      );

      final updatedMinion = updatedProfile.roomState.activeMinions.first;
      // 5 temp HP absorbed, 5 damage spills over to current HP: 20 - 5 = 15
      expect(updatedMinion.currentHp, equals(15));
      expect(updatedMinion.tempHp, equals(0));
      expect(identical(updatedMinion, originalMinion), isFalse);

      // Verify original minion remains completely unmodified
      expect(originalMinion.currentHp, equals(20));
      expect(originalMinion.tempHp, equals(5));
    });

    test('nextTurn and prevTurn cycle active turn and round count', () {
      const p1 = EncounterParticipant(
        participantId: 'p1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.character,
          entityId: 'bob',
          displayName: 'Bob',
        ),
        currentHp: 20,
        maxHp: 20,
        isActiveTurn: true,
      );
      const p2 = EncounterParticipant(
        participantId: 'p2',
        entityLink: RoomEntityLink(
          refType: SessionRefType.monster,
          entityId: 'goblin',
          displayName: 'Goblin',
        ),
        currentHp: 7,
        maxHp: 7,
        isActiveTurn: false,
      );

      final list = [p1, p2];

      // Next turn: p1 -> p2
      int? newRound;
      final turn2 = service.nextTurn(
        list,
        currentRound: 1,
        onNewRound: (r) => newRound = r,
      );
      expect(turn2[0].isActiveTurn, isFalse);
      expect(turn2[1].isActiveTurn, isTrue);
      expect(newRound, isNull);

      // Next turn again: p2 -> p1 (triggers round increment!)
      final turn3 = service.nextTurn(
        turn2,
        currentRound: 1,
        onNewRound: (r) => newRound = r,
      );
      expect(turn3[0].isActiveTurn, isTrue);
      expect(turn3[1].isActiveTurn, isFalse);
      expect(newRound, equals(2));

      // Previous turn: p1 -> p2
      final turnBack = service.prevTurn(turn3);
      expect(turnBack[0].isActiveTurn, isFalse);
      expect(turnBack[1].isActiveTurn, isTrue);
    });

    test('applyParticipantDamageOrHeal handles damage absorption and defeat status', () {
      const p1 = EncounterParticipant(
        participantId: 'p1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.character,
          entityId: 'bob',
          displayName: 'Bob',
        ),
        currentHp: 15,
        maxHp: 20,
        tempHp: 5,
      );

      // 8 damage: absorbs 5 temp HP, 3 damage to HP -> 12 HP remaining
      final damaged = service.applyParticipantDamageOrHeal(
        participants: [p1],
        participantId: 'p1',
        delta: -8,
      );
      expect(damaged.first.currentHp, equals(12));
      expect(damaged.first.tempHp, equals(0));
      expect(damaged.first.isDefeated, isFalse);

      // Lethal non-massive damage: 15 damage -> 0 HP, isDefeated = true, isDead = false (downed/unconscious)
      final lethal = service.applyParticipantDamageOrHeal(
        participants: damaged,
        participantId: 'p1',
        delta: -15,
      );
      expect(lethal.first.currentHp, equals(0));
      expect(lethal.first.isDefeated, isTrue);
      expect(lethal.first.isDead, isFalse);

      // Healing a downed (0 HP) participant: +10 HP -> 10 HP, isDefeated = false per 5e RAW
      final healed = service.applyParticipantDamageOrHeal(
        participants: lethal,
        participantId: 'p1',
        delta: 10,
      );
      expect(healed.first.currentHp, equals(10));
      expect(healed.first.isDefeated, isFalse);
      expect(healed.first.isDead, isFalse);

      // Massive lethal damage (e.g. 50 damage on 10 HP / 20 max HP -> excess 40 >= 20 maxHp)
      final massiveLethal = service.applyParticipantDamageOrHeal(
        participants: healed,
        participantId: 'p1',
        delta: -50,
      );
      expect(massiveLethal.first.currentHp, equals(0));
      expect(massiveLethal.first.isDefeated, isTrue);
      expect(massiveLethal.first.isDead, isTrue);

      // Standard healing cannot revive a permanently dead participant
      final stillDead = service.applyParticipantDamageOrHeal(
        participants: massiveLethal,
        participantId: 'p1',
        delta: 10,
      );
      expect(stillDead.first.currentHp, equals(0));
      expect(stillDead.first.isDead, isTrue);
      expect(stillDead.first.isDefeated, isTrue);

      // Explicit revival restores the dead participant
      final revived = service.applyParticipantDamageOrHeal(
        participants: stillDead,
        participantId: 'p1',
        delta: 15,
        allowRevive: true,
      );
      expect(revived.first.currentHp, equals(15));
      expect(revived.first.isDead, isFalse);
      expect(revived.first.isDefeated, isFalse);
    });

    test('applyCharacterHealing handles unconscious vs dead characters per 5e RAW', () async {
      // 1. Downed character at 0 HP with 1 death save failure
      final downedChar = testChar.copyWith(
        resources: testChar.resources.copyWith(
          currentHp: 0,
          deathSaveFailures: 1,
          deathSaveSuccesses: 1,
        ),
      );
      final revivedDowned = await service.applyCharacterHealing(
        character: downedChar,
        amount: 8,
        maxHp: 20,
      );
      expect(revivedDowned.resources.currentHp, equals(8));
      // Death saves are reset on waking up
      expect(revivedDowned.resources.deathSaveFailures, equals(0));
      expect(revivedDowned.resources.deathSaveSuccesses, equals(0));

      // 2. Permanently dead character with 3 death save failures
      final deadChar = testChar.copyWith(
        resources: testChar.resources.copyWith(
          currentHp: 0,
          deathSaveFailures: 3,
        ),
      );
      // Standard healing rejected without isRevival
      final failedHeal = await service.applyCharacterHealing(
        character: deadChar,
        amount: 10,
        maxHp: 20,
      );
      expect(failedHeal.resources.currentHp, equals(0));
      expect(failedHeal.resources.deathSaveFailures, equals(3));

      // Explicit revival restores HP and resets death saves
      final explicitRevived = await service.applyCharacterHealing(
        character: deadChar,
        amount: 10,
        maxHp: 20,
        isRevival: true,
      );
      expect(explicitRevived.resources.currentHp, equals(10));
      expect(explicitRevived.resources.deathSaveFailures, equals(0));
    });

    test('toggleParticipantCondition adds and removes conditions', () {
      const p1 = EncounterParticipant(
        participantId: 'p1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.character,
          entityId: 'bob',
          displayName: 'Bob',
        ),
        currentHp: 20,
        maxHp: 20,
        activeConditions: ['prone'],
      );

      // Add 'stunned'
      final added = service.toggleParticipantCondition(
        participants: [p1],
        participantId: 'p1',
        conditionName: 'stunned',
      );
      expect(added.first.activeConditions, containsAll(['prone', 'stunned']));

      // Remove 'prone'
      final removed = service.toggleParticipantCondition(
        participants: added,
        participantId: 'p1',
        conditionName: 'prone',
      );
      expect(removed.first.activeConditions, equals(['stunned']));
    });

    test('updateEncounterParticipants anchors HLC timestamps to injected networkTimeProvider', () async {
      const fixedNetworkTime = 1715000000000;
      final timedService = CombatEncounterService(
        characterRepo: charRepo,
        campaignRepo: campaignRepo,
        localNodeId: 'node-timed-test',
        networkTimeProvider: () => fixedNetworkTime,
      );

      const p1 = EncounterParticipant(
        participantId: 'p1',
        entityLink: RoomEntityLink(
          refType: SessionRefType.character,
          entityId: 'alice',
          displayName: 'Alice',
        ),
        currentHp: 25,
        maxHp: 25,
      );

      final profile = CampaignProfile.defaultProfile(id: 'camp_clock_test');
      final updatedProfile = await timedService.updateEncounterParticipants(
        profile: profile,
        encounter: [p1],
      );

      final encounterItem = updatedProfile.roomState.activeEncounter.items['p1'];
      expect(encounterItem, isNotNull);
      expect(encounterItem!.timestamp.physicalTime, equals(fixedNetworkTime));
      expect(encounterItem.timestamp.nodeId, equals('node-timed-test'));

      // Now remove participant
      final removedProfile = await timedService.updateEncounterParticipants(
        profile: updatedProfile,
        encounter: [],
      );
      final tombstone = removedProfile.roomState.activeEncounter.tombstones['p1'];
      expect(tombstone, isNotNull);
      expect(tombstone!.physicalTime, equals(fixedNetworkTime));
      expect(tombstone.logicalCounter, greaterThan(encounterItem.timestamp.logicalCounter));
    });
  });
}
