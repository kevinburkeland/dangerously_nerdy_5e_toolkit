import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  group('Subclass Features Separation Ingestion Tests', () {
    late CompendiumJsonIngestionPipeline pipeline;

    setUp(() {
      pipeline = CompendiumJsonIngestionPipeline();
    });

    test('ingestion routes subclass features to Subclass and keeps Class featuresMarkdown clean', () {
      const jsonCompendium = '''
{
  "class": [
    {
      "name": "Warden",
      "source": "HOMEBREW",
      "hd": {"faces": 10},
      "classFeatures": [
        "Defensive Stance|Warden||1",
        {
          "classFeature": "Bulwark Shield|Warden||Bulwark||2",
          "gainSubclassFeature": true
        },
        {
          "classFeature": "Iron Vanguard|Warden||Bulwark||2",
          "gainSubclassFeature": true
        }
      ]
    }
  ],
  "subclass": [
    {
      "name": "Bulwark Warden",
      "className": "Warden",
      "shortName": "Bulwark",
      "source": "HOMEBREW",
      "subclassFeatures": [
        "Bulwark Shield|Warden||Bulwark|HOMEBREW|2",
        "Iron Vanguard|Warden||Bulwark|HOMEBREW|2",
        "Unbreakable Bastion|Warden||Bulwark|HOMEBREW|6"
      ]
    }
  ],
  "classFeature": [
    {
      "name": "Defensive Stance",
      "className": "Warden",
      "level": 1,
      "entries": [
        "You take a defensive stance, gaining a +1 bonus to Armor Class."
      ]
    },
    {
      "name": "Bulwark Shield",
      "className": "Warden",
      "subclassShortName": "Bulwark",
      "level": 2,
      "entries": [
        "You can interpose your shield to intercept incoming projectiles."
      ]
    },
    {
      "name": "Iron Vanguard",
      "className": "Warden",
      "subclassShortName": "Bulwark",
      "level": 2,
      "entries": [
        "Your armor resilience protects allies standing within 5 feet of you."
      ]
    },
    {
      "name": "Unbreakable Bastion",
      "className": "Warden",
      "subclassShortName": "Bulwark",
      "level": 6,
      "entries": [
        "You gain resistance to all physical damage while you are not incapacitated."
      ]
    }
  ]
}
''';

      final result = pipeline.ingestJsonString(jsonCompendium);
      expect(result.hasErrors, isFalse);
      expect(result.classes.length, equals(1));
      expect(result.subclasses.length, equals(1));

      final wardenClass = result.classes.first;
      expect(wardenClass.name, equals('Warden'));

      // Core class featuresMarkdown MUST contain base features
      expect(wardenClass.featuresMarkdown, contains('Defensive Stance'));
      expect(wardenClass.featuresMarkdown, contains('gaining a +1 bonus to Armor Class'));

      // Core class featuresMarkdown MUST NOT contain subclass features
      expect(wardenClass.featuresMarkdown, isNot(contains('Bulwark Shield')));
      expect(wardenClass.featuresMarkdown, isNot(contains('Iron Vanguard')));
      expect(wardenClass.featuresMarkdown, isNot(contains('Unbreakable Bastion')));

      // Subclass featuresMarkdown MUST contain the subclass features
      final bulwarkSub = result.subclasses.first;
      expect(bulwarkSub.name, equals('Bulwark Warden'));
      expect(bulwarkSub.featuresMarkdown, contains('Bulwark Shield (Level 2)'));
      expect(bulwarkSub.featuresMarkdown, contains('Iron Vanguard (Level 2)'));
      expect(bulwarkSub.featuresMarkdown, contains('Unbreakable Bastion (Level 6)'));
      expect(bulwarkSub.featuresMarkdown, contains('intercept incoming projectiles'));
    });
  });
}
