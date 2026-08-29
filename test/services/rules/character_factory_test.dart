import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';

void main() {
  group('CharacterFactory Tests', () {
    test('validates standard 27 Point Buy arrays', () {
      const validArray = AbilityScores(
        strength: 15, // 9 pts
        dexterity: 14, // 7 pts
        constitution: 13, // 5 pts
        intelligence: 12, // 4 pts
        wisdom: 10, // 2 pts
        charisma: 8, // 0 pts => Total = 27
      );

      expect(CharacterFactory.calculatePointBuyCost(validArray), equals(27));
      expect(CharacterFactory.validatePointBuy(validArray), isTrue);

      const invalidOverBudget = AbilityScores(
        strength: 15,
        dexterity: 15,
        constitution: 15,
        intelligence: 15,
        wisdom: 8,
        charisma: 8,
      );

      expect(CharacterFactory.validatePointBuy(invalidOverBudget), isFalse);

      const invalidScoreOutOfRange = AbilityScores(
        strength: 18,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
      );

      expect(CharacterFactory.validatePointBuy(invalidScoreOutOfRange), isFalse);
    });

    test('creates 2014 ruleset Level 1 Fighter with Racial ASI and starting equipment', () {
      final request = CharacterCreationRequest(
        characterName: 'Thorin Stonehelm',
        ruleset: RulesetVersion.v2014,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'mountain-dwarf',
          displayName: 'Mountain Dwarf',
        ),
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'soldier',
          displayName: 'Soldier',
        ),
        startingClassSlug: 'fighter',
        startingClassDisplayName: 'Fighter',
        startingClassHitDie: 'd10',
        baseScores: const AbilityScores.standardArray(), // STR 15, DEX 14, CON 13, INT 12, WIS 10, CHA 8
        bonusScores: const AbilityScores(
          strength: 2, // 2014 Mountain Dwarf +2 STR
          constitution: 2, // +2 CON
        ),
        startingEquipment: const [
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'chain-mail',
              displayName: 'Chain Mail',
            ),
            quantity: 1,
            equipImmediately: true,
            defaultSlot: EquipmentSlot.armor,
          ),
          StartingEquipmentItemRequest(
            itemRef: EntityReference(
              refType: EntityType.equipment,
              slug: 'longsword',
              displayName: 'Longsword',
            ),
            quantity: 1,
            equipImmediately: true,
            defaultSlot: EquipmentSlot.mainHand,
          ),
        ],
        startingPurse: const PartyPurse(gp: 10),
      );

      final character = CharacterFactory.createLevel1Character(request);

      expect(character.name, equals('Thorin Stonehelm'));
      expect(character.ruleset, equals(RulesetVersion.v2014));
      expect(character.totalLevel, equals(1));
      // CON is 13 + 2 = 15 (+2 mod). Level 1 Fighter HP = 10 + 2 = 12
      expect(character.resources.currentHp, equals(12));
      expect(character.inventory.length, equals(2));
      expect(character.equippedItems.length, equals(2));
      expect(character.purse.gp, equals(10));
    });

    test('creates 2024 ruleset Level 1 Wizard with Origin Feat and Background ASI', () {
      final request = CharacterCreationRequest(
        characterName: 'Eldrin the Wise',
        ruleset: RulesetVersion.v2024,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'high-elf',
          displayName: 'High Elf',
        ),
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'sage',
          displayName: 'Sage',
        ),
        startingClassSlug: 'wizard',
        startingClassDisplayName: 'Wizard',
        startingClassHitDie: 'd6',
        baseScores: const AbilityScores(
          strength: 8,
          dexterity: 14,
          constitution: 13,
          intelligence: 15,
          wisdom: 12,
          charisma: 10,
        ),
        bonusScores: const AbilityScores(
          intelligence: 2, // 2024 Background +2 INT
          constitution: 1, // +1 CON -> 14 (+2 mod)
        ),
        originFeats: const [
          EntityReference(
            refType: EntityType.feat,
            slug: 'magic-initiate-cleric',
            displayName: 'Magic Initiate (Cleric)',
          ),
        ],
        cantrips: const [
          EntityReference(
            refType: EntityType.spell,
            slug: 'fire-bolt',
            displayName: 'Fire Bolt',
          ),
        ],
        spellsKnown: const [
          EntityReference(
            refType: EntityType.spell,
            slug: 'mage-armor',
            displayName: 'Mage Armor',
          ),
        ],
      );

      final character = CharacterFactory.createLevel1Character(request);

      expect(character.name, equals('Eldrin the Wise'));
      expect(character.ruleset, equals(RulesetVersion.v2024));
      // CON = 13 + 1 = 14 (+2 mod). Wizard HP = 6 + 2 = 8
      expect(character.resources.currentHp, equals(8));
      expect(character.feats.length, equals(1));
      expect(character.cantrips.length, equals(1));
      expect(character.spellsKnown.length, equals(1));
    });
  });
}
