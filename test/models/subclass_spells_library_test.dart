import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

void main() {
  group('SubclassSpellsLibrary Filter Evaluation & Divine Magic Tests', () {
    test('1. resolveFilterSpells evaluates level and class query filters', () {
      final clericCantrips =
          SubclassSpellsLibrary.resolveFilterSpells('level=0|class=Cleric');
      expect(clericCantrips, isNotEmpty);
      expect(clericCantrips.every((s) => s.level == 0), isTrue);
      final names = clericCantrips.map((s) => s.name.toLowerCase()).toSet();
      expect(names, contains('sacred flame'));
      expect(names, contains('guidance'));

      final clericLvl1 =
          SubclassSpellsLibrary.resolveFilterSpells('level=1|class=Cleric');
      expect(clericLvl1, isNotEmpty);
      expect(clericLvl1.every((s) => s.level == 1), isTrue);
      final lvl1Names = clericLvl1.map((s) => s.name.toLowerCase()).toSet();
      expect(lvl1Names, contains('cure wounds'));
      expect(lvl1Names, contains('bless'));
      expect(lvl1Names, contains('guiding bolt'));
    });

    test('2. resolveFilterSpells evaluates school query filters', () {
      final illusionNecromancy =
          SubclassSpellsLibrary.resolveFilterSpells('level=1|school=I;N');
      expect(illusionNecromancy, isNotEmpty);
      for (final s in illusionNecromancy) {
        expect(s.level, 1);
        expect(
          s.resolvedSchool == SpellSchool.illusion ||
              s.resolvedSchool == SpellSchool.necromancy,
          isTrue,
        );
      }
    });

    test('3. extractFilterStrings recursively extracts all and choose queries',
        () {
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

    test(
        '6. Dynamic Homebrew Subclass with compendium expanded filters resolves correctly',
        () {
      final customRadiantSubclass = Subclass(
        id: const EntityId(
            slug: 'radiant-soul-origin', ruleset: RulesetVersion.homebrew),
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
      addTearDown(
          () => SrdClassesLibrary.removeCustomSubclass('radiant-soul-origin'));

      final expanded = SubclassSpellsLibrary.getExpandedSpells(
          'sorcerer', 'radiant-soul-origin');
      expect(expanded, contains('cure wounds'));
      expect(expanded, contains('sacred flame'));
      expect(expanded, contains('guidance'));
      expect(expanded, contains('bless'));
      expect(expanded, contains('spiritual weapon'));

      final sacredFlame = SpellbookLibrary.findSpell('sacred flame')!;
      expect(
        SubclassSpellsLibrary.isExpandedSpell('sorcerer', 'radiant-soul-origin',
            sacredFlame, DmRulesEdition.v2014),
        isTrue,
      );
    });
  });
}
