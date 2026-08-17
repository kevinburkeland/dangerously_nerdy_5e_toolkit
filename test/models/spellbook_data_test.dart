import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

void main() {
  group('SpellbookLibrary & SpellItem Data Model Tests', () {
    test('contains comprehensive spells across schools and levels', () {
      const spells = SpellbookLibrary.allSpells;
      expect(spells.isNotEmpty, isTrue);

      final schools = spells.map((s) => s.school).toSet();
      expect(schools.contains(SpellSchool.abjuration), isTrue);
      expect(schools.contains(SpellSchool.divination), isTrue);
      expect(schools.contains(SpellSchool.evocation), isTrue);
      expect(schools.contains(SpellSchool.transmutation), isTrue);
      expect(schools.contains(SpellSchool.conjuration), isTrue);

      final levels = spells.map((s) => s.level).toSet();
      expect(levels.contains(0), isTrue); // Cantrips
      expect(levels.contains(1), isTrue); // 1st level
      expect(levels.contains(3), isTrue); // 3rd level
      expect(levels.contains(9), isTrue); // 9th level
    });

    test('True Strike reflects 2014 advantage vs 2024 weapon attack radiant redesign', () {
      final trueStrike = SpellbookLibrary.getSpellById('spell_true_strike');
      expect(trueStrike, isNotNull);
      expect(trueStrike!.isChangedIn2024, isTrue);

      final r2014 = trueStrike.getRules(DmRulesEdition.v2014);
      final r2024 = trueStrike.getRules(DmRulesEdition.v2024);

      expect(r2014.concentration, isTrue);
      expect(r2014.duration.contains('Concentration'), isTrue);
      expect(r2014.description.any((d) => d.contains('advantage on your first attack roll')), isTrue);

      expect(r2024.concentration, isFalse);
      expect(r2024.damageOrHealType, 'Radiant');
      expect(r2024.description.any((d) => d.contains('Radiant damage')), isTrue);
      expect(r2024.description.any((d) => d.contains('spellcasting ability modifier instead of Strength')), isTrue);
    });

    test('Cure Wounds and Healing Word reflect 2024 dice doubling buff', () {
      final cureWounds = SpellbookLibrary.getSpellById('spell_cure_wounds')!;
      expect(cureWounds.getRules(DmRulesEdition.v2014).rollFormula, '1d8 + mod');
      expect(cureWounds.getRules(DmRulesEdition.v2024).rollFormula, '2d8 + mod');

      final healingWord = SpellbookLibrary.getSpellById('spell_healing_word')!;
      expect(healingWord.getRules(DmRulesEdition.v2014).rollFormula, '1d4 + mod');
      expect(healingWord.getRules(DmRulesEdition.v2024).rollFormula, '2d4 + mod');
    });

    test('Counterspell reflects 2014 ability check vs 2024 Constitution save', () {
      final counterspell = SpellbookLibrary.getSpellById('spell_counterspell')!;
      expect(counterspell.isChangedIn2024, isTrue);

      final r2014 = counterspell.getRules(DmRulesEdition.v2014);
      final r2024 = counterspell.getRules(DmRulesEdition.v2024);

      expect(r2014.description.any((d) => d.contains('DC equals 10 + the spell’s level')), isTrue);
      expect(r2024.savingThrow, 'Constitution');
      expect(r2024.description.any((d) => d.contains('Constitution saving throw')), isTrue);
    });

    test('Divine Smite reflects 2014 class feature vs 2024 Bonus Action spell', () {
      final smite = SpellbookLibrary.getSpellById('spell_divine_smite')!;
      expect(smite.isChangedIn2024, isTrue);

      final r2014 = smite.getRules(DmRulesEdition.v2014);
      final r2024 = smite.getRules(DmRulesEdition.v2024);

      expect(r2014.castingTime.contains('No Action'), isTrue);
      expect(r2024.castingTime.contains('Bonus Action'), isTrue);
      expect(r2024.components, 'V');
    });

    test('Spiritual Weapon reflects 2014 non-concentration vs 2024 concentration', () {
      final weapon = SpellbookLibrary.getSpellById('spell_spiritual_weapon')!;
      expect(weapon.getRules(DmRulesEdition.v2014).concentration, isFalse);
      expect(weapon.getRules(DmRulesEdition.v2024).concentration, isTrue);
    });

    test('SpellItem.matches filters correctly by query, level, school, and tags', () {
      final fireball = SpellbookLibrary.getSpellById('spell_fireball')!;

      expect(fireball.matches('fire'), isTrue);
      expect(fireball.matches('guano'), isTrue);
      expect(fireball.matches('8d6'), isTrue);
      expect(fireball.matches('cleric'), isFalse);
      expect(fireball.matches('fire', levelFilter: 3), isTrue);
      expect(fireball.matches('fire', levelFilter: 2), isFalse);
      expect(fireball.matches('fire', schoolFilter: SpellSchool.evocation), isTrue);
      expect(fireball.matches('fire', schoolFilter: SpellSchool.illusion), isFalse);
    });

    test('Helper query methods return expected collections', () {
      final changed = SpellbookLibrary.getChangedSpells();
      expect(changed.isNotEmpty, isTrue);
      expect(changed.every((s) => s.isChangedIn2024), isTrue);

      final cantrips = SpellbookLibrary.getSpellsByLevel(0);
      expect(cantrips.isNotEmpty, isTrue);
      expect(cantrips.every((s) => s.level == 0), isTrue);

      final wizardSpells = SpellbookLibrary.getSpellsByClass(SpellClass.wizard);
      expect(wizardSpells.any((s) => s.id == 'spell_fireball'), isTrue);
      expect(wizardSpells.any((s) => s.id == 'spell_wish'), isTrue);
    });

    test('Summon presets link directly to SpellbookLibrary source spells', () {
      final animateObjectsSpell = SpellbookLibrary.getSpellById('spell_animate_objects');
      expect(animateObjectsSpell, isNotNull);
      expect(animateObjectsSpell!.level, 5);
      expect(animateObjectsSpell.school, SpellSchool.transmutation);

      final conjureAnimalsSpell = SpellbookLibrary.getSpellById('spell_conjure_animals');
      expect(conjureAnimalsSpell, isNotNull);
      expect(conjureAnimalsSpell!.isChangedIn2024, isTrue);

      final animateDeadSpell = SpellbookLibrary.getSpellById('spell_animate_dead');
      expect(animateDeadSpell, isNotNull);
      expect(animateDeadSpell!.school, SpellSchool.necromancy);
    });

    test('Unified SpellSchool provides canonical styling tokens and icons', () {
      for (final school in SpellSchool.values) {
        expect(school.displayName.isNotEmpty, isTrue);
        expect(school.label, school.displayName);
        expect(school.color, isNotNull);
        expect(school.icon, isNotNull);
        expect(school.getLegibleColor(true), isNotNull);
        expect(school.getLegibleColor(false), isNotNull);
      }
    });

    test('Cleric spell list includes spells across all spell levels 0 through 9', () {
      final clericSpells2014 = SpellbookLibrary.getSpellsByClass(SpellClass.cleric, edition: DmRulesEdition.v2014);
      final clericSpells2024 = SpellbookLibrary.getSpellsByClass(SpellClass.cleric, edition: DmRulesEdition.v2024);

      expect(clericSpells2014.isNotEmpty, isTrue);
      expect(clericSpells2024.isNotEmpty, isTrue);

      for (int lvl = 0; lvl <= 9; lvl++) {
        expect(clericSpells2014.any((s) => s.level == lvl), isTrue, reason: 'Missing 2014 Cleric spell at level $lvl');
        expect(clericSpells2024.any((s) => s.level == lvl), isTrue, reason: 'Missing 2024 Cleric spell at level $lvl');
      }

      // Check iconic high-level cleric spells
      expect(SpellbookLibrary.getSpellById('spell_harm'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_heroes_feast'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_divine_word'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_fire_storm'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_regenerate'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_resurrection'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_holy_aura'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_earthquake'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_mass_heal'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_true_resurrection'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_gate'), isNotNull);
      expect(SpellbookLibrary.getSpellById('spell_astral_projection'), isNotNull);
    });

    test('Every spellcasting class has rich spell coverage in both 2014 and 2024 editions', () {
      for (final cls in SpellClass.values) {
        final spells2014 = SpellbookLibrary.getSpellsByClass(cls, edition: DmRulesEdition.v2014);
        final spells2024 = SpellbookLibrary.getSpellsByClass(cls, edition: DmRulesEdition.v2024);

        expect(spells2014.isNotEmpty, isTrue, reason: 'Class ${cls.label} has no 2014 spells');
        expect(spells2024.isNotEmpty, isTrue, reason: 'Class ${cls.label} has no 2024 spells');

        // Full casters have spells across levels 0 to 9
        if (cls == SpellClass.cleric || cls == SpellClass.wizard || cls == SpellClass.sorcerer || cls == SpellClass.druid || cls == SpellClass.bard || cls == SpellClass.warlock) {
          final maxLevel = spells2024.map((s) => s.level).reduce((a, b) => a > b ? a : b);
          expect(maxLevel, 9, reason: 'Full caster ${cls.label} should reach 9th level spells');
        }
      }
    });

    test('All classes match canonical SRD 5.1 class spell assignments', () {
      // Canonical SRD 5.1 Paladin Spells
      const paladinSrd = {
        'Bless', 'Command', 'Cure Wounds', 'Detect Evil and Good', 'Detect Magic',
        'Detect Poison and Disease', 'Divine Favor', 'Heroism', 'Protection from Evil and Good',
        'Purify Food and Drink', 'Shield of Faith', 'Aid', 'Find Steed', 'Lesser Restoration',
        'Locate Object', 'Magic Weapon', 'Protection from Poison', 'Zone of Truth',
        'Create Food and Water', 'Daylight', 'Dispel Magic', 'Magic Circle', 'Remove Curse',
        'Revivify', 'Banishment', 'Death Ward', 'Locate Creature', 'Dispel Evil and Good',
        'Geas', 'Raise Dead'
      };

      // Canonical SRD 5.1 Ranger Spells
      const rangerSrd = {
        'Alarm', 'Animal Friendship', 'Cure Wounds', 'Detect Magic', 'Detect Poison and Disease',
        'Fog Cloud', 'Goodberry', "Hunter's Mark", 'Jump', 'Longstrider', 'Speak with Animals',
        'Animal Messenger', 'Barkskin', 'Darkvision', 'Find Traps', 'Lesser Restoration',
        'Locate Animals or Plants', 'Locate Object', 'Pass without Trace', 'Protection from Poison',
        'Silence', 'Spike Growth', 'Conjure Animals', 'Daylight', 'Nondetection', 'Plant Growth',
        'Protection from Energy', 'Speak with Plants', 'Water Breathing', 'Water Walk', 'Wind Wall',
        'Conjure Woodland Beings', 'Freedom of Movement', 'Locate Creature', 'Stoneskin',
        'Commune with Nature', 'Tree Stride'
      };

      // Canonical SRD 5.1 Warlock Spells
      const warlockSrd = {
        'Chill Touch', 'Eldritch Blast', 'Friends', 'Mage Hand', 'Minor Illusion',
        'Poison Spray', 'Prestidigitation', 'True Strike', 'Charm Person', 'Comprehend Languages',
        'Expeditious Retreat', 'Hellish Rebuke', 'Illusory Script', 'Protection from Evil and Good',
        'Unseen Servant', 'Darkness', 'Enthrall', 'Hold Person', 'Invisibility', 'Mirror Image',
        'Misty Step', 'Ray of Enfeeblement', 'Shatter', 'Spider Climb', 'Suggestion',
        'Counterspell', 'Dispel Magic', 'Fear', 'Fly', 'Gaseous Form', 'Hypnotic Pattern',
        'Magic Circle', 'Major Image', 'Remove Curse', 'Tongues', 'Vampiric Touch',
        'Banishment', 'Blight', 'Dimension Door', 'Hallucinatory Terrain', 'Contact Other Plane',
        'Dream', 'Hold Monster', 'Scrying', 'Circle of Death', 'Conjure Fey', 'Create Undead',
        'Eyebite', 'Flesh to Stone', 'Mass Suggestion', 'True Seeing',
        'Etherealness', 'Finger of Death', 'Forcecage', 'Plane Shift', 'Demiplane',
        'Dominate Monster', 'Feeblemind', 'Power Word Stun', 'Astral Projection', 'Foresight',
        'Imprisonment', 'Power Word Kill', 'True Polymorph'
      };

      // Canonical SRD 5.1 Cleric Spells
      const clericSrd = {
        'Guidance', 'Light', 'Mending', 'Resistance', 'Sacred Flame', 'Spare the Dying',
        'Thaumaturgy', 'Bane', 'Bless', 'Command', 'Create or Destroy Water', 'Cure Wounds',
        'Detect Evil and Good', 'Detect Magic', 'Detect Poison and Disease', 'Guiding Bolt',
        'Healing Word', 'Inflict Wounds', 'Protection from Evil and Good', 'Purify Food and Drink',
        'Sanctuary', 'Shield of Faith', 'Aid', 'Augury', 'Blindness/Deafness', 'Calm Emotions',
        'Continual Flame', 'Enhance Ability', 'Find Traps', 'Gentle Repose', 'Hold Person',
        'Lesser Restoration', 'Locate Object', 'Prayer of Healing', 'Protection from Poison',
        'Silence', 'Spiritual Weapon', 'Warding Bond', 'Zone of Truth', 'Animate Dead',
        'Beacon of Hope', 'Bestow Curse', 'Clairvoyance', 'Create Food and Water', 'Daylight',
        'Dispel Magic', 'Feign Death', 'Glyph of Warding', 'Magic Circle', 'Mass Healing Word',
        'Meld into Stone', 'Protection from Energy', 'Remove Curse', 'Revivify', 'Sending',
        'Speak with Dead', 'Spirit Guardians', 'Tongues', 'Water Walk', 'Banishment',
        'Control Water', 'Death Ward', 'Divination', 'Freedom of Movement', 'Guardian of Faith',
        'Locate Creature', 'Stone Shape', 'Commune', 'Contagion', 'Dispel Evil and Good',
        'Flame Strike', 'Geas', 'Greater Restoration', 'Hallow', 'Insect Plague', 'Legend Lore',
        'Mass Cure Wounds', 'Planar Binding', 'Raise Dead', 'Scrying', 'Blade Barrier',
        'Create Undead', 'Find the Path', 'Forbiddance', 'Harm', 'Heal', 'Heroes\' Feast',
        'Planar Ally', 'True Seeing', 'Word of Recall', 'Conjure Celestial', 'Divine Word',
        'Etherealness', 'Fire Storm', 'Plane Shift', 'Regenerate', 'Resurrection', 'Symbol',
        'Antimagic Field', 'Control Weather', 'Earthquake', 'Holy Aura', 'Sunburst',
        'Astral Projection', 'Gate', 'Mass Heal', 'True Resurrection'
      };

      // Canonical SRD 5.1 Druid Spells
      const druidSrd = {
        'Druidcraft', 'Guidance', 'Mending', 'Poison Spray', 'Produce Flame', 'Resistance',
        'Shillelagh', 'Animal Friendship', 'Charm Person', 'Create or Destroy Water',
        'Cure Wounds', 'Detect Magic', 'Detect Poison and Disease', 'Entangle', 'Faerie Fire',
        'Fog Cloud', 'Goodberry', 'Healing Word', 'Jump', 'Longstrider', 'Purify Food and Drink',
        'Speak with Animals', 'Thunderwave', 'Animal Messenger', 'Barkskin', 'Darkvision',
        'Enhance Ability', 'Find Traps', 'Flame Blade', 'Flaming Sphere', 'Gust of Wind',
        'Heat Metal', 'Hold Person', 'Lesser Restoration', 'Locate Animals or Plants',
        'Locate Object', 'Moonbeam', 'Pass without Trace', 'Protection from Poison', 'Spike Growth',
        'Call Lightning', 'Conjure Animals', 'Daylight', 'Dispel Magic', 'Feign Death',
        'Meld into Stone', 'Plant Growth', 'Protection from Energy', 'Sleet Storm',
        'Speak with Plants', 'Water Breathing', 'Water Walk', 'Wind Wall', 'Blight', 'Confusion',
        'Conjure Minor Elementals', 'Conjure Woodland Beings', 'Control Water', 'Dominate Beast',
        'Freedom of Movement', 'Giant Insect', 'Hallucinatory Terrain', 'Ice Storm',
        'Locate Creature', 'Polymorph', 'Stone Shape', 'Stoneskin', 'Wall of Fire',
        'Antilife Shell', 'Awaken', 'Commune with Nature', 'Conjure Elemental', 'Contagion',
        'Geas', 'Greater Restoration', 'Insect Plague', 'Mass Cure Wounds',
        'Planar Binding', 'Reincarnate', 'Scrying', 'Tree Stride', 'Wall of Stone', 'Conjure Fey',
        'Find the Path', 'Heal', 'Heroes\' Feast', 'Move Earth', 'Sunbeam', 'Transport via Plants',
        'Wall of Thorns', 'Wind Walk', 'Fire Storm', 'Mirage Arcane', 'Plane Shift',
        'Regenerate', 'Reverse Gravity', 'Animal Shapes', 'Antipathy/Sympathy', 'Control Weather',
        'Earthquake', 'Feeblemind', 'Sunburst', 'Tsunami', 'Foresight', 'Shapechange',
        'Storm of Vengeance', 'True Resurrection'
      };

      for (final name in paladinSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Paladin spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.paladin),
          isTrue,
          reason: 'Spell $name should be on Paladin 2014 spell list',
        );
      }

      for (final name in rangerSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Ranger spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.ranger),
          isTrue,
          reason: 'Spell $name should be on Ranger 2014 spell list',
        );
      }

      for (final name in warlockSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Warlock spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.warlock),
          isTrue,
          reason: 'Spell $name should be on Warlock 2014 spell list',
        );
      }

      for (final name in clericSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Cleric spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.cleric),
          isTrue,
          reason: 'Spell $name should be on Cleric 2014 spell list',
        );
      }

      for (final name in druidSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Druid spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.druid),
          isTrue,
          reason: 'Spell $name should be on Druid 2014 spell list',
        );
      }

      // Canonical SRD 5.1 Bard Spells
      const bardSrd = {
        'Blade Ward', 'Dancing Lights', 'Friends', 'Light', 'Mage Hand', 'Mending',
        'Message', 'Minor Illusion', 'Prestidigitation', 'True Strike', 'Vicious Mockery',
        'Animal Friendship', 'Bane', 'Charm Person', 'Comprehend Languages', 'Cure Wounds',
        'Detect Magic', 'Disguise Self', 'Faerie Fire', 'Feather Fall', 'Healing Word',
        'Heroism', 'Hideous Laughter', 'Identify', 'Illusory Script', 'Longstrider',
        'Silent Image', 'Sleep', 'Speak with Animals', 'Thunderwave', 'Unseen Servant',
        'Animal Messenger', 'Blindness/Deafness', 'Calm Emotions', 'Detect Thoughts',
        'Enhance Ability', 'Enthrall', 'Heat Metal', 'Hold Person', 'Invisibility',
        'Knock', 'Lesser Restoration', 'Locate Animals or Plants', 'Locate Object',
        'Magic Mouth', 'See Invisibility', 'Shatter', 'Silence', 'Suggestion', 'Zone of Truth',
        'Bestow Curse', 'Clairvoyance', 'Dispel Magic', 'Fear', 'Feign Death',
        'Hypnotic Pattern', 'Major Image', 'Nondetection', 'Plant Growth', 'Sending',
        'Speak with Dead', 'Speak with Plants', 'Stinking Cloud', 'Tiny Hut', 'Tongues',
        'Compulsion', 'Confusion', 'Dimension Door', 'Freedom of Movement', 'Greater Invisibility',
        'Hallucinatory Terrain', 'Locate Creature', 'Polymorph', 'Animate Objects', 'Awaken',
        'Dominate Person', 'Dream', 'Geas', 'Greater Restoration', 'Hold Monster',
        'Legend Lore', 'Mass Cure Wounds', 'Mislead', 'Modify Memory', 'Planar Binding',
        'Raise Dead', 'Scrying', 'Seeming', 'Telepathic Bond', 'Teleportation Circle',
        'Eyebite', 'Find the Path', 'Guards and Wards',
        'Irresistible Dance', 'Mass Suggestion', 'Programmed Illusion', 'True Seeing',
        'Arcane Sword', 'Etherealness', 'Forcecage', 'Magnificent Mansion', 'Mirage Arcane',
        'Project Image', 'Regenerate', 'Resurrection',
        'Symbol', 'Teleport', 'Dominate Monster',
        'Feeblemind', 'Mind Blank', 'Power Word Stun', 'Foresight',
        'Power Word Kill', 'True Polymorph'
      };

      // Canonical SRD 5.1 Sorcerer Spells
      const sorcererSrd = {
        'Acid Splash', 'Blade Ward', 'Chill Touch', 'Dancing Lights', 'Fire Bolt',
        'Friends', 'Light', 'Mage Hand', 'Mending', 'Message', 'Minor Illusion',
        'Poison Spray', 'Prestidigitation', 'Ray of Frost', 'Shocking Grasp',
        'True Strike', 'Burning Hands', 'Charm Person', 'Color Spray', 'Comprehend Languages',
        'Detect Magic', 'Disguise Self', 'Expeditious Retreat', 'False Life', 'Feather Fall',
        'Fog Cloud', 'Jump', 'Mage Armor', 'Magic Missile', 'Shield', 'Silent Image',
        'Sleep', 'Thunderwave', 'Alter Self', 'Blindness/Deafness', 'Blur', 'Darkness',
        'Darkvision', 'Detect Thoughts', 'Enhance Ability', 'Enlarge/Reduce', 'Gust of Wind',
        'Hold Person', 'Invisibility', 'Knock', 'Levitate', 'Mirror Image', 'Misty Step',
        'Scorching Ray', 'See Invisibility', 'Shatter', 'Spider Climb', 'Web', 'Blink',
        'Clairvoyance', 'Counterspell', 'Daylight', 'Dispel Magic', 'Fear', 'Fireball',
        'Fly', 'Gaseous Form', 'Haste', 'Hypnotic Pattern', 'Lightning Bolt', 'Major Image',
        'Protection from Energy', 'Sleet Storm', 'Slow', 'Stinking Cloud', 'Tongues',
        'Water Breathing', 'Water Walk', 'Banishment', 'Blight', 'Confusion', 'Dimension Door',
        'Dominate Beast', 'Greater Invisibility', 'Ice Storm', 'Polymorph', 'Stoneskin',
        'Wall of Fire', 'Animate Objects', 'Cloudkill', 'Cone of Cold', 'Creation',
        'Dominate Person', 'Hold Monster', 'Insect Plague', 'Seeming', 'Telekinesis',
        'Teleportation Circle', 'Wall of Stone', 'Arcane Gate', 'Chain Lightning',
        'Circle of Death', 'Disintegrate', 'Eyebite', 'Globe of Invulnerability', 'Move Earth',
        'Sunbeam', 'True Seeing', 'Delayed Blast Fireball', 'Etherealness', 'Finger of Death',
        'Fire Storm', 'Plane Shift', 'Prismatic Spray', 'Reverse Gravity', 'Teleport',
        'Dominate Monster', 'Earthquake', 'Incendiary Cloud', 'Power Word Stun', 'Sunburst',
        'Gate', 'Meteor Swarm', 'Power Word Kill', 'Time Stop', 'Wish'
      };

      // Canonical SRD 5.1 Wizard Spells
      const wizardSrd = {
        'Acid Splash', 'Blade Ward', 'Chill Touch', 'Dancing Lights', 'Fire Bolt',
        'Friends', 'Light', 'Mage Hand', 'Mending', 'Message', 'Minor Illusion',
        'Poison Spray', 'Prestidigitation', 'Ray of Frost', 'Shocking Grasp', 'True Strike',
        'Alarm', 'Burning Hands', 'Charm Person', 'Color Spray', 'Comprehend Languages',
        'Detect Magic', 'Disguise Self', 'Expeditious Retreat', 'False Life', 'Feather Fall',
        'Find Familiar', 'Floating Disk', 'Fog Cloud', 'Grease', 'Hideous Laughter',
        'Identify', 'Illusory Script', 'Jump', 'Longstrider', 'Mage Armor', 'Magic Missile',
        'Protection from Evil and Good', 'Shield', 'Silent Image', 'Sleep', 'Thunderwave',
        'Unseen Servant', 'Acid Arrow', 'Alter Self', 'Arcane Lock', 'Blindness/Deafness',
        'Blur', 'Continual Flame', 'Darkness', 'Darkvision', 'Detect Thoughts', 'Enlarge/Reduce',
        'Flaming Sphere', 'Gentle Repose', 'Gust of Wind', 'Hold Person', 'Invisibility',
        'Knock', 'Levitate', 'Locate Object', 'Magic Mouth', 'Magic Weapon', 'Mirror Image',
        'Misty Step', 'Ray of Enfeeblement', 'Rope Trick', 'Scorching Ray', 'See Invisibility',
        'Shatter', 'Spider Climb', 'Suggestion', 'Web', 'Animate Dead', 'Bestow Curse',
        'Blink', 'Clairvoyance', 'Counterspell', 'Dispel Magic', 'Fear', 'Feign Death',
        'Fireball', 'Fly', 'Gaseous Form', 'Glyph of Warding', 'Haste', 'Hypnotic Pattern',
        'Lightning Bolt', 'Magic Circle', 'Major Image', 'Nondetection', 'Phantom Steed',
        'Protection from Energy', 'Remove Curse', 'Sending', 'Sleet Storm', 'Slow',
        'Stinking Cloud', 'Tiny Hut', 'Tongues', 'Vampiric Touch', 'Water Breathing',
        'Arcane Eye', 'Banishment', 'Black Tentacles', 'Blight', 'Confusion',
        'Conjure Minor Elementals', 'Control Water', 'Dimension Door', 'Fabricate',
        'Faithful Hound', 'Fire Shield', 'Greater Invisibility', 'Hallucinatory Terrain',
        'Ice Storm', 'Locate Creature', 'Phantasmal Killer', 'Polymorph', 'Private Sanctum',
        'Resilient Sphere', 'Secret Chest', 'Stone Shape', 'Stoneskin', 'Wall of Fire',
        'Animate Objects', 'Cloudkill', 'Cone of Cold', 'Conjure Elemental', 'Contact Other Plane',
        'Creation', 'Dream', 'Geas', 'Hold Monster', 'Legend Lore', 'Mislead', 'Modify Memory',
        'Passwall', 'Planar Binding', 'Scrying', 'Seeming', 'Telekinesis', 'Telepathic Bond',
        'Teleportation Circle', 'Wall of Force', 'Wall of Stone', 'Arcane Gate', 'Chain Lightning',
        'Circle of Death', 'Contingency', 'Create Undead', 'Disintegrate', 'Eyebite',
        'Flesh to Stone', 'Freezing Sphere', 'Globe of Invulnerability', 'Guards and Wards',
        'Instant Summons', 'Irresistible Dance', 'Magic Jar', 'Mass Suggestion', 'Move Earth',
        'Programmed Illusion', 'Sunbeam', 'True Seeing', 'Wall of Ice', 'Arcane Sword',
        'Delayed Blast Fireball', 'Etherealness', 'Finger of Death', 'Forcecage',
        'Magnificent Mansion', 'Mirage Arcane', 'Plane Shift', 'Prismatic Spray',
        'Project Image', 'Reverse Gravity', 'Sequester', 'Simulacrum', 'Symbol', 'Teleport',
        'Antimagic Field', 'Antipathy/Sympathy', 'Clone', 'Control Weather', 'Demiplane',
        'Dominate Monster', 'Feeblemind', 'Incendiary Cloud', 'Maze', 'Mind Blank',
        'Power Word Stun', 'Sunburst', 'Astral Projection', 'Foresight', 'Gate', 'Imprisonment',
        'Meteor Swarm', 'Power Word Kill', 'Prismatic Wall', 'Shapechange', 'Time Stop',
        'True Polymorph', 'Weird', 'Wish'
      };

      for (final name in bardSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Bard spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.bard),
          isTrue,
          reason: 'Spell $name should be on Bard 2014 spell list',
        );
      }

      for (final name in sorcererSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Sorcerer spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.sorcerer),
          isTrue,
          reason: 'Spell $name should be on Sorcerer 2014 spell list',
        );
      }

      for (final name in wizardSrd) {
        final spell = SpellbookLibrary.allSpells.firstWhere(
          (s) => s.name.toLowerCase() == name.toLowerCase(),
          orElse: () => throw Exception('Wizard spell $name not found in library'),
        );
        expect(
          spell.rules2014.classes.contains(SpellClass.wizard),
          isTrue,
          reason: 'Spell $name should be on Wizard 2014 spell list',
        );
      }
    });

    test('All changed spells have diffSummary and unchanged spells have uniform rules properties', () {
      for (final spell in SpellbookLibrary.allSpells) {
        final r2014 = spell.rules2014;
        final r2024 = spell.rules2024;

        if (spell.isChangedIn2024) {
          expect(
            spell.diffSummary != null && spell.diffSummary!.isNotEmpty,
            isTrue,
            reason: '${spell.name} is marked changed but has no diffSummary',
          );
        } else {
          // Unchanged spells should have identical core mechanical fields
          expect(
            r2014.castingTime,
            r2024.castingTime,
            reason: '${spell.name} castingTime mismatch for unchanged spell',
          );
          expect(
            r2014.range,
            r2024.range,
            reason: '${spell.name} range mismatch for unchanged spell',
          );
          expect(
            r2014.duration,
            r2024.duration,
            reason: '${spell.name} duration mismatch for unchanged spell',
          );
          expect(
            r2014.concentration,
            r2024.concentration,
            reason: '${spell.name} concentration mismatch for unchanged spell',
          );
          expect(
            r2014.ritual,
            r2024.ritual,
            reason: '${spell.name} ritual mismatch for unchanged spell',
          );
        }
      }
    });

    test('Identifies missing SRD 5.1 spells', () {
      const srd51SpellNames = {
        // Cantrips
        'Acid Splash', 'Blade Ward', 'Chill Touch', 'Dancing Lights', 'Druidcraft',
        'Eldritch Blast', 'Fire Bolt', 'Friends', 'Guidance', 'Light',
        'Mage Hand', 'Mending', 'Message', 'Minor Illusion', 'Poison Spray',
        'Prestidigitation', 'Produce Flame', 'Ray of Frost', 'Resistance',
        'Sacred Flame', 'Shillelagh', 'Shocking Grasp', 'Spare the Dying',
        'Thaumaturgy', 'True Strike', 'Vicious Mockery',

        // 1st Level
        'Alarm', 'Animal Friendship', 'Bane', 'Bless', 'Burning Hands',
        'Charm Person', 'Color Spray', 'Command', 'Comprehend Languages',
        'Cure Wounds', 'Detect Evil and Good', 'Detect Magic', 'Detect Poison and Disease',
        'Disguise Self', 'Divine Favor', 'Entangle', 'Expeditious Retreat',
        'Faerie Fire', 'False Life', 'Feather Fall', 'Find Familiar', 'Floating Disk',
        'Fog Cloud', 'Goodberry', 'Grease', 'Guiding Bolt', 'Healing Word',
        'Hellish Rebuke', 'Heroism', 'Hideous Laughter', 'Hunter’s Mark', 'Identify',
        'Illusory Script', 'Inflict Wounds', 'Jump', 'Longstrider', 'Mage Armor',
        'Magic Missile', 'Protection from Evil and Good', 'Purify Food and Drink',
        'Sanctuary', 'Shield', 'Shield of Faith', 'Silent Image', 'Sleep',
        'Speak with Animals', 'Thunderwave', 'Unseen Servant',

        // 2nd Level
        'Acid Arrow', 'Aid', 'Alter Self', 'Animal Messenger', 'Arcane Lock',
        'Augury', 'Barkskin', 'Blindness/Deafness', 'Blur', 'Calm Emotions',
        'Continual Flame', 'Darkness', 'Darkvision', 'Detect Thoughts',
        'Enhance Ability', 'Enlarge/Reduce', 'Enthrall', 'Find Steed',
        'Find Traps', 'Flame Blade', 'Flaming Sphere', 'Gentle Repose',
        'Gust of Wind', 'Heat Metal', 'Hold Person', 'Invisibility', 'Knock',
        'Lesser Restoration', 'Levitate', 'Locate Animals or Plants', 'Locate Object',
        'Magic Mouth', 'Magic Weapon', 'Mirror Image', 'Misty Step', 'Moonbeam',
        'Pass without Trace', 'Prayer of Healing', 'Protection from Poison',
        'Ray of Enfeeblement', 'Rope Trick', 'Scorching Ray', 'See Invisibility',
        'Shatter', 'Silence', 'Spider Climb', 'Spike Growth', 'Spiritual Weapon',
        'Suggestion', 'Warding Bond', 'Web', 'Zone of Truth',

        // 3rd Level
        'Animate Dead', 'Beacon of Hope', 'Bestow Curse', 'Blink', 'Call Lightning',
        'Clairvoyance', 'Conjure Animals', 'Counterspell', 'Create Food and Water',
        'Daylight', 'Dispel Magic', 'Fear', 'Feign Death', 'Fireball',
        'Fly', 'Gaseous Form', 'Glyph of Warding', 'Haste', 'Hypnotic Pattern',
        'Lightning Bolt', 'Magic Circle', 'Major Image', 'Mass Healing Word',
        'Meld into Stone', 'Nondetection', 'Phantom Steed', 'Plant Growth',
        'Protection from Energy', 'Remove Curse', 'Revivify', 'Sending',
        'Sleet Storm', 'Slow', 'Speak with Dead', 'Speak with Plants',
        'Spirit Guardians', 'Stinking Cloud', 'Tiny Hut', 'Tongues',
        'Vampiric Touch', 'Water Breathing', 'Water Walk', 'Wind Wall',

        // 4th Level
        'Arcane Eye', 'Banishment', 'Black Tentacles', 'Blight', 'Compulsion',
        'Confusion', 'Conjure Minor Elementals', 'Conjure Woodland Beings',
        'Control Water', 'Death Ward', 'Dimension Door', 'Divination',
        'Dominate Beast', 'Fabricate', 'Faithful Hound', 'Fire Shield',
        'Freedom of Movement', 'Giant Insect', 'Greater Invisibility',
        'Guardian of Faith', 'Hallucinatory Terrain', 'Ice Storm', 'Locate Creature',
        'Phantasmal Killer', 'Polymorph', 'Private Sanctum', 'Resilient Sphere',
        'Secret Chest', 'Stone Shape', 'Stoneskin', 'Wall of Fire',

        // 5th Level
        'Animate Objects', 'Antilife Shell', 'Awaken', 'Cloudkill', 'Commune',
        'Commune with Nature', 'Cone of Cold', 'Conjure Elemental',
        'Contact Other Plane', 'Contagion', 'Creation', 'Dispel Evil and Good',
        'Dominate Person', 'Dream', 'Flame Strike', 'Geas', 'Greater Restoration',
        'Hallow', 'Hold Monster', 'Insect Plague', 'Legend Lore', 'Mass Cure Wounds',
        'Mislead', 'Modify Memory', 'Passwall', 'Planar Binding', 'Raise Dead',
        'Reincarnate', 'Scrying', 'Seeming', 'Telekinesis', 'Telepathic Bond',
        'Teleportation Circle', 'Tree Stride', 'Wall of Force', 'Wall of Stone',

        // 6th Level
        'Arcane Gate', 'Blade Barrier', 'Chain Lightning', 'Circle of Death',
        'Conjure Fey', 'Contingency', 'Create Undead', 'Disintegrate',
        'Eyebite', 'Find the Path', 'Flesh to Stone', 'Forbiddance',
        'Freezing Sphere', 'Globe of Invulnerability', 'Guards and Wards',
        'Harm', 'Heal', 'Heroes\' Feast', 'Instant Summons', 'Irresistible Dance',
        'Magic Jar', 'Mass Suggestion', 'Move Earth', 'Planar Ally',
        'Programmed Illusion', 'Sunbeam', 'Transport via Plants', 'True Seeing',
        'Wall of Ice', 'Wall of Thorns', 'Wind Walk', 'Word of Recall',

        // 7th Level
        'Arcane Sword', 'Conjure Celestial', 'Delayed Blast Fireball', 'Divine Word',
        'Etherealness', 'Finger of Death', 'Fire Storm', 'Forcecage', 'Magnificent Mansion',
        'Mirage Arcane', 'Plane Shift', 'Prismatic Spray', 'Project Image',
        'Regenerate', 'Resurrection', 'Reverse Gravity', 'Sequester', 'Simulacrum',
        'Symbol', 'Teleport',

        // 8th Level
        'Animal Shapes', 'Antimagic Field', 'Antipathy/Sympathy', 'Clone',
        'Control Weather', 'Demiplane', 'Dominate Monster', 'Earthquake',
        'Feeblemind', 'Holy Aura', 'Incendiary Cloud', 'Maze', 'Mind Blank',
        'Power Word Stun', 'Sunburst', 'Tsunami',

        // 9th Level
        'Astral Projection', 'Foresight', 'Gate', 'Imprisonment', 'Mass Heal',
        'Meteor Swarm', 'Power Word Heal', 'Power Word Kill', 'Prismatic Wall',
        'Shapechange', 'Storm of Vengeance', 'Time Stop', 'True Polymorph',
        'True Resurrection', 'Weird', 'Wish',
      };

      final currentNames = <String>{};
      for (final s in SpellbookLibrary.allSpells) {
        currentNames.add(s.name.toLowerCase().replaceAll('’', "'"));
        if (s.name2014 != null) currentNames.add(s.name2014!.toLowerCase().replaceAll('’', "'"));
        if (s.name2024 != null) currentNames.add(s.name2024!.toLowerCase().replaceAll('’', "'"));
      }
      final missing = <String>[];
      for (final s in srd51SpellNames) {
        final clean = s.toLowerCase().replaceAll('’', "'");
        final match = currentNames.contains(clean);
        if (!match) {
          missing.add(s);
        }
      }
      expect(missing, isEmpty, reason: 'Missing spells from SRD 5.1: $missing');
    });
  });
}



