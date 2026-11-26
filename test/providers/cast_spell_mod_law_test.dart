import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';

import '../test_doubles/service_test_configurator.dart';

final _lawReplica = ReplicaId('spell_mod_law_replica');

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

Character _makeCleric({
  required RulesetEdition edition,
  int wisdomScore = 16,
}) =>
    Character(
      id: EntityId(
        slug: 'cleric-law',
        ruleset: edition == RulesetEdition.v2024
            ? RulesetVersion.v2024
            : RulesetVersion.v2014,
      ),
      name: 'Law Cleric',
      rulesEdition: edition,
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
              slug: 'cleric',
              displayName: 'Cleric',
            ),
            level: 17,
            hitDie: 'd8',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: AbilityScores(wisdom: wisdomScore),
      resources: const CharacterResourcePool(
        currentHp: 100,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1, 8: 1, 9: 1},
          currentSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1, 7: 1, 8: 1, 9: 1},
        ),
      ),
    );

Character _makeFighterNonCaster(RulesetEdition edition) => Character(
      id: EntityId(
        slug: 'fighter-law',
        ruleset: edition == RulesetEdition.v2024
            ? RulesetVersion.v2024
            : RulesetVersion.v2014,
      ),
      name: 'Law Fighter',
      rulesEdition: edition,
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
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 10,
            hitDie: 'd10',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: const AbilityScores(strength: 18, wisdom: 16),
      resources: const CharacterResourcePool(
        currentHp: 100,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4, 2: 3, 3: 3},
          currentSlots: {1: 4, 2: 3, 3: 3},
        ),
      ),
    );

Spell _domainSpellFromItem(Spell item, DmRulesEdition edition) {
  final rules = item.getRules(edition);
  final rf = rules.rollFormula;
  final hasFormula =
      rf != null && rf.trim().isNotEmpty && rf.trim().toLowerCase() != 'none';
  final scaleStr = rules.scalingFormula != null
      ? '+${rules.scalingFormula!.dicePerSlotLevel}d${rules.scalingFormula!.diceSides}'
      : null;

  return Spell(
    id: EntityId(
      slug: item.id.slug,
      ruleset: edition == DmRulesEdition.v2024
          ? RulesetVersion.v2024
          : RulesetVersion.v2014,
    ),
    name: item.getName(edition),
    level: item.level,
    school: item.getSchool(edition).name,
    castingTime: CastingTime(
      cost: 1,
      actionType: ActionType.action,
      triggerCondition: rules.castingTime,
    ),
    duration: SpellDuration(
      type: rules.concentration
          ? DurationType.special
          : DurationType.instantaneous,
      requiresConcentration: rules.concentration,
      rawText: rules.duration,
    ),
    range: rules.range,
    components: SpellComponents(
      v: rules.components.contains('V'),
      s: rules.components.contains('S'),
      m: rules.components.contains('M'),
    ),
    descriptionMarkdown: rules.description.join('\n\n'),
    higherLevelsMarkdown: rules.higherLevels,
    damageMath: hasFormula
        ? [
            EvaluationMath(
              diceFormula: rf,
              damageType: DamageType.untyped,
              scalingFormula: scaleStr,
            ),
          ]
        : const [],
    customProperties: {
      if (hasFormula) 'rollFormula': rf,
      'scalingFormula': ?scaleStr,
    },
  );
}

Spell _customSpell({
  required String formula,
  String? scalingFormula,
  int level = 1,
}) =>
    Spell(
      id: const EntityId(slug: 'custom-law-spell', ruleset: RulesetVersion.v2024),
      name: 'Custom Law Spell',
      level: level,
      school: 'evocation',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
      duration: const SpellDuration(type: DurationType.instantaneous),
      range: '60 ft.',
      components: const SpellComponents(v: true, s: true),
      descriptionMarkdown: 'Generated spell.',
      damageMath: [
        EvaluationMath(
          diceFormula: formula,
          scalingFormula: scalingFormula,
          damageType: DamageType.force,
        ),
      ],
    );

