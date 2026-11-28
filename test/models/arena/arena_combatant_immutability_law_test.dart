import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:flutter_test/flutter_test.dart';

Monster _makeTestMonster() {
  const sb = MonsterStatBlock(
    id: 'test_guard',
    name: 'Test Guard',
    sizeDisplay: 'Medium',
    crDisplay: 'CR 1',
    ac: 14,
    maxHp: 30,
    attackBonus: 4,
    damageDiceCount: 1,
    damageDiceSides: 8,
    damageBonus: 2,
    damageType: 'slashing',
  );
  return const Monster.simple(
    id: EntityId(slug: 'test_guard', ruleset: RulesetVersion.v2014),
    name: 'Test Guard',
    statBlock: sb,
  );
}

void main() {
  test('ArenaCombatant collections are unmodifiable across construction, mutations, clone, and reset', () {
    final monster = _makeTestMonster();
    final inputConditions = <ArenaCondition>{ArenaCondition.poisoned};
    final inputActive = <ActiveCondition>[
      const ActiveCondition(condition: ArenaCondition.poisoned, durationRounds: 2),
    ];
    final inputSlots = <int, int>{1: 2};
    final inputSaves = <String, int>{'str': 3};
    final inputDrain = <String, int>{'str': 1};

    final c = ArenaCombatant(
      id: 'c1',
      monster: monster,
      team: ArenaTeam.teamA,
      displayName: 'Guard',
      maxHp: 30,
      currentHp: 30,
      ac: 14,
      initiativeBonus: 1,
      conditions: inputConditions,
      activeConditions: inputActive,
      maxSpellSlots: inputSlots,
      currentSpellSlots: inputSlots,
      savingThrowBonuses: inputSaves,
      drainedAbilityScores: inputDrain,
    );

    // Mutating caller-owned inputs does not affect combatant.
    inputConditions.add(ArenaCondition.prone);
    inputActive.clear();
    inputSlots[2] = 9;
    inputSaves['dex'] = 5;
    inputDrain['dex'] = 2;

    expect(c.conditions, equals({ArenaCondition.poisoned}));
    expect(c.activeConditions, hasLength(1));
    expect(c.maxSpellSlots, equals({1: 2}));
    expect(c.currentSpellSlots, equals({1: 2}));
    expect(c.savingThrowBonuses, equals({'str': 3}));
    expect(c.drainedAbilityScores, equals({'str': 1}));

    // Exposed collections reject in-place mutation.
    expect(() => c.conditions.add(ArenaCondition.prone), throwsUnsupportedError);
    expect(
      () => c.activeConditions.add(const ActiveCondition(condition: ArenaCondition.prone)),
      throwsUnsupportedError,
    );
    expect(() => c.currentSpellSlots[1] = 0, throwsUnsupportedError);
    expect(() => c.maxSpellSlots[1] = 0, throwsUnsupportedError);
    expect(() => c.savingThrowBonuses['str'] = 0, throwsUnsupportedError);
    expect(() => c.drainedAbilityScores['str'] = 0, throwsUnsupportedError);

    // Clone and mutations remain isolated and unmodifiable.
    final cloned = c.clone();
    c.applyCondition(ArenaCondition.prone, (s) => 1, DmRulesEdition.v2024);
    c.setSpellSlot(1, 1);
    c.applyAttributeDrain(AbilityType.strength, 2, deathAtZero: false);

    expect(cloned.conditions, equals({ArenaCondition.poisoned}));
    expect(cloned.currentSpellSlots, equals({1: 2}));
    expect(cloned.drainedAbilityScores, equals({'str': 1}));

    expect(() => c.conditions.add(ArenaCondition.stunned), throwsUnsupportedError);
    expect(() => c.activeConditions.removeAt(0), throwsUnsupportedError);
    expect(() => c.currentSpellSlots[2] = 1, throwsUnsupportedError);
    expect(() => c.drainedAbilityScores['con'] = 1, throwsUnsupportedError);

    final reset = c.reset();
    expect(reset.conditions, isEmpty);
    expect(reset.activeConditions, isEmpty);
    expect(reset.drainedAbilityScores, isEmpty);
    expect(() => reset.conditions.add(ArenaCondition.prone), throwsUnsupportedError);
  });
}
