import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

void main() {
  group('SubclassSpellsLibrary Filter Evaluation & Divine Magic Tests', () {
    test('1. resolveFilterSpells evaluates level and class query filters', () {
      final clericCantrips = SubclassSpellsLibrary.resolveFilterSpells('level=0|class=Cleric');
      expect(clericCantrips, isNotEmpty);
      expect(clericCantrips.every((s) => s.level == 0), isTrue);
      final names = clericCantrips.map((s) => s.name.toLowerCase()).toSet();
      expect(names, contains('sacred flame'));
      expect(names, contains('guidance'));

      final clericLvl1 = SubclassSpellsLibrary.resolveFilterSpells('level=1|class=Cleric');
      expect(clericLvl1, isNotEmpty);
      expect(clericLvl1.every((s) => s.level == 1), isTrue);
      final lvl1Names = clericLvl1.map((s) => s.name.toLowerCase()).toSet();
      expect(lvl1Names, contains('cure wounds'));
      expect(lvl1Names, contains('bless'));
      expect(lvl1Names, contains('guiding bolt'));
    });

    test('2. resolveFilterSpells evaluates school query filters', () {
      final illusionNecromancy = SubclassSpellsLibrary.resolveFilterSpells('level=1|school=I;N');
      expect(illusionNecromancy, isNotEmpty);
      for (final s in illusionNecromancy) {
        expect(s.level, 1);
        expect(
          s.school == SpellSchool.illusion || s.school == SpellSchool.necromancy,
          isTrue,
        );
      }
    });

    test('3. extractFilterStrings recursively extracts all and choose queries', () {
      final data = [
        {
          'name': 'Good',
          'known': {
            '1': ['cure wounds']
          },
          'expanded': {
            '1': [
              {'all': 'level=0|class=Cleric'},
              {'all': 'level=1|class=Cleric'}
            ],
            '3': [
              {'all': 'level=2|class=Cleric'}
            ]
          }
        }
      ];

      final filters = SubclassSpellsLibrary.extractFilterStrings(data);
      expect(filters, contains('level=0|class=Cleric'));
      expect(filters, contains('level=1|class=Cleric'));
      expect(filters, contains('level=2|class=Cleric'));
    });

    test('4. Sorcerer with divine magic origin receives full Cleric spell list in getExpandedSpells', () {
      final expanded = SubclassSpellsLibrary.getExpandedSpells('sorcerer', 'divine-soul');
      expect(expanded, contains('sacred flame'));
      expect(expanded, contains('guidance'));
      expect(expanded, contains('cure wounds'));
      expect(expanded, contains('bless'));
      expect(expanded, contains('spiritual weapon'));
      expect(expanded, contains('spirit guardians'));
      expect(expanded, contains('revivify'));
    });

    test('5. isExpandedSpell returns true for Cleric spells for Sorcerers with divine magic origin', () {
      final sacredFlame = SpellbookLibrary.findSpell('sacred flame')!;
      final guidingBolt = SpellbookLibrary.findSpell('guiding bolt')!;
      final spiritualWeapon = SpellbookLibrary.findSpell('spiritual weapon')!;
      final eldritchBlast = SpellbookLibrary.findSpell('eldritch blast')!;

      // 2014 edition
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'divine-soul', sacredFlame, DmRulesEdition.v2014),
        isTrue,
      );
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'divine-soul', guidingBolt, DmRulesEdition.v2014),
        isTrue,
      );
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'divine-soul', spiritualWeapon, DmRulesEdition.v2014),
        isTrue,
      );
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'divine-soul', eldritchBlast, DmRulesEdition.v2014),
        isFalse,
      );

      // 2024 edition
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'divine-soul', sacredFlame, DmRulesEdition.v2024),
        isTrue,
      );
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'divine_soul', guidingBolt, DmRulesEdition.v2024),
        isTrue,
      );
    });

    test('6. Dynamic Homebrew Subclass with 5eTools expanded filters resolves correctly', () {
      final customRadiantSubclass = Subclass(
        id: const EntityId(slug: 'radiant-soul-origin', ruleset: RulesetVersion.homebrew),
        name: 'Radiant Soul',
        classSlug: 'sorcerer',
        featuresMarkdown: 'Radiant bloodline power',
        grants: [
          FeatureGrant.bonusSpell(
            grantId: 'subclass-radiant-spell-cure-wounds',
            slug: 'cure-wounds',
            displayName: 'cure wounds',
          ),
        ],
        customProperties: {
          'additionalSpells': [
            {
              'name': 'Radiant Origin',
              'known': {
                '1': ['cure wounds']
              },
              'expanded': {
                '1': [
                  {'all': 'level=0|class=Cleric'},
                  {'all': 'level=1|class=Cleric'}
                ],
                '3': [
                  {'all': 'level=2|class=Cleric'}
                ]
              }
            }
          ]
        },
      );

      SrdClassesLibrary.addCustomSubclass(customRadiantSubclass);
      addTearDown(() => SrdClassesLibrary.removeCustomSubclass('radiant-soul-origin'));

      final expanded = SubclassSpellsLibrary.getExpandedSpells('sorcerer', 'radiant-soul-origin');
      expect(expanded, contains('cure wounds'));
      expect(expanded, contains('sacred flame'));
      expect(expanded, contains('guidance'));
      expect(expanded, contains('bless'));
      expect(expanded, contains('spiritual weapon'));

      final sacredFlame = SpellbookLibrary.findSpell('sacred flame')!;
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'radiant-soul-origin', sacredFlame, DmRulesEdition.v2014),
        isTrue,
      );
    });

    test('7. Character creation spell pool for Sorcerer with divine magic origin includes Cleric cantrips & 1st-level spells', () {
      const edition = DmRulesEdition.v2014;
      const classSlug = 'sorcerer';
      const subclassSlug = 'divine-soul';

      final allAvailableSpells = SpellbookLibrary.allSpells.where((s) {
        if (s.level > 1) return false;
        final rules = s.getRules(edition);
        final isClassSpell = rules.classes.contains(SpellClass.sorcerer);
        final isExpanded = SubclassSpellsLibrary.isExpandedSpell(classSlug, subclassSlug, s, edition);
        return isClassSpell || isExpanded;
      }).toList();

      final availableCantrips = allAvailableSpells.where((s) => s.level == 0).map((s) => s.name.toLowerCase()).toSet();
      final availableLevel1 = allAvailableSpells.where((s) => s.level == 1).map((s) => s.name.toLowerCase()).toSet();

      // Sorcerer native spells
      expect(availableCantrips, contains('fire bolt'));
      expect(availableCantrips, contains('mage hand'));
      expect(availableLevel1, contains('magic missile'));
      expect(availableLevel1, contains('shield'));

      // Cleric expanded spells via Divine Soul
      expect(availableCantrips, contains('sacred flame'));
      expect(availableCantrips, contains('guidance'));
      expect(availableLevel1, contains('cure wounds'));
      expect(availableLevel1, contains('bless'));
      expect(availableLevel1, contains('guiding bolt'));
      expect(availableLevel1, contains('sanctuary'));
    });
  });
}
