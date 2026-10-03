import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart'
    show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/inventory_transaction_service.dart';

void main() {
  group('Plate Armor +3 and Armor Classification Tests', () {
    test(
        'InventoryTransactionService.resolveDefaultSlot correctly classifies Plate Armor +3 as armor',
        () {
      final plateItem = InventoryItemInstance(
        instanceId: 'plate-1',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'plate-plus-3',
          displayName: 'Plate Armor +3',
        ),
      );

      final slot = InventoryTransactionService.resolveDefaultSlot(plateItem);
      expect(slot, equals(EquipmentSlot.armor));
    });

    test(
        'InventoryTransactionService.resolveDefaultSlot classifies weapons, shields, and rings properly',
        () {
      final shield = InventoryItemInstance(
        instanceId: 'shield-1',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'shield-plus-1',
          displayName: 'Shield +1',
        ),
      );
      expect(InventoryTransactionService.resolveDefaultSlot(shield),
          equals(EquipmentSlot.shield));

      final sword = InventoryItemInstance(
        instanceId: 'sword-1',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'longsword',
          displayName: 'Longsword +1',
        ),
      );
      expect(InventoryTransactionService.resolveDefaultSlot(sword),
          equals(EquipmentSlot.mainHand));

      final greatsword = InventoryItemInstance(
        instanceId: 'gs-1',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'greatsword',
          displayName: 'Greatsword',
        ),
      );
      expect(InventoryTransactionService.resolveDefaultSlot(greatsword),
          equals(EquipmentSlot.twoHand));

      final ring = InventoryItemInstance(
        instanceId: 'ring-1',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'ring-of-protection',
          displayName: 'Ring of Protection',
        ),
      );
      expect(InventoryTransactionService.resolveDefaultSlot(ring),
          equals(EquipmentSlot.ring1));
    });

    test(
        'SrdEquipmentLibrary maps Plate Armor +3 with base AC 18, heavy armor, and +3 AC bonus',
        () {
      final allItems = SrdEquipmentLibrary.allEquipmentItems;
      final platePlus3 = allItems.firstWhere((i) => i.name == 'Plate Armor +3');

      expect(platePlus3.customProperties['baseAc'], equals(18));
      expect(platePlus3.customProperties['armorType'], equals('heavy'));
      expect(platePlus3.customProperties['acBonus'], equals(3));
      expect(platePlus3.customProperties['defaultSlot'],
          equals(EquipmentSlot.armor));
    });

    test(
        'Equipping Plate Armor +3 calculates AC 21 and does NOT generate a weapon attack profile',
        () {
      final baseCharacter = Character(
        id: const EntityId(slug: 'test-knight', ruleset: RulesetVersion.v2024),
        name: 'Sir Galahad',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 5,
              hitDie: 'd10',
            ),
          ],
        ),
        rulesEdition: DmRulesEdition.v2024,
        resources: const CharacterResourcePool(currentHp: 10),
        baseScores: const AbilityScores(
          strength: 16,
          dexterity: 14,
          constitution: 14,
          intelligence: 10,
          wisdom: 12,
          charisma: 10,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'plate-plus-3-inst',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'plate-plus-3',
              displayName: 'Plate Armor +3',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
            customProperties: {
              'baseAc': 18,
              'armorType': 'heavy',
              'acBonus': 3,
            },
          ),
        ],
      );

      final stats = CharacterEvaluationEngine.evaluate(baseCharacter);

      // Plate (18) + Magic (+3) = 21, DEX bonus ignored for heavy armor
      expect(stats.armorClass, equals(21));
      expect(stats.armorClassBreakdown, contains('18 (Plate Armor +3)'));
      expect(stats.armorClassBreakdown, contains('+3 (Plate Armor +3)'));

      // Must not generate any attack profile for Plate Armor
      expect(stats.attackProfiles.where((a) => a.weaponName.contains('Plate')),
          isEmpty);
    });

    test(
        'Plate Armor +3 without explicit customProperties still resolves standard armor base AC 18 and +3 bonus',
        () {
      final baseCharacter = Character(
        id: const EntityId(slug: 'test-knight-2', ruleset: RulesetVersion.v2024),
        name: 'Sir Lancelot',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 5,
              hitDie: 'd10',
            ),
          ],
        ),
        rulesEdition: DmRulesEdition.v2024,
        resources: const CharacterResourcePool(currentHp: 10),
        baseScores: const AbilityScores(
          strength: 16,
          dexterity: 12,
          constitution: 14,
          intelligence: 10,
          wisdom: 10,
          charisma: 10,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'plate-plus-3-bare',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'plate-plus-3',
              displayName: 'Plate Armor +3',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
          ),
        ],
      );

      final stats = CharacterEvaluationEngine.evaluate(baseCharacter);

      expect(stats.armorClass, equals(21));
      expect(stats.attackProfiles.where((a) => a.weaponName.contains('Plate')),
          isEmpty);
    });

    test(
        'CharacterSheetController.toggleEquipItem equips Plate Armor +3 into EquipmentSlot.armor',
        () async {
      final baseCharacter = Character(
        id: const EntityId(slug: 'controller-knight', ruleset: RulesetVersion.v2024),
        name: 'Dame Brienne',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'paladin',
                displayName: 'Paladin',
              ),
              level: 3,
              hitDie: 'd10',
            ),
          ],
        ),
        rulesEdition: DmRulesEdition.v2024,
        resources: const CharacterResourcePool(currentHp: 10),
        baseScores: const AbilityScores(
          strength: 18,
          dexterity: 10,
          constitution: 16,
          intelligence: 10,
          wisdom: 12,
          charisma: 10,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'plate-3-ctrl',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'plate-plus-3',
              displayName: 'Plate Armor +3',
            ),
            isEquipped: false,
            equippedSlot: null,
          ),
        ],
      );

      final controller = CharacterSheetController(character: baseCharacter);

      await controller.toggleEquipItem('plate-3-ctrl');

      final equippedPlate = controller.character.inventory
          .firstWhere((i) => i.instanceId == 'plate-3-ctrl');
      expect(equippedPlate.isEquipped, isTrue);
      expect(equippedPlate.equippedSlot, equals(EquipmentSlot.armor));
      expect(controller.stats.armorClass, equals(21));
      expect(
          controller.stats.attackProfiles
              .where((a) => a.weaponName.contains('Plate')),
          isEmpty);
    });

    test(
        'CommunityCompendiumAdapters parses W as Wondrous Item and HA as Armor',
        () {
      final adapters = CommunityCompendiumAdapters();

      final wondrousJson = {
        'name': 'Cloak of Billowing',
        'type': 'W',
        'entries': ['This cloak billows dramatically.'],
      };
      final wondrousItem = adapters.parseItem(wondrousJson);
      expect(wondrousItem.itemType, equals('Wondrous Item'));

      final plateJson = {
        'name': 'Plate Armor, +3',
        'type': 'HA',
        'entries': ['+3 plate armor.'],
      };
      final plateItem = adapters.parseItem(plateJson);
      expect(plateItem.itemType, equals('Armor'));
    });
  });
}
