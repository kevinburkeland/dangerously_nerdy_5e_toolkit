import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/generic_tag_scrubber.dart';

void main() {
  group('GenericTagScrubber Tests', () {
    test('Scrubs simple damage tags', () {
      expect(GenericTagScrubber.scrub('deals {@damage 1d6 + 2} piercing'),
          equals('deals 1d6 + 2 piercing'));
      expect(GenericTagScrubber.scrub('deals {@damage 2d8} fire'),
          equals('deals 2d8 fire'));
    });

    test('Scrubs dice tags and hit bonuses', () {
      expect(GenericTagScrubber.scrub('Roll {@dice 1d20+5} check'),
          equals('Roll 1d20+5 check'));
      expect(GenericTagScrubber.scrub('Attack: {@hit +7} to hit'),
          equals('Attack: +7 to hit'));
      expect(GenericTagScrubber.scrub('Attack: {@hit 5} to hit'),
          equals('Attack: +5 to hit'));
    });

    test('Scrubs spell and item tags with source references', () {
      expect(GenericTagScrubber.scrub('Can cast {@spell misty step|phb}.'),
          equals('Can cast misty step.'));
      expect(GenericTagScrubber.scrub('Wields a {@item vorpal sword|dmg}.'),
          equals('Wields a vorpal sword.'));
      expect(
          GenericTagScrubber.scrub('Inflicted with {@condition poisoned|phb}.'),
          equals('Inflicted with poisoned.'));
    });

    test('Honors explicit display text overrides in multi-part pipe tags', () {
      expect(
        GenericTagScrubber.scrub(
            'Can cast {@spell misty step|phb|Hellish Step}.'),
        equals('Can cast Hellish Step.'),
      );
      expect(
        GenericTagScrubber.scrub(
            'Carries a {@item potion of healing|dmg|Elixir of Vitality}.'),
        equals('Carries a Elixir of Vitality.'),
      );
    });

    test('Scrubs mechanical dc and recharge tags cleanly', () {
      expect(GenericTagScrubber.scrub('Targets make a {@dc 15} saving throw.'),
          equals('Targets make a DC 15 saving throw.'));
      expect(GenericTagScrubber.scrub('Recharge rate: {@recharge 5-6}'),
          equals('Recharge rate: (Recharge 5-6)'));
      expect(GenericTagScrubber.scrub('Recharge rate: {@recharge}'),
          equals('Recharge rate: (Recharge 5–6)'));
    });

    test('Scrubs formatting and link tags', () {
      expect(
          GenericTagScrubber.scrub(
              'See {@link Rules Reference|https://example.com}'),
          equals('See Rules Reference'));
      expect(GenericTagScrubber.scrub('Caution: {@note Take care here}'),
          equals('Caution: Take care here'));
    });

    test('Resolves nested markup tags recursively', () {
      expect(
        GenericTagScrubber.scrub(
            'Special attack: {@note deals {@damage 3d6} on {@spell fireball|phb}}'),
        equals('Special attack: deals 3d6 on fireball'),
      );
    });

    test(
        'Recursively scrubs entire Map and List structures without dropping keys',
        () {
      final inputMap = {
        'name': '{@spell misty step|phb}',
        'description': 'Cast {@spell fireball|phb} dealing {@damage 8d6} fire.',
        'dc': '{@dc 17}',
        'nested': {
          'effects': [
            'Target is {@condition blinded}',
            'Attack bonus: {@hit +9}',
          ],
          'recharge': '{@recharge 6}',
        },
        'unrecognizedVendorData': {
          'preserveMe': 123,
          'nestedList': ['{@dice 2d4}'],
        },
      };

      final scrubbed = GenericTagScrubber.scrubMap(inputMap);

      expect(scrubbed['name'], equals('misty step'));
      expect(
          scrubbed['description'], equals('Cast fireball dealing 8d6 fire.'));
      expect(scrubbed['dc'], equals('DC 17'));
      final nested = scrubbed['nested'] as Map<String, dynamic>;
      expect(
          nested['effects'], equals(['Target is blinded', 'Attack bonus: +9']));
      expect(nested['recharge'], equals('(Recharge 6)'));

      // Check preservation of unparsed/unrecognized keys
      final vendor = scrubbed['unrecognizedVendorData'] as Map<String, dynamic>;
      expect(vendor['preserveMe'], equals(123));
      expect(vendor['nestedList'], equals(['2d4']));
    });

    test('Copy-on-write preserves map and list identity when no tags exist',
        () {
      final cleanMap = {
        'name': 'Longsword',
        'damage': '1d8',
        'properties': ['versatile', 'martial'],
        'details': {
          'weight': 3,
          'cost': '15 gp',
        },
      };

      final scrubbed = GenericTagScrubber.scrubMap(cleanMap);
      expect(identical(scrubbed, cleanMap), isTrue);
      expect(identical(scrubbed['properties'], cleanMap['properties']), isTrue);
      expect(identical(scrubbed['details'], cleanMap['details']), isTrue);
    });
  });
}
