import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/homebrew_merge_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('Warlock 2nd Level Invocations & Homebrew Ingestion Tests', () {
    late CompendiumJsonIngestionPipeline pipeline;
    late HomebrewMergeResolver resolver;
    late HomebrewPersistenceService persistence;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      pipeline = CompendiumJsonIngestionPipeline();
      resolver = const HomebrewMergeResolver();
      persistence = HomebrewPersistenceService();
      SrdFeatureOptions.setCustomInvocations([]);
    });

    test('Warlock has Eldritch Invocations decision at 2nd level requiring 2 choices', () {
      final warlock = SrdClassesLibrary.warlock;
      final level2Decisions = warlock.getDecisionsForLevel(2);

      expect(level2Decisions, isNotEmpty);
      final invocationDecision = level2Decisions.firstWhere(
        (d) => d.type == FeatureChoiceType.invocations,
      );

      expect(invocationDecision.minSelections, equals(2));
      expect(invocationDecision.maxSelections, equals(2));
      expect(invocationDecision.availableOptions.length, greaterThanOrEqualTo(25));
    });

    test('SrdFeatureOptions contains comprehensive canonical SRD invocations', () {
      final invocations = SrdFeatureOptions.warlockInvocationsAndBoons;
      final ids = invocations.map((i) => i.id).toSet();

      expect(ids.contains('agonizing_blast'), isTrue);
      expect(ids.contains('armor_of_shadows'), isTrue);
      expect(ids.contains('beast_speech'), isTrue);
      expect(ids.contains('beguiling_influence'), isTrue);
      expect(ids.contains('devils_sight'), isTrue);
      expect(ids.contains('eldritch_sight'), isTrue);
      expect(ids.contains('eldritch_spear'), isTrue);
      expect(ids.contains('eyes_of_the_rune_keeper'), isTrue);
      expect(ids.contains('fiendish_vigor'), isTrue);
      expect(ids.contains('mask_of_many_faces'), isTrue);
      expect(ids.contains('misty_visions'), isTrue);
      expect(ids.contains('repelling_blast'), isTrue);
      expect(ids.contains('book_of_ancient_secrets'), isTrue);
      expect(ids.contains('thirsting_blade'), isTrue);
      expect(ids.contains('lifedrinker'), isTrue);
      expect(ids.contains('whispers_of_the_grave'), isTrue);
      expect(ids.contains('pact_of_the_blade'), isTrue);
      expect(ids.contains('pact_of_the_tome'), isTrue);
      expect(ids.contains('pact_of_the_chain'), isTrue);
    });

    test('Ingests custom homebrew Eldritch Invocations and links to warlock feature choices', () async {
      const jsonCompendium = '''
{
  "invocation": [
    {
      "name": "Grasp of Hadar",
      "source": "XGE",
      "entries": [
        "Prerequisite: Eldritch Blast cantrip. Once on each of your turns when you hit a creature with your Eldritch Blast, you can move that creature in a straight line 10 feet closer to you."
      ]
    }
  ],
  "optionalfeature": [
    {
      "name": "Tomb of Levistus",
      "source": "XGE",
      "featureType": "EI",
      "entries": [
        "As a reaction on taking damage, entomb yourself in ice gaining 10 temporary HP per warlock level."
      ]
    },
    {
      "name": "Agonizing Blast",
      "source": "PHB",
      "featureType": "EI",
      "entries": [
        "Add Charisma modifier to Eldritch Blast damage."
      ]
    }
  ]
}
''';

      final ingestion = pipeline.ingestJsonString(jsonCompendium);
      expect(ingestion.hasErrors, isFalse);
      expect(ingestion.otherEntries.length, equals(3));

      // All 3 should be categorized as Eldritch Invocation
      for (final entry in ingestion.otherEntries) {
        expect(entry.category, equals('Eldritch Invocation'));
      }

      final bundle = ingestion.toBundle();
      final analysis = resolver.analyzeBundle(incomingBundle: bundle);

      // Canonical Agonizing Blast should be identified as SRD Built-in (excluded)
      final agonizing = analysis.otherEntries.firstWhere((e) => e.displayName == 'Agonizing Blast');
      expect(agonizing.isSrdCanon, isTrue);
      expect(agonizing.isSelected, isFalse);

      // Grasp of Hadar and Tomb of Levistus should be Novel homebrew (selected)
      final grasp = analysis.otherEntries.firstWhere((e) => e.displayName == 'Grasp of Hadar');
      expect(grasp.isSrdCanon, isFalse);
      expect(grasp.disposition, equals(ImportDisposition.novel));
      expect(grasp.isSelected, isTrue);

      final tomb = analysis.otherEntries.firstWhere((e) => e.displayName == 'Tomb of Levistus');
      expect(tomb.isSrdCanon, isFalse);
      expect(tomb.disposition, equals(ImportDisposition.novel));
      expect(tomb.isSelected, isTrue);

      // Import the resolved bundle into persistence
      await persistence.importResolvedBundle(analysis);

      // Check that SrdFeatureOptions dynamically includes the custom imported invocations
      final updatedOptions = SrdFeatureOptions.warlockInvocationsAndBoons;
      expect(updatedOptions.any((o) => o.name == 'Grasp of Hadar'), isTrue);
      expect(updatedOptions.any((o) => o.name == 'Tomb of Levistus'), isTrue);

      // Level 2 Warlock decisions should now offer these newly imported invocations
      final warlockLvl2 = SrdClassesLibrary.warlock.getDecisionsForLevel(2).first;
      expect(warlockLvl2.availableOptions.any((o) => o.name == 'Grasp of Hadar'), isTrue);
      expect(warlockLvl2.availableOptions.any((o) => o.name == 'Tomb of Levistus'), isTrue);

      // Deleting custom invocation removes it from options
      await persistence.deleteCustomOtherEntry('grasp-of-hadar');
      expect(SrdFeatureOptions.warlockInvocationsAndBoons.any((o) => o.name == 'Grasp of Hadar'), isFalse);
      expect(SrdFeatureOptions.warlockInvocationsAndBoons.any((o) => o.name == 'Tomb of Levistus'), isTrue);
    });
  });
}
