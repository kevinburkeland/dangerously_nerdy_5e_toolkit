import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/monster_combat_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';

void _expectProfilesEqualFieldByField(
  MonsterCombatProfile actual,
  MonsterCombatProfile expected,
) {
  expect(actual.attacks.keys, equals(expected.attacks.keys));
  for (final key in expected.attacks.keys) {
    final a = actual.attacks[key]!;
    final e = expected.attacks[key]!;
    expect(a.attackId, equals(e.attackId));
    expect(a.attackBonus, equals(e.attackBonus));
    expect(a.flatBonus, equals(e.flatBonus));
    expect(a.damageGroups.length, equals(e.damageGroups.length));
    for (var i = 0; i < e.damageGroups.length; i++) {
      expect(a.damageGroups[i].count, equals(e.damageGroups[i].count));
      expect(a.damageGroups[i].faces, equals(e.damageGroups[i].faces));
    }
    expect(a.riders.length, equals(e.riders.length));
  }
  expect(actual.maxSpellSlots, equals(expected.maxSpellSlots));
  expect(actual.knownSpellIds, equals(expected.knownSpellIds));
  expect(actual.spellSaveDc, equals(expected.spellSaveDc));
  expect(actual.spellAttackBonus, equals(expected.spellAttackBonus));
  expect(actual.meleeReachInFeet, equals(expected.meleeReachInFeet));
  expect(actual.canFly, equals(expected.canFly));
  expect(actual.hasHover, equals(expected.hasHover));
  expect(actual.defaultAltitudeInFeet, equals(expected.defaultAltitudeInFeet));
  expect(actual.savingThrowBonuses, equals(expected.savingThrowBonuses));
  expect(actual.maxLegendaryActions, equals(expected.maxLegendaryActions));
  expect(actual.maxLegendaryResistances,
      equals(expected.maxLegendaryResistances));
  expect(actual.canSwim, equals(expected.canSwim));
  expect(actual.canBurrow, equals(expected.canBurrow));
  expect(actual.canClimb, equals(expected.canClimb));
  expect(actual.hasEvasion, equals(expected.hasEvasion));
  expect(actual.hasFlyby, equals(expected.hasFlyby));
  expect(actual.hasNimbleEscape, equals(expected.hasNimbleEscape));
}

void main() {
  group('Fix 4.2: MonsterItem.getCombatProfile caches once per edition', () {
    test('const SRD monster returns identical object per edition and matches fresh build',
        () {
      final monster = MonsterCodexLibrary.allMonsters.first;

      final p2024a = monster.getCombatProfile(DmRulesEdition.v2024);
      final p2024b = monster.getCombatProfile(DmRulesEdition.v2024);
      final p2014a = monster.getCombatProfile(DmRulesEdition.v2014);
      final p2014b = monster.getCombatProfile(DmRulesEdition.v2014);

      expect(identical(p2024a, p2024b), isTrue);
      expect(identical(p2014a, p2014b), isTrue);
      expect(identical(p2024a, p2014a), isFalse);

      final fresh2024 = MonsterCombatProfile.fromStatBlock(
        monster.getStatBlock(DmRulesEdition.v2024),
        challengeRating: monster.challengeRatingValue,
      );
      final fresh2014 = MonsterCombatProfile.fromStatBlock(
        monster.getStatBlock(DmRulesEdition.v2014),
        challengeRating: monster.challengeRatingValue,
      );
      _expectProfilesEqualFieldByField(p2024a, fresh2024);
      _expectProfilesEqualFieldByField(p2014a, fresh2014);
    });

    test('non-const MonsterItem returns identical object per edition and differs across editions',
        () {
      final runtimeId = 'custom_cached_${DateTime.now().microsecondsSinceEpoch}';
      final monster = Monster(
        id: EntityId(slug: runtimeId, ruleset: RulesetVersion.v2014),
        name: 'Custom Cached Monster',
        statBlock2014: const MonsterStatBlock(
          id: 'custom_2014',
          name: 'Custom 2014',
          sizeDisplay: 'Large',
          crDisplay: 'CR 4',
          ac: 14,
          maxHp: 50,
          speed: '30 ft.',
          attackBonus: 6,
          damageDiceCount: 1,
          damageDiceSides: 8,
          damageBonus: 4,
          damageType: 'slashing',
        ),
        statBlock2024: const MonsterStatBlock(
          id: 'custom_2024',
          name: 'Custom 2024',
          sizeDisplay: 'Large',
          crDisplay: 'CR 4',
          ac: 15,
          maxHp: 58,
          speed: '30 ft., fly 60 ft.',
          attackBonus: 6,
          damageDiceCount: 1,
          damageDiceSides: 10,
          damageBonus: 4,
          damageType: 'slashing',
        ),
      );

      final p2024a = monster.getCombatProfile(DmRulesEdition.v2024);
      final p2024b = monster.getCombatProfile(DmRulesEdition.v2024);
      final p2014a = monster.getCombatProfile(DmRulesEdition.v2014);

      expect(identical(p2024a, p2024b), isTrue);
      expect(identical(p2024a, p2014a), isFalse);
      expect(p2024a.canFly, isTrue);
      expect(p2014a.canFly, isFalse);
    });
  });
}
