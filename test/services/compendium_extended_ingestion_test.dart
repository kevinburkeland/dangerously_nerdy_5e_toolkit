import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/landing_tool_item.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  group('Compendium Extended Ingestion & Tools for Nerds Tests', () {
    test('Homebrew Studio is positioned under Tools for Nerds category', () {
      final tools = LandingToolRegistry.defaultTools;
      final homebrewTool = tools.firstWhere((t) => t.id == 'homebrew_studio');

      expect(homebrewTool.category, equals('Tools for Nerds'));
      expect(homebrewTool.keywords, contains('classes'));
      expect(homebrewTool.keywords, contains('races'));
      expect(homebrewTool.keywords, contains('feats'));
      expect(homebrewTool.keywords, contains('backgrounds'));
    });

    test('ingests multi-entity bundle with classes, subclasses, races, feats, and backgrounds', () {
      const comprehensiveJson = '''
{
  "class": [
    {
      "name": "Warlord",
      "source": "HOMEBREW",
      "hd": {"number": 1, "faces": 10},
      "proficiency": ["str", "con"],
      "primaryAbility": "Strength",
      "classFeatures": [
        "Tactical Command: Issue orders as a bonus action.",
        "Rallying Cry: Bolster allies with temp HP."
      ]
    }
  ],
  "subclass": [
    {
      "name": "Tactician",
      "className": "Warlord",
      "source": "HOMEBREW",
      "subclassFeatures": [
        "Battle Clarity: Add INT modifier to initiative rolls."
      ]
    }
  ],
  "race": [
    {
      "name": "Aetherborn",
      "source": "HOMEBREW",
      "size": "Medium",
      "speed": {"walk": 35},
      "ability": "CHA +2, DEX +1",
      "trait": [
        "Born of Aether: Resistance to necrotic damage.",
        "Gift of Life: Detect living creatures within 30 ft."
      ]
    }
  ],
  "feat": [
    {
      "name": "Heavy Blade Mastery",
      "source": "HOMEBREW",
      "prerequisite": ["Strength 13 or higher"],
      "category": "General",
      "entries": [
        "You gain a +1 bonus to attack rolls with greatswords and glaives.",
        "When you crit, you can make an additional melee strike."
      ]
    }
  ],
  "background": [
    {
      "name": "Cartographer",
      "source": "HOMEBREW",
      "skillProficiencies": ["Investigation", "Survival"],
      "toolProficiencies": ["Cartographer's tools", "Navigator's tools"],
      "languages": ["Dwarvish"],
      "feat": "Keen Mind",
      "entries": [
        "Feature: Wanderer. You always recall the general layout of terrain and settlements."
      ]
    }
  ],
  "table": [
    {
      "name": "Wild Magic Surges (Expanded)",
      "source": "HOMEBREW",
      "caption": "d100 Chaos Table",
      "entries": [
        "1-2: Roll on this table every turn for 1 minute.",
        "3-4: For the next minute, you can see any invisible creature."
      ]
    }
  ]
}
''';

      final pipeline = CompendiumJsonIngestionPipeline();
      final result = pipeline.ingestJsonString(comprehensiveJson);

      expect(result.errors, isEmpty);
      expect(result.totalEntities, equals(6));

      // Classes
      expect(result.classes.length, equals(1));
      expect(result.classes.first.name, equals('Warlord'));
      expect(result.classes.first.hitDie, equals('d10'));
      expect(result.classes.first.savingThrows, contains('STR'));
      expect(result.classes.first.savingThrows, contains('CON'));
      expect(result.classes.first.featuresMarkdown, contains('Tactical Command'));

      // Subclasses
      expect(result.subclasses.length, equals(1));
      expect(result.subclasses.first.name, equals('Tactician'));
      expect(result.subclasses.first.classSlug, equals('warlord'));
      expect(result.subclasses.first.featuresMarkdown, contains('Battle Clarity'));

      // Races
      expect(result.races.length, equals(1));
      expect(result.races.first.name, equals('Aetherborn'));
      expect(result.races.first.size, equals('Medium'));
      expect(result.races.first.speed, equals('35 ft.'));
      expect(result.races.first.traitsMarkdown, contains('Born of Aether'));

      // Feats
      expect(result.feats.length, equals(1));
      expect(result.feats.first.name, equals('Heavy Blade Mastery'));
      expect(result.feats.first.prerequisite, contains('Strength 13'));
      expect(result.feats.first.descriptionMarkdown, contains('You gain a +1 bonus'));

      // Backgrounds
      expect(result.backgrounds.length, equals(1));
      expect(result.backgrounds.first.name, equals('Cartographer'));
      expect(result.backgrounds.first.skillProficiencies, contains('Investigation'));
      expect(result.backgrounds.first.skillProficiencies, contains('Survival'));
      expect(result.backgrounds.first.originFeat, equals('Keen Mind'));

      // Other / Tables
      expect(result.otherEntries.length, equals(1));
      expect(result.otherEntries.first.name, equals('Wild Magic Surges (Expanded)'));
      expect(result.otherEntries.first.category, equals('Table'));
    });

    test('persists and hydrates all extended homebrew types across repository and backups', () async {
      final service = HomebrewPersistenceService();

      final customClass = CharacterClass(
        id: const EntityId(slug: 'shaman', ruleset: RulesetVersion.homebrew),
        name: 'Shaman',
        hitDie: 'd8',
        savingThrows: const ['WIS', 'CHA'],
        featuresMarkdown: 'Spirit Communion',
      );

      final customRace = Race(
        id: const EntityId(slug: 'gorgonkin', ruleset: RulesetVersion.homebrew),
        name: 'Gorgonkin',
        traitsMarkdown: 'Petrifying Gaze',
      );

      final customFeat = Feat(
        id: const EntityId(slug: 'spell-sniper-plus', ruleset: RulesetVersion.homebrew),
        name: 'Spell Sniper Plus',
        category: 'Origin',
        descriptionMarkdown: 'Doubles spell range.',
      );

      final customBg = Background(
        id: const EntityId(slug: 'astronomer', ruleset: RulesetVersion.homebrew),
        name: 'Astronomer',
        skillProficiencies: const ['Arcana', 'Perception'],
        descriptionMarkdown: 'Stargazer feature.',
      );

      await service.saveCustomClass(customClass);
      await service.saveCustomRace(customRace);
      await service.saveCustomFeat(customFeat);
      await service.saveCustomBackground(customBg);

      // Verify loaded from persistence
      final loadedClasses = await service.loadCustomClasses();
      final loadedRaces = await service.loadCustomRaces();
      final loadedFeats = await service.loadCustomFeats();
      final loadedBgs = await service.loadCustomBackgrounds();

      expect(loadedClasses.length, equals(1));
      expect(loadedClasses.first.name, equals('Shaman'));
      expect(loadedRaces.length, equals(1));
      expect(loadedRaces.first.name, equals('Gorgonkin'));
      expect(loadedFeats.length, equals(1));
      expect(loadedFeats.first.name, equals('Spell Sniper Plus'));
      expect(loadedBgs.length, equals(1));
      expect(loadedBgs.first.name, equals('Astronomer'));

      // Hydrate repository
      final repo = LayeredPriorityRepository();
      await service.hydrateRepository(repo);

      final homebrewLayer = repo.layers.firstWhere((l) => l.layerId == 'homebrew-packs');
      expect(homebrewLayer.get('shaman', type: EntityType.classDefinition), isNotNull);
      expect(homebrewLayer.get('gorgonkin', type: EntityType.species), isNotNull);
      expect(homebrewLayer.get('spell-sniper-plus', type: EntityType.feat), isNotNull);
      expect(homebrewLayer.get('astronomer', type: EntityType.background), isNotNull);
    });
  });
}
