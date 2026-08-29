import 'package:flutter/foundation.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/party/party_purse.dart';
import 'character_stat_calculator.dart';
import 'dnd_5e_rules_engine.dart';

/// Starting Equipment Preset Item Request
@immutable
class StartingEquipmentItemRequest {
  final EntityReference<EquipmentItem> itemRef;
  final int quantity;
  final bool equipImmediately;
  final EquipmentSlot? defaultSlot;
  final bool requiresAttunement;

  const StartingEquipmentItemRequest({
    required this.itemRef,
    this.quantity = 1,
    this.equipImmediately = false,
    this.defaultSlot,
    this.requiresAttunement = false,
  });
}

/// Request bundle for creating a new 5e character
@immutable
class CharacterCreationRequest {
  final String characterName;
  final RulesetVersion ruleset;
  final EntityReference<DomainEntity> speciesRef; // 2014 Race or 2024 Species
  final EntityReference<DomainEntity>? backgroundRef;
  final String startingClassSlug;
  final String startingClassDisplayName;
  final String startingClassHitDie; // e.g. "d8", "d10"
  final AbilityScores baseScores;
  final AbilityScores bonusScores; // From 2014 Race or 2024 Background
  final Map<SkillType, SkillProficiencyLevel> skillProficiencies;
  final Set<AbilityType> savingThrowProficiencies;
  final List<String> toolProficiencies;
  final List<String> languages;
  final List<StartingEquipmentItemRequest> startingEquipment;
  final PartyPurse startingPurse;
  final List<EntityReference<Spell>> cantrips;
  final List<EntityReference<Spell>> spellsKnown;
  final List<EntityReference<Spell>> spellsPrepared;
  final List<EntityReference<DomainEntity>> originFeats;
  final int baseSpeedFeet;

  const CharacterCreationRequest({
    required this.characterName,
    this.ruleset = RulesetVersion.v2024,
    required this.speciesRef,
    this.backgroundRef,
    required this.startingClassSlug,
    required this.startingClassDisplayName,
    required this.startingClassHitDie,
    required this.baseScores,
    required this.bonusScores,
    this.skillProficiencies = const {},
    this.savingThrowProficiencies = const {},
    this.toolProficiencies = const [],
    this.languages = const ['Common'],
    this.startingEquipment = const [],
    this.startingPurse = const PartyPurse(),
    this.cantrips = const [],
    this.spellsKnown = const [],
    this.spellsPrepared = const [],
    this.originFeats = const [],
    this.baseSpeedFeet = 30,
  });
}

/// Factory producing validated Characters conforming to SRD 2014 / 2024 specifications
class CharacterFactory {
  /// Standard 5e Point Buy costs for attributes between 8 and 15
  static const Map<int, int> pointBuyCostTable = {
    8: 0,
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    13: 5,
    14: 7,
    15: 9,
  };

  /// Validates point buy allocation within standard 27 points budget
  static bool validatePointBuy(AbilityScores scores, {int maxPoints = 27}) {
    int totalCost = 0;
    for (final ability in AbilityType.values) {
      final score = scores.getScore(ability);
      if (score < 8 || score > 15) return false;
      totalCost += pointBuyCostTable[score] ?? 999;
    }
    return totalCost <= maxPoints;
  }

  /// Calculates total point buy points consumed by an ability array
  static int calculatePointBuyCost(AbilityScores scores) {
    int totalCost = 0;
    for (final ability in AbilityType.values) {
      final score = scores.getScore(ability);
      totalCost += pointBuyCostTable[score] ?? 0;
    }
    return totalCost;
  }

  /// Creates a fully instantiated starting Character (Level 1)
  static Character createLevel1Character(CharacterCreationRequest request) {
    final cleanHitDie = request.startingClassHitDie.replaceAll('d', '').trim();
    final hitDieSides = int.tryParse(cleanHitDie) ?? 8;
    final totalCon = request.baseScores.constitution + request.bonusScores.constitution;
    final conMod = totalCon.dndModifier;
    final startingHp = hitDieSides + conMod;

    // Convert starting equipment requests into InventoryItemInstances
    final inventory = <InventoryItemInstance>[];
    int instanceCounter = 1;
    for (final equipReq in request.startingEquipment) {
      final instanceId = 'item-inst-$instanceCounter-${equipReq.itemRef.slug}';
      instanceCounter++;

      inventory.add(InventoryItemInstance(
        instanceId: instanceId,
        itemRef: equipReq.itemRef,
        quantity: equipReq.quantity,
        isEquipped: equipReq.equipImmediately,
        equippedSlot: equipReq.equipImmediately ? equipReq.defaultSlot : null,
        isAttuned: false,
        requiresAttunement: equipReq.requiresAttunement,
      ));
    }

    // Progression
    final startingClassProgression = ClassLevelProgression(
      classRef: EntityReference<DomainEntity>(
        refType: EntityType.classDefinition,
        slug: request.startingClassSlug,
        displayName: request.startingClassDisplayName,
      ),
      level: 1,
      hitDie: request.startingClassHitDie,
      hitPointsRolled: const [],
      isStartingClass: true,
    );

    final progression = CharacterProgression(
      classes: [startingClassProgression],
      experiencePoints: 0,
    );

    // Initial Hit Dice Resource
    final currentHitDice = <String, int>{
      request.startingClassHitDie: 1,
    };

    final character = Character(
      id: EntityId(
        slug: _slugify(request.characterName),
        ruleset: request.ruleset,
      ),
      name: request.characterName,
      speciesRef: request.speciesRef,
      backgroundRef: request.backgroundRef,
      progression: progression,
      baseScores: request.baseScores,
      bonusScores: request.bonusScores,
      skillProficiencies: request.skillProficiencies,
      savingThrowProficiencies: request.savingThrowProficiencies,
      toolProficiencies: request.toolProficiencies,
      languages: request.languages,
      inventory: inventory,
      purse: request.startingPurse,
      cantrips: request.cantrips,
      spellsKnown: request.spellsKnown,
      spellsPrepared: request.spellsPrepared,
      feats: request.originFeats,
      resources: CharacterResourcePool(
        currentHp: startingHp,
        tempHp: 0,
        currentHitDice: currentHitDice,
      ),
      maxAttunementSlots: 3,
      baseSpeedFeet: request.baseSpeedFeet,
    );

    return character;
  }

  static String _slugify(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }
}
