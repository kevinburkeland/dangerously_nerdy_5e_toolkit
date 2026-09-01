import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';

void main() {
  group('CharacterEvaluationEngine Tests', () {
    test('Calculates standard unarmored AC (10 + DEX)', () {
      const character = Character(
        id: EntityId(slug: 'hero-1', ruleset: RulesetVersion.v2024),
        name: 'Rogue Hero',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'rogue',
                displayName: 'Rogue',
              ),
              level: 1,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(dexterity: 16), // Mod +3
        resources: CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.abilityModifiers[AbilityType.dexterity], equals(3));
      expect(stats.armorClass, equals(13)); // 10 + 3
    });

    test('Plate Armor sets flat AC 18 and ignores DEX bonus', () {
      const character = Character(
        id: EntityId(slug: 'hero-plate', ruleset: RulesetVersion.v2024),
        name: 'Knight',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 1,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: AbilityScores(dexterity: 18), // Mod +4
        inventory: [
          InventoryItemInstance(
            instanceId: 'plate-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'plate',
              displayName: 'Plate Armor',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
            customProperties: {
              'baseAc': 18,
              'armorType': 'heavy',
            },
          ),
        ],
        resources: CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.armorClass, equals(18));
      expect(stats.armorClassBreakdown, contains('18 (Plate Armor)'));
    });

    test('Medium Armor (Breastplate) caps DEX contribution at maxDexBonus (+2)', () {
      const character = Character(
        id: EntityId(slug: 'hero-med', ruleset: RulesetVersion.v2024),
        name: 'Ranger',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
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
        baseScores: AbilityScores(dexterity: 18), // Mod +4
        inventory: [
          InventoryItemInstance(
            instanceId: 'breastplate-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'breastplate',
              displayName: 'Breastplate',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
            customProperties: {
              'baseAc': 14,
              'armorType': 'medium',
              'maxDexBonus': 2,
            },
          ),
          InventoryItemInstance(
            instanceId: 'shield-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
            customProperties: {
              'acBonus': 2,
            },
          ),
        ],
        resources: CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      // 14 + min(4, 2) + 2 = 18
      expect(stats.armorClass, equals(18));
    });

    test('Barbarian Unarmored Defense calculates 10 + DEX + CON (allows shield)', () {
      const character = Character(
        id: EntityId(slug: 'barb-1', ruleset: RulesetVersion.v2024),
        name: 'Krag',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'goliath',
          displayName: 'Goliath',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'barbarian',
                displayName: 'Barbarian',
              ),
              level: 1,
              hitDie: 'd12',
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 14, // Mod +2
          constitution: 16, // Mod +3
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'shield-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
            customProperties: {
              'acBonus': 2,
            },
          ),
        ],
        resources: CharacterResourcePool(currentHp: 15),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      // 10 + 2 (DEX) + 3 (CON) + 2 (Shield) = 17
      expect(stats.armorClass, equals(17));
    });

    test('Monk Unarmored Defense calculates 10 + DEX + WIS (disallowed if shield equipped)', () {
      const characterNoShield = Character(
        id: EntityId(slug: 'monk-1', ruleset: RulesetVersion.v2024),
        name: 'Li',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'monk',
                displayName: 'Monk',
              ),
              level: 1,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 16, // Mod +3
          wisdom: 16, // Mod +3
        ),
        resources: CharacterResourcePool(currentHp: 10),
      );

      final statsNoShield = CharacterEvaluationEngine.evaluate(characterNoShield);
      // 10 + 3 (DEX) + 3 (WIS) = 16
      expect(statsNoShield.armorClass, equals(16));

      const characterWithShield = Character(
        id: EntityId(slug: 'monk-2', ruleset: RulesetVersion.v2024),
        name: 'Li With Shield',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'monk',
                displayName: 'Monk',
              ),
              level: 1,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 16, // Mod +3
          wisdom: 16, // Mod +3
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'shield-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
            customProperties: {'acBonus': 2},
          ),
        ],
        resources: CharacterResourcePool(currentHp: 10),
      );

      final statsWithShield = CharacterEvaluationEngine.evaluate(characterWithShield);
      // Monk Unarmored Defense disabled: fallback to 10 + 3 (DEX) + 2 (Shield) = 15
      expect(statsWithShield.armorClass, equals(15));
    });

    test('Stat Overrides (Belt of Giant Strength) correctly override lower base stat when attuned', () {
      const character = Character(
        id: EntityId(slug: 'hero-belt', ruleset: RulesetVersion.v2024),
        name: 'Thorin',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'dwarf',
          displayName: 'Dwarf',
        ),
        progression: CharacterProgression(
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
        baseScores: AbilityScores(strength: 14), // Base Mod +2
        inventory: [
          InventoryItemInstance(
            instanceId: 'belt-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'belt-hill-giant',
              displayName: 'Belt of Hill Giant Strength',
            ),
            isEquipped: true,
            isAttuned: true,
            requiresAttunement: true,
            customProperties: {
              'overrideStrength': 21,
            },
          ),
        ],
        resources: CharacterResourcePool(currentHp: 40),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.effectiveScores.strength, equals(21));
      expect(stats.abilityModifiers[AbilityType.strength], equals(5)); // (21-10)/2 = 5
    });

    test('Attunement item bonuses are ignored if item is not attuned', () {
      const character = Character(
        id: EntityId(slug: 'hero-unattuned', ruleset: RulesetVersion.v2024),
        name: 'Unattuned Hero',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'fighter',
                displayName: 'Fighter',
              ),
              level: 1,
              hitDie: 'd10',
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 14),
        inventory: [
          InventoryItemInstance(
            instanceId: 'ring-1',
            itemRef: EntityReference<EquipmentItem>(
              refType: EntityType.equipment,
              slug: 'ring-protection',
              displayName: 'Ring of Protection',
            ),
            isEquipped: true,
            isAttuned: false, // Unattuned
            requiresAttunement: true,
            customProperties: {
              'acBonus': 1,
            },
          ),
        ],
        resources: CharacterResourcePool(currentHp: 10),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.armorClass, equals(10)); // AC bonus not applied
    });

    test('Artificer Class scales attunement slots dynamically (Levels 10, 14, 18)', () {
      // Level 1 Artificer: standard 3 slots
      const art1 = Character(
        id: EntityId(slug: 'art-1', ruleset: RulesetVersion.v2024),
        name: 'Artificer Novice',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'gnome',
          displayName: 'Gnome',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'artificer',
                displayName: 'Artificer',
              ),
              level: 5,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(currentHp: 30),
      );
      expect(CharacterEvaluationEngine.evaluate(art1).effectiveMaxAttunementSlots, equals(3));

      // Level 10 Artificer (Magic Item Adept): 4 slots
      const art10 = Character(
        id: EntityId(slug: 'art-10', ruleset: RulesetVersion.v2024),
        name: 'Artificer Adept',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'gnome',
          displayName: 'Gnome',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'artificer',
                displayName: 'Artificer',
              ),
              level: 10,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(currentHp: 60),
      );
      expect(CharacterEvaluationEngine.evaluate(art10).effectiveMaxAttunementSlots, equals(4));

      // Level 14 Artificer (Magic Item Savant): 5 slots
      const art14 = Character(
        id: EntityId(slug: 'art-14', ruleset: RulesetVersion.v2024),
        name: 'Artificer Savant',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'gnome',
          displayName: 'Gnome',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'artificer',
                displayName: 'Artificer',
              ),
              level: 14,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(currentHp: 80),
      );
      expect(CharacterEvaluationEngine.evaluate(art14).effectiveMaxAttunementSlots, equals(5));

      // Level 18 Artificer (Magic Item Master): 6 slots
      const art18 = Character(
        id: EntityId(slug: 'art-18', ruleset: RulesetVersion.v2024),
        name: 'Artificer Master',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'gnome',
          displayName: 'Gnome',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'artificer',
                displayName: 'Artificer',
              ),
              level: 18,
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(),
        resources: CharacterResourcePool(currentHp: 100),
      );
      expect(CharacterEvaluationEngine.evaluate(art18).effectiveMaxAttunementSlots, equals(6));
    });

    test('Calculates Skill modifiers and Proficiency multipliers (Proficient & Expertise)', () {
      const character = Character(
        id: EntityId(slug: 'rogue-expert', ruleset: RulesetVersion.v2024),
        name: 'Master Thief',
        speciesRef: EntityReference<DomainEntity>(
          refType: EntityType.species,
          slug: 'halfling',
          displayName: 'Halfling',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>(
                refType: EntityType.classDefinition,
                slug: 'rogue',
                displayName: 'Rogue',
              ),
              level: 5, // PB = +3
              hitDie: 'd8',
            ),
          ],
        ),
        baseScores: AbilityScores(
          dexterity: 16, // Mod +3
          wisdom: 12, // Mod +1
        ),
        skillProficiencies: {
          SkillType.stealth: SkillProficiencyLevel.expertise, // DEX Mod + (2 * 3) = +9
          SkillType.perception: SkillProficiencyLevel.proficient, // WIS Mod + (1 * 3) = +4
          SkillType.athletics: SkillProficiencyLevel.none, // STR Mod 0 = 0
        },
        resources: CharacterResourcePool(currentHp: 30),
      );

      final stats = CharacterEvaluationEngine.evaluate(character);
      expect(stats.proficiencyBonus, equals(3));
      expect(stats.skillModifiers[SkillType.stealth], equals(9));
      expect(stats.skillModifiers[SkillType.perception], equals(4));
      expect(stats.skillModifiers[SkillType.athletics], equals(0));
      expect(stats.passivePerception, equals(14)); // 10 + 4
    });
  });
}
