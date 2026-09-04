import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_builder_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Character _createTestCharacter({
  AbilityScores baseScores = const AbilityScores(),
  List<ClassLevelProgression> classes = const [],
  List<InventoryItemInstance> inventory = const [],
  Map<SkillType, SkillProficiencyLevel> skillProficiencies = const {},
  Set<AbilityType> savingThrowProficiencies = const {},
  List<EntityReference<DomainEntity>> feats = const [],
  DmRulesEdition rulesEdition = DmRulesEdition.v2014,
  Map<String, dynamic> customProperties = const {},
}) {
  return Character(
    id: const EntityId(slug: 'test-char', ruleset: RulesetVersion.v2014),
    name: 'Test Character',
    speciesRef: const EntityReference<DomainEntity>(
      refType: EntityType.species,
      slug: 'human',
      displayName: 'Human',
    ),
    progression: CharacterProgression(
      classes: classes.isNotEmpty
          ? classes
          : [
              const ClassLevelProgression(
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
    baseScores: baseScores,
    inventory: inventory,
    skillProficiencies: skillProficiencies,
    savingThrowProficiencies: savingThrowProficiencies,
    feats: feats,
    resources: const CharacterResourcePool(
      currentHp: 20,
      tempHp: 0,
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
      exhaustionLevel: 0,
      hasHeroicInspiration: false,
      spellSlots: SpellSlotPool(maxSlots: {}, currentSlots: {}),
      currentHitDice: {},
    ),
    rulesEdition: rulesEdition,
    customProperties: customProperties,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Character Derived Stats Engine - Armor Class', () {
    test('Level 1 character with 16 DEX and studded leather has 15 AC, increments to 17 with shield', () {
      const studdedLeather = InventoryItemInstance(
        instanceId: 'item-armor',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          displayName: 'Studded Leather Armor',
          slug: 'studded-leather-armor',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
      );

      final charWithoutShield = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 16),
        inventory: [studdedLeather],
      );

      // 12 (studded leather base) + 3 (DEX 16) = 15
      expect(charWithoutShield.armorClass, equals(15));

      const shield = InventoryItemInstance(
        instanceId: 'item-shield',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          displayName: 'Shield',
          slug: 'shield',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.shield,
      );

      final charWithShield = charWithoutShield.copyWith(
        inventory: [studdedLeather, shield],
      );

      // 15 + 2 = 17
      expect(charWithShield.armorClass, equals(17));
    });

    test('Heavy armor ignores DEX modifier', () {
      const chainMail = InventoryItemInstance(
        instanceId: 'item-chain-mail',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          displayName: 'Chain Mail',
          slug: 'chain-mail',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
      );

      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 18), // +4 DEX
        inventory: [chainMail],
      );

      // Heavy armor (16 base) gives 0 DEX contribution
      expect(char.armorClass, equals(16));
    });

    test('Medium armor caps DEX at 2, but Medium Armor Master raises cap to 3', () {
      const scaleMail = InventoryItemInstance(
        instanceId: 'item-scale-mail',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          displayName: 'Scale Mail',
          slug: 'scale-mail',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
      );

      final charWithoutMam = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 16), // +3 DEX
        inventory: [scaleMail],
      );

      // 14 (Scale mail) + 2 (capped DEX) = 16
      expect(charWithoutMam.armorClass, equals(16));

      // With Medium Armor Master feat
      final charWithMam = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 16), // +3 DEX
        inventory: [scaleMail],
        feats: [
          const EntityReference(
            refType: EntityType.feat,
            displayName: 'Medium Armor Master',
            slug: 'medium-armor-master',
          ),
        ],
      );

      // 14 (Scale mail) + 3 (DEX cap is 3 with MAM) = 17
      expect(charWithMam.armorClass, equals(17));
    });

    test('Barbarian Unarmored Defense adds CON modifier and works with shields', () {
      const barbarianClass = ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: 'barbarian',
          displayName: 'Barbarian',
        ),
        level: 1,
        hitDie: 'd12',
      );

      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 14, constitution: 16), // +2 DEX, +3 CON
        classes: [barbarianClass],
      );

      // 10 + 2 (DEX) + 3 (CON) = 15
      expect(char.armorClass, equals(15));

      const shield = InventoryItemInstance(
        instanceId: 'item-shield',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          displayName: 'Shield',
          slug: 'shield',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.shield,
      );

      final charWithShield = char.copyWith(inventory: [shield]);
      // 15 + 2 = 17
      expect(charWithShield.armorClass, equals(17));
    });

    test('Monk Unarmored Defense adds WIS modifier but is negated by shields', () {
      const monkClass = ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: 'monk',
          displayName: 'Monk',
        ),
        level: 1,
        hitDie: 'd8',
      );

      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 16, wisdom: 16), // +3 DEX, +3 WIS
        classes: [monkClass],
      );

      // 10 + 3 (DEX) + 3 (WIS) = 16
      expect(char.armorClass, equals(16));

      const shield = InventoryItemInstance(
        instanceId: 'item-shield',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          displayName: 'Shield',
          slug: 'shield',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.shield,
      );

      final charWithShield = char.copyWith(inventory: [shield]);
      // Shield cancels monk unarmored defense -> falls back to base 10 + 3 (DEX) + 2 (Shield) = 15
      expect(charWithShield.armorClass, equals(15));
    });

    test('Draconic Sorcerer sets base unarmored AC to 13', () {
      const sorcererClass = ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: 'sorcerer',
          displayName: 'Sorcerer',
        ),
        subclassRef: EntityReference<DomainEntity>(
          refType: EntityType.subclass,
          slug: 'draconic-bloodline',
          displayName: 'Draconic Bloodline',
        ),
        level: 1,
        hitDie: 'd6',
      );

      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 16), // +3 DEX
        classes: [sorcererClass],
      );

      // 13 + 3 (DEX) = 16
      expect(char.armorClass, equals(16));
    });

    test('Defense Fighting Style adds +1 AC while wearing armor', () {
      const leatherArmor = InventoryItemInstance(
        instanceId: 'item-leather',
        itemRef: EntityReference(
          refType: EntityType.equipment,
          displayName: 'Leather Armor',
          slug: 'leather-armor',
        ),
        isEquipped: true,
        equippedSlot: EquipmentSlot.armor,
      );

      final fighterWithDefense = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 14), // +2 DEX
        inventory: [leatherArmor],
        classes: [
          const ClassLevelProgression(
            classRef: EntityReference<DomainEntity>(
              refType: EntityType.classDefinition,
              slug: 'fighter',
              displayName: 'Fighter',
            ),
            level: 1,
            hitDie: 'd10',
            selectedFeatureOptions: {
              'fighting_style': ['defense'],
            },
          ),
        ],
      );

      // 11 (leather) + 2 (DEX) + 1 (defense style) = 14
      expect(fighterWithDefense.armorClass, equals(14));
    });
  });

  group('Character Derived Stats Engine - Initiative', () {
    test('DEX modifier gives baseline initiative', () {
      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 16), // +3
      );
      expect(char.initiativeBonus, equals(3));
    });

    test('Alert feat 2014 adds flat +5 bonus', () {
      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 14), // +2
        feats: [
          const EntityReference(
            refType: EntityType.feat,
            displayName: 'Alert',
            slug: 'alert',
          ),
        ],
        rulesEdition: DmRulesEdition.v2014,
      );
      // 2 + 5 = 7
      expect(char.initiativeBonus, equals(7));
    });

    test('Alert feat 2024 adds proficiency bonus', () {
      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 14), // +2
        feats: [
          const EntityReference(
            refType: EntityType.feat,
            displayName: 'Alert',
            slug: 'alert',
          ),
        ],
        rulesEdition: DmRulesEdition.v2024,
      );
      // 2 + 2 (prof bonus at level 1) = 4
      expect(char.initiativeBonus, equals(4));
    });

    test('Jack of All Trades adds half proficiency bonus to initiative for untrained', () {
      const bardClass = ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: 'bard',
          displayName: 'Bard',
        ),
        level: 2,
        hitDie: 'd8',
      );

      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 14), // +2 DEX, prof bonus is 2
        classes: [bardClass],
      );

      expect(char.hasCapabilityFlag('jackOfAllTrades'), isTrue);
      // 2 (DEX) + 1 (half of 2) = 3
      expect(char.initiativeBonus, equals(3));
    });
  });

  group('Character Derived Stats Engine - Skills & Saves', () {
    test('Skill modifier adds full proficiency when proficient', () {
      final char = _createTestCharacter(
        baseScores: const AbilityScores(dexterity: 14), // +2 DEX
        skillProficiencies: {
          SkillType.stealth: SkillProficiencyLevel.proficient,
        },
      );
      // 2 (DEX) + 2 (prof bonus) = 4
      expect(char.getSkillModifier(SkillType.stealth), equals(4));
    });

    test('Skill modifier adds double proficiency for expertise', () {
      final char = _createTestCharacter(
        baseScores: const AbilityScores(wisdom: 16), // +3 WIS
        skillProficiencies: {
          SkillType.perception: SkillProficiencyLevel.expertise,
        },
      );
      // 3 (WIS) + 2 * 2 (prof bonus) = 7
      expect(char.getSkillModifier(SkillType.perception), equals(7));
    });

    test('Untrained skill modifier evaluates half-proficiency if Jack of All Trades is active', () {
      const bardClass = ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: 'bard',
          displayName: 'Bard',
        ),
        level: 2,
        hitDie: 'd8',
      );

      final char = _createTestCharacter(
        baseScores: const AbilityScores(strength: 14, charisma: 16), // +2 STR, +3 CHA
        classes: [bardClass],
        skillProficiencies: {
          SkillType.persuasion: SkillProficiencyLevel.proficient,
        },
      );

      // Trained: 3 (CHA) + 2 (prof bonus) = 5
      expect(char.getSkillModifier(SkillType.persuasion), equals(5));

      // Untrained Athletics: 2 (STR) + 1 (half of 2) = 3
      expect(char.getSkillModifier(SkillType.athletics), equals(3));
    });

    test('Saving throw modifier factors in ability modifier and proficiency', () {
      final char = _createTestCharacter(
        baseScores: const AbilityScores(constitution: 16, wisdom: 10), // +3 CON, +0 WIS
        savingThrowProficiencies: {AbilityType.constitution},
      );

      // Proficient in CON save: 3 + 2 = 5
      expect(char.getSaveModifier(AbilityType.constitution), equals(5));
      // Untrained in WIS save: 0 + 0 = 0
      expect(char.getSaveModifier(AbilityType.wisdom), equals(0));
    });
  });

  group('Character Derived Stats Engine - Passive Senses', () {
    test('Passive perception reflects skill modifier and Observant feat bonus', () {
      final char = _createTestCharacter(
        baseScores: const AbilityScores(wisdom: 14), // +2 WIS
        skillProficiencies: {
          SkillType.perception: SkillProficiencyLevel.proficient, // +2 prof
        },
      );

      // 10 + 4 (perception modifier) = 14
      expect(char.passivePerception, equals(14));

      final observantChar = char.copyWith(
        feats: [
          const EntityReference(
            refType: EntityType.feat,
            displayName: 'Observant',
            slug: 'observant',
          ),
        ],
      );

      // 14 + 5 = 19
      expect(observantChar.passivePerception, equals(19));
      expect(observantChar.passiveInvestigation, equals(10 + 0 + 5)); // 15
    });
  });

  group('Character Sheet Controller - Capability Flags & Agonizing Blast', () {
    test('hasAgonizingBlast exposes flag and injects CHA modifier into Eldritch Blast damage', () {
      const warlockClass = ClassLevelProgression(
        classRef: EntityReference<DomainEntity>(
          refType: EntityType.classDefinition,
          slug: 'warlock',
          displayName: 'Warlock',
        ),
        level: 2,
        hitDie: 'd8',
        selectedFeatureOptions: {
          'eldritch_invocations': ['agonizing_blast'],
        },
      );

      final char = _createTestCharacter(
        baseScores: const AbilityScores(charisma: 16), // +3 CHA
        classes: [warlockClass],
      );

      final controller = CharacterSheetController(character: char);

      expect(controller.hasAgonizingBlast, isTrue);

      const eldritchBlast = Spell(
        id: EntityId(slug: 'eldritch-blast', ruleset: RulesetVersion.v2014),
        name: 'Eldritch Blast',
        level: 0,
        school: 'evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action, triggerCondition: '1 Action'),
        duration: SpellDuration(type: DurationType.instantaneous, rawText: 'Instantaneous'),
        range: '120 ft',
        components: SpellComponents(v: true, s: true),
        descriptionMarkdown: 'Make a ranged spell attack against the target.',
        damageMath: [
          EvaluationMath(diceFormula: '1d10', damageType: DamageType.force),
        ],
        customProperties: {
          'isSpellAttack': true,
          'rollFormula': '1d10',
        },
      );

      final damageResult = controller.rollSpellDamage(eldritchBlast);
      // Modifier must be +3 (CHA modifier)
      expect(damageResult.modifier, equals(3));
      expect(damageResult.total, greaterThanOrEqualTo(4)); // 1 + 3 minimum
    });
  });

  group('Character Builder Controller - Skill Overlap & Refund State Tracking', () {
    test('pendingReplacementSkills reflects resolved refunds', () {
      final controller = CharacterBuilderController();
      controller.setSelectedSkills({SkillType.athletics, SkillType.history});
      controller.setBackgroundSlug('soldier'); // grants Athletics & Intimidation -> 1 collision

      expect(controller.refundedSkillChoices, equals(1));
      expect(controller.pendingReplacementSkills, isEmpty);

      controller.resolveRefundedSkill(SkillType.stealth);
      expect(controller.refundedSkillChoices, equals(0));
      expect(controller.pendingReplacementSkills, contains(SkillType.stealth));

      controller.unresolveRefundedSkill(SkillType.stealth);
      expect(controller.refundedSkillChoices, equals(1));
      expect(controller.pendingReplacementSkills.contains(SkillType.stealth), isFalse);
    });
  });
}
