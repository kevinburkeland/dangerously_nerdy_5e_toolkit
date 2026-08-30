import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_sheet_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CharacterSheetView Widget Tests', () {
    late Character baseCharacter;
    late CharacterSheetController controller;

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      baseCharacter = Character(
        id: const EntityId(slug: 'hero-test', ruleset: RulesetVersion.v2024),
        name: 'Valerius',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: const EntityReference<DomainEntity>(
          refType: EntityType.background,
          slug: 'soldier',
          displayName: 'Soldier',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 16, // Mod +3
          dexterity: 14, // Mod +2
          constitution: 14, // Mod +2
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        inventory: const [
          InventoryItemInstance(
            instanceId: 'plate-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'plate-armor',
              displayName: 'Plate Armor',
            ),
            isEquipped: false,
            equippedSlot: EquipmentSlot.armor,
            customProperties: {
              'baseAc': 18,
              'armorType': 'heavy',
            },
          ),
          InventoryItemInstance(
            instanceId: 'ring-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'ring-prot',
              displayName: 'Ring of Protection',
            ),
            isEquipped: true,
            isAttuned: false,
            requiresAttunement: true,
            customProperties: {
              'acBonus': 1,
            },
          ),
        ],
        resources: const CharacterResourcePool(
          currentHp: 28,
          tempHp: 0,
          currentHitDice: {'d10': 3},
        ),
      );

      controller = CharacterSheetController(character: baseCharacter);
    });

    testWidgets('Renders character name, class level, vital HUD cards, and ability ribbon', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterSheetView(controller: controller),
        ),
      );
      await tester.pump();

      expect(find.text('Valerius'), findsWidgets);
      expect(find.text('Level 3'), findsOneWidget);
      expect(find.text('ARMOR CLASS'), findsOneWidget);
      expect(find.text('INITIATIVE'), findsOneWidget);
      expect(find.text('SPEED'), findsOneWidget);
      expect(find.text('HIT POINTS'), findsOneWidget);
      expect(find.text('STR'), findsOneWidget);
      expect(find.text('DEX'), findsOneWidget);
      expect(find.text('CON'), findsOneWidget);
    });

    testWidgets('Toggling Equip on Plate Armor immediately updates AC to 18', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterSheetView(controller: controller),
        ),
      );
      await tester.pump();

      // Initial unarmored AC: 10 + DEX(2) = 12
      expect(controller.stats.armorClass, equals(12));
      expect(find.text('12'), findsWidgets);

      // Switch to Inventory Tab
      final inventoryTab = find.byWidgetPredicate((w) => w is Tab && w.text == 'Inventory');
      expect(inventoryTab, findsOneWidget);
      await tester.tap(inventoryTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // Tap Equip on Plate Armor
      final equipButton = find.text('Equip');
      expect(equipButton, findsWidgets);
      await tester.tap(equipButton.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Check controller and UI AC
      expect(controller.stats.armorClass, equals(18));
      expect(find.text('18'), findsWidgets);
    });

    testWidgets('Toggling Inspiration updates state reactively', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterSheetView(controller: controller),
        ),
      );
      await tester.pump();

      expect(controller.hasInspiration, isFalse);

      final inspirationChip = find.text('Inspiration');
      expect(inspirationChip, findsOneWidget);

      await tester.tap(inspirationChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.hasInspiration, isTrue);
    });

    testWidgets('Attuning to item updates Attuned Slots count in Inventory tab', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: CharacterSheetView(controller: controller),
        ),
      );
      await tester.pump();

      // Switch to Inventory Tab
      final inventoryTab = find.byWidgetPredicate((w) => w is Tab && w.text == 'Inventory');
      await tester.tap(inventoryTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('0 / 3 Attuned'), findsOneWidget);

      // Tap Attune
      final attuneButton = find.text('Attune');
      expect(attuneButton, findsOneWidget);

      await tester.tap(attuneButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('1 / 3 Attuned'), findsOneWidget);
      expect(controller.stats.attunedItemCount, equals(1));
    });
  });
}
