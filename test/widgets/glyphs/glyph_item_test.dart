import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_tokens.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/glyph_gallery_data.dart';

void main() {
  group('5e Item Glyph System Tests', () {
    test('All 10 ItemCategories and 7 ItemRarities have valid colors and frame shapes', () {
      expect(ItemCategory.values.length, equals(10));
      expect(ItemRarity.values.length, equals(7));

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

    test('GlyphGalleryData.allItems contains items for all 10 categories', () {
      expect(GlyphGalleryData.allItems.isNotEmpty, isTrue);
      final categoriesFound =
          GlyphGalleryData.allItems.map((i) => i.category).toSet();
      for (final cat in ItemCategory.values) {
        expect(categoriesFound.contains(cat), isTrue,
            reason: 'Missing item entry for category $cat');
      }
    });

    testWidgets('DndGlyph.item renders correctly across all 10 item categories',
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

    testWidgets('DndGlyph.item renders with custom explicit glyphColor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DndGlyph.item(
                category: ItemCategory.wondrousItem,
                rarity: ItemRarity.uncommon,
                glyphColor: const Color(0xFFC2410C), // Rust
                size: 80,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsOneWidget);
    });

    testWidgets('DndGlyph.item responds to focus state and enables active animations',
        (WidgetTester tester) async {
      final focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Focus(
                focusNode: focusNode,
                child: DndGlyph.item(
                  category: ItemCategory.weapon,
                  rarity: ItemRarity.rare,
                  requiresAttunement: true,
                  actionRings: const [
                    ActionTraitRing(
                      ringType: ActionRingType.melee,
                      damageType: DamageAccent.fire,
                    ),
                  ],
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsOneWidget);

      // Request focus
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(focusNode.hasFocus, isTrue);
      expect(find.byType(DndGlyph), findsOneWidget);

      focusNode.unfocus();
      await tester.pump();
      focusNode.dispose();
    });

    testWidgets('DndGlyph.item renders with isActive: true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DndGlyph.item(
                category: ItemCategory.staff,
                rarity: ItemRarity.veryRare,
                requiresAttunement: true,
                isActive: true,
                size: 64,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DndGlyph), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DndGlyph), findsOneWidget);
    });

    test('GlyphThemeData.fromItem applies primaryColorOverride', () {
      const customColor = Color(0xFFC2410C);
      final theme = GlyphThemeData.fromItem(
        ItemCategory.wondrousItem,
        primaryColorOverride: customColor,
      );

      expect(theme.primary, equals(customColor));
      expect(theme.border, equals(customColor));
    });
  });
}