int _signedModCount(DiceExpression expr) {
  var count = 0;
  for (final t in expr.terms) {
    if (t is DiceModTerm) {
      count += t.isNegative ? -1 : 1;
    }
  }
  return count;
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

  group('Fix 3.2 & 3.3 Law 1: every bundled spell roll matches formula and mod', () {
    test(
      'WIS 16 Cleric (+3) casting every bundled spell (both editions, base and +1 level)',
      () async {
        final mismatches = <String>[];
        final unreadable = <String>[];

        for (final item in SpellbookLibrary.srdSpells) {
          for (final dmEd in const [DmRulesEdition.v2014, DmRulesEdition.v2024]) {
            final rules = item.getRules(dmEd);
            final rf = rules.rollFormula;
            if (rf == null ||
                rf.trim().isEmpty ||
                rf.trim().toLowerCase() == 'none') {
              continue;
            }

            final rulesEd = dmEd == DmRulesEdition.v2024
                ? RulesetEdition.v2024
                : RulesetEdition.v2014;
            final domainSpell = _domainSpellFromItem(item, dmEd);
            final castLevels =
                item.level == 0 || item.level >= 9
                    ? <int>[item.level]
                    : <int>[item.level, item.level + 1];

            final baseExpr = DiceExpression.tryParse(rf.trim());
            final scaleStr = domainSpell.damageMath.firstOrNull?.scalingFormula;
            final scaleExpr = scaleStr != null
                ? DiceExpression.tryParse(
                    scaleStr.trim().replaceFirst(RegExp(r'^\+\s*'), ''),
                  )
                : null;

            for (final castLevel in castLevels) {
              final delta = castLevel > item.level ? (castLevel - item.level) : 0;
              final ctrl = CharacterSheetController(
                character: _makeCleric(edition: rulesEd, wisdomScore: 16),
                persistenceService: _MemoryRepo(),
                replicaId: _lawReplica,
              );

              final res = await ctrl.castSpell(domainSpell, castLevel: castLevel);

              if (baseExpr == null ||
                  baseExpr.diceTerms.any((t) => t.isNegative)) {
                unreadable.add('${item.name} (${dmEd.name}) "$rf"');
                if (res != null) {
                  mismatches.add(
                    '${item.name} (${dmEd.name}) L$castLevel "$rf": expected null for unreadable formula, got ${res.formulaString}',
                  );
                }
                continue;
              }

              if (res == null) {
                mismatches.add(
                  '${item.name} (${dmEd.name}) L$castLevel "$rf": returned null unexpectedly',
                );
                continue;
              }

              // Expected dice per sides (base + explicit scalingFormula if present,
              // or higherLevelsMarkdown first match when no scalingFormula).
              final expectedDiceList = <({int sides, int count})>[
                for (final dt in baseExpr.diceTerms)
                  (sides: dt.sides, count: dt.count),
              ];
              var expectedMod =
                  baseExpr.constantSum + (_signedModCount(baseExpr) * 3);

              if (delta > 0) {
                if (scaleExpr != null) {
                  for (final st in scaleExpr.diceTerms) {
                    expectedDiceList
                        .add((sides: st.sides, count: st.count * delta));
                  }
                  expectedMod += delta *
                      (scaleExpr.constantSum + (_signedModCount(scaleExpr) * 3));
                } else if (domainSpell.higherLevelsMarkdown != null) {
                  final proseMatch =
                      DiceExpression.findAll(domainSpell.higherLevelsMarkdown!)
                          .firstOrNull;
                  if (proseMatch != null &&
                      !proseMatch.expression.diceTerms
                          .any((t) => t.isNegative)) {
                    for (final st in proseMatch.expression.diceTerms) {
                      expectedDiceList
                          .add((sides: st.sides, count: st.count * delta));
                    }
                    expectedMod += delta *
                        (proseMatch.expression.constantSum +
                            (_signedModCount(proseMatch.expression) * 3));
                  }
                }
              }

              final expectedDice = _sumBySides(expectedDiceList);
              final actualDice = _sumBySides([
                for (final e in res.diceEntries) (sides: e.sides, count: e.count),
              ]);

              if (actualDice.toString() != expectedDice.toString() ||
                  res.modifier != expectedMod) {
                mismatches.add(
                  '${item.name} (${dmEd.name}) L$castLevel "$rf": '
                  'expected dice=$expectedDice mod=$expectedMod, '
                  'got dice=$actualDice mod=${res.modifier}',
                );
              }
            }
          }
        }

        expect(
          mismatches,
          isEmpty,
          reason: 'Bundled spell mismatches (${mismatches.length}):\n'
              '${mismatches.join('\n')}',
        );
      },
    );
  });

  group('Fix 3.2 & 3.3 Law 2: generated formulas never partially roll', () {
    test(
      '520 seeded generated formulas + fixed edge cases: either null (no slot/broadcast) or exact match',
      () async {
        // Fixed case 1: '1d8 + spellmod' must be rejected as unreadable.
        {
          configureTestDiceRoomService();
          final room = DiceRoomService();
          final beforeRolls = room.getCachedRolls('LOCAL').length;
          final ctrl = CharacterSheetController(
            character: _makeCleric(edition: RulesetEdition.v2024, wisdomScore: 16),
            persistenceService: _MemoryRepo(),
            replicaId: _lawReplica,
          );
          final beforeSlots = ctrl.character.resources.spellSlots.currentSlots[1];
          final res = await ctrl.castSpell(
            _customSpell(formula: '1d8 + spellmod'),
            castLevel: 1,
          );
          expect(res, isNull, reason: '1d8 + spellmod must return null');
          expect(
            ctrl.character.resources.spellSlots.currentSlots[1],
            equals(beforeSlots),
          );
          expect(room.getCachedRolls('LOCAL').length, equals(beforeRolls));
        }

        // Fixed case 2: '1d8 + mod' with no spellcasting class must return null.
        {
          configureTestDiceRoomService();
          final room = DiceRoomService();
          final beforeRolls = room.getCachedRolls('LOCAL').length;
          final ctrl = CharacterSheetController(
            character: _makeFighterNonCaster(RulesetEdition.v2024),
            persistenceService: _MemoryRepo(),
            replicaId: _lawReplica,
          );
          final beforeSlots = ctrl.character.resources.spellSlots.currentSlots[1];
          final res = await ctrl.castSpell(
            _customSpell(formula: '1d8 + mod'),
            castLevel: 1,
          );
          expect(
            res,
            isNull,
            reason: '1d8 + mod with no spellcasting class must return null',
          );
          expect(
            ctrl.character.resources.spellSlots.currentSlots[1],
            equals(beforeSlots),
          );
          expect(room.getCachedRolls('LOCAL').length, equals(beforeRolls));
        }

        // 520 seeded generated formulas.
        final rng = Random(140303);
        const sidesPool = [4, 6, 8, 10, 12];
        const wordPool = ['fire', 'cold', 'radiant', 'spellmod', 'bonus', 'str'];
        const wisScores = [8, 10, 12, 14, 16, 18, 20]; // modifiers -1..+5

        for (var seed = 0; seed < 520; seed++) {
          final wisScore = wisScores[rng.nextInt(wisScores.length)];
          final casterMod = (wisScore - 10) ~/ 2;

          final parts = <({String text, String kind, int count, int sides, int value, bool isNeg})>[];
          final numParts = 1 + rng.nextInt(4);

          for (var p = 0; p < numParts; p++) {
            final isNeg = p > 0 && rng.nextInt(4) == 0;
            final pick = rng.nextInt(4);
            if (pick == 0) {
              final c = 1 + rng.nextInt(4);
              final s = sidesPool[rng.nextInt(sidesPool.length)];
              parts.add((text: '${c}d$s', kind: 'dice', count: c, sides: s, value: 0, isNeg: isNeg));
            } else if (pick == 1) {
              final v = 1 + rng.nextInt(10);
              parts.add((text: '$v', kind: 'const', count: 0, sides: 0, value: v, isNeg: isNeg));
            } else if (pick == 2) {
              parts.add((text: 'mod', kind: 'mod', count: 0, sides: 0, value: 0, isNeg: isNeg));
            } else {
              final w = wordPool[rng.nextInt(wordPool.length)];
              parts.add((text: w, kind: 'word', count: 0, sides: 0, value: 0, isNeg: isNeg));
            }
          }

          final buf = StringBuffer();
          var hasSignedWord = false;
          var hasNegDice = false;
          var hasAnyDiceOrConstOrMod = false;
          final expectedDiceList = <({int sides, int count})>[];
          var expectedFlat = 0;
          var expectedModTerms = 0;

          for (var p = 0; p < parts.length; p++) {
            final part = parts[p];
            final spaced = rng.nextBool();
            if (p > 0) {
              final useSign = part.kind != 'word' || rng.nextBool();
              if (useSign) {
                final sign = part.isNeg ? '-' : '+';
                buf.write(spaced ? ' $sign ' : sign);
                if (part.kind == 'word') hasSignedWord = true;
                if (parts[p - 1].kind == 'word') hasSignedWord = true;
              } else {
                buf.write(' ');
              }
            }
            buf.write(part.text);

            if (part.kind == 'dice') {
              hasAnyDiceOrConstOrMod = true;
              if (part.isNeg) {
                hasNegDice = true;
              } else {
                expectedDiceList.add((sides: part.sides, count: part.count));
              }
            } else if (part.kind == 'const') {
              hasAnyDiceOrConstOrMod = true;
              expectedFlat += part.isNeg ? -part.value : part.value;
            } else if (part.kind == 'mod') {
              hasAnyDiceOrConstOrMod = true;
              expectedModTerms += part.isNeg ? -1 : 1;
            }
          }

          final formula = buf.toString();
          configureTestDiceRoomService();
          final room = DiceRoomService();
          final beforeRolls = room.getCachedRolls('LOCAL').length;
          final ctrl = CharacterSheetController(
            character: _makeCleric(
              edition: RulesetEdition.v2024,
              wisdomScore: wisScore,
            ),
            persistenceService: _MemoryRepo(),
            replicaId: _lawReplica,
          );
          final beforeSlots = ctrl.character.resources.spellSlots.currentSlots[1];

          final res = await ctrl.castSpell(
            _customSpell(formula: formula),
            castLevel: 1,
          );

          if (res == null) {
            expect(
              ctrl.character.resources.spellSlots.currentSlots[1],
              equals(beforeSlots),
              reason: 'seed=$seed formula="$formula": null roll must not spend slot',
            );
            expect(
              room.getCachedRolls('LOCAL').length,
              equals(beforeRolls),
              reason: 'seed=$seed formula="$formula": null roll must not broadcast',
            );
          } else {
            expect(
              hasSignedWord,
              isFalse,
              reason:
                  'seed=$seed formula="$formula": signed word must not partially roll (got ${res.formulaString})',
            );
            expect(
              hasNegDice,
              isFalse,
              reason:
                  'seed=$seed formula="$formula": negative die must not roll',
            );
            expect(
              hasAnyDiceOrConstOrMod,
              isTrue,
              reason: 'seed=$seed formula="$formula": no dice/const/mod',
            );

            final expectedDice = _sumBySides(expectedDiceList);
            final actualDice = _sumBySides([
              for (final e in res.diceEntries) (sides: e.sides, count: e.count),
            ]);
            final expectedModifier =
                expectedFlat + (expectedModTerms * casterMod);

            expect(
              actualDice,
              equals(expectedDice),
              reason:
                  'seed=$seed formula="$formula" wis=$wisScore (mod $casterMod): dice mismatch',
            );
            expect(
              res.modifier,
              equals(expectedModifier),
              reason:
                  'seed=$seed formula="$formula" wis=$wisScore (mod $casterMod): modifier mismatch',
            );
          }
        }
      },
    );

    test(
      'multiclass caster picks the first spellcasting class whose spell list holds the spell, else primary',
      () async {
        // Wizard (INT 18 -> +4) / Cleric (WIS 14 -> +2)
        final multi = Character(
          id: const EntityId(slug: 'wiz-cleric', ruleset: RulesetVersion.v2024),
          name: 'Wizard Cleric',
          rulesEdition: RulesetEdition.v2024,
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
                level: 3,
                hitDie: 'd6',
                isStartingClass: true,
              ),
              ClassLevelProgression(
                classRef: EntityReference.empty(
                  refType: EntityType.classDefinition,
                  slug: 'cleric',
                  displayName: 'Cleric',
                ),
                level: 3,
                hitDie: 'd8',
              ),
            ],
          ),
          baseScores: const AbilityScores(intelligence: 18, wisdom: 14),
          resources: const CharacterResourcePool(
            currentHp: 35,
            spellSlots: SpellSlotPool(
              maxSlots: {1: 4, 2: 3, 3: 3},
              currentSlots: {1: 4, 2: 3, 3: 3},
            ),
          ),
        );

        final ctrl = CharacterSheetController(
          character: multi,
          persistenceService: _MemoryRepo(),
          replicaId: _lawReplica,
        );

        // Cure Wounds is on Cleric list (not Wizard) -> must use Cleric WIS +2.
        final cureWoundsItem = SpellbookLibrary.getSpellByName('Cure Wounds')!;
        final cureWoundsSpell = _domainSpellFromItem(
          cureWoundsItem,
          DmRulesEdition.v2024,
        );
        final cwRes = await ctrl.castSpell(cureWoundsSpell, castLevel: 1);
        expect(cwRes, isNotNull);
        expect(cwRes!.modifier, equals(2));

        // Unlisted custom spell with mod -> falls back to primary (Wizard INT +4).
        final customRes = await ctrl.castSpell(
          _customSpell(formula: '1d8 + mod'),
          castLevel: 1,
        );
        expect(customRes, isNotNull);
        expect(customRes!.modifier, equals(4));
      },
    );
  });
}
