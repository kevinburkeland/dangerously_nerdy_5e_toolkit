import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/spellbook_data.dart';
import '../../services/haptic_service.dart';
import '../../services/rules/character_progression_engine.dart';
import '../../services/rules/character_evaluation_engine.dart';
import '../../services/rules/dnd_5e_rules_engine.dart';
import '../../theme/app_theme.dart';

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

  // Step 4: ASI / Feat
  bool _isAsiSelected = true;
  bool _isAsiPlusTwo = true;
  AbilityType _asiSingleAbility = AbilityType.strength;
  AbilityType _asiDualAbility1 = AbilityType.strength;
  AbilityType _asiDualAbility2 = AbilityType.dexterity;
  String _selectedFeatSlug = 'tough';
  String _selectedFeatName = 'Tough';

  // Step 5: Spells
  final List<String> _newCantrips = [];
  final List<String> _newSpells = [];
  String _spellSearchQuery = '';
  final TextEditingController _customCantripController = TextEditingController();
  final TextEditingController _customSpellController = TextEditingController();

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

  static const List<Map<String, String>> _popularFeats = [
    {'slug': 'tough', 'name': 'Tough', 'desc': '+2 Hit Points per character level'},
    {'slug': 'war_caster', 'name': 'War Caster', 'desc': 'Advantage on concentration & spell opportunity attacks'},
    {'slug': 'alert', 'name': 'Alert', 'desc': '+5 to Initiative & cannot be surprised'},
    {'slug': 'mobile', 'name': 'Mobile', 'desc': '+10 ft speed & free disengage on melee attack'},
    {'slug': 'lucky', 'name': 'Lucky', 'desc': '3 Luck Points to reroll d20 rolls'},
    {'slug': 'sentinel', 'name': 'Sentinel', 'desc': 'Opportunity attacks stop movement to 0 ft'},
    {'slug': 'sharpshooter', 'name': 'Sharpshooter', 'desc': 'Ignore half/three-quarters cover & -5/+10 ranged damage'},
    {'slug': 'great_weapon_master', 'name': 'Great Weapon Master', 'desc': 'Bonus attack on crit/kill & -5/+10 heavy weapon damage'},
    {'slug': 'fey_touched', 'name': 'Fey Touched', 'desc': '+1 INT/WIS/CHA, Misty Step & 1st level Div/Ench spell'},
    {'slug': 'shadow_touched', 'name': 'Shadow Touched', 'desc': '+1 INT/WIS/CHA, Invisibility & 1st level Necro/Illusion spell'},
  ];

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
        asiChoice = AsiOrFeatChoice.feat(EntityReference<DomainEntity>(
          refType: EntityType.feat,
          slug: _selectedFeatSlug,
          displayName: _selectedFeatName,
        ));
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

    final cantripRefs = _newCantrips.map((c) {
      final spell = SpellbookLibrary.getSpellById(c);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: spell?.id ?? c.toLowerCase().replaceAll(' ', '_'),
        displayName: spell?.getName(edition) ?? c,
      );
    }).toList();

    final spellRefs = _newSpells.map((s) {
      final spell = SpellbookLibrary.getSpellById(s);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: spell?.id ?? s.toLowerCase().replaceAll(' ', '_'),
        displayName: spell?.getName(edition) ?? s,
      );
    }).toList();

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
    );
  }

  void _onConfirmLevelUp() {
    final request = _buildRequest();
    final updated = CharacterProgressionEngine.applyLevelUp(widget.character, request);
    HapticService.selectionTick(context);
    widget.onLevelUpApplied?.call(updated);
    Navigator.of(context).pop(updated);
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
            prefixIcon: const Icon(Icons.shield_outlined),
          ),
          items: _availableClasses.map((cls) {
            final isCurrent = widget.character.progression.classes.any((c) => c.classRef.slug.toLowerCase() == cls['slug']);
            final label = '${cls['name']} (${cls['hitDie']}) ${isCurrent ? "— Current" : "— Multiclass (Req: ${cls['prereq']})"}';
            return DropdownMenuItem(
              value: cls['slug'],
              child: Text(label, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedClassSlug = val;
                _isMulticlass = !widget.character.progression.classes.any((c) => c.classRef.slug.toLowerCase() == val);
                _rolledHp = _fixedAverageHp;
                _selectedSubclass = null;
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
            const ButtonSegment(
              value: false,
              icon: Icon(Icons.casino_outlined),
              label: Text('Interactive Roll'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Features & Archetypes',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Unlocking features for $_selectedClassSlug Level $_targetClassNewLevel.',
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
                  onChanged: (v) => setState(() => _selectedSubclass = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
            decoration: const InputDecoration(labelText: 'Select Feat', border: OutlineInputBorder()),
            items: _popularFeats.map((f) => DropdownMenuItem(value: f['slug'], child: Text('${f['name']} — ${f['desc']}'))).toList(),
            onChanged: (v) {
              if (v != null) {
                final match = _popularFeats.firstWhere((f) => f['slug'] == v);
                setState(() {
                  _selectedFeatSlug = v;
                  _selectedFeatName = match['name']!;
                });
              }
            },
          ),
        ],
      ],
    );
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
      return (lvl ~/ 2).clamp(1, 5);
    }
    if (slug == 'artificer') {
      return ((lvl + 1) ~/ 2).clamp(1, 5);
    }
    if (_selectedSubclass != null &&
        (_selectedSubclass!.contains('eldritch_knight') || _selectedSubclass!.contains('arcane_trickster'))) {
      return ((lvl + 1) ~/ 3).clamp(1, 4);
    }
    return 1;
  }

  SpellClass? get _targetSpellClass {
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
    final edition = widget.character.id.ruleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;
    final spellClass = _targetSpellClass;
    final maxLvl = _maxAccessibleSpellLevel;

    final allClassSpells = SpellbookLibrary.allSpells.where((s) {
      if (spellClass == null) return s.level <= maxLvl;
      final rules = s.getRules(edition);
      return rules.classes.contains(spellClass) && s.level <= maxLvl;
    }).toList();

    final filtered = allClassSpells.where((s) {
      if (_spellSearchQuery.isEmpty) return true;
      final q = _spellSearchQuery.toLowerCase();
      return s.getName(edition).toLowerCase().contains(q) ||
          s.id.toLowerCase().contains(q);
    }).toList();

    final availableCantrips = filtered.where((s) => s.level == 0).toList();
    final availableLeveled = filtered.where((s) => s.level > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Spells & Cantrips Advancement',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
        const SizedBox(height: 4),
        Text(
          'Select newly learned, prepared, or subclass spells for $_selectedClassSlug (Max Spell Level: $maxLvl).',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),

        // Selected Spells Summary Chips
        if (_newCantrips.isNotEmpty || _newSpells.isNotEmpty) ...[
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
                    ..._newCantrips.map((c) {
                      final spell = SpellbookLibrary.getSpellById(c);
                      return Chip(
                        label: Text('Cantrip: ${spell?.getName(edition) ?? c}'),
                        backgroundColor: Colors.purple.shade800.withValues(alpha: 0.5),
                        onDeleted: () => setState(() => _newCantrips.remove(c)),
                      );
                    }),
                    ..._newSpells.map((s) {
                      final spell = SpellbookLibrary.getSpellById(s);
                      return Chip(
                        label: Text('${spell?.levelLabel ?? "Spell"}: ${spell?.getName(edition) ?? s}'),
                        backgroundColor: Colors.cyan.shade800.withValues(alpha: 0.5),
                        onDeleted: () => setState(() => _newSpells.remove(s)),
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
          Text('Available Cantrips (${availableCantrips.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purpleAccent)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableCantrips.map((c) {
              final isChosen = _newCantrips.contains(c.id);
              return FilterChip(
                selected: isChosen,
                selectedColor: Colors.purpleAccent.withValues(alpha: 0.35),
                label: Text(c.getName(edition)),
                avatar: Icon(Icons.star, size: 14, color: isChosen ? Colors.purpleAccent : Colors.white54),
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  setState(() {
                    if (selected) {
                      _newCantrips.add(c.id);
                    } else {
                      _newCantrips.remove(c.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Available Leveled Spells Grid
        if (availableLeveled.isNotEmpty) ...[
          Text('Available Leveled Spells (Up to Level $maxLvl)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.cyanAccent)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableLeveled.map((s) {
              final isChosen = _newSpells.contains(s.id);
              return FilterChip(
                selected: isChosen,
                selectedColor: Colors.cyanAccent.withValues(alpha: 0.35),
                label: Text('${s.getName(edition)} (L${s.level})'),
                avatar: Icon(Icons.auto_awesome, size: 14, color: isChosen ? Colors.cyanAccent : Colors.white54),
                onSelected: (selected) {
                  HapticService.selectionTick(context);
                  setState(() {
                    if (selected) {
                      _newSpells.add(s.id);
                    } else {
                      _newSpells.remove(s.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

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
              if (_isAsiEligible && !_isAsiSelected)
                _buildDiffRow('Feat Gained', 'None', _selectedFeatName, theme, highlightNew: true),
              if (_selectedSubclass != null)
                _buildDiffRow('Subclass', 'None', _selectedSubclass!, theme, highlightNew: true),
            ],
          ),
        ),
      ],
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
