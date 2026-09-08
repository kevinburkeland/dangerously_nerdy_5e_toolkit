import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/data/acl/character_telemetry_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';

void main() {
  group('ClassLevelPointerDto', () {
    test('serializes to and from minified keys', () {
      const pointer = ClassLevelPointerDto(
        classSlug: 'fighter',
        subclassSlug: 'champion',
        level: 5,
      );

      final map = pointer.toMap();
      expect(map, {
        'c': 'fighter',
        'sc': 'champion',
        'l': 5,
      });

      final restored = ClassLevelPointerDto.fromMap(map);
      expect(restored.classSlug, 'fighter');
      expect(restored.subclassSlug, 'champion');
      expect(restored.level, 5);
    });

    test('handles null subclassSlug and clamps level', () {
      final pointer = ClassLevelPointerDto.fromMap({
        'c': 'wizard',
        'l': 99,
      });
      expect(pointer.classSlug, 'wizard');
      expect(pointer.subclassSlug, isNull);
      expect(pointer.level, 20); // Clamped to 20
    });
  });

  group('CharacterTelemetryDto', () {
    test('enforces strict boundary clamping on combat metrics', () {
      final dto = CharacterTelemetryDto(
        id: 'hero-1',
        name: 'Gromph',
        speciesSlug: 'half-orc',
        classPointers: const [
          ClassLevelPointerDto(classSlug: 'barbarian', level: 25),
        ],
        currentHp: -50,
        maxHp: 2000,
        tempHp: -10,
        armorClass: 99,
        speed: 500,
        level: 50,
        exhaustionLevel: 10,
        deathSaveSuccesses: 5,
        deathSaveFailures: -2,
      );

      expect(dto.currentHp, 0); // clamped 0..999
      expect(dto.maxHp, 999); // clamped 1..999
      expect(dto.tempHp, 0); // clamped 0..999
      expect(dto.armorClass, 50); // clamped 1..50
      expect(dto.speed, 300); // clamped 0..300
      expect(dto.level, 20); // clamped 1..20
      expect(dto.exhaustionLevel, 6); // clamped 0..6
      expect(dto.deathSaveSuccesses, 3); // clamped 0..3
      expect(dto.deathSaveFailures, 0); // clamped 0..3
    });

    test('serializes with minified JSON keys and round-trips accurately', () {
      final dto = CharacterTelemetryDto(
        id: 'hero-123',
        name: 'Aelar',
        speciesSlug: 'elf',
        backgroundSlug: 'acolyte',
        classPointers: const [
          ClassLevelPointerDto(classSlug: 'wizard', subclassSlug: 'evoker', level: 5),
        ],
        currentHp: 28,
        maxHp: 32,
        tempHp: 5,
        armorClass: 15,
        speed: 30,
        level: 5,
        passivePerception: 14,
        exhaustionLevel: 1,
        deathSaveSuccesses: 0,
        deathSaveFailures: 0,
        conditions: const ['poisoned'],
        spellSlots: const {'1': 4, '2': 3, '3': 2},
        featSlugs: const ['homebrew-combat-caster'],
        equippedItemSlugs: const ['quarterstaff', 'robe-of-stars'],
        rulesEdition: '2024',
        timestamp: 1725700000000,
      );

      final map = dto.toMap();
      expect(map['id'], 'hero-123');
      expect(map['n'], 'Aelar');
      expect(map['sp'], 'elf');
      expect(map['bg'], 'acolyte');
      expect(map['hp'], 28);
      expect(map['mhp'], 32);
      expect(map['thp'], 5);
      expect(map['ac'], 15);
      expect(map['spd'], 30);
      expect(map['lvl'], 5);
      expect(map['pp'], 14);
      expect(map['exh'], 1);
      expect(map['cnd'], ['poisoned']);
      expect(map['ss'], {'1': 4, '2': 3, '3': 2});
      expect(map['ft'], ['homebrew-combat-caster']);
      expect(map['eq'], ['quarterstaff', 'robe-of-stars']);
      expect(map['re'], '2024');
      expect(map['ts'], 1725700000000);

      final restored = CharacterTelemetryDto.fromMap(map);
      expect(restored.id, dto.id);
      expect(restored.name, dto.name);
      expect(restored.speciesSlug, dto.speciesSlug);
      expect(restored.backgroundSlug, dto.backgroundSlug);
      expect(restored.classPointers.first.classSlug, 'wizard');
      expect(restored.classPointers.first.subclassSlug, 'evoker');
      expect(restored.currentHp, 28);
      expect(restored.maxHp, 32);
      expect(restored.tempHp, 5);
      expect(restored.armorClass, 15);
      expect(restored.conditions, ['poisoned']);
      expect(restored.spellSlots, {'1': 4, '2': 3, '3': 2});
      expect(restored.featSlugs, ['homebrew-combat-caster']);
      expect(restored.equippedItemSlugs, ['quarterstaff', 'robe-of-stars']);
    });

    test('extracts faithfully from full domain Character via toTelemetryDto()', () {
      final draft = CharacterDraft()
        ..characterName = 'Eldrin Shadowcloak'
        ..rulesEdition = DmRulesEdition.v2024
        ..speciesRef = const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
        )
        ..backgroundRef = const EntityReference(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        )
        ..startingClassRef = const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'rogue',
          displayName: 'Rogue',
        )
        ..startingClassHitDie = 'd8'
        ..baseScores = const AbilityScores(
          strength: 8,
          dexterity: 16,
          constitution: 14,
          intelligence: 12,
          wisdom: 13,
          charisma: 10,
        )
        ..selectedSkills = {
          SkillType.stealth: SkillProficiencyLevel.proficient,
          SkillType.perception: SkillProficiencyLevel.proficient,
        };

      var character = CharacterFactory.buildFromDraft(draft);

      const equippedItem = InventoryItemInstance(
        instanceId: 'rapier-1',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          slug: 'rapier',
          displayName: 'Rapier',
        ),
        isEquipped: true,
      );
      const backpackItem = InventoryItemInstance(
        instanceId: 'potion-1',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          slug: 'potion-of-healing',
          displayName: 'Potion of Healing',
        ),
        isEquipped: false,
      );

      character = character.copyWith(
        inventory: [equippedItem, backpackItem],
        customProperties: {
          'notesMarkdown': 'Secret key is hidden under tavern floorboard.',
          'narrativeTraits': 'Very long backstory about ancient prophecies and ancestral ruins.',
        },
      );

      final dto = character.toTelemetryDto();

      expect(dto.name, 'Eldrin Shadowcloak');
      expect(dto.speciesSlug, 'elf');
      expect(dto.backgroundSlug, 'acolyte');
      expect(dto.classPointers.length, 1);
      expect(dto.classPointers.first.classSlug, 'rogue');
      expect(dto.currentHp, greaterThan(0));
      expect(dto.maxHp, greaterThan(0));
      expect(dto.equippedItemSlugs, ['rapier']); // Only equipped item slug

      // Verify that NO markdown or heavy narrative leaked into the telemetry JSON
      final jsonStr = jsonEncode(dto.toMap());
      expect(jsonStr.contains('Secret key'), isFalse);
      expect(jsonStr.contains('floorboard'), isFalse);
      expect(jsonStr.contains('ancient prophecies'), isFalse);
    });

    test('backward compatibility: handles legacy full character maps', () {
      final legacyMap = {
        'id': {'slug': 'legacy-hero'},
        'name': 'Old Timer',
        'species': {'slug': 'human'},
        'background': {'slug': 'folk-hero'},
        'classes': [
          {
            'classRef': {'slug': 'fighter'},
            'subclassRef': {'slug': 'champion'},
            'level': 4,
          }
        ],
        'resources': {
          'currentHp': 36,
          'maxHp': 40,
          'tempHp': 0,
          'exhaustionLevel': 0,
          'deathSaves': {'successes': 1, 'failures': 0},
          'spellSlots': {'currentSlots': {'1': 2}},
        },
        'conditions': ['prone'],
        'inventory': [
          {'slug': 'shield', 'isEquipped': true},
        ],
        'featuresMarkdown': '### Heavy Narrative Text',
      };

      final dto = CharacterTelemetryDto.fromLegacyCharacterMap(legacyMap);
      expect(dto.id, 'legacy-hero');
      expect(dto.name, 'Old Timer');
      expect(dto.speciesSlug, 'human');
      expect(dto.backgroundSlug, 'folk-hero');
      expect(dto.classPointers.first.classSlug, 'fighter');
      expect(dto.currentHp, 36);
      expect(dto.maxHp, 40);
      expect(dto.conditions, ['prone']);
      expect(dto.equippedItemSlugs, ['shield']);
    });
  });
}
