import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_tokens.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/glyph_geometry.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/glyph_showcase_screen.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';

void main() {
  group('D&D Glyph System Tests', () {
    test('All 8 SpellSchools define complete color tokens and container shapes',
        () {
      expect(SpellSchool.values.length, equals(8));
      for (final school in SpellSchool.values) {
        expect(school.displayName.isNotEmpty, isTrue);
        expect(school.primaryColor, isNotNull);
        expect(school.lightFillTint, isNotNull);
        expect(school.darkFillTint, isNotNull);
        expect(school.frameShape, isNotNull);
      }
    });

    test(
        'All 14 CreatureTypes define complete color tokens and container shapes',
        () {
      expect(CreatureType.values.length, equals(14));
      for (final type in CreatureType.values) {
        expect(type.displayName.isNotEmpty, isTrue);
        expect(type.primaryColor, isNotNull);
        expect(type.lightFillTint, isNotNull);
        expect(type.darkFillTint, isNotNull);
        expect(type.frameShape, isNotNull);
      }
    });

    test('All 14 DamageAccents and 5 ActionBadges have valid colors', () {
      expect(DamageAccent.values.length, equals(14));
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

    test('GlyphGeometry generates valid non-empty paths for all frame shapes',
        () {
      const size = Size(48.0, 48.0);
      for (final shape in GlyphFrameShape.values) {
        final path = GlyphGeometry.getContainerPath(shape, size);
        final bounds = path.getBounds();
        expect(bounds.width, greaterThan(10.0));
        expect(bounds.height, greaterThan(10.0));
      }
    });

    testWidgets(
        'DndGlyph.spell renders correctly across tiers and damage accents',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DndGlyph.spell(
                    school: SpellSchool.abjuration, level: 0, size: 32),
                DndGlyph.spell(
                    school: SpellSchool.evocation,
                    level: 3,
                    damageAccent: DamageAccent.fire,
                    size: 48),
                DndGlyph.spell(
                    school: SpellSchool.necromancy, level: 5, size: 64),
                DndGlyph.spell(
                    school: SpellSchool.divination,
                    level: 9,
                    damageAccent: DamageAccent.radiant,
                    size: 96),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsNWidgets(4));
    });

    test(
        'Concentration ActionTraitRing is strictly non-elemental and has orbital cyan color',
        () {
      const concRingWithoutDamage =
          ActionTraitRing(ringType: ActionRingType.concentration);
      const concRingWithAccidentalDamage = ActionTraitRing(
        ringType: ActionRingType.concentration,
        damageType: DamageAccent.fire,
      );

      // In dark mode
      expect(
        concRingWithoutDamage.getEffectiveColor(Colors.grey, isDarkMode: true),
        equals(const Color(0xFF38BDF8)),
      );
      expect(
        concRingWithAccidentalDamage.getEffectiveColor(Colors.grey,
            isDarkMode: true),
        equals(const Color(0xFF38BDF8)),
      );

      // In light mode
      expect(
        concRingWithoutDamage.getEffectiveColor(Colors.grey, isDarkMode: false),
        equals(const Color(0xFF0284C7)),
      );
      expect(
        concRingWithAccidentalDamage.getEffectiveColor(Colors.grey,
            isDarkMode: false),
        equals(const Color(0xFF0284C7)),
      );
    });

    test('Multi-damage ActionTraitRing cycles through configured damage colors',
        () {
      const ring = ActionTraitRing(
        ringType: ActionRingType.recharge,
        damageType: DamageAccent.radiant,
        damageTypes: [DamageAccent.necrotic],
      );

      final colorAtStart =
          ring.getAnimatedColor(Colors.grey, isDarkMode: true, phase: 0.0);
      final colorHalfCycle =
          ring.getAnimatedColor(Colors.grey, isDarkMode: true, phase: 0.5);

      expect(colorAtStart, equals(DamageAccent.radiant.color));
      expect(colorHalfCycle, equals(DamageAccent.necrotic.color));
      expect(ring.damageLegend, 'Radiant / Necrotic');
    });

    testWidgets(
        'DndGlyph renders multi-ring action traits with damage coloring and arbitrary ring counts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                DndGlyph.monster(
                  creatureType: CreatureType.elemental,
                  crTier: 2,
                  actionRings: const [
                    ActionTraitRing(
                        ringType: ActionRingType.melee,
                        damageType: DamageAccent.cold),
                    ActionTraitRing(
                        ringType: ActionRingType.recharge,
                        damageType: DamageAccent.cold),
                  ],
                  size: 64,
                ),
                DndGlyph.spell(
                  school: SpellSchool.transmutation,
                  level: 5,
                  actionRings: const [
                    ActionTraitRing(ringType: ActionRingType.concentration),
                    ActionTraitRing(
                        ringType: ActionRingType.melee,
                        damageType: DamageAccent.force),
                  ],
                  size: 64,
                ),
                // 5 Concentric rings (arbitrary ring count support)
                DndGlyph.monster(
                  creatureType: CreatureType.dragon,
                  crTier: 4,
                  actionRings: const [
                    ActionTraitRing(
                        ringType: ActionRingType.legendary,
                        damageType: DamageAccent.fire),
                    ActionTraitRing(
                        ringType: ActionRingType.recharge,
                        damageType: DamageAccent.fire),
                    ActionTraitRing(
                        ringType: ActionRingType.melee,
                        damageType: DamageAccent.physical),
                    ActionTraitRing(ringType: ActionRingType.reaction),
                    ActionTraitRing(ringType: ActionRingType.concentration),
                  ],
                  size: 88,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DndGlyph), findsNWidgets(3));
    });

    testWidgets(
        'GlyphShowcaseScreen renders known spells, minions, custom builder, and full style guide',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: GlyphShowcaseScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('D&D Glyph Studio & Codex'), findsOneWidget);
      expect(find.text('Spellbook Schematics'), findsOneWidget);
      expect(find.text('Minion & Summon Matrix'), findsOneWidget);
      // Magic Item Reliquary tab was promoted to a standalone core tool (ItemCompendiumScreen)
      expect(find.text('Magic Item Reliquary'), findsNothing);
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
      final studioTab = find.text('Custom Glyph Studio');
      await tester.ensureVisible(studioTab);
      await tester.tap(studioTab);
      await tester.pumpAndSettle();
      expect(find.text('Interactive Custom Glyph Studio'), findsOneWidget);
      expect(find.text('Select Arcane Spell School:'), findsOneWidget);

      // Verify shape override chip selection works
      final octChip = find.widgetWithText(ChoiceChip, 'Psionic Octagon');
      expect(octChip, findsOneWidget);
      await tester.ensureVisible(octChip);
      await tester.tap(octChip);
      await tester.pumpAndSettle();

      // Verify Dart Code Preview and Copy Button
      final copyBtn = find.widgetWithText(ElevatedButton, 'Copy Dart Code');
      expect(copyBtn, findsOneWidget);
      await tester.ensureVisible(copyBtn);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();
      expect(find.text('Generated Dart Widget Code:'), findsOneWidget);
      expect(find.text('Copied complete DndGlyph Dart code to clipboard!'),
          findsOneWidget);

      // Switch to Full Style Guide Codex tab
      final codexTab = find.text('Full Style Guide Codex');
      await tester.ensureVisible(codexTab);
      await tester.tap(codexTab);
      await tester.pumpAndSettle();
      expect(
          find.text(
              'D&D App Glyph System: Techno-Wireframe HUD & Arcane Codex'),
          findsOneWidget);
      expect(find.text('1. The 8 Arcane Schools of Magic'), findsOneWidget);
      expect(find.text('3. The 9 Magic Item & Equipment Categories'),
          findsOneWidget);
      expect(find.text('4. The 6 Standard 5e Item Rarities'), findsOneWidget);
      expect(find.text('5. The 4 Progression Tiers & Threat Architecture'),
          findsOneWidget);
      expect(find.text('Tier 1 • Initiate / CR 0–4'), findsOneWidget);
      expect(find.text('8. Species & Heritage Sigils (2024 SRD)'), findsOneWidget);

      // Toggle to 2014 edition via RulesEditionToggle in AppBar
      final toggle2014 = find.text('2014');
      expect(toggle2014, findsWidgets);
      await tester.tap(toggle2014.first);
      await tester.pumpAndSettle();

      expect(find.text('8. Races & Heritage Sigils (2014 SRD)'), findsOneWidget);
      expect(find.text('Races & Heritages'), findsOneWidget);
    });

    testWidgets('DndGlyph applies frameShapeOverride properly',
        (WidgetTester tester) async {
      final spellGlyph = DndGlyph.spell(
        school: SpellSchool.evocation,
        frameShapeOverride: GlyphFrameShape.octagon,
      );
      expect(spellGlyph.themeData.frameShape, equals(GlyphFrameShape.octagon));

      final monsterGlyph = DndGlyph.monster(
        creatureType: CreatureType.dragon,
        frameShapeOverride: GlyphFrameShape.tombstone,
      );
      expect(
          monsterGlyph.themeData.frameShape, equals(GlyphFrameShape.tombstone));
    });

    test('SummonPresetGlyphExt correctly dynamically reads all spell cards',
        () {
      for (final preset in SrdSummonsLibrary.allPresets) {
        expect(preset.glyphSchool, isNotNull);
        expect(preset.glyphSpellLevel, inInclusiveRange(0, 9));
        expect(preset.glyphActionRings, isNotNull);
      }

      // Concentration spell check
      expect(
        BeastSummons.conjureAnimalsPreset.glyphActionRings.any(
          (r) => r.ringType == ActionRingType.concentration,
        ),
        isTrue,
      );
      expect(
        ElementalSummons.conjureElementalPreset.glyphActionRings.any(
          (r) => r.ringType == ActionRingType.concentration,
        ),
        isTrue,
      );
    });

    test(
        'MinionStatBlockGlyphExt correctly dynamically reads creature stat blocks with damage types',
        () {
      // Beast
      expect(
          SrdSummonsLibrary.wolf.glyphCreatureType, equals(CreatureType.beast));
      expect(SrdSummonsLibrary.wolf.glyphCrTier, equals(1));
      expect(SrdSummonsLibrary.wolf.glyphActionRings.first.ringType,
          equals(ActionRingType.melee));

      // Construct
      expect(SrdSummonsLibrary.tinyObject.glyphCreatureType,
          equals(CreatureType.construct));
      expect(SrdSummonsLibrary.tinyObject.glyphCrTier, equals(1));

      // Undead
      expect(SrdSummonsLibrary.skeleton.glyphCreatureType,
          equals(CreatureType.undead));
      expect(
        SrdSummonsLibrary.skeleton.glyphActionRings
            .any((r) => r.ringType == ActionRingType.ranged),
        isTrue,
      );

      // Elemental
      expect(ElementalSummons.fireElemental.glyphCreatureType,
          equals(CreatureType.elemental));
      expect(ElementalSummons.fireElemental.glyphCrTier,
          equals(2)); // CR 5 -> Tier 2
      expect(
        ElementalSummons.fireElemental.glyphActionRings.any(
          (r) => r.damageType == DamageAccent.fire,
        ),
        isTrue,
      );
    });

    testWidgets('DndGlyph handles repeated sequential mouse hover enter and exit cycles without freezing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DndGlyph.monster(
                creatureType: CreatureType.dragon,
                actionRings: const [ActionTraitRing(ringType: ActionRingType.recharge)],
                size: 64,
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();

      final glyphFinder = find.byType(DndGlyph);
      expect(glyphFinder, findsOneWidget);
      final center = tester.getCenter(glyphFinder);

      // Cycle 1: Hover in -> Hover out
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 100));

      // Cycle 2: Hover in again immediately (verifying no early exit while settling)
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 100));

      // Cycle 3: Third hover in
      await gesture.moveTo(center);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 100));

      expect(glyphFinder, findsOneWidget);
    });
  });
}
