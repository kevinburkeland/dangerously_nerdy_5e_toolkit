import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/spell_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/animated_object_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/mappers/homebrew_ingestor.dart';

void main() {
  group('SpellDto & Unparsed Payload Scooping', () {
    test('fromJson preserves standard fields and scoops unknown keys into unparsedPayload', () {
      final json = {
        'id': 'eldritch-blast-custom',
        'name': 'Custom Eldritch Blast',
        'level': 0,
        'school': 'Evocation',
        'castingTime': '1 action',
        'duration': 'Instantaneous',
        'range': '120 feet',
        'descriptionMarkdown': 'A beam of crackling energy.',
        // Homebrew extra properties
        'homebrewSource': 'Grim Hollow',
        'customVfxId': 'fx-eldritch-purple',
        'isSignatureSpell': true,
        'nestedVendorMetadata': {'price': 500, 'rarity': 'uncommon'},
      };

      final dto = SpellDto.fromJson(json);

      expect(dto.id, equals('eldritch-blast-custom'));
      expect(dto.name, equals('Custom Eldritch Blast'));
      expect(dto.level, equals(0));
      expect(dto.school, equals('Evocation'));
      expect(dto.unparsedPayload.containsKey('homebrewSource'), isTrue);
      expect(dto.unparsedPayload['homebrewSource'], equals('Grim Hollow'));
      expect(dto.unparsedPayload['customVfxId'], equals('fx-eldritch-purple'));
      expect(dto.unparsedPayload['isSignatureSpell'], isTrue);
      expect(dto.unparsedPayload['nestedVendorMetadata'], equals({'price': 500, 'rarity': 'uncommon'}));

      // Verify round-trip serialization retains unparsed fields
      final serialized = dto.toMap();
      expect(serialized['homebrewSource'], equals('Grim Hollow'));
      expect(serialized['customVfxId'], equals('fx-eldritch-purple'));
      expect(serialized['isSignatureSpell'], isTrue);
      expect(serialized['nestedVendorMetadata'], equals({'price': 500, 'rarity': 'uncommon'}));

      // Verify domain conversion
      final domainSpell = dto.toDomain();
      expect(domainSpell.id.slug, equals('eldritch-blast-custom'));
      expect(domainSpell.name, equals('Custom Eldritch Blast'));
      expect(domainSpell.customProperties['homebrewSource'], equals('Grim Hollow'));
    });

    test('SpellDto clamps level between 0 and 9 and defaults missing fields safely', () {
      final json = {
        'id': 'epic-spell',
        'name': 'Epic 12th Level Spell',
        'level': 12,
      };

      final dto = SpellDto.fromJson(json);
      expect(dto.level, equals(9));
      expect(dto.school, equals('Universal'));
      expect(dto.range, equals('Self'));
    });
  });

  group('AnimatedObjectDto Unparsed Payload Tests', () {
    test('fromMap scoops unknown fields into unparsedPayload and retains them in toMap', () {
      final map = {
        'id': 'minion-123',
        'name': 'Animated Sword',
        'size': 'small',
        'currentHp': 20,
        'maxHp': 20,
        'homebrewAura': 'holy_glow',
        'customTag': 42,
      };

      final dto = AnimatedObjectDto.fromMap(map);
      expect(dto.unparsedPayload['homebrewAura'], equals('holy_glow'));
      expect(dto.unparsedPayload['customTag'], equals(42));

      final serialized = dto.toMap();
      expect(serialized['homebrewAura'], equals('holy_glow'));
      expect(serialized['customTag'], equals(42));
    });
  });

  group('HomebrewIngestor ACL Tests', () {
    test('parseCustomSpells isolates malformed records and preserves valid spells', () {
      final rawBundle = [
        // Valid spell 1
        {
          'id': 'fireball-plus',
          'name': 'Super Fireball',
          'level': 3,
          'school': 'Evocation',
          'customElementalBurst': true,
        },
        // Non-map item (should be skipped)
        'Not a JSON map',
        12345,
        null,
        // Malformed spell (missing name and id)
        {
          'description': 'A nameless void with no identity',
        },
        // Valid spell 2
        {
          'id': 'frostbite-aura',
          'name': 'Frostbite Aura',
          'level': 1,
          'school': 'Evocation',
        },
      ];

      final result = HomebrewIngestor.parseCustomSpells(rawBundle);

      expect(result.length, equals(2));
      expect(result[0].id, equals('fireball-plus'));
      expect(result[0].name, equals('Super Fireball'));
      expect(result[0].unparsedPayload['customElementalBurst'], isTrue);

      expect(result[1].id, equals('frostbite-aura'));
      expect(result[1].name, equals('Frostbite Aura'));
    });

    test('parseCustomCharacters isolates corrupt entries', () {
      final rawCharacters = [
        {
          'id': 'hero-1',
          'name': 'Sir Galahad',
          'level': 5,
          'strength': 18,
          'customBackstory': 'Knight of the Realm',
        },
        null,
        {'corrupt': 'no id or name'},
        {
          'id': 'hero-2',
          'name': 'Merlin',
          'level': 10,
          'strength': 8,
        },
      ];

      final characters = HomebrewIngestor.parseCustomCharacters(rawCharacters);
      expect(characters.length, equals(2));
      expect(characters[0].name, equals('Sir Galahad'));
      expect(characters[0].unparsedPayload['customBackstory'], equals('Knight of the Realm'));
      expect(characters[1].name, equals('Merlin'));
    });

    test('parseCustomAnimatedObjects isolates corrupt entries', () {
      final rawObjects = [
        {
          'id': 'obj-1',
          'name': 'Flying Dagger',
          'size': 'tiny',
          'maxHp': 10,
        },
        'corrupt entry',
        {
          'id': 'obj-2',
          'name': 'Stone Golem Head',
          'size': 'large',
          'maxHp': 80,
        },
      ];

      final objects = HomebrewIngestor.parseCustomAnimatedObjects(rawObjects);
      expect(objects.length, equals(2));
      expect(objects[0].name, equals('Flying Dagger'));
      expect(objects[1].name, equals('Stone Golem Head'));
    });
  });
}
