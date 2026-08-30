import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('Additive Subclasses Ingestion & SrdClassesLibrary Integration Tests', () {
    late CompendiumJsonIngestionPipeline pipeline;
    late HomebrewMergeResolver resolver;
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      pipeline = CompendiumJsonIngestionPipeline();
      resolver = const HomebrewMergeResolver();
      persistence = HomebrewPersistenceService();
      SrdClassesLibrary.setCustomClasses([]);
      SrdClassesLibrary.setCustomSubclasses([]);
    });

    test('ingesting SRD class with new homebrew subclass extracts subclass as novel additive addition', () async {
      const compendiumJson = '''
{
  "class": [
    {
      "name": "Fighter",
      "source": "PHB",
      "hd": {"faces": 10},
      "proficiency": ["STR", "CON"],
      "subclasses": [
        {
          "name": "Champion",
          "source": "PHB",
          "subclassFeatures": ["Improved Critical"]
        },
        {
          "name": "Echo Knight",
          "source": "EGtW",
          "subclassFeatures": [
            {"name": "Manifest Echo", "entries": ["You can summon an echo of yourself in combat."]}
          ]
        }
      ]
    }
  ],
  "subclass": [
    {
      "name": "Clockwork Soul",
      "className": "Sorcerer",
      "source": "TCE",
      "subclassFeatures": [
        {"name": "Clockwork Magic", "entries": ["You learn additional spells related to cosmic order."]}
      ]
    }
  ]
}
''';

      final ingestion = pipeline.ingestJsonString(compendiumJson);
      expect(ingestion.hasErrors, isFalse);
      expect(ingestion.classes.length, equals(1));
      // Champion, Echo Knight, and Clockwork Soul in subclasses
      expect(ingestion.subclasses.length, equals(3));

      final bundle = ingestion.toBundle();
      final analysis = resolver.analyzeBundle(incomingBundle: bundle);

      // Fighter is SRD Built-in (excluded by default)
      final fighterClass = analysis.classes.firstWhere((c) => c.displayName == 'Fighter');
      expect(fighterClass.isSrdCanon, isTrue);
      expect(fighterClass.isSelected, isFalse);

      // Champion is SRD Built-in subclass (excluded by default)
      final champion = analysis.subclasses.firstWhere((s) => s.displayName == 'Champion');
      expect(champion.isSrdCanon, isTrue);
      expect(champion.isSelected, isFalse);

      // Echo Knight is NOT SRD — must be marked novel and selected by default
      final echoKnight = analysis.subclasses.firstWhere((s) => s.displayName == 'Echo Knight');
      expect(echoKnight.isSrdCanon, isFalse);
      expect(echoKnight.disposition, equals(ImportDisposition.novel));
      expect(echoKnight.isSelected, isTrue);
      expect(echoKnight.incomingEntity.classSlug, equals('fighter'));

      // Clockwork Soul is NOT SRD — must be marked novel and selected by default
      final clockwork = analysis.subclasses.firstWhere((s) => s.displayName == 'Clockwork Soul');
      expect(clockwork.isSrdCanon, isFalse);
      expect(clockwork.disposition, equals(ImportDisposition.novel));
      expect(clockwork.isSelected, isTrue);
      expect(clockwork.incomingEntity.classSlug, equals('sorcerer'));

      // Import the resolved bundle into persistence
      await persistence.importResolvedBundle(analysis);

      // Check loaded subclasses from persistence
      final loadedSubs = await persistence.loadCustomSubclasses();
      expect(loadedSubs.length, equals(2));

      // Verify SrdClassesLibrary dynamically incorporates the new subclasses
      final fighterInLib = SrdClassesLibrary.findBySlug('fighter');
      expect(fighterInLib, isNotNull);
      expect(fighterInLib!.subclasses.any((s) => s.name == 'Echo Knight'), isTrue);
      expect(fighterInLib.subclasses.any((s) => s.name == 'Champion'), isTrue);

      final sorcererInLib = SrdClassesLibrary.findBySlug('sorcerer');
      expect(sorcererInLib, isNotNull);
      expect(sorcererInLib!.subclasses.any((s) => s.name == 'Clockwork Soul'), isTrue);

      // Verify deleting a custom subclass updates the library dynamically
      await persistence.deleteCustomSubclass('echo-knight');
      final updatedFighter = SrdClassesLibrary.findBySlug('fighter');
      expect(updatedFighter!.subclasses.any((s) => s.name == 'Echo Knight'), isFalse);
      expect(updatedFighter.subclasses.any((s) => s.name == 'Champion'), isTrue);
    });
  });
}
