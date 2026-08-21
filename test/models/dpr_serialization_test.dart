import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_serialization.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dpr_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DPR Serialization & Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('DprAttackAction round-trip serialization maintains all complex properties', () {
      const attack = DprAttackAction(
        id: 'att_test_1',
        name: 'Vorpal Greatsword',
        attackBonus: 9,
        diceCount: 2,
        diceSides: 6,
        damageBonus: 5,
        damageType: 'slashing',
        secondaryDiceCount: 1,
        secondaryDiceSides: 6,
        secondaryDamageBonus: 0,
        secondaryDamageType: 'fire',
        gwmMode: GwmMode.v2014PowerAttack,
        gwfVersion: GwfVersion.v2024Floor3,
        weaponMastery: WeaponMastery.graze,
        abilityModForGraze: 5,
        hasDueling: false,
        attacksPerRound: 2,
      );

      final map = attack.toMap();
      final deserialized = DprAttackActionSerialization.fromMap(map);

      expect(deserialized.id, 'att_test_1');
      expect(deserialized.name, 'Vorpal Greatsword');
      expect(deserialized.attackBonus, 9);
      expect(deserialized.diceCount, 2);
      expect(deserialized.diceSides, 6);
      expect(deserialized.damageBonus, 5);
      expect(deserialized.secondaryDiceCount, 1);
      expect(deserialized.secondaryDamageType, 'fire');
      expect(deserialized.gwmMode, GwmMode.v2014PowerAttack);
      expect(deserialized.gwfVersion, GwfVersion.v2024Floor3);
      expect(deserialized.weaponMastery, WeaponMastery.graze);
      expect(deserialized.abilityModForGraze, 5);
      expect(deserialized.attacksPerRound, 2);
    });

    test('DprCombatantProfile round-trip JSON serialization', () {
      const profile = DprCombatantProfile(
        id: 'char_paladin',
        name: 'Vengeance Paladin',
        description: 'Level 11 Vengeance Paladin Build',
        level: 11,
        abilityScore: 20,
        proficiencyBonus: 4,
        defaultAdvantage: AdvantageType.advantage,
        hasHalflingLuck: true,
        attacks: [
          DprAttackAction(
            id: 'smite_attack',
            name: 'Radiant Strike',
            attackBonus: 9,
            diceCount: 1,
            diceSides: 8,
            damageBonus: 5,
            secondaryDiceCount: 2,
            secondaryDiceSides: 8,
            secondaryDamageType: 'radiant',
          ),
        ],
      );

      final jsonStr = profile.toJson();
      final restored = DprCombatantProfileSerialization.fromJson(jsonStr);

      expect(restored.id, 'char_paladin');
      expect(restored.name, 'Vengeance Paladin');
      expect(restored.level, 11);
      expect(restored.abilityScore, 20);
      expect(restored.defaultAdvantage, AdvantageType.advantage);
      expect(restored.hasHalflingLuck, isTrue);
      expect(restored.attacks.length, 1);
      expect(restored.attacks.first.name, 'Radiant Strike');
      expect(restored.attacks.first.secondaryDiceCount, 2);
    });

    test('DprPersistenceService saves and loads custom builds library', () async {
      final service = DprPersistenceService();

      const profile1 = DprCombatantProfile(
        id: 'build_1',
        name: 'Build Alpha',
        attacks: [],
      );

      const profile2 = DprCombatantProfile(
        id: 'build_2',
        name: 'Build Beta',
        attacks: [],
      );

      await service.saveProfileToLibrary(profile1);
      await service.saveProfileToLibrary(profile2);

      final library = await service.loadSavedProfiles();
      expect(library.length, 2);
      expect(library.map((p) => p.name), containsAll(['Build Alpha', 'Build Beta']));

      await service.deleteProfileFromLibrary('build_1');
      final updatedLibrary = await service.loadSavedProfiles();
      expect(updatedLibrary.length, 1);
      expect(updatedLibrary.first.name, 'Build Beta');
    });
  });
}
