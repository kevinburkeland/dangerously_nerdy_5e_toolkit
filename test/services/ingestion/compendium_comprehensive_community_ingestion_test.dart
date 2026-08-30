import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HomebrewPersistenceService().clearAllHomebrew();
  });

  group('Comprehensive Community & Multi-Category Compendium Ingestion Tests', () {
    test('ingests multi-category community compendium payload with 0% data loss', () {
      const fullPayload = '''
{
  "spell": [
    {
      "name": "Eldritch Smite Wave",
      "source": "HOMEBREW",
      "level": 4,
      "school": "N",
      "time": [{"number": 1, "unit": "bonus"}],
      "range": {"type": "self"},
      "components": {"v": true, "s": true},
      "duration": [{"type": "instant"}],
      "entries": [
        "Your next strike erupts in necrotic power dealing {@damage 4d8|necrotic} damage."
      ],
      "damageInflict": ["necrotic"],
      "homebrewDesigner": "Hexblade Council"
    }
  ],
  "monster": [
    {
      "name": "Astral Dreadstalker",
      "source": "HOMEBREW",
      "size": ["L"],
      "type": "aberration",
      "alignment": ["N", "E"],
      "ac": [{"ac": 16, "from": ["carapace"]}],
      "hp": {"average": 95, "formula": "10d10 + 40"},
      "speed": {"walk": 40, "climb": 40},
      "str": 18,
      "dex": 15,
      "con": 18,
      "int": 8,
      "wis": 12,
      "cha": 6,
      "cr": "6",
      "action": [
        {
          "name": "Claw",
          "entries": ["{@atk mw} {@hit 7} to hit, reach 10 ft. *Hit:* 13 ({@damage 2d8 + 4|slashing}) damage."]
        }
      ],
      "habitatOrigin": "Astral Sea"
    }
  ],
  "item": [
    {
      "name": "Girdle of the Mountain King",
      "source": "HOMEBREW",
      "type": "W",
      "rarity": "Legendary",
      "reqAttune": "by a barbarian, fighter, or paladin",
      "entries": [
        "Your Strength score becomes 25 while wearing this girdle."
      ],
      "bonusWeapon": "+1",
      "ancientRune": "Khaz-Modan"
    }
  ],
  "class": [
    {
      "name": "Psion",
      "source": "HOMEBREW",
      "hd": {"number": 1, "faces": 6},
      "proficiency": ["int", "wis"],
      "primaryAbility": "Intelligence",
      "classFeatures": [
        "Psionic Talent: You have a psionic energy die (d6)."
      ],
      "psionDiscipline": "Telekinesis"
    }
  ],
  "subclass": [
    {
      "name": "Metacreator",
      "className": "Psion",
      "source": "HOMEBREW",
      "subclassFeatures": [
        "Astral Construct: Manifest an ectoplasmic minion."
      ]
    }
  ],
  "race": [
    {
      "name": "Shardmind",
      "source": "HOMEBREW",
      "size": "Medium",
      "speed": {"walk": 30},
      "ability": [{"int": 2, "wis": 1}],
      "trait": [
        {"name": "Crystalline Body", "entries": ["You have resistance to psychic damage."]}
      ]
    }
  ],
  "feat": [
    {
      "name": "Telekinetic Master",
      "source": "HOMEBREW",
      "prerequisite": ["Intelligence 13 or higher"],
      "entries": [
        "You learn the {@spell mage hand} cantrip, which is invisible for you."
      ]
    }
  ],
  "background": [
    {
      "name": "Astral Drifter",
      "source": "HOMEBREW",
      "skillProficiencies": ["Arcana", "Religion"],
      "feat": "Magic Initiate",
      "entries": [
        "You lived among the timeless currents of the Astral Plane."
      ]
    }
  ],
  "table": [
    {
      "name": "Psionic Wild Surges",
      "source": "HOMEBREW",
      "entries": [
        "1-10: Gravity reverses for 1 round."
      ]
    }
  ]
}
''';

      final pipeline = CompendiumJsonIngestionPipeline();
      final result = pipeline.ingestJsonString(fullPayload);

      expect(result.errors, isEmpty);
      expect(result.totalEntities, equals(9));

      // 1. Spells
      expect(result.spells.length, equals(1));
      expect(result.spells.first.name, equals('Eldritch Smite Wave'));
      expect(result.spells.first.school, equals('Necromancy'));
      expect(result.spells.first.customProperties['homebrewDesigner'], equals('Hexblade Council'));

      // 2. Monsters
      expect(result.monsters.length, equals(1));
      expect(result.monsters.first.name, equals('Astral Dreadstalker'));
      expect(result.monsters.first.armorClass, equals(16));
      expect(result.monsters.first.customProperties['habitatOrigin'], equals('Astral Sea'));

      // 3. Items
      expect(result.items.length, equals(1));
      expect(result.items.first.name, equals('Girdle of the Mountain King'));
      expect(result.items.first.rarity, equals('Legendary'));
      expect(result.items.first.customProperties['ancientRune'], equals('Khaz-Modan'));

      // 4. Classes
      expect(result.classes.length, equals(1));
      expect(result.classes.first.name, equals('Psion'));
      expect(result.classes.first.customProperties['psionDiscipline'], equals('Telekinesis'));

      // 5. Subclasses
      expect(result.subclasses.length, equals(1));
      expect(result.subclasses.first.name, equals('Metacreator'));
      expect(result.subclasses.first.classSlug, equals('psion'));

      // 6. Races
      expect(result.races.length, equals(1));
      expect(result.races.first.name, equals('Shardmind'));

      // 7. Feats
      expect(result.feats.length, equals(1));
      expect(result.feats.first.name, equals('Telekinetic Master'));

      // 8. Backgrounds
      expect(result.backgrounds.length, equals(1));
      expect(result.backgrounds.first.name, equals('Astral Drifter'));
      expect(result.backgrounds.first.originFeat, equals('Magic Initiate'));

      // 9. Tables/Rules
      expect(result.otherEntries.length, equals(1));
      expect(result.otherEntries.first.name, equals('Psionic Wild Surges'));

      // Bundle conversion
      final bundle = result.toBundle(bundleName: 'Psionics & Astral Compendium');
      expect(bundle.bundleName, equals('Psionics & Astral Compendium'));
      expect(bundle.totalCount, equals(9));
    });
  });
}
