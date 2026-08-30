import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/inventory_transaction_service.dart';

void main() {
  group('Armor Class Engine & Inventory Propagation Tests', () {
    Character createBaseCharacter({
      String classSlug = 'fighter',
      String speciesSlug = 'human',
      int str = 14,
      int dex = 16, // +3 mod
      int con = 14, // +2 mod
      int wis = 16, // +3 mod
      List<InventoryItemInstance> items = const [],
    }) {
      return Character(
        id: const EntityId(slug: 'test-char', ruleset: RulesetVersion.v2024),
        name: 'Test Character',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: speciesSlug,
          displayName: speciesSlug.toUpperCase(),
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: classSlug,
                displayName: classSlug.toUpperCase(),
              ),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(
          strength: str,
          dexterity: dex,
          constitution: con,
          intelligence: 10,
          wisdom: wis,
          charisma: 10,
        ),
        resources: const CharacterResourcePool(currentHp: 12),
        inventory: items,
      );
    }

    test('Unarmored standard calculation: 10 + DEX mod', () {
      final char = createBaseCharacter(dex: 16);
      final stats = CharacterEvaluationEngine.evaluate(char);
      expect(stats.armorClass, 13); // 10 + 3
    });

    test('Unarmored Defense: Barbarian adds CON mod', () {
      final barbarian = createBaseCharacter(
        classSlug: 'barbarian',
        dex: 14, // +2
        con: 16, // +3
      );
      final stats = CharacterEvaluationEngine.evaluate(barbarian);
      expect(stats.armorClass, 15); // 10 + 2 + 3
    });

    test('Unarmored Defense: Monk adds WIS mod (no armor, no shield)', () {
      final monk = createBaseCharacter(
        classSlug: 'monk',
        dex: 16, // +3
        wis: 16, // +3
      );
      final stats = CharacterEvaluationEngine.evaluate(monk);
      expect(stats.armorClass, 16); // 10 + 3 + 3
    });

    test('Light Armor: Leather base 11 + full DEX mod', () {
      final leatherArmor = InventoryItemInstance(
        instanceId: 'armor-1',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'leather-armor',
          displayName: 'Leather Armor',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
        customProperties: const {
          'armorType': 'light',
          'baseAc': 11,
        },
      );

      final char = createBaseCharacter(dex: 16, items: [leatherArmor]);
      final stats = CharacterEvaluationEngine.evaluate(char);
      expect(stats.armorClass, 14); // 11 + 3
    });

    test('Medium Armor: Scale Mail base 14 + DEX capped at +2', () {
      final scaleMail = InventoryItemInstance(
        instanceId: 'armor-2',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'scale-mail',
          displayName: 'Scale Mail',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
        customProperties: const {
          'armorType': 'medium',
          'baseAc': 14,
          'maxDexBonus': 2,
        },
      );

      final char = createBaseCharacter(dex: 18, items: [scaleMail]); // DEX +4
      final stats = CharacterEvaluationEngine.evaluate(char);
      expect(stats.armorClass, 16); // 14 + min(4, 2) = 16
    });

    test('Heavy Armor: Plate base 18 ignores DEX mod', () {
      final plate = InventoryItemInstance(
        instanceId: 'armor-3',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'plate-armor',
          displayName: 'Plate Armor',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
        customProperties: const {
          'armorType': 'heavy',
          'baseAc': 18,
        },
      );

      final char = createBaseCharacter(dex: 18, items: [plate]);
      final stats = CharacterEvaluationEngine.evaluate(char);
      expect(stats.armorClass, 18);
    });

    test('Shield adds +2 to AC', () {
      final plate = InventoryItemInstance(
        instanceId: 'armor-3',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'plate-armor',
          displayName: 'Plate Armor',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
        customProperties: const {
          'armorType': 'heavy',
          'baseAc': 18,
        },
      );

      final shield = InventoryItemInstance(
        instanceId: 'shield-1',
        itemRef: const EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'shield',
          displayName: 'Shield',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.shield,
        customProperties: const {
          'isShield': true,
          'shieldBonus': 2,
        },
      );

      final char = createBaseCharacter(items: [plate, shield]);
      final stats = CharacterEvaluationEngine.evaluate(char);
      expect(stats.armorClass, 20); // 18 + 2
    });

    test('Equipping two-handed weapon auto-unequips shield and offhand', () {
      final longsword = InventoryItemInstance(
        instanceId: 'weapon-1',
        itemRef: const EntityReference<EquipmentItem>(refType: EntityType.equipment, slug: 'longsword', displayName: 'Longsword'),
        isEquipped: true,
        equippedSlot: EquipmentSlot.mainHand,
      );

      final shield = InventoryItemInstance(
        instanceId: 'shield-1',
        itemRef: const EntityReference<EquipmentItem>(refType: EntityType.equipment, slug: 'shield', displayName: 'Shield'),
        isEquipped: true,
        equippedSlot: EquipmentSlot.shield,
      );

      final greatsword = InventoryItemInstance(
        instanceId: 'weapon-2',
        itemRef: const EntityReference<EquipmentItem>(refType: EntityType.equipment, slug: 'greatsword', displayName: 'Greatsword'),
        isEquipped: false,
      );

      var char = createBaseCharacter(items: [longsword, shield, greatsword]);

      // Equip greatsword into twoHand slot
      char = InventoryTransactionService.equipItem(char, 'weapon-2', EquipmentSlot.twoHand);

      final greatswordItem = char.inventory.firstWhere((i) => i.instanceId == 'weapon-2');
      final shieldItem = char.inventory.firstWhere((i) => i.instanceId == 'shield-1');
      final longswordItem = char.inventory.firstWhere((i) => i.instanceId == 'weapon-1');

      expect(greatswordItem.isEquipped, isTrue);
      expect(greatswordItem.equippedSlot, EquipmentSlot.twoHand);
      expect(shieldItem.isEquipped, isFalse);
      expect(longswordItem.isEquipped, isFalse);
    });

    test('Dwarven Toughness propagation adds +1 HP per level', () {
      final dwarf = createBaseCharacter(
        speciesSlug: 'dwarf',
        con: 14, // +2 mod
      ); // 1d10 + 2 CON = 12 + 1 Dwarven Toughness = 13
      final stats = CharacterEvaluationEngine.evaluate(dwarf, overrideEdition: DmRulesEdition.v2024);
      expect(stats.maxHp, 13);
    });
  });
}
