import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/dm_screen_data.dart' show DmRulesEdition;
import '../models/domain/character_draft.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../models/characters/srd_backgrounds_library.dart';
import '../models/characters/srd_classes_library.dart';
import '../models/characters/srd_equipment_library.dart';
import '../models/characters/srd_feats_library.dart';
import '../models/characters/srd_species_library.dart';
import '../models/characters/subclass_spells_library.dart';
import '../models/party/party_purse.dart';
import '../models/spellbook_data.dart';
import '../services/rules/character_factory.dart';
import '../services/rules/character_validation_engine.dart';
import '../services/rules/skill_trait_resolver.dart';

/// State manager for 5e Character Builder attribute generation, consumable resource pools,
/// progression validation, skill overlap refunds, and character draft state.
class CharacterBuilderController extends ChangeNotifier {
  late final CharacterDraft _draft;

  String _abilityScoreMode =
      'standard'; // 'standard', 'pointBuy', 'rolled', 'manual'
  String _rollMethod =
      'standard_4d6'; // 'standard_4d6', 'classic_3d6_down', 'classic_3d6_nice', 'silly_d20'

  // Consumable Pool state
  List<int> _availableScores = [15, 14, 13, 12, 10, 8];
  final Map<AbilityType, int> _assignedScores = {};
  int? _selectedPoolScore;

  // Dice roll state
  List<int> _rolledPool = [];
  List<String> _rolledBreakdowns = [];

  // Point buy state
  AbilityScores _pointBuyScores = const AbilityScores(
    strength: 8,
    dexterity: 8,
    constitution: 8,
    intelligence: 8,
    wisdom: 8,
    charisma: 8,
  );

  // Manual entry state
  final Map<AbilityType, int> _manualScores = {
    AbilityType.strength: 10,
    AbilityType.dexterity: 10,
    AbilityType.constitution: 10,
    AbilityType.intelligence: 10,
    AbilityType.wisdom: 10,
    AbilityType.charisma: 10,
  };

  // Skill Overlap & Refund State
  int _refundedSkillChoices = 0;
  final Set<SkillType> _bonusReplacementSkills = {};
  String? _selectedSpeciesSlug;
  String? _selectedBackgroundSlug;

  CharacterBuilderController({
    String initialMode = 'standard',
    bool startEmpty = true,
    DmRulesEdition initialEdition = DmRulesEdition.v2024,
    CharacterDraft? initialDraft,
  }) : _draft = initialDraft ?? CharacterDraft(rulesEdition: initialEdition) {
    _abilityScoreMode = initialMode;
    if (initialMode == 'standard') {
      if (startEmpty) {
        populateStandardArray(clear: true);
      } else {
        autoAssignStandardArray();
      }
    }
  }

  // --- Draft Getters & Validation ---
  CharacterDraft get draft => _draft;
  bool get hasValidSpecies => _draft.hasValidSpecies;
  bool get hasValidClass => _draft.hasValidClass;
  bool get hasValidBackground => _draft.hasValidBackground;
  bool get hasValidScores => _draft.hasValidScores;
  bool get isReadyForCompilation => _draft.isReadyForCompilation;
  List<ValidationIssue> get validationIssues =>
      CharacterValidationEngine.validateDraft(_draft);

  // --- Skill Refund Getters ---
  int get refundedSkillChoices => _refundedSkillChoices;
  Set<SkillType> get bonusReplacementSkills =>
      Set.unmodifiable(_bonusReplacementSkills);
  Set<SkillType> get pendingReplacementSkills =>
      Set.unmodifiable(_bonusReplacementSkills);
  Set<SkillType> get selectedSkills =>
      Set.unmodifiable(_draft.selectedSkills.keys);

  /// Skills granted by the selected Background.
  Set<SkillType> get grantedBackgroundSkills {
    final slug = _draft.backgroundRef?.slug ?? _selectedBackgroundSlug;
    if (slug == null) return {};
    final bg = SrdBackgroundsLibrary.findBySlug(slug);
    final res = <SkillType>{};
    if (bg != null) {
      for (final s in bg.skillProficiencies) {
        final sk = _parseSkillType(s);
        if (sk != null) res.add(sk);
      }
    }
    // Canonical SRD 5.1 fallback
    if (res.isEmpty && slug.toLowerCase() == 'acolyte') {
      res.addAll([SkillType.insight, SkillType.religion]);
    }
    return res;
  }

