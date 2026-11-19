import 'dart:math';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_telemetry_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

void main() {
  group('Fix 8.5 Law Test: Party Telemetry AC Comes From Rules', () {
    test('DEX 18 unarmored rogue telemetry AC is 14, not 10', () {
      const rogue = Character(
        id: EntityId(slug: 'dex-18-rogue', ruleset: RulesetVersion.v2024),
        name: 'Dex 18 Rogue',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        baseScores: AbilityScores(dexterity: 18),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference<DomainEntity>.empty(
              refType: EntityType.classDefinition,
              slug: 'rogue',
              displayName: 'Rogue',
            ),
            level: 3,
          ),
        ]),
        rulesEdition: RulesetEdition.v2024,
      );

      final dtoAc = rogue.toTelemetryDto().armorClass;
      final evalAc = CharacterEvaluationEngine.evaluate(rogue).armorClass;
      expect(dtoAc, equals(14));
      expect(dtoAc, equals(evalAc));
    });

    test('Over 300 seeded characters (armor, shields, abilities, overrides), toTelemetryDto().armorClass equals CharacterEvaluationEngine.evaluate(c).armorClass and edition module queryStat', () {
      final rng = Random(8500);
      const armorCatalog = <(String, String)?>[
        null,
        ('leather-armor', 'Leather Armor'),
        ('studded-leather', 'Studded Leather'),
        ('hide-armor', 'Hide Armor'),
        ('chain-shirt', 'Chain Shirt'),
        ('scale-mail', 'Scale Mail'),
        ('breastplate', 'Breastplate'),
        ('half-plate', 'Half Plate'),
        ('ring-mail', 'Ring Mail'),
        ('chain-mail', 'Chain Mail'),
        ('splint-armor', 'Splint Armor'),
        ('plate-armor', 'Plate Armor'),
      ];
      const classPool = ['fighter', 'rogue', 'wizard', 'cleric', 'barbarian', 'monk'];

      for (var i = 0; i < 300; i++) {
        final edition = i.isEven ? RulesetEdition.v2024 : RulesetEdition.v2014;
        final str = 3 + rng.nextInt(18);
        final dex = 3 + rng.nextInt(18);
        final con = 3 + rng.nextInt(18);
        final intl = 3 + rng.nextInt(18);
        final wis = 3 + rng.nextInt(18);
        final cha = 3 + rng.nextInt(18);

        final armorChoice = armorCatalog[rng.nextInt(armorCatalog.length)];
        final hasShield = rng.nextBool();
        final classSlug = classPool[rng.nextInt(classPool.length)];
        final inventory = <InventoryItemInstance>[];
        if (armorChoice != null) {
          inventory.add(InventoryItemInstance(
            itemRef: EntityReference<DomainEntity>.empty(
              refType: EntityType.equipment,
              slug: armorChoice.$1,
              displayName: armorChoice.$2,
            ),
            instanceId: 'armor_$i',
            isEquipped: true,
            equippedSlot: EquipmentSlot.armor,
          ));
        }
        if (hasShield) {
          inventory.add(InventoryItemInstance(
            itemRef: const EntityReference<DomainEntity>.empty(
              refType: EntityType.equipment,
              slug: 'shield',
              displayName: 'Shield',
            ),
            instanceId: 'shield_$i',
            isEquipped: true,
            equippedSlot: EquipmentSlot.shield,
          ));
        }

        final customProps = <String, dynamic>{};
        if (i % 5 == 0) {
          customProps['armorClass'] = 11 + rng.nextInt(15);
        } else if (i % 7 == 0) {
          customProps['ac'] = 11 + rng.nextInt(15);
        }

        final c = Character(
          id: EntityId(
            slug: 'party-ac-$i',
            ruleset: edition == RulesetEdition.v2024
                ? RulesetVersion.v2024
                : RulesetVersion.v2014,
          ),
          name: 'Party Hero $i',
          speciesRef: const EntityReference<DomainEntity>.empty(
            refType: EntityType.species,
            slug: 'human',
            displayName: 'Human',
          ),
          baseScores: AbilityScores(
            strength: str,
            dexterity: dex,
            constitution: con,
            intelligence: intl,
            wisdom: wis,
            charisma: cha,
          ),
          progression: CharacterProgression(classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>.empty(
                refType: EntityType.classDefinition,
                slug: classSlug,
                displayName: classSlug[0].toUpperCase() + classSlug.substring(1),
              ),
              level: 1 + rng.nextInt(20),
            ),
          ]),
          inventory: inventory,
          rulesEdition: edition,
          customProperties: customProps,
        );

        final module = edition == RulesetEdition.v2014
            ? const Dnd5eRulesetModule.v2014()
            : const Dnd5eRulesetModule.v2024();
        final telemetryAc = c.toTelemetryDto().armorClass;
        final evaluatedAc = CharacterEvaluationEngine.evaluate(c).armorClass;
        final moduleAc = c.queryStat('ac', module: module);

        expect(
          telemetryAc,
          equals(evaluatedAc),
          reason: 'Seed $i: telemetry AC ($telemetryAc) != evaluated AC ($evaluatedAc)',
        );
        expect(
          telemetryAc,
          equals(moduleAc),
          reason: 'Seed $i: telemetry AC ($telemetryAc) != module queryStat AC ($moduleAc)',
        );
      }
    });
  });
}
