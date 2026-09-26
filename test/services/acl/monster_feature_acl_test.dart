import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/arena/monster_combat_profile.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_generic_entry_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';

void main() {
  group('Monster Feature ACL Parser & Discrepancy Resolution Tests', () {
    test(
        'StatBlockAclParser.parseMonsterFeature extracts mobility, combat flags, reach, and riders',
        () {
      final feature = StatBlockAclParser.parseMonsterFeature(
        'Tentacle Grapple',
        'Melee Weapon Attack: reach 10 ft., one target. Hit: 12 (2d6 + 5) bludgeoning damage, '
            'and the target is grappled (escape DC 14). Until this grapple ends, the target is restrained. '
            'The creature can breathe air and water (Amphibious) and has Flyby.',
      );

      expect(feature.maxReachFt, equals(10));
      expect(feature.canSwim, isTrue);
      expect(feature.hasFlyby, isTrue);
      expect(feature.riders.length, equals(2));
    });

    test(
        'MonsterCombatProfile.fromStatBlock checks explicit declarations against ACL parser and favors ACL on discrepancies',
        () {
      // Create a statblock where incoming/explicit declarations conflict with the actual text/traits
      const conflictedStatBlock = MinionStatBlock(
        id: 'aberrant-beast',
        name: 'Aberrant Beast',
        sizeDisplay: 'Large',
        crDisplay: '5',
        ac: 15,
        maxHp: 80,
        speed: '30 ft., fly 60 ft., swim 40 ft.',
        strScore: 18,
        dexScore: 14,
        conScore: 16,
        intScore: 10,
        wisScore: 12,
        attackBonus: 7,
        damageDiceCount: 2,
        damageDiceSides: 8,
        damageBonus: 5,
        damageType: 'bludgeoning',
        // Conflicting/discrepant explicit fields:
        explicitMeleeReachFt: 5, // Action text actually has reach 10 ft!
        canFly: false, // Speed actually specifies fly 60 ft!
        spellSaveDc: 10, // Text actually specifies spell save DC 16!
        explicitSavingThrows: {
          AbilityType.strength: 4, // Raw says +4, but STR 18 + PB 3 = +7
        },
        traits: [
          CreatureTrait(
            name: 'Amphibious',
            description: 'The creature can breathe air and water.',
          ),
          CreatureTrait(
            name: 'Flyby',
            description:
                'The creature doesn\'t provoke opportunity attacks when it flies out of an enemy\'s reach.',
          ),
          CreatureTrait(
            name: 'Pack Tactics',
            description:
                'The creature has advantage on attack rolls against a creature if at least one ally is within 5 feet.',
          ),
          CreatureTrait(
            name: 'Spellcasting',
            description:
                'The creature is a 5th-level spellcaster. Its spellcasting ability is Wisdom (spell save DC 16, +8 to hit with spell attacks).',
          ),
        ],
        actions: [
          CreatureAction(
            name: 'Tentacle Sweep',
            description:
                'Melee Weapon Attack: +7 to hit, reach 10 ft., one target. Hit: 14 (2d8 + 5) bludgeoning damage.',
          ),
        ],
      );

      final profile = MonsterCombatProfile.fromStatBlock(conflictedStatBlock,
          challengeRating: 5.0);

      // Verify that the internal ACL parser was favored on every discrepancy:
      expect(profile.meleeReachInFeet, equals(10),
          reason:
              'ACL parsed reach 10 ft must take precedence over explicit 5 ft');
      expect(profile.canFly, isTrue,
          reason:
              'ACL parsed fly speed must take precedence over explicit canFly: false');
      expect(profile.canSwim, isTrue,
          reason: 'ACL parsed Amphibious trait must grant canSwim');
      expect(profile.hasFlyby, isTrue,
          reason: 'ACL parsed Flyby trait must be active');
      expect(profile.spellSaveDc, equals(16),
          reason:
              'ACL parsed spell save DC 16 must take precedence over explicit 10');
      expect(profile.spellAttackBonus, equals(8),
          reason: 'ACL parsed spell attack bonus +8 must take precedence');
      expect(profile.maxSpellSlots[1], equals(4),
          reason: 'ACL parsed 5th-level spellcaster slots must be populated');
      expect(profile.maxSpellSlots[3], equals(2),
          reason: 'ACL parsed 3rd-level spell slots must be populated');
    });

    test(
        'CompendiumGenericEntryParser checks Monster Feature against ACL parser and favors ACL over conflicting raw properties',
        () {
      final parser = CompendiumGenericEntryParser();
      final raw = {
        'name': 'Pounce & Strangle',
        'category': 'Monster Feature',
        'canSwim': false, // Erroneous raw flag
        'reach': 5, // Erroneous raw reach
        'entries': [
          'If the creature moves at least 20 feet straight toward a creature and then hits with a claw attack (reach 10 ft.), '
              'the target is grappled (escape DC 15) and restrained until this grapple ends. '
              'The creature can breathe air and water.'
        ],
      };

      final entry =
          parser.parseGenericEntry(raw, defaultCategory: 'Monster Feature');

      expect(entry.category, equals('Monster Feature'));
      final cp = entry.customProperties;
      // Discrepancies resolved in favor of internal ACL parser:
      expect(cp['canSwim'], isTrue,
          reason: 'Internal ACL parser identifies breathing air and water');
      expect(cp['maxReachFt'], equals(10),
          reason: 'Internal ACL parser identifies reach 10 ft');
      expect(cp['riders'], isNotNull);
      final riders = cp['riders'] as List;
      expect(riders.length, equals(2),
          reason:
              'Internal ACL parser extracts grappled and restrained riders');
    });
  });
}
