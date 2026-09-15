import 'package:flutter/foundation.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/character_draft.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/party/party_purse.dart';
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../models/characters/srd_backgrounds_library.dart';
import 'character_progression_engine.dart';
import 'dnd_5e_rules_engine.dart';
import 'skill_trait_resolver.dart';

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
  final EntityReference<DomainEntity>? startingSubclassRef;
  final Map<String, List<String>> selectedFeatureOptions;

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
    this.startingSubclassRef,
    this.selectedFeatureOptions = const {},
  });
}

/// Factory producing validated Characters conforming to SRD 2014 / 2024 specifications
class CharacterFactory {
  /// Compiles a fully validated [Character] domain entity from a [CharacterDraft].
  ///
  /// Strictly checks [CharacterDraft.isReadyForCompilation]. If incomplete,
  /// throws a [StateError] describing what is missing.
  static Character buildFromDraft(CharacterDraft draft) {
    if (!draft.isReadyForCompilation) {
      final missing = <String>[];
      if (!draft.hasValidSpecies) missing.add('Species');
      if (!draft.hasValidClass) missing.add('Class');
      if (!draft.hasValidBackground) missing.add('Background');
      if (!draft.hasValidScores) missing.add('Base Scores');
      if (draft.characterName == null || draft.characterName!.trim().isEmpty) missing.add('Character Name');
      throw StateError('Cannot compile character from draft. Missing mandatory field(s): ${missing.join(", ")}');
    }

    final ruleset = draft.rulesEdition == DmRulesEdition.v2014 ? RulesetVersion.v2014 : RulesetVersion.v2024;
    final hitDie = draft.startingClassHitDie ?? 'd8';
    final cleanHitDie = hitDie.replaceAll('d', '').trim();
    final hitDieSides = int.tryParse(cleanHitDie) ?? 8;

    // Resolve background
    final resolvedBg = draft.backgroundRef != null
        ? SrdBackgroundsLibrary.findBySlug(draft.backgroundRef!.slug)
        : null;

    // Resolve 2014 / 2024 Background ASIs if bonusScores not already populated
    AbilityScores finalBonusScores = draft.bonusScores;
    if (draft.rulesEdition == DmRulesEdition.v2014) {
      if (finalBonusScores == const AbilityScores.zero() && draft.speciesBonusScores != const AbilityScores.zero()) {
        finalBonusScores = draft.speciesBonusScores;
      }
    } else if (draft.rulesEdition == DmRulesEdition.v2024) {
      if (finalBonusScores == const AbilityScores.zero() && draft.backgroundBonusScores != const AbilityScores.zero()) {
        finalBonusScores = draft.backgroundBonusScores;
      }
      if (finalBonusScores == const AbilityScores.zero() && draft.backgroundRef != null) {
        final bgAbilities = draft.backgroundRef!.customProperties['abilities'];
        if (bgAbilities is Map) {
          int str = (bgAbilities['str'] as num?)?.toInt() ?? 0;
          int dex = (bgAbilities['dex'] as num?)?.toInt() ?? 0;
          int con = (bgAbilities['con'] as num?)?.toInt() ?? 0;
          int intl = (bgAbilities['int'] as num?)?.toInt() ?? 0;
          int wis = (bgAbilities['wis'] as num?)?.toInt() ?? 0;
          int cha = (bgAbilities['cha'] as num?)?.toInt() ?? 0;
          finalBonusScores = AbilityScores(
            strength: str,
            dexterity: dex,
            constitution: con,
            intelligence: intl,
            wisdom: wis,
            charisma: cha,
          );
        }
      }
    }

    final totalCon = draft.baseScores!.constitution + finalBonusScores.constitution;
    final conMod = totalCon.dndModifier;
    final startingHp = hitDieSides + conMod;

    // Convert starting equipment requests into InventoryItemInstances
    final inventory = <InventoryItemInstance>[];
    int instanceCounter = 1;
    for (final equipReq in draft.startingEquipment) {
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

    // Ingest background starting equipment if present (unless character took starting wealth / gold only)
    final bgEquip = !draft.takesStartingWealth
        ? (draft.backgroundRef?.customProperties['startingEquipment'] ??
            (draft.rulesEdition == DmRulesEdition.v2014
                ? (resolvedBg?.customProperties['startingEquipment'] ??
                    (draft.backgroundRef != null ? SrdBackgroundsLibrary.extractStartingEquipment(draft.backgroundRef!.slug) : null))
                : null))
        : null;
    if (bgEquip is List) {
      for (final item in bgEquip) {
        String itemName = '';
        if (item is String) {
          itemName = item;
        } else if (item is Map) {
          itemName = (item['item'] ?? item['name'] ?? item['slug'] ?? '').toString();
        }
        if (itemName.isNotEmpty) {
          final slug = _slugify(itemName);
          final alreadyPresent = inventory.any((inv) => inv.itemRef.slug == slug);
          if (!alreadyPresent) {
            final instanceId = 'item-inst-$instanceCounter-$slug';
            instanceCounter++;
            inventory.add(InventoryItemInstance(
              instanceId: instanceId,
              itemRef: EntityReference(
                refType: EntityType.equipment,
                slug: slug,
                displayName: itemName,
              ),
              quantity: 1,
              isEquipped: false,
              requiresAttunement: false,
            ));
          }
        }
      }
    }

    // Merge skills: draft.selectedSkills + background skills
    final compiledSkills = Map<SkillType, SkillProficiencyLevel>.from(draft.selectedSkills);
    if (draft.backgroundRef != null) {
      for (final skill in draft.backgroundRef!.grantedSkills) {
        if (!compiledSkills.containsKey(skill) || compiledSkills[skill] == SkillProficiencyLevel.none) {
          compiledSkills[skill] = SkillProficiencyLevel.proficient;
        }
      }
      final bgSkillsRaw = draft.backgroundRef!.customProperties['skillProficiencies'] ??
          draft.backgroundRef!.customProperties['skills'] ??
          resolvedBg?.skillProficiencies;
      if (bgSkillsRaw is List) {
        for (final s in bgSkillsRaw) {
          final sName = s.toString().toLowerCase().trim().replaceAll(' ', '').replaceAll('-', '');
          for (final st in SkillType.values) {
            if (st.name.toLowerCase() == sName) {
              if (!compiledSkills.containsKey(st) || compiledSkills[st] == SkillProficiencyLevel.none) {
                compiledSkills[st] = SkillProficiencyLevel.proficient;
              }
            }
          }
        }
      }
    }

    // Progression
    final startingClassProgression = ClassLevelProgression(
      classRef: draft.startingClassRef!,
      subclassRef: draft.startingSubclassRef,
      level: 1,
      hitDie: hitDie,
      hitPointsRolled: const [],
      isStartingClass: true,
      selectedFeatureOptions: draft.selectedFeatureOptions,
    );

    final progression = CharacterProgression(
      classes: [startingClassProgression],
      experiencePoints: 0,
    );

    // Initial Hit Dice Resource
    final currentHitDice = <String, int>{
      hitDie: 1,
    };

    // Initial Spell Slots Resource
    final startingSpellSlots = CharacterProgressionEngine.computeSpellSlots(
      progression.classes,
      edition: draft.rulesEdition,
    );

    final speciesTraits = SkillTraitResolver.getSpeciesTraits(
      speciesSlug: draft.speciesRef!.slug,
      subraceSlug: draft.subraceRef?.slug,
      edition: draft.rulesEdition,
    );

    final feats = List<EntityReference<DomainEntity>>.from(draft.originFeats);
    final customProps = <String, dynamic>{
      if (draft.subraceRef != null) 'subrace': draft.subraceRef!.toMap(),
      if (draft.subraceRef != null) 'subspecies': draft.subraceRef!.displayName,
    };

    if (draft.rulesEdition == DmRulesEdition.v2014 && draft.backgroundRef != null) {
      final feature = SrdBackgroundsLibrary.get2014Feature(draft.backgroundRef!.slug) ??
          (resolvedBg?.customProperties['feature'] != null
              ? (
                  name: resolvedBg!.customProperties['feature'].toString(),
                  description: resolvedBg.customProperties['featureDescription']?.toString() ?? '',
                )
              : null);
      if (feature != null) {
        customProps['backgroundFeature'] = feature.name;
        customProps['backgroundFeatureDescription'] = feature.description;
      }
    }

    final compiledTools = SkillTraitResolver.resolveTools(
      draftTools: draft.toolProficiencies,
      classSlug: draft.startingClassRef?.slug,
      speciesSlug: draft.speciesRef?.slug,
      subraceSlug: draft.subraceRef?.slug,
      backgroundSlug: draft.backgroundRef?.slug,
      customProperties: draft.speciesRef?.customProperties,
    );

    final compiledCantrips = List<EntityReference<Spell>>.from(draft.cantrips);
    final compiledSpellsKnown = List<EntityReference<Spell>>.from(draft.spellsKnown);

    if (draft.speciesRef != null) {
      final innateSpells = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: draft.speciesRef!.slug,
        subraceSlug: draft.subraceRef?.slug,
        totalCharacterLevel: 1,
        edition: draft.rulesEdition,
        subraceRef: draft.subraceRef,
        customProperties: draft.speciesRef?.customProperties,
      );
      for (final isp in innateSpells) {
        if (isp.isCantrip) {
          if (!compiledCantrips.any((c) => c.slug == isp.spellRef.slug)) {
            compiledCantrips.add(isp.spellRef);
          }
        } else {
          if (!compiledSpellsKnown.any((s) => s.slug == isp.spellRef.slug)) {
            compiledSpellsKnown.add(isp.spellRef);
          }
        }
      }
    }

    final character = Character(
      id: EntityId(
        slug: _slugify(draft.characterName!),
        ruleset: ruleset,
      ),
      name: draft.characterName!,
      speciesRef: draft.speciesRef!,
      backgroundRef: draft.backgroundRef,
      progression: progression,
      baseScores: draft.baseScores!,
      bonusScores: finalBonusScores,
      skillProficiencies: compiledSkills,
      savingThrowProficiencies: draft.savingThrowProficiencies,
      toolProficiencies: compiledTools,
      languages: draft.languages,
      inventory: inventory,
      purse: draft.startingPurse,
      cantrips: compiledCantrips,
      spellsKnown: compiledSpellsKnown,
      spellsPrepared: draft.spellsPrepared,
      feats: feats,
      resources: CharacterResourcePool(
        currentHp: startingHp + speciesTraits.hpPerLevelBonus,
        tempHp: 0,
        currentHitDice: currentHitDice,
        spellSlots: startingSpellSlots,
      ),
      maxAttunementSlots: 3,
      baseSpeedFeet: speciesTraits.baseSpeedFeet,
      rulesEdition: draft.rulesEdition,
      customProperties: customProps,
    );

    return character;
  }
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
      subclassRef: request.startingSubclassRef,
      level: 1,
      hitDie: request.startingClassHitDie,
      hitPointsRolled: const [],
      isStartingClass: true,
      selectedFeatureOptions: request.selectedFeatureOptions,
    );

    final progression = CharacterProgression(
      classes: [startingClassProgression],
      experiencePoints: 0,
    );

    // Initial Hit Dice Resource
    final currentHitDice = <String, int>{
      request.startingClassHitDie: 1,
    };

    // Initial Spell Slots Resource
    final edition = request.ruleset == RulesetVersion.v2014 ? DmRulesEdition.v2014 : DmRulesEdition.v2024;
    final startingSpellSlots = CharacterProgressionEngine.computeSpellSlots(
      progression.classes,
      edition: edition,
    );

    final speciesTraits = SkillTraitResolver.getSpeciesTraits(
      speciesSlug: request.speciesRef.slug,
      subraceSlug: null,
      edition: request.ruleset == RulesetVersion.v2014 ? DmRulesEdition.v2014 : DmRulesEdition.v2024,
    );

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
        currentHp: startingHp + speciesTraits.hpPerLevelBonus,
        tempHp: 0,
        currentHitDice: currentHitDice,
        spellSlots: startingSpellSlots,
      ),
      maxAttunementSlots: 3,
      baseSpeedFeet: speciesTraits.baseSpeedFeet,
    );

    return character;
  }

  static String _slugify(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }
}
