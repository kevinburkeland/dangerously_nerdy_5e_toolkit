import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';

import '../test_doubles/service_test_configurator.dart';

final _charReplica = ReplicaId('spell_mod_characterization_replica');

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

Character _makeClericWis16(RulesetEdition edition) => Character(
      id: EntityId(
        slug: 'cleric-wis16',
        ruleset: edition == RulesetEdition.v2024
            ? RulesetVersion.v2024
            : RulesetVersion.v2014,
      ),
      name: 'Cleric WIS 16',
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
            level: 11,
            hitDie: 'd8',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: const AbilityScores(wisdom: 16), // +3 modifier
      resources: const CharacterResourcePool(
        currentHp: 60,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1},
          currentSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1},
        ),
      ),
    );

Character _makeNonCaster(RulesetEdition edition) => Character(
      id: EntityId(
        slug: 'fighter-noncaster',
        ruleset: edition == RulesetEdition.v2024
            ? RulesetVersion.v2024
            : RulesetVersion.v2014,
      ),
      name: 'Fighter Non-Caster',
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
            level: 11,
            hitDie: 'd10',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: const AbilityScores(strength: 16, wisdom: 16),
      resources: const CharacterResourcePool(
        currentHp: 80,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1},
          currentSlots: {1: 4, 2: 3, 3: 3, 4: 3, 5: 2, 6: 1},
        ),
      ),
    );

Spell _domainSpellFromItem(Spell item, DmRulesEdition edition) {
  final rules = item.getRules(edition);
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
    rules2014: rules,
    rules2024: rules,
    damageMath: (rules.rollFormula != null &&
            rules.rollFormula!.trim().isNotEmpty &&
            rules.rollFormula!.trim().toLowerCase() != 'none')
        ? [
            EvaluationMath(
              diceFormula: rules.rollFormula!,
              damageType: DamageType.untyped,
              scalingFormula: rules.scalingFormula != null
                  ? '+${rules.scalingFormula!.dicePerSlotLevel}d${rules.scalingFormula!.diceSides}'
                  : null,
            ),
          ]
        : const [],
    customProperties: {
      if (rules.rollFormula != null) 'rollFormula': rules.rollFormula,
      if (rules.scalingFormula != null)
        'scalingFormula':
            '+${rules.scalingFormula!.dicePerSlotLevel}d${rules.scalingFormula!.diceSides}',
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureTestCampaignProfileService();
    configureTestDiceRoomService();
  });

  group('Cleanup slice 14 Step 3 characterization: bundled mod spells', () {
    test(
      'characterizes castSpell for WIS 16 Cleric and non-spellcaster on all bundled mod spells (both editions, base and +1 level)',
      () async {
        // Collect every bundled spell with 'mod' in rollFormula in either edition.
        final cases = <(Spell, DmRulesEdition, String)>[];
        for (final item in SpellbookLibrary.srdSpells) {
          for (final dmEd in const [DmRulesEdition.v2014, DmRulesEdition.v2024]) {
            final rf = item.getRules(dmEd).rollFormula;
            if (rf != null && RegExp(r'\bmod\b', caseSensitive: false).hasMatch(rf)) {
              cases.add((item, dmEd, rf));
            }
          }
        }

        // Expect all 15 bundled rollFormula entries with 'mod'.
        expect(cases.length, equals(15));

        for (final (item, dmEd, rawFormula) in cases) {
          final rulesEd = dmEd == DmRulesEdition.v2024
              ? RulesetEdition.v2024
              : RulesetEdition.v2014;
          final domainSpell = _domainSpellFromItem(item, dmEd);
          final castLevels =
              item.level == 0 ? <int>[0] : <int>[item.level, item.level + 1];

          for (final isCaster in const [true, false]) {
            for (final castLevel in castLevels) {
              configureTestDiceRoomService();
              final fakeRoom = DiceRoomService();
              final broadcastCountBefore =
                  fakeRoom.getCachedRolls('LOCAL').length;

              final character =
                  isCaster ? _makeClericWis16(rulesEd) : _makeNonCaster(rulesEd);
              final ctrl = CharacterSheetController(
                character: character,
                persistenceService: _MemoryRepo(),
                replicaId: _charReplica,
              );

              final slotsBefore = castLevel > 0
                  ? (ctrl.character.resources.spellSlots.currentSlots[castLevel] ?? 0)
                  : 0;

              final res = await ctrl.castSpell(domainSpell, castLevel: castLevel);

              final slotsAfter = castLevel > 0
                  ? (ctrl.character.resources.spellSlots.currentSlots[castLevel] ?? 0)
                  : 0;
              final slotSpent = castLevel > 0 ? (slotsBefore - slotsAfter == 1) : false;
              final broadcastCountAfter =
                  fakeRoom.getCachedRolls('LOCAL').length;
              final broadcast = broadcastCountAfter > broadcastCountBefore;

              if (isCaster) {
                // After Fix 3.2: WIS 16 Cleric resolves mod to +3 (and Barkskin 10 + 3 = 13).
                expect(
                  res,
                  isNotNull,
                  reason: '${item.id} (${dmEd.name}) L$castLevel caster=$isCaster',
                );
                expect(broadcast, isTrue);
                expect(slotSpent, equals(castLevel > 0));

                if (item.name.toLowerCase() == 'barkskin') {
                  expect(res!.diceEntries, isEmpty);
                  expect(res.modifier, equals(13));
                } else {
                  expect(
                    res!.diceEntries,
                    isNotEmpty,
                    reason: '${item.id} (${dmEd.name}) "$rawFormula" L$castLevel',
                  );
                  expect(
                    res.modifier,
                    equals(3),
                    reason:
                        'After Fix 3.2, ${item.id} (${dmEd.name}) "$rawFormula" adds WIS +3',
                  );
                }
              } else {
                // After Fix 3.2: non-spellcaster cannot roll mod formulas; no slot spent, no broadcast.
                expect(
                  res,
                  isNull,
                  reason: '${item.id} (${dmEd.name}) L$castLevel non-caster must return null',
                );
                expect(broadcast, isFalse);
                expect(slotSpent, isFalse);
                expect(
                  ctrl.lastCastError,
                  equals('Can\'t roll "$rawFormula": no spellcasting modifier'),
                );
              }
            }
          }
        }
      },
    );
  });
}