  /// Skills granted natively by the selected Species.
  Set<SkillType> get grantedSpeciesSkills {
    final slug =
        (_draft.speciesRef?.slug ?? _selectedSpeciesSlug)?.toLowerCase();
    if (slug == null) return {};
    final res = <SkillType>{};
    if (slug.contains('elf') && !slug.contains('half-elf')) {
      res.add(SkillType.perception);
    } else if (slug.contains('half-orc') || slug.contains('orc')) {
      res.add(SkillType.intimidation);
    }
    final sp = SrdSpeciesLibrary.findBySlug(slug);
    if (sp != null && sp.customProperties.containsKey('skillProficiencies')) {
      final list = sp.customProperties['skillProficiencies'];
      if (list is List) {
        for (final s in list) {
          final sk = _parseSkillType(s.toString());
          if (sk != null) res.add(sk);
        }
      }
    }
    return res;
  }

  /// All background and species granted skills combined.
  Set<SkillType> get grantedSkills => {
        ...grantedBackgroundSkills,
        ...grantedSpeciesSkills,
      };

  /// Overlaps between granted skills and class/draft selected skills.
  Set<SkillType> get collidingSkills =>
      grantedSkills.intersection(_draft.selectedSkills.keys.toSet());

  /// Remaining eligible skills available for replacement allocation.
  Set<SkillType> get availableReplacementSkills {
    final used = <SkillType>{
      ..._draft.selectedSkills.keys,
      ...grantedSkills,
      ..._bonusReplacementSkills,
    };
    return SkillType.values.where((s) => !used.contains(s)).toSet();
  }

  static SkillType? _parseSkillType(String name) {
    final clean = name
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
    for (final s in SkillType.values) {
      if (s.name.toLowerCase() == clean ||
          s.displayName.toLowerCase().replaceAll(' ', '') == clean) {
        return s;
      }
    }
    return null;
  }

  void _recalculateSkillOverlaps() {
    final granted = grantedSkills;
    final selected = _draft.selectedSkills.keys.toSet();
    final overlaps = granted.intersection(selected);

    // Prune bonus replacement skills that now collide with granted or selected skills
    _bonusReplacementSkills
        .removeWhere((s) => granted.contains(s) || selected.contains(s));

    // Reset orphaned skill refunds if replacement count exceeds required overlaps
    final requiredRefunds = overlaps.length;
    while (_bonusReplacementSkills.length > requiredRefunds) {
      _bonusReplacementSkills.remove(_bonusReplacementSkills.last);
    }

    // Calculate unspent refunds
    _refundedSkillChoices =
        math.max(0, requiredRefunds - _bonusReplacementSkills.length);
  }

  void _reconcileDraftInvariants() {
    CharacterValidationEngine.reconcileDraft(_draft);
  }

  /// Resolves one refunded skill by adding it to [bonusReplacementSkills]
  /// and decrementing [refundedSkillChoices].
  void resolveRefundedSkill(SkillType newSkill) {
    if (!_bonusReplacementSkills.contains(newSkill)) {
      _bonusReplacementSkills.add(newSkill);
      if (_refundedSkillChoices > 0) {
        _refundedSkillChoices--;
      }
      notifyListeners();
    }
  }

  /// Removes an allocated bonus replacement skill and returns the refund choice.
  void unresolveRefundedSkill(SkillType skill) {
    if (_bonusReplacementSkills.remove(skill)) {
      _refundedSkillChoices++;
      notifyListeners();
    }
  }

  /// Clears all resolved replacement skills and resets the refund counter.
  void clearRefunds() {
    _bonusReplacementSkills.clear();
    _recalculateSkillOverlaps();
    notifyListeners();
  }

  /// Manually triggers recalculation of skill overlaps and refund counts.
  void recalculateSkillRefunds() {
    _recalculateSkillOverlaps();
    notifyListeners();
  }

  // --- Draft Mutation Methods ---
  void setName(String? name) {
    _draft.characterName = name;
    notifyListeners();
  }

  void setRulesEdition(DmRulesEdition edition) {
    _draft.rulesEdition = edition;
    _reconcileDraftInvariants();
    _recalculateSkillOverlaps();
    notifyListeners();
  }

