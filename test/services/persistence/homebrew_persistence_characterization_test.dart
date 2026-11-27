import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_other_category.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/fluff/entity_fluff_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/homebrew/models/homebrew_entity.dart';
import '../../test_doubles/hive_test_harness.dart';

Spell _spell(String slug, String name) => Spell.singleEdition(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      level: 1,
      school: 'evocation',
      castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
      range: '60 feet',
      components: const SpellComponents(v: true, s: true, m: false),
      duration: const SpellDuration(type: DurationType.instantaneous),
      descriptionMarkdown: 'Test spell $name.',
      customProperties: const {'classes': ['Wizard']},
    );

Monster _monster(String slug, String name) => Monster(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      size: 'Medium',
      monsterType: 'humanoid',
      alignment: 'neutral',
      armorClass: 14,
      hitPoints: 22,
      hitDieFormula: '4d8 + 4',
      challengeRating: '1',
      actionsMarkdown: 'Club. Melee Weapon Attack.',
    );

EquipmentItem _item(String slug, String name) => EquipmentItem.singleEdition(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      itemType: 'Wondrous Item',
      rarity: 'rare',
      requiresAttunement: false,
      descriptionMarkdown: 'Test item $name.',
    );

CharacterClass _cls(String slug, String name) => CharacterClass(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      hitDie: 'd8',
      featuresMarkdown: 'Class $name features.',
    );

Subclass _subclass(String slug, String name) => Subclass(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      classSlug: 'fighter',
      shortName: name,
      featuresMarkdown: 'Subclass $name features.',
    );

Race _race(String slug, String name) => Race(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      size: 'Medium',
      speed: '30 ft.',
      traitsMarkdown: 'Race $name traits.',
    );

Subrace _subrace(String slug, String name) => Subrace(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      raceSlug: 'elf',
      traitsMarkdown: 'Subrace $name traits.',
    );

Feat _feat(String slug, String name) => Feat(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      descriptionMarkdown: 'Feat $name description.',
    );

Background _background(String slug, String name) => Background(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      descriptionMarkdown: 'Background $name description.',
    );

HomebrewCompendiumEntry _other(
  String slug,
  String name, {
  String category = 'Deity',
}) =>
    HomebrewCompendiumEntry(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      category: category,
      descriptionMarkdown: 'Other $name content.',
    );

EntityFluff _fluff(String slug) => EntityFluff(
      slug: slug,
      entityType: 'monster',
      loreMarkdown: 'Lore for $slug.',
    );

