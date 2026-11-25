import 'package:material_ui/material_ui.dart';
import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_equipment_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../providers/character_builder_controller.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/haptic_service.dart';
import '../../../services/rules/character_factory.dart';
import '../ability_score_step.dart';
import '../background_step.dart';
import '../steps/basics_step.dart';
import '../steps/builder_step_order.dart';
import '../steps/class_decisions_step.dart';
import '../steps/class_step.dart';
import '../steps/equipment_step.dart';
import '../steps/feats_step.dart';
import '../steps/review_step.dart';
import '../steps/species_step.dart';
import '../steps/spells_step.dart';
import '../steps/subclass_step.dart';
import 'builder_proficiency_dialogs.dart';

class GuidedBuilderTab extends StatefulWidget {
  final RulesetVersion selectedRuleset;
  final DmRulesEdition rulesEdition;
  final int resetNonce;
  final ValueChanged<DmRulesEdition> onRulesEditionChanged;
  final ValueChanged<Character> onCharacterCreated;

  const GuidedBuilderTab({
    super.key,
    required this.selectedRuleset,
    required this.rulesEdition,
    required this.resetNonce,
    required this.onRulesEditionChanged,
    required this.onCharacterCreated,
  });

  @override
  State<GuidedBuilderTab> createState() => _GuidedBuilderTabState();
}

class _GuidedBuilderTabState extends State<GuidedBuilderTab> {
  int _wizardStep = 0;
  final TextEditingController _nameController = TextEditingController();
  String? _selectedSpecies;
  String? _selectedSubrace;
  String? _selectedClass;
  String? _selectedBackground;
  String? _selectedFeat;
  AbilityType? _selectedFeatAbility;
  SkillType? _selectedFeatSkill;
  SkillType? _selectedFeatExpertise;
  String? _selectedFeatOption;
  String? _wizardSelectedSubclass;
  final Map<String, List<String>> _wizardSelectedFeatureOptions = {};
  final Set<String> _selectedWizardCantrips = {};
  final Set<String> _selectedWizardSpells = {};
  String? _selectedStartingEquipmentPreset;
  Set<SkillType> _wizardSelectedSkills = {};
  final Set<SkillType> _compensatorySkillPicks = {};
  final Set<SkillType> _speciesBonusSkillPicks = {};

  String _speciesSearchQuery = '';
  String _featSearchQuery = '';
  String _spellSearchQuery = '';

  final Set<String> _builderLanguages = {'Common'};
  final Set<String> _builderToolProficiencies = {};
  String? _dwarfToolChoice;
  final Set<String> _speciesBonusLanguages = {};
  final Set<String> _classBonusTools = {};

  late final CharacterBuilderController _abilityScoreController;
  AbilityScores get _wizardBaseScores =>
      _abilityScoreController.effectiveBaseScores;

  final Set<AbilityType> _variantHumanBonuses = {};
  AbilityType _backgroundPrimaryBonus = AbilityType.strength;
  AbilityType _backgroundSecondaryBonus = AbilityType.constitution;

  RulesetVersion get _selectedRuleset => widget.selectedRuleset;
  DmRulesEdition get _rulesEdition => widget.rulesEdition;

  Set<String> get _allBuilderLanguages => computeBuilderLanguages(
        builderLanguages: _builderLanguages,
        selectedSpecies: _selectedSpecies,
        speciesBonusLanguages: _speciesBonusLanguages,
        selectedClass: _selectedClass,
        selectedBackground: _selectedBackground,
      );

  Set<String> get _allBuilderTools => computeBuilderTools(
        builderToolProficiencies: _builderToolProficiencies,
        selectedSpecies: _selectedSpecies,
        dwarfToolChoice: _dwarfToolChoice,
        selectedClass: _selectedClass,
        classBonusTools: _classBonusTools,
        selectedBackground: _selectedBackground,
      );

  @override
  void initState() {
    super.initState();
    _abilityScoreController =
        CharacterBuilderController(initialMode: 'standard', startEmpty: true);
    _abilityScoreController.setName(_nameController.text.trim().isEmpty
        ? 'Adventurer'
        : _nameController.text.trim());
    _abilityScoreController.addListener(_onControllerChanged);
    _nameController.addListener(_onNameChanged);
  }

