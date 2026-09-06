import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_proficiencies_library.dart';
import '../../models/characters/subclass_spells_library.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/spellbook_data.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/character_progression_engine.dart';
import '../../services/rules/character_evaluation_engine.dart';
import '../../services/rules/spell_allocation_validator.dart';
import '../../services/rules/dnd_5e_rules_engine.dart';
import '../../theme/app_theme.dart';
import '../glyphs/dnd_glyph.dart';
import '../spellbook/spell_comparison_dialog.dart';

/// Interactive, 6-step multi-step modal wizard for 5e Character Level Advancement.
class LevelUpWizardDialog extends StatefulWidget {
  final Character character;
  final ValueChanged<Character>? onLevelUpApplied;

  const LevelUpWizardDialog({
    super.key,
    required this.character,
    this.onLevelUpApplied,
  });

  static Future<Character?> show(
    BuildContext context, {
    required Character character,
    ValueChanged<Character>? onLevelUpApplied,
  }) {
    return showDialog<Character>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LevelUpWizardDialog(
        character: character,
        onLevelUpApplied: onLevelUpApplied,
      ),
    );
  }

  @override
  State<LevelUpWizardDialog> createState() => _LevelUpWizardDialogState();
}

class _LevelUpWizardDialogState extends State<LevelUpWizardDialog> with SingleTickerProviderStateMixin {
  int _currentStep = 0;

  // Step 1: Class Selection
  late String _selectedClassSlug;
  bool _isMulticlass = false;

  // Step 2: Hit Points Increase
  bool _useFixedAverage = true;
  late int _rolledHp;
  bool _isRolling = false;

  // Step 3: Subclass Selection
  String? _selectedSubclass;
  final Map<String, List<String>> _selectedFeatureOptions = {};

  // Step 4: ASI / Feat
  bool _isAsiSelected = true;
  bool _isAsiPlusTwo = true;
  AbilityType _asiSingleAbility = AbilityType.strength;
  AbilityType _asiDualAbility1 = AbilityType.strength;
  AbilityType _asiDualAbility2 = AbilityType.dexterity;
  String _selectedFeatSlug = 'tough';
  String _selectedFeatName = 'Tough';
  AbilityType? _selectedFeatAbility;
  SkillType? _selectedFeatSkill;
  SkillType? _selectedFeatExpertise;

  // Step 5: Spells
  final List<String> _newCantrips = [];
  final List<String> _newSpells = [];
  String? _replacedSpellId;
  String? _selectedMysticArcanumSpellId;
  String _spellSearchQuery = '';
  SpellClass? _selectedSpellListSource;
  bool _showAllSpellListsForSecrets = false;
  final TextEditingController _customCantripController = TextEditingController();
  final TextEditingController _customSpellController = TextEditingController();

  // Languages & Tools gained on level up
  final Set<String> _newToolProficiencies = {};
  final Set<String> _newLanguages = {};

  // Animation controller for dice roll
  late AnimationController _diceAnimController;

  static const List<Map<String, String>> _availableClasses = [
    {'slug': 'barbarian', 'name': 'Barbarian', 'hitDie': 'd12', 'prereq': 'STR 13'},
    {'slug': 'bard', 'name': 'Bard', 'hitDie': 'd8', 'prereq': 'CHA 13'},
    {'slug': 'cleric', 'name': 'Cleric', 'hitDie': 'd8', 'prereq': 'WIS 13'},
    {'slug': 'druid', 'name': 'Druid', 'hitDie': 'd8', 'prereq': 'WIS 13'},
    {'slug': 'fighter', 'name': 'Fighter', 'hitDie': 'd10', 'prereq': 'STR 13 or DEX 13'},
    {'slug': 'monk', 'name': 'Monk', 'hitDie': 'd8', 'prereq': 'DEX 13 & WIS 13'},
    {'slug': 'paladin', 'name': 'Paladin', 'hitDie': 'd10', 'prereq': 'STR 13 & CHA 13'},
    {'slug': 'ranger', 'name': 'Ranger', 'hitDie': 'd10', 'prereq': 'DEX 13 & WIS 13'},
    {'slug': 'rogue', 'name': 'Rogue', 'hitDie': 'd8', 'prereq': 'DEX 13'},
    {'slug': 'sorcerer', 'name': 'Sorcerer', 'hitDie': 'd6', 'prereq': 'CHA 13'},
    {'slug': 'warlock', 'name': 'Warlock', 'hitDie': 'd8', 'prereq': 'CHA 13'},
    {'slug': 'wizard', 'name': 'Wizard', 'hitDie': 'd6', 'prereq': 'INT 13'},
    {'slug': 'artificer', 'name': 'Artificer', 'hitDie': 'd8', 'prereq': 'INT 13'},
  ];

  static const Map<String, List<Map<String, String>>> _subclassesByClass = {
    'fighter': [
      {'slug': 'champion', 'name': 'Champion', 'desc': 'Improved Critical & physical mastery'},
      {'slug': 'battle_master', 'name': 'Battle Master', 'desc': 'Tactical superiority maneuvers & superiority dice'},
      {'slug': 'eldritch_knight', 'name': 'Eldritch Knight', 'desc': 'Abjuration & evocation arcane martial magic'},
      {'slug': 'samurai', 'name': 'Samurai', 'desc': 'Fighting Spirit advantage & resilience'},
    ],
    'wizard': [
      {'slug': 'school_of_evocation', 'name': 'School of Evocation', 'desc': 'Sculpt Spells & destructive blasts'},
      {'slug': 'school_of_abjuration', 'name': 'School of Abjuration', 'desc': 'Arcane Ward defensive wards'},
      {'slug': 'school_of_divination', 'name': 'School of Divination', 'desc': 'Portent roll manipulation'},
      {'slug': 'bladesinging', 'name': 'Bladesinging', 'desc': 'Graceful sword-and-spell agility'},
    ],
    'rogue': [
      {'slug': 'thief', 'name': 'Thief', 'desc': 'Fast Hands & Supreme Sneak mobility'},
      {'slug': 'assassin', 'name': 'Assassin', 'desc': 'Surprise assassinate critical strikes'},
      {'slug': 'arcane_trickster', 'name': 'Arcane Trickster', 'desc': 'Illusion & enchantment spellcasting with Mage Hand'},
      {'slug': 'swashbuckler', 'name': 'Swashbuckler', 'desc': 'Fancy Footwork & Rakish Audacity duel mastery'},
    ],
    'cleric': [
      {'slug': 'life_domain', 'name': 'Life Domain', 'desc': 'Disciple of Life empowered healing'},
      {'slug': 'light_domain', 'name': 'Light Domain', 'desc': 'Radiance of the Dawn radiant blast fire magic'},
      {'slug': 'war_domain', 'name': 'War Domain', 'desc': 'War Priest bonus attacks & divine strike'},
      {'slug': 'trickery_domain', 'name': 'Trickery Domain', 'desc': 'Invoke Duplicity illusions & stealth blessings'},
    ],
    'paladin': [
      {'slug': 'oath_of_devotion', 'name': 'Oath of Devotion', 'desc': 'Sacred Weapon & Aura of Devotion'},
      {'slug': 'oath_of_vengeance', 'name': 'Oath of Vengeance', 'desc': 'Vow of Enmity relentless hunting'},
      {'slug': 'oath_of_the_ancients', 'name': 'Oath of the Ancients', 'desc': 'Nature wrath & magic spell resistance aura'},
    ],
    'barbarian': [
      {'slug': 'berserker', 'name': 'Path of the Berserker', 'desc': 'Frenzy bonus attacks & Mindless Rage'},
      {'slug': 'totem_warrior', 'name': 'Path of the Totem Warrior', 'desc': 'Spirit animal damage resistances & speed'},
      {'slug': 'wild_magic_barbarian', 'name': 'Path of Wild Magic', 'desc': 'Chaotic surge magical explosions in rage'},
    ],
    'bard': [
      {'slug': 'college_of_lore', 'name': 'College of Lore', 'desc': 'Cutting Words & Additional Magical Secrets'},
      {'slug': 'college_of_valor', 'name': 'College of Valor', 'desc': 'Combat Inspiration & Martial proficiencies'},
      {'slug': 'college_of_eloquence', 'name': 'College of Eloquence', 'desc': 'Silver Tongue persuasion & Unsettling Words'},
    ],
    'druid': [
      {'slug': 'circle_of_the_land', 'name': 'Circle of the Land', 'desc': 'Natural Recovery & biome bonus spells'},
      {'slug': 'circle_of_the_moon', 'name': 'Circle of the Moon', 'desc': 'Combat Wild Shape into formidable beasts'},
      {'slug': 'circle_of_stars', 'name': 'Circle of Stars', 'desc': 'Star Map astral forms (Archer, Chalice, Dragon)'},
    ],
    'monk': [
      {'slug': 'way_of_the_open_hand', 'name': 'Way of the Open Hand', 'desc': 'Flurry of Blows knockdowns & push techniques'},
      {'slug': 'way_of_shadow', 'name': 'Way of Shadow', 'desc': 'Shadow Step teleportation & darkness arts'},
      {'slug': 'way_of_the_four_elements', 'name': 'Way of the Four Elements', 'desc': 'Elemental disciplines spell bursts'},
    ],
    'ranger': [
      {'slug': 'hunter', 'name': 'Hunter', 'desc': 'Colossus Slayer & defensive tactics'},
      {'slug': 'gloom_stalker', 'name': 'Gloom Stalker', 'desc': 'Dread Ambusher & Umbral Sight in darkness'},
      {'slug': 'beast_master', 'name': 'Beast Master', 'desc': 'Primal companion martial bond'},
    ],
    'sorcerer': [
      {'slug': 'draconic_bloodline', 'name': 'Draconic Bloodline', 'desc': 'Dragon ancestor armor, HP & elemental affinity'},
      {'slug': 'wild_magic', 'name': 'Wild Magic', 'desc': 'Tides of Chaos & wild magic surge surges'},
      {'slug': 'aberrant_mind', 'name': 'Aberrant Mind', 'desc': 'Psionic Spells & telepathic contact'},
    ],
    'warlock': [
      {'slug': 'the_fiend', 'name': 'The Fiend', 'desc': 'Dark One\'s Blessing temp HP & Hellfire'},
      {'slug': 'the_archfey', 'name': 'The Archfey', 'desc': 'Fey Presence charms & Misty Escape'},
      {'slug': 'the_hexblade', 'name': 'The Hexblade', 'desc': 'Hexblade\'s Curse & charisma weapon attacks'},
    ],
    'artificer': [
      {'slug': 'armorer', 'name': 'Armorer', 'desc': 'Arcane Armor (Guardian or Infiltrator)'},
      {'slug': 'battle_smith', 'name': 'Battle Smith', 'desc': 'Steel Defender automaton companion'},
      {'slug': 'artillerist', 'name': 'Artillerist', 'desc': 'Eldritch Cannon firepower support'},
      {'slug': 'alchemist', 'name': 'Alchemist', 'desc': 'Experimental Elixirs & alchemical chemistry'},
    ],
  };