void main() {
  final hive = HiveTestHarness();
  late HomebrewPersistenceService svc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await hive.setUpInMemory();
    svc = HomebrewPersistenceService();
    await svc.clearAllHomebrew();
  });

  tearDown(() async {
    await svc.clearAllHomebrew();
    await hive.tearDown();
  });

  group('Fix 4.3: HomebrewPersistenceService public behaviour characterization', () {
    test('spells: saveCustomSpell, loadCustomSpells, saveCustomSpellsBatch, deleteCustomSpell, and SpellbookLibrary state', () async {
      await svc.saveCustomSpell(_spell('char-spell-1', 'Char Spell One'));
      await svc.syncToLibraries();
      expect((await svc.loadCustomSpells()).map((e) => e.id.slug), contains('char-spell-1'));
      expect(
        SpellbookLibrary.getSpellById('char-spell-1')?.name,
        equals('Char Spell One'),
        reason: 'SpellbookLibrary must contain Char Spell One (char-spell-1) after saveCustomSpell + syncToLibraries',
      );

      await svc.saveCustomSpellsBatch([_spell('char-spell-2', 'Char Spell Two')]);
      await svc.syncToLibraries();
      expect((await svc.loadCustomSpells()).map((e) => e.id.slug), containsAll(['char-spell-1', 'char-spell-2']));
      expect(SpellbookLibrary.getSpellById('char-spell-2')?.name, equals('Char Spell Two'));

      await svc.deleteCustomSpell('char-spell-1');
      await svc.syncToLibraries();
      expect((await svc.loadCustomSpells()).map((e) => e.id.slug), isNot(contains('char-spell-1')));
      expect(SpellbookLibrary.getSpellById('char-spell-1'), isNull);
    });

    test('monsters: saveCustomMonster, loadCustomMonsters, saveCustomMonstersBatch, deleteCustomMonster, and MonsterCodexLibrary state', () async {
      await svc.saveCustomMonster(_monster('char-mon-1', 'Char Monster One'));
      expect((await svc.loadCustomMonsters()).map((e) => e.id.slug), contains('char-mon-1'));
      expect(MonsterCodexLibrary.allMonsters.any((m) => m.name == 'Char Monster One'), isTrue);

      await svc.saveCustomMonstersBatch([_monster('char-mon-2', 'Char Monster Two')]);
      expect((await svc.loadCustomMonsters()).map((e) => e.id.slug), containsAll(['char-mon-1', 'char-mon-2']));
      expect(MonsterCodexLibrary.allMonsters.any((m) => m.name == 'Char Monster Two'), isTrue);

      await svc.deleteCustomMonster('char-mon-1');
      expect((await svc.loadCustomMonsters()).map((e) => e.id.slug), isNot(contains('char-mon-1')));
      expect(MonsterCodexLibrary.allMonsters.any((m) => m.name == 'Char Monster One'), isFalse);
    });

    test('items: saveCustomItem, loadCustomItems, saveCustomItemsBatch, deleteCustomItem, and MagicItemLibrary state', () async {
      await svc.saveCustomItem(_item('char-item-1', 'Char Item One'));
      await svc.syncToLibraries();
      expect((await svc.loadCustomItems()).map((e) => e.id.slug), contains('char-item-1'));
      expect(MagicItemLibrary.findById('char-item-1')?.name, equals('Char Item One'));

      await svc.saveCustomItemsBatch([_item('char-item-2', 'Char Item Two')]);
      await svc.syncToLibraries();
      expect((await svc.loadCustomItems()).map((e) => e.id.slug), containsAll(['char-item-1', 'char-item-2']));
      expect(MagicItemLibrary.findById('char-item-2')?.name, equals('Char Item Two'));

      await svc.deleteCustomItem('char-item-1');
      await svc.syncToLibraries();
      expect((await svc.loadCustomItems()).map((e) => e.id.slug), isNot(contains('char-item-1')));
      expect(MagicItemLibrary.findById('char-item-1'), isNull);
    });

    test('classes: saveCustomClass, loadCustomClasses, saveCustomClassesBatch, deleteCustomClass, and SrdClassesLibrary state', () async {
      await svc.saveCustomClass(_cls('char-cls-1', 'Char Class One'));
      expect((await svc.loadCustomClasses()).map((e) => e.id.slug), contains('char-cls-1'));
      expect(SrdClassesLibrary.findBySlug('char-cls-1')?.name, equals('Char Class One'));

      await svc.saveCustomClassesBatch([_cls('char-cls-2', 'Char Class Two')]);
      expect((await svc.loadCustomClasses()).map((e) => e.id.slug), containsAll(['char-cls-1', 'char-cls-2']));
      expect(SrdClassesLibrary.findBySlug('char-cls-2')?.name, equals('Char Class Two'));

      await svc.deleteCustomClass('char-cls-1');
      expect((await svc.loadCustomClasses()).map((e) => e.id.slug), isNot(contains('char-cls-1')));
      expect(SrdClassesLibrary.findBySlug('char-cls-1'), isNull);
    });

    test('subclasses: saveCustomSubclass, loadCustomSubclasses, saveCustomSubclassesBatch, deleteCustomSubclass, and library state', () async {
      await svc.saveCustomSubclass(_subclass('char-sub-1', 'Char Subclass One'));
      expect((await svc.loadCustomSubclasses()).map((e) => e.id.slug), contains('char-sub-1'));
      expect(
        SrdClassesLibrary.findBySlug('fighter')?.subclasses.any((s) => s.id.slug == 'char-sub-1'),
        isTrue,
      );

      await svc.saveCustomSubclassesBatch([_subclass('char-sub-2', 'Char Subclass Two')]);
      expect((await svc.loadCustomSubclasses()).map((e) => e.id.slug), containsAll(['char-sub-1', 'char-sub-2']));

      await svc.deleteCustomSubclass('char-sub-1');
      expect((await svc.loadCustomSubclasses()).map((e) => e.id.slug), isNot(contains('char-sub-1')));
    });

    test('races: saveCustomRace, loadCustomRaces, saveCustomRacesBatch, deleteCustomRace, and SrdSpeciesLibrary state', () async {
      await svc.saveCustomRace(_race('char-race-1', 'Char Race One'));
      expect((await svc.loadCustomRaces()).map((e) => e.id.slug), contains('char-race-1'));
      expect(SrdSpeciesLibrary.findBySlug('char-race-1')?.name, equals('Char Race One'));

      await svc.saveCustomRacesBatch([_race('char-race-2', 'Char Race Two')]);
      expect((await svc.loadCustomRaces()).map((e) => e.id.slug), containsAll(['char-race-1', 'char-race-2']));

      await svc.deleteCustomRace('char-race-1');
      expect((await svc.loadCustomRaces()).map((e) => e.id.slug), isNot(contains('char-race-1')));
      expect(SrdSpeciesLibrary.findBySlug('char-race-1'), isNull);
    });

    test('subraces: saveCustomSubrace, loadCustomSubraces, saveCustomSubracesBatch, deleteCustomSubrace, and SrdSpeciesLibrary state', () async {
      await svc.saveCustomSubrace(_subrace('char-subrace-1', 'Char Subrace One'));
      expect((await svc.loadCustomSubraces()).map((e) => e.id.slug), contains('char-subrace-1'));
      expect(SrdSpeciesLibrary.findSubraceBySlug('char-subrace-1')?.name, equals('Char Subrace One'));

      await svc.saveCustomSubracesBatch([_subrace('char-subrace-2', 'Char Subrace Two')]);
      expect((await svc.loadCustomSubraces()).map((e) => e.id.slug), containsAll(['char-subrace-1', 'char-subrace-2']));

      await svc.deleteCustomSubrace('char-subrace-1');
      expect((await svc.loadCustomSubraces()).map((e) => e.id.slug), isNot(contains('char-subrace-1')));
    });

    test('feats: saveCustomFeat, loadCustomFeats, saveCustomFeatsBatch, deleteCustomFeat, and SrdFeatsLibrary state', () async {
      await svc.saveCustomFeat(_feat('char-feat-1', 'Char Feat One'));
      expect((await svc.loadCustomFeats()).map((e) => e.id.slug), contains('char-feat-1'));
      expect(SrdFeatsLibrary.findBySlug('char-feat-1')?.name, equals('Char Feat One'));

      await svc.saveCustomFeatsBatch([_feat('char-feat-2', 'Char Feat Two')]);
      expect((await svc.loadCustomFeats()).map((e) => e.id.slug), containsAll(['char-feat-1', 'char-feat-2']));

      await svc.deleteCustomFeat('char-feat-1');
      expect((await svc.loadCustomFeats()).map((e) => e.id.slug), isNot(contains('char-feat-1')));
      expect(SrdFeatsLibrary.findBySlug('char-feat-1'), isNull);
    });

    test('backgrounds: saveCustomBackground, loadCustomBackgrounds, saveCustomBackgroundsBatch, deleteCustomBackground, and SrdBackgroundsLibrary state', () async {
      await svc.saveCustomBackground(_background('char-bg-1', 'Char BG One'));
      expect((await svc.loadCustomBackgrounds()).map((e) => e.id.slug), contains('char-bg-1'));
      expect(SrdBackgroundsLibrary.findBySlug('char-bg-1')?.name, equals('Char BG One'));

      await svc.saveCustomBackgroundsBatch([_background('char-bg-2', 'Char BG Two')]);
      expect((await svc.loadCustomBackgrounds()).map((e) => e.id.slug), containsAll(['char-bg-1', 'char-bg-2']));

      await svc.deleteCustomBackground('char-bg-1');
      expect((await svc.loadCustomBackgrounds()).map((e) => e.id.slug), isNot(contains('char-bg-1')));
      expect(SrdBackgroundsLibrary.findBySlug('char-bg-1'), isNull);
    });

    test('other entries: save, load, batch, delete, toggleOtherEntryEnabled, loadOtherCategoryCounts, clearOtherEntriesByCategories', () async {
      await svc.saveCustomOtherEntry(_other('char-other-1', 'Char Other One', category: 'Deity'));
      await svc.saveCustomOtherEntriesBatch([
        _other('char-other-2', 'Char Other Two', category: 'Variant Rule'),
      ]);
      expect((await svc.loadCustomOtherEntries()).length, equals(2));

      final counts = await svc.loadOtherCategoryCounts();
      expect(counts[HomebrewOtherCategory.deities], equals(1));
      expect(counts[HomebrewOtherCategory.rulesAndReference], equals(1));

      final toggled = await svc.toggleOtherEntryEnabled('char-other-1', isEnabled: false);
      expect(toggled, isFalse);
      final afterToggle = (await svc.loadCustomOtherEntries())
          .firstWhere((e) => e.id.slug == 'char-other-1');
      expect(afterToggle.isEnabled, isFalse);

      final removed = await svc.clearOtherEntriesByCategories({HomebrewOtherCategory.rulesAndReference});
      expect(removed, equals(1));
      expect((await svc.loadCustomOtherEntries()).map((e) => e.id.slug), equals(['char-other-1']));

      await svc.deleteCustomOtherEntry('char-other-1');
      expect(await svc.loadCustomOtherEntries(), isEmpty);
    });

    test('fluff: saveCustomFluffBatch, loadCustomFluff, and EntityFluffService state', () async {
      await svc.saveCustomFluffBatch([_fluff('char-fluff-1')]);
      final loaded = await svc.loadCustomFluff();
      expect(loaded.any((f) => f.slug == 'char-fluff-1'), isTrue);
      expect(EntityFluffService().getFluff('monster', 'char-fluff-1')?.loreMarkdown, equals('Lore for char-fluff-1.'));
    });

    test('deleteCustomEntitiesBatch, clearHomebrewCategory, and clearAllHomebrew', () async {
      await svc.saveCustomSpellsBatch([
        _spell('batch-sp-1', 'Batch Sp 1'),
        _spell('batch-sp-2', 'Batch Sp 2'),
      ]);
      await svc.saveCustomItem(_item('batch-it-1', 'Batch Item 1'));

      final deleted = await svc.deleteCustomEntitiesBatch(EntityType.spell, const ['batch-sp-1']);
      expect(deleted, equals(1));
      expect((await svc.loadCustomSpells()).map((s) => s.id.slug), equals(['batch-sp-2']));

      await svc.clearHomebrewCategory(EntityType.spell);
      expect(await svc.loadCustomSpells(), isEmpty);
      expect(await svc.loadCustomItems(), isNotEmpty);

      await svc.clearAllHomebrew();
      expect(await svc.loadCustomItems(), isEmpty);
      expect(MagicItemLibrary.findById('batch-it-1'), isNull);
    });

    test('hydrateRepository registers homebrew entities in LayeredPriorityRepository homebrew layer', () async {
      await svc.saveCustomSpell(_spell('hyd-sp-1', 'Hydrate Spell'));
      await svc.saveCustomItem(_item('hyd-it-1', 'Hydrate Item'));

      final repo = LayeredPriorityRepository();
      await svc.hydrateRepository(repo);

      final hbLayers = repo.layers.where((l) => l.priority == LayerPriority.homebrewPacks).toList();
      expect(hbLayers, isNotEmpty);
      expect(hbLayers.first.get('hyd-sp-1', type: EntityType.spell)?.name, equals('Hydrate Spell'));
      expect(hbLayers.first.get('hyd-it-1', type: EntityType.equipment)?.name, equals('Hydrate Item'));
    });

    test('raw payloads and reparseAllHomebrew return expected ReparseResult numbers', () async {
      await svc.saveCustomSpell(
        _spell('reparse-sp-1', 'Reparse Flame'),
        rawPayload: const {
          'name': 'Reparse Flame',
          'source': 'HB',
          'level': 1,
          'school': 'V',
          'time': [{'number': 1, 'unit': 'action'}],
          'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 60}},
          'components': {'v': true, 's': true},
          'duration': [{'type': 'instant'}],
          'entries': ['A bright flame leaps forward.'],
        },
      );
      expect(await svc.rawPayloadCount(EntityType.spell), equals(1));
      expect((await svc.loadRawPayloads(EntityType.spell)).length, equals(1));

      final res = await svc.reparseAllHomebrew();
      expect(res.updatedCount, greaterThanOrEqualTo(1));
      expect(res.srdRemovedCount, equals(0));
      expect(res.noPayloadCount, equals(0));
    });

    test('saveHomebrewEntity and saveHomebrewEntitiesBatch persist and sync entities', () async {
      final spEntity = HomebrewEntity(
        id: 'generic-sp-1',
        entityType: 'spell',
        ruleset: RulesetVersion.homebrew,
        name: 'Generic Spell One',
        rawPayload: const {
          'name': 'Generic Spell One',
          'source': 'HB',
          'level': 1,
          'school': 'V',
          'time': [{'number': 1, 'unit': 'action'}],
          'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 60}},
          'components': {'v': true},
          'duration': [{'type': 'instant'}],
          'entries': ['A spark of light.'],
        },
      );
      await svc.saveHomebrewEntity(spEntity);
      expect((await svc.loadCustomSpells()).any((s) => s.name == 'Generic Spell One'), isTrue);
      expect(SpellbookLibrary.allSpells.any((s) => s.name == 'Generic Spell One'), isTrue);

      await svc.saveHomebrewEntitiesBatch([
        HomebrewEntity(
          id: 'generic-it-1',
          entityType: 'item',
          ruleset: RulesetVersion.homebrew,
          name: 'Generic Item One',
          rawPayload: const {
            'name': 'Generic Item One',
            'source': 'HB',
            'type': 'W',
            'rarity': 'rare',
            'entries': ['A glowing pebble.'],
          },
        ),
        HomebrewEntity(
          id: 'generic-ft-1',
          entityType: 'feat',
          ruleset: RulesetVersion.homebrew,
          name: 'Generic Feat One',
          rawPayload: const {
            'name': 'Generic Feat One',
            'source': 'HB',
            'entries': ['You gain keen focus.'],
          },
        ),
      ]);
      expect((await svc.loadCustomItems()).any((i) => i.name == 'Generic Item One'), isTrue);
      expect((await svc.loadCustomFeats()).any((f) => f.name == 'Generic Feat One'), isTrue);
      expect(MagicItemLibrary.allItems.any((i) => i.name == 'Generic Item One'), isTrue);
      expect(SrdFeatsLibrary.allFeats.any((f) => f.name == 'Generic Feat One'), isTrue);
    });
  });
}
