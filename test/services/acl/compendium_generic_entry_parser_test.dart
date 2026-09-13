import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_generic_entry_parser.dart';

void main() {
  group('CompendiumGenericEntryParser Tests', () {
    late CompendiumGenericEntryParser parser;

    setUp(() {
      parser = CompendiumGenericEntryParser();
    });

    test('parses rollable table into formatted markdown table', () {
      final json = {
        'name': 'Wandering Celestial Encounters',
        'colLabels': ['d4', 'Encounter'],
        'rows': [
          ['1', 'A shower of falling starlight'],
          ['2', 'An astral courier gliding through the sky'],
          ['3', 'A dormant beacon of ancient silver'],
          ['4', 'A planar boundary shimmering faintly'],
        ],
      };

      final entry = parser.parseGenericEntry(json, defaultCategory: 'table');
      expect(entry.name, equals('Wandering Celestial Encounters'));
      expect(entry.category, equals('Table'));
      expect(entry.descriptionMarkdown, contains('| d4 | Encounter |'));
      expect(entry.descriptionMarkdown, contains('| :--- | :--- |'));
      expect(entry.descriptionMarkdown, contains('| 1 | A shower of falling starlight |'));
      expect(entry.descriptionMarkdown, contains('| 4 | A planar boundary shimmering faintly |'));
    });

    test('parses deity entry with structured pantheon and domain metadata header', () {
      final json = {
        'name': 'Solas the Dawnbringer',
        'pantheon': 'Solar Expanse',
        'alignment': ['L', 'G'],
        'domains': ['Light', 'Life'],
        'symbol': 'A blazing sun rising above twin mountains',
        'entries': [
          'Solas embodies the unyielding light of truth, inspiring healers and paladins across the frontier.',
        ],
      };

      final entry = parser.parseGenericEntry(json, defaultCategory: 'deity');
      expect(entry.name, equals('Solas the Dawnbringer'));
      expect(entry.category, equals('Deity'));
      expect(entry.descriptionMarkdown, contains('**Pantheon:** Solar Expanse'));
      expect(entry.descriptionMarkdown, contains('**Alignment:** LG'));
      expect(entry.descriptionMarkdown, contains('**Domains:** Light, Life'));
      expect(entry.descriptionMarkdown, contains('**Symbol:** A blazing sun rising above twin mountains'));
      expect(entry.descriptionMarkdown, contains('Solas embodies the unyielding light'));
    });

    test('normalizes categorized entries for vehicles, traps, and hazards', () {
      final vehicleJson = {
        'name': 'Dune Skiff',
        'entries': ['A light wooden skiff equipped with silk sails for gliding over sand dunes.'],
      };
      final vehicleEntry = parser.parseGenericEntry(vehicleJson, defaultCategory: 'vehicle');
      expect(vehicleEntry.category, equals('Vehicle'));

      final trapJson = {
        'name': 'Pressure Plate Dart Trap',
        'entries': ['Stepping on this stone plate triggers a volley of poisoned needles.'],
      };
      final trapEntry = parser.parseGenericEntry(trapJson, defaultCategory: 'trap');
      expect(trapEntry.category, equals('Trap'));

      final hazardJson = {
        'name': 'Spore Blossom Cloud',
        'entries': ['Disturbing the fungal blooms creates a choking yellow mist.'],
      };
      final hazardEntry = parser.parseGenericEntry(hazardJson, defaultCategory: 'hazard');
      expect(hazardEntry.category, equals('Hazard'));
    });

    test('preserves extra properties in customProperties for lossless serialization', () {
      final json = {
        'name': 'Echoes of the Ancients',
        'chapter': 3,
        'page': 42,
        'customTags': ['lore', 'pre-cataclysm'],
        'entries': ['In the first age of the mortal realm...'],
      };

      final entry = parser.parseGenericEntry(json, defaultCategory: 'lore');
      expect(entry.customProperties['chapter'], equals(3));
      expect(entry.customProperties['page'], equals(42));
      expect(entry.customProperties['customTags'], contains('pre-cataclysm'));
    });
  });
}
