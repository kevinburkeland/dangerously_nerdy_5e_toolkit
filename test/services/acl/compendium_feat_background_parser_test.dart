import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_background_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_feat_parser.dart';

void main() {
  group('Community Compendium & Homebrew Feat & Background Parser Tests', () {
    late CompendiumFeatParser featParser;
    late CompendiumBackgroundParser backgroundParser;

    setUp(() {
      featParser = CompendiumFeatParser();
      backgroundParser = CompendiumBackgroundParser();
    });

    test('parses Origin Feat with structured prerequisites', () {
      final raw = {
        'name': 'Alert',
        'source': 'SRD52',
        'category': 'Origin',
        'prerequisite': [
          {'level': 1, 'other': 'Origin Feat'}
        ],
        'entries': [
          'You gain proficiency in Initiative rolls.',
          'Immediately after you roll Initiative, you can swap your initiative with a willing ally.'
        ],
        'customTag': '2024 Revised Core'
      };

      final feat = featParser.parseFeat(raw);

      expect(feat.name, equals('Alert'));
      expect(feat.id.slug, equals('alert'));
      expect(feat.id.ruleset, equals(RulesetVersion.v2024));
      expect(feat.category, equals('Origin'));
      expect(feat.prerequisite, contains('Level 1'));
      expect(feat.descriptionMarkdown, contains('proficiency in Initiative'));
      expect(feat.customProperties['customTag'], equals('2024 Revised Core'));
    });

    test('parses 2024 Background with Origin Feat and multi-skill proficiencies', () {
      final raw = {
        'name': 'Acolyte',
        'source': 'SRD52',
        'ability': [
          {'int': true, 'wis': true, 'cha': true}
        ],
        'feat': 'Magic Initiate',
        'skillProficiencies': ['Insight', 'Religion'],
        'toolProficiencies': ['Calligrapher\'s supplies'],
        'languageProficiencies': ['Celestial'],
        'startingEquipment': [
          {'item': 'Holy Symbol'},
          {'item': 'Pouch with 15 GP'}
        ],
        'entries': [
          'You devoted yourself to service in a temple.',
          'Feature: Shelter of the Faithful. You and your companions can receive free healing and care at a temple.'
        ],
        'flavorLore': 'Canonical SRD 5.2 religious acolyte'
      };

      final bg = backgroundParser.parseBackground(raw);

      expect(bg.name, equals('Acolyte'));
      expect(bg.id.slug, equals('acolyte'));
      expect(bg.originFeat, equals('Magic Initiate'));
      expect(bg.skillProficiencies, contains('Insight'));
      expect(bg.skillProficiencies, contains('Religion'));
      expect(bg.toolProficiencies, contains('Calligrapher\'s supplies'));
      expect(bg.languages, contains('Celestial'));
      expect(bg.abilityScoreSummary, contains('INT'));
      expect(bg.descriptionMarkdown, contains('Shelter of the Faithful'));
      expect(bg.customProperties['flavorLore'], equals('Canonical SRD 5.2 religious acolyte'));
      expect(bg.customProperties['startingEquipment'], isNotNull);
    });
  });
}
