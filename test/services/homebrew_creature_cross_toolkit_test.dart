import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/arena_combatant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/monster_codex_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/arena/arena_monster_picker_sheet.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/monster_codex/monster_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  group('Homebrew Creature Cross-Toolkit Integration Tests', () {
    const customBeast = Monster(
      id: EntityId(slug: 'dire-timber-wolf', ruleset: RulesetVersion.homebrew),
      name: 'Dire Timber Wolf',
      size: 'Large',
      monsterType: 'Beast',
      alignment: 'Unaligned',
      armorClass: 15,
      hitPoints: 45,
      hitDieFormula: '6d10+12',
      challengeRating: '1',
      actionsMarkdown:
          '**Bite**: Melee Weapon Attack: +6 to hit, reach 5 ft., one target. Hit: 10 (2d6 + 4) piercing damage.\n\n**Pack Tactics**: The wolf has advantage on attack rolls against a creature if at least one ally is within 5 ft.',
      customProperties: {
        'strScore': 18,
        'dexScore': 14,
        'conScore': 15,
        'speed': '50 ft.',
      },
    );

    const customDragon = Monster(
      id: EntityId(slug: 'astral-drake', ruleset: RulesetVersion.homebrew),
      name: 'Astral Drake',
      size: 'Huge',
      monsterType: 'Dragon',
      alignment: 'Chaotic Neutral',
      armorClass: 18,
      hitPoints: 136,
      hitDieFormula: '13d12+52',
      challengeRating: '8',
      actionsMarkdown:
          '**Multiattack**: The drake makes three attacks: one with its bite and two with its claws.\n\n**Bite**: Melee Weapon Attack: +9 to hit, reach 10 ft., one target. Hit: 17 (2d10 + 6) piercing damage.\n\n**Astral Breath (Recharge 5-6)**: Exhales starlight in a 30-foot cone dealing 42 (12d6) radiant damage.',
      customProperties: {
        'strScore': 22,
        'dexScore': 12,
        'conScore': 18,
        'speed': '40 ft., fly 80 ft.',
      },
    );

    test('converts domain Monster into MinionStatBlock and MonsterItem accurately', () {
      final statBlock = customBeast.toMinionStatBlock();
      expect(statBlock.id, equals('dire-timber-wolf'));
      expect(statBlock.name, equals('Dire Timber Wolf'));
      expect(statBlock.sizeDisplay, equals('Large'));
      expect(statBlock.typeDisplay, equals('Beast'));
      expect(statBlock.ac, equals(15));
      expect(statBlock.maxHp, equals(45));
      expect(statBlock.crDisplay, equals('CR 1'));
      expect(statBlock.crValue, equals(1.0));
      expect(statBlock.attackBonus, equals(6));
      expect(statBlock.damageDiceCount, equals(2));
      expect(statBlock.damageDiceSides, equals(6));
      expect(statBlock.damageBonus, equals(4));
      expect(statBlock.damageType, equals('Piercing'));
      expect(statBlock.hasPackTactics, isTrue);
      expect(statBlock.speed, equals('50 ft.'));

      final monsterItem = customBeast.toMonsterItem();
      expect(monsterItem.isHomebrew, isTrue);
      expect(monsterItem.sourcePresetId, equals('homebrew'));
      expect(monsterItem.challengeRating, equals(1.0));
    });

    test('parses ### markdown headers without colon into named traits and actions', () {
      const headingMonster = Monster(
        id: EntityId(slug: 'shadow-stalker', ruleset: RulesetVersion.homebrew),
        name: 'Shadow Stalker',
        size: 'Medium',
        monsterType: 'Monstrosity',
        alignment: 'Neutral Evil',
        armorClass: 14,
        hitPoints: 32,
        hitDieFormula: '5d8+10',
        challengeRating: '2',
        actionsMarkdown: '''
### Traits
### Pack Tactics
The stalker has advantage on an attack roll against a creature if at least one ally is within 5 ft.

### Keen Smell
The stalker has advantage on Wisdom (Perception) checks that rely on smell.

### Actions
### Bite
Melee Weapon Attack: +5 to hit, reach 5 ft., one target. Hit: 8 (1d8 + 3) piercing damage.
''',
      );

      final statBlock = headingMonster.toMinionStatBlock();

      // Traits should be parsed with their exact names (NOT 'Feature')
      expect(statBlock.traits.length, equals(2));
      expect(statBlock.traits[0].name, equals('Pack Tactics'));
      expect(statBlock.traits[0].description, contains('advantage on an attack roll'));
      expect(statBlock.traits[1].name, equals('Keen Smell'));
      expect(statBlock.traits[1].description, contains('Wisdom (Perception) checks'));

      // Actions should be parsed cleanly without section headers
      expect(statBlock.actions.length, equals(1));
      expect(statBlock.actions[0].name, equals('Bite'));
      expect(statBlock.actions[0].attackBonus, equals(5));
      expect(statBlock.actions[0].reach, equals('5 ft.'));
      expect(statBlock.actions[0].hitDamage, contains('8 (1d8 + 3) piercing damage'));

      // Primary attack math
      expect(statBlock.attackBonus, equals(5));
      expect(statBlock.damageDiceCount, equals(1));
      expect(statBlock.damageDiceSides, equals(8));
      expect(statBlock.damageBonus, equals(3));
      expect(statBlock.damageType, equals('Piercing'));
      expect(statBlock.hasPackTactics, isTrue);
    });

    test('HomebrewPersistenceService syncs to MonsterCodexLibrary dynamically', () async {
      final service = HomebrewPersistenceService();
      await service.saveCustomMonster(customBeast);
      await service.saveCustomMonster(customDragon);

      expect(MonsterCodexLibrary.homebrewMonsters.length, equals(2));
      expect(MonsterCodexLibrary.getMonsterById('dire-timber-wolf'), isNotNull);
      expect(MonsterCodexLibrary.getMonsterById('astral-drake'), isNotNull);
      expect(MonsterCodexLibrary.getMonsterByName('Dire Timber Wolf'), isNotNull);

      // Deletion test
      await service.deleteCustomMonster('astral-drake');
      expect(MonsterCodexLibrary.getMonsterById('astral-drake'), isNull);
      expect(MonsterCodexLibrary.getMonsterById('dire-timber-wolf'), isNotNull);
    });

    test('Conjure Animals dynamically includes homebrew beasts with CR <= 2', () async {
      final service = HomebrewPersistenceService();
      await service.saveCustomMonster(customBeast);
      await service.saveCustomMonster(customDragon);

      const animalsPreset = BeastSummons.conjureAnimalsPreset;
      final effectiveCreatures = animalsPreset.effectiveStatBlocks;

      // Dire Timber Wolf is a Beast with CR 1, so it MUST appear in Conjure Animals!
      expect(
        effectiveCreatures.any((sb) => sb.id == 'dire-timber-wolf' && sb.name == 'Dire Timber Wolf'),
        isTrue,
      );

      // Astral Drake is a Dragon (CR 8), so it must NOT appear in Conjure Animals
      expect(
        effectiveCreatures.any((sb) => sb.id == 'astral-drake'),
        isFalse,
      );

      // SrdSummonsLibrary findStatBlock lookups work
      final foundWolf = SrdSummonsLibrary.findStatBlockById('dire-timber-wolf');
      expect(foundWolf, isNotNull);
      expect(foundWolf!.name, equals('Dire Timber Wolf'));
    });

    testWidgets('Monster Codex Screen displays Homebrew creatures with HOMEBREW badge and filter',
        (tester) async {
      await HomebrewPersistenceService().saveCustomMonster(customBeast);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScope(
            notifier: SettingsProvider(initialSettings: const AppSettings()),
            child: const MonsterCodexScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for our custom creature
      await tester.enterText(find.byType(TextField), 'Dire Timber Wolf');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MonsterCard, 'Dire Timber Wolf'), findsOneWidget);
      expect(find.text('HOMEBREW'), findsOneWidget);

      // Switch to Homebrew view mode tab
      await tester.tap(find.text('Homebrew (1)'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(MonsterCard, 'Dire Timber Wolf'), findsOneWidget);
    });

    testWidgets('Arena Monster Picker Sheet lists Homebrew creatures for simulation',
        (tester) async {
      await HomebrewPersistenceService().saveCustomMonster(customDragon);

      MonsterItem? selectedMonster;
      int selectedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  ArenaMonsterPickerSheet.show(
                    context,
                    team: ArenaTeam.teamA,
                    edition: DmRulesEdition.v2024,
                    onMonstersSelected: (monster, count) {
                      selectedMonster = monster;
                      selectedCount = count;
                    },
                  );
                },
                child: const Text('OPEN PICKER'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN PICKER'));
      await tester.pumpAndSettle();

      // Search for custom dragon in picker
      await tester.enterText(find.byType(TextField), 'Astral Drake');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Astral Drake'), findsOneWidget);
      expect(find.text('HOMEBREW'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Astral Drake'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ADD TO TEAM CRIMSON'));
      await tester.pumpAndSettle();

      expect(selectedMonster?.id, equals('astral-drake'));
      expect(selectedCount, equals(1));
    });
  });
}
