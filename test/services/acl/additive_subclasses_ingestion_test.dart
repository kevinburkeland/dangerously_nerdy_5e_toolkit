import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('Additive Subclasses Ingestion & SrdClassesLibrary Integration Tests',
      () {
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

    test(
        'ingesting SRD class with new homebrew subclass extracts subclass as novel additive addition',
        () async {
      const compendiumJson = '''
{
  "class": [
    {
      "name": "Fighter",
      "source": "SRD",
      "hd": {"faces": 10},
      "proficiency": ["STR", "CON"],
      "subclasses": [
        {
          "name": "Champion",
          "source": "SRD",
          "subclassFeatures": ["Improved Critical"]
        },
        {
          "name": "Rift Warden",
          "source": "HOMEBREW",
          "subclassFeatures": [
            {"name": "Rift Step", "entries": ["You can summon a planar rift in combat."]}
          ]
        }
      ]
    }
  ],
  "subclass": [
    {
      "name": "Astral Sorcerer",
      "className": "Sorcerer",
      "source": "HOMEBREW",
      "subclassFeatures": [
        {"name": "Astral Weaving", "entries": ["You learn additional spells related to cosmic order."]}
      ]
    }
  ]
}
''';

      final ingestion = pipeline.ingestJsonString(compendiumJson);
      expect(ingestion.hasErrors, isFalse);
      expect(ingestion.classes.length, equals(1));
      // Champion, Rift Warden, and Astral Sorcerer in subclasses
      expect(ingestion.subclasses.length, equals(3));

      final bundle = ingestion.toBundle();
      final analysis = resolver.analyzeBundle(incomingBundle: bundle);

      // Fighter is SRD Built-in (excluded by default)
      final fighterClass =
          analysis.classes.firstWhere((c) => c.displayName == 'Fighter');
      expect(fighterClass.isSrdCanon, isTrue);
      expect(fighterClass.isSelected, isFalse);

      // Champion is SRD Built-in subclass (excluded by default)
      final champion =
          analysis.subclasses.firstWhere((s) => s.displayName == 'Champion');
      expect(champion.isSrdCanon, isTrue);
      expect(champion.isSelected, isFalse);

      // Rift Warden is NOT SRD — must be marked novel and selected by default
      final riftWarden =
          analysis.subclasses.firstWhere((s) => s.displayName == 'Rift Warden');
      expect(riftWarden.isSrdCanon, isFalse);
      expect(riftWarden.disposition, equals(ImportDisposition.novel));
      expect(riftWarden.isSelected, isTrue);
      expect(riftWarden.incomingEntity.classSlug, equals('fighter'));

      // Astral Sorcerer is NOT SRD — must be marked novel and selected by default
      final astralSorcerer = analysis.subclasses
          .firstWhere((s) => s.displayName == 'Astral Sorcerer');
      expect(astralSorcerer.isSrdCanon, isFalse);
      expect(astralSorcerer.disposition, equals(ImportDisposition.novel));
      expect(astralSorcerer.isSelected, isTrue);
      expect(astralSorcerer.incomingEntity.classSlug, equals('sorcerer'));

      // Import the resolved bundle into persistence
      await persistence.importResolvedBundle(analysis);

      // Check loaded subclasses from persistence
      final loadedSubs = await persistence.loadCustomSubclasses();
      expect(loadedSubs.length, equals(2));

      // Verify SrdClassesLibrary dynamically incorporates the new subclasses
      final fighterInLib = SrdClassesLibrary.findBySlug('fighter');
      expect(fighterInLib, isNotNull);
      expect(
          fighterInLib!.subclasses.any((s) => s.name == 'Rift Warden'), isTrue);
      expect(fighterInLib.subclasses.any((s) => s.name == 'Champion'), isTrue);

      final sorcererInLib = SrdClassesLibrary.findBySlug('sorcerer');
      expect(sorcererInLib, isNotNull);
      expect(sorcererInLib!.subclasses.any((s) => s.name == 'Astral Sorcerer'),
          isTrue);

      // Verify deleting a custom subclass updates the library dynamically
      await persistence.deleteCustomSubclass('rift-warden');
      final updatedFighter = SrdClassesLibrary.findBySlug('fighter');
      expect(updatedFighter!.subclasses.any((s) => s.name == 'Rift Warden'),
          isFalse);
      expect(
          updatedFighter.subclasses.any((s) => s.name == 'Champion'), isTrue);
    });
  });
}
