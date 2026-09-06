import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_stat_calculator.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/inventory_transaction_service.dart';

void main() {
  group('Breastplate and Standard Armor Disambiguation Tests', () {
    test('SrdEquipmentLibrary resolves Breastplate with baseAc 14, medium armor, maxDexBonus 2', () {
      final all = SrdEquipmentLibrary.allEquipmentItems;
      final breastplate = all.firstWhere((i) => i.name == 'Breastplate');

      expect(breastplate.customProperties['baseAc'], equals(14));
      expect(breastplate.customProperties['armorType'], equals('medium'));
      expect(breastplate.customProperties['maxDexBonus'], equals(2));
      expect(breastplate.customProperties['defaultSlot'], equals(EquipmentSlot.armor));
    });

    test('SrdEquipmentLibrary resolves Breastplate +1 with baseAc 14, medium armor, and +1 AC bonus', () {
      final all = SrdEquipmentLibrary.allEquipmentItems;
      final breastplatePlus1 = all.firstWhere((i) => i.name == 'Breastplate +1');

      expect(breastplatePlus1.customProperties['baseAc'], equals(14));
      expect(breastplatePlus1.customProperties['armorType'], equals('medium'));
      expect(breastplatePlus1.customProperties['maxDexBonus'], equals(2));
      expect(breastplatePlus1.customProperties['acBonus'], equals(1));
    });

    test('SrdEquipmentLibrary resolves Half Plate Armor with baseAc 15 and Plate Armor with baseAc 18', () {
      final all = SrdEquipmentLibrary.allEquipmentItems;
      final halfPlate = all.firstWhere((i) => i.name == 'Half Plate Armor');
      final fullPlate = all.firstWhere((i) => i.name == 'Plate Armor (Full Plate)');

      expect(halfPlate.customProperties['baseAc'], equals(15));
      expect(halfPlate.customProperties['armorType'], equals('medium'));
      expect(halfPlate.customProperties['maxDexBonus'], equals(2));

      expect(fullPlate.customProperties['baseAc'], equals(18));
      expect(fullPlate.customProperties['armorType'], equals('heavy'));
      expect(fullPlate.customProperties['maxDexBonus'], equals(0));
    });

    test('Character.resolveStandardArmor resolves breastplate, half plate, plate, and leather correctly', () {
      final bp = Character.resolveStandardArmor('Breastplate', 'breastplate');
      expect(bp.baseAc, equals(14));
      expect(bp.armorType, equals('medium'));
      expect(bp.maxDex, equals(2));

      final hp = Character.resolveStandardArmor('Half Plate', 'half-plate');
      expect(hp.baseAc, equals(15));
      expect(hp.armorType, equals('medium'));
      expect(hp.maxDex, equals(2));

      final pl = Character.resolveStandardArmor('Plate Armor', 'plate-armor');
      expect(pl.baseAc, equals(18));
      expect(pl.armorType, equals('heavy'));
      expect(pl.maxDex, equals(0));

      // Armor with "leather" in description/name should not downgrade medium/heavy armor
      final leatherLinedBp = Character.resolveStandardArmor('Leather-Lined Breastplate', 'leather-lined-breastplate');
      expect(leatherLinedBp.baseAc, equals(14));
      expect(leatherLinedBp.armorType, equals('medium'));

      final studded = Character.resolveStandardArmor('Studded Leather', 'studded-leather');
      expect(studded.baseAc, equals(12));
      expect(studded.armorType, equals('light'));

      final plainLeather = Character.resolveStandardArmor('Leather Armor', 'leather-armor');
      expect(plainLeather.baseAc, equals(11));
      expect(plainLeather.armorType, equals('light'));
    });

    test('CharacterEvaluationEngine calculates AC for bare Breastplate with DEX capping at +2', () {
      // Character with 18 DEX (+4 mod) wearing Breastplate (bare instance, no customProperties)
      const character = Character(
        id: EntityId(slug: 'hero-ranger', ruleset: RulesetVersion.v2024),
        name: 'Ranger',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        resources: CharacterResourcePool(currentHp: 10),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'ranger',
                displayName: 'Ranger',
              ),
              level: 1,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: AbilityScores(
          strength: 10,
          dexterity: 18,
          constitution: 14,
          intelligence: 10,
          wisdom: 14,
          charisma: 10,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'bp-inst',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'breastplate',
              displayName: 'Breastplate',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
          ),
        ],
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      // Breastplate 14 + capped DEX 2 = 16 (NOT 18 from plate armor!)
      expect(stats.armorClass, equals(16));
      expect(stats.armorClassBreakdown, contains('14 (Breastplate) + 2 DEX (capped at 2)'));
      // Must not be heavy armor
      expect(stats.armorClassBreakdown.contains('(Plate'), isFalse);
    });

    test('CharacterStatCalculator calculates AC for Breastplate +1', () {
      final breastplatePlus1 = SrdEquipmentLibrary.allEquipmentItems.firstWhere((i) => i.name == 'Breastplate +1');
      final character = Character(
        id: const EntityId(slug: 'hero-cleric', ruleset: RulesetVersion.v2024),
        name: 'Cleric',
        speciesRef: const EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'dwarf',
          displayName: 'Dwarf',
        ),
        resources: const CharacterResourcePool(currentHp: 20),
        progression: const CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'cleric',
                displayName: 'Cleric',
              ),
              level: 3,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: const AbilityScores(
          strength: 14,
          dexterity: 14, // Mod +2
          constitution: 14,
          intelligence: 10,
          wisdom: 16,
          charisma: 10,
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'bp1-inst',
            itemRef: const EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'breastplate-plus-1',
              displayName: 'Breastplate +1',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
            customProperties: breastplatePlus1.customProperties,
          ),
        ],
      );

      final repo = LayeredPriorityRepository();
      final layer = PriorityLayer(layerId: 'test', name: 'Test', priority: LayerPriority.baseRuleset)
        ..registerEntity(breastplatePlus1);
      repo.addLayer(layer);
      final resolver = ReferenceResolver(repo);
      final stats = CharacterStatCalculator.compute(character, resolver);

      // 14 base + 2 DEX + 1 bonus = 17
      expect(stats.armorClass, equals(17));
    });

    test('CommunityCompendiumAdapters parses medium armor breastplate JSON with correct AC and type', () {
      final adapters = CommunityCompendiumAdapters();
      final itemJson = {
        'name': 'Custom Breastplate',
        'type': 'MA',
        'ac': 14,
      };

      final parsed = adapters.parseItem(itemJson);
      expect(parsed.customProperties['baseAc'], equals(14));
      expect(parsed.customProperties['armorType'], equals('medium'));
      expect(parsed.customProperties['maxDexBonus'], equals(2));
    });

    test('InventoryTransactionService assigns two-handed slot to shortbow and light crossbow', () {
      const shortbow = InventoryItemInstance(
        instanceId: 'sb-1',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'shortbow',
          displayName: 'Shortbow',
        ),
      );
      expect(InventoryTransactionService.resolveDefaultSlot(shortbow), equals(EquipmentSlot.twoHand));

      const lightXbow = InventoryItemInstance(
        instanceId: 'lxb-1',
        itemRef: EntityReference<EquipmentItem>(
          refType: EntityType.equipment,
          slug: 'light-crossbow',
          displayName: 'Light Crossbow',
        ),
      );
      expect(InventoryTransactionService.resolveDefaultSlot(lightXbow), equals(EquipmentSlot.twoHand));
    });
  });
}
