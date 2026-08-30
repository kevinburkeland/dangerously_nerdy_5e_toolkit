import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  group('Compendium Ingestion & SRD Deduplication Polymorphism Tests', () {
    late CompendiumJsonIngestionPipeline pipeline;
    late HomebrewMergeResolver resolver;

    setUp(() {
      pipeline = CompendiumJsonIngestionPipeline();
      resolver = const HomebrewMergeResolver();
    });

    test('ingests mixed bundle and accurately quarantines all canonical SRD entries', () {
      const mixedJson = '''
{
  "spell": [
    {
      "name": "Fireball",
      "level": 3,
      "school": "V",
      "time": [{"number": 1, "unit": "action"}],
      "range": {"type": "point", "distance": {"type": "feet", "amount": 150}},
      "components": {"v": true, "s": true, "m": "a tiny ball of bat guano and sulfur"},
      "duration": [{"type": "instant"}],
      "entries": ["A bright streak flashes from your pointing finger to a point you choose within range."]
    },
    {
      "name": "Void Lance",
      "level": 4,
      "school": "V",
      "time": "1 action",
      "range": "120 feet",
      "components": "V, S",
      "duration": "Instantaneous",
      "entries": ["A beam of {@damage 6d8|necrotic} void energy pierces through targets."]
    }
  ],
  "monster": [
    {
      "name": "Goblin",
      "size": "S",
      "type": "humanoid",
      "alignment": ["N", "E"],
      "ac": 15,
      "hp": {"average": 7, "formula": "2d6"},
      "speed": {"walk": 30},
      "cr": "1/4",
      "action": [
        {"name": "Scimitar", "entries": ["Melee Weapon Attack: +4 to hit, reach 5 ft., one target. Hit: 5 (1d6 + 2) slashing damage."]}
      ]
    },
    {
      "name": "Void Abomination",
      "size": "Huge",
      "type": "aberration",
      "ac": 17,
      "hp": "140 (16d12 + 36)",
      "speed": "40 ft., fly 60 ft.",
      "cr": "9",
      "trait": [
        "Void Aura. Any creature that starts its turn within 10 ft. takes 2d6 necrotic damage."
      ],
      "action": [
        "Void Slam: +8 to hit, reach 10 ft. Hit: 18 (3d8 + 5) force damage."
      ]
    }
  ],
  "item": [
    {
      "name": "Potion of Healing",
      "type": "P",
      "rarity": "Common",
      "entries": ["You regain 2d4 + 2 hit points when you drink this potion."]
    },
    {
      "name": "Blade of the Nether",
      "type": "M",
      "rarity": "very rare",
      "reqAttune": true,
      "desc": "A jagged blade that radiates necrotic whispers."
    }
  ],
  "class": [
    {
      "name": "Fighter",
      "hd": {"faces": 10},
      "proficiency": ["STR", "CON"],
      "classFeatures": ["Second Wind: Regain hp", "Action Surge: Take an extra action"]
    },
    {
      "name": "Blood Mage",
      "hd": 8,
      "proficiency": ["CON", "INT"],
      "classFeatures": [
        {"name": "Blood Siphon", "entries": ["Drain vitality to empower spells."]}
      ]
    }
  ]
}
''';

      final ingestion = pipeline.ingestJsonString(mixedJson);
      expect(ingestion.hasErrors, isFalse);
      expect(ingestion.spells.length, equals(2));
      expect(ingestion.monsters.length, equals(2));
      expect(ingestion.items.length, equals(2));
      expect(ingestion.classes.length, equals(2));

      // Analyze with HomebrewMergeResolver
      final bundle = ingestion.toBundle();
      final analysis = resolver.analyzeBundle(incomingBundle: bundle);

      // SRD items (Fireball, Goblin, Potion of Healing, Fighter) MUST be marked SRD canon and excluded
      expect(analysis.srdDuplicateCount, equals(4));

      // Homebrew items (Void Lance, Void Abomination, Blade of the Nether, Blood Mage) MUST be Novel and selected
      expect(analysis.novelCount, equals(4));
      expect(analysis.selectedCount, equals(4));

      // Check Spells
      final fireball = analysis.spells.firstWhere((s) => s.displayName == 'Fireball');
      expect(fireball.isSrdCanon, isTrue);
      expect(fireball.isSelected, isFalse);

      final voidLance = analysis.spells.firstWhere((s) => s.displayName == 'Void Lance');
      expect(voidLance.isSrdCanon, isFalse);
      expect(voidLance.isSelected, isTrue);
      expect(voidLance.incomingEntity.damageMath.first.diceFormula, equals('6d8'));

      // Check Monsters
      final goblin = analysis.monsters.firstWhere((m) => m.displayName == 'Goblin');
      expect(goblin.isSrdCanon, isTrue);
      expect(goblin.isSelected, isFalse);

      final voidAbom = analysis.monsters.firstWhere((m) => m.displayName == 'Void Abomination');
      expect(voidAbom.isSrdCanon, isFalse);
      expect(voidAbom.isSelected, isTrue);
      expect(voidAbom.incomingEntity.hitPoints, equals(140));
      expect(voidAbom.incomingEntity.actionsMarkdown, contains('Void Aura'));

      // Check Items
      final potion = analysis.items.firstWhere((i) => i.displayName == 'Potion of Healing');
      expect(potion.isSrdCanon, isTrue);
      expect(potion.isSelected, isFalse);

      final blade = analysis.items.firstWhere((i) => i.displayName == 'Blade of the Nether');
      expect(blade.isSrdCanon, isFalse);
      expect(blade.isSelected, isTrue);
      expect(blade.incomingEntity.rarity, equals('Very Rare'));
      expect(blade.incomingEntity.descriptionMarkdown, contains('necrotic whispers'));

      // Check Classes
      final fighter = analysis.classes.firstWhere((c) => c.displayName == 'Fighter');
      expect(fighter.isSrdCanon, isTrue);
      expect(fighter.isSelected, isFalse);

      final bloodMage = analysis.classes.firstWhere((c) => c.displayName == 'Blood Mage');
      expect(bloodMage.isSrdCanon, isFalse);
      expect(bloodMage.isSelected, isTrue);
      expect(bloodMage.incomingEntity.featuresMarkdown, contains('Blood Siphon'));
    });
  });
}
