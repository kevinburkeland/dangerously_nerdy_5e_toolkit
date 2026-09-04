import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/classes/class_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/classes/class_detail_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/feats/feat_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/feats/feat_detail_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/races/race_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/races/race_detail_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_header_banner.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_vitals_hud.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/interactive_spell_tile.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/spell_list_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/skills_saves_matrix.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/short_rest_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Character testCharacter;
  late CharacterSheetController testController;
  late Spell testSpell;

  setUp(() {
    testCharacter = const Character(
      id: EntityId(slug: 'solomon-test', ruleset: RulesetVersion.v2024),
      name: 'Solomon Kane',
      speciesRef: EntityReference<DomainEntity>(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      progression: CharacterProgression(
        classes: [
          ClassLevelProgression(
            classRef: EntityReference<DomainEntity>(
              refType: EntityType.classDefinition,
              slug: 'wizard',
              displayName: 'Wizard',
            ),
            level: 5,
            hitDie: 'd6',
          ),
        ],
      ),
      baseScores: AbilityScores(
        strength: 10,
        dexterity: 14,
        constitution: 14,
        intelligence: 18,
        wisdom: 12,
        charisma: 8,
      ),
      resources: CharacterResourcePool(
        currentHp: 28,
        currentHitDice: {'d6': 5},
        deathSaveSuccesses: 1,
        deathSaveFailures: 1,
      ),
    );

    testController = CharacterSheetController(character: testCharacter);

    testSpell = const Spell(
      id: EntityId(slug: 'fireball', ruleset: RulesetVersion.v2024),
      name: 'Fireball',
      level: 3,
      school: 'evocation',
      castingTime: CastingTime(cost: 1, actionType: ActionType.action),
      duration: SpellDuration(type: DurationType.instantaneous),
      range: '150 feet',
      components: SpellComponents(v: true, s: true, m: true),
      descriptionMarkdown: 'A bright streak flashes from your pointing finger...',
    );
  });

  Widget wrapWithSettings(Widget child) {
    return SettingsScope(
      notifier: SettingsProvider(),
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  group('Glyph Audit Integration Tests', () {
    testWidgets('ClassCard renders DndGlyph.classFeature', (tester) async {
      final cls = SrdClassesLibrary.allClasses.first;
      await tester.pumpWidget(
        wrapWithSettings(
          ClassCard(
            characterClass: cls,
            isPinned: false,
            onTogglePin: () {},
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    testWidgets('ClassDetailDialog renders DndGlyph.classFeature', (tester) async {
      final cls = SrdClassesLibrary.allClasses.first;
      await tester.pumpWidget(
        wrapWithSettings(
          ClassDetailDialog(
            characterClass: cls,
            isPinned: false,
            onTogglePin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    testWidgets('FeatCard renders DndGlyph.feat', (tester) async {
      final feat = SrdFeatsLibrary.allFeats.first;
      await tester.pumpWidget(
        wrapWithSettings(
          FeatCard(
            feat: feat,
            isPinned: false,
            onTogglePin: () {},
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    testWidgets('FeatDetailDialog renders DndGlyph.feat', (tester) async {
      final feat = SrdFeatsLibrary.allFeats.first;
      await tester.pumpWidget(
        wrapWithSettings(
          FeatDetailDialog(
            feat: feat,
            isPinned: false,
            onTogglePin: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    testWidgets('RaceCard renders DndGlyph.species', (tester) async {
      final race = SrdSpeciesLibrary.allSpecies.first;
      await tester.pumpWidget(
        wrapWithSettings(
          RaceCard(
            race: race,
            isPinned: false,
            onTogglePin: () {},
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    testWidgets('RaceDetailDialog renders DndGlyph.species', (tester) async {
      final race = SrdSpeciesLibrary.allSpecies.first;
      await tester.pumpWidget(
        wrapWithSettings(
          RaceDetailDialog(race: race),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    testWidgets('CharacterHeaderBanner renders avatar DndGlyph', (tester) async {
      await tester.pumpWidget(
        wrapWithSettings(
          CharacterHeaderBanner(controller: testController),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsAtLeastNWidgets(1));
    });

    testWidgets('CharacterVitalsHud renders DndGlyph for Hit Dice & Death Saves', (tester) async {
      await tester.pumpWidget(
        wrapWithSettings(
          SingleChildScrollView(
            child: CharacterVitalsHud(controller: testController),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsAtLeastNWidgets(2));
    });

    testWidgets('SkillsSavesMatrix renders DndGlyph for Roll Mode toggle', (tester) async {
      await tester.pumpWidget(
        wrapWithSettings(
          SingleChildScrollView(
            child: SkillsSavesMatrix(controller: testController),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Normal, Disadvantage, Advantage segments each render a DndGlyph
      expect(find.byType(DndGlyph), findsAtLeastNWidgets(3));
    });

    testWidgets('InteractiveSpellTile and SpellListItem render DndGlyph.spell', (tester) async {
      await tester.pumpWidget(
        wrapWithSettings(
          Column(
            children: [
              InteractiveSpellTile(spell: testSpell, controller: testController),
              SpellListItem(spell: testSpell),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsAtLeastNWidgets(2));
    });

    testWidgets('ShortRestDialog renders Hit Die DndGlyph.genericUi', (tester) async {
      await tester.pumpWidget(
        wrapWithSettings(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ShortRestDialog.show(context, controller: testController),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsAtLeastNWidgets(1));
    });
  });
}