  @override
  void didUpdateWidget(covariant GuidedBuilderTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetNonce != widget.resetNonce) {
      _wizardStep = 0;
    }
  }

  void _onNameChanged() {
    _abilityScoreController.setName(_nameController.text.trim().isEmpty
        ? 'Adventurer'
        : _nameController.text.trim());
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _abilityScoreController.removeListener(_onControllerChanged);
    _abilityScoreController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  AbilityScores _calculateBonusScores(
      Race? curSpecies, Background? curBackground, RulesetVersion ruleset,
      {Subrace? curSubrace}) {
    return computeBuilderOriginBonuses(
      curSpecies: curSpecies,
      curBackground: curBackground,
      ruleset: ruleset,
      variantHumanBonuses: _variantHumanBonuses,
      backgroundPrimaryBonus: _backgroundPrimaryBonus,
      backgroundSecondaryBonus: _backgroundSecondaryBonus,
      curSubrace: curSubrace,
    );
  }

  void _handleSpeciesSelected(Race sp) {
    setState(() {
      final prevSpecies = _selectedSpecies;
      _selectedSpecies = sp.id.slug;
      Subrace? autoSubrace;
      if (_speciesSearchQuery.isNotEmpty) {
        final q = _speciesSearchQuery.toLowerCase();
        autoSubrace = sp.subraces
            .where((sub) => sub.name.toLowerCase().contains(q))
            .firstOrNull;
      }
      _selectedSubrace = autoSubrace?.id.slug ??
          (sp.subraces.isNotEmpty ? sp.subraces.first.id.slug : null);
      _abilityScoreController.setSpecies(buildSpeciesEntityRef(sp));
      if (_selectedSubrace != null) {
        final chosenSub =
            sp.subraces.firstWhere((s) => s.id.slug == _selectedSubrace);
        _abilityScoreController.setSubrace(buildSubraceEntityRef(chosenSub));
      }
      if (prevSpecies != sp.id.slug) _speciesBonusSkillPicks.clear();
      _pruneFlexibleChoicesForSpecies(sp, _selectedSubrace);
      final is2024 = _selectedRuleset == RulesetVersion.v2024;
      final hasFeatStep = is2024 || sp.grantsBonusFeat;
      final maxStepIndex = hasFeatStep ? 7 : 6;
      if (_wizardStep > maxStepIndex) _wizardStep = maxStepIndex;
    });
  }

  void _handleSubraceSelected(Race sp, Subrace sub) {
    setState(() {
      _selectedSubrace = sub.id.slug;
      _abilityScoreController.setSubrace(buildSubraceEntityRef(sub));
      if (_selectedRuleset == RulesetVersion.v2014) {
        _pruneFlexibleChoicesForSpecies(sp, sub.id.slug);
      }
    });
  }

  void _pruneFlexibleChoicesForSpecies(Race sp, String? subSlug) {
    pruneBuilderFlexibleChoices(
      sp: sp,
      subSlug: subSlug,
      selectedRuleset: _selectedRuleset,
      variantHumanBonuses: _variantHumanBonuses,
      abilityScoreController: _abilityScoreController,
    );
  }

  void _handleFeatSelected(Feat feat) {
    final next = resolveFeatSelectionDefaults(
      feat: feat,
      currentAbility: _selectedFeatAbility,
      currentSkill: _selectedFeatSkill,
      currentExpertise: _selectedFeatExpertise,
      selectedClass: _selectedClass,
      wizardSelectedSkills: _wizardSelectedSkills,
      speciesBonusSkillPicks: _speciesBonusSkillPicks,
      compensatorySkillPicks: _compensatorySkillPicks,
      wizardSelectedFeatureOptions: _wizardSelectedFeatureOptions,
      selectedWizardCantrips: _selectedWizardCantrips,
      selectedWizardSpells: _selectedWizardSpells,
    );
    setState(() {
      _selectedFeat = feat.id.slug;
      _selectedFeatAbility = next.ability;
      _selectedFeatSkill = next.skill;
      _selectedFeatExpertise = next.expertise;
      _selectedFeatOption = next.option;
    });
  }

  void _showLimitSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _toggleSpeciesBonusSkill(SkillType sk, bool selected, int maxCount) {
    setState(() {
      if (selected) {
        if (_speciesBonusSkillPicks.length < maxCount) {
          _speciesBonusSkillPicks.add(sk);
        } else {
          _showLimitSnackBar(
              'Cannot select more than $maxCount species bonus skill(s).');
        }
      } else {
        _speciesBonusSkillPicks.remove(sk);
      }
    });
  }

  void _finalizeCreatedCharacter() {
    if (!_abilityScoreController.isReadyForCompilation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please complete all wizard steps before creating character.')),
      );
      return;
    }

    final draft = _abilityScoreController.buildFinalizedDraft(
      rawName: _nameController.text,
      ruleset: _selectedRuleset,
      speciesSlug: _selectedSpecies!,
      subraceSlug: _selectedSubrace,
      classSlug: _selectedClass!,
      backgroundSlug: _selectedBackground!,
      selectedSubclassSlug: _wizardSelectedSubclass,
      selectedFeatSlug: _selectedFeat,
      selectedFeatAbility: _selectedFeatAbility,
      selectedFeatSkill: _selectedFeatSkill,
      selectedFeatExpertise: _selectedFeatExpertise,
      selectedFeatOption: _selectedFeatOption,
      selectedClassSkills: _wizardSelectedSkills,
      compensatorySkillPicks: _compensatorySkillPicks,
      speciesBonusSkillPicks: _speciesBonusSkillPicks,
      selectedCantripIds: _selectedWizardCantrips,
      selectedSpellIds: _selectedWizardSpells,
      startingEquipmentPresetId: _selectedStartingEquipmentPreset,
      selectedFeatureOptions: _wizardSelectedFeatureOptions,
      variantHumanBonuses: _variantHumanBonuses,
      backgroundPrimaryBonus: _backgroundPrimaryBonus,
      backgroundSecondaryBonus: _backgroundSecondaryBonus,
      languages: _allBuilderLanguages.toList(),
      toolProficiencies: _allBuilderTools.toList(),
    );

    final newChar = CharacterFactory.buildFromDraft(draft);
    setState(() => _wizardStep = 0);
    widget.onCharacterCreated(newChar);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created ${newChar.name} successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curSpecies = _selectedSpecies != null
        ? SrdSpeciesLibrary.findBySlug(_selectedSpecies!)
        : null;
    final steps = computeWizardStepTypes(
      selectedSpecies: _selectedSpecies,
      selectedClass: _selectedClass,
      selectedRuleset: _selectedRuleset,
      preset:
          SettingsScope.settingsOf(context, listen: false).wizardOrderingPreset,
    );
    final maxStepIndex = steps.length - 1;
    if (_wizardStep > maxStepIndex) _wizardStep = maxStepIndex;

    final curClass = _selectedClass != null
        ? SrdClassesLibrary.findBySlug(_selectedClass!,
            ruleset: _selectedRuleset)
        : null;
    final curBackground = _selectedBackground != null
        ? SrdBackgroundsLibrary.findBySlug(_selectedBackground!)
        : null;
    final allowedClassSkills =
        curClass != null ? curClass.allowedSkills : <SkillType>[];
    final allowedSkillCount = curClass?.skillChoiceCount ?? 2;
    final lvl1Decisions =
        curClass?.getDecisionsForLevel(1, ruleset: _selectedRuleset) ?? [];
    final currentStepKey = steps[_wizardStep];

    if (currentStepKey == 'subclass' &&
        curClass != null &&
        curClass.subclasses.isNotEmpty) {
      _wizardSelectedSubclass ??= curClass.subclasses.first.id.slug;
    }
    if (currentStepKey == 'equipment' && curClass != null) {
      final packages = SrdEquipmentLibrary.getPackagesForClass(curClass.id.slug);
      if (packages.isNotEmpty &&
          !packages.any((p) => p.id == _selectedStartingEquipmentPreset)) {
        _selectedStartingEquipmentPreset = packages.first.id;
      }
    }

    final canAdvance = canAdvanceWizardStep(
      currentStepKey: currentStepKey,
      abilityScoreController: _abilityScoreController,
      selectedRuleset: _selectedRuleset,
      selectedSpecies: _selectedSpecies,
      selectedSubrace: _selectedSubrace,
      variantHumanBonuses: _variantHumanBonuses,
      wizardSelectedSubclass: _wizardSelectedSubclass,
      selectedFeat: _selectedFeat,
      selectedStartingEquipmentPreset: _selectedStartingEquipmentPreset,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: List.generate(steps.length, (i) {
            final isDone = i < _wizardStep;
            final isCur = i == _wizardStep;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 6,
                decoration: BoxDecoration(
                  color: isCur
                      ? Colors.cyanAccent
                      : (isDone ? Colors.cyan.shade800 : Colors.white12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Card(
          color: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCurrentStep(
              currentStepKey: currentStepKey,
              steps: steps,
              curSpecies: curSpecies,
              curClass: curClass,
              curBackground: curBackground,
              allowedClassSkills: allowedClassSkills,
              allowedSkillCount: allowedSkillCount,
              lvl1Decisions: lvl1Decisions,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_wizardStep > 0)
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                onPressed: () {
                  HapticService.selectionTick(context);
                  setState(() => _wizardStep--);
                },
              )
            else
              const SizedBox.shrink(),
            if (_wizardStep < maxStepIndex)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAdvance
                      ? Colors.cyanAccent.shade700
                      : Colors.grey.shade800,
                  foregroundColor: canAdvance ? Colors.black : Colors.white38,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Step',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: canAdvance
                    ? () {
                        HapticService.selectionTick(context);
                        setState(() => _wizardStep++);
                      }
                    : null,
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _abilityScoreController.isReadyForCompilation
                      ? Colors.greenAccent.shade700
                      : Colors.grey.shade800,
                  foregroundColor: _abilityScoreController.isReadyForCompilation
                      ? Colors.black
                      : Colors.white38,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text('CREATE & LAUNCH SHEET',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _abilityScoreController.isReadyForCompilation
                    ? () {
                        HapticService.heavyImpact(context);
                        _finalizeCreatedCharacter();
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentStep({
    required String currentStepKey,
    required List<String> steps,
    required Race? curSpecies,
    required CharacterClass? curClass,
    required Background? curBackground,
    required List<SkillType> allowedClassSkills,
    required int allowedSkillCount,
    required List<ClassFeatureDecision> lvl1Decisions,
  }) {
    final curSubrace = _selectedSubrace != null
        ? SrdSpeciesLibrary.findSubraceBySlug(_selectedSubrace!)
        : null;
    return switch (currentStepKey) {
      'basics' => BuilderBasicsStep(
          nameController: _nameController,
          selectedRuleset: _selectedRuleset,
          onRandomNameSelected: (name) =>
              setState(() => _nameController.text = name),
          onRulesEditionChanged: widget.onRulesEditionChanged,
        ),
      'species' => BuilderSpeciesStep(
          selectedRuleset: _selectedRuleset,
          rulesEdition: _rulesEdition,
          selectedSpecies: _selectedSpecies,
          selectedSubrace: _selectedSubrace,
          selectedClass: _selectedClass,
          selectedBackground: _selectedBackground,
          speciesSearchQuery: _speciesSearchQuery,
          abilityScoreController: _abilityScoreController,
          wizardBaseScores: _wizardBaseScores,
          wizardSelectedSkills: _wizardSelectedSkills,
          compensatorySkillPicks: _compensatorySkillPicks,
          speciesBonusSkillPicks: _speciesBonusSkillPicks,
          variantHumanBonuses: _variantHumanBonuses,
          dwarfToolChoice: _dwarfToolChoice,
          speciesBonusLanguages: _speciesBonusLanguages,
          calculateBonusScores: (sp, bg) => _calculateBonusScores(
              sp, bg, _selectedRuleset,
              curSubrace: curSubrace),
          onSearchChanged: (q) => setState(() => _speciesSearchQuery = q),
          onSelectSpecies: _handleSpeciesSelected,
          onSelectSubrace: _handleSubraceSelected,
          onToggleFlexibleAbility: (ab, selected, flexCount) => setState(() {
            if (selected) {
              while (_variantHumanBonuses.length >= flexCount &&
                  _variantHumanBonuses.isNotEmpty) {
                _variantHumanBonuses.remove(_variantHumanBonuses.first);
              }
              _variantHumanBonuses.add(ab);
            } else {
              _variantHumanBonuses.remove(ab);
            }
            _abilityScoreController
                .setFlexibleAbilityChoices(_variantHumanBonuses.toList());
          }),
          onToggleSpeciesBonusSkill: _toggleSpeciesBonusSkill,
          onDwarfToolChanged: (tool) => setState(() => _dwarfToolChoice = tool),
          onToggleSpeciesBonusLanguage: (lang, selected) => setState(() {
            _speciesBonusLanguages.clear();
            if (selected) _speciesBonusLanguages.add(lang);
          }),
        ),
      'class' => BuilderClassStep(
          curClass: curClass,
          allowedSkills: allowedClassSkills,
          allowedCount: allowedSkillCount,
          selectedClass: _selectedClass,
          selectedSpecies: _selectedSpecies,
          selectedSubrace: _selectedSubrace,
          selectedBackground: _selectedBackground,
          selectedRuleset: _selectedRuleset,
          wizardSelectedSkills: _wizardSelectedSkills,
          compensatorySkillPicks: _compensatorySkillPicks,
          speciesBonusSkillPicks: _speciesBonusSkillPicks,
          classBonusTools: _classBonusTools,
          onSelectClass: (v) => setState(() {
            if (_selectedClass != v) {
              _wizardSelectedFeatureOptions.clear();
              _selectedWizardCantrips.clear();
              _selectedWizardSpells.clear();
            }
            _selectedClass = v;
            final newCls =
                SrdClassesLibrary.findBySlug(v, ruleset: _selectedRuleset)!;
            _abilityScoreController.setClass(
              EntityReference(
                refType: EntityType.classDefinition,
                slug: newCls.id.slug,
                displayName: newCls.name,
              ),
              hitDie: newCls.hitDie,
            );
            _wizardSelectedSkills =
                newCls.allowedSkills.take(newCls.skillChoiceCount).toSet();
            _compensatorySkillPicks.clear();
            _abilityScoreController.setSelectedSkills(_wizardSelectedSkills);
          }),
          onToggleClassSkill: (sk, selected, maxCount, className) =>
              setState(() {
            if (selected) {
              if (_wizardSelectedSkills.length < maxCount) {
                _wizardSelectedSkills.add(sk);
              } else {
                _showLimitSnackBar(
                    'Cannot select more than $maxCount class skills for $className.');
              }
            } else {
              _wizardSelectedSkills.remove(sk);
            }
            _abilityScoreController.setSelectedSkills(_wizardSelectedSkills);
          }),
          onToggleCompensatorySkill: (sk, selected, maxCount) => setState(() {
            if (selected) {
              if (_compensatorySkillPicks.length < maxCount) {
                _compensatorySkillPicks.add(sk);
              } else {
                _showLimitSnackBar(
                    'Cannot select more than $maxCount compensatory skill(s).');
              }
            } else {
              _compensatorySkillPicks.remove(sk);
            }
          }),
          onToggleSpeciesBonusSkill: _toggleSpeciesBonusSkill,
          onToggleClassBonusTool: (tool, selected, singleSelect) =>
              setState(() {
            if (singleSelect) {
              _classBonusTools.clear();
              if (selected) _classBonusTools.add(tool);
            } else {
              if (selected) {
                if (_classBonusTools.length < 3) _classBonusTools.add(tool);
              } else {
                _classBonusTools.remove(tool);
              }
            }
          }),
        ),
      'subclass' => curClass != null
          ? BuilderSubclassStep(
              curClass: curClass,
              selectedRuleset: _selectedRuleset,
              wizardSelectedSubclass: _wizardSelectedSubclass,
              onSelectSubclass: (slug) =>
                  setState(() => _wizardSelectedSubclass = slug),
            )
          : const SizedBox.shrink(),
      'class_decisions' => curClass != null
          ? BuilderClassDecisionsStep(
              curClass: curClass,
              decisions: lvl1Decisions,
              wizardSelectedFeatureOptions: _wizardSelectedFeatureOptions,
              selectedPacts:
                  collectBuilderSelectedPacts(_wizardSelectedFeatureOptions),
              knownSpellSlugs: collectBuilderKnownSpellSlugs(
                selectedWizardCantrips: _selectedWizardCantrips,
                selectedWizardSpells: _selectedWizardSpells,
              ),
              onMutateState: (fn) => setState(fn),
            )
          : const SizedBox.shrink(),
      'background' => BackgroundStep(
          controller: _abilityScoreController,
          selectedBackground: _selectedBackground ?? '',
          selectedRuleset: _selectedRuleset,
          onBackgroundSelected: (slug) {
            final is2024 = _selectedRuleset == RulesetVersion.v2024;
            final bg = SrdBackgroundsLibrary.findBySlug(slug);
            setState(() {
              _selectedBackground = slug;
              _abilityScoreController.setBackground(
                EntityReference(
                  refType: EntityType.background,
                  slug: slug,
                  displayName: bg?.name ?? slug,
                  customProperties: {
                    if (bg != null) ...bg.customProperties,
                    if (bg != null && bg.skillProficiencies.isNotEmpty)
                      'skillProficiencies': bg.skillProficiencies,
                    if (bg != null && bg.toolProficiencies.isNotEmpty)
                      'toolProficiencies': bg.toolProficiencies,
                    if (bg != null && bg.languages.isNotEmpty)
                      'languages': bg.languages,
                  },
                ),
              );
              if (is2024 && bg?.originFeat != null) {
                final fSlug = bg!.originFeat!
                    .toLowerCase()
                    .replaceAll(' ', '-')
                    .replaceAll('(', '')
                    .replaceAll(')', '');
                if (SrdFeatsLibrary.findBySlug(fSlug) != null) {
                  _selectedFeat = fSlug;
                }
              }
            });
          },
        ),
      'scores' => AbilityScoreStep(
          controller: _abilityScoreController,
          curSpecies: curSpecies,
          curSubrace: curSubrace,
          curBackground: curBackground,
          selectedRuleset: _selectedRuleset,
          variantHumanBonuses: _variantHumanBonuses,
          onVariantHumanBonusesChanged: (set) => setState(() {
            _variantHumanBonuses
              ..clear()
              ..addAll(set);
            _abilityScoreController
                .setFlexibleAbilityChoices(_variantHumanBonuses.toList());
          }),
          backgroundPrimaryBonus: _backgroundPrimaryBonus,
          onBackgroundPrimaryBonusChanged: (ab) =>
              setState(() => _backgroundPrimaryBonus = ab),
          backgroundSecondaryBonus: _backgroundSecondaryBonus,
          onBackgroundSecondaryBonusChanged: (ab) =>
              setState(() => _backgroundSecondaryBonus = ab),
          bonusScores: _calculateBonusScores(
              curSpecies, curBackground, _selectedRuleset,
              curSubrace: curSubrace),
        ),
      'feats' => BuilderFeatsStep(
          selectedSpecies: _selectedSpecies,
          selectedClass: _selectedClass,
          selectedRuleset: _selectedRuleset,
          featSearchQuery: _featSearchQuery,
          selectedFeat: _selectedFeat,
          selectedFeatAbility: _selectedFeatAbility,
          selectedFeatSkill: _selectedFeatSkill,
          selectedFeatExpertise: _selectedFeatExpertise,
          selectedFeatOption: _selectedFeatOption,
          wizardSelectedSkills: _wizardSelectedSkills,
          speciesBonusSkillPicks: _speciesBonusSkillPicks,
          compensatorySkillPicks: _compensatorySkillPicks,
          wizardSelectedFeatureOptions: _wizardSelectedFeatureOptions,
          selectedWizardCantrips: _selectedWizardCantrips,
          selectedWizardSpells: _selectedWizardSpells,
          onSearchChanged: (q) => setState(() => _featSearchQuery = q),
          onSelectFeat: _handleFeatSelected,
          onFeatAbilityChanged: (ab) =>
              setState(() => _selectedFeatAbility = ab),
          onFeatSkillChanged: (feat, s) {
            final oldSkill = _selectedFeatSkill;
            setState(() {
              _selectedFeatSkill = s;
              if (feat.hasExpertiseChoice) {
                final eligible = <SkillType>{
                  ..._wizardSelectedSkills,
                  ..._speciesBonusSkillPicks,
                  ..._compensatorySkillPicks,
                  s,
                };
                if (_selectedFeatExpertise == null ||
                    _selectedFeatExpertise == oldSkill ||
                    !eligible.contains(_selectedFeatExpertise)) {
                  _selectedFeatExpertise = s;
                }
              }
            });
          },
          onFeatExpertiseChanged: (s) =>
              setState(() => _selectedFeatExpertise = s),
          onFeatOptionChanged: (optId) =>
              setState(() => _selectedFeatOption = optId),
        ),
      'spells' => curClass != null
          ? BuilderSpellsStep(
              curClass: curClass,
              selectedRuleset: _selectedRuleset,
              selectedSpecies: _selectedSpecies,
              selectedSubrace: _selectedSubrace,
              selectedBackground: _selectedBackground,
              wizardSelectedSubclass: _wizardSelectedSubclass,
              stepNumber: steps.indexOf('spells') + 1,
              wizardBaseScores: _wizardBaseScores,
              calculateBonusScores: _calculateBonusScores,
              selectedWizardCantrips: _selectedWizardCantrips,
              selectedWizardSpells: _selectedWizardSpells,
              spellSearchQuery: _spellSearchQuery,
              onSpellSearchQueryChanged: (q) =>
                  setState(() => _spellSearchQuery = q),
              onMutateState: (fn) => setState(fn),
            )
          : const SizedBox.shrink(),
      'equipment' => BuilderEquipmentStep(
          selectedClass: _selectedClass,
          selectedRuleset: _selectedRuleset,
          selectedStartingEquipmentPreset: _selectedStartingEquipmentPreset,
          stepNumber: steps.indexOf('equipment') + 1,
          onSelectEquipmentPreset: (id) =>
              setState(() => _selectedStartingEquipmentPreset = id),
        ),
      _ => BuilderReviewStep(
          curSpecies: curSpecies,
          curClass: curClass,
          curBackground: curBackground,
          totalSteps: steps.length,
          nameController: _nameController,
          selectedRuleset: _selectedRuleset,
          selectedSpecies: _selectedSpecies,
          selectedSubrace: _selectedSubrace,
          selectedBackground: _selectedBackground,
          selectedFeat: _selectedFeat,
          selectedFeatAbility: _selectedFeatAbility,
          selectedFeatSkill: _selectedFeatSkill,
          selectedFeatExpertise: _selectedFeatExpertise,
          selectedStartingEquipmentPreset: _selectedStartingEquipmentPreset,
          wizardBaseScores: _wizardBaseScores,
          wizardSelectedSkills: _wizardSelectedSkills,
          compensatorySkillPicks: _compensatorySkillPicks,
          speciesBonusSkillPicks: _speciesBonusSkillPicks,
          selectedWizardCantrips: _selectedWizardCantrips,
          selectedWizardSpells: _selectedWizardSpells,
          allBuilderLanguages: _allBuilderLanguages,
          allBuilderTools: _allBuilderTools,
          builderLanguages: _builderLanguages,
          builderToolProficiencies: _builderToolProficiencies,
          onAddLanguage: () => showBuilderAddLanguageDialog(
            context,
            allBuilderLanguages: _allBuilderLanguages,
            onAddLanguage: (lang) =>
                setState(() => _builderLanguages.add(lang)),
          ),
          onAddTool: () => showBuilderAddToolDialog(
            context,
            allBuilderTools: _allBuilderTools,
            onAddTool: (tool) =>
                setState(() => _builderToolProficiencies.add(tool)),
          ),
          onMutateState: (fn) => setState(fn),
        ),
    };
  }
}
