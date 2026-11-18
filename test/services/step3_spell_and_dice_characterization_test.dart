import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/candidate_identification.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_candidate.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_field.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_span.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_class_field_extractor.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/simulation/precomputed_attack.dart';

import '../test_doubles/service_test_configurator.dart';

final _testReplica = ReplicaId('step3_char_replica');

class _InMemoryRepo implements ICharacterRepository<Character> {
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

Character _makeCaster() => const Character(
      id: EntityId(slug: 'step3-caster', ruleset: RulesetVersion.v2024),
      name: 'Step3 Caster',
      speciesRef: EntityReference.empty(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      progression: CharacterProgression(
        classes: [
          ClassLevelProgression(
            classRef: EntityReference.empty(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 5,
            hitDie: 'd6',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: AbilityScores(intelligence: 18, charisma: 14),
      resources: CharacterResourcePool(
        currentHp: 30,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4, 2: 3, 3: 2},
          currentSlots: {1: 4, 2: 3, 3: 2},
        ),
      ),
    );

Spell _makeSpell({
  String? formula,
  String? scalingFormula,
  int level = 1,
}) {
  return Spell(
    id: const EntityId(slug: 'step3-spell', ruleset: RulesetVersion.v2024),
    name: 'Step3 Spell',
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
    descriptionMarkdown: 'Characterization test spell.',
    damageMath: formula == null
        ? const []
        : [
            EvaluationMath(
              diceFormula: formula,
              scalingFormula: scalingFormula,
              damageType: DamageType.force,
            ),
          ],
  );
}

List<String> _entryPairs(List<dynamic> entries) =>
    entries.map((e) => '${e.count}d${e.sides}').toList();

SourceBlock _makeBlock(String text) => SourceBlock(
      id: 'b-${text.hashCode}',
      rawText: text,
      normalizedText: text,
      span: const SourceSpan.empty(),
    );

MinionStatBlock _makeMinion(List<CreatureAction> actions) => MinionStatBlock(
      id: 'step3-minion',
      name: 'Step3 Minion',
      sizeDisplay: 'Medium',
      crDisplay: '1',
      typeDisplay: 'Beast',
      alignment: 'unaligned',
      ac: 12,
      maxHp: 20,
      speed: '30 ft.',
      strScore: 14,
      dexScore: 12,
      conScore: 12,
      intScore: 4,
      wisScore: 10,
      chaScore: 6,
      attackBonus: 4,
      damageDiceCount: 1,
      damageDiceSides: 6,
      damageBonus: 2,
      damageType: 'Slashing',
      actions: actions,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureTestCampaignProfileService();
    configureTestDiceRoomService();
  });

  group('Step 3 Characterization: castSpell baseline behavior', () {
    final baseCases = <(String label, String? formula, List<String> expectedAtBase, int expectedMod)>[
      ('2d6', '2d6', ['2d6'], 0),
      ('2d6 + 1d8', '2d6 + 1d8', ['2d6'], 0),
      ('1d4 + 1', '1d4 + 1', ['1d4'], 0),
      ('3d4 + 3', '3d4 + 3', ['3d4'], 0),
      ('8d6', '8d6', ['8d6'], 0),
      ('1d10 + 1d6 + 2', '1d10 + 1d6 + 2', ['1d10'], 0),
      ('2d6 fire', '2d6 fire', ['2d6'], 0),
      ('no formula', null, [], 0),
      ('garbage', 'banana', [], 0),
    ];

    test('castSpell at base level records dice entries, modifier, broadcast, and slot spend', () async {
      for (final (label, formula, expectedEntries, expectedMod) in baseCases) {
        configureTestDiceRoomService();
        final room = DiceRoomService();
        final beforeRolls = room.getCachedRolls('LOCAL').length;
        final ctrl = CharacterSheetController(
          replicaId: _testReplica,
          character: _makeCaster(),
          persistenceService: _InMemoryRepo(),
        );

        final res = await ctrl.castSpell(_makeSpell(formula: formula), castLevel: 1);
        expect(res, isNotNull, reason: 'base case $label');
        expect(_entryPairs(res!.diceEntries), equals(expectedEntries), reason: 'entries for $label');
        expect(res.modifier, equals(expectedMod), reason: 'modifier for $label');
        expect(room.getCachedRolls('LOCAL').length, equals(beforeRolls + 1), reason: 'broadcast for $label');
        expect(ctrl.character.resources.spellSlots.currentSlots[1], equals(3), reason: 'slot spent for $label');
      }
    });

    test('castSpell upcast +2 with 1d6 and 1d6 + 1d4 scaling records baseline dice entries', () async {
      for (final scaling in ['1d6', '1d6 + 1d4']) {
        for (final (label, formula, baseEntries, _) in baseCases) {
          configureTestDiceRoomService();
          final room = DiceRoomService();
          final beforeRolls = room.getCachedRolls('LOCAL').length;
          final ctrl = CharacterSheetController(
            replicaId: _testReplica,
            character: _makeCaster(),
            persistenceService: _InMemoryRepo(),
          );

          final res = await ctrl.castSpell(
            _makeSpell(formula: formula, scalingFormula: scaling),
            castLevel: 3,
          );
          expect(res, isNotNull, reason: 'upcast ($scaling) case $label');
          final expected = baseEntries.isEmpty
              ? (formula == null ? <String>[] : ['2d6'])
              : baseEntries.first.endsWith('d6')
                  ? ['${int.parse(baseEntries.first.split('d').first) + 2}d6']
                  : [...baseEntries, '2d6'];
          expect(_entryPairs(res!.diceEntries), equals(expected), reason: 'entries for $label ($scaling)');
          expect(res.modifier, equals(0), reason: 'modifier for $label ($scaling)');
          expect(room.getCachedRolls('LOCAL').length, equals(beforeRolls + 1), reason: 'broadcast for $label ($scaling)');
          expect(ctrl.character.resources.spellSlots.currentSlots[3], equals(1), reason: 'slot 3 spent for $label ($scaling)');
        }
      }
    });
  });

  group('Step 3 Characterization: rollSpellDamage baseline behavior', () {
    test('rollSpellDamage outside a room keeps all terms and constantSum', () {
      final ctrl = CharacterSheetController(
        replicaId: _testReplica,
        character: _makeCaster(),
        persistenceService: _InMemoryRepo(),
      );

      final r1 = ctrl.rollSpellDamage(_makeSpell(formula: '2d6 + 1d8'));
      expect(_entryPairs(r1.diceEntries), equals(['2d6', '1d8']));
      expect(r1.modifier, equals(0));

      final r2 = ctrl.rollSpellDamage(_makeSpell(formula: '1d10 + 1d6 + 2'));
      expect(_entryPairs(r2.diceEntries), equals(['1d10', '1d6']));
      expect(r2.modifier, equals(2));

      final rGarbage = ctrl.rollSpellDamage(_makeSpell(formula: 'banana'));
      expect(rGarbage.diceEntries, isEmpty);
      expect(rGarbage.total, equals(0));
    });

    test('rollSpellDamage inside an active room throws StateError on garbage formula', () {
      final ctrl = CharacterSheetController(
        replicaId: _testReplica,
        character: _makeCaster(),
        persistenceService: _InMemoryRepo(),
      );
      DiceRoomService().joinRoom('ROOM1', 'Tester', remember: false);

      final rOk = ctrl.rollSpellDamage(_makeSpell(formula: '2d6 + 1d8'));
      expect(_entryPairs(rOk.diceEntries), equals(['2d6', '1d8']));

      expect(
        () => ctrl.rollSpellDamage(_makeSpell(formula: 'banana')),
        throwsStateError,
      );
    });
  });

  group('Step 3 Characterization: K1 .diceTerms.first sites', () {
    test('Dnd5eClassFieldExtractor hitDie extraction across 1-group, 2-group, negative, garbage', () {
      String? extract(String hitDieText) {
        final desc = const Dnd5eIngestionCapability().getTargetDescriptor('class')!;
        final result = const Dnd5eClassFieldExtractor().extract(
          blocks: [_makeBlock('Fighter'), _makeBlock('Hit Die: $hitDieText')],
          descriptor: desc,
        );
        return result.fields['hitDie']?.value as String?;
      }

      expect(extract('1d8'), equals('d8'));
      expect(extract('1d8 + 1d6'), equals('d8'));
      expect(extract('1d8 - 1d4'), equals('d8'));
      expect(extract('banana'), isNull);
    });

    test('Dnd5eIngestionCapability validateCandidate hitDie across 1-group, 2-group, negative, garbage', () {
      bool isHitDieValid(String val) {
        const span = SourceSpan.empty();
        final candidate = IngestionCandidate(
          id: 'cand-1',
          targetTypeKey: 'class',
          rawSource: 'class warrior',
          normalizedSource: 'class warrior',
          blocks: const [],
          identification: const CandidateIdentification(
            identifiedTypeKey: 'class',
            confidence: 1.0,
            evidence: [],
          ),
          span: span,
          fields: {
            'name': IngestionField<String>.extracted(
              key: 'name',
              label: 'Name',
              value: 'Warrior',
              rawText: 'Warrior',
              span: span,
              isRequired: true,
            ),
            'hitDie': IngestionField<String>.extracted(
              key: 'hitDie',
              label: 'Hit Die',
              value: val,
              rawText: val,
              span: span,
              isRequired: true,
            ),
            'primaryAbility': IngestionField<List<String>>.extracted(
              key: 'primaryAbility',
              label: 'Primary Ability',
              value: const ['Strength'],
              rawText: 'Strength',
              span: span,
              isRequired: true,
            ),
            'savingThrows': IngestionField<List<String>>.extracted(
              key: 'savingThrows',
              label: 'Saving Throws',
              value: const ['Strength', 'Constitution'],
              rawText: 'Strength, Constitution',
              span: span,
              isRequired: true,
            ),
          },
        );
        final res = const Dnd5eIngestionCapability().validateCandidate(candidate);
        return !res.blockingErrors.any((e) => e.contains('Hit Die'));
      }

      expect(isHitDieValid('1d8'), isTrue);
      expect(isHitDieValid('1d8 + 1d6'), isFalse);
      expect(isHitDieValid('1d8 - 1d4'), isFalse);
      expect(isHitDieValid('banana'), isFalse);
    });

    test('StatBlockAclParser AttributeDrainRider and PeriodicDamageRider across 1-group, 2-group, negative, garbage', () {
      final d1 = StatBlockAclParser.extractRiders(
        "The target's Strength score is reduced by 1d4 until a rest.",
      ).whereType<AttributeDrainRider>().toList();
      expect(d1.length, 1);
      expect((d1.first.diceCount, d1.first.diceSides), equals((1, 4)));

      final d2 = StatBlockAclParser.extractRiders(
        "The target's Strength score is reduced by 1d8 + 1d6 until a rest.",
      ).whereType<AttributeDrainRider>().toList();
      expect(d2.length, 1);
      expect((d2.first.diceCount, d2.first.diceSides), equals((1, 8)));

      final dNeg = StatBlockAclParser.extractRiders(
        "The target's Strength score is reduced by 1d8 - 1d4 until a rest.",
      ).whereType<AttributeDrainRider>().toList();
      expect(dNeg.length, 1);
      expect((dNeg.first.diceCount, dNeg.first.diceSides), equals((1, 8)));

      final dGarbage = StatBlockAclParser.extractRiders(
        "The target's Strength score is reduced by banana until a rest.",
      ).whereType<AttributeDrainRider>().toList();
      expect(dGarbage, isEmpty);

      final p1 = StatBlockAclParser.extractRiders(
        'The target takes 1d8 fire damage at the start of each of its turns.',
      ).whereType<PeriodicDamageRider>().toList();
      expect(p1.length, 1);
      expect((p1.first.diceCount, p1.first.diceSides), equals((1, 8)));

      final p2 = StatBlockAclParser.extractRiders(
        'The target takes 1d8 + 1d6 fire damage at the start of each of its turns.',
      ).whereType<PeriodicDamageRider>().toList();
      expect(p2.length, 1);
      expect((p2.first.diceCount, p2.first.diceSides), equals((1, 8)));

      final pNeg = StatBlockAclParser.extractRiders(
        'The target takes 1d8 - 1d4 fire damage at the start of each of its turns.',
      ).whereType<PeriodicDamageRider>().toList();
      expect(pNeg.length, 1);
      expect((pNeg.first.diceCount, pNeg.first.diceSides), equals((1, 8)));

      final pGarbage = StatBlockAclParser.extractRiders(
        'The target takes banana fire damage at the start of each of its turns.',
      ).whereType<PeriodicDamageRider>().toList();
      expect(pGarbage, isEmpty);
    });

    test('DprModels extractDprAttacks primary and secondary damage across 1-group, 2-group, negative, garbage', () {
      DprAttackAction parseAction(String hitDmg, String desc) {
        final block = _makeMinion([
          CreatureAction(name: 'Bite', hitDamage: hitDmg, description: desc),
        ]);
        return block.extractDprAttacks().first;
      }

      final a1 = parseAction(
        '1d8 + 2',
        'Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 6 (1d8 + 2) piercing damage plus 1d6 poison damage.',
      );
      expect((a1.diceCount, a1.diceSides, a1.damageBonus), equals((1, 8, 2)));
      expect((a1.secondaryDiceCount, a1.secondaryDiceSides), equals((1, 6)));

      final a2 = parseAction(
        '1d8 + 1d6',
        'Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 8 (1d8 + 1d6) piercing damage plus 1d8 + 1d4 poison damage.',
      );
      expect((a2.diceCount, a2.diceSides), equals((1, 8)));
      expect((a2.secondaryDiceCount, a2.secondaryDiceSides), equals((1, 8)));

      final aNeg = parseAction(
        '1d8 - 1d4',
        'Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 2 (1d8 - 1d4) piercing damage plus 1d8 - 1d4 poison damage.',
      );
      expect((aNeg.diceCount, aNeg.diceSides), equals((1, 8)));
      expect((aNeg.secondaryDiceCount, aNeg.secondaryDiceSides), equals((1, 8)));

      final aGarbage = parseAction(
        'banana',
        'Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: banana piercing damage plus banana poison damage.',
      );
      expect((aGarbage.diceCount, aGarbage.diceSides), equals((0, 0)));
      expect((aGarbage.secondaryDiceCount, aGarbage.secondaryDiceSides), equals((0, 0)));
    });

    test('Monster.toMinionStatBlock parsedActions and attackMath paths across 1-group, 2-group, negative, garbage', () {
      Monster makeActionMonster(String hitDmg) => Monster(
            id: const EntityId(slug: 'mon-arena-1', ruleset: RulesetVersion.v2024),
            name: 'Arena Beast',
            size: 'Medium',
            monsterType: 'beast',
            alignment: 'unaligned',
            armorClass: 12,
            hitPoints: 20,
            hitDieFormula: '3d8+6',
            challengeRating: '1',
            actionsMarkdown:
                '***Claw.*** *Melee Weapon Attack:* +4 to hit, reach 5 ft., one target. *Hit:* 7 ($hitDmg) slashing damage.',
            innateSpells: const [],
            attackMath: const [],
          );

      final c1 = makeActionMonster('1d8 + 2').toMinionStatBlock();
      expect((c1.damageDiceCount, c1.damageDiceSides, c1.damageBonus), equals((1, 8, 2)));

      final c2 = makeActionMonster('1d8 + 1d6').toMinionStatBlock();
      expect((c2.damageDiceCount, c2.damageDiceSides), equals((1, 8)));

      final cNeg = makeActionMonster('1d8 - 1d4').toMinionStatBlock();
      expect((cNeg.damageDiceCount, cNeg.damageDiceSides), equals((1, 8)));

      final cGarbage = makeActionMonster('banana').toMinionStatBlock();
      expect((cGarbage.damageDiceCount, cGarbage.damageDiceSides), equals((1, 6)));

      Monster makeMathMonster(String formula) => Monster(
            id: const EntityId(slug: 'mon-arena-2', ruleset: RulesetVersion.v2024),
            name: 'Arena Construct',
            size: 'Medium',
            monsterType: 'construct',
            alignment: 'unaligned',
            armorClass: 12,
            hitPoints: 20,
            hitDieFormula: '3d8+6',
            challengeRating: '1',
            actionsMarkdown: '',
            innateSpells: const [],
            attackMath: [
              EvaluationMath(diceFormula: formula, damageType: DamageType.bludgeoning),
            ],
          );

      final m1 = makeMathMonster('1d8 + 2').toMinionStatBlock();
      expect((m1.damageDiceCount, m1.damageDiceSides, m1.damageBonus), equals((1, 8, 2)));

      final m2 = makeMathMonster('1d8 + 1d6').toMinionStatBlock();
      expect((m2.damageDiceCount, m2.damageDiceSides), equals((1, 8)));

      final mNeg = makeMathMonster('1d8 - 1d4').toMinionStatBlock();
      expect((mNeg.damageDiceCount, m2.damageDiceSides), equals((1, 8)));

      final mGarbage = makeMathMonster('banana').toMinionStatBlock();
      expect((mGarbage.damageDiceCount, mGarbage.damageDiceSides), equals((1, 6)));
    });
  });
}