  List<Feat> get _availableFeats {
    return SrdFeatsLibrary.getFeatsForRuleset(widget.character.id.ruleset);
  }

  @override
  void initState() {
    super.initState();
    // Default target class to starting class or first class
    final starting = widget.character.progression.startingClass ??
        (widget.character.progression.classes.isNotEmpty ? widget.character.progression.classes.first : null);
    _selectedClassSlug = starting?.classRef.slug.toLowerCase() ?? 'fighter';
    _isMulticlass = false;

    final hitDie = starting?.hitDie ?? 'd8';
    _rolledHp = CharacterProgressionEngine.getAverageHpForHitDie(hitDie);

    final feats = _availableFeats;
    if (feats.isNotEmpty) {
      final initialFeat = feats.firstWhere((f) => f.id.slug == 'tough', orElse: () => feats.first);
      _selectedFeatSlug = initialFeat.id.slug;
      _selectedFeatName = initialFeat.name;
      if (initialFeat.hasAbilityScoreIncrease) {
        _selectedFeatAbility = initialFeat.selectableAbilities.first;
      }
      if (initialFeat.hasSkillProficiencyChoice) {
        _selectedFeatSkill = initialFeat.selectableSkills.isNotEmpty
            ? initialFeat.selectableSkills.first
            : SkillType.athletics;
      }
      if (initialFeat.hasExpertiseChoice) {
        _selectedFeatExpertise = _selectedFeatSkill ?? SkillType.athletics;
      }
    }

    _diceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _diceAnimController.dispose();
    _customCantripController.dispose();
    _customSpellController.dispose();
    super.dispose();
  }

  int get _targetClassCurrentLevel {
    final match = widget.character.progression.classes.where(
      (c) => c.classRef.slug.toLowerCase() == _selectedClassSlug.toLowerCase(),
    );
    return match.isNotEmpty ? match.first.level : 0;
  }

  int get _targetClassNewLevel => _targetClassCurrentLevel + 1;

  int get _newTotalLevel => widget.character.totalLevel + 1;

  String get _currentHitDie =>
      CharacterProgressionEngine.getDefaultHitDie(_selectedClassSlug);

  int get _hitDieSides => CharacterProgressionEngine.getHitDieSides(_currentHitDie);

  int get _fixedAverageHp => CharacterProgressionEngine.getAverageHpForHitDie(_currentHitDie);

  bool get _isAsiEligible =>
      CharacterProgressionEngine.isAsiMilestone(_selectedClassSlug, _targetClassNewLevel);

  bool get _isSubclassMilestone {
    final existingSubclass = widget.character.progression.classes
        .where((c) => c.classRef.slug.toLowerCase() == _selectedClassSlug.toLowerCase())
        .map((c) => c.subclassRef)
        .firstOrNull;
    final cls = SrdClassesLibrary.findBySlug(_selectedClassSlug, ruleset: widget.character.id.ruleset);
    return existingSubclass == null &&
        CharacterProgressionEngine.isSubclassMilestone(
          _selectedClassSlug,
          _targetClassNewLevel,
          ruleset: widget.character.id.ruleset,
          characterClass: cls,
        );
  }

  int get _conModifier {
    var con = widget.character.baseScores.constitution + widget.character.bonusScores.constitution;
    if (_isAsiEligible && _isAsiSelected) {
      if (_isAsiPlusTwo && _asiSingleAbility == AbilityType.constitution) {
        con += 2;
      } else if (!_isAsiPlusTwo && (_asiDualAbility1 == AbilityType.constitution || _asiDualAbility2 == AbilityType.constitution)) {
        con += 1;
      }
    }
    return con.dndModifier;
  }

  int get _effectiveHpGain {
    final base = _useFixedAverage ? _fixedAverageHp : _rolledHp;
    return math.max(1, base + _conModifier);
  }

  void _rollHitPoints() {
    setState(() => _isRolling = true);
    _diceAnimController.forward(from: 0.0).then((_) {
      final random = math.Random();
      final roll = random.nextInt(_hitDieSides) + 1;
      if (mounted) {
        setState(() {
          _rolledHp = roll;
          _isRolling = false;
        });
        HapticService.selectionTick(context);
      }
    });
  }

  LevelUpRequest _buildRequest() {
    AsiOrFeatChoice? asiChoice;
    if (_isAsiEligible) {
      if (_isAsiSelected) {
        if (_isAsiPlusTwo) {
          asiChoice = AsiOrFeatChoice.asi({_asiSingleAbility: 2});
        } else {
          final increases = <AbilityType, int>{};
          increases[_asiDualAbility1] = (increases[_asiDualAbility1] ?? 0) + 1;
          increases[_asiDualAbility2] = (increases[_asiDualAbility2] ?? 0) + 1;
          asiChoice = AsiOrFeatChoice.asi(increases);
        }
      } else {
        final feat = SrdFeatsLibrary.findBySlug(_selectedFeatSlug);
        final increases = <AbilityType, int>{};
        final saves = <AbilityType>{};
        final chosenAbility = _selectedFeatAbility ??
            (feat?.selectableAbilities.isNotEmpty == true ? feat!.selectableAbilities.first : null);

        if (feat != null && feat.hasAbilityScoreIncrease && chosenAbility != null) {
          increases[chosenAbility] = feat.statIncreaseAmount;
          if (feat.grantsSavingThrowProficiency) {
            saves.add(chosenAbility);
          }
        }

        final skills = <SkillType>{};
        if (feat != null && feat.hasSkillProficiencyChoice && _selectedFeatSkill != null) {
          skills.add(_selectedFeatSkill!);
        }
        final expertises = <SkillType>{};
        if (feat != null && feat.hasExpertiseChoice && _selectedFeatExpertise != null) {
          expertises.add(_selectedFeatExpertise!);
        }

        asiChoice = AsiOrFeatChoice.feat(
          EntityReference<DomainEntity>(
            refType: EntityType.feat,
            slug: _selectedFeatSlug,
            displayName: _selectedFeatName,
          ),
          abilityIncreases: increases,
          savingThrowGrants: saves,
          chosenFeatAbility: chosenAbility,
          skillGrants: skills,
          expertiseGrants: expertises,
        );
      }
    }

    EntityReference<DomainEntity>? subclassRef;
    if (_selectedSubclass != null) {
      final customCls = SrdClassesLibrary.findBySlug(_selectedClassSlug, ruleset: widget.character.id.ruleset);
      final List<Map<String, String>> subs = [];
      if (customCls != null && customCls.subclasses.isNotEmpty) {
        for (final s in customCls.subclasses) {
          subs.add({'slug': s.id.slug, 'name': s.name});
        }
      }
      if (subs.isEmpty) {
        subs.addAll(_subclassesByClass[_selectedClassSlug] ?? []);
      }
      final sub = subs.firstWhere((s) => s['slug'] == _selectedSubclass, orElse: () => {'slug': _selectedSubclass!, 'name': _selectedSubclass!});
      subclassRef = EntityReference<DomainEntity>(
        refType: EntityType.subclass,
        slug: sub['slug']!,
        displayName: sub['name']!,
      );
    }

    final edition = widget.character.id.ruleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;

    final limits = SpellAllocationValidator.getLimitsForClass(
      classSlug: _selectedClassSlug,
      classLevel: _targetClassNewLevel,
      abilityModifier: _getCastingModifier(_selectedClassSlug),
      subclassSlug: subclassRef?.slug ?? _effectiveSubclassSlug,
      edition: edition,
    );
    final curCantripsCount = widget.character.cantrips.length;
    final maxAllowedNewCantrips = math.max(0, limits.maxCantrips - curCantripsCount);

    final allowedCantrips = maxAllowedNewCantrips > 0
        ? _newCantrips.take(maxAllowedNewCantrips).toList()
        : <String>[];

    final cantripRefs = allowedCantrips.map((c) {
      final spell = SpellbookLibrary.getSpellById(c);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: spell?.id ?? c.toLowerCase().replaceAll(' ', '_'),
        displayName: spell?.getName(edition) ?? c,
      );
    }).toList();

