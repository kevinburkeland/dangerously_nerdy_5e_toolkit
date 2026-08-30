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
        'source': 'XPHB',
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
        'name': 'Wayfarer',
        'source': 'XPHB',
        'ability': [
          {'dex': true, 'wis': true, 'cha': true}
        ],
        'feat': 'Lucky',
        'skillProficiencies': ['Insight', 'Stealth'],
        'toolProficiencies': ['Thieves\' tools'],
        'languageProficiencies': ['Thieves\' cant'],
        'startingEquipment': [
          {'item': 'Thieves\' tools'},
          {'item': 'Pouch with 16 GP'}
        ],
        'entries': [
          'You grew up among travelers, drifters, and wanderers.',
          'Feature: Wayfarer\'s Network. You know informants in every major settlement.'
        ],
        'flavorLore': 'Street urchin background refined for 2024'
      };

      final bg = backgroundParser.parseBackground(raw);

      expect(bg.name, equals('Wayfarer'));
      expect(bg.id.slug, equals('wayfarer'));
      expect(bg.originFeat, equals('Lucky'));
      expect(bg.skillProficiencies, contains('Insight'));
      expect(bg.skillProficiencies, contains('Stealth'));
      expect(bg.toolProficiencies, contains('Thieves\' tools'));
      expect(bg.languages, contains('Thieves\' cant'));
      expect(bg.abilityScoreSummary, contains('DEX'));
      expect(bg.descriptionMarkdown, contains('Wayfarer\'s Network'));
      expect(bg.customProperties['flavorLore'], equals('Street urchin background refined for 2024'));
      expect(bg.customProperties['startingEquipment'], isNotNull);
    });
  });
}
