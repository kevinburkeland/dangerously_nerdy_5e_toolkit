import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_tokens.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_geometry.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/glyph_showcase_screen.dart';

void main() {
  group('D&D Glyph System Tests', () {
    test('All 8 SpellSchools define complete color tokens and container shapes', () {
      expect(SpellSchool.values.length, equals(8));
      for (final school in SpellSchool.values) {
        expect(school.displayName.isNotEmpty, isTrue);
        expect(school.primaryColor, isNotNull);
        expect(school.lightFillTint, isNotNull);
        expect(school.darkFillTint, isNotNull);
        expect(school.frameShape, isNotNull);
      }
    });

    test('All 14 CreatureTypes define complete color tokens and container shapes', () {
      expect(CreatureType.values.length, equals(14));
      for (final type in CreatureType.values) {
        expect(type.displayName.isNotEmpty, isTrue);
        expect(type.primaryColor, isNotNull);
        expect(type.lightFillTint, isNotNull);
        expect(type.darkFillTint, isNotNull);
        expect(type.frameShape, isNotNull);
      }
    });

    test('All 11 DamageAccents and 5 ActionBadges have valid colors', () {
      expect(DamageAccent.values.length, equals(11));
      for (final acc in DamageAccent.values) {
        expect(acc.displayName.isNotEmpty, isTrue);
        expect(acc.color, isNotNull);
      }

      expect(ActionBadge.values.length, equals(5));
      for (final badge in ActionBadge.values) {
        expect(badge.displayName.isNotEmpty, isTrue);
        expect(badge.color, isNotNull);
      }
    });

    test('GlyphGeometry generates valid non-empty paths for all frame shapes', () {
      const size = Size(48.0, 48.0);
      for (final shape in GlyphFrameShape.values) {
        final path = GlyphGeometry.getContainerPath(shape, size);
        final bounds = path.getBounds();
        expect(bounds.width, greaterThan(10.0));
        expect(bounds.height, greaterThan(10.0));
      }
    });

    testWidgets('DndGlyph.spell renders correctly across tiers and damage accents', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DndGlyph.spell(school: SpellSchool.abjuration, level: 0, size: 32),
                DndGlyph.spell(school: SpellSchool.evocation, level: 3, damageAccent: DamageAccent.fire, size: 48),
                DndGlyph.spell(school: SpellSchool.necromancy, level: 5, size: 64),
                DndGlyph.spell(school: SpellSchool.divination, level: 9, damageAccent: DamageAccent.radiant, size: 96),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsNWidgets(4));
    });

    testWidgets('DndGlyph renders multi-ring action traits with damage coloring', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DndGlyph.monster(
                  creatureType: CreatureType.elemental,
                  crTier: 2,
                  actionRings: const [
                    ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.cold),
                    ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.cold),
                  ],
                  size: 64,
                ),
                DndGlyph.spell(
                  school: SpellSchool.transmutation,
                  level: 5,
                  actionRings: const [
                    ActionTraitRing(ringType: ActionRingType.concentration, damageType: DamageAccent.force),
                    ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.force),
                  ],
                  size: 64,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsNWidgets(2));
    });

    testWidgets('GlyphShowcaseScreen renders known spells, minions, custom builder, and full style guide', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GlyphShowcaseScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('D&D Glyph Studio & Codex'), findsOneWidget);
      expect(find.text('Spellbook Schematics'), findsOneWidget);
      expect(find.text('Minion & Summon Matrix'), findsOneWidget);
      expect(find.text('Custom Glyph Studio'), findsOneWidget);
      expect(find.text('Full Style Guide Codex'), findsOneWidget);

      // Verify known spells in toolkit are rendered
      expect(find.text('Animate Objects'), findsOneWidget);
      expect(find.text('Conjure Animals'), findsOneWidget);
      expect(find.text('Animate Dead'), findsOneWidget);

      // Switch to Minion & Summon Matrix tab
      await tester.tap(find.text('Minion & Summon Matrix'));
      await tester.pumpAndSettle();
      expect(find.text('Tiny Animated Object'), findsOneWidget);
      expect(find.text('Small Animated Object'), findsOneWidget);

      // Switch to Custom Glyph Studio tab
      await tester.tap(find.text('Custom Glyph Studio'));
      await tester.pumpAndSettle();
      expect(find.text('Interactive Custom Glyph Studio'), findsOneWidget);
      expect(find.text('Select Arcane Spell School:'), findsOneWidget);

      // Switch to Full Style Guide Codex tab
      await tester.tap(find.text('Full Style Guide Codex'));
      await tester.pumpAndSettle();
      expect(find.text('D&D App Glyph System: Techno-Wireframe HUD & Arcane Codex'), findsOneWidget);
      expect(find.text('1. The 8 Arcane Schools of Magic'), findsOneWidget);
    });
  });
}
