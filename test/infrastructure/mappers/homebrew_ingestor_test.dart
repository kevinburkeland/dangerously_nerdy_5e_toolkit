import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
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
        'homebrewSource': 'Custom Campaign',
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
      expect(dto.unparsedPayload['homebrewSource'], equals('Custom Campaign'));
      expect(dto.unparsedPayload['customVfxId'], equals('fx-eldritch-purple'));
      expect(dto.unparsedPayload['isSignatureSpell'], isTrue);
      expect(dto.unparsedPayload['nestedVendorMetadata'], equals({'price': 500, 'rarity': 'uncommon'}));

      // Verify round-trip serialization retains unparsed fields
      final serialized = dto.toMap();
      expect(serialized['homebrewSource'], equals('Custom Campaign'));
      expect(serialized['customVfxId'], equals('fx-eldritch-purple'));
      expect(serialized['isSignatureSpell'], isTrue);
      expect(serialized['nestedVendorMetadata'], equals({'price': 500, 'rarity': 'uncommon'}));

      // Verify domain conversion
      final domainSpell = dto.toDomain();
      expect(domainSpell.id.slug, equals('eldritch-blast-custom'));
      expect(domainSpell.name, equals('Custom Eldritch Blast'));
      expect(domainSpell.customProperties['homebrewSource'], equals('Custom Campaign'));
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

  group('Homebrew Ingestor Fortification & Parsing Edge Cases', () {
    test('Elemental Absorption and Frost Shard map higherLevelsMarkdown dice step into damageMath.scalingFormula', () {
      final absorbJson = {
        'id': 'elemental-absorption',
        'name': 'Elemental Absorption',
        'level': 1,
        'higherLevelsMarkdown':
            'When you cast this spell using a spell slot of 2nd level or higher, the extra damage increases by 1d6 for each slot level above 1st.',
        'damageMath': [
          {'diceFormula': '1d6', 'damageType': 'untyped'},
        ],
      };

      final absorbDto = SpellDto.fromJson(absorbJson);
      expect(absorbDto.damageMath.isNotEmpty, isTrue);
      expect(absorbDto.damageMath.first.scalingFormula, equals('1d6'));

      final frostShardJson = {
        'id': 'frost-shard',
        'name': 'Frost Shard',
        'level': 1,
        'descriptionMarkdown':
            'You fling a shard of ice at one creature within range. Make a ranged spell attack against the target. On a hit, the target takes 1d10 piercing damage. Hit or miss, the shard shatters into freezing ice. The target and each creature within 5 feet of the point where the ice exploded must succeed on a Dexterity saving throw or take 2d6 cold damage.',
        'higherLevelsMarkdown':
            'When you cast this spell using a spell slot of 2nd level or higher, the cold damage increases by 1d6 for each slot level above 1st.',
        'damageMath': [
          {'diceFormula': '1d10', 'damageType': 'piercing'},
          {'diceFormula': '2d6', 'damageType': 'cold'},
        ],
      };

      final frostShardDto = SpellDto.fromJson(frostShardJson);
      final coldMath = frostShardDto.damageMath.firstWhere((dm) => dm.damageType == DamageType.cold);
      expect(coldMath.scalingFormula, equals('1d6'));
    });

    test('Chaotic Blast and Prismatic Orb map damageType as variable rather than acid', () {
      final chaosBlastJson = {
        'id': 'chaotic-blast',
        'name': 'Chaotic Blast',
        'level': 1,
        'descriptionMarkdown':
            'You hurl an undulating, warbling mass of chaotic energy at one creature in range. Make a ranged spell attack against the target. On a hit, the target takes 2d8 + 1d6 damage. A d8 determines the attack\'s damage type: 1 - acid, 2 - cold, 3 - fire, 4 - force, 5 - lightning, 6 - poison, 7 - psychic, 8 - thunder.',
        'damageMath': [
          {'diceFormula': '2d8+1d6', 'damageType': 'acid'},
        ],
      };

      final chaosBlastDto = SpellDto.fromJson(chaosBlastJson);
      expect(chaosBlastDto.damageType, equals('variable'));
      expect(chaosBlastDto.damageMath.first.damageType, equals(DamageType.variable));

      final prismaticOrbJson = {
        'id': 'prismatic-orb',
        'name': 'Prismatic Orb',
        'level': 1,
        'descriptionMarkdown':
            'You hurl a 4-inch-diameter sphere of energy at a creature that you can see within range. You choose acid, cold, fire, lightning, poison, or thunder for the type of orb you create, and then make a ranged spell attack against the target. If the attack hits, the creature takes 3d8 damage of the type you chose.',
        'damageMath': [
          {'diceFormula': '3d8', 'damageType': 'acid'},
        ],
      };

      final prismaticOrbDto = SpellDto.fromJson(prismaticOrbJson);
      expect(prismaticOrbDto.damageType, equals('variable'));
      expect(prismaticOrbDto.damageMath.first.damageType, equals(DamageType.variable));
    });

    test('Scorching Line range normalizes to rangeDistanceFeet: 30 and rangeType: "line"', () {
      final scorchingStringJson = {
        'id': 'scorching-line-str',
        'name': 'Scorching Line',
        'level': 2,
        'range': '30-foot line',
      };

      final scorchingDto1 = SpellDto.fromJson(scorchingStringJson);
      expect(scorchingDto1.rangeDistanceFeet, equals(30));
      expect(scorchingDto1.rangeType, equals('line'));

      final scorchingMapJson = {
        'id': 'scorching-line-map',
        'name': 'Scorching Line',
        'level': 2,
        'range': {
          'type': 'line',
          'distance': {'amount': 30, 'type': 'feet'},
        },
      };

      final scorchingDto2 = SpellDto.fromJson(scorchingMapJson);
      expect(scorchingDto2.rangeDistanceFeet, equals(30));
      expect(scorchingDto2.rangeType, equals('line'));

      // Verify touch and self fallbacks
      final touchNorm = HomebrewIngestor.normalizeRange('Touch');
      expect(touchNorm['rangeDistanceFeet'], equals(0));
      expect(touchNorm['rangeType'], equals('touch'));

      final selfNorm = HomebrewIngestor.normalizeRange('Self');
      expect(selfNorm['rangeDistanceFeet'], equals(0));
      expect(selfNorm['rangeType'], equals('self'));

      // Verify domain Spell preservation
      final domainSpell = scorchingDto1.toDomain();
      expect(domainSpell.rangeDistanceFeet, equals(30));
      expect(domainSpell.rangeType, equals('line'));
    });

    test('Frost Shard damageMath array flags 1d10 piercing as attack roll and 2d6 cold as saving throw', () {
      final frostShardJson = {
        'id': 'frost-shard',
        'name': 'Frost Shard',
        'level': 1,
        'descriptionMarkdown':
            'You fling a shard of ice at one creature within range. Make a ranged spell attack against the target. On a hit, the target takes 1d10 piercing damage. Hit or miss, the shard explodes into frost. The target and each creature within 5 feet of the point of detonation must succeed on a Dexterity saving throw or take 2d6 cold damage.',
        'damageMath': [
          {'diceFormula': '1d10', 'damageType': 'piercing'},
          {'diceFormula': '2d6', 'damageType': 'cold'},
        ],
      };

      final dto = SpellDto.fromJson(frostShardJson);
      expect(dto.damageMath.length, equals(2));

      final piercing = dto.damageMath.firstWhere((dm) => dm.diceFormula == '1d10');
      final cold = dto.damageMath.firstWhere((dm) => dm.diceFormula == '2d6');

      expect(piercing.isAttackRoll, isTrue);
      expect(piercing.requiresSave, isFalse);

      expect(cold.isAttackRoll, isFalse);
      expect(cold.requiresSave, isTrue);

      // Verify domain conversion and back to DTO
      final domainSpell = dto.toDomain();
      expect(domainSpell.damageMath[0].isAttackRoll, isTrue);
      expect(domainSpell.damageMath[1].requiresSave, isTrue);

      final roundTripDto = SpellDto.fromDomain(domainSpell);
      expect(roundTripDto.damageMath[0].isAttackRoll, isTrue);
      expect(roundTripDto.damageMath[1].requiresSave, isTrue);
    });

    test('reconciles narrative spatial geometry and repairs mislabeled damage types from description', () {
      // 1. Scorching Line with generic "30 feet" range but "A line of roaring flame" in description
      final scorchingNarrativeJson = {
        'id': 'scorching-line-narrative',
        'name': 'Scorching Line',
        'level': 2,
        'range': '30 feet',
        'descriptionMarkdown':
            'A line of roaring flame 30 feet long and 5 feet wide emanates from you in a direction you choose.',
      };
      final scorchingDto = SpellDto.fromJson(scorchingNarrativeJson);
      expect(scorchingDto.rangeDistanceFeet, equals(30));
      expect(scorchingDto.rangeType, equals('line'));

      // 2. Frost Shard with payload mislabeling both items as cold
      final frostShardMislabeledJson = {
        'id': 'frost-shard-mislabeled',
        'name': 'Frost Shard',
        'level': 1,
        'descriptionMarkdown':
            'You fling a shard of ice at one creature within range. Make a ranged spell attack against the target. On a hit, the target takes **1d10** piercing damage. Hit or miss, the shard then explodes. The target and each creature within 5 feet of it must succeed on a Dexterity saving throw or take **2d6** cold damage.',
        'higherLevelsMarkdown':
            'When you cast this spell using a spell slot of 2nd level or higher, the cold damage increases by 1d6 for each slot level above 1st.',
        'damageMath': [
          {'diceFormula': '1d10', 'damageType': 'cold'},
          {'diceFormula': '2d6', 'damageType': 'cold'},
        ],
      };

      final frostShardDto = SpellDto.fromJson(frostShardMislabeledJson);
      final piercingDm = frostShardDto.damageMath.firstWhere((dm) => dm.diceFormula == '1d10');
      final coldDm = frostShardDto.damageMath.firstWhere((dm) => dm.diceFormula == '2d6');

      expect(piercingDm.damageType, equals(DamageType.piercing));
      expect(piercingDm.isAttackRoll, isTrue);
      expect(piercingDm.requiresSave, isFalse);
      expect(piercingDm.scalingFormula, isNull);

      expect(coldDm.damageType, equals(DamageType.cold));
      expect(coldDm.isAttackRoll, isFalse);
      expect(coldDm.requiresSave, isTrue);
      expect(coldDm.scalingFormula, equals('1d6'));
    });

    test('deserialization priority correctly overrides stale raw fields and persists boolean flags in exported JSON', () {
      // 1. Stale raw JSON where rangeType and rangeDistanceFeet were un-normalized or corrupted
      final staleRawJson = {
        'id': 'elemental-absorption',
        'name': 'Elemental Absorption',
        'level': 1,
        'range': 'Self',
        'rangeDistanceFeet': 60, // Stale/corrupt un-normalized field
        'rangeType': 'ranged',    // Stale/corrupt un-normalized field
        'higherLevelsMarkdown':
            'When you cast this spell using a spell slot of 2nd level or higher, the extra damage increases by 1d6 for each slot level above 1st.',
        'damageMath': [
          {'diceFormula': '1d6', 'damageType': 'untyped'},
        ],
      };

      final dto = SpellDto.fromJson(staleRawJson);
      expect(dto.rangeDistanceFeet, equals(0));
      expect(dto.rangeType, equals('self'));

      final exported = dto.toMap();
      expect(exported['rangeDistanceFeet'], equals(0));
      expect(exported['rangeType'], equals('self'));

      // 2. Variable damage root field override in exported JSON
      final chaosJson = {
        'id': 'chaotic-blast',
        'name': 'Chaotic Blast',
        'level': 1,
        'damageType': 'acid', // Stale/default type
        'descriptionMarkdown':
            'You hurl an erratic burst of energy at one creature in range. A d8 determines the attack\'s damage type: 1 - acid, 2 - cold, 3 - fire, 4 - force, 5 - lightning, 6 - poison, 7 - psychic, 8 - thunder.',
        'damageMath': [
          {'diceFormula': '2d8+1d6', 'damageType': 'acid'},
        ],
      };
      final chaosDto = SpellDto.fromJson(chaosJson);
      expect(chaosDto.damageType, equals('variable'));
      final exportedChaos = chaosDto.toMap();
      expect(exportedChaos['damageType'], equals('variable'));

      // 3. Boolean flags in EvaluationMath exported JSON survive round-trip
      final frostJson = {
        'id': 'frost-shard',
        'name': 'Frost Shard',
        'level': 1,
        'descriptionMarkdown':
            'You fling a shard of ice at one creature within range. Make a ranged spell attack against the target. On a hit, the target takes 1d10 piercing damage. Hit or miss, the shard explodes. Each creature within 5 feet must succeed on a Dexterity saving throw or take 2d6 cold damage.',
        'damageMath': [
          {'diceFormula': '1d10', 'damageType': 'piercing'},
          {'diceFormula': '2d6', 'damageType': 'cold'},
        ],
      };
      final frostDto = SpellDto.fromJson(frostJson);
      final exportedFrost = frostDto.toMap();
      final exportedMath = (exportedFrost['damageMath'] as List).cast<Map<String, dynamic>>();

      final piercingMap = exportedMath.firstWhere((m) => m['diceFormula'] == '1d10');
      final coldMap = exportedMath.firstWhere((m) => m['diceFormula'] == '2d6');

      expect(piercingMap['isAttackRoll'], isTrue);
      expect(piercingMap['requiresSave'], isFalse);

      expect(coldMap['isAttackRoll'], isFalse);
      expect(coldMap['requiresSave'], isTrue);
    });
  });
}