    final allSpellsList = List<String>.from(_newSpells);
    final alwaysPrepared = SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: _selectedClassSlug,
      subclassSlug: subclassRef?.slug ?? _effectiveSubclassSlug,
      classLevel: _targetClassNewLevel,
      edition: edition,
    );
    for (final s in alwaysPrepared) {
      if (!allSpellsList.contains(s.id)) {
        allSpellsList.add(s.id);
      }
    }

    final spellRefs = allSpellsList.map((s) {
      final spell = SpellbookLibrary.getSpellById(s);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: spell?.id ?? s.toLowerCase().replaceAll(' ', '_'),
        displayName: spell?.getName(edition) ?? s,
      );
    }).toList();

    final arcanumRef = _selectedMysticArcanumSpellId != null
        ? () {
            final s = SpellbookLibrary.getSpellById(_selectedMysticArcanumSpellId!);
            return EntityReference<Spell>(
              refType: EntityType.spell,
              slug: s?.id ?? _selectedMysticArcanumSpellId!.toLowerCase().replaceAll(' ', '_'),
              displayName: s?.getName(edition) ?? _selectedMysticArcanumSpellId!,
            );
          }()
        : null;

    return LevelUpRequest(
      targetClassSlug: _selectedClassSlug,
      targetClassDisplayName: _selectedClassSlug.toUpperCase(),
      targetClassHitDie: _currentHitDie,
      isMulticlass: _isMulticlass,
      subclassRef: subclassRef,
      hpChoice: _useFixedAverage ? const HpProgressionChoice.average() : HpProgressionChoice.rolled(_rolledHp),
      asiOrFeat: asiChoice,
      newCantrips: cantripRefs,
      newSpells: spellRefs,
      replacedSpellIds: _replacedSpellId != null ? [_replacedSpellId!] : const [],
      selectedFeatureOptions: Map<String, List<String>>.from(_selectedFeatureOptions),
      newToolProficiencies: _newToolProficiencies.toList(),
      newLanguages: _newLanguages.toList(),
      mysticArcanumSpell: arcanumRef,
    );
  }

  void _onConfirmLevelUp() {
    final request = _buildRequest();
    final updated = CharacterProgressionEngine.applyLevelUp(widget.character, request);
    HapticService.selectionTick(context);
    widget.onLevelUpApplied?.call(updated);
    if (mounted) {
      Navigator.of(context).pop(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();
    final validation = CharacterProgressionEngine.validateMulticlass(widget.character, _selectedClassSlug);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
          width: 1.5,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: math.min(740, MediaQuery.sizeOf(context).height * 0.9),
        ),
        child: Column(
          children: [
            // Header with Wizard Steps Indicator
            _buildDialogHeader(theme, customColors),
            const Divider(height: 1),

            // Step Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(theme, customColors, validation),
              ),
            ),
            const Divider(height: 1),

            // Bottom Navigation Actions
            _buildBottomBar(theme, validation),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(ThemeData theme, TabletopColors? customColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: customColors?.critGold ?? Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level Up Hero: ${widget.character.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Advancing to Character Level $_newTotalLevel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Step progress indicator bar
          Row(
            children: List.generate(6, (index) {
              final isPassed = index < _currentStep;
              final isCurrent = index == _currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? (customColors?.hitGreen ?? Colors.green)
                        : (isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _getStepTitle(_currentStep),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Step 1 of 6: Target Class & Multiclass Rules';
      case 1:
        return 'Step 2 of 6: Hit Points & Hit Die Scaling';
      case 2:
        return 'Step 3 of 6: Class Features & Subclass Archetype';
      case 3:
        return 'Step 4 of 6: Ability Score Improvement or Feat';
      case 4:
        return 'Step 5 of 6: Spells & Invocations Management';
      case 5:
        return 'Step 6 of 6: Review & Final Confirmation';
      default:
        return '';
    }
  }

  Widget _buildCurrentStepContent(ThemeData theme, TabletopColors? customColors, LevelUpValidationResult validation) {
    switch (_currentStep) {
      case 0:
        return _buildStep1ClassSelection(theme, customColors, validation);
      case 1:
        return _buildStep2HpIncrease(theme, customColors);
      case 2:
        return _buildStep3SubclassAndFeatures(theme, customColors);
      case 3:
        return _buildStep4AsiOrFeat(theme, customColors);
      case 4:
        return _buildStep5Spells(theme, customColors);
      case 5:
        return _buildStep6Summary(theme, customColors);
      default:
        return const SizedBox.shrink();
    }
  }

  // --------------------------------------------------------------------------
  // STEP 1: CLASS SELECTION
  // --------------------------------------------------------------------------
  Widget _buildStep1ClassSelection(ThemeData theme, TabletopColors? customColors, LevelUpValidationResult validation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Target Class to Advance',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Advance your primary class or multiclass into a new archetype according to 5e prerequisites.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Class Cards Grid / Dropdown
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _selectedClassSlug,
          decoration: InputDecoration(
            labelText: 'Class to Level Up',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10.0),
              child: DndGlyph.classFeature(
                classType: DndClassType.tryParse(_selectedClassSlug) ?? DndClassType.fighter,
                size: 24,
                isDarkMode: theme.brightness == Brightness.dark,
              ),
            ),
          ),
          items: _availableClasses.map((cls) {
            final isCurrent = widget.character.progression.classes.any((c) => c.classRef.slug.toLowerCase() == cls['slug']);
            final label = '${cls['name']} (${cls['hitDie']}) ${isCurrent ? "— Current" : "— Multiclass (Req: ${cls['prereq']})"}';
            final classType = DndClassType.tryParse(cls['slug']) ?? DndClassType.fighter;
            return DropdownMenuItem(
              value: cls['slug'],
              child: Row(
                children: [
                  DndGlyph.classFeature(
                    classType: classType,
                    size: 20,
                    isDarkMode: theme.brightness == Brightness.dark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedClassSlug = val;
                _isMulticlass = !widget.character.progression.classes.any((c) => c.classRef.slug.toLowerCase() == val);
                _rolledHp = _fixedAverageHp;
                _selectedSubclass = null;
                _newCantrips.clear();
                _newSpells.clear();
                _selectedMysticArcanumSpellId = null;
              });
            }
          },
        ),
        const SizedBox(height: 16),

        // Validation alert if multiclass requirements are not met
        if (!validation.isValid)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    validation.errors.join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (customColors?.hitGreen ?? Colors.green).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (customColors?.hitGreen ?? Colors.green).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: customColors?.hitGreen ?? Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prerequisites Satisfied: Ready to advance $_selectedClassSlug to Level $_targetClassNewLevel!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: customColors?.hitGreen ?? Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // STEP 2: HP INCREASE
  // --------------------------------------------------------------------------
  Widget _buildStep2HpIncrease(ThemeData theme, TabletopColors? customColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hit Points & Hit Die Scaling',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Gain a new $_currentHitDie Hit Die and increase your character\'s maximum Hit Points.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Fixed Average vs Die Roll Toggle
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.balance),
              label: Text('Fixed Average ($_fixedAverageHp)'),
            ),
            ButtonSegment(
              value: false,
              icon: DndGlyph.genericUi(
                uiType: GenericUiGlyphType.fromDie(_currentHitDie) ?? GenericUiGlyphType.d20,
                size: 16,
                isDarkMode: theme.brightness == Brightness.dark,
              ),
              label: const Text('Interactive Roll'),
            ),
          ],
          selected: {_useFixedAverage},
          onSelectionChanged: (val) {
            setState(() => _useFixedAverage = val.first);
          },
        ),
        const SizedBox(height: 20),

        if (!_useFixedAverage) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DndGlyph.genericUi(
                      uiType: GenericUiGlyphType.fromDie(_currentHitDie) ?? GenericUiGlyphType.d20,
                      size: 24,
                      isDarkMode: theme.brightness == Brightness.dark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Roll $_currentHitDie:',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isRolling
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                '$_rolledHp',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isRolling ? null : _rollHitPoints,
                  icon: const Icon(Icons.replay),
                  label: const Text('Roll Hit Die'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Breakdown card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HP Gain Breakdown:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Hit Die Base (${_useFixedAverage ? "Average" : "Rolled"}):')),
                  Text('+${_useFixedAverage ? _fixedAverageHp : _rolledHp}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('Constitution Modifier:')),
                  Text(_conModifier >= 0 ? "+$_conModifier" : "$_conModifier", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('Total HP Gain this Level:', style: TextStyle(fontWeight: FontWeight.bold))),
                  Text(
                    '+$_effectiveHpGain HP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: customColors?.hitGreen ?? Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Set<String> _getAllKnownSpellSlugs() {
    final slugs = <String>{};
    for (final c in widget.character.cantrips) {
      slugs.add(c.slug.toLowerCase().trim());
      slugs.add(c.displayName.toLowerCase().trim());
    }
    for (final s in widget.character.spellsKnown) {
      slugs.add(s.slug.toLowerCase().trim());
      slugs.add(s.displayName.toLowerCase().trim());
    }
    for (final s in widget.character.spellsPrepared) {
      slugs.add(s.slug.toLowerCase().trim());
      slugs.add(s.displayName.toLowerCase().trim());
    }
    for (final c in _newCantrips) {
      slugs.add(c.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(c);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    for (final s in _newSpells) {
      slugs.add(s.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(s);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    if (_selectedMysticArcanumSpellId != null) {
      final s = _selectedMysticArcanumSpellId!;
      slugs.add(s.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(s);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    return slugs;
  }

  Set<String> _getAllSelectedPacts() {
    final pacts = <String>{};
    final existing = widget.character.progression.getAllSelectedFeatureOptions();
    for (final list in existing.values) {
      for (final id in list) {
        final lower = id.toLowerCase();
        if (lower.contains('blade')) pacts.add('blade');
        if (lower.contains('tome')) pacts.add('tome');
        if (lower.contains('chain')) pacts.add('chain');
        if (lower.contains('talisman')) pacts.add('talisman');
      }
    }
    for (final list in _selectedFeatureOptions.values) {
      for (final id in list) {
        final lower = id.toLowerCase();
        if (lower.contains('blade')) pacts.add('blade');
        if (lower.contains('tome')) pacts.add('tome');
        if (lower.contains('chain')) pacts.add('chain');
        if (lower.contains('talisman')) pacts.add('talisman');
      }
    }
    return pacts;
  }

  // --------------------------------------------------------------------------
  // STEP 3: SUBCLASS & FEATURES
  // --------------------------------------------------------------------------
  Widget _buildStep3SubclassAndFeatures(ThemeData theme, TabletopColors? customColors) {
    final customCls = SrdClassesLibrary.findBySlug(_selectedClassSlug, ruleset: widget.character.id.ruleset);
    final List<Map<String, String>> availableSubs = [];
    if (customCls != null && customCls.subclasses.isNotEmpty) {
      for (final s in customCls.subclasses) {
        availableSubs.add({
          'slug': s.id.slug,
          'name': s.name,
          'desc': s.featuresMarkdown.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => s.name),
        });
      }
    }
    if (availableSubs.isEmpty) {
      availableSubs.addAll(_subclassesByClass[_selectedClassSlug] ?? []);
    }
    final needsSubclass = _isSubclassMilestone && availableSubs.isNotEmpty;
    final decisions = customCls?.getDecisionsForLevel(_targetClassNewLevel, ruleset: widget.character.id.ruleset) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Features & Specializations',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Unlocking features and choices for $_selectedClassSlug Level $_targetClassNewLevel.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        if (needsSubclass) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (customColors?.critGold ?? Colors.amber).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: customColors?.critGold ?? Colors.amber),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Subclass Archetype Milestone Unlocked!', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Choose your Subclass archetype specialization:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedSubclass,
                  decoration: const InputDecoration(
                    labelText: 'Select Subclass',
                    border: OutlineInputBorder(),
                  ),
                  items: availableSubs.map((sub) {
                    return DropdownMenuItem(
                      value: sub['slug'],
                      child: Text('${sub['name']} — ${sub['desc']}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedSubclass = v;
                      final sub = v?.toLowerCase() ?? '';
                      if (sub.contains('assassin')) {
                        _newToolProficiencies.add('Disguise Kit');
                        _newToolProficiencies.add('Poisoner\'s Kit');
                      } else if (sub.contains('battle_master') || sub.contains('battle master')) {
                        _newToolProficiencies.add('Artisan\'s Tools');
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Feature Decisions (e.g. Eldritch Invocations, Fighting Style, Divine Order, etc.)
        if (decisions.isNotEmpty) ...[
          ...decisions.map((decision) {
            final selected = _selectedFeatureOptions[decision.id] ??= [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.cyan.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          decision.type.displayName,
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          decision.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${decision.prompt} (Selected: ${selected.length} / ${decision.maxSelections})',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: decision.availableOptions.map((opt) {
                      final isSelected = selected.contains(opt.id);
                      final eval = opt.prerequisite.evaluate(
                        classLevel: _targetClassNewLevel,
                        selectedPacts: _getAllSelectedPacts(),
                        knownSpellSlugs: _getAllKnownSpellSlugs(),
                      );
                      final isGated = !eval.isMet && !isSelected;

                      return Tooltip(
                        message: isGated
                            ? 'Locked: ${eval.summary}'
                            : (opt.descriptionMarkdown.isNotEmpty ? opt.descriptionMarkdown : opt.name),
                        child: FilterChip(
                          selected: isSelected,
                          selectedColor: Colors.cyanAccent.withValues(alpha: 0.35),
                          disabledColor: Colors.white10,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isGated) ...[
                                const Icon(Icons.lock_outline, size: 12, color: Colors.orangeAccent),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                opt.name,
                                style: TextStyle(
                                  color: isGated ? Colors.white38 : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          avatar: Icon(
                            isSelected ? Icons.check_circle : (isGated ? Icons.lock : Icons.circle_outlined),
                            size: 14,
                            color: isSelected
                                ? Colors.cyanAccent
                                : (isGated ? Colors.orangeAccent.withValues(alpha: 0.6) : Colors.white54),
                          ),
                          onSelected: (bool chosen) {
                            if (isGated && chosen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot select ${opt.name}: ${eval.summary}'),
                                  backgroundColor: Colors.red.shade900,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              return;
                            }
                            HapticService.selectionTick(context);
                            setState(() {
                              final list = List<String>.from(_selectedFeatureOptions[decision.id] ?? []);
                              if (chosen) {
                                if (decision.maxSelections == 1) {
                                  list.clear();
                                  list.add(opt.id);
                                } else {
                                  if (list.length >= decision.maxSelections) {
                                    list.removeAt(0);
                                  }
                                  list.add(opt.id);
                                }
                              } else {
                                list.remove(opt.id);
                              }
                              _selectedFeatureOptions[decision.id] = list;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],

        // General features overview
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gains at Level $_targetClassNewLevel:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• Hit Die Pool: +1 $_currentHitDie'),
              Text('• Proficiency Bonus: +${_newTotalLevel.dndProficiencyBonus}'),
              if (_isAsiEligible) const Text('• Ability Score Improvement / Feat Eligible'),
              if (needsSubclass && _selectedSubclass != null)
                Text('• Specialization: $_selectedSubclass'),
              if (_selectedFeatureOptions.isNotEmpty)
                Text('• Chosen Specializations: ${_selectedFeatureOptions.values.expand((v) => v).join(', ')}'),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // STEP 4: ASI / FEAT
  // --------------------------------------------------------------------------
  Widget _buildStep4AsiOrFeat(ThemeData theme, TabletopColors? customColors) {
    if (!_isAsiEligible) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              'No ASI / Feat Milestone at Level $_targetClassNewLevel',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '$_selectedClassSlug grants ASI/Feats at levels 4, 8, 12, 16, 19.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ability Score Improvement (ASI) or Feat', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Milestone reached! Choose between increasing ability scores or gaining a new Feat.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Ability Score Improvement')),
            ButtonSegment(value: false, label: Text('Choose Feat')),
          ],
          selected: {_isAsiSelected},
          onSelectionChanged: (set) => setState(() => _isAsiSelected = set.first),
        ),
        const SizedBox(height: 16),

        if (_isAsiSelected) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('+2 to One Score')),
              ButtonSegment(value: false, label: Text('+1 to Two Scores')),
            ],
            selected: {_isAsiPlusTwo},
            onSelectionChanged: (set) => setState(() => _isAsiPlusTwo = set.first),
          ),
          const SizedBox(height: 16),
          if (_isAsiPlusTwo) ...[
            DropdownButtonFormField<AbilityType>(
              isExpanded: true,
              initialValue: _asiSingleAbility,
              decoration: const InputDecoration(labelText: '+2 Ability Score', border: OutlineInputBorder()),
              items: AbilityType.values.map((a) => DropdownMenuItem(value: a, child: Text('${a.name.toUpperCase()} (+2)'))).toList(),
              onChanged: (v) => setState(() => _asiSingleAbility = v!),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AbilityType>(
                    isExpanded: true,
                    initialValue: _asiDualAbility1,
                    decoration: const InputDecoration(labelText: '+1 Score 1', border: OutlineInputBorder()),
                    items: AbilityType.values.map((a) => DropdownMenuItem(value: a, child: Text(a.name.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _asiDualAbility1 = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AbilityType>(
                    isExpanded: true,
                    initialValue: _asiDualAbility2,
                    decoration: const InputDecoration(labelText: '+1 Score 2', border: OutlineInputBorder()),
                    items: AbilityType.values.map((a) => DropdownMenuItem(value: a, child: Text(a.name.toUpperCase()))).toList(),
                    onChanged: (v) => setState(() => _asiDualAbility2 = v!),
                  ),
                ),
              ],
            ),
          ],
        ] else ...[
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedFeatSlug,
            decoration: InputDecoration(
              labelText: 'Select Feat',
              border: const OutlineInputBorder(),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(10.0),
                child: DndGlyph.feat(
                  category: FeatCategory.parse(
                    _availableFeats.firstWhere((f) => f.id.slug == _selectedFeatSlug, orElse: () => _availableFeats.first).category,
                  ),
                  featId: _selectedFeatSlug,
                  displayName: _selectedFeatName,
                  size: 24,
                  isDarkMode: theme.brightness == Brightness.dark,
                ),
              ),
            ),
            items: _availableFeats.map((f) {
              final prereq = f.prerequisite != null ? ' (${f.prerequisite})' : '';
              return DropdownMenuItem(
                value: f.id.slug,
                child: Row(
                  children: [
                    DndGlyph.feat(
                      category: FeatCategory.parse(f.category),
                      featId: f.id.slug,
                      displayName: f.name,
                      size: 20,
                      isDarkMode: theme.brightness == Brightness.dark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${f.name}$prereq',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) {
                final match = _availableFeats.firstWhere(
                  (f) => f.id.slug == v,
                  orElse: () => _availableFeats.first,
                );
                setState(() {
                  _selectedFeatSlug = v;
                  _selectedFeatName = match.name;
                  if (match.hasAbilityScoreIncrease) {
                    if (_selectedFeatAbility == null || !match.selectableAbilities.contains(_selectedFeatAbility)) {
                      _selectedFeatAbility = match.selectableAbilities.first;
                    }
                  } else {
                    _selectedFeatAbility = null;
                  }
                  if (match.hasSkillProficiencyChoice) {
                    final selectable = match.selectableSkills.isNotEmpty
                        ? match.selectableSkills
                        : SkillType.values.toList();
                    if (_selectedFeatSkill == null || !selectable.contains(_selectedFeatSkill)) {
                      _selectedFeatSkill = selectable.first;
                    }
                  } else {
                    _selectedFeatSkill = null;
                  }
                  if (match.hasExpertiseChoice) {
                    final eligible = <SkillType>{
                      ...widget.character.skillProficiencies.entries
                          .where((e) => e.value != SkillProficiencyLevel.none)
                          .map((e) => e.key),
                      if (_selectedFeatSkill != null) _selectedFeatSkill!,
                    };
                    if (eligible.isEmpty) eligible.addAll(SkillType.values);
                    if (_selectedFeatExpertise == null || !eligible.contains(_selectedFeatExpertise)) {
                      _selectedFeatExpertise = _selectedFeatSkill ?? eligible.first;
                    }
                  } else {
                    _selectedFeatExpertise = null;
                  }
                });
              }
            },
          ),
          () {
            final feat = _availableFeats.firstWhere(
              (f) => f.id.slug == _selectedFeatSlug,
              orElse: () => _availableFeats.first,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feat.hasAbilityScoreIncrease) ...[
                  const SizedBox(height: 16),
                  if (feat.requiresAbilityChoice) ...[
                    Text(
                      'Choose Ability Score to Increase (+${feat.statIncreaseAmount}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: feat.selectableAbilities.map((ability) {
                        final isSelected = (_selectedFeatAbility ?? feat.selectableAbilities.first) == ability;
                        return ChoiceChip(
                          key: Key('feat_ability_chip_${ability.name}'),
                          label: Text('${ability.shortName} (+${feat.statIncreaseAmount})'),
                          selected: isSelected,
                          selectedColor: Colors.purpleAccent.withValues(alpha: 0.3),
                          onSelected: (sel) {
                            if (sel) {
                              HapticService.selectionTick(context);
                              setState(() => _selectedFeatAbility = ability);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Chip(
                      avatar: const Icon(Icons.arrow_upward, size: 16, color: Colors.greenAccent),
                      label: Text('+${feat.statIncreaseAmount} ${feat.selectableAbilities.first.shortName} (Included)'),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                    ),
                  ],
                  if (feat.grantsSavingThrowProficiency) ...[
                    const SizedBox(height: 10),
                    () {
                      final chosenSave = _selectedFeatAbility ?? feat.selectableAbilities.first;
                      final alreadyProficient = widget.character.savingThrowProficiencies.contains(chosenSave);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: alreadyProficient
                              ? Colors.amber.shade900.withValues(alpha: 0.2)
                              : Colors.blue.shade900.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: alreadyProficient ? Colors.amberAccent : Colors.blueAccent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              alreadyProficient ? Icons.warning_amber_rounded : Icons.shield,
                              color: alreadyProficient ? Colors.amberAccent : Colors.cyanAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alreadyProficient
                                    ? 'Already proficient in ${chosenSave.shortName} saving throws.'
                                    : 'Grants Proficiency: ${chosenSave.shortName} Saving Throws',
                                style: TextStyle(
                                  color: alreadyProficient ? Colors.amberAccent : Colors.cyanAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
                  ],
                ],
                if (feat.hasSkillProficiencyChoice) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Choose Skill Proficiency:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SkillType>(
                    key: const Key('levelup_feat_skill_dropdown'),
                    initialValue: _selectedFeatSkill ??
                        (feat.selectableSkills.isNotEmpty
                            ? feat.selectableSkills.first
                            : SkillType.athletics),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: (feat.selectableSkills.isNotEmpty ? feat.selectableSkills : SkillType.values)
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.displayName),
                            ))
                        .toList(),
                    onChanged: (s) {
                      if (s != null) {
                        setState(() {
                          _selectedFeatSkill = s;
                          if (feat.hasExpertiseChoice && _selectedFeatExpertise == null) {
                            _selectedFeatExpertise = s;
                          }
                        });
                      }
                    },
                  ),
                ],
                if (feat.hasExpertiseChoice) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Choose Skill for Expertise (Double Proficiency):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  () {
                    final eligible = <SkillType>{
                      ...widget.character.skillProficiencies.entries
                          .where((e) => e.value != SkillProficiencyLevel.none)
                          .map((e) => e.key),
                      if (_selectedFeatSkill != null) _selectedFeatSkill!,
                    };
                    if (eligible.isEmpty) eligible.addAll(SkillType.values);
                    final effectiveVal = eligible.contains(_selectedFeatExpertise)
                        ? _selectedFeatExpertise
                        : (_selectedFeatSkill != null && eligible.contains(_selectedFeatSkill)
                            ? _selectedFeatSkill
                            : eligible.first);

                    return DropdownButtonFormField<SkillType>(
                      key: const Key('levelup_feat_expertise_dropdown'),
                      initialValue: effectiveVal,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: eligible
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s == _selectedFeatSkill
                                      ? '${s.displayName} (From this Feat)'
                                      : s.displayName,
                                ),
                              ))
                          .toList(),
                      onChanged: (s) {
                        if (s != null) {
                          setState(() => _selectedFeatExpertise = s);
                        }
                      },
                    );
                  }(),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    feat.descriptionMarkdown,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            );
          }(),
        ],
      ],
    );
  }

  String? get _effectiveSubclassSlug {
    if (_selectedSubclass != null) return _selectedSubclass;
    final match = widget.character.progression.classes.where(
      (c) => c.classRef.slug.toLowerCase() == _selectedClassSlug.toLowerCase(),
    );
    return match.isNotEmpty ? match.first.subclassRef?.slug : null;
  }

  int _getCastingModifier(String classSlug) {
    final slug = classSlug.toLowerCase();
    AbilityType ability = AbilityType.intelligence;
    if (['cleric', 'druid', 'ranger'].contains(slug)) {
      ability = AbilityType.wisdom;
    } else if (['bard', 'sorcerer', 'warlock', 'paladin'].contains(slug)) {
      ability = AbilityType.charisma;
    }

    var score = widget.character.baseScores.getScore(ability) + widget.character.bonusScores.getScore(ability);
    if (_isAsiEligible && _isAsiSelected) {
      if (_isAsiPlusTwo && _asiSingleAbility == ability) {
        score += 2;
      } else if (!_isAsiPlusTwo && (_asiDualAbility1 == ability || _asiDualAbility2 == ability)) {
        score += 1;
      }
    }
    return score.dndModifier;
  }

  int get _maxAccessibleSpellLevel {
    final slug = _selectedClassSlug.toLowerCase();
    final lvl = _targetClassNewLevel;
    if (['wizard', 'cleric', 'druid', 'bard', 'sorcerer'].contains(slug)) {
      return ((lvl + 1) ~/ 2).clamp(1, 9);
    }
    if (slug == 'warlock') {
      return ((lvl + 1) ~/ 2).clamp(1, 5);
    }
    if (['paladin', 'ranger'].contains(slug)) {
      if (lvl < 2) {
        return (widget.character.id.ruleset == RulesetVersion.v2024) ? 1 : 0;
      }
      return ((lvl + 3) ~/ 4).clamp(1, 5);
    }
    if (slug == 'artificer') {
      return ((lvl + 3) ~/ 4).clamp(1, 5);
    }
    final effSub = _effectiveSubclassSlug?.toLowerCase() ?? '';
    if (effSub.contains('eldritch_knight') || effSub.contains('arcane_trickster')) {
      if (lvl < 3) return 0;
      return ((lvl + 1) ~/ 6 + 1).clamp(1, 4);
    }
    return 0;
  }

  bool get _isSpellcaster => _maxAccessibleSpellLevel > 0;

  SpellClass? get _targetSpellClass {
    final effSub = _effectiveSubclassSlug?.toLowerCase() ?? '';
    if (effSub.contains('eldritch_knight') || effSub.contains('arcane_trickster')) {
      return SpellClass.wizard;
    }
    return switch (_selectedClassSlug.toLowerCase()) {
      'wizard' => SpellClass.wizard,
      'cleric' => SpellClass.cleric,
      'druid' => SpellClass.druid,
      'bard' => SpellClass.bard,
      'sorcerer' => SpellClass.sorcerer,
      'warlock' => SpellClass.warlock,
      'artificer' => SpellClass.artificer,
      'ranger' => SpellClass.ranger,
      'paladin' => SpellClass.paladin,
      _ => null,
    };
  }

  // --------------------------------------------------------------------------
  // STEP 5: SPELLS
  // --------------------------------------------------------------------------
  Widget _buildStep5Spells(ThemeData theme, TabletopColors? customColors) {
    if (!_isSpellcaster) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 40, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              'No Spellcasting Advancement at Level $_targetClassNewLevel',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '$_selectedClassSlug does not learn or prepare spells at this level.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final edition = widget.character.id.ruleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;
    final defaultSpellClass = _targetSpellClass;
    final maxLvl = _maxAccessibleSpellLevel;
    final castingMod = _getCastingModifier(_selectedClassSlug);
    final isDark = theme.brightness == Brightness.dark;

    final limits = SpellAllocationValidator.getLimitsForClass(
      classSlug: _selectedClassSlug,
      classLevel: _targetClassNewLevel,
      abilityModifier: castingMod,
      subclassSlug: _effectiveSubclassSlug,
      edition: edition,
    );

    final isMagicalSecretsActive = limits.magicalSecretsCount > 0 || limits.allowedMagicalSecretClasses.isNotEmpty;
    final isMysticArcanumActive = limits.mysticArcanumLevel > 0;
    final alwaysPreparedSpells = SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: _selectedClassSlug,
      subclassSlug: _effectiveSubclassSlug,
      classLevel: _targetClassNewLevel,
      edition: edition,
    );

    // Filter spells based on class list, active Magical Secrets, or specific cross-list browsing
    final allClassSpells = SpellbookLibrary.allSpells.where((s) {
      if (s.level > maxLvl) return false;

      if (_showAllSpellListsForSecrets) {
        return true;
      }

      final activeClassFilter = _selectedSpellListSource ?? defaultSpellClass;
      if (activeClassFilter == null) return s.level <= maxLvl;

      final rules = s.getRules(edition);
      final isClassSpell = rules.classes.contains(activeClassFilter);
      final isExpanded = SubclassSpellsLibrary.isExpandedSpell(_selectedClassSlug, _effectiveSubclassSlug, s, edition);
      return isClassSpell || isExpanded;
    }).toList();

    final filtered = allClassSpells.where((s) {
      if (_spellSearchQuery.isEmpty) return true;
      final q = _spellSearchQuery.toLowerCase();
      return s.getName(edition).toLowerCase().contains(q) ||
          s.id.toLowerCase().contains(q);
    }).toList();

    final existingCantripSlugs = widget.character.cantrips.map((c) => c.slug).toSet();
    final availableCantrips = filtered.where((s) => s.level == 0 && !existingCantripSlugs.contains(s.id)).toList();
    final availableLeveled = filtered.where((s) => s.level > 0).toList();

    final previousClassLevel = math.max(0, _targetClassNewLevel - 1);
    final previousLimits = previousClassLevel > 0
        ? SpellAllocationValidator.getLimitsForClass(
            classSlug: _selectedClassSlug,
            classLevel: previousClassLevel,
            abilityModifier: castingMod,
            subclassSlug: _effectiveSubclassSlug,
            edition: edition,
          )
        : const SpellAllocationLimits.nonCaster();

    final isMysticArcanumMilestone = _selectedClassSlug.toLowerCase() == 'warlock' &&
        limits.mysticArcanumLevel > previousLimits.mysticArcanumLevel;

    final availableMysticArcanumSpells = isMysticArcanumMilestone
        ? SpellbookLibrary.allSpells.where((s) {
            if (s.level != limits.mysticArcanumLevel) return false;
            final rules = s.getRules(edition);
            final isWarlock = rules.classes.contains(SpellClass.warlock);
            final isExpanded = SubclassSpellsLibrary.isExpandedSpell(
              _selectedClassSlug,
              _effectiveSubclassSlug,
              s,
              edition,
            );
            return isWarlock || isExpanded;
          }).toList()
        : <SpellItem>[];

    final filteredMysticArcanumSpells = availableMysticArcanumSpells.where((s) {
      if (_spellSearchQuery.isEmpty) return true;
      final q = _spellSearchQuery.toLowerCase();
      return s.getName(edition).toLowerCase().contains(q) || s.id.toLowerCase().contains(q);
    }).toList();

    final gainedCantripsProgression = math.max(0, limits.maxCantrips - previousLimits.maxCantrips);
    final gainedSpellsProgression = math.max(0, limits.maxSpellsKnown - previousLimits.maxSpellsKnown);

    final curCantripsCount = widget.character.cantrips.length;
    final maxAllowedNewCantrips = math.max(gainedCantripsProgression, limits.maxCantrips - curCantripsCount);

    final effSub = _effectiveSubclassSlug?.toLowerCase() ?? '';
    final isWizard = _selectedClassSlug.toLowerCase() == 'wizard';
    final isSpontaneous = ['sorcerer', 'bard', 'warlock'].contains(_selectedClassSlug.toLowerCase()) ||
        (_selectedClassSlug.toLowerCase() == 'ranger' && edition == DmRulesEdition.v2014) ||
        effSub.contains('eldritch_knight') ||
        effSub.contains('arcane_trickster');

    int maxAllowedNewSpells;
    if (isWizard) {
      maxAllowedNewSpells = limits.maxSpellbookLevelUpScribe; // 2
    } else if (isSpontaneous) {
      final isReplacing = _replacedSpellId != null;
      final curKnownCount = widget.character.spellsKnown.length;
      final catchUpDelta = math.max(0, limits.maxSpellsKnown - curKnownCount);
      final baseNewSpells = math.max(gainedSpellsProgression, catchUpDelta);
      maxAllowedNewSpells = baseNewSpells + (isReplacing ? 1 : 0);
    } else {
      // Prepared casters
      final curPrepCount = widget.character.spellsPrepared.length;
      final delta = math.max(0, limits.maxSpellsPrepared - curPrepCount);
      maxAllowedNewSpells = math.max(1, delta + (_replacedSpellId != null ? 1 : 0));
    }

    final replaceableSpells = widget.character.spellsKnown.isNotEmpty
        ? widget.character.spellsKnown
        : widget.character.spellsPrepared;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Spells & Cantrips Advancement',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
              ),
            ),
            if (isMagicalSecretsActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.amberAccent),
                    SizedBox(width: 4),
                    Text(
                      'MAGICAL SECRETS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select newly learned, prepared, or subclass spells for $_selectedClassSlug (Max Spell Level: $maxLvl).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'Quota for Level $_targetClassNewLevel: ${_newSpells.length}/$maxAllowedNewSpells New Leveled Spell(s)${maxAllowedNewCantrips > 0 ? ", ${_newCantrips.length}/$maxAllowedNewCantrips New Cantrip(s)" : ", 0 New Cantrips allowed ($curCantripsCount/${limits.maxCantrips} already known)"}${isMysticArcanumMilestone ? " + 1 Mystic Arcanum (Level ${limits.mysticArcanumLevel})" : ""}.',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 12),

        // Subclass Always-Prepared Spells Alert Card
        if (alwaysPreparedSpells.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified, size: 14, color: Colors.tealAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Subclass Granted Spells (Always Prepared, Free Quota):',
                        style: theme.textTheme.labelSmall?.copyWith(color: Colors.tealAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: alwaysPreparedSpells.map((s) {
                    return ActionChip(
                      avatar: DndGlyph.spell(school: s.school, level: s.level, size: 14, isDarkMode: true),
                      visualDensity: VisualDensity.compact,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${s.getName(edition)} (L${s.level})', style: const TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline, size: 12, color: Colors.tealAccent),
                        ],
                      ),
                      onPressed: () {
                        HapticService.selectionTick(context);
                        SpellComparisonDialog.show(
                          context,
                          spell: s,
                          edition: edition,
                          isPinned: false,
                          onTogglePin: () {},
                        );
                      },
                      backgroundColor: Colors.teal.shade800.withValues(alpha: 0.4),
                      side: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.3)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Spell Replacement (Spell Swapping) Section for Spontaneous / Known Casters
        if (isSpontaneous && replaceableSpells.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.swap_horiz, size: 16, color: Colors.amberAccent),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Replace a Known Spell (Optional - 1 per level-up):',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                      ),
                    ),
                    if (_replacedSpellId != null)
                      TextButton(
                        onPressed: () => setState(() => _replacedSpellId = null),
                        child: const Text('Cancel Swap', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _replacedSpellId == null
                      ? 'You may swap one existing spell you know for a new one from your spell list.'
                      : 'Selected spell will be forgotten and replaced with your new selection below.',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: replaceableSpells.map((s) {
                    final isReplaced = _replacedSpellId == s.slug;
                    final spellItem = SpellbookLibrary.getSpellById(s.slug) ?? SpellbookLibrary.findSpell(s.displayName);
                    return Container(
                      decoration: BoxDecoration(
                        color: isReplaced
                            ? Colors.redAccent.withValues(alpha: 0.25)
                            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isReplaced ? Colors.redAccent : Colors.amberAccent.withValues(alpha: 0.4),
                          width: isReplaced ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.horizontal(
                              left: const Radius.circular(8),
                              right: Radius.circular(spellItem != null ? 0 : 8),
                            ),
                            onTap: () {
                              HapticService.selectionTick(context);
                              setState(() {
                                _replacedSpellId = isReplaced ? null : s.slug;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isReplaced)
                                    const Icon(Icons.close, size: 13, color: Colors.redAccent)
                                  else
                                    const Icon(Icons.swap_horiz, size: 13, color: Colors.amberAccent),
                                  const SizedBox(width: 5),
                                  Text(
                                    isReplaced ? 'Replacing: ${s.displayName}' : s.displayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isReplaced ? Colors.redAccent : Colors.white,
                                      decoration: isReplaced ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (spellItem != null) ...[
                            Container(
                              width: 1,
                              height: 16,
                              color: Colors.amberAccent.withValues(alpha: 0.3),
                            ),
                            Tooltip(
                              message: 'Spell info: ${s.displayName}',
                              child: InkWell(
                                key: Key('replaceable_spell_info_${s.slug}'),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                onTap: () {
                                  HapticService.selectionTick(context);
                                  SpellComparisonDialog.show(
                                    context,
                                    spell: spellItem,
                                    edition: edition,
                                    isPinned: false,
                                    onTogglePin: () {},
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                                  child: Icon(Icons.info_outline, size: 13, color: Colors.amberAccent),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Mystic Arcanum Milestone Callout & Selection
        if (isMysticArcanumActive) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade900.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.deepPurpleAccent),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.deepPurpleAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mystic Arcanum Milestone (Level ${limits.mysticArcanumLevel} Spell)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurpleAccent),
                          ),
                          Text(
                            'Choose one Level ${limits.mysticArcanumLevel} Warlock spell. You can cast it once per long rest without expending a spell slot. This does NOT consume your normal spell known quota.',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (isMysticArcanumMilestone) ...[
                  const SizedBox(height: 10),
                  const Divider(color: Colors.deepPurpleAccent, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Mystic Arcanum Spell:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        _selectedMysticArcanumSpellId != null ? '1/1 Arcanum Selected' : '0/1 Arcanum Selected',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _selectedMysticArcanumSpellId != null ? Colors.amberAccent : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (filteredMysticArcanumSpells.isEmpty)
                    Text(
                      'No matching level ${limits.mysticArcanumLevel} Warlock spells found.',
                      style: const TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredMysticArcanumSpells.map((s) {
                        final isSelected = _selectedMysticArcanumSpellId == s.id;
                        return ChoiceChip(
                          avatar: DndGlyph.spell(
                            school: s.school,
                            level: s.level,
                            size: 16,
                            isDarkMode: true,
                          ),
                          label: Text(s.getName(edition)),
                          selected: isSelected,
                          selectedColor: Colors.deepPurpleAccent.shade700,
                          onSelected: (selected) {
                            setState(() {
                              _selectedMysticArcanumSpellId = selected ? s.id : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Magical Secrets List Switcher Bar
        if (isMagicalSecretsActive) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Spell List: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ChoiceChip(
                  label: const Text('Bard List'),
                  selected: _selectedSpellListSource == null && !_showAllSpellListsForSecrets,
                  onSelected: (selected) {
                    setState(() {
                      _selectedSpellListSource = null;
                      _showAllSpellListsForSecrets = false;
                    });
                  },
                ),
                const SizedBox(width: 6),
                if (limits.allowedMagicalSecretClasses.contains(SpellClass.wizard))
                  ChoiceChip(
                    label: const Text('Wizard'),
                    selected: _selectedSpellListSource == SpellClass.wizard,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSpellListSource = selected ? SpellClass.wizard : null;
                        _showAllSpellListsForSecrets = false;
                      });
                    },
                  ),
                const SizedBox(width: 6),
                if (limits.allowedMagicalSecretClasses.contains(SpellClass.cleric))
                  ChoiceChip(
                    label: const Text('Cleric'),
                    selected: _selectedSpellListSource == SpellClass.cleric,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSpellListSource = selected ? SpellClass.cleric : null;
                        _showAllSpellListsForSecrets = false;
                      });
                    },
                  ),
                const SizedBox(width: 6),
                if (limits.allowedMagicalSecretClasses.contains(SpellClass.druid))
                  ChoiceChip(
                    label: const Text('Druid'),
                    selected: _selectedSpellListSource == SpellClass.druid,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSpellListSource = selected ? SpellClass.druid : null;
                        _showAllSpellListsForSecrets = false;
                      });
                    },
                  ),
                const SizedBox(width: 6),
                if (limits.allowedMagicalSecretClasses.length > 4 || edition == DmRulesEdition.v2014)
                  ChoiceChip(
                    label: const Text('All Spell Lists ✨'),
                    selected: _showAllSpellListsForSecrets,
                    onSelected: (selected) {
                      setState(() {
                        _showAllSpellListsForSecrets = selected;
                        _selectedSpellListSource = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Selected Spells Summary Chips
        if (_newCantrips.isNotEmpty || _newSpells.isNotEmpty || _selectedMysticArcanumSpellId != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected for this Level Up:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (_selectedMysticArcanumSpellId != null) () {
                      final spell = SpellbookLibrary.getSpellById(_selectedMysticArcanumSpellId!);
                      return InputChip(
                        avatar: spell != null
                            ? DndGlyph.spell(
                                school: spell.school,
                                level: spell.level,
                                size: 16,
                                isDarkMode: true,
                              )
                            : null,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Mystic Arcanum: ${spell?.getName(edition) ?? _selectedMysticArcanumSpellId}'),
                            if (spell != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.info_outline, size: 12, color: Colors.amberAccent),
                            ],
                          ],
                        ),
                        backgroundColor: Colors.deepPurple.shade800.withValues(alpha: 0.6),
                        onDeleted: () => setState(() => _selectedMysticArcanumSpellId = null),
                        onPressed: spell != null
                            ? () {
                                HapticService.selectionTick(context);
                                SpellComparisonDialog.show(
                                  context,
                                  spell: spell,
                                  edition: edition,
                                  isPinned: false,
                                  onTogglePin: () {},
                                );
                              }
                            : null,
                      );
                    }(),
                    ..._newCantrips.map((c) {
                      final spell = SpellbookLibrary.getSpellById(c);
                      return InputChip(
                        avatar: spell != null
                            ? DndGlyph.spell(
                                school: spell.school,
                                level: 0,
                                size: 16,
                                isDarkMode: true,
                              )
                            : null,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Cantrip: ${spell?.getName(edition) ?? c}'),
                            if (spell != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.info_outline, size: 12, color: Colors.purpleAccent),
                            ],
                          ],
                        ),
                        backgroundColor: Colors.purple.shade800.withValues(alpha: 0.5),
                        onDeleted: () => setState(() => _newCantrips.remove(c)),
                        onPressed: spell != null
                            ? () {
                                HapticService.selectionTick(context);
                                SpellComparisonDialog.show(
                                  context,
                                  spell: spell,
                                  edition: edition,
                                  isPinned: false,
                                  onTogglePin: () {},
                                );
                              }
                            : null,
                      );
                    }),
                    ..._newSpells.map((s) {
                      final spell = SpellbookLibrary.getSpellById(s);
                      return InputChip(
                        avatar: spell != null
                            ? DndGlyph.spell(
                                school: spell.school,
                                level: spell.level,
                                size: 16,
                                isDarkMode: true,
                              )
                            : null,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${spell?.levelLabel ?? "Spell"}: ${spell?.getName(edition) ?? s}'),
                            if (spell != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.info_outline, size: 12, color: Colors.cyanAccent),
                            ],
                          ],
                        ),
                        backgroundColor: Colors.cyan.shade800.withValues(alpha: 0.5),
                        onDeleted: () => setState(() => _newSpells.remove(s)),
                        onPressed: spell != null
                            ? () {
                                HapticService.selectionTick(context);
                                SpellComparisonDialog.show(
                                  context,
                                  spell: spell,
                                  edition: edition,
                                  isPinned: false,
                                  onTogglePin: () {},
                                );
                              }
                            : null,
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Search Bar
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search Available Class Spells',
            prefixIcon: Icon(Icons.search, size: 20),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _spellSearchQuery = v.trim()),
        ),
        const SizedBox(height: 12),

        // Available Cantrips Grid
        if (availableCantrips.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Available Cantrips (${availableCantrips.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: maxAllowedNewCantrips > 0
                        ? Colors.purpleAccent.withValues(alpha: 0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: maxAllowedNewCantrips > 0 ? Colors.purpleAccent : Colors.white24,
                    ),
                  ),
                  child: Text(
                    maxAllowedNewCantrips > 0
                        ? '${_newCantrips.length}/$maxAllowedNewCantrips Selected'
                        : '0 New Allowed ($curCantripsCount/${limits.maxCantrips} known)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: maxAllowedNewCantrips > 0 ? Colors.purpleAccent : Colors.white60,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableCantrips.map((c) {
              final isChosen = _newCantrips.contains(c.id);
              return _buildSpellSelectionChip(
                context: context,
                spell: c,
                isSelected: isChosen,
                accentColor: Colors.purpleAccent,
                edition: edition,
                onSelected: (selected) {
                  if (selected) {
                    if (_newCantrips.length >= maxAllowedNewCantrips) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            maxAllowedNewCantrips == 0
                                ? 'No new cantrips granted at Level $_targetClassNewLevel (already at maximum $curCantripsCount/${limits.maxCantrips}).'
                                : 'Cannot select more than $maxAllowedNewCantrips new cantrip(s) at Level $_targetClassNewLevel.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    setState(() => _newCantrips.add(c.id));
                  } else {
                    setState(() => _newCantrips.remove(c.id));
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Available Leveled Spells Grid (Grouped by Level)
        if (availableLeveled.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available Leveled Spells (Up to Level $maxLvl)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_newSpells.length}/$maxAllowedNewSpells Selected',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(() {
            final spellsByLevel = <int, List<SpellItem>>{};
            for (final s in availableLeveled) {
              (spellsByLevel[s.level] ??= []).add(s);
            }
            final sortedLevels = spellsByLevel.keys.toList()..sort();

            return sortedLevels.map((lvl) {
              final levelSpells = spellsByLevel[lvl]!;
              final levelLabel = switch (lvl) {
                1 => '1st-Level Spells',
                2 => '2nd-Level Spells',
                3 => '3rd-Level Spells',
                _ => '${lvl}th-Level Spells',
              };
              final selectedAtThisLevel = levelSpells.where((s) => _newSpells.contains(s.id)).length;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedAtThisLevel > 0
                        ? Colors.cyanAccent.withValues(alpha: 0.4)
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selectedAtThisLevel > 0
                            ? Colors.cyan.shade900.withValues(alpha: 0.3)
                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'LEVEL $lvl',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              levelLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedAtThisLevel > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$selectedAtThisLevel selected',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${levelSpells.length} spells',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Spells in this Level
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: levelSpells.map((s) {
                          final isChosen = _newSpells.contains(s.id);
                          return _buildSpellSelectionChip(
                            context: context,
                            spell: s,
                            isSelected: isChosen,
                            accentColor: Colors.cyanAccent,
                            edition: edition,
                            onSelected: (selected) {
                              if (selected) {
                                if (_newSpells.length >= maxAllowedNewSpells) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        maxAllowedNewSpells == 0
                                            ? 'No new leveled spells granted at Level $_targetClassNewLevel.'
                                            : 'Cannot select more than $maxAllowedNewSpells new spell(s) at Level $_targetClassNewLevel.',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                setState(() => _newSpells.add(s.id));
                              } else {
                                setState(() => _newSpells.remove(s.id));
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            });
          })(),
          const SizedBox(height: 12),
        ],

        if (availableCantrips.isEmpty && availableLeveled.isEmpty && _spellSearchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No spells found matching "$_spellSearchQuery"',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ),

        // Custom Spell Entry Option
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customSpellController,
                decoration: const InputDecoration(
                  labelText: 'Add Custom Spell / Cantrip',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.add),
              tooltip: 'Add Custom Spell',
              onPressed: () {
                final txt = _customSpellController.text.trim();
                if (txt.isNotEmpty) {
                  if (_newSpells.length >= maxAllowedNewSpells) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          maxAllowedNewSpells == 0
                              ? 'No new leveled spells granted at Level $_targetClassNewLevel.'
                              : 'Cannot select more than $maxAllowedNewSpells new spell(s) at Level $_targetClassNewLevel.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  HapticService.selectionTick(context);
                  setState(() {
                    _newSpells.add(txt);
                    _customSpellController.clear();
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpellSelectionChip({
    required BuildContext context,
    required SpellItem spell,
    required bool isSelected,
    required Color accentColor,
    required DmRulesEdition edition,
    required ValueChanged<bool> onSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final displayName = spell.level == 0
        ? spell.getName(edition)
        : '${spell.getName(edition)} (L${spell.level})';

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.22)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : (isDark ? Colors.white24 : Colors.black26),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              onTap: () {
                HapticService.selectionTick(context);
                onSelected(!isSelected);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DndGlyph.spell(
                      school: spell.school,
                      level: spell.level,
                      size: 16,
                      isDarkMode: isDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? accentColor : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check, size: 14, color: accentColor),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 18,
              color: isSelected
                  ? accentColor.withValues(alpha: 0.4)
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
            Tooltip(
              message: 'Spell info: ${spell.getName(edition)}',
              child: InkWell(
                key: Key('spell_info_btn_${spell.id}'),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                onTap: () {
                  HapticService.selectionTick(context);
                  SpellComparisonDialog.show(
                    context,
                    spell: spell,
                    edition: edition,
                    isPinned: false,
                    onTogglePin: () {},
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: isSelected ? accentColor : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STEP 6: SUMMARY & CONFIRMATION
  // --------------------------------------------------------------------------
  Widget _buildStep6Summary(ThemeData theme, TabletopColors? customColors) {
    final candidateRequest = _buildRequest();
    final updatedChar = CharacterProgressionEngine.applyLevelUp(widget.character, candidateRequest);
    final oldStats = CharacterEvaluationEngine.evaluate(widget.character);
    final newStats = CharacterEvaluationEngine.evaluate(updatedChar);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Level-Up Summary & Diff Preview', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Review changes before applying to your character sheet.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              _buildDiffRow('Total Level', '${widget.character.totalLevel}', '$_newTotalLevel', theme),
              _buildDiffRow('Class Progression',
                  '$_selectedClassSlug $_targetClassCurrentLevel',
                  '$_selectedClassSlug $_targetClassNewLevel', theme),
              _buildDiffRow('Hit Dice Pool',
                  '${widget.character.resources.currentHitDice[_currentHitDie] ?? 0} $_currentHitDie',
                  '${updatedChar.resources.currentHitDice[_currentHitDie] ?? 0} $_currentHitDie', theme),
              _buildDiffRow('Maximum HP', '${oldStats.maxHp}', '${newStats.maxHp} (+${newStats.maxHp - oldStats.maxHp})', theme, highlightNew: true),
              _buildDiffRow('Proficiency Bonus', '+${oldStats.proficiencyBonus}', '+${newStats.proficiencyBonus}', theme),
              if (_isAsiEligible && _isAsiSelected)
                _buildDiffRow('ASI Bonus', 'None', _isAsiPlusTwo ? '+2 ${_asiSingleAbility.name}' : '+1 ${_asiDualAbility1.name}, +1 ${_asiDualAbility2.name}', theme, highlightNew: true),
              if (_isAsiEligible && !_isAsiSelected) ...[
                _buildDiffRow('Feat Gained', 'None', _selectedFeatName, theme, highlightNew: true),
                () {
                  final feat = SrdFeatsLibrary.findBySlug(_selectedFeatSlug);
                  final chosenAbility = _selectedFeatAbility ??
                      (feat?.selectableAbilities.isNotEmpty == true ? feat!.selectableAbilities.first : null);
                  if (feat != null && feat.hasAbilityScoreIncrease && chosenAbility != null) {
                    return Column(
                      children: [
                        _buildDiffRow('Feat Ability', 'None', '+${feat.statIncreaseAmount} ${chosenAbility.shortName}', theme, highlightNew: true),
                        if (feat.grantsSavingThrowProficiency)
                          _buildDiffRow('Feat Saving Throw', 'None', '${chosenAbility.shortName} Save Proficiency', theme, highlightNew: true),
                        if (feat.hasSkillProficiencyChoice && _selectedFeatSkill != null)
                          _buildDiffRow('Feat Skill', 'None', '${_selectedFeatSkill!.displayName} Proficiency', theme, highlightNew: true),
                        if (feat.hasExpertiseChoice && _selectedFeatExpertise != null)
                          _buildDiffRow('Feat Expertise', 'None', '${_selectedFeatExpertise!.displayName} Expertise', theme, highlightNew: true),
                      ],
                    );
                  }
                  if (feat != null && (feat.hasSkillProficiencyChoice || feat.hasExpertiseChoice)) {
                    return Column(
                      children: [
                        if (feat.hasSkillProficiencyChoice && _selectedFeatSkill != null)
                          _buildDiffRow('Feat Skill', 'None', '${_selectedFeatSkill!.displayName} Proficiency', theme, highlightNew: true),
                        if (feat.hasExpertiseChoice && _selectedFeatExpertise != null)
                          _buildDiffRow('Feat Expertise', 'None', '${_selectedFeatExpertise!.displayName} Expertise', theme, highlightNew: true),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }(),
              ],
              if (_selectedSubclass != null)
                _buildDiffRow('Subclass', 'None', _selectedSubclass!, theme, highlightNew: true),
              if (_selectedMysticArcanumSpellId != null) () {
                final spell = SpellbookLibrary.getSpellById(_selectedMysticArcanumSpellId!);
                final name = spell?.getName(widget.character.id.ruleset == RulesetVersion.v2024 ? DmRulesEdition.v2024 : DmRulesEdition.v2014) ?? _selectedMysticArcanumSpellId!;
                return _buildDiffRow('Mystic Arcanum', 'None', name, theme, highlightNew: true);
              }(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Languages & Tools Gained Panel
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: customColors?.cardBorder ?? theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Languages & Tool Proficiencies Gained',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showLevelUpAddLanguageDialog(context),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Language', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                      TextButton.icon(
                        onPressed: () => _showLevelUpAddToolDialog(context),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Tool', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_newLanguages.isEmpty && _newToolProficiencies.isEmpty)
                const Text(
                  'No additional languages or tools gained this level. Tap above to add training or DM awards.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white54, fontStyle: FontStyle.italic),
                )
              else ...[
                if (_newLanguages.isNotEmpty) ...[
                  const Text('New Languages:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _newLanguages.map((l) => Chip(
                      label: Text(l, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 12),
                      onDeleted: () => setState(() => _newLanguages.remove(l)),
                    )).toList(),
                  ),
                  const SizedBox(height: 6),
                ],
                if (_newToolProficiencies.isNotEmpty) ...[
                  const Text('New Tools:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _newToolProficiencies.map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 12),
                      onDeleted: () => setState(() => _newToolProficiencies.remove(t)),
                    )).toList(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showLevelUpAddLanguageDialog(BuildContext context) {
    final customController = TextEditingController();
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final existing = {
            ...widget.character.languages.map((l) => l.toLowerCase()),
            ..._newLanguages.map((l) => l.toLowerCase()),
          };
          final availableStandard = SrdProficienciesLibrary.standardLanguages
              .where((l) => !existing.contains(l.toLowerCase()))
              .where((l) => l.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();
          final availableExotic = SrdProficienciesLibrary.exoticLanguages
              .where((l) => !existing.contains(l.toLowerCase()))
              .where((l) => l.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return AlertDialog(
            title: const Text('Add Language Gained'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: customController,
                      decoration: const InputDecoration(
                        labelText: 'Search or Custom Language',
                        hintText: 'Enter language...',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),
                    if (availableStandard.isNotEmpty) ...[
                      const Text('Standard Languages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: availableStandard.map((lang) {
                          return ActionChip(
                            label: Text(lang),
                            onPressed: () {
                              setState(() => _newLanguages.add(lang));
                              Navigator.of(ctx).pop();
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (availableExotic.isNotEmpty) ...[
                      const Text('Exotic Languages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: availableExotic.map((lang) {
                          return ActionChip(
                            label: Text(lang),
                            onPressed: () {
                              setState(() => _newLanguages.add(lang));
                              Navigator.of(ctx).pop();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final custom = customController.text.trim();
                  if (custom.isNotEmpty) {
                    setState(() => _newLanguages.add(custom));
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add Custom'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLevelUpAddToolDialog(BuildContext context) {
    final customController = TextEditingController();
    ToolCategory selectedCategory = ToolCategory.artisansTools;
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final existing = {
            ...widget.character.toolProficiencies.map((t) => t.toLowerCase()),
            ..._newToolProficiencies.map((t) => t.toLowerCase()),
          };
          final allCategoryTools = switch (selectedCategory) {
            ToolCategory.artisansTools => SrdProficienciesLibrary.artisansTools,
            ToolCategory.gamingSets => SrdProficienciesLibrary.gamingSets,
            ToolCategory.musicalInstruments => SrdProficienciesLibrary.musicalInstruments,
            ToolCategory.kits => SrdProficienciesLibrary.kitsAndSpecialized,
            ToolCategory.vehicles => SrdProficienciesLibrary.vehicles,
          };
          final availableTools = allCategoryTools
              .where((t) => !existing.contains(t.toLowerCase()))
              .where((t) => t.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return AlertDialog(
            title: const Text('Add Tool Proficiency Gained'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: customController,
                      decoration: const InputDecoration(
                        labelText: 'Search or Custom Tool',
                        hintText: 'Search or enter custom tool name...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => setDialogState(() => searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ToolCategory.values.map((cat) {
                          final isSel = selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat.displayName, style: const TextStyle(fontSize: 11)),
                              selected: isSel,
                              onSelected: (_) => setDialogState(() => selectedCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (availableTools.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: availableTools.map((tool) {
                          return ActionChip(
                            label: Text(tool),
                            onPressed: () {
                              setState(() => _newToolProficiencies.add(tool));
                              Navigator.of(ctx).pop();
                            },
                          );
                        }).toList(),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No matching tools in this category.', style: TextStyle(fontSize: 12, color: Colors.white54)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final custom = customController.text.trim();
                  if (custom.isNotEmpty) {
                    setState(() => _newToolProficiencies.add(custom));
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add Custom'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiffRow(String label, String oldVal, String newVal, ThemeData theme, {bool highlightNew = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            oldVal,
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            newVal,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlightNew ? Colors.greenAccent : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, LevelUpValidationResult validation) {
    final isLastStep = _currentStep == 5;
    final canAdvance = validation.isValid;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: () {
                HapticService.selectionTick(context);
                setState(() => _currentStep--);
              },
              icon: const Icon(Icons.chevron_left),
              label: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          if (!isLastStep)
            FilledButton.icon(
              onPressed: canAdvance
                  ? () {
                      HapticService.selectionTick(context);
                      setState(() => _currentStep++);
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next Step'),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.purpleAccent),
              onPressed: canAdvance ? _onConfirmLevelUp : null,
              icon: const Icon(Icons.check),
              label: const Text('CONFIRM LEVEL UP', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
