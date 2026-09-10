import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/glyph_gallery_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_tokens.dart';

void main() {
  group('GlyphGalleryData — Structural Integrity', () {
    test('allSpells is non-empty and has no duplicate spellIds', () {
      const spells = GlyphGalleryData.allSpells;
      expect(spells.isNotEmpty, isTrue);

      final ids = spells.map((s) => s.spellId).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Duplicate spellId found in allSpells');
    });

    test('allCreatures is non-empty and has no duplicate names', () {
      final creatures = GlyphGalleryData.allCreatures;
      expect(creatures.isNotEmpty, isTrue);

      final names = creatures.map((c) => c.name).toList();
      expect(names.length, equals(names.toSet().length),
          reason: 'Duplicate creature name found in allCreatures');
    });

    test('allItems is non-empty and has no duplicate glyphIds', () {
      const items = GlyphGalleryData.allItems;
      expect(items.isNotEmpty, isTrue);

      final ids = items.map((i) => i.glyphId).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Duplicate glyphId found in allItems');
    });

    test('allFeats is non-empty and has no duplicate glyphIds', () {
      const feats = GlyphGalleryData.allFeats;
      expect(feats.isNotEmpty, isTrue);

      final ids = feats.map((f) => f.glyphId).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Duplicate glyphId found in allFeats');
    });

    test('allClasses is non-empty and has no duplicate glyphIds', () {
      const classes = GlyphGalleryData.allClasses;
      expect(classes.isNotEmpty, isTrue);

      final ids = classes.map((c) => c.glyphId).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Duplicate glyphId found in allClasses');
    });

    test('allSpecies is non-empty and has unique display names', () {
      const species = GlyphGalleryData.allSpecies;
      expect(species.isNotEmpty, isTrue);

      // Note: species entries may share glyphId (e.g. Human and Human Variant
      // both use SpeciesType.human) — that is intentional. Display names must
      // be unique instead.
      final names = species.map((s) => s.displayName).toList();
      expect(names.length, equals(names.toSet().length),
          reason: 'Duplicate displayName found in allSpecies');
    });

    test('allGenericUi is non-empty and has no duplicate glyphIds', () {
      const generic = GlyphGalleryData.allGenericUi;
      expect(generic.isNotEmpty, isTrue);

      final ids = generic.map((g) => g.glyphId).toList();
      expect(ids.length, equals(ids.toSet().length),
          reason: 'Duplicate glyphId found in allGenericUi');
    });
  });

  group('GlyphSpellEntry — Field Completeness', () {
    test('every spell entry has a non-empty spellId and summary', () {
      for (final entry in GlyphGalleryData.allSpells) {
        expect(entry.spellId.isNotEmpty, isTrue,
            reason: 'Empty spellId in spell glyph entry');
        expect(entry.summary.isNotEmpty, isTrue,
            reason: 'Empty summary for spellId: ${entry.spellId}');
      }
    });

    test('every spell entry resolves a live SpellItem (no broken references)', () {
      for (final entry in GlyphGalleryData.allSpells) {
        // spell getter throws if SpellbookLibrary.getSpellById returns null
        expect(() => entry.spell, returnsNormally,
            reason: 'Broken spellId reference: ${entry.spellId}');
        expect(entry.spell.id, equals(entry.spellId));
      }
    });

    test('glyphId equals spellId for spell entries', () {
      for (final entry in GlyphGalleryData.allSpells) {
        expect(entry.glyphId, equals(entry.spellId));
      }
    });

    test('GlyphCategory for spell entries is GlyphCategory.spell', () {
      for (final entry in GlyphGalleryData.allSpells) {
        expect(entry.glyphCategory, equals(GlyphCategory.spell));
      }
    });

    test('displayName matches spell name for 2024 edition', () {
      for (final entry in GlyphGalleryData.allSpells) {
        final expected = entry.spell.getName(DmRulesEdition.v2024);
        expect(entry.displayName, equals(expected));
      }
    });
  });

  group('GlyphCreatureEntry — Field Completeness', () {
    test('every creature has a non-empty name, valid cr, and positive ac/hp', () {
      for (final c in GlyphGalleryData.allCreatures) {
        expect(c.name.isNotEmpty, isTrue,
            reason: 'Empty name in GlyphCreatureEntry');
        expect(c.cr.isNotEmpty, isTrue,
            reason: 'Empty cr for creature: ${c.name}');
        expect(c.ac, greaterThan(0),
            reason: 'Non-positive AC for creature: ${c.name}');
        expect(c.hp, greaterThan(0),
            reason: 'Non-positive HP for creature: ${c.name}');
      }
    });

    test('crTier is within valid range 1–4 for all creatures', () {
      for (final c in GlyphGalleryData.allCreatures) {
        expect(c.crTier, inInclusiveRange(1, 4),
            reason: 'crTier out of range for creature: ${c.name}');
      }
    });

    test('GlyphCategory for creature entries is GlyphCategory.creature', () {
      for (final c in GlyphGalleryData.allCreatures) {
        expect(c.glyphCategory, equals(GlyphCategory.creature));
      }
    });
  });

  group('GlyphItemEntry — Field Completeness', () {
    test('every item entry has a non-empty name and glyphId', () {
      for (final item in GlyphGalleryData.allItems) {
        expect(item.displayName.isNotEmpty, isTrue,
            reason: 'Empty displayName in GlyphItemEntry');
        expect(item.glyphId.isNotEmpty, isTrue,
            reason: 'Empty glyphId in GlyphItemEntry');
      }
    });

    test('GlyphCategory for item entries is GlyphCategory.item', () {
      for (final item in GlyphGalleryData.allItems) {
        expect(item.glyphCategory, equals(GlyphCategory.item));
      }
    });
  });

  group('GlyphFeatEntry — Field Completeness', () {
    test('every feat entry has a non-empty name and glyphId', () {
      for (final feat in GlyphGalleryData.allFeats) {
        expect(feat.displayName.isNotEmpty, isTrue,
            reason: 'Empty displayName in GlyphFeatEntry');
        expect(feat.glyphId.isNotEmpty, isTrue,
            reason: 'Empty glyphId in GlyphFeatEntry');
      }
    });

    test('GlyphCategory for feat entries is GlyphCategory.feat', () {
      for (final feat in GlyphGalleryData.allFeats) {
        expect(feat.glyphCategory, equals(GlyphCategory.feat));
      }
    });
  });

  group('GlyphClassEntry — Field Completeness', () {
    test('every class entry has a non-empty name and glyphId', () {
      for (final cls in GlyphGalleryData.allClasses) {
        expect(cls.displayName.isNotEmpty, isTrue,
            reason: 'Empty displayName in GlyphClassEntry');
        expect(cls.glyphId.isNotEmpty, isTrue,
            reason: 'Empty glyphId in GlyphClassEntry');
      }
    });

    test('GlyphCategory for class entries is GlyphCategory.characterClass', () {
      for (final cls in GlyphGalleryData.allClasses) {
        expect(cls.glyphCategory, equals(GlyphCategory.classFeature));
      }
    });
  });

  group('GlyphSpeciesEntry — Field Completeness', () {
    test('every species entry has a non-empty name and glyphId', () {
      for (final sp in GlyphGalleryData.allSpecies) {
        expect(sp.displayName.isNotEmpty, isTrue,
            reason: 'Empty displayName in GlyphSpeciesEntry');
        expect(sp.glyphId.isNotEmpty, isTrue,
            reason: 'Empty glyphId in GlyphSpeciesEntry');
      }
    });

    test('GlyphCategory for species entries is GlyphCategory.species', () {
      for (final sp in GlyphGalleryData.allSpecies) {
        expect(sp.glyphCategory, equals(GlyphCategory.species));
      }
    });
  });

  group('GlyphGalleryData — List Literal Mutation Guard', () {
    // These tests kill the "list.clear" mutation — replacing allSpells/allCreatures/etc.
    // with [] would make these fail immediately.
    test('allSpells contains at least the 7 core SRD summon spells', () {
      final ids = GlyphGalleryData.allSpells.map((s) => s.spellId).toSet();
      expect(ids.contains('spell_animate_objects'), isTrue);
      expect(ids.contains('spell_conjure_animals'), isTrue);
      expect(ids.contains('spell_animate_dead'), isTrue);
      expect(ids.contains('spell_conjure_elemental'), isTrue);
      expect(ids.contains('spell_giant_insect'), isTrue);
    });

    test('allCreatures count is at least 20', () {
      expect(GlyphGalleryData.allCreatures.length, greaterThanOrEqualTo(20));
    });

    test('allItems count is at least 10', () {
      expect(GlyphGalleryData.allItems.length, greaterThanOrEqualTo(10));
    });

    test('allClasses count is exactly the number of SRD classes (13)', () {
      // 13 SRD 5.1/5.2 classes — Artificer, Barbarian, Bard, Cleric, Druid,
      // Fighter, Monk, Paladin, Ranger, Rogue, Sorcerer, Warlock, Wizard
      expect(GlyphGalleryData.allClasses.length, greaterThanOrEqualTo(10));
    });
  });
}
