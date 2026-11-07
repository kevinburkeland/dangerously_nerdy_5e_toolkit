import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/dice_room_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/character_sheet_tabs.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';

import '../../test_doubles/hive_test_harness.dart';
import '../../test_doubles/service_test_configurator.dart';

final _testReplica = ReplicaId('test_runner_replica');

/// Pinned literal expected records for combat action buttons.
const expectedFighterActions = [
  (
    name: 'Longsword',
    buttons: ['Atk', 'Damage'],
    attack: (label: 'Longsword Attack', formula: '1d20+6'),
    damage: (label: 'Longsword Damage', formula: '1d8 + 3'),
    use: null,
  ),
  (
    name: 'Unarmed Strike',
    buttons: ['Atk', 'Damage'],
    attack: (label: 'Unarmed Strike Attack', formula: '1d20+6'),
    damage: (label: 'Unarmed Strike Damage', formula: '4'),
    use: null,
  ),
  (
    name: 'Second Wind',
    buttons: ['Use Action'],
    attack: null,
    damage: null,
    use: (label: 'Second Wind Healing', formula: '1d10+5'),
  ),
  (
    name: 'Opportunity Attack',
    buttons: ['Atk'],
    attack: (label: 'Opportunity Attack (Longsword)', formula: '1d20+6'),
    damage: null,
    use: null,
  ),
  (
    name: 'Hide',
    buttons: ['Use Action'],
    attack: null,
    damage: null,
    use: (label: 'Dexterity (Stealth) Check', formula: '1d20+2'),
  ),
  (
    name: 'Search',
    buttons: ['Use Action'],
    attack: null,
    damage: null,
    use: (label: 'Wisdom (Perception) Check', formula: '1d20+1'),
  ),
];

const expectedBardActions = [
  (
    name: 'Bardic Inspiration',
    buttons: ['Use Action'],
    use: (label: 'Bardic Inspiration Die', formula: '1d8'),
  ),
];