  void setSpecies(EntityReference<DomainEntity>? speciesRef) {
    _draft.speciesRef = speciesRef;
    _draft.subraceRef = null;
    _selectedSpeciesSlug = speciesRef?.slug;
    _recalculateSkillOverlaps();
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setSubrace(EntityReference<DomainEntity>? subraceRef) {
    _draft.subraceRef = subraceRef;
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setSpeciesSlug(String? slug) {
    _selectedSpeciesSlug = slug;
    if (slug != null) {
      _draft.speciesRef = EntityReference<DomainEntity>(
        refType: EntityType.species,
        slug: slug,
        displayName: slug,
      );
    } else {
      _draft.speciesRef = null;
    }
    _recalculateSkillOverlaps();
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setClass(EntityReference<DomainEntity>? classRef, {String? hitDie}) {
    _draft.startingClassRef = classRef;
    if (hitDie != null) {
      _draft.startingClassHitDie = hitDie;
    }
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setBackground(EntityReference<DomainEntity>? backgroundRef) {
    _draft.backgroundRef = backgroundRef;
    _selectedBackgroundSlug = backgroundRef?.slug;
    _recalculateSkillOverlaps();
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setBackgroundSlug(String? slug) {
    _selectedBackgroundSlug = slug;
    if (slug != null) {
      _draft.backgroundRef = EntityReference<DomainEntity>(
        refType: EntityType.background,
        slug: slug,
        displayName: slug,
      );
    } else {
      _draft.backgroundRef = null;
    }
    _recalculateSkillOverlaps();
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setScores(AbilityScores? scores) {
    _draft.baseScores = scores;
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setFlexibleAbilityChoices(List<AbilityType> choices) {
    _draft.pendingFlexibleAbilityChoices = List.from(choices);
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setSelectedSkills(dynamic skills) {
    if (skills is Map<SkillType, SkillProficiencyLevel>) {
      _draft.selectedSkills = Map.from(skills);
    } else if (skills is Set<SkillType>) {
      _draft.selectedSkills = {
        for (final s in skills) s: SkillProficiencyLevel.proficient
      };
    } else if (skills is Iterable<SkillType>) {
      _draft.selectedSkills = {
        for (final s in skills) s: SkillProficiencyLevel.proficient
      };
    }
    _recalculateSkillOverlaps();
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void setOriginFeats(List<EntityReference<DomainEntity>> feats) {
    _draft.originFeats = List.from(feats);
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void addOriginFeat(EntityReference<DomainEntity> feat) {
    _draft.originFeats.add(feat);
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void removeOriginFeat(String slug) {
    _draft.originFeats.removeWhere((f) => f.slug == slug);
    _reconcileDraftInvariants();
    notifyListeners();
  }

  void _syncDraftScores() {
    _draft.baseScores =
        isAbilityAllocationComplete ? effectiveBaseScores : null;
    _reconcileDraftInvariants();
  }

  // --- Getters ---
  String get abilityScoreMode => _abilityScoreMode;
  String get rollMethod => _rollMethod;
  List<int> get availableScores => List.unmodifiable(_availableScores);
  Map<AbilityType, int> get assignedScores => Map.unmodifiable(_assignedScores);
  int? get selectedPoolScore => _selectedPoolScore;
  List<int> get rolledPool => List.unmodifiable(_rolledPool);
  List<String> get rolledBreakdowns => List.unmodifiable(_rolledBreakdowns);
  AbilityScores get pointBuyScores => _pointBuyScores;
  Map<AbilityType, int> get manualScores => Map.unmodifiable(_manualScores);

  int get pointBuyCost =>
      CharacterFactory.calculatePointBuyCost(_pointBuyScores);
  int get pointBuyPointsRemaining => 27 - pointBuyCost;

  // --- Mode Switching ---
  void setMode(String mode) {
    if (_abilityScoreMode == mode) return;
    _abilityScoreMode = mode;
    _selectedPoolScore = null;
    if (mode == 'standard') {
      populateStandardArray(clear: true);
    } else if (mode == 'rolled') {
      if (_rolledPool.isEmpty) {
        rollScores();
      } else if (_rollMethod != 'classic_3d6_down') {
        _availableScores = List.of(_rolledPool)..sort((a, b) => b.compareTo(a));
        _assignedScores.clear();
      }
    }
    _syncDraftScores();
    notifyListeners();
  }

  void setRollMethod(String method) {
    _rollMethod = method;
    rollScores(method: method);
  }

  // --- Consumable Pool Mutation Methods ---

  /// Assigns a score from the consumable pool to [ability].
  /// If [ability] already has a score, that score is returned to [availableScores].
  /// Exactly one instance of [score] is removed from [availableScores].
  void assignScore(AbilityType ability, int score) {
    // If the ability already has a score, return it to the available pool
    if (_assignedScores.containsKey(ability)) {
      _availableScores.add(_assignedScores[ability]!);
    }
    // Remove exactly one instance of the new score from the available pool
    _availableScores.remove(score);
    _assignedScores[ability] = score;
    _availableScores
        .sort((a, b) => b.compareTo(a)); // Keep pool sorted high-to-low

    if (_selectedPoolScore == score && !_availableScores.contains(score)) {
      _selectedPoolScore = null;
    }
    _syncDraftScores();
    notifyListeners();
  }

  /// Removes the assigned score from [ability] and returns it to [availableScores].
  void unassignScore(AbilityType ability) {
    if (_assignedScores.containsKey(ability)) {
      _availableScores.add(_assignedScores.remove(ability)!);
      _availableScores
          .sort((a, b) => b.compareTo(a)); // Keep pool sorted high-to-low
      _syncDraftScores();
      notifyListeners();
    }
  }

  /// Selects a pool score chip for two-tap assignment. Tapping an already-selected
  /// chip deselects it.
  void selectPoolScore(int? score) {
    if (_selectedPoolScore == score) {
      _selectedPoolScore = null;
    } else {
      _selectedPoolScore = score;
    }
    notifyListeners();
  }

  /// Assigns the currently highlighted [_selectedPoolScore] to [ability].
  void assignSelectedPoolScore(AbilityType ability) {
    if (_selectedPoolScore != null &&
        _availableScores.contains(_selectedPoolScore)) {
      assignScore(ability, _selectedPoolScore!);
      _selectedPoolScore = null;
    }
  }

  /// Clears assigned scores and restores the standard array pool [15, 14, 13, 12, 10, 8].
  void populateStandardArray({bool clear = true}) {
    if (clear) {
      _availableScores = [15, 14, 13, 12, 10, 8];
      _assignedScores.clear();
      _selectedPoolScore = null;
    }
    _syncDraftScores();
    notifyListeners();
  }

  /// Convenience method that assigns standard array in traditional high-to-low order
  /// (STR 15 -> CHA 8) and exhausts the pool.
  void autoAssignStandardArray() {
    _availableScores.clear();
    _assignedScores[AbilityType.strength] = 15;
    _assignedScores[AbilityType.dexterity] = 14;
    _assignedScores[AbilityType.constitution] = 13;
    _assignedScores[AbilityType.intelligence] = 12;
    _assignedScores[AbilityType.wisdom] = 10;
    _assignedScores[AbilityType.charisma] = 8;
    _selectedPoolScore = null;
    _syncDraftScores();
    notifyListeners();
  }

  /// Rolls dice according to [_rollMethod] and resets the consumable pool or auto-assigns
  /// down the line.
  void rollScores({String? method, math.Random? random}) {
    if (method != null) _rollMethod = method;
    final rand = random ?? math.Random();
    final newPool = <int>[];
    final newBreakdowns = <String>[];

    if (_rollMethod == 'standard_4d6') {
      for (int i = 0; i < 6; i++) {
        final dice = List.generate(4, (_) => rand.nextInt(6) + 1)..sort();
        final dropped = dice.first;
        final kept = dice.sublist(1);
        final total = kept.reduce((a, b) => a + b);
        newPool.add(total);
        newBreakdowns
            .add('Roll ${i + 1}: [${dice.join(', ')}] drop $dropped = $total');
      }
    } else if (_rollMethod == 'classic_3d6_down' ||
        _rollMethod == 'classic_3d6_nice') {
      for (int i = 0; i < 6; i++) {
        final dice = List.generate(3, (_) => rand.nextInt(6) + 1);
        final total = dice.reduce((a, b) => a + b);
        newPool.add(total);
        newBreakdowns.add('Roll ${i + 1}: [${dice.join(' + ')}] = $total');
      }
    } else if (_rollMethod == 'silly_d20') {
      for (int i = 0; i < 6; i++) {
        final roll = rand.nextInt(20) + 1;
        newPool.add(roll);
        newBreakdowns.add('Roll ${i + 1}: 1d20 = $roll');
      }
    }

    _rolledPool = List.of(newPool);
    _rolledBreakdowns = newBreakdowns;
    _selectedPoolScore = null;

    if (_rollMethod == 'classic_3d6_down') {
      _availableScores.clear();
      _assignedScores[AbilityType.strength] = newPool[0];
      _assignedScores[AbilityType.dexterity] = newPool[1];
      _assignedScores[AbilityType.constitution] = newPool[2];
      _assignedScores[AbilityType.intelligence] = newPool[3];
      _assignedScores[AbilityType.wisdom] = newPool[4];
      _assignedScores[AbilityType.charisma] = newPool[5];
    } else {
      _availableScores = List.of(newPool)..sort((a, b) => b.compareTo(a));
      _assignedScores.clear();
    }
    _syncDraftScores();
    notifyListeners();
  }

  /// Sets rolled scores directly. Useful for tests or external seed generators.
  void populateRolledScores(List<int> scores,
      {List<String> breakdowns = const [], bool downTheLine = false}) {
    _rolledPool = List.of(scores);
    _rolledBreakdowns = List.of(breakdowns);
    _selectedPoolScore = null;

    if (downTheLine) {
      _availableScores.clear();
      _assignedScores[AbilityType.strength] = scores[0];
      _assignedScores[AbilityType.dexterity] = scores[1];
      _assignedScores[AbilityType.constitution] = scores[2];
      _assignedScores[AbilityType.intelligence] = scores[3];
      _assignedScores[AbilityType.wisdom] = scores[4];
      _assignedScores[AbilityType.charisma] = scores[5];
    } else {
      _availableScores = List.of(scores)..sort((a, b) => b.compareTo(a));
      _assignedScores.clear();
    }
    _syncDraftScores();
    notifyListeners();
  }

  // --- Point Buy & Manual Mutations ---
  void adjustPointBuy(AbilityType ability, int delta) {
    final curScore = _pointBuyScores.getScore(ability);
    final target = curScore + delta;
    if (target < 8 || target > 15) return;
    final updated = _adjustScoresRecord(_pointBuyScores, ability, delta);
    final cost = CharacterFactory.calculatePointBuyCost(updated);
    if (cost <= 27 || delta < 0) {
      _pointBuyScores = updated;
      _syncDraftScores();
      notifyListeners();
    }
  }

  void setManualScore(AbilityType ability, int value) {
    _manualScores[ability] = value.clamp(1, 30);
    _syncDraftScores();
    notifyListeners();
  }

  AbilityScores _adjustScoresRecord(
      AbilityScores scores, AbilityType ab, int delta) {
    switch (ab) {
      case AbilityType.strength:
        return scores.copyWith(strength: scores.strength + delta);
      case AbilityType.dexterity:
        return scores.copyWith(dexterity: scores.dexterity + delta);
      case AbilityType.constitution:
        return scores.copyWith(constitution: scores.constitution + delta);
      case AbilityType.intelligence:
        return scores.copyWith(intelligence: scores.intelligence + delta);
      case AbilityType.wisdom:
        return scores.copyWith(wisdom: scores.wisdom + delta);
      case AbilityType.charisma:
        return scores.copyWith(charisma: scores.charisma + delta);
    }
  }

  // --- Progression Validation ---

  /// Evaluates whether the ability score allocation step is complete and valid.
  bool get isAbilityAllocationComplete {
    switch (_abilityScoreMode) {
      case 'standard':
        return _availableScores.isEmpty &&
            _assignedScores.length == 6 &&
            AbilityType.values.every((a) => _assignedScores.containsKey(a));
      case 'rolled':
        if (_rollMethod == 'classic_3d6_down') {
          return _assignedScores.length == 6 &&
              AbilityType.values.every((a) => _assignedScores.containsKey(a));
        }
        return _availableScores.isEmpty &&
            _assignedScores.length == 6 &&
            AbilityType.values.every((a) => _assignedScores.containsKey(a));
      case 'pointBuy':
        final cost = CharacterFactory.calculatePointBuyCost(_pointBuyScores);
        return cost <= 27 &&
            AbilityType.values.every((a) {
              final s = _pointBuyScores.getScore(a);
              return s >= 8 && s <= 15;
            });
      case 'manual':
        return AbilityType.values.every((a) {
          final s = _manualScores[a];
          return s != null && s >= 3 && s <= 30;
        });
      default:
        return false;
    }
  }

  // --- Effective Output ---

  /// Computes the effective base scores for character creation.
  AbilityScores get effectiveBaseScores {
    switch (_abilityScoreMode) {
      case 'standard':
      case 'rolled':
        return AbilityScores(
          strength: _assignedScores[AbilityType.strength] ?? 10,
          dexterity: _assignedScores[AbilityType.dexterity] ?? 10,
          constitution: _assignedScores[AbilityType.constitution] ?? 10,
          intelligence: _assignedScores[AbilityType.intelligence] ?? 10,
          wisdom: _assignedScores[AbilityType.wisdom] ?? 10,
          charisma: _assignedScores[AbilityType.charisma] ?? 10,
        );
      case 'pointBuy':
        return _pointBuyScores;
      case 'manual':
        return AbilityScores(
          strength: _manualScores[AbilityType.strength] ?? 10,
          dexterity: _manualScores[AbilityType.dexterity] ?? 10,
          constitution: _manualScores[AbilityType.constitution] ?? 10,
          intelligence: _manualScores[AbilityType.intelligence] ?? 10,
          wisdom: _manualScores[AbilityType.wisdom] ?? 10,
          charisma: _manualScores[AbilityType.charisma] ?? 10,
        );
      default:
        return const AbilityScores.standardArray();
    }
  }

  /// Assembles and returns the finalized [CharacterDraft] from all builder
  /// selections so the screen's finalize handler stays purely UI-focused (Fix 7.5).
  CharacterDraft buildFinalizedDraft({
    required String rawName,
    required RulesetVersion ruleset,
    required String speciesSlug,
    String? subraceSlug,
    required String classSlug,
    required String backgroundSlug,
    String? selectedSubclassSlug,
    String? selectedFeatSlug,
    AbilityType? selectedFeatAbility,
    SkillType? selectedFeatSkill,
    SkillType? selectedFeatExpertise,
    String? selectedFeatOption,
    required Set<SkillType> selectedClassSkills,
    required Set<SkillType> compensatorySkillPicks,
    required Set<SkillType> speciesBonusSkillPicks,
    required Set<String> selectedCantripIds,
    required Set<String> selectedSpellIds,
    String? startingEquipmentPresetId,
    required Map<String, List<String>> selectedFeatureOptions,
    required Set<AbilityType> variantHumanBonuses,
    required AbilityType backgroundPrimaryBonus,
    required AbilityType backgroundSecondaryBonus,
    required List<String> languages,
    required List<String> toolProficiencies,
  }) {
    final curClass =
        SrdClassesLibrary.findBySlug(classSlug, ruleset: ruleset)!;
    final curSpecies = SrdSpeciesLibrary.findBySlug(speciesSlug)!;
    final curBackground = SrdBackgroundsLibrary.findBySlug(backgroundSlug)!;
    final is2024 = ruleset == RulesetVersion.v2024;
    final edition = is2024 ? DmRulesEdition.v2024 : DmRulesEdition.v2014;

    // Resolve class saves
    final saveProficiencies = curClass.savingThrows.map((s) {
      return AbilityType.values.firstWhere(
        (a) =>
            a.name.toLowerCase() == s.toLowerCase() ||
            a.shortName.toLowerCase() == s.toLowerCase(),
        orElse: () => AbilityType.strength,
      );
    }).toSet();

    // Map skill proficiencies using SkillTraitResolver
    final skillReport = SkillTraitResolver.resolveSkills(
      speciesSlug: speciesSlug,
      subraceSlug: subraceSlug,
      backgroundSlug: backgroundSlug,
      classSlug: curClass.id.slug,
      requestedClassSkills: selectedClassSkills,
      compensatoryPicks: compensatorySkillPicks,
      speciesBonusSkills: speciesBonusSkillPicks,
      edition: edition,
    );
    final skillMap = Map<SkillType, SkillProficiencyLevel>.from(
        skillReport.resolvedProficiencies);
    for (final sk in speciesBonusSkillPicks) {
      skillMap[sk] = SkillProficiencyLevel.proficient;
    }
    for (final sk in _bonusReplacementSkills) {
      skillMap[sk] = SkillProficiencyLevel.proficient;
    }
    for (final s in curBackground.skillProficiencies) {
      final clean = s
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('_', '')
          .replaceAll('-', '');
      for (final st in SkillType.values) {
        if (st.name.toLowerCase() == clean ||
            st.displayName.toLowerCase().replaceAll(' ', '') == clean) {
          skillMap[st] = SkillProficiencyLevel.proficient;
          break;
        }
      }
    }

    // Starting equipment and purse from chosen SRD package
    final classPackages =
        SrdEquipmentLibrary.getPackagesForClass(curClass.id.slug);
    final selectedPkg = (startingEquipmentPresetId != null
            ? SrdEquipmentLibrary.findPackageById(startingEquipmentPresetId)
            : null) ??
        classPackages.first;
    final equipRequests =
        List<StartingEquipmentItemRequest>.from(selectedPkg.items);
    final startingPurse = PartyPurse(gp: selectedPkg.startingGold);

    final hasFeat = is2024 || curSpecies.grantsBonusFeat;
    final cantripRefs = selectedCantripIds.map((id) {
      final spell = SpellbookLibrary.getSpellById(id);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: id,
        displayName: spell?.name ?? id,
      );
    }).toList();

    final allSelectedSpells = List<String>.from(selectedSpellIds);
    final autoGrantedSubclassSpells =
        SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: curClass.id.slug,
      subclassSlug: selectedSubclassSlug,
      classLevel: 1,
      edition: edition,
    );
    for (final s in autoGrantedSubclassSpells) {
      if (!allSelectedSpells.contains(s.id)) {
        allSelectedSpells.add(s.id);
      }
    }

    final innateSpells = SkillTraitResolver.getInnateSpeciesSpells(
      speciesSlug: curSpecies.id.slug,
      subraceSlug: subraceSlug,
      totalCharacterLevel: 1,
      edition: edition,
    );
    for (final isp in innateSpells) {
      if (isp.isCantrip) {
        if (!cantripRefs.any((c) => c.slug == isp.spellRef.slug)) {
          cantripRefs.add(isp.spellRef);
        }
      } else {
        if (!allSelectedSpells.contains(isp.spellRef.slug)) {
          allSelectedSpells.add(isp.spellRef.slug);
        }
      }
    }

    final spellRefs = allSelectedSpells.map((id) {
      final spell = SpellbookLibrary.getSpellById(id);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: id,
        displayName: spell?.name ?? id,
      );
    }).toList();

    final curSubrace = subraceSlug != null
        ? SrdSpeciesLibrary.findSubraceBySlug(subraceSlug)
        : null;
    final hasSubraceAbilities = curSubrace != null &&
        (curSubrace.fixedAbilityBonuses2014.isNotEmpty ||
            curSubrace.flexibleAbilityChoiceCount > 0);
    var finalBonusScores = computeOriginAbilityBonuses(
      edition: is2024 ? RulesetEdition.v2024 : RulesetEdition.v2014,
      fixedBonuses2014: hasSubraceAbilities
          ? curSubrace.fixedAbilityBonuses2014
          : curSpecies.fixedAbilityBonuses2014,
      flexibleChoiceCount2014: hasSubraceAbilities
          ? curSubrace.flexibleAbilityChoiceCount
          : curSpecies.flexibleAbilityChoiceCount,
      flexibleBonusValue2014: hasSubraceAbilities
          ? curSubrace.flexibleAbilityBonusValue
          : curSpecies.flexibleAbilityBonusValue,
      flexibleChoices2014: variantHumanBonuses,
      backgroundPrimary2024: backgroundPrimaryBonus,
      backgroundSecondary2024: backgroundSecondaryBonus,
    );
    final finalSaveProficiencies = Set<AbilityType>.from(saveProficiencies);

    if (hasFeat && selectedFeatSlug != null) {
      final feat = SrdFeatsLibrary.findBySlug(selectedFeatSlug) ??
          SrdFeatsLibrary.allFeats
              .where((f) => f.id.slug == selectedFeatSlug)
              .firstOrNull;
      if (feat != null && feat.hasAbilityScoreIncrease) {
        final chosenAbility = selectedFeatAbility ??
            (feat.selectableAbilities.isNotEmpty
                ? feat.selectableAbilities.first
                : null);
        if (chosenAbility != null) {
          final amt = feat.statIncreaseAmount;
          switch (chosenAbility) {
            case AbilityType.strength:
              finalBonusScores = finalBonusScores.copyWith(
                  strength: finalBonusScores.strength + amt);
            case AbilityType.dexterity:
              finalBonusScores = finalBonusScores.copyWith(
                  dexterity: finalBonusScores.dexterity + amt);
            case AbilityType.constitution:
              finalBonusScores = finalBonusScores.copyWith(
                  constitution: finalBonusScores.constitution + amt);
            case AbilityType.intelligence:
              finalBonusScores = finalBonusScores.copyWith(
                  intelligence: finalBonusScores.intelligence + amt);
            case AbilityType.wisdom:
              finalBonusScores = finalBonusScores.copyWith(
                  wisdom: finalBonusScores.wisdom + amt);
            case AbilityType.charisma:
              finalBonusScores = finalBonusScores.copyWith(
                  charisma: finalBonusScores.charisma + amt);
          }
          if (feat.grantsSavingThrowProficiency) {
            finalSaveProficiencies.add(chosenAbility);
          }
        }
      }
      if (feat != null) {
        if (feat.hasSkillProficiencyChoice && selectedFeatSkill != null) {
          skillMap[selectedFeatSkill] = SkillProficiencyLevel.proficient;
        }
        if (feat.hasExpertiseChoice) {
          final eligible = <SkillType>{
            ...selectedClassSkills,
            ...speciesBonusSkillPicks,
            ...compensatorySkillPicks,
            ?selectedFeatSkill,
          };
          final finalExp = eligible.contains(selectedFeatExpertise)
              ? selectedFeatExpertise
              : (selectedFeatSkill ??
                  (eligible.isNotEmpty ? eligible.first : null));
          if (finalExp != null) {
            skillMap[finalExp] = SkillProficiencyLevel.expertise;
          }
        }
      }
    }

    EntityReference<DomainEntity>? startingSubclassRef;
    if (curClass.getSubclassLevel(ruleset) == 1 &&
        curClass.subclasses.isNotEmpty) {
      final chosenSubSlug =
          selectedSubclassSlug ?? curClass.subclasses.first.id.slug;
      final sub = curClass.subclasses.firstWhere(
        (s) => s.id.slug == chosenSubSlug,
        orElse: () => curClass.subclasses.first,
      );
      startingSubclassRef = EntityReference<DomainEntity>(
        refType: EntityType.subclass,
        slug: sub.id.slug,
        displayName: sub.name,
        customProperties: {
          'featuresMarkdown': sub.featuresMarkdown,
          'classSlug': sub.classSlug,
          'shortName': sub.shortName,
          'grants': sub.grants.map((g) => g.toMap()).toList(),
          ...sub.customProperties,
        },
      );
    }

    final draft = _draft;
    draft.characterName =
        rawName.trim().isEmpty ? 'Adventurer' : rawName.trim();
    draft.rulesEdition = edition;
    draft.speciesRef = EntityReference(
      refType: EntityType.species,
      slug: curSpecies.id.slug,
      displayName: curSpecies.name,
      customProperties: {
        if (curSpecies.flexibleAbilityPool != null)
          'flexibleAbilityPool': curSpecies.flexibleAbilityPool,
        if (curSpecies.flexibleAbilityChoiceCount > 0)
          'flexibleAbilityCount': curSpecies.flexibleAbilityChoiceCount,
        if (curSpecies.flexibleAbilityBonus > 0)
          'flexibleAbilityBonus': curSpecies.flexibleAbilityBonus,
        if (curSpecies.fixedAbilityBonuses2014.isNotEmpty)
          'fixedAbilityBonuses': curSpecies.fixedAbilityBonuses2014,
      },
    );
    if (subraceSlug != null) {
      final chosenSub = SrdSpeciesLibrary.findSubraceBySlug(subraceSlug) ??
          (curSpecies.subraces.isNotEmpty
              ? curSpecies.subraces.firstWhere(
                  (s) => s.id.slug == subraceSlug,
                  orElse: () => curSpecies.subraces.first)
              : null);
      if (chosenSub != null) {
        draft.subraceRef = EntityReference(
          refType: EntityType.species,
          slug: chosenSub.id.slug,
          displayName: chosenSub.name,
          customProperties: {
            if (chosenSub.flexibleAbilityPool != null)
              'flexibleAbilityPool': chosenSub.flexibleAbilityPool,
            if (chosenSub.flexibleAbilityCount > 0)
              'flexibleAbilityCount': chosenSub.flexibleAbilityCount,
            if (chosenSub.flexibleAbilityBonus > 0)
              'flexibleAbilityBonus': chosenSub.flexibleAbilityBonus,
            if (chosenSub.fixedAbilityBonuses.isNotEmpty)
              'fixedAbilityBonuses': chosenSub.fixedAbilityBonuses,
          },
        );
      } else {
        draft.subraceRef = null;
      }
    } else {
      draft.subraceRef = null;
    }
    draft.pendingFlexibleAbilityChoices = variantHumanBonuses.toList();
    final bgProps = Map<String, dynamic>.from(curBackground.customProperties);
    if (curBackground.skillProficiencies.isNotEmpty) {
      bgProps['skillProficiencies'] = curBackground.skillProficiencies;
      bgProps['skills'] = curBackground.skillProficiencies;
    }
    if (curBackground.toolProficiencies.isNotEmpty) {
      bgProps['toolProficiencies'] = curBackground.toolProficiencies;
    }
    if (curBackground.languages.isNotEmpty) {
      bgProps['languages'] = curBackground.languages;
    }
    draft.backgroundRef = EntityReference(
      refType: EntityType.background,
      slug: curBackground.id.slug,
      displayName: curBackground.name,
      customProperties: bgProps,
    );
    draft.startingClassRef = EntityReference(
      refType: EntityType.classDefinition,
      slug: curClass.id.slug,
      displayName: curClass.name,
    );
    draft.startingClassHitDie = curClass.hitDie;
    draft.baseScores = effectiveBaseScores;
    draft.bonusScores = finalBonusScores;
    draft.savingThrowProficiencies = finalSaveProficiencies;
    draft.selectedSkills = skillMap;
    draft.originFeats = [
      if (hasFeat && selectedFeatSlug != null)
        EntityReference(
          refType: EntityType.feat,
          slug: selectedFeatSlug,
          displayName:
              SrdFeatsLibrary.findBySlug(selectedFeatSlug)?.name ?? 'Feat',
        ),
    ];
    draft.startingEquipment = equipRequests;
    draft.startingPurse = startingPurse;
    draft.takesStartingWealth = selectedPkg.id.startsWith('starting_wealth_');
    draft.cantrips = cantripRefs;
    draft.spellsKnown = spellRefs;
    draft.spellsPrepared = spellRefs;
    draft.startingSubclassRef = startingSubclassRef;
    final finalFeatureOptions =
        Map<String, List<String>>.from(selectedFeatureOptions);
    if (hasFeat && selectedFeatSlug != null && selectedFeatOption != null) {
      finalFeatureOptions['feat-$selectedFeatSlug'] = [selectedFeatOption];
    }
    draft.selectedFeatureOptions = finalFeatureOptions;
    draft.languages = languages;
    draft.toolProficiencies = toolProficiencies;
    return draft;
  }
}
