import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/campaign_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';

void main() {
  group('AnimatedObjectInstance Equality Contract', () {
    test('Instances with identical IDs but different combat state are NOT equal', () {
      final obj1 = AnimatedObjectInstance(
        id: 'token_1',
        name: 'Animated Dagger',
        size: ObjectSize.tiny,
        currentHp: 20,
        maxHp: 20,
        tempHp: 0,
      );

      final obj2 = AnimatedObjectInstance(
        id: 'token_1',
        name: 'Animated Dagger',
        size: ObjectSize.tiny,
        currentHp: 12, // Damaged HP
        maxHp: 20,
        tempHp: 0,
      );

      expect(obj1 == obj2, isFalse, reason: 'Different currentHp must not evaluate as equal');
      expect(obj1.hashCode == obj2.hashCode, isFalse);
    });

    test('Instances with identical fields evaluate as equal and share hashCodes', () {
      final obj1 = AnimatedObjectInstance(
        id: 'token_1',
        name: 'Animated Table',
        size: ObjectSize.medium,
        currentHp: 40,
        maxHp: 40,
        tempHp: 5,
        damageType: 'Bludgeoning',
        isSilvered: true,
        customAc: 15,
        customAttackBonus: 6,
      );

      final obj2 = AnimatedObjectInstance(
        id: 'token_1',
        name: 'Animated Table',
        size: ObjectSize.medium,
        currentHp: 40,
        maxHp: 40,
        tempHp: 5,
        damageType: 'Bludgeoning',
        isSilvered: true,
        customAc: 15,
        customAttackBonus: 6,
      );

      expect(obj1 == obj2, isTrue);
      expect(obj1.hashCode, equals(obj2.hashCode));
    });
  });

  group('CampaignProfile Deserialization Data Safety & Roster Preservation', () {
    test('Preserves malformed or unparsed character payloads without dropping them on save', () {
      final malformedCharacterPayload = {
        'id': 'corrupt_char_99',
        'name': 'Corrupted Hero',
        'abilityScores': 'INVALID_STRING_INSTEAD_OF_MAP', // Causes Character.fromMap to throw
      };

      final rawCampaignMap = {
        'id': 'camp_safe_1',
        'name': 'Data Safety Campaign',
        'edition': 'v2024',
        'partyRoster': [malformedCharacterPayload],
        'activeMinions': [],
      };

      // Deserialization should not throw and should safely store unparsed payload
      final profile = CampaignProfile.fromMap(rawCampaignMap);
      expect(profile.partyCharacterIds.isEmpty, isTrue);
      expect(profile.unparsedPartyRoster.length, equals(1));
      expect(profile.unparsedPartyRoster.first['id'], equals('corrupt_char_99'));

      // Reserialization outputs partyCharacterIds
      final serializedMap = profile.toMap();
      final rosterOut = serializedMap['partyCharacterIds'] as List;
      expect(rosterOut.isEmpty, isTrue);
    });

    test('Preserves malformed active minions payloads on round-trip', () {
      final malformedMinionPayload = {
        'id': 'corrupt_minion_1',
        // Missing size, name, hp
      };

      final rawCampaignMap = {
        'id': 'camp_safe_2',
        'name': 'Minion Safety Campaign',
        'edition': 'v2024',
        'partyCharacterIds': [],
        'activeMinions': [malformedMinionPayload],
      };

      final profile = CampaignProfile.fromMap(rawCampaignMap);
      expect(profile.roomState.activeMinions.length, equals(1)); // AnimatedObjectInstance.fromMap falls back safely
    });
  });

  group('MonsterCombatProfile & Arena Simulation Pre-Computation', () {
    test('Parses spell slots, DCs, reach, and saving throws once into typed primitives', () {
      final monster = MonsterCodexLibrary.allMonsters.firstWhere(
        (m) => m.traits.isNotEmpty,
        orElse: () => MonsterCodexLibrary.allMonsters.first,
      );
      final profile = monster.getCombatProfile(DmRulesEdition.v2024);

      expect(profile.meleeReachInFeet, greaterThanOrEqualTo(5));

      // ArenaCombatant instantiates directly without re-parsing
      final combatant = ArenaCombatant.fromMonster(
        id: 'monster_1',
        monster: monster,
        team: ArenaTeam.teamA,
      );

      expect(combatant.maxSpellSlots, equals(profile.maxSpellSlots));
      expect(combatant.spellSaveDc, equals(profile.spellSaveDc));
      expect(combatant.meleeReachInFeet, equals(profile.meleeReachInFeet));
      expect(combatant.canFly(), equals(profile.canFly));
    });
  });

  group('Race Normalized Typed Fields', () {
    test('Correctly exposes typed bonus feats and flexible ability score increases', () {
      final variantHuman = Race(
        id: const EntityId(slug: 'human-variant', ruleset: RulesetVersion.v2014),
        name: 'Human (Variant)',
        traitsMarkdown: 'Bonus Feat & Skills',
      );

      expect(variantHuman.grantsBonusFeat, isTrue);
      expect(variantHuman.bonusFeatCount, equals(1));
      expect(variantHuman.flexibleAbilityChoiceCount, equals(2));
      expect(variantHuman.flexibleAbilityBonusValue, equals(1));

      final serialized = variantHuman.toMap();
      expect(serialized['bonusFeatCount'], equals(1));
      expect(serialized['flexibleAbilityCount'], equals(2));

      final deserialized = Race.fromMap(serialized);
      expect(deserialized.bonusFeatCount, equals(1));
      expect(deserialized.flexibleAbilityCount, equals(2));
      expect(deserialized.grantsBonusFeat, isTrue);
    });
  });
}
