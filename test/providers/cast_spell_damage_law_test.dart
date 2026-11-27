import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';

import '../test_doubles/service_test_configurator.dart';

final _lawReplica = ReplicaId('spell_damage_law_replica');

class _MemoryRepo implements ICharacterRepository<Character> {
  Character? saved;
  @override
  Future<void> saveCharacter(Character character) async => saved = character;
  @override
  Future<List<Character>> loadCharacters() async =>
      saved != null ? [saved!] : [];
  @override
  Future<String?> loadActiveCharacterId() async => saved?.id.slug;
  @override
  Future<void> saveActiveCharacterId(String slug) async {}
  @override
  Future<void> clearActiveCharacterId() async {}
  @override
  Future<void> saveRoster(List<Character> roster) async {}
  @override
  Future<List<Character>> deleteCharacter(String slug) async => [];
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async =>
      saved != null ? [saved!] : [];
  @override
  Future<Character?> getCharacter(String id) async => saved;
  @override
  Future<void> saveCharacters(List<Character> characters) async {
    if (characters.isNotEmpty) saved = characters.last;
  }

  @override
  Future<Character> reparseCharacter(Character character) async => character;
  @override
  Future<List<Character>> reparseAllCharacters() async =>
      saved != null ? [saved!] : [];
}

Character _makeCaster() => Character(
      id: const EntityId(slug: 'law-caster', ruleset: RulesetVersion.v2024),
      name: 'Law Caster',
      speciesRef: const EntityReference.empty(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      progression: const CharacterProgression(
        classes: [
          ClassLevelProgression(
            classRef: EntityReference.empty(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 9,
            hitDie: 'd6',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: const AbilityScores(intelligence: 18, charisma: 16),
      resources: const CharacterResourcePool(
        currentHp: 50,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
          currentSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 1},
        ),
      ),
    );

Spell _makeSpell({
  required String formula,
  String? scalingFormula,
  int level = 1,
}) {
  return Spell.singleEdition(
    id: const EntityId(slug: 'law-spell', ruleset: RulesetVersion.v2024),
    name: 'Law Spell',
    level: level,
    school: 'evocation',
    castingTime: const CastingTime(
      cost: 1,
      actionType: ActionType.action,
      triggerCondition: '1 Action',
    ),
    duration: const SpellDuration(
      type: DurationType.instantaneous,
      rawText: 'Instantaneous',
    ),
    range: '60 ft.',
    components: const SpellComponents(v: true, s: true),
    descriptionMarkdown: 'Generated law test spell.',
    damageMath: [
      EvaluationMath(
        diceFormula: formula,
        scalingFormula: scalingFormula,
        damageType: DamageType.force,
      ),
    ],
  );
}

Map<int, int> _sumBySides(Iterable<({int sides, int count})> terms) {
  final out = <int, int>{};
  for (final t in terms) {
    out[t.sides] = (out[t.sides] ?? 0) + t.count;
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureTestCampaignProfileService();
    configureTestDiceRoomService();
  });

  group('Fix 3.1 Law: castSpell rolls every die group and flat bonus', () {
    test('Over >= 500 seeded multi-group base + scaling formulas, dice per side and modifier match exactly', () async {
      final rng = Random(13031);
      const sidesPool = [4, 6, 8, 10, 12, 20, 3, 5, 100];

      String formatExpr(List<(int, int)> groups, int? bonus, bool spaced) {
        final joiner = spaced ? ' + ' : '+';
        final buf = StringBuffer();
        for (var i = 0; i < groups.length; i++) {
          if (i > 0) buf.write(joiner);
          buf.write('${groups[i].$1}d${groups[i].$2}');
        }
        if (bonus != null && bonus != 0) {
          if (bonus > 0) {
            buf.write(spaced ? ' + $bonus' : '+$bonus');
          } else {
            buf.write(spaced ? ' - ${bonus.abs()}' : '-${bonus.abs()}');
          }
        }
        return buf.toString();
      }

      for (var seed = 0; seed < 520; seed++) {
        final baseGroupCount = 1 + rng.nextInt(4);
        final baseGroups = <(int, int)>[
          for (var g = 0; g < baseGroupCount; g++)
            (1 + rng.nextInt(10), sidesPool[rng.nextInt(sidesPool.length)]),
        ];
        final bonus = rng.nextBool() ? (rng.nextInt(16) - 5) : 0; // -5..+10
        final spaced = rng.nextBool();
        final baseFormula = formatExpr(baseGroups, bonus, spaced);

        final scaleGroupCount = 1 + rng.nextInt(2);
        final scaleGroups = <(int, int)>[
          for (var g = 0; g < scaleGroupCount; g++)
            (1 + rng.nextInt(3), sidesPool[rng.nextInt(sidesPool.length)]),
        ];
        final scaleFormula = formatExpr(scaleGroups, 0, rng.nextBool());

        final baseExpr = DiceExpression.parse(baseFormula);
        final scaleExpr = DiceExpression.parse(scaleFormula);

        final spell = _makeSpell(
          formula: baseFormula,
          scalingFormula: scaleFormula,
          level: 1,
        );

        // Cast at base level (delta = 0) and upcast (delta = 1..3)
        final delta = 1 + rng.nextInt(3);
        for (final castLevel in [1, 1 + delta]) {
          final levelsAbove = castLevel - 1;
          final ctrl = CharacterSheetController(
            replicaId: _lawReplica,
            character: _makeCaster(),
            persistenceService: _MemoryRepo(),
          );
          final res = await ctrl.castSpell(spell, castLevel: castLevel);
          expect(
            res,
            isNotNull,
            reason: 'seed=$seed base="$baseFormula" scale="$scaleFormula" castLevel=$castLevel returned null',
          );

          final expectedDice = _sumBySides([
            for (final dt in baseExpr.diceTerms) (sides: dt.sides, count: dt.count),
            if (levelsAbove > 0)
              for (final st in scaleExpr.diceTerms)
                (sides: st.sides, count: st.count * levelsAbove),
          ]);
          final actualDice = _sumBySides([
            for (final e in res!.diceEntries) (sides: e.sides, count: e.count),
          ]);

          expect(
            actualDice,
            equals(expectedDice),
            reason: 'seed=$seed base="$baseFormula" scale="$scaleFormula" castLevel=$castLevel: dice mismatch',
          );
          expect(
            res.modifier,
            equals(baseExpr.constantSum),
            reason: 'seed=$seed base="$baseFormula" scale="$scaleFormula" castLevel=$castLevel: modifier mismatch',
          );
        }
      }
    });
  });

  group('Fix 3.2 Law: unreadable spell formula returns null, spends no slot, broadcasts nothing', () {
    test('Over >= 500 seeded unreadable formula strings, castSpell returns null with no slot spend or broadcast', () async {
      final rng = Random(13032);
      const alphabet = 'abcefghijklmnopqrstuvwxyz!@#%^&*()_=[]{}|;:,./<>? ';
      var tested = 0;

      while (tested < 520) {
        final len = 1 + rng.nextInt(24);
        final buf = StringBuffer();
        for (var i = 0; i < len; i++) {
          buf.write(alphabet[rng.nextInt(alphabet.length)]);
        }
        final candidate = buf.toString().trim();
        if (candidate.isEmpty) continue;
        if (DiceExpression.tryParse(candidate) != null) continue;
        if (DiceExpression.findAll(candidate).isNotEmpty) continue;

        tested++;
        configureTestDiceRoomService();
        final room = DiceRoomService();
        final beforeRolls = room.getCachedRolls('LOCAL').length;
        final ctrl = CharacterSheetController(
          replicaId: _lawReplica,
          character: _makeCaster(),
          persistenceService: _MemoryRepo(),
        );
        final beforeSlots = ctrl.character.resources.spellSlots.currentSlots[1];

        final res = await ctrl.castSpell(
          _makeSpell(formula: candidate, level: 1),
          castLevel: 1,
        );
        expect(
          res,
          isNull,
          reason: 'case #$tested formula="$candidate": expected null',
        );
        expect(
          ctrl.character.resources.spellSlots.currentSlots[1],
          equals(beforeSlots),
          reason: 'case #$tested formula="$candidate": slot must not be spent',
        );
        expect(
          room.getCachedRolls('LOCAL').length,
          equals(beforeRolls),
          reason: 'case #$tested formula="$candidate": must not broadcast to room',
        );
      }
    });
  });
}
