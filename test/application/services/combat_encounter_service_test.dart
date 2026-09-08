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
        roomState: RoomNodeState(
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

      // Lethal damage: 15 damage -> 0 HP, isDefeated = true
      final lethal = service.applyParticipantDamageOrHeal(
        participants: damaged,
        participantId: 'p1',
        delta: -15,
      );
      expect(lethal.first.currentHp, equals(0));
      expect(lethal.first.isDefeated, isTrue);

      // Healing: +10 HP -> 10 HP, isDefeated = false
      final healed = service.applyParticipantDamageOrHeal(
        participants: lethal,
        participantId: 'p1',
        delta: 10,
      );
      expect(healed.first.currentHp, equals(10));
      expect(healed.first.isDefeated, isFalse);
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
  });
}