const expectedWarlockActions = [
  (
    name: 'Pact Keeper: Regain Spell Slot',
    buttons: ['Use Action'],
    slotsBefore: 1,
    slotsAfter: 2,
    snackBarText: 'Rod of the Pact Keeper: Restored 1 Warlock spell slot!',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final harness = HiveTestHarness();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await harness.setUpInMemory();
  });

  tearDown(() async {
    resetTestServices();
    await harness.tearDown();
  });

  group('Combat Action Buttons Characterization (Fix 3.1)', () {
    testWidgets(
        'Fighter 5 with longsword pins attack, damage, and use buttons with formulas',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recordingTransport = NoOpP2pTransportPort();
      configureTestDiceRoomService(transport: recordingTransport);
      DiceRoomService().activeSessionNotifier.value = RoomSession(
        roomCode: 'ACTION-ROOM',
        playerName: 'Fighter Hero',
        isRemembered: false,
      );

      final fighter = Character(
        id: const EntityId(slug: 'fighter-5', ruleset: RulesetVersion.v2024),
        name: 'Fighter Hero',
        speciesRef: const EntityReference.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference.empty(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 5,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 8,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'longsword-1',
            itemRef: const EntityReference<EquipmentItem>.empty(
              refType: EntityType.equipment,
              slug: 'longsword',
              displayName: 'Longsword',
            ),
            equippedSlot: EquipmentSlot.mainHand,
            isEquipped: true,
            customProperties: {
              'isWeapon': true,
              'damageFormula': '1d8',
              'damageType': 'slashing',
            },
          ),
        ],
        resources: const CharacterResourcePool(),
      );

      final controller =
          CharacterSheetController(replicaId: _testReplica, character: fighter);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterSheetTabs(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vert = find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            (w.axisDirection == AxisDirection.down ||
                w.axisDirection == AxisDirection.up),
      ).first;

      for (final expected in expectedFighterActions) {
        final nameFinder = find.text(expected.name);
        await tester.scrollUntilVisible(nameFinder, 200, scrollable: vert);
        await tester.pumpAndSettle();
        expect(nameFinder, findsOneWidget);

        final cardFinder = find.ancestor(
          of: nameFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(12),
          ),
        ).first;

        final atkBtn = find.descendant(
          of: cardFinder,
          matching: find.ancestor(
            of: find.byIcon(Icons.sports_martial_arts),
            matching: find.byType(ElevatedButton),
          ),
        );
        final dmgBtn = find.descendant(
          of: cardFinder,
          matching: find.ancestor(
            of: find.byIcon(Icons.local_fire_department),
            matching: find.byType(ElevatedButton),
          ),
        );
        final useBtn = find.descendant(
          of: cardFinder,
          matching: find.ancestor(
            of: find.byIcon(Icons.play_arrow),
            matching: find.byType(ElevatedButton),
          ),
        );

        final actualButtons = <String>[];
        if (atkBtn.evaluate().isNotEmpty) actualButtons.add('Atk');
        if (dmgBtn.evaluate().isNotEmpty) actualButtons.add('Damage');
        if (useBtn.evaluate().isNotEmpty) actualButtons.add('Use Action');

        expect(actualButtons, equals(expected.buttons));

        if (expected.attack != null) {
          await tester.tap(atkBtn);
          await tester.pumpAndSettle();
          final roll = DiceRoomService().getCachedRolls('ACTION-ROOM').first;
          expect(roll.details?.first, equals(expected.attack!.label));
          expect(roll.formulaString, equals(expected.attack!.formula));
        }

        if (expected.damage != null) {
          await tester.tap(dmgBtn);
          await tester.pumpAndSettle();
          final roll = DiceRoomService().getCachedRolls('ACTION-ROOM').first;
          expect(roll.details?.first, equals(expected.damage!.label));
          expect(roll.formulaString, equals(expected.damage!.formula));
        }

        if (expected.use != null) {
          await tester.tap(useBtn);
          await tester.pumpAndSettle();
          final roll = DiceRoomService().getCachedRolls('ACTION-ROOM').first;
          expect(roll.details?.first, equals(expected.use!.label));
          expect(roll.formulaString, equals(expected.use!.formula));
        }
      }
    });

    testWidgets(
        'Bard 5 pins Bardic Inspiration use button with 1d8 die formula',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recordingTransport = NoOpP2pTransportPort();
      configureTestDiceRoomService(transport: recordingTransport);
      DiceRoomService().activeSessionNotifier.value = RoomSession(
        roomCode: 'ACTION-ROOM',
        playerName: 'Bard Hero',
        isRemembered: false,
      );

      const bard = Character(
        id: EntityId(slug: 'bard-5', ruleset: RulesetVersion.v2024),
        name: 'Bard Hero',
        speciesRef: EntityReference.empty(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference.empty(
                refType: EntityType.classDefinition,
                slug: 'bard',
                displayName: 'Bard',
              ),
              level: 5,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 12,
          intelligence: 12,
          wisdom: 10,
          charisma: 16,
        ),
        resources: CharacterResourcePool(),
      );

      final controller =
          CharacterSheetController(replicaId: _testReplica, character: bard);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterSheetTabs(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vert = find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            (w.axisDirection == AxisDirection.down ||
                w.axisDirection == AxisDirection.up),
      ).first;

      for (final expected in expectedBardActions) {
        final nameFinder = find.text(expected.name);
        await tester.scrollUntilVisible(nameFinder, 200, scrollable: vert);
        await tester.pumpAndSettle();
        expect(nameFinder, findsOneWidget);

        final cardFinder = find.ancestor(
          of: nameFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(12),
          ),
        ).first;

        final useBtn = find.descendant(
          of: cardFinder,
          matching: find.ancestor(
            of: find.byIcon(Icons.play_arrow),
            matching: find.byType(ElevatedButton),
          ),
        );

        final actualButtons = <String>[];
        if (useBtn.evaluate().isNotEmpty) actualButtons.add('Use Action');
        expect(actualButtons, equals(expected.buttons));

        await tester.tap(useBtn);
        await tester.pumpAndSettle();
        final roll = DiceRoomService().getCachedRolls('ACTION-ROOM').first;
        expect(roll.details?.first, equals(expected.use.label));
        expect(roll.formulaString, equals(expected.use.formula));
      }
    });

    testWidgets(
        'Warlock 5 pins Rod of the Pact Keeper spell slot recovery and SnackBar text',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final recordingTransport = NoOpP2pTransportPort();
      configureTestDiceRoomService(transport: recordingTransport);
      DiceRoomService().activeSessionNotifier.value = RoomSession(
        roomCode: 'ACTION-ROOM',
        playerName: 'Warlock Hero',
        isRemembered: false,
      );

      final warlock = Character(
        id: const EntityId(slug: 'warlock-5', ruleset: RulesetVersion.v2024),
        name: 'Warlock Hero',
        speciesRef: const EntityReference.empty(
          refType: EntityType.species,
          slug: 'tiefling',
          displayName: 'Tiefling',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference.empty(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 5,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 16,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'rod-pact-1',
            itemRef: const EntityReference<EquipmentItem>.empty(
              refType: EntityType.equipment,
              slug: 'item-rod-of-the-pact-keeper-plus-1',
              displayName: 'Rod of the Pact Keeper +1',
            ),
            isEquipped: true,
            isAttuned: true,
            requiresAttunement: true,
          ),
        ],
        resources: const CharacterResourcePool(
          spellSlots: SpellSlotPool(
            pactMagicMax: 2,
            pactMagicCurrent: 1,
          ),
        ),
      );

      final controller =
          CharacterSheetController(replicaId: _testReplica, character: warlock);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CharacterSheetTabs(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vert = find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            (w.axisDirection == AxisDirection.down ||
                w.axisDirection == AxisDirection.up),
      ).first;

      for (final expected in expectedWarlockActions) {
        final nameFinder = find.text(expected.name);
        await tester.scrollUntilVisible(nameFinder, 200, scrollable: vert);
        await tester.pumpAndSettle();
        expect(nameFinder, findsOneWidget);

        final cardFinder = find.ancestor(
          of: nameFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).borderRadius ==
                    BorderRadius.circular(12),
          ),
        ).first;

        final useBtn = find.descendant(
          of: cardFinder,
          matching: find.ancestor(
            of: find.byIcon(Icons.play_arrow),
            matching: find.byType(ElevatedButton),
          ),
        );

        final actualButtons = <String>[];
        if (useBtn.evaluate().isNotEmpty) actualButtons.add('Use Action');
        expect(actualButtons, equals(expected.buttons));

        expect(controller.character.resources.spellSlots.pactMagicCurrent,
            equals(expected.slotsBefore));

        await tester.tap(useBtn);
        await tester.pumpAndSettle();

        expect(controller.character.resources.spellSlots.pactMagicCurrent,
            equals(expected.slotsAfter));

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);
        expect(find.text(expected.snackBarText), findsOneWidget);
      }
    });
  });
}
