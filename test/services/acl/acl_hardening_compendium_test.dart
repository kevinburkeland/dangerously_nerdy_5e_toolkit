import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_item_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_monster_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_spell_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/entry_node_transformer.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('5etools ACL Hardening & Boot Sequence Verification', () {
    test('1. Homebrew cantrip correctly routes to cantrips list on Character', () {
      // Create a homebrew cantrip
      const homebrewCantrip = Spell(
        id: EntityId(slug: 'mystic-spark', ruleset: RulesetVersion.homebrew),
        name: 'Mystic Spark',
        level: 0,
        school: 'Evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '60 ft.',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'You unleash a spark of crackling arcane energy.',
      );

      // Register into SpellbookLibrary (as done by HomebrewPersistenceService.syncToLibraries)
      final spellItem = HomebrewPersistenceService.spellToSpellItem(homebrewCantrip);
      SpellbookLibrary.setHomebrewSpells([spellItem]);

      expect(SpellbookLibrary.getSpellById('mystic-spark'), isNotNull);
      expect(SpellbookLibrary.getSpellById('mystic-spark')!.level, 0);

      // Create a character with allocated mystic-spark
      const character = Character(
        id: EntityId(slug: 'char-123', ruleset: RulesetVersion.homebrew),
        name: 'Sparky',
        speciesRef: EntityReference<Race>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        baseScores: AbilityScores(
          strength: 10,
          dexterity: 10,
          constitution: 10,
          intelligence: 16,
          wisdom: 10,
          charisma: 10,
        ),
        resources: CharacterResourcePool(currentHp: 8),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<CharacterClass>(
                refType: EntityType.classDefinition,
                slug: 'wizard',
                displayName: 'Wizard',
              ),
              level: 1,
              hitDie: 'd6',
            ),
          ],
        ),
        allocatedSpells: {
          'wizard': [
            EntityReference<Spell>(
              refType: EntityType.spell,
              slug: 'mystic-spark',
              displayName: 'Mystic Spark',
            ),
            EntityReference<Spell>(
              refType: EntityType.spell,
              slug: 'magic-missile',
              displayName: 'Magic Missile',
            ),
          ],
        },
      );

      // Cantrip should route to cantrips, not spellsKnown
      expect(character.cantrips.map((c) => c.slug), contains('mystic-spark'));
      expect(character.cantrips.map((c) => c.slug), isNot(contains('magic-missile')));
      expect(character.spellsKnown.map((s) => s.slug), contains('magic-missile'));
      expect(character.spellsKnown.map((s) => s.slug), isNot(contains('mystic-spark')));
    });

    test('2. Ingesting 5etools Fighter correctly stitches classFeature pointers (Second Wind)', () {
      final pipeline = CompendiumJsonIngestionPipeline();
      const raw5eToolsFighterPayload = '''
      {
        "class": [
          {
            "name": "Fighter",
            "source": "PHB",
            "hd": {"number": 1, "faces": 10},
            "proficiency": ["str", "con"],
            "classFeatures": [
              "Fighting Style|Fighter|PHB|1",
              "Second Wind|Fighter|PHB|1",
              "Action Surge (1 use)|Fighter|PHB|2"
            ]
          }
        ],
        "classFeature": [
          {
            "name": "Fighting Style",
            "source": "PHB",
            "className": "Fighter",
            "classSource": "PHB",
            "level": 1,
            "entries": ["You adopt a particular style of fighting as your specialty."]
          },
          {
            "name": "Second Wind",
            "source": "PHB",
            "className": "Fighter",
            "classSource": "PHB",
            "level": 1,
            "entries": [
              "You have a limited well of stamina that you can draw on to protect yourself from harm. On your turn, you can use a bonus action to regain hit points equal to {@dice 1d10} + your fighter level."
            ]
          },
          {
            "name": "Action Surge (1 use)",
            "source": "PHB",
            "className": "Fighter",
            "classSource": "PHB",
            "level": 2,
            "entries": ["Starting at 2nd level, you can push yourself beyond your normal limits for a moment."]
          }
        ]
      }
      ''';

      final result = pipeline.ingestJsonString(raw5eToolsFighterPayload);
      expect(result.hasErrors, isFalse);
      expect(result.classes.length, 1);

      final fighter = result.classes.first;
      expect(fighter.name, 'Fighter');
      expect(fighter.featuresMarkdown, contains('Second Wind'));
      expect(fighter.featuresMarkdown, contains('regain hit points equal to'));
      expect(fighter.featuresMarkdown, contains('Fighting Style'));
      expect(fighter.featuresMarkdown, contains('Action Surge'));
      expect(fighter.featuresMarkdown, isNot(contains('Second Wind|Fighter|PHB|1')));
    });

    test('3. Monster with polymorphic ac: [{"ac": 16, "from": ["chain mail"]}] parses to ac = 16', () {
      final parser = CompendiumMonsterParser();
      final raw = {
        'name': 'Knight Guard',
        'source': 'MM',
        'size': ['M'],
        'type': 'humanoid',
        'alignment': ['L', 'G'],
        'ac': [
          {'ac': 16, 'from': ['chain mail']}
        ],
        'hp': {'average': 52, 'formula': '8d8 + 16'},
        'speed': {'walk': 30},
        'str': 16,
        'dex': 11,
        'con': 14,
        'int': 11,
        'wis': 11,
        'cha': 15,
        'cr': '3',
      };

      final monster = parser.parseMonster(raw);
      expect(monster.name, 'Knight Guard');
      expect(monster.armorClass, 16);
    });

    test('4. Monster with speed integer parses cleanly', () {
      final parser = CompendiumMonsterParser();
      final raw = {
        'name': 'Fast Goblin',
        'source': 'MM',
        'ac': 15,
        'hp': 7,
        'speed': 35,
      };

      final monster = parser.parseMonster(raw);
      expect(monster.actionsMarkdown, contains('walk 35ft.'));
    });

    test('5. Item with polymorphic reqAttune: {"optional": true} and string reqAttune parses attunement', () {
      final parser = CompendiumItemParser();

      final item1 = parser.parseItem({
        'name': 'Cloak of Shrouding',
        'source': 'DMG',
        'type': 'W',
        'rarity': 'rare',
        'reqAttune': {'optional': true},
        'entries': ['A mystical cloak.'],
      });
      expect(item1.requiresAttunement, isTrue);

      final item2 = parser.parseItem({
        'name': 'Staff of the Magi',
        'source': 'DMG',
        'type': 'ST',
        'rarity': 'artifact',
        'reqAttune': 'by a sorcerer, warlock, or wizard',
        'entries': ['An ancient staff.'],
      });
      expect(item2.requiresAttunement, isTrue);

      final item3 = parser.parseItem({
        'name': 'Iron Dagger',
        'source': 'PHB',
        'type': 'M',
        'rarity': 'common',
        'reqAttune': false,
        'entries': ['A standard dagger.'],
      });
      expect(item3.requiresAttunement, isFalse);
    });

    test('6. Spell with string components.m parses cleanly with 0 cost', () {
      final parser = CompendiumSpellParser();
      final raw = {
        'name': 'Fireball',
        'source': 'PHB',
        'level': 3,
        'school': 'V',
        'time': [{'number': 1, 'unit': 'action'}],
        'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 150}},
        'components': {
          'v': true,
          's': true,
          'm': 'a tiny ball of bat guano and pitch',
        },
        'duration': [{'type': 'instant'}],
        'entries': ['A bright streak flashes from your pointing finger to a point you choose.'],
      };

      final spell = parser.parseSpell(raw);
      expect(spell.components.v, isTrue);
      expect(spell.components.s, isTrue);
      expect(spell.components.m, isTrue);
      expect(spell.components.materialDescription, 'a tiny ball of bat guano and pitch');
      expect(spell.components.materialCostGp, 0);
      expect(spell.components.consumesMaterial, isFalse);
    });

    test('7. Monster spellcasting normalization handles daily suffixes (1e, 3e) and slot objects', () {
      final parser = CompendiumMonsterParser();
      final raw = {
        'name': 'Archmage Lich',
        'source': 'MM',
        'ac': 17,
        'hp': 135,
        'cr': '21',
        'spellcasting': [
          {
            'name': 'Innate Spellcasting',
            'daily': {
              '1e': ['{@spell dominate monster|phb}', '{@spell plane shift|phb}'],
              '3e': ['{@spell darkness|phb}', '{@spell misty step|phb}']
            },
            'will': ['{@spell mage hand|phb}', '{@spell prestidigitation|phb}'],
            'spells': {
              '0': {
                'spells': ['{@spell ray of frost|phb}']
              },
              '1': {
                'slots': 4,
                'spells': ['{@spell magic missile|phb}', '{@spell shield|phb}']
              }
            }
          }
        ]
      };

      final monster = parser.parseMonster(raw);
      expect(monster.actionsMarkdown, contains('- **1/day each:** *dominate monster*, *plane shift*'));
      expect(monster.actionsMarkdown, contains('- **3/day each:** *darkness*, *misty step*'));
      expect(monster.actionsMarkdown, contains('- **At will:** *mage hand*, *prestidigitation*'));
      expect(monster.actionsMarkdown, contains('- **Cantrips (at will):** *ray of frost*'));
      expect(monster.actionsMarkdown, contains('- **Level 1 (4 slots):** *magic missile*, *shield*'));

      final innateSlugs = monster.innateSpells.map((s) => s.slug).toList();
      expect(innateSlugs, contains('dominate-monster'));
      expect(innateSlugs, contains('plane-shift'));
      expect(innateSlugs, contains('darkness'));
      expect(innateSlugs, contains('misty-step'));
      expect(innateSlugs, contains('magic-missile'));
    });

    test('8. {@atk mw} renders as *Melee Weapon Attack:* and {@spell fireball|phb} strips source', () {
      final transformer = EntryNodeTransformer();

      final res1 = transformer.transformEntries('{@atk mw} {@hit 5} to hit, reach 5 ft., one target.');
      expect(res1.markdown, contains('*Melee Weapon Attack:* **`+5`** to hit, reach 5 ft., one target.'));

      final res2 = transformer.transformEntries('{@atk rw} {@hit 7} to hit, range 150/600 ft.');
      expect(res2.markdown, contains('*Ranged Weapon Attack:* **`+7`** to hit, range 150/600 ft.'));

      final res3 = transformer.transformEntries('{@atk rs} {@hit 6} to hit.');
      expect(res3.markdown, contains('*Ranged Spell Attack:* **`+6`** to hit.'));

      final res4 = transformer.transformEntries('The wizard casts {@spell fireball|phb} on the goblins.');
      expect(res4.markdown, contains('[fireball](ref://spell/fireball)'));
      expect(res4.extractedRefs.first.slug, 'fireball');
    });

    test('9. Deep AST recursion handles type: "options" and nested entry nodes', () {
      final transformer = EntryNodeTransformer();
      final ast = [
        {
          'type': 'entries',
          'name': 'Eldritch Invocations',
          'entries': [
            {
              'type': 'options',
              'name': 'Choose One',
              'entries': [
                {
                  'type': 'entries',
                  'name': 'Agonizing Blast',
                  'entries': ['When you cast {@spell eldritch blast|phb}, add your Charisma modifier to the damage.']
                },
                {
                  'type': 'entries',
                  'name': 'Armor of Shadows',
                  'entries': ['You can cast {@spell mage armor|phb} on yourself at will.']
                }
              ]
            }
          ]
        }
      ];

      final res = transformer.transformEntries(ast);
      expect(res.markdown, contains('### Eldritch Invocations'));
      expect(res.markdown, contains('#### Choose One'));
      expect(res.markdown, contains('##### Agonizing Blast'));
      expect(res.markdown, contains('##### Armor of Shadows'));
      expect(res.markdown, contains('[eldritch blast](ref://spell/eldritch-blast)'));
      expect(res.markdown, contains('[mage armor](ref://spell/mage-armor)'));
    });

    test('10. Explicit 2014 / 2024 ruleset toggle forces target edition on parsed homebrew', () {
      final pipeline = CompendiumJsonIngestionPipeline();
      const rawSpellJson = '''
      {
        "name": "Astral Tether",
        "source": "CustomBrew",
        "level": 2,
        "school": "T",
        "time": [{"number": 1, "unit": "action"}],
        "range": {"type": "point", "distance": {"type": "feet", "amount": 60}},
        "components": {"v": true, "s": true},
        "duration": [{"type": "timed", "duration": {"type": "minute", "amount": 1}}],
        "entries": ["You link two creatures astrally."]
      }
      ''';

      final res2024 = pipeline.ingestJsonString(rawSpellJson, forceRuleset: RulesetVersion.v2024);
      expect(res2024.spells.first.id.ruleset, RulesetVersion.v2024);

      final res2014 = pipeline.ingestJsonString(rawSpellJson, forceRuleset: RulesetVersion.v2014);
      expect(res2014.spells.first.id.ruleset, RulesetVersion.v2014);

      final resAuto = pipeline.ingestJsonString(rawSpellJson, forceRuleset: null);
      expect(resAuto.spells.first.id.ruleset, RulesetVersion.homebrew);
    });
  });
}
