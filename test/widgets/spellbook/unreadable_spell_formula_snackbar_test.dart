import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/interactive_spell_tile.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_card.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';

import '../../test_doubles/service_test_configurator.dart';

final _widgetReplica = ReplicaId('unreadable_formula_widget_replica');

class _FakeRepo implements ICharacterRepository<Character> {
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
      id: const EntityId(slug: 'widget-caster', ruleset: RulesetVersion.v2024),
      name: 'Widget Caster',
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
        ],
      ),
      baseScores: const AbilityScores(intelligence: 16),
      resources: const CharacterResourcePool(
        currentHp: 20,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4},
          currentSlots: {1: 4},
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    configureTestCampaignProfileService();
    configureTestDiceRoomService();
  });

  testWidgets('InteractiveSpellTile shows SnackBar on unreadable spell formula', (tester) async {
    final controller = CharacterSheetController(
      replicaId: _widgetReplica,
      character: _makeCaster(),
      persistenceService: _FakeRepo(),
    );
    const badSpell = Spell(
      id: EntityId(slug: 'bad-formula-spell', ruleset: RulesetVersion.v2024),
      name: 'Broken Bolt',
      level: 0,
      school: 'evocation',
      castingTime: CastingTime(cost: 1, actionType: ActionType.action),
      duration: SpellDuration(type: DurationType.instantaneous),
      range: '60 feet',
      components: SpellComponents(v: true),
      descriptionMarkdown: 'Malformed homebrew formula.',
      damageMath: [
        EvaluationMath(diceFormula: 'banana', damageType: DamageType.fire),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveSpellTile(
            spell: badSpell,
            controller: controller,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Broken Bolt'));
    await tester.pumpAndSettle();

    expect(
      find.text('Can\'t roll "banana": not dice notation'),
      findsOneWidget,
    );
  });

  testWidgets('SpellCard shows SnackBar on unreadable spell formula', (tester) async {
    final controller = CharacterSheetController(
      replicaId: _widgetReplica,
      character: _makeCaster(),
      persistenceService: _FakeRepo(),
    );
    const badSpellItem = Spell(
      id: EntityId(slug: 'bad-card-spell', ruleset: RulesetVersion.v2024),
      name: 'Broken Cantrip',
      level: 0,
      school: 'evocation',
      schoolEnum: SpellSchool.evocation,
      castingTime: CastingTime(cost: 1, actionType: ActionType.action),
      duration: SpellDuration(type: DurationType.instantaneous),
      range: '60 feet',
      components: SpellComponents(v: true),
      descriptionMarkdown: 'A cantrip with a bad formula.',
      rules2014: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V',
        duration: 'Instantaneous',
        description: ['A cantrip with a bad formula.'],
        classes: [SpellClass.wizard],
        rollFormula: 'banana',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Action',
        range: '60 feet',
        components: 'V',
        duration: 'Instantaneous',
        description: ['A cantrip with a bad formula.'],
        classes: [SpellClass.wizard],
        rollFormula: 'banana',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpellCard(
            spell: badSpellItem,
            edition: DmRulesEdition.v2024,
            isPinned: false,
            onTap: () {},
            onTogglePin: () {},
            controller: controller,
          ),
        ),
      ),
    );

    final castBtn = find.text('Cast');
    expect(castBtn, findsOneWidget);
    await tester.tap(castBtn);
    await tester.pumpAndSettle();

    expect(
      find.text('Can\'t roll "banana": not dice notation'),
      findsOneWidget,
    );
  });

  Character makeNonCaster() => Character(
        id: const EntityId(slug: 'widget-fighter', ruleset: RulesetVersion.v2024),
        name: 'Widget Fighter',
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
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(strength: 16, wisdom: 16),
        resources: const CharacterResourcePool(
          currentHp: 30,
          spellSlots: SpellSlotPool(
            maxSlots: {1: 4},
            currentSlots: {1: 4},
          ),
        ),
      );

  testWidgets(
      'InteractiveSpellTile shows SnackBar when mod spell cast with no spellcasting modifier',
      (tester) async {
    final controller = CharacterSheetController(
      replicaId: _widgetReplica,
      character: makeNonCaster(),
      persistenceService: _FakeRepo(),
    );
    const modSpell = Spell(
      id: EntityId(slug: 'shillelagh-test', ruleset: RulesetVersion.v2024),
      name: 'Mod Cantrip',
      level: 0,
      school: 'transmutation',
      castingTime: CastingTime(cost: 1, actionType: ActionType.bonusAction),
      duration: SpellDuration(type: DurationType.instantaneous),
      range: 'Touch',
      components: SpellComponents(v: true),
      descriptionMarkdown: 'Requires spellcasting modifier.',
      damageMath: [
        EvaluationMath(diceFormula: '1d8 + mod', damageType: DamageType.bludgeoning),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveSpellTile(
            spell: modSpell,
            controller: controller,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mod Cantrip'));
    await tester.pumpAndSettle();

    expect(
      find.text('Can\'t roll "1d8 + mod": no spellcasting modifier'),
      findsOneWidget,
    );
  });

  testWidgets(
      'SpellCard shows SnackBar when mod spell cast with no spellcasting modifier',
      (tester) async {
    final controller = CharacterSheetController(
      replicaId: _widgetReplica,
      character: makeNonCaster(),
      persistenceService: _FakeRepo(),
    );
    const modSpellItem = Spell(
      id: EntityId(slug: 'mod-card-spell', ruleset: RulesetVersion.v2024),
      name: 'Mod Cantrip Card',
      level: 0,
      school: 'transmutation',
      schoolEnum: SpellSchool.transmutation,
      castingTime: CastingTime(cost: 1, actionType: ActionType.bonusAction),
      duration: SpellDuration(type: DurationType.timed, durationSeconds: 60),
      range: 'Touch',
      components: SpellComponents(v: true),
      descriptionMarkdown: 'A cantrip using mod.',
      rules2014: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: 'Touch',
        components: 'V',
        duration: '1 minute',
        description: ['A cantrip using mod.'],
        classes: [SpellClass.druid],
        rollFormula: '1d8 + mod',
      ),
      rules2024: SpellEditionDetails(
        castingTime: '1 Bonus Action',
        range: 'Touch',
        components: 'V',
        duration: '1 minute',
        description: ['A cantrip using mod.'],
        classes: [SpellClass.druid],
        rollFormula: '1d8 + mod',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpellCard(
            spell: modSpellItem,
            edition: DmRulesEdition.v2024,
            isPinned: false,
            onTap: () {},
            onTogglePin: () {},
            controller: controller,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cast'));
    await tester.pumpAndSettle();

    expect(
      find.text('Can\'t roll "1d8 + mod": no spellcasting modifier'),
      findsOneWidget,
    );
  });
}
