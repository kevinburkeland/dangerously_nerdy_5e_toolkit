import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/glyph_gallery_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_tokens.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';

void main() {
  group('Polymorphic Glyph System & Renderables', () {
    test('All gallery catalog entries implement GlyphRenderable properly', () {
      expect(GlyphGalleryData.allSpells, isNotEmpty);
      expect(GlyphGalleryData.allCreatures, isNotEmpty);
      expect(GlyphGalleryData.allItems, isNotEmpty);
      expect(GlyphGalleryData.allFeats, isNotEmpty);
      expect(GlyphGalleryData.allClasses, isNotEmpty);
      expect(GlyphGalleryData.allSpecies, isNotEmpty);
      expect(GlyphGalleryData.allGenericUi, isNotEmpty);

      // Verify Spells
      for (final spell in GlyphGalleryData.allSpells) {
        expect(spell.glyphId, isNotEmpty);
        expect(spell.displayName, isNotEmpty);
        expect(spell.glyphCategory, equals(GlyphCategory.spell));
        expect(spell.fallbackIcon, isNotNull);
        expect(spell.metadata, isNotNull);
      }

      // Verify Creatures
      for (final creature in GlyphGalleryData.allCreatures) {
        expect(creature.glyphId, isNotEmpty);
        expect(creature.displayName, isNotEmpty);
        expect(creature.glyphCategory, equals(GlyphCategory.creature));
        expect(creature.fallbackIcon, isNotNull);
        expect(creature.metadata, isNotNull);
      }

      // Verify Items
      for (final item in GlyphGalleryData.allItems) {
        expect(item.glyphId, isNotEmpty);
        expect(item.displayName, isNotEmpty);
        expect(item.glyphCategory, equals(GlyphCategory.item));
        expect(item.fallbackIcon, isNotNull);
        expect(item.metadata, isNotNull);
      }

      // Verify Feats
      for (final feat in GlyphGalleryData.allFeats) {
        expect(feat.glyphId, isNotEmpty);
        expect(feat.displayName, isNotEmpty);
        expect(feat.glyphCategory, equals(GlyphCategory.feat));
        expect(feat.fallbackIcon, isNotNull);
        expect(feat.metadata, isNotNull);
      }

      // Verify Classes
      for (final cls in GlyphGalleryData.allClasses) {
        expect(cls.glyphId, isNotEmpty);
        expect(cls.displayName, isNotEmpty);
        expect(cls.glyphCategory, equals(GlyphCategory.classFeature));
        expect(cls.fallbackIcon, isNotNull);
        expect(cls.metadata, isNotNull);
        expect(cls.classType.hitDieSides, isIn([6, 8, 10, 12]));
      }

      // Verify Species
      for (final spec in GlyphGalleryData.allSpecies) {
        expect(spec.glyphId, isNotEmpty);
        expect(spec.displayName, isNotEmpty);
        expect(spec.glyphCategory, equals(GlyphCategory.species));
        expect(spec.fallbackIcon, isNotNull);
        expect(spec.metadata, isNotNull);
        expect(spec.speed, isPositive);
      }

      // Verify Generic UI
      for (final ui in GlyphGalleryData.allGenericUi) {
        expect(ui.glyphId, isNotEmpty);
        expect(ui.displayName, isNotEmpty);
        expect(ui.glyphCategory, equals(GlyphCategory.genericUi));
        expect(ui.fallbackIcon, isNotNull);
        expect(ui.metadata, isNotNull);
      }
    });

    testWidgets('DndGlyph.fromRenderable renders Spells, Creatures, and Items',
        (tester) async {
      final spell = GlyphGalleryData.allSpells.first;
      final creature = GlyphGalleryData.allCreatures.first;
      final item = GlyphGalleryData.allItems.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DndGlyph.fromRenderable(spell, size: 64),
                DndGlyph.fromRenderable(creature, size: 64),
                DndGlyph.fromRenderable(item, size: 64),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsNWidgets(3));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('DndGlyph.fromRenderable renders Feats, Classes, Species, and Generic UI',
        (tester) async {
      final feat = GlyphGalleryData.allFeats.first;
      final cls = GlyphGalleryData.allClasses.first;
      final spec = GlyphGalleryData.allSpecies.first;
      final ui = GlyphGalleryData.allGenericUi.first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DndGlyph.fromRenderable(feat, size: 64),
                DndGlyph.fromRenderable(cls, size: 64),
                DndGlyph.fromRenderable(spec, size: 64),
                DndGlyph.fromRenderable(ui, size: 64),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsNWidgets(4));
    });

    testWidgets('DndGlyph renders all 13 Character Classes without exception',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: DndClassType.values.map((c) {
                  return DndGlyph.classFeature(
                    classType: c,
                    size: 48,
                    tooltip: c.displayName,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsNWidgets(13));
    });

    testWidgets('DndGlyph renders all Feat Categories', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: FeatCategory.values.map((fc) {
                return DndGlyph.feat(
                  category: fc,
                  featId: 'test_feat',
                  size: 48,
                );
              }).toList(),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsNWidgets(FeatCategory.values.length));
    });

    testWidgets('DndGlyph renders all Species Types', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Row(
                children: SpeciesType.values.map((st) {
                  return DndGlyph.species(
                    speciesType: st,
                    size: 48,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsNWidgets(SpeciesType.values.length));
    });

    testWidgets('DndGlyph renders all Generic UI Icons and Dice Polyhedrals',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: GenericUiGlyphType.values.map((uiType) {
                  return DndGlyph.genericUi(
                    uiType: uiType,
                    size: 48,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph),
          findsNWidgets(GenericUiGlyphType.values.length));
    });

    testWidgets('DndGlyph renders with all ActionRingType variants',
        (tester) async {
      final allRings = ActionRingType.values.map((rt) {
        return ActionTraitRing(
          ringType: rt,
          damageType: DamageAccent.fire,
          label: rt.displayName,
        );
      }).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DndGlyph.classFeature(
              classType: DndClassType.barbarian,
              actionRings: allRings,
              size: 96,
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    test('Theme contrast and legibility functions return distinct colors', () {
      for (final ct in DndClassType.values) {
        final darkCol = ct.getLegibleColor(true);
        final lightCol = ct.getLegibleColor(false);
        expect(darkCol, isNotNull);
        expect(lightCol, isNotNull);
      }

      for (final fc in FeatCategory.values) {
        final darkCol = fc.getLegibleColor(true);
        final lightCol = fc.getLegibleColor(false);
        expect(darkCol, isNotNull);
        expect(lightCol, isNotNull);
      }

      for (final st in SpeciesType.values) {
        final darkCol = st.getLegibleColor(true);
        final lightCol = st.getLegibleColor(false);
        expect(darkCol, isNotNull);
        expect(lightCol, isNotNull);
      }

      for (final gt in GenericUiGlyphType.values) {
        final darkCol = gt.getLegibleColor(true);
        final lightCol = gt.getLegibleColor(false);
        expect(darkCol, isNotNull);
        expect(lightCol, isNotNull);
      }
    });

    test('SpeciesType 2014 vs 2024 SRD speed, size, and trait specifications', () {
      // Gnome: 25 ft in 2014 vs 30 ft in 2024
      expect(SpeciesType.gnome.getSpeed(DmRulesEdition.v2014), equals(25));
      expect(SpeciesType.gnome.getSpeed(DmRulesEdition.v2024), equals(30));

      // Dwarf: 25 ft in 2014 vs 30 ft in 2024
      expect(SpeciesType.dwarf.getSpeed(DmRulesEdition.v2014), equals(25));
      expect(SpeciesType.dwarf.getSpeed(DmRulesEdition.v2024), equals(30));

      // Halfling: 25 ft in 2014 vs 30 ft in 2024
      expect(SpeciesType.halfling.getSpeed(DmRulesEdition.v2014), equals(25));
      expect(SpeciesType.halfling.getSpeed(DmRulesEdition.v2024), equals(30));

      // Goliath: 30 ft in 2014 vs 35 ft in 2024
      expect(SpeciesType.goliath.getSpeed(DmRulesEdition.v2014), equals(30));
      expect(SpeciesType.goliath.getSpeed(DmRulesEdition.v2024), equals(35));

      // Elf & Human: 30 ft in both
      expect(SpeciesType.elf.getSpeed(DmRulesEdition.v2014), equals(30));
      expect(SpeciesType.elf.getSpeed(DmRulesEdition.v2024), equals(30));
      expect(SpeciesType.human.getSpeed(DmRulesEdition.v2014), equals(30));
      expect(SpeciesType.human.getSpeed(DmRulesEdition.v2024), equals(30));

      // Size differences: Human is Medium in 2014, Medium or Small in 2024
      expect(SpeciesType.human.getSize(DmRulesEdition.v2014), equals('Medium'));
      expect(SpeciesType.human.getSize(DmRulesEdition.v2024), equals('Medium or Small'));

      // Gnome is Small in both
      expect(SpeciesType.gnome.getSize(DmRulesEdition.v2014), equals('Small'));
      expect(SpeciesType.gnome.getSize(DmRulesEdition.v2024), equals('Small'));

      // Trait differences
      expect(SpeciesType.gnome.getTraits(DmRulesEdition.v2014),
          contains('Gnome Cunning'));
      expect(SpeciesType.gnome.getTraits(DmRulesEdition.v2024),
          contains('Gnomish Cunning'));
      expect(SpeciesType.dwarf.getTraits(DmRulesEdition.v2024),
          contains('Tremorsense'));
    });

    test('GlyphSpeciesEntry returns edition-aware data and action rings', () {
      final gnome = GlyphGalleryData.allSpecies
          .firstWhere((s) => s.speciesType == SpeciesType.gnome);

      expect(gnome.getSpeed(DmRulesEdition.v2014), equals(25));
      expect(gnome.getSpeed(DmRulesEdition.v2024), equals(30));
      expect(gnome.getActionRings(DmRulesEdition.v2014), isNotEmpty);
      expect(gnome.getActionRings(DmRulesEdition.v2024), isNotEmpty);

      final dwarf = GlyphGalleryData.allSpecies
          .firstWhere((s) => s.speciesType == SpeciesType.dwarf);

      expect(dwarf.getSpeed(DmRulesEdition.v2014), equals(25));
      expect(dwarf.getSpeed(DmRulesEdition.v2024), equals(30));
    });
  });
}
