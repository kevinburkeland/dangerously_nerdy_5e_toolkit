import '../../models/dm_screen_data.dart' show DmRulesEdition;
import 'character_models.dart';
import 'entity_reference.dart';
import 'spell_monster_equipment.dart';
import '../party/party_purse.dart';
import '../../services/rules/character_factory.dart' show StartingEquipmentItemRequest;

/// Mutable working-memory draft model for character creation.
///
/// Accepts nullable inputs and arbitrary out-of-order assignments
/// (supporting dynamic wizard ordering presets). Validates completely before
/// compiling into an immutable [Character] domain entity.
class CharacterDraft {
  String? characterName;
  DmRulesEdition _rulesEdition;
  DmRulesEdition get rulesEdition => _rulesEdition;
  set rulesEdition(DmRulesEdition edition) {
    _rulesEdition = edition;
    reconcile();
  }

  EntityReference<DomainEntity>? speciesRef;
  EntityReference<DomainEntity>? backgroundRef;
  EntityReference<DomainEntity>? startingClassRef;
  String? startingClassHitDie;
  AbilityScores? baseScores;
  Map<SkillType, SkillProficiencyLevel> selectedSkills;

  // Extended compilation properties
  AbilityScores backgroundBonusScores;
  AbilityScores speciesBonusScores;
  AbilityScores bonusScores;
  Set<AbilityType> savingThrowProficiencies;
  List<String> toolProficiencies;
  List<String> languages;
  List<StartingEquipmentItemRequest> startingEquipment;
  PartyPurse startingPurse;
  List<EntityReference<Spell>> cantrips;
  List<EntityReference<Spell>> spellsKnown;
  List<EntityReference<Spell>> spellsPrepared;
  List<EntityReference<DomainEntity>> originFeats;
  EntityReference<DomainEntity>? startingSubclassRef;
  Map<String, List<String>> selectedFeatureOptions;
  int baseSpeedFeet;

  CharacterDraft({
    this.characterName,
    DmRulesEdition rulesEdition = DmRulesEdition.v2024,
    this.speciesRef,
    this.backgroundRef,
    this.startingClassRef,
    this.startingClassHitDie,
    this.baseScores,
    Map<SkillType, SkillProficiencyLevel>? selectedSkills,
    this.backgroundBonusScores = const AbilityScores.zero(),
    this.speciesBonusScores = const AbilityScores.zero(),
    this.bonusScores = const AbilityScores.zero(),
    Set<AbilityType>? savingThrowProficiencies,
    List<String>? toolProficiencies,
    List<String>? languages,
    List<StartingEquipmentItemRequest>? startingEquipment,
    this.startingPurse = const PartyPurse(),
    List<EntityReference<Spell>>? cantrips,
    List<EntityReference<Spell>>? spellsKnown,
    List<EntityReference<Spell>>? spellsPrepared,
    List<EntityReference<DomainEntity>>? originFeats,
    this.startingSubclassRef,
    Map<String, List<String>>? selectedFeatureOptions,
    this.baseSpeedFeet = 30,
  })  : _rulesEdition = rulesEdition,
        selectedSkills = selectedSkills != null ? Map.from(selectedSkills) : {},
        savingThrowProficiencies = savingThrowProficiencies != null ? Set.from(savingThrowProficiencies) : {},
        toolProficiencies = toolProficiencies != null ? List.from(toolProficiencies) : [],
        languages = languages != null ? List.from(languages) : ['Common'],
        startingEquipment = startingEquipment != null ? List.from(startingEquipment) : [],
        cantrips = cantrips != null ? List.from(cantrips) : [],
        spellsKnown = spellsKnown != null ? List.from(spellsKnown) : [],
        spellsPrepared = spellsPrepared != null ? List.from(spellsPrepared) : [],
        originFeats = originFeats != null ? List.from(originFeats) : [],
        selectedFeatureOptions = selectedFeatureOptions != null ? Map.from(selectedFeatureOptions) : {} {
    reconcile();
  }

  /// Reconciles ruleset-dependent invariants in-place.
  void reconcile() {
    if (_rulesEdition == DmRulesEdition.v2014) {
      if (originFeats.isNotEmpty) {
        originFeats.clear();
      }
      backgroundBonusScores = const AbilityScores.zero();
      bonusScores = const AbilityScores.zero();
    } else {
      speciesBonusScores = const AbilityScores.zero();
    }
  }

  CharacterDraft copyWith({
    String? characterName,
    DmRulesEdition? rulesEdition,
    EntityReference<DomainEntity>? speciesRef,
    EntityReference<DomainEntity>? backgroundRef,
    EntityReference<DomainEntity>? startingClassRef,
    String? startingClassHitDie,
    AbilityScores? baseScores,
    Map<SkillType, SkillProficiencyLevel>? selectedSkills,
    AbilityScores? backgroundBonusScores,
    AbilityScores? speciesBonusScores,
    AbilityScores? bonusScores,
    Set<AbilityType>? savingThrowProficiencies,
    List<String>? toolProficiencies,
    List<String>? languages,
    List<StartingEquipmentItemRequest>? startingEquipment,
    PartyPurse? startingPurse,
    List<EntityReference<Spell>>? cantrips,
    List<EntityReference<Spell>>? spellsKnown,
    List<EntityReference<Spell>>? spellsPrepared,
    List<EntityReference<DomainEntity>>? originFeats,
    EntityReference<DomainEntity>? startingSubclassRef,
    Map<String, List<String>>? selectedFeatureOptions,
    int? baseSpeedFeet,
  }) {
    return CharacterDraft(
      characterName: characterName ?? this.characterName,
      rulesEdition: rulesEdition ?? this.rulesEdition,
      speciesRef: speciesRef ?? this.speciesRef,
      backgroundRef: backgroundRef ?? this.backgroundRef,
      startingClassRef: startingClassRef ?? this.startingClassRef,
      startingClassHitDie: startingClassHitDie ?? this.startingClassHitDie,
      baseScores: baseScores ?? this.baseScores,
      selectedSkills: selectedSkills ?? this.selectedSkills,
      backgroundBonusScores: backgroundBonusScores ?? this.backgroundBonusScores,
      speciesBonusScores: speciesBonusScores ?? this.speciesBonusScores,
      bonusScores: bonusScores ?? this.bonusScores,
      savingThrowProficiencies: savingThrowProficiencies ?? this.savingThrowProficiencies,
      toolProficiencies: toolProficiencies ?? this.toolProficiencies,
      languages: languages ?? this.languages,
      startingEquipment: startingEquipment ?? this.startingEquipment,
      startingPurse: startingPurse ?? this.startingPurse,
      cantrips: cantrips ?? this.cantrips,
      spellsKnown: spellsKnown ?? this.spellsKnown,
      spellsPrepared: spellsPrepared ?? this.spellsPrepared,
      originFeats: originFeats ?? this.originFeats,
      startingSubclassRef: startingSubclassRef ?? this.startingSubclassRef,
      selectedFeatureOptions: selectedFeatureOptions ?? this.selectedFeatureOptions,
      baseSpeedFeet: baseSpeedFeet ?? this.baseSpeedFeet,
    );
  }

  // --- Granular Validation Getters ---
  bool get hasValidSpecies => speciesRef != null;
  bool get hasValidClass => startingClassRef != null;
  bool get hasValidBackground => backgroundRef != null;
  bool get hasValidScores => baseScores != null;

  // --- Master Validation Getter ---
  bool get isReadyForCompilation =>
      hasValidSpecies &&
      hasValidClass &&
      hasValidBackground &&
      hasValidScores &&
      characterName != null &&
      characterName!.trim().isNotEmpty;
}
