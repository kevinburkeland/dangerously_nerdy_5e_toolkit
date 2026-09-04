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
  DmRulesEdition rulesEdition;
  EntityReference<DomainEntity>? speciesRef;
  EntityReference<DomainEntity>? backgroundRef;
  EntityReference<DomainEntity>? startingClassRef;
  String? startingClassHitDie;
  AbilityScores? baseScores;
  Map<SkillType, SkillProficiencyLevel> selectedSkills;

  // Extended compilation properties
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
    this.rulesEdition = DmRulesEdition.v2024,
    this.speciesRef,
    this.backgroundRef,
    this.startingClassRef,
    this.startingClassHitDie,
    this.baseScores,
    Map<SkillType, SkillProficiencyLevel>? selectedSkills,
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
  })  : selectedSkills = selectedSkills != null ? Map.from(selectedSkills) : {},
        savingThrowProficiencies = savingThrowProficiencies != null ? Set.from(savingThrowProficiencies) : {},
        toolProficiencies = toolProficiencies != null ? List.from(toolProficiencies) : [],
        languages = languages != null ? List.from(languages) : ['Common'],
        startingEquipment = startingEquipment != null ? List.from(startingEquipment) : [],
        cantrips = cantrips != null ? List.from(cantrips) : [],
        spellsKnown = spellsKnown != null ? List.from(spellsKnown) : [],
        spellsPrepared = spellsPrepared != null ? List.from(spellsPrepared) : [],
        originFeats = originFeats != null ? List.from(originFeats) : [],
        selectedFeatureOptions = selectedFeatureOptions != null ? Map.from(selectedFeatureOptions) : {};

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
