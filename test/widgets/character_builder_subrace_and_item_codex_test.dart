import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/skill_trait_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/common/formatted_markdown_text.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/races/race_card.dart';

void main() {
  group('Subrace & Character Builder Support', () {
    test('SrdSpeciesLibrary correctly exposes subraces and attaches custom subraces', () {
      final elf = SrdSpeciesLibrary.findBySlug('elf');
      expect(elf, isNotNull);
      expect(elf!.subraces, isNotEmpty);
      expect(elf.subraces.any((s) => s.name.contains('High')), isTrue);
      expect(elf.subraces.any((s) => s.name.contains('Wood')), isTrue);

      // Custom subrace attachment
      const customSub = Subrace(
        id: EntityId(slug: 'eladrin-custom', ruleset: RulesetVersion.v2014),
        name: 'Eladrin (Custom)',
        raceSlug: 'elf',
        traitsMarkdown: '**Fey Step.** Once per short rest teleport 30 feet.',
      );
      SrdSpeciesLibrary.setCustomSubraces([customSub]);

      expect(SrdSpeciesLibrary.customSubraces.length, 1);
      final updatedElf = SrdSpeciesLibrary.findBySlug('elf')!;
      expect(updatedElf.subraces.any((s) => s.id.slug == 'eladrin-custom'), isTrue);

      // SkillTraitResolver resolves subrace traits
      final woodTraits = SkillTraitResolver.getSpeciesTraits(
        speciesSlug: 'elf',
        subraceSlug: 'wood-elf',
      );
      expect(woodTraits.baseSpeedFeet, 35);

      final drowTraits = SkillTraitResolver.getSpeciesTraits(
        speciesSlug: 'elf',
        subraceSlug: 'drow',
      );
      expect(drowTraits.darkvisionFeet, 120);
    });

    test('2014 mode subrace attributes replace base species ability score increases (not additive)', () {
      final elf = SrdSpeciesLibrary.findBySlug('elf')!;
      final highElf = elf.subraces.firstWhere((s) => s.id.slug == 'high-elf');

      // Elf base: +2 DEX
      expect(elf.fixedAbilityBonuses2014['dexterity'], 2);

      // High Elf subrace defines complete replacement: +2 DEX, +1 INT
      expect(highElf.fixedAbilityBonuses2014['dexterity'], 2);
      expect(highElf.fixedAbilityBonuses2014['intelligence'], 1);

      // Replacement logic verification: subrace attributes replace base species (not additive)
      final effectiveBonuses = highElf.fixedAbilityBonuses2014.isNotEmpty
          ? Map<String, int>.from(highElf.fixedAbilityBonuses2014)
          : Map<String, int>.from(elf.fixedAbilityBonuses2014);

      expect(effectiveBonuses['dexterity'], 2);
      expect(effectiveBonuses['intelligence'], 1);
      expect(effectiveBonuses['strength'] ?? 0, 0);

      // Mountain Dwarf defines complete replacement: +2 CON, +2 STR
      final dwarf = SrdSpeciesLibrary.findBySlug('dwarf')!;
      final mountainDwarf = dwarf.subraces.firstWhere((s) => s.id.slug == 'mountain-dwarf');
      final dwarfEffective = mountainDwarf.fixedAbilityBonuses2014.isNotEmpty
          ? Map<String, int>.from(mountainDwarf.fixedAbilityBonuses2014)
          : Map<String, int>.from(dwarf.fixedAbilityBonuses2014);

      expect(dwarfEffective['constitution'], 2);
      expect(dwarfEffective['strength'], 2);
    });

    test('Drow subrace grants dancing-lights cantrip at level 1 and scales at levels 3 and 5', () {
      final lvl1 = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'elf',
        subraceSlug: 'drow',
        totalCharacterLevel: 1,
      );
      expect(lvl1.any((s) => s.spellRef.slug == 'dancing-lights' && s.isCantrip), isTrue);
      expect(lvl1.any((s) => s.spellRef.slug == 'faerie-fire'), isFalse);

      final lvl3 = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'elf',
        subraceSlug: 'drow',
        totalCharacterLevel: 3,
      );
      expect(lvl3.any((s) => s.spellRef.slug == 'faerie-fire'), isTrue);

      final lvl5 = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'elf',
        subraceSlug: 'drow',
        totalCharacterLevel: 5,
      );
      expect(lvl5.any((s) => s.spellRef.slug == 'darkness'), isTrue);
    });
  });

  group('MagicItemLibrary & Homebrew Item Integration', () {
    test('Homebrew items can be converted and loaded into MagicItemLibrary', () {
      const equip = EquipmentItem(
        id: EntityId(slug: 'sunblade-custom', ruleset: RulesetVersion.v2024),
        name: 'Sunblade of the Dawn',
        itemType: 'Weapon',
        rarity: 'Rare',
        requiresAttunement: true,
        descriptionMarkdown: 'A radiant blade that shines with daylight.',
      );

      final magicItem = HomebrewPersistenceService.equipmentItemToMagicItem(equip);
      expect(magicItem.id, 'sunblade-custom');
      expect(magicItem.name, 'Sunblade of the Dawn');
      expect(magicItem.category, ItemCategory.weapon);
      expect(magicItem.rarity, ItemRarity.rare);
      expect(magicItem.requiresAttunement, isTrue);

      MagicItemLibrary.setHomebrewItems([magicItem]);
      expect(MagicItemLibrary.allItems.any((i) => i.id == 'sunblade-custom'), isTrue);
      expect(MagicItemLibrary.findById('sunblade-custom'), isNotNull);
      expect(MagicItemLibrary.findByName('Sunblade of the Dawn'), isNotNull);
    });

    test('CharacterSheetController adds and removes inventory items seamlessly', () async {
      const initialChar = Character(
        id: EntityId(slug: 'test-adventurer', ruleset: RulesetVersion.v2024),
        name: 'Test Adventurer',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10),
        resources: CharacterResourcePool(currentHp: 10),
      );

      final controller = CharacterSheetController(character: initialChar);
      expect(controller.character.inventory, isEmpty);

      const newItem = InventoryItemInstance(
        instanceId: 'inst-1',
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'dagger', displayName: 'Dagger'),
        quantity: 1,
      );

      await controller.addItem(newItem);
      expect(controller.character.inventory.length, 1);
      expect(controller.character.inventory.first.displayName, 'Dagger');

      await controller.updateItemQuantity('inst-1', 3);
      expect(controller.character.inventory.first.quantity, 3);

      await controller.removeItem('inst-1');
      expect(controller.character.inventory, isEmpty);
    });
  });

  group('Markdown & Tag Parsing Robustness', () {
    test('cleanRawTags accurately parses hit bonus, h, hom, recharge, dc, and nested tags', () {
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@hit 5}'), '+5');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@hit +7}'), '+7');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@h}'), '*Hit:* ');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@hom}'), '*Hit or Miss:* ');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@recharge 5}'), '*(Recharge 5–6)*');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@recharge}'), '*(Recharge 6)*');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@dc 15}'), 'DC 15');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@damage 2d6+3}'), '**`2d6+3`**');
      expect(CompendiumJsonIngestionPipeline.cleanRawTags('{@scaledice 3d6}'), '**`3d6`**');
    });

    testWidgets('FormattedMarkdownText renders deep headings, blockquotes, and tables', (tester) async {
      const sample = '''
#### Subaction Heading
> Important tactical note for adventuring party.

| Dice | Result |
| :--- | :--- |
| 1 | Failure |
| 2 | Success |
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(sample),
          ),
        ),
      );

      expect(find.textContaining('Subaction Heading'), findsOneWidget);
      expect(find.textContaining('Important tactical note'), findsOneWidget);
      expect(find.textContaining('Failure'), findsOneWidget);
      expect(find.textContaining('Success'), findsOneWidget);
    });

    testWidgets('RaceCard renders traits using FormattedMarkdownText', (tester) async {
      final elf = SrdSpeciesLibrary.findBySlug('elf')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RaceCard(
              race: elf,
              isPinned: false,
              onTogglePin: () {},
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(FormattedMarkdownText), findsOneWidget);
      expect(find.textContaining('Darkvision'), findsWidgets);
    });
  });
}
