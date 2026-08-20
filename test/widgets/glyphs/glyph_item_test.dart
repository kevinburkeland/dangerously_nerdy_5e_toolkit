import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_tokens.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_geometry.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/glyph_gallery_data.dart';

void main() {
  group('5e Item Glyph System Tests', () {
    test('All 9 ItemCategories and 6 ItemRarities have valid colors and frame shapes', () {
      expect(ItemCategory.values.length, equals(9));
      expect(ItemRarity.values.length, equals(6));

      for (final cat in ItemCategory.values) {
        expect(cat.displayName.isNotEmpty, isTrue);
        expect(cat.primaryColor.a, equals(1.0));
        expect(cat.lightFillTint.a, equals(1.0));
        expect(cat.darkFillTint.a, equals(1.0));
        expect(cat.getLegibleColor(true).a, equals(1.0));
        expect(cat.getLegibleColor(false).a, equals(1.0));
        expect(cat.icon, isNotNull);
      }

      for (final rar in ItemRarity.values) {
        expect(rar.displayName.isNotEmpty, isTrue);
        expect(rar.color.a, equals(1.0));
        expect(rar.getLegibleColor(true).a, equals(1.0));
        expect(rar.getLegibleColor(false).a, equals(1.0));
        expect(rar.tierLevel, inInclusiveRange(0, 5));
      }
    });

    test('GlyphThemeData.fromItem correctly assigns primary colors and frame shapes', () {
      final themeWeapon = GlyphThemeData.fromItem(ItemCategory.weapon);
      expect(themeWeapon.frameShape, equals(GlyphFrameShape.sharpDiamondShield));
      expect(themeWeapon.primary, equals(ItemCategory.weapon.primaryColor));

      // With rarity override
      final themeRareWeapon = GlyphThemeData.fromItem(
        ItemCategory.weapon,
        rarity: ItemRarity.rare,
      );
      expect(themeRareWeapon.primary, equals(ItemRarity.rare.color));
      expect(themeRareWeapon.frameShape, equals(GlyphFrameShape.sharpDiamondShield));

      // With shape override
      final themeCustom = GlyphThemeData.fromItem(
        ItemCategory.armor,
        shapeOverride: GlyphFrameShape.circle,
      );
      expect(themeCustom.frameShape, equals(GlyphFrameShape.circle));
    });

    test('ActionRingType.attunement has valid colors and geometry', () {
      const ring = ActionTraitRing(ringType: ActionRingType.attunement);
      expect(ring.getEffectiveColor(Colors.white, isDarkMode: true), isNotNull);
      expect(ring.getEffectiveColor(Colors.white, isDarkMode: false), isNotNull);
    });

    test('GlyphGalleryData.allItems contains items for all 9 categories', () {
      expect(GlyphGalleryData.allItems.isNotEmpty, isTrue);
      final categoriesFound =
          GlyphGalleryData.allItems.map((i) => i.category).toSet();
      for (final cat in ItemCategory.values) {
        expect(categoriesFound.contains(cat), isTrue,
            reason: 'Missing item entry for category $cat');
      }
    });

    testWidgets('DndGlyph.item renders correctly across all 9 item categories',
        (WidgetTester tester) async {
      for (final cat in ItemCategory.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: DndGlyph.item(
                  category: cat,
                  rarity: ItemRarity.veryRare,
                  requiresAttunement: true,
                  size: 64,
                ),
              ),
            ),
          ),
        );
        expect(find.byType(DndGlyph), findsOneWidget);
      }
    });

    testWidgets('DndGlyph.item renders with damage accents and action trait rings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DndGlyph.item(
                category: ItemCategory.weapon,
                rarity: ItemRarity.rare,
                requiresAttunement: true,
                damageAccent: DamageAccent.fire,
                actionRings: const [
                  ActionTraitRing(
                    ringType: ActionRingType.melee,
                    damageType: DamageAccent.fire,
                    label: '+2d6 Fire',
                  ),
                ],
                size: 80,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsOneWidget);
    });
  });
}
