import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Homebrew Complete Bundle Exporter Tests', () {
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      persistence = HomebrewPersistenceService();
    });

    test('exportBundle serializes all active registries into comprehensive sibling arrays', () async {
      // 1. Seed Custom Spell
      const spell = Spell(
        id: EntityId(slug: 'astral-pulse', ruleset: RulesetVersion.homebrew),
        name: 'Astral Pulse',
        level: 2,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '60 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Deals 3d8 force damage.',
      );
      await persistence.saveCustomSpell(spell);

      // 2. Seed Custom Monster
      const monster = Monster(
        id: EntityId(slug: 'void-lurker', ruleset: RulesetVersion.homebrew),
        name: 'Void Lurker',
        size: 'Medium',
        monsterType: 'Aberration',
        alignment: 'Neutral Evil',
        armorClass: 14,
        hitPoints: 45,
        hitDieFormula: '6d8 + 18',
        challengeRating: '2',
        actionsMarkdown: 'Tentacle strike.',
      );
      await persistence.saveCustomMonster(monster);

      // 3. Seed Custom Equipment Item
      const item = EquipmentItem(
        id: EntityId(slug: 'blade-of-echoes', ruleset: RulesetVersion.homebrew),
        name: 'Blade of Echoes',
        itemType: 'weapon',
        rarity: 'Uncommon',
        requiresAttunement: false,
        descriptionMarkdown: 'A resonant rapier vibrating with psychic force.',
      );
      await persistence.saveCustomItem(item);

      // 4. Seed Custom Class
      const charClass = CharacterClass(
        id: EntityId(slug: 'runesmith', ruleset: RulesetVersion.homebrew),
        name: 'Runesmith',
        hitDie: 'd10',
        primaryAbility: 'Intelligence',
        featuresMarkdown: 'Master of runic magic and metallurgy.',
      );
      await persistence.saveCustomClass(charClass);

      // 5. Seed Custom Subclass
      const subclass = Subclass(
        id: EntityId(slug: 'iron-warden', ruleset: RulesetVersion.homebrew),
        name: 'Iron Warden',
        classSlug: 'runesmith',
        featuresMarkdown: 'Grants heavy armor and defensive runes.',
      );
      await persistence.saveCustomSubclass(subclass);

      // 6. Seed Custom Race with Subrace
      final race = Race(
        id: const EntityId(slug: 'crystallid', ruleset: RulesetVersion.homebrew),
        name: 'Crystallid',
        size: 'Medium',
        speed: '30 ft.',
        traitsMarkdown: 'Formed of sentient living crystal.',
        fixedAbilityBonuses: const {'con': 2, 'constitution': 2},
        subraces: const [
          Subrace(
            id: EntityId(slug: 'prismatic-crystallid', ruleset: RulesetVersion.homebrew),
            name: 'Prismatic Crystallid',
            raceSlug: 'crystallid',
            traitsMarkdown: 'Refracts radiant light.',
          ),
        ],
      );
      await persistence.saveCustomRace(race);

      // 7. Seed Custom Feat
      const feat = Feat(
        id: EntityId(slug: 'void-touched', ruleset: RulesetVersion.homebrew),
        name: 'Void Touched',
        category: 'General',
        descriptionMarkdown: 'Gain misty step once per day.',
      );
      await persistence.saveCustomFeat(feat);

      // 8. Seed Custom Background
      const background = Background(
        id: EntityId(slug: 'planar-cartographer', ruleset: RulesetVersion.homebrew),
        name: 'Planar Cartographer',
        descriptionMarkdown: 'Planar Navigation: You can intuitively navigate the outer planes.',
      );
      await persistence.saveCustomBackground(background);

      // Export the complete bundle map
      final exported = await persistence.exportBundle(
        bundleName: 'Cosmic Expansion Pack',
        author: 'Grand Archivist',
        description: 'Complete homebrew collection of planar entities.',
      );

      // Assert root envelope metadata
      expect(exported['bundleName'], equals('Cosmic Expansion Pack'));
      expect(exported['author'], equals('Grand Archivist'));
      expect(exported['description'], equals('Complete homebrew collection of planar entities.'));
      expect(exported['schemaVersion'], equals(1));
      expect(exported['appVersion'], equals('1.0.0'));
      expect(exported['exportedAt'], isNotNull);

      // Assert comprehensive sibling arrays
      expect(exported['spells'], isA<List>());
      expect((exported['spells'] as List).length, equals(1));
      expect((exported['spells'] as List).first['name'], equals('Astral Pulse'));

      expect(exported['monsters'], isA<List>());
      expect((exported['monsters'] as List).length, equals(1));
      expect((exported['monsters'] as List).first['name'], equals('Void Lurker'));

      expect(exported['items'], isA<List>());
      expect((exported['items'] as List).length, equals(1));
      expect((exported['items'] as List).first['name'], equals('Blade of Echoes'));

      expect(exported['classes'], isA<List>());
      expect((exported['classes'] as List).length, equals(1));
      expect((exported['classes'] as List).first['name'], equals('Runesmith'));

      expect(exported['subclasses'], isA<List>());
      expect((exported['subclasses'] as List).length, equals(1));
      expect((exported['subclasses'] as List).first['name'], equals('Iron Warden'));

      expect(exported['races'], isA<List>());
      expect((exported['races'] as List).length, equals(1));
      expect((exported['races'] as List).first['name'], equals('Crystallid'));

      expect(exported['subraces'], isA<List>());
      expect((exported['subraces'] as List).length, equals(1));
      expect((exported['subraces'] as List).first['name'], equals('Prismatic Crystallid'));

      expect(exported['feats'], isA<List>());
      expect((exported['feats'] as List).length, equals(1));
      expect((exported['feats'] as List).first['name'], equals('Void Touched'));

      expect(exported['backgrounds'], isA<List>());
      expect((exported['backgrounds'] as List).length, equals(1));
      expect((exported['backgrounds'] as List).first['name'], equals('Planar Cartographer'));
    });

    test('exportBundle respects category filtering when specified', () async {
      // Seed spell and item
      const spell = Spell(
        id: EntityId(slug: 'sun-beam', ruleset: RulesetVersion.homebrew),
        name: 'Sun Beam',
        level: 1,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '30 feet',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Deals radiant damage.',
      );
      await persistence.saveCustomSpell(spell);

      const item = EquipmentItem(
        id: EntityId(slug: 'shield-of-light', ruleset: RulesetVersion.homebrew),
        name: 'Shield of Light',
        itemType: 'shield',
        rarity: 'Common',
        requiresAttunement: false,
        descriptionMarkdown: 'Emits gentle warmth.',
      );
      await persistence.saveCustomItem(item);

      // Export only equipment items
      final exported = await persistence.exportBundle(
        bundleName: 'Items Only',
        categories: {EntityType.equipment},
      );

      expect((exported['items'] as List).length, equals(1));
      expect((exported['spells'] as List), isEmpty);
      expect((exported['races'] as List), isEmpty);
    });

    test('exportHomebrewBundle populates subraces in portable bundle object', () async {
      final race = Race(
        id: const EntityId(slug: 'starborn', ruleset: RulesetVersion.homebrew),
        name: 'Starborn',
        size: 'Medium',
        speed: '30 ft.',
        traitsMarkdown: 'Children of the stars.',
        subraces: const [
          Subrace(
            id: EntityId(slug: 'solar-starborn', ruleset: RulesetVersion.homebrew),
            name: 'Solar Starborn',
            raceSlug: 'starborn',
            traitsMarkdown: 'Fire resistance.',
          ),
        ],
      );
      await persistence.saveCustomRace(race);

      final bundle = await persistence.exportHomebrewBundle(bundleName: 'Starborn Pack');

      expect(bundle.races.length, equals(1));
      expect(bundle.races.first.name, equals('Starborn'));
      expect(bundle.subraces.length, equals(1));
      expect(bundle.subraces.first.name, equals('Solar Starborn'));

      final map = bundle.toMap();
      expect(map['subraces'], isNotNull);
      expect((map['subraces'] as List).length, equals(1));
      expect((map['subraces'] as List).first['name'], equals('Solar Starborn'));
    });
  });
}
