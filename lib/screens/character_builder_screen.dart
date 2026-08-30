import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/characters/srd_feats_library.dart';
import '../models/characters/srd_classes_library.dart';
import '../models/characters/srd_species_library.dart';
import '../models/characters/srd_backgrounds_library.dart';
import '../models/characters/srd_equipment_library.dart';
import '../models/characters/subclass_spells_library.dart';
import '../models/magic_items/magic_item_library.dart';
import '../models/domain/core_types.dart';
import '../models/domain/character_models.dart';
import '../models/domain/entity_reference.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../models/domain/spell_monster_equipment.dart';
import '../models/party/party_purse.dart';
import '../models/spellbook_data.dart';
import '../services/haptic_service.dart';
import '../services/repository/layered_priority_repository.dart';
import '../services/repository/reference_resolver.dart';
import '../services/rules/character_factory.dart';
import '../services/rules/character_stat_calculator.dart';
import '../services/rules/dnd_5e_rules_engine.dart';
import '../services/rules/inventory_transaction_service.dart';
import '../services/rules/spell_allocation_validator.dart';
import '../services/rules/skill_trait_resolver.dart';
import '../services/persistence/character_persistence_service.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/formatted_markdown_text.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/glyphs/dnd_glyph.dart';
import '../widgets/room_banner_widget.dart';
import '../widgets/character_builder/level_up_wizard_dialog.dart';
import '../providers/character_sheet_controller.dart';
import '../widgets/character_sheet/character_header_banner.dart';
import '../widgets/character_sheet/character_vitals_hud.dart';
import '../widgets/character_sheet/ability_scores_ribbon.dart';
import '../widgets/character_sheet/character_sheet_tabs.dart';

/// Interactive Character Generator, Live State Sheet, and Multiclassing Studio
class CharacterBuilderScreen extends StatefulWidget {
  const CharacterBuilderScreen({super.key});

  @override
  State<CharacterBuilderScreen> createState() => _CharacterBuilderScreenState();
}

class _CharacterBuilderScreenState extends State<CharacterBuilderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late LayeredPriorityRepository _repository;
  late ReferenceResolver _resolver;

  // Active Edition
  DmRulesEdition _rulesEdition = DmRulesEdition.v2024;
  DmRulesEdition? _localEditionOverride;

  // Character Persistence & Roster
  final CharacterPersistenceService _persistenceService = CharacterPersistenceService();
  List<Character> _characterRoster = [];
  bool _isSelectorView = true; // Defaults to Character Selector
  String _rosterSearchQuery = '';
  RulesetVersion? _rosterRulesetFilter;

  // Active Character & State
  Character? _character;
  CharacterSheetController? _sheetController;

  // Guided Character Creation Wizard State
  int _wizardStep = 0;
  RulesetVersion _selectedRuleset = RulesetVersion.v2024;
  final TextEditingController _nameController = TextEditingController();
  String _selectedSpecies = 'human';
  String _selectedClass = 'fighter';
  String _selectedBackground = 'soldier';
  String _selectedFeat = 'tough';
  String? _wizardSelectedSubclass;
  final Map<String, List<String>> _wizardSelectedFeatureOptions = {};
  final Set<String> _selectedWizardCantrips = {};
  final Set<String> _selectedWizardSpells = {};
  String _selectedStartingEquipmentPreset = 'chain_and_sword';
  Set<SkillType> _wizardSelectedSkills = {SkillType.athletics, SkillType.intimidation};
  final Set<SkillType> _compensatorySkillPicks = {};
  final Set<SkillType> _speciesBonusSkillPicks = {};

  // Ability Allocation Mode
  String _abilityScoreMode = 'standard'; // 'standard', 'pointBuy', 'rolled', 'manual'
  String _rollMethod = 'standard_4d6'; // 'standard_4d6', 'classic_3d6_down', 'classic_3d6_nice', 'silly_d20'
  AbilityScores _wizardBaseScores = const AbilityScores.standardArray();
  final Map<AbilityType, int> _standardArrayPicks = {
    AbilityType.strength: 15,
    AbilityType.dexterity: 14,
    AbilityType.constitution: 13,
    AbilityType.intelligence: 12,
    AbilityType.wisdom: 10,
    AbilityType.charisma: 8,
  };

  // Rolled dice state
  List<int> _rolledPool = [15, 14, 13, 12, 10, 8];
  List<String> _rolledBreakdowns = [];
  final Map<AbilityType, int> _rolledAssignments = {
    AbilityType.strength: 15,
    AbilityType.dexterity: 14,
    AbilityType.constitution: 13,
    AbilityType.intelligence: 12,
    AbilityType.wisdom: 10,
    AbilityType.charisma: 8,
  };

  // Manual / Enter Your Own picks
  final Map<AbilityType, int> _manualPicks = {
    AbilityType.strength: 10,
    AbilityType.dexterity: 10,
    AbilityType.constitution: 10,
    AbilityType.intelligence: 10,
    AbilityType.wisdom: 10,
    AbilityType.charisma: 10,
  };

  // Lineage / Background Bonus Allocations
  final Set<AbilityType> _variantHumanBonuses = {AbilityType.strength, AbilityType.constitution};
  AbilityType _backgroundPrimaryBonus = AbilityType.strength; // +2 in 2024
  AbilityType _backgroundSecondaryBonus = AbilityType.constitution; // +1 in 2024

  final List<String> _suggestedNames = [
    'Valeros Ironclad',
    'Eldrin Shadowbane',
    'Kaelen Swift',
    'Lyra Sunseeker',
    'Thorin Stoneguard',
    'Aria Whisperwind',
    'Morgrim Battlehammer',
    'Zephyr Stormcaller',
    'Vespera Nightshade',
    'Rowan Oakheart',
    'Gideon Dawnbringer',
    'Cassian Brightwood',
  ];

  bool get _hasActiveCharacter => !_isSelectorView && _character != null;
  int get _expectedTabCount => _hasActiveCharacter ? 4 : 2;

  void _syncTabController() {
    final expected = _expectedTabCount;
    if (_tabController.length != expected) {
      final oldIndex = _tabController.index.clamp(0, expected - 1);
      final old = _tabController;
      _tabController = TabController(
        length: expected,
        initialIndex: oldIndex,
        vsync: this,
      );
      old.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _expectedTabCount, vsync: this);

    _repository = LayeredPriorityRepository();
    _resolver = ReferenceResolver(_repository);

    _initSampleRepository();
    _initDefaultCharacter();
  }

  void _initSampleRepository() {
    final baseLayer = PriorityLayer(
      layerId: 'base-srd',
      name: 'SRD Baseline',
      priority: LayerPriority.baseRuleset,
    );

    // Register all SRD items
    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'chain-mail', ruleset: RulesetVersion.v2024),
      name: 'Chain Mail',
      itemType: 'Heavy Armor',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy armor with Base AC 16.',
      customProperties: const {'baseAc': 16, 'armorType': 'heavy'},
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'leather-armor', ruleset: RulesetVersion.v2024),
      name: 'Leather Armor',
      itemType: 'Light Armor',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Light armor Base AC 11 + DEX modifier.',
      customProperties: const {'baseAc': 11, 'armorType': 'light'},
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'breastplate', ruleset: RulesetVersion.v2024),
      name: 'Breastplate',
      itemType: 'Medium Armor',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Medium armor Base AC 14 + DEX (max 2).',
      customProperties: const {
        'baseAc': 14,
        'armorType': 'medium',
        'maxDexBonus': 2
      },
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'shield', ruleset: RulesetVersion.v2024),
      name: 'Shield',
      itemType: 'Shield',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: '+2 Shield AC.',
      customProperties: const {'isShield': true, 'acBonus': 2},
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'longsword', ruleset: RulesetVersion.v2024),
      name: 'Longsword',
      itemType: 'Martial Melee Weapon',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Versatile 1d8 slashing (1d10 two-handed).',
      customProperties: const {
        'isWeapon': true,
        'damageFormula': '1d8',
        'damageType': 'slashing'
      },
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'greatsword', ruleset: RulesetVersion.v2024),
      name: 'Greatsword',
      itemType: 'Martial Melee Weapon',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy, two-handed 2d6 slashing.',
      customProperties: const {
        'isWeapon': true,
        'damageFormula': '2d6',
        'damageType': 'slashing'
      },
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'shortsword', ruleset: RulesetVersion.v2024),
      name: 'Shortsword',
      itemType: 'Martial Melee Weapon',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Finesse, Light 1d6 piercing.',
      customProperties: const {
        'isWeapon': true,
        'isFinesse': true,
        'damageFormula': '1d6',
        'damageType': 'piercing'
      },
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'longbow', ruleset: RulesetVersion.v2024),
      name: 'Longbow',
      itemType: 'Martial Ranged Weapon',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heavy, two-handed ranged weapon 1d8 piercing.',
      customProperties: const {
        'isWeapon': true,
        'isRanged': true,
        'damageFormula': '1d8',
        'damageType': 'piercing',
        'range': '150/600 ft',
      },
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'ring-of-protection', ruleset: RulesetVersion.v2024),
      name: 'Ring of Protection',
      itemType: 'Ring',
      rarity: 'Rare',
      requiresAttunement: true,
      descriptionMarkdown: '+1 AC and Saving Throws when attuned.',
      customProperties: const {'acBonus': 1},
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'gauntlets-of-ogre-power', ruleset: RulesetVersion.v2024),
      name: 'Gauntlets of Ogre Power',
      itemType: 'Wondrous Item',
      rarity: 'Uncommon',
      requiresAttunement: true,
      descriptionMarkdown: 'Sets wearer Strength to 19.',
      customProperties: const {
        'abilityOverrides': {'strength': 19}
      },
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(slug: 'potion-of-healing', ruleset: RulesetVersion.v2024),
      name: 'Potion of Healing',
      itemType: 'Potion',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heals 2d4 + 2 HP.',
      customProperties: const {},
    ));

    // Register all SRD Feats, Classes, Species, Backgrounds
    for (final feat in SrdFeatsLibrary.allFeats) {
      baseLayer.registerEntity(feat);
    }
    for (final cls in SrdClassesLibrary.allClasses) {
      baseLayer.registerEntity(cls);
    }
    for (final sp in SrdSpeciesLibrary.allSpecies) {
      baseLayer.registerEntity(sp);
    }
    for (final bg in SrdBackgroundsLibrary.allBackgrounds) {
      baseLayer.registerEntity(bg);
    }
    for (final eq in SrdEquipmentLibrary.allEquipmentItems) {
      baseLayer.registerEntity(eq);
    }

    _repository.addLayer(baseLayer);
  }

  void _initDefaultCharacter() {
    _characterRoster = [];
    _character = null;
    _isSelectorView = true;
    _loadPersistedRoster();
  }

  Future<void> _loadPersistedRoster() async {
    await HomebrewPersistenceService().syncToLibraries();
    final loaded = await _persistenceService.loadCharacters();
    final activeId = await _persistenceService.loadActiveCharacterId();
    if (mounted) {
      setState(() {
        _characterRoster = loaded;
        if (_characterRoster.isNotEmpty) {
          if (activeId != null) {
            final matched = _characterRoster.cast<Character?>().firstWhere(
                  (c) => c?.id.slug == activeId,
                  orElse: () => null,
                );
            _character = matched ?? _characterRoster.first;
          } else {
            _character = _characterRoster.first;
          }
          _recalculateStats();
        } else {
          _character = null;
          _isSelectorView = true;
        }
        _syncTabController();
      });
    }
  }

  void _selectCharacter(Character char) {
    HapticService.selectionTick(context);
    setState(() {
      _character = char;
      _rulesEdition = char.ruleset == RulesetVersion.v2024
          ? DmRulesEdition.v2024
          : DmRulesEdition.v2014;
      _isSelectorView = false;
      _recalculateStats();
      _syncTabController();
    });
    _persistenceService.saveActiveCharacterId(char.id.slug);
  }

  void _confirmDeleteCharacter(Character char) {
    HapticService.selectionTick(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Delete ${char.name}?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete ${char.name}? This character will be permanently removed from your roster.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteCharacter(char);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCharacter(Character char) async {
    HapticService.heavyImpact(context);
    final updated = await _persistenceService.deleteCharacter(char.id.slug);
    setState(() {
      _characterRoster = updated;
      if (_character?.id.slug == char.id.slug) {
        if (_characterRoster.isNotEmpty) {
          _character = _characterRoster.first;
          _recalculateStats();
        } else {
          _character = null;
        }
        _isSelectorView = true;
      }
      _syncTabController();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          content: Text('${char.name} deleted from roster.'),
        ),
      );
    }
  }

  void _recalculateStats() {
    final char = _character;
    if (char != null) {
      _syncSheetController();
    }
  }

  void _syncSheetController() {
    final char = _character;
    if (char != null) {
      if (_sheetController == null) {
        _sheetController = CharacterSheetController(
          character: char,
          persistenceService: _persistenceService,
          resolver: _resolver,
        );
        _sheetController!.addListener(_onSheetControllerUpdated);
      } else if (_sheetController!.character.id != char.id || _sheetController!.character != char) {
        _sheetController!.setCharacter(char);
      }
    } else {
      _sheetController?.removeListener(_onSheetControllerUpdated);
      _sheetController?.dispose();
      _sheetController = null;
    }
  }

  void _onSheetControllerUpdated() {
    if (_sheetController != null && mounted) {
      setState(() {
        _character = _sheetController!.character;
      });
    }
  }

  void _onRulesEditionChanged(DmRulesEdition newEdition) {
    HapticService.selectionTick(context);
    setState(() {
      _localEditionOverride = newEdition;
      _rulesEdition = newEdition;
      _selectedRuleset = newEdition == DmRulesEdition.v2024
          ? RulesetVersion.v2024
          : RulesetVersion.v2014;
      final char = _character;
      if (char != null) {
        _character = char.copyWith(
          id: EntityId(slug: char.id.slug, ruleset: _selectedRuleset),
        );
        _recalculateStats();
      }
    });
    SettingsScope.maybeOf(context)?.setRulesEdition(newEdition);
  }

  @override
  void dispose() {
    _sheetController?.removeListener(_onSheetControllerUpdated);
    _sheetController?.dispose();
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = SettingsScope.maybeOf(context);
    final activeEdition = _localEditionOverride ??
        settingsProvider?.settings.rulesEdition ??
        _rulesEdition;

    if (_localEditionOverride == null && activeEdition != _rulesEdition) {
      _rulesEdition = activeEdition;
      _selectedRuleset = activeEdition == DmRulesEdition.v2024
          ? RulesetVersion.v2024
          : RulesetVersion.v2014;
      final char = _character;
      if (char != null) {
        _character = char.copyWith(
          id: EntityId(slug: char.id.slug, ruleset: _selectedRuleset),
        );
        _syncSheetController();
      }
    }

    _syncTabController();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person_pin, color: Colors.cyanAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isSelectorView || _character == null ? 'Character Studio' : _character!.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          RulesEditionToggle(
            currentEdition: _rulesEdition,
            onEditionChanged: _onRulesEditionChanged,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          key: ValueKey('studio_tab_bar_$_hasActiveCharacter'),
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white70,
          tabs: _hasActiveCharacter
              ? const [
                  Tab(icon: Icon(Icons.badge_outlined), text: 'Live Sheet'),
                  Tab(icon: Icon(Icons.auto_awesome), text: 'Guided Builder'),
                  Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory & Loot'),
                  Tab(icon: Icon(Icons.upgrade), text: 'Level Up'),
                ]
              : const [
                  Tab(icon: Icon(Icons.badge_outlined), text: 'Live Sheet'),
                  Tab(icon: Icon(Icons.auto_awesome), text: 'Guided Builder'),
                ],
        ),
      ),
      body: Column(
        children: [
          RoomBannerWidget(),
          Expanded(
            child: TabBarView(
              key: ValueKey('studio_tab_bar_view_$_hasActiveCharacter'),
              controller: _tabController,
              children: [
                _buildLiveSheetTab(theme),
                _buildGuidedBuilderTab(theme),
                if (_hasActiveCharacter) ...[
                  _buildInventoryTab(theme),
                  _buildLevelUpTab(theme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static DndClassType? _findClassType(String slug) {
    final s = slug.toLowerCase();
    for (final c in DndClassType.values) {
      if (c.name.toLowerCase() == s || c.displayName.toLowerCase() == s) return c;
    }
    return null;
  }

  static SpeciesType _findSpeciesType(String slug) {
    final s = slug.toLowerCase();
    if (s.contains('human')) return SpeciesType.human;
    for (final sp in SpeciesType.values) {
      if (sp.name.toLowerCase() == s || sp.displayName.toLowerCase() == s || s.contains(sp.name.toLowerCase())) return sp;
    }
    return SpeciesType.human;
  }

  // --------------------------------------------------------------------------
  // TAB 1: LIVE SHEET & REACTIVE STATS
  // --------------------------------------------------------------------------
  Widget _buildLiveSheetTab(ThemeData theme) {
    if (_isSelectorView || _characterRoster.isEmpty) {
      return _buildCharacterSelectorView(theme);
    }
    return _buildActiveLiveSheetView(theme);
  }

  Widget _buildMiniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCharacterSelectorView(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final filteredRoster = _characterRoster.where((c) {
      if (_rosterRulesetFilter != null && c.ruleset != _rosterRulesetFilter) {
        return false;
      }
      if (_rosterSearchQuery.isEmpty) return true;
      final q = _rosterSearchQuery.toLowerCase();
      final nameMatches = c.name.toLowerCase().contains(q);
      final classMatches = c.progression.classes
          .any((cls) => cls.classRef.displayName.toLowerCase().contains(q));
      final speciesMatches = c.speciesRef.displayName.toLowerCase().contains(q);
      final bgMatches =
          c.backgroundRef?.displayName.toLowerCase().contains(q) ?? false;
      return nameMatches || classMatches || speciesMatches || bgMatches;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Roster Banner / Hero Card
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups_outlined,
                      color: Colors.cyanAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '5e Character Roster',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Select an adventurer to inspect their live sheet, or manage your party members.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.shade700,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('New Hero',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    _tabController.animateTo(1);
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Search Bar
        TextField(
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search heroes by name, class, species...',
            hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 12),
            prefixIcon: Icon(Icons.search, color: primary, size: 18),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF1E293B)
                : theme.colorScheme.surfaceContainerHighest,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (val) => setState(() => _rosterSearchQuery = val.trim()),
        ),

        const SizedBox(height: 8),

        // Ruleset Filter Chips
        Row(
          children: [
            FilterChip(
              label:
                  const Text('All Rulesets', style: TextStyle(fontSize: 11)),
              selected: _rosterRulesetFilter == null,
              onSelected: (_) => setState(() => _rosterRulesetFilter = null),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label:
                  const Text('2024 Revised', style: TextStyle(fontSize: 11)),
              selected: _rosterRulesetFilter == RulesetVersion.v2024,
              onSelected: (_) =>
                  setState(() => _rosterRulesetFilter = RulesetVersion.v2024),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label:
                  const Text('2014 Classic', style: TextStyle(fontSize: 11)),
              selected: _rosterRulesetFilter == RulesetVersion.v2014,
              onSelected: (_) =>
                  setState(() => _rosterRulesetFilter = RulesetVersion.v2014),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (filteredRoster.isEmpty)
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.person_off_outlined,
                        color: Colors.white38, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _characterRoster.isEmpty
                          ? 'No characters in roster yet.'
                          : 'No characters found matching your filter.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Create New Character'),
                      onPressed: () {
                        HapticService.selectionTick(context);
                        _tabController.animateTo(1);
                      },
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...filteredRoster.map((hero) {
            final curCls = hero.progression.classes.firstOrNull;
            final clsType = curCls != null
                ? _findClassType(curCls.classRef.slug)
                : DndClassType.fighter;
            final isCurrentActive = _character?.id.slug == hero.id.slug;
            final heroStats =
                CharacterStatCalculator.compute(hero, _resolver);

            return Card(
              key: ValueKey('character_card_${hero.id.slug}'),
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isCurrentActive ? Colors.cyanAccent : Colors.white12,
                  width: isCurrentActive ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        RepaintBoundary(
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: DndGlyph.classFeature(
                                classType: clsType ?? DndClassType.fighter,
                                size: 44,
                                isDarkMode: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      hero.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: hero.ruleset ==
                                              RulesetVersion.v2024
                                          ? Colors.cyan.shade900
                                              .withValues(alpha: 0.6)
                                          : Colors.amber.shade900
                                              .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      hero.ruleset == RulesetVersion.v2024
                                          ? '2024'
                                          : '2014',
                                      style: TextStyle(
                                        color: hero.ruleset ==
                                                RulesetVersion.v2024
                                            ? Colors.cyanAccent
                                            : Colors.amberAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Level ${hero.totalLevel} ${hero.progression.classes.map((c) => "${c.classRef.displayName} ${c.level}").join(" / ")} • ${hero.speciesRef.displayName} • ${hero.backgroundRef?.displayName ?? "Adventurer"}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: ValueKey('delete_character_${hero.id.slug}'),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          tooltip: 'Delete Character',
                          onPressed: () => _confirmDeleteCharacter(hero),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: Colors.white12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildMiniPill(
                                'AC ${heroStats.armorClass}', Colors.amberAccent),
                            _buildMiniPill(
                                'HP ${hero.resources.currentHp}/${heroStats.maxHp}',
                                Colors.redAccent),
                            _buildMiniPill(
                                'Prof +${heroStats.proficiencyBonus}',
                                Colors.cyanAccent),
                            _buildMiniPill(
                                'Speed ${hero.baseSpeedFeet}ft',
                                Colors.greenAccent),
                          ],
                        ),
                        ElevatedButton.icon(
                          key: ValueKey('open_sheet_${hero.id.slug}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent.shade700,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.badge_outlined, size: 14),
                          label: const Text('Open Sheet',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _selectCharacter(hero),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildActiveLiveSheetView(ThemeData theme) {
    final char = _character;
    if (char == null) {
      return _buildCharacterSelectorView(theme);
    }

    _syncSheetController();
    final controller = _sheetController;
    if (controller == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          CharacterHeaderBanner(
                            controller: controller,
                            onSwitchHero: () {
                              setState(() {
                                _isSelectorView = true;
                                _syncTabController();
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          CharacterVitalsHud(controller: controller),
                          const SizedBox(height: 14),
                          AbilityScoresRibbon(controller: controller),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: CharacterSheetTabs(controller: controller),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  CharacterHeaderBanner(
                    controller: controller,
                    onSwitchHero: () {
                      setState(() {
                        _isSelectorView = true;
                        _syncTabController();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  CharacterVitalsHud(controller: controller),
                  const SizedBox(height: 12),
                  AbilityScoresRibbon(controller: controller),
                  const SizedBox(height: 14),
                  CharacterSheetTabs(controller: controller),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }



  bool _isSpellcasterClass(String classSlug, RulesetVersion ruleset) {
    final slug = classSlug.toLowerCase();
    if (slug == 'wizard' ||
        slug == 'cleric' ||
        slug == 'druid' ||
        slug == 'bard' ||
        slug == 'sorcerer' ||
        slug == 'warlock' ||
        slug == 'artificer') {
      return true;
    }
    if (ruleset == RulesetVersion.v2024 && slug == 'ranger') {
      return true;
    }
    return false;
  }

  SpellClass? _findSpellClass(String slug) {
    return switch (slug.toLowerCase()) {
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

  AbilityType _getCastingAbility(String slug) {
    return switch (slug.toLowerCase()) {
      'wizard' || 'artificer' => AbilityType.intelligence,
      'cleric' || 'druid' || 'ranger' => AbilityType.wisdom,
      _ => AbilityType.charisma,
    };
  }

  List<String> _getWizardStepTypes() {
    final curSpecies = SrdSpeciesLibrary.findBySlug(_selectedSpecies) ?? SrdSpeciesLibrary.human;
    final is2024 = _selectedRuleset == RulesetVersion.v2024;
    final hasFeatStep = is2024 || curSpecies.grantsBonusFeat;
    final curClass = SrdClassesLibrary.findBySlug(_selectedClass, ruleset: _selectedRuleset) ?? SrdClassesLibrary.fighter;
    final isCaster = _isSpellcasterClass(_selectedClass, _selectedRuleset);
    final hasSubclass = curClass.getSubclassLevel(_selectedRuleset) == 1 && curClass.subclasses.isNotEmpty;
    final lvl1Decisions = curClass.getDecisionsForLevel(1, ruleset: _selectedRuleset);
    final hasDecisions = lvl1Decisions.isNotEmpty;

    final preset = SettingsScope.settingsOf(context, listen: false).wizardOrderingPreset;

    final steps = <String>['basics'];

    void addClassBlocks() {
      steps.add('class');
      if (hasSubclass) steps.add('subclass');
      if (hasDecisions) steps.add('class_decisions');
    }

    switch (preset) {
      case WizardOrderingPreset.modern2024:
        addClassBlocks();
        steps.add('background');
        steps.add('species');
        steps.add('scores');
      case WizardOrderingPreset.attributesFirst:
        steps.add('scores');
        addClassBlocks();
        steps.add('species');
        steps.add('background');
      case WizardOrderingPreset.classic2014:
        steps.add('species');
        addClassBlocks();
        steps.add('background');
        steps.add('scores');
    }

    if (hasFeatStep) steps.add('feats');
    if (isCaster) steps.add('spells');
    steps.add('equipment');
    steps.add('review');
    return steps;
  }

  // --------------------------------------------------------------------------
  // TAB 2: GUIDED CHARACTER CREATION WIZARD (STEP-BY-STEP)
  // --------------------------------------------------------------------------
  Widget _buildGuidedBuilderTab(ThemeData theme) {
    final curSpecies = SrdSpeciesLibrary.findBySlug(_selectedSpecies) ?? SrdSpeciesLibrary.human;
    final steps = _getWizardStepTypes();
    final maxStepIndex = steps.length - 1;
    if (_wizardStep > maxStepIndex) _wizardStep = maxStepIndex;

    final curClass = SrdClassesLibrary.findBySlug(_selectedClass, ruleset: _selectedRuleset) ?? SrdClassesLibrary.fighter;
    final curBackground = SrdBackgroundsLibrary.findBySlug(_selectedBackground) ?? SrdBackgroundsLibrary.soldier;
    final allowedClassSkills = (curClass.customProperties['allowedSkills'] as List? ?? [])
        .map((s) => SkillType.values.firstWhere((st) => st.name == s.toString(), orElse: () => SkillType.athletics))
        .toList();
    final allowedSkillCount = (curClass.customProperties['skillChoiceCount'] as num?)?.toInt() ?? 2;
    final lvl1Decisions = curClass.getDecisionsForLevel(1, ruleset: _selectedRuleset);

    final currentStepKey = steps[_wizardStep];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stepper Progress Header
        Row(
          children: List.generate(steps.length, (i) {
            final isDone = i < _wizardStep;
            final isCur = i == _wizardStep;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 6,
                decoration: BoxDecoration(
                  color: isCur ? Colors.cyanAccent : (isDone ? Colors.cyan.shade800 : Colors.white12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),

        // Step Content Card
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: () {
              return switch (currentStepKey) {
                'basics' => _buildStep0Basics(theme),
                'species' => _buildStep1Species(theme),
                'class' => _buildStep2Class(theme, curClass, allowedClassSkills, allowedSkillCount),
                'subclass' => _buildStepSubclass(theme, curClass),
                'class_decisions' => _buildStepClassDecisions(theme, curClass, lvl1Decisions),
                'background' => _buildStep3Background(theme, curBackground),
                'scores' => _buildStep4AbilityScores(theme),
                'feats' => _buildStep5Feats(theme),
                'spells' => _buildStepSpells(theme, curClass),
                'equipment' => _buildStep6Equipment(theme),
                _ => _buildStep7Review(theme, curSpecies, curClass, curBackground),
              };
            }(),
          ),
        ),

        const SizedBox(height: 16),

        // Navigation Actions
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
                  backgroundColor: Colors.cyanAccent.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticService.selectionTick(context);
                  if (_wizardStep == 0 && _nameController.text.trim().isEmpty) {
                    _nameController.text = _suggestedNames[math.Random().nextInt(_suggestedNames.length)];
                  }
                  setState(() => _wizardStep++);
                },
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.check_circle),
                label: const Text('CREATE & LAUNCH SHEET', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticService.heavyImpact(context);
                  _finalizeCreatedCharacter();
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep0Basics(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 1: Character Identity & Edition',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text('Enter your character\'s name and pick the 5e rules standard.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Character Name',
                  hintText: 'e.g. Valeros Ironclad',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.casino),
              tooltip: 'Random Name Suggestion',
              onPressed: () {
                HapticService.selectionTick(context);
                setState(() {
                  _nameController.text = _suggestedNames[math.Random().nextInt(_suggestedNames.length)];
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Ruleset Standard:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<RulesetVersion>(
          segments: const [
            ButtonSegment(
              value: RulesetVersion.v2024,
              label: Text('2024 SRD (5.2 Revised)'),
              icon: Icon(Icons.auto_awesome),
            ),
            ButtonSegment(
              value: RulesetVersion.v2014,
              label: Text('2014 SRD (5.1 Classic)'),
              icon: Icon(Icons.history_edu),
            ),
          ],
          selected: {_selectedRuleset},
          onSelectionChanged: (set) {
            final targetRuleset = set.first;
            final targetEdition = targetRuleset == RulesetVersion.v2024
                ? DmRulesEdition.v2024
                : DmRulesEdition.v2014;
            _onRulesEditionChanged(targetEdition);
          },
        ),
      ],
    );
  }

  Widget _buildStep1Species(ThemeData theme) {
    final speciesList = SrdSpeciesLibrary.getSpeciesForRuleset(_selectedRuleset);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 2: Choose Species / Race',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text('Select your character lineage from standard SRD species.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),
        ...speciesList.map((sp) {
          final isSelected = _selectedSpecies == sp.id.slug;
          final spType = _findSpeciesType(sp.id.slug);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyan.shade900.withValues(alpha: 0.3) : Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.cyanAccent : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    RepaintBoundary(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: DndGlyph.species(
                            speciesType: spType,
                            size: 32,
                            isDarkMode: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(sp.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Speed: ${sp.getSpeedForEdition(_rulesEdition)} • Size: ${sp.size}\n${sp.abilityScoreSummary ?? ""}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                onTap: () {
                  HapticService.selectionTick(context);
                  setState(() {
                    _selectedSpecies = sp.id.slug;
                    final is2024 = _selectedRuleset == RulesetVersion.v2024;
                    final hasFeatStep = is2024 || sp.grantsBonusFeat;
                    final maxStepIndex = hasFeatStep ? 7 : 6;
                    if (_wizardStep > maxStepIndex) _wizardStep = maxStepIndex;
                  });
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep2Class(ThemeData theme, CharacterClass curClass, List<SkillType> allowedSkills, int allowedCount) {
    final curClassType = _findClassType(_selectedClass) ?? DndClassType.fighter;
    final edition = _selectedRuleset == RulesetVersion.v2024 ? DmRulesEdition.v2024 : DmRulesEdition.v2014;

    // Resolve skills through the rules engine to detect collisions and compensatory picks
    final skillReport = SkillTraitResolver.resolveSkills(
      speciesSlug: _selectedSpecies,
      backgroundSlug: _selectedBackground,
      classSlug: curClass.id.slug,
      requestedClassSkills: _wizardSelectedSkills,
      compensatoryPicks: _compensatorySkillPicks,
      edition: edition,
    );

    final speciesBonusSkillCount = SkillTraitResolver.getSpeciesBonusSkillCount(_selectedSpecies, edition);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 3: Choose Class & Starting Skills',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text('Select your core adventurer class and starting skill proficiencies.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.cyan.shade900.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              RepaintBoundary(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: DndGlyph.classFeature(
                      classType: curClassType,
                      size: 48,
                      isDarkMode: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curClassType.displayName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'd${curClassType.hitDieSides} Hit Die • Resource: ${curClassType.primaryResource}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _selectedClass,
          decoration: const InputDecoration(labelText: 'Starting Class', border: OutlineInputBorder()),
          items: SrdClassesLibrary.allClasses
              .map((c) => DropdownMenuItem(value: c.id.slug, child: Text('${c.name} (${c.hitDie} • Primary: ${c.primaryAbility})')))
              .toList(),
          onChanged: (v) {
            HapticService.selectionTick(context);
            setState(() {
              _selectedClass = v!;
              final newCls = SrdClassesLibrary.findBySlug(v)!;
              final newAllowed = (newCls.customProperties['allowedSkills'] as List? ?? [])
                  .map((s) => SkillType.values.firstWhere((st) => st.name == s.toString(), orElse: () => SkillType.athletics))
                  .toList();
              final cnt = (newCls.customProperties['skillChoiceCount'] as num?)?.toInt() ?? 2;
              _wizardSelectedSkills = newAllowed.take(cnt).toSet();
              _compensatorySkillPicks.clear();
            });
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Class Skills (Pick $allowedCount):', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${_wizardSelectedSkills.length} / $allowedCount selected',
                style: TextStyle(
                  fontSize: 12,
                  color: _wizardSelectedSkills.length == allowedCount ? Colors.greenAccent : Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                )),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: allowedSkills.map((sk) {
            final isChosen = _wizardSelectedSkills.contains(sk);
            final source = skillReport.grantedSkills[sk];
            final isGrantedByOther = source != null && !source.startsWith('Class:');

            return FilterChip(
              label: Text(isGrantedByOther ? '${sk.displayName} ($source)' : sk.displayName),
              selected: isChosen,
              avatar: isGrantedByOther
                  ? const Icon(Icons.info_outline, size: 14, color: Colors.amberAccent)
                  : null,
              onSelected: (selected) {
                HapticService.selectionTick(context);
                setState(() {
                  if (selected) {
                    if (_wizardSelectedSkills.length < allowedCount) {
                      _wizardSelectedSkills.add(sk);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Cannot select more than $allowedCount class skills for ${curClass.name}.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    _wizardSelectedSkills.remove(sk);
                  }
                });
              },
            );
          }).toList(),
        ),

        // Collision & Compensatory Picks Section
        if (skillReport.collidingSkills.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Skill Collision Detected: ${skillReport.collidingSkills.map((s) => s.displayName).join(", ")} is already granted by your background/species.',
                        style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Per RAW rules, you receive ${skillReport.compensatoryPicksEarned} compensatory choice(s) from any remaining unselected skill.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Compensatory Pick(s):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(
                      '${_compensatorySkillPicks.length} / ${skillReport.compensatoryPicksEarned} selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: _compensatorySkillPicks.length == skillReport.compensatoryPicksEarned ? Colors.greenAccent : Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: SkillType.values.where((sk) {
                    return skillReport.availableSkillPool.contains(sk) || _compensatorySkillPicks.contains(sk);
                  }).map((sk) {
                    final isChosen = _compensatorySkillPicks.contains(sk);
                    return FilterChip(
                      label: Text(sk.displayName, style: const TextStyle(fontSize: 12)),
                      selected: isChosen,
                      selectedColor: Colors.amberAccent.withValues(alpha: 0.3),
                      onSelected: (selected) {
                        HapticService.selectionTick(context);
                        setState(() {
                          if (selected) {
                            if (_compensatorySkillPicks.length < skillReport.compensatoryPicksEarned) {
                              _compensatorySkillPicks.add(sk);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot select more than ${skillReport.compensatoryPicksEarned} compensatory skill(s).'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            _compensatorySkillPicks.remove(sk);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        // Species Flexible Bonus Skills (e.g. Human Skillful, Half-Elf Skill Versatility)
        if (speciesBonusSkillCount > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Species Bonus Skill (${SrdSpeciesLibrary.findBySlug(_selectedSpecies)?.name ?? "Species"}):',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.tealAccent)),
                    Text(
                      '${_speciesBonusSkillPicks.length} / $speciesBonusSkillCount selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: _speciesBonusSkillPicks.length == speciesBonusSkillCount ? Colors.greenAccent : Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: SkillType.values.where((sk) {
                    return !skillReport.resolvedProficiencies.containsKey(sk) || _speciesBonusSkillPicks.contains(sk);
                  }).map((sk) {
                    final isChosen = _speciesBonusSkillPicks.contains(sk);
                    return FilterChip(
                      label: Text(sk.displayName, style: const TextStyle(fontSize: 12)),
                      selected: isChosen,
                      selectedColor: Colors.tealAccent.withValues(alpha: 0.3),
                      onSelected: (selected) {
                        HapticService.selectionTick(context);
                        setState(() {
                          if (selected) {
                            if (_speciesBonusSkillPicks.length < speciesBonusSkillCount) {
                              _speciesBonusSkillPicks.add(sk);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot select more than $speciesBonusSkillCount species bonus skill(s).'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            _speciesBonusSkillPicks.remove(sk);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepSubclass(ThemeData theme, CharacterClass curClass) {
    if (curClass.subclasses.isEmpty) {
      return const Text('No subclasses available for this class.');
    }
    _wizardSelectedSubclass ??= curClass.subclasses.first.id.slug;
    final selectedSlug = _wizardSelectedSubclass!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose ${curClass.name} Subclass / Archetype',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          'Under the selected ruleset (${_selectedRuleset == RulesetVersion.v2024 ? '2024' : '2014'}), ${curClass.name} chooses an archetype at 1st level.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 14),
        ...curClass.subclasses.map((sub) {
          final isSelected = sub.id.slug == selectedSlug;
          return Card(
            color: isSelected ? Colors.cyan.shade900.withValues(alpha: 0.4) : const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                HapticService.selectionTick(context);
                setState(() => _wizardSelectedSubclass = sub.id.slug);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isSelected ? Colors.cyanAccent : Colors.white54,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sub.name,
                            style: TextStyle(
                              color: isSelected ? Colors.cyanAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (sub.featuresMarkdown.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FormattedMarkdownText(
                        sub.featuresMarkdown,
                        defaultColor: Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepClassDecisions(ThemeData theme, CharacterClass curClass, List<ClassFeatureDecision> decisions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${curClass.name} Decisions & Specializations',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          'Customize your ${curClass.name} feature options at 1st level.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 14),
        ...decisions.map((decision) {
          final selected = _wizardSelectedFeatureOptions[decision.id] ??= [
            if (decision.availableOptions.isNotEmpty) decision.availableOptions.first.id,
          ];

          return Card(
            color: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Colors.white24),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(decision.prompt, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  ...decision.availableOptions.map((opt) {
                    final isOptSelected = selected.contains(opt.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isOptSelected ? Colors.cyan.shade900.withValues(alpha: 0.3) : Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isOptSelected ? Colors.cyanAccent.withValues(alpha: 0.7) : Colors.white12,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          HapticService.selectionTick(context);
                          setState(() {
                            if (decision.maxSelections == 1) {
                              _wizardSelectedFeatureOptions[decision.id] = [opt.id];
                            } else {
                              final list = List<String>.from(_wizardSelectedFeatureOptions[decision.id] ?? []);
                              if (list.contains(opt.id)) {
                                if (list.length > decision.minSelections) {
                                  list.remove(opt.id);
                                }
                              } else {
                                if (list.length < decision.maxSelections) {
                                  list.add(opt.id);
                                }
                              }
                              _wizardSelectedFeatureOptions[decision.id] = list;
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    decision.maxSelections == 1
                                        ? (isOptSelected ? Icons.radio_button_checked : Icons.radio_button_off)
                                        : (isOptSelected ? Icons.check_box : Icons.check_box_outline_blank),
                                    color: isOptSelected ? Colors.cyanAccent : Colors.white38,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    opt.name,
                                    style: TextStyle(
                                      color: isOptSelected ? Colors.cyanAccent : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (opt.descriptionMarkdown.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 26),
                                  child: FormattedMarkdownText(
                                    opt.descriptionMarkdown,
                                    defaultColor: Colors.white70,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep3Background(ThemeData theme, Background curBackground) {
    final is2024 = _selectedRuleset == RulesetVersion.v2024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(is2024 ? 'Step 4: Choose Background Origin' : 'Step 4: Choose Background',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        Text(
          is2024
              ? 'Your background grants starting skills, tool proficiencies, and an Origin Feat.'
              : 'Your background grants starting skills, tool proficiencies, and starting equipment.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ...SrdBackgroundsLibrary.allBackgrounds.map((bg) {
          final isSelected = _selectedBackground == bg.id.slug;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyan.shade900.withValues(alpha: 0.3) : Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.cyanAccent : Colors.white12,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.cyanAccent : Colors.white54,
                ),
                title: Text(bg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  is2024
                      ? 'Skills: ${bg.skillProficiencies.join(", ")}\nOrigin Feat: ${bg.originFeat ?? "General"}'
                      : 'Skills: ${bg.skillProficiencies.join(", ")}${bg.toolProficiencies.isNotEmpty ? "\nTools: ${bg.toolProficiencies.join(', ')}" : ""}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
                onTap: () {
                  HapticService.selectionTick(context);
                  setState(() {
                    _selectedBackground = bg.id.slug;
                    // Auto-set origin feat recommendation in 2024 mode
                    if (is2024 && bg.originFeat != null) {
                      final fSlug = bg.originFeat!.toLowerCase().replaceAll(' ', '-').replaceAll('(', '').replaceAll(')', '');
                      if (SrdFeatsLibrary.findBySlug(fSlug) != null) {
                        _selectedFeat = fSlug;
                      }
                    }
                  });
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep4AbilityScores(ThemeData theme) {
    final pointBuyCost = CharacterFactory.calculatePointBuyCost(_wizardBaseScores);
    final pointsRemaining = 27 - pointBuyCost;
    final curSpecies = SrdSpeciesLibrary.findBySlug(_selectedSpecies) ?? SrdSpeciesLibrary.human;
    final curBackground = SrdBackgroundsLibrary.findBySlug(_selectedBackground) ?? SrdBackgroundsLibrary.soldier;
    final bonusScores = _calculateBonusScores(curSpecies, curBackground, _selectedRuleset);
    final is2014 = _selectedRuleset == RulesetVersion.v2014;
    final flexibleCount = curSpecies.flexibleAbilityChoiceCount;
    final flexibleBonusValue = curSpecies.flexibleAbilityBonusValue;
    final hasFlexibleLineageBonus = is2014 && flexibleCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 5: Ability Score Allocation',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text(
          'Choose your attribute generation method (Standard Array, Point Buy, Dice Roll, or Manual Entry) and assign your lineage bonuses.',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 12),

        // Method Selector
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'standard', label: Text('Standard Array', style: TextStyle(fontSize: 10.5))),
            ButtonSegment(value: 'pointBuy', label: Text('Point Buy', style: TextStyle(fontSize: 10.5))),
            ButtonSegment(value: 'rolled', label: Text('Dice Roll', style: TextStyle(fontSize: 10.5))),
            ButtonSegment(value: 'manual', label: Text('Enter Own', style: TextStyle(fontSize: 10.5))),
          ],
          selected: {_abilityScoreMode},
          onSelectionChanged: (set) {
            HapticService.selectionTick(context);
            setState(() {
              _abilityScoreMode = set.first;
              if (_abilityScoreMode == 'manual') {
                _syncManualToWizardScores();
              } else if (_abilityScoreMode == 'rolled') {
                if (_rolledPool.isEmpty) {
                  _rollAbilityScores();
                } else {
                  _syncRolledToWizardScores();
                }
              } else if (_abilityScoreMode == 'standard') {
                _wizardBaseScores = AbilityScores(
                  strength: _standardArrayPicks[AbilityType.strength]!,
                  dexterity: _standardArrayPicks[AbilityType.dexterity]!,
                  constitution: _standardArrayPicks[AbilityType.constitution]!,
                  intelligence: _standardArrayPicks[AbilityType.intelligence]!,
                  wisdom: _standardArrayPicks[AbilityType.wisdom]!,
                  charisma: _standardArrayPicks[AbilityType.charisma]!,
                );
              }
            });
          },
        ),
        const SizedBox(height: 16),

        // METHOD 1: POINT BUY
        if (_abilityScoreMode == 'pointBuy') ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: pointsRemaining >= 0 ? Colors.green.shade900.withValues(alpha: 0.25) : Colors.red.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pointsRemaining >= 0 ? Colors.greenAccent : Colors.redAccent, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Point Buy Pool (Cost: 8=0, 9=1, ..., 15=9):', style: TextStyle(fontSize: 12, color: Colors.white70)),
                Text(
                  'Points Remaining: $pointsRemaining / 27',
                  style: TextStyle(color: pointsRemaining >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...AbilityType.values.map((ab) {
            final score = _wizardBaseScores.getScore(ab);
            final mod = score.dndModifier;
            final modStr = mod >= 0 ? '+$mod' : '$mod';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: score > 8
                            ? () {
                                HapticService.selectionTick(context);
                                setState(() => _wizardBaseScores = _adjustScore(_wizardBaseScores, ab, -1));
                              }
                            : null,
                      ),
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: score < 15
                            ? () {
                                HapticService.selectionTick(context);
                                setState(() => _wizardBaseScores = _adjustScore(_wizardBaseScores, ab, 1));
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ]

        // METHOD 2: DICE ROLL
        else if (_abilityScoreMode == 'rolled') ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.casino, color: Colors.purpleAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Dice Rolling Method', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _rollMethod,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'standard_4d6', child: Text('Standard Roll (4d6 drop lowest)')),
                    DropdownMenuItem(value: 'classic_3d6_down', child: Text('Old School (3d6 down the line)')),
                    DropdownMenuItem(value: 'classic_3d6_nice', child: Text('Old School (Nice) (3d6, assignable)')),
                    DropdownMenuItem(value: 'silly_d20', child: Text('Silly, don\'t use this (1d20 per stat)')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    HapticService.selectionTick(context);
                    setState(() {
                      _rollMethod = v;
                      _rollAbilityScores();
                    });
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.casino_outlined, size: 16),
                  label: const Text('Roll / Re-roll Dice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade800,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    HapticService.heavyImpact(context);
                    _rollAbilityScores();
                  },
                ),
                if (_rolledBreakdowns.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _rolledBreakdowns
                          .map((b) => Text(b, style: const TextStyle(fontSize: 11, color: Colors.purpleAccent)))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_rollMethod == 'classic_3d6_down') ...[
            const Text(
              '3d6 Down the Line: scores assigned strictly in sequence (STR, DEX, CON, INT, WIS, CHA):',
              style: TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            ...AbilityType.values.map((ab) {
              final score = _wizardBaseScores.getScore(ab);
              final mod = score.dndModifier;
              final modStr = mod >= 0 ? '+$mod' : '$mod';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.purpleAccent, width: 0.8),
                      ),
                      child: Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            const Text(
              'Assign your rolled scores to each ability:',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            ...AbilityType.values.map((ab) {
              final score = _rolledAssignments[ab] ?? _rolledPool.first;
              final mod = score.dndModifier;
              final modStr = mod >= 0 ? '+$mod' : '$mod';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<int>(
                      value: score,
                      items: _rolledPool.toSet().map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        HapticService.selectionTick(context);
                        setState(() {
                          _rolledAssignments[ab] = v;
                          _syncRolledToWizardScores();
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ]

        // METHOD 3: ENTER YOUR OWN (MANUAL)
        else if (_abilityScoreMode == 'manual') ...[
          const Text(
            'Enter your own custom attributes (3 to 30):',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ...AbilityType.values.map((ab) {
            final score = _manualPicks[ab] ?? 10;
            final mod = score.dndModifier;
            final modStr = mod >= 0 ? '+$mod' : '$mod';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: score > 3
                            ? () {
                                HapticService.selectionTick(context);
                                setState(() {
                                  _manualPicks[ab] = score - 1;
                                  _syncManualToWizardScores();
                                });
                              }
                            : null,
                      ),
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: score < 30
                            ? () {
                                HapticService.selectionTick(context);
                                setState(() {
                                  _manualPicks[ab] = score + 1;
                                  _syncManualToWizardScores();
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ]

        // METHOD 4: STANDARD ARRAY
        else ...[
          const Text(
            'Assign the standard array values (15, 14, 13, 12, 10, 8) to your attributes:',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ...AbilityType.values.map((ab) {
            final score = _standardArrayPicks[ab] ?? 10;
            final mod = score.dndModifier;
            final modStr = mod >= 0 ? '+$mod' : '$mod';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<int>(
                    value: score,
                    items: const [15, 14, 13, 12, 10, 8]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) {
                      HapticService.selectionTick(context);
                      setState(() {
                        _standardArrayPicks[ab] = v!;
                        _wizardBaseScores = AbilityScores(
                          strength: _standardArrayPicks[AbilityType.strength]!,
                          dexterity: _standardArrayPicks[AbilityType.dexterity]!,
                          constitution: _standardArrayPicks[AbilityType.constitution]!,
                          intelligence: _standardArrayPicks[AbilityType.intelligence]!,
                          wisdom: _standardArrayPicks[AbilityType.wisdom]!,
                          charisma: _standardArrayPicks[AbilityType.charisma]!,
                        );
                      });
                    },
                  ),
                ],
              ),
            );
          }),
        ],

        const SizedBox(height: 16),

        // LINEAGE / BACKGROUND BONUS SECTION
        if (hasFlexibleLineageBonus) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.cyan.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.cyanAccent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${curSpecies.name} Lineage Bonus (+$flexibleBonusValue to $flexibleCount Score${flexibleCount > 1 ? 's' : ''})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select $flexibleCount different ability score${flexibleCount > 1 ? 's' : ''} to receive a +$flexibleBonusValue bonus:',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: AbilityType.values.map((ab) {
                    final isSelected = _variantHumanBonuses.contains(ab);
                    return FilterChip(
                      label: Text('${ab.name.toUpperCase()} (+$flexibleBonusValue Bonus)'),
                      selected: isSelected,
                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                      checkmarkColor: Colors.cyanAccent,
                      onSelected: (selected) {
                        HapticService.selectionTick(context);
                        setState(() {
                          if (selected) {
                            if (_variantHumanBonuses.length >= flexibleCount) {
                              _variantHumanBonuses.remove(_variantHumanBonuses.first);
                            }
                            _variantHumanBonuses.add(ab);
                          } else {
                            if (_variantHumanBonuses.length > 1) {
                              _variantHumanBonuses.remove(ab);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ] else if (!is2014) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Background Ability Score Bonus (+2 / +1)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '2024 rules grant a +2 bonus to your primary attribute and +1 to your secondary attribute:',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AbilityType>(
                        initialValue: _backgroundPrimaryBonus,
                        decoration: const InputDecoration(
                          labelText: '+2 Primary Bonus',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: AbilityType.values
                            .map((ab) => DropdownMenuItem(value: ab, child: Text('${ab.name.toUpperCase()} (+2)')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          HapticService.selectionTick(context);
                          setState(() {
                            _backgroundPrimaryBonus = v;
                            if (_backgroundSecondaryBonus == v) {
                              _backgroundSecondaryBonus = AbilityType.values.firstWhere((a) => a != v);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<AbilityType>(
                        initialValue: _backgroundSecondaryBonus,
                        decoration: const InputDecoration(
                          labelText: '+1 Secondary Bonus',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: AbilityType.values
                            .map((ab) => DropdownMenuItem(value: ab, child: Text('${ab.name.toUpperCase()} (+1)')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          HapticService.selectionTick(context);
                          setState(() {
                            _backgroundSecondaryBonus = v;
                            if (_backgroundPrimaryBonus == v) {
                              _backgroundPrimaryBonus = AbilityType.values.firstWhere((a) => a != v);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '2014 Species Racial Bonus: ${curSpecies.abilityScoreSummary}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // FINAL COMPUTED STATS PREVIEW TABLE
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FINAL STARTING ATTRIBUTES PREVIEW',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1, color: Colors.cyanAccent),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: AbilityType.values.map((ab) {
                    final base = _wizardBaseScores.getScore(ab);
                    final bonus = bonusScores.getScore(ab);
                    final total = base + bonus;
                    final mod = total.dndModifier;
                    final modStr = mod >= 0 ? '+$mod' : '$mod';
                    return Column(
                      children: [
                        Text(ab.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(modStr, style: const TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                        if (bonus > 0)
                          Text('+$bonus bonus', style: const TextStyle(fontSize: 8.5, color: Colors.amberAccent)),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Feats(ThemeData theme) {
    final curSpecies = SrdSpeciesLibrary.findBySlug(_selectedSpecies) ?? SrdSpeciesLibrary.human;
    final is2024 = _selectedRuleset == RulesetVersion.v2024;
    final availableFeats = is2024
        ? SrdFeatsLibrary.getOriginFeats()
        : SrdFeatsLibrary.getFeatsForRuleset(RulesetVersion.v2014);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          is2024
              ? 'Step 6: Origin Feat'
              : 'Step 6: ${curSpecies.name} Bonus Feat',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          is2024
              ? 'Choose your 1st-level origin feat granted by your 2024 background.'
              : 'As a ${curSpecies.name}, choose your 1st-level bonus feat from the 2014 SRD Feat Library.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ...availableFeats.map((feat) {
          final isSelected = _selectedFeat == feat.id.slug;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.purple.shade900.withValues(alpha: 0.3) : Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.purpleAccent : Colors.white12,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                title: Text(feat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: FormattedMarkdownText(
                  feat.descriptionMarkdown,
                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.purpleAccent) : null,
                onTap: () {
                  HapticService.selectionTick(context);
                  setState(() => _selectedFeat = feat.id.slug);
                },
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep6Equipment(ThemeData theme) {
    final curClass = SrdClassesLibrary.findBySlug(_selectedClass) ?? SrdClassesLibrary.fighter;
    final packages = SrdEquipmentLibrary.getPackagesForClass(curClass.id.slug);
    final stepNumber = _getWizardStepTypes().indexOf('equipment') + 1;

    if (!packages.any((p) => p.id == _selectedStartingEquipmentPreset)) {
      _selectedStartingEquipmentPreset = packages.first.id;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $stepNumber: Starting Equipment & Inventory (SRD)',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose an official 5e SRD starting inventory package or starting wealth for your ${curClass.name}.',
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ...packages.map((pkg) {
          return _buildEquipmentPresetOption(
            id: pkg.id,
            title: pkg.name,
            subtitle: pkg.subtitle,
            icon: pkg.icon,
            gold: pkg.startingGold,
          );
        }),
      ],
    );
  }

  Widget _buildEquipmentPresetOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    int? gold,
  }) {
    final isSelected = _selectedStartingEquipmentPreset == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.cyan.shade900.withValues(alpha: 0.3) : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.cyanAccent : Colors.white12,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.white70, size: 22),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.cyanAccent)
              : (gold != null && gold > 0
                  ? Chip(
                      label: Text('$gold GP', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                      backgroundColor: Colors.amber.shade900.withValues(alpha: 0.25),
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                      padding: EdgeInsets.zero,
                    )
                  : null),
          onTap: () {
            HapticService.selectionTick(context);
            setState(() => _selectedStartingEquipmentPreset = id);
          },
        ),
      ),
    );
  }

  Widget _buildStepSpells(ThemeData theme, CharacterClass curClass) {
    final edition = _selectedRuleset == RulesetVersion.v2024 ? DmRulesEdition.v2024 : DmRulesEdition.v2014;
    final spellClass = _findSpellClass(curClass.id.slug);

    final allClassSpells = SpellbookLibrary.allSpells.where((s) {
      if (s.level > 1) return false;
      if (spellClass == null) return s.level <= 1;
      final rules = s.getRules(edition);
      final isClassSpell = rules.classes.contains(spellClass);
      final isExpanded = SubclassSpellsLibrary.isExpandedSpell(curClass.id.slug, _wizardSelectedSubclass, s, edition);
      return isClassSpell || isExpanded;
    }).toList();

    final cantrips = allClassSpells.where((s) => s.level == 0).toList();
    final level1Spells = allClassSpells.where((s) => s.level == 1).toList();
    final stepNumber = _getWizardStepTypes().indexOf('spells') + 1;

    // Calculate dynamic spell limits based on class, level, ability score modifier, and edition
    final castingAbility = _getCastingAbility(curClass.id.slug);
    final curSpecies = SrdSpeciesLibrary.findBySlug(_selectedSpecies) ?? SrdSpeciesLibrary.human;
    final curBackground = SrdBackgroundsLibrary.findBySlug(_selectedBackground) ?? SrdBackgroundsLibrary.soldier;
    final calculatedBonuses = _calculateBonusScores(curSpecies, curBackground, _selectedRuleset);
    final effectiveScores = _wizardBaseScores.withBonus(calculatedBonuses);
    final castingMod = effectiveScores.getModifier(castingAbility);

    final limits = SpellAllocationValidator.getLimitsForClass(
      classSlug: curClass.id.slug,
      classLevel: 1,
      abilityModifier: castingMod,
      edition: edition,
    );

    final maxCantrips = limits.maxCantrips;
    final isWizard = curClass.id.slug.toLowerCase() == 'wizard';
    final maxSpells = (isWizard && limits.maxSpellbookInitialScribe > 0)
        ? limits.maxSpellbookInitialScribe // 6 for Wizard spellbook
        : (limits.maxSpellsPrepared > 0 ? limits.maxSpellsPrepared : limits.maxSpellsKnown);

    final spellsSectionTitle = isWizard
        ? 'SPELLBOOK (1ST-LEVEL SPELLS)'
        : (limits.maxSpellsPrepared > 0 ? 'PREPARED 1ST-LEVEL SPELLS' : '1ST-LEVEL SPELLS KNOWN');

    final spellsSubtitle = isWizard
        ? 'A Level 1 Wizard must choose exactly 6 1st-level spells to scribe into their spellbook.'
        : (limits.maxSpellsPrepared > 0
            ? 'Prepared limit: Level 1 + ${castingAbility.shortName} mod (${castingMod >= 0 ? "+$castingMod" : "$castingMod"}) = $maxSpells spells.'
            : 'Spells known limit: $maxSpells spells.');

    final alwaysPreparedSpells = SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: curClass.id.slug,
      subclassSlug: _wizardSelectedSubclass,
      classLevel: 1,
      edition: edition,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $stepNumber: Spells & Cantrips',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
        const SizedBox(height: 6),
        Text('Select starting cantrips and 1st-level spells for ${curClass.name} (${castingAbility.shortName} mod: ${castingMod >= 0 ? "+$castingMod" : "$castingMod"}).',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${s.getName(edition)} (L${s.level})', style: const TextStyle(fontSize: 11)),
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

        // Quick Auto-Fill Recommended Spells
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('Select Recommended Spells', style: TextStyle(fontSize: 12)),
            onPressed: () {
              HapticService.selectionTick(context);
              setState(() {
                _selectedWizardCantrips.clear();
                _selectedWizardSpells.clear();
                if (cantrips.isNotEmpty && maxCantrips > 0) {
                  _selectedWizardCantrips.addAll(cantrips.take(maxCantrips).map((c) => c.id));
                }
                if (level1Spells.isNotEmpty && maxSpells > 0) {
                  _selectedWizardSpells.addAll(level1Spells.take(maxSpells).map((s) => s.id));
                }
              });
            },
          ),
        ),

        // Section 1: Cantrips
        if (maxCantrips > 0 || cantrips.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade900.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CANTRIPS (Level 0)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                    Text(
                      '${_selectedWizardCantrips.length} / $maxCantrips selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: _selectedWizardCantrips.length == maxCantrips ? Colors.greenAccent : Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (cantrips.isEmpty)
                  const Text('No class-specific cantrips found.', style: TextStyle(fontSize: 12, color: Colors.white54))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cantrips.map((c) {
                      final isSelected = _selectedWizardCantrips.contains(c.id);
                      return FilterChip(
                        selected: isSelected,
                        selectedColor: Colors.purpleAccent.withValues(alpha: 0.3),
                        label: Text(c.getName(edition)),
                        avatar: Icon(Icons.star, size: 14, color: isSelected ? Colors.purpleAccent : Colors.white54),
                        onSelected: (selected) {
                          HapticService.selectionTick(context);
                          setState(() {
                            if (selected) {
                              if (_selectedWizardCantrips.length < maxCantrips) {
                                _selectedWizardCantrips.add(c.id);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Cannot select more than $maxCantrips cantrips for Level 1 ${curClass.name}.'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } else {
                              _selectedWizardCantrips.remove(c.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Section 2: 1st-Level Spells
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.cyan.shade900.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(spellsSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  Text(
                    '${_selectedWizardSpells.length} / $maxSpells selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedWizardSpells.length == maxSpells ? Colors.greenAccent : Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(spellsSubtitle, style: const TextStyle(fontSize: 11, color: Colors.white60, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              if (level1Spells.isEmpty)
                const Text('No class-specific 1st-level spells found.', style: TextStyle(fontSize: 12, color: Colors.white54))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: level1Spells.map((s) {
                    final isSelected = _selectedWizardSpells.contains(s.id);
                    return FilterChip(
                      selected: isSelected,
                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                      label: Text(s.getName(edition)),
                      avatar: Icon(Icons.auto_awesome, size: 14, color: isSelected ? Colors.cyanAccent : Colors.white54),
                      onSelected: (selected) {
                        HapticService.selectionTick(context);
                        setState(() {
                          if (selected) {
                            if (_selectedWizardSpells.length < maxSpells) {
                              _selectedWizardSpells.add(s.id);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cannot select more than $maxSpells spells for Level 1 ${curClass.name}.'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            _selectedWizardSpells.remove(s.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep7Review(ThemeData theme, Race sp, CharacterClass cls, Background bg) {
    final name = _nameController.text.trim().isEmpty ? 'Adventurer' : _nameController.text.trim();
    final is2024 = _selectedRuleset == RulesetVersion.v2024;
    final hasFeat = is2024 || sp.grantsBonusFeat;
    final selectedPkg = SrdEquipmentLibrary.findPackageById(_selectedStartingEquipmentPreset) ??
        SrdEquipmentLibrary.getPackagesForClass(cls.id.slug).first;
    final stepNumber = _getWizardStepTypes().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $stepNumber: Review & Finalize',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        const SizedBox(height: 6),
        const Text('Review your generated character summary before launching the live sheet.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const Divider(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          subtitle: Text('Level 1 ${cls.name} • ${sp.name} • ${bg.name}\nRuleset: ${_selectedRuleset.name.toUpperCase()}',
              style: const TextStyle(color: Colors.cyanAccent)),
        ),
        const SizedBox(height: 8),
        Text('Class Saving Throws: ${cls.savingThrows.join(", ")}', style: const TextStyle(fontSize: 12)),
        Builder(builder: (ctx) {
          final reviewSkillReport = SkillTraitResolver.resolveSkills(
            speciesSlug: _selectedSpecies,
            backgroundSlug: _selectedBackground,
            classSlug: cls.id.slug,
            requestedClassSkills: _wizardSelectedSkills,
            compensatoryPicks: _compensatorySkillPicks,
            edition: _selectedRuleset == RulesetVersion.v2024 ? DmRulesEdition.v2024 : DmRulesEdition.v2014,
          );
          final allReviewSkills = {...reviewSkillReport.resolvedProficiencies.keys, ..._speciesBonusSkillPicks};
          return Text('Skill Proficiencies: ${allReviewSkills.map((s) => s.displayName).join(", ")}', style: const TextStyle(fontSize: 12));
        }),
        if (hasFeat)
          Text(is2024 ? 'Origin Feat: ${_selectedFeat.toUpperCase()}' : 'Feat: ${_selectedFeat.toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.purpleAccent)),
        if (_selectedWizardCantrips.isNotEmpty || _selectedWizardSpells.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Spells: ${_selectedWizardCantrips.length} Cantrips, ${_selectedWizardSpells.length} 1st-Level Spells',
            style: const TextStyle(fontSize: 12, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 4),
        Text('Starting Inventory: ${selectedPkg.name} (${selectedPkg.startingGold} GP)',
            style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
        const SizedBox(height: 8),
        Text('Scores: STR ${_wizardBaseScores.strength}, DEX ${_wizardBaseScores.dexterity}, CON ${_wizardBaseScores.constitution}, INT ${_wizardBaseScores.intelligence}, WIS ${_wizardBaseScores.wisdom}, CHA ${_wizardBaseScores.charisma}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
      ],
    );
  }

  AbilityScores _adjustScore(AbilityScores scores, AbilityType ab, int delta) {
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

  void _rollAbilityScores() {
    final rand = math.Random();
    final newPool = <int>[];
    final newBreakdowns = <String>[];

    if (_rollMethod == 'standard_4d6') {
      for (int i = 0; i < 6; i++) {
        final dice = List.generate(4, (_) => rand.nextInt(6) + 1)..sort();
        final dropped = dice.first;
        final kept = dice.sublist(1);
        final total = kept.reduce((a, b) => a + b);
        newPool.add(total);
        newBreakdowns.add('4d6 (drop $dropped): [${kept.join(", ")}] => $total');
      }
    } else if (_rollMethod == 'classic_3d6_down' || _rollMethod == 'classic_3d6_nice') {
      for (int i = 0; i < 6; i++) {
        final dice = List.generate(3, (_) => rand.nextInt(6) + 1);
        final total = dice.reduce((a, b) => a + b);
        newPool.add(total);
        newBreakdowns.add('3d6: [${dice.join(", ")}] => $total');
      }
    } else if (_rollMethod == 'silly_d20') {
      for (int i = 0; i < 6; i++) {
        final d20 = rand.nextInt(20) + 1;
        newPool.add(d20);
        newBreakdowns.add('1d20 Chaos: => $d20');
      }
    }

    setState(() {
      _rolledPool = newPool;
      _rolledBreakdowns = newBreakdowns;
      if (_rollMethod == 'classic_3d6_down') {
        _rolledAssignments[AbilityType.strength] = newPool[0];
        _rolledAssignments[AbilityType.dexterity] = newPool[1];
        _rolledAssignments[AbilityType.constitution] = newPool[2];
        _rolledAssignments[AbilityType.intelligence] = newPool[3];
        _rolledAssignments[AbilityType.wisdom] = newPool[4];
        _rolledAssignments[AbilityType.charisma] = newPool[5];
        _wizardBaseScores = AbilityScores(
          strength: newPool[0],
          dexterity: newPool[1],
          constitution: newPool[2],
          intelligence: newPool[3],
          wisdom: newPool[4],
          charisma: newPool[5],
        );
      } else {
        for (int i = 0; i < AbilityType.values.length; i++) {
          _rolledAssignments[AbilityType.values[i]] = newPool[i];
        }
        _syncRolledToWizardScores();
      }
    });
  }

  void _syncRolledToWizardScores() {
    _wizardBaseScores = AbilityScores(
      strength: _rolledAssignments[AbilityType.strength] ?? 10,
      dexterity: _rolledAssignments[AbilityType.dexterity] ?? 10,
      constitution: _rolledAssignments[AbilityType.constitution] ?? 10,
      intelligence: _rolledAssignments[AbilityType.intelligence] ?? 10,
      wisdom: _rolledAssignments[AbilityType.wisdom] ?? 10,
      charisma: _rolledAssignments[AbilityType.charisma] ?? 10,
    );
  }

  void _syncManualToWizardScores() {
    _wizardBaseScores = AbilityScores(
      strength: _manualPicks[AbilityType.strength] ?? 10,
      dexterity: _manualPicks[AbilityType.dexterity] ?? 10,
      constitution: _manualPicks[AbilityType.constitution] ?? 10,
      intelligence: _manualPicks[AbilityType.intelligence] ?? 10,
      wisdom: _manualPicks[AbilityType.wisdom] ?? 10,
      charisma: _manualPicks[AbilityType.charisma] ?? 10,
    );
  }

  AbilityScores _calculateBonusScores(Race curSpecies, Background curBackground, RulesetVersion ruleset) {
    if (ruleset == RulesetVersion.v2014) {
      final fixed = curSpecies.fixedAbilityBonuses2014;
      final flexibleCount = curSpecies.flexibleAbilityChoiceCount;
      final flexibleBonus = curSpecies.flexibleAbilityBonusValue;

      int str = fixed['strength'] ?? 0;
      int dex = fixed['dexterity'] ?? 0;
      int con = fixed['constitution'] ?? 0;
      int intl = fixed['intelligence'] ?? 0;
      int wis = fixed['wisdom'] ?? 0;
      int cha = fixed['charisma'] ?? 0;

      if (flexibleCount > 0) {
        if (_variantHumanBonuses.contains(AbilityType.strength)) str += flexibleBonus;
        if (_variantHumanBonuses.contains(AbilityType.dexterity)) dex += flexibleBonus;
        if (_variantHumanBonuses.contains(AbilityType.constitution)) con += flexibleBonus;
        if (_variantHumanBonuses.contains(AbilityType.intelligence)) intl += flexibleBonus;
        if (_variantHumanBonuses.contains(AbilityType.wisdom)) wis += flexibleBonus;
        if (_variantHumanBonuses.contains(AbilityType.charisma)) cha += flexibleBonus;
      }

      return AbilityScores(
        strength: str,
        dexterity: dex,
        constitution: con,
        intelligence: intl,
        wisdom: wis,
        charisma: cha,
      );
    } else {
      // 2024 rules: +2 to chosen primary, +1 to secondary
      return AbilityScores(
        strength: (_backgroundPrimaryBonus == AbilityType.strength ? 2 : 0) + (_backgroundSecondaryBonus == AbilityType.strength ? 1 : 0),
        dexterity: (_backgroundPrimaryBonus == AbilityType.dexterity ? 2 : 0) + (_backgroundSecondaryBonus == AbilityType.dexterity ? 1 : 0),
        constitution: (_backgroundPrimaryBonus == AbilityType.constitution ? 2 : 0) + (_backgroundSecondaryBonus == AbilityType.constitution ? 1 : 0),
        intelligence: (_backgroundPrimaryBonus == AbilityType.intelligence ? 2 : 0) + (_backgroundSecondaryBonus == AbilityType.intelligence ? 1 : 0),
        wisdom: (_backgroundPrimaryBonus == AbilityType.wisdom ? 2 : 0) + (_backgroundSecondaryBonus == AbilityType.wisdom ? 1 : 0),
        charisma: (_backgroundPrimaryBonus == AbilityType.charisma ? 2 : 0) + (_backgroundSecondaryBonus == AbilityType.charisma ? 1 : 0),
      );
    }
  }

  void _finalizeCreatedCharacter() {
    final curClass = SrdClassesLibrary.findBySlug(_selectedClass) ?? SrdClassesLibrary.fighter;
    final curSpecies = SrdSpeciesLibrary.findBySlug(_selectedSpecies) ?? SrdSpeciesLibrary.human;
    final curBackground = SrdBackgroundsLibrary.findBySlug(_selectedBackground) ?? SrdBackgroundsLibrary.soldier;

    // Resolve class saves
    final saveProficiencies = curClass.savingThrows.map((s) {
      final match = AbilityType.values.firstWhere(
        (a) => a.name.toLowerCase() == s.toLowerCase() || a.shortName.toLowerCase() == s.toLowerCase(),
        orElse: () => AbilityType.strength,
      );
      return match;
    }).toSet();

    // Map skill proficiencies using SkillTraitResolver
    final skillReport = SkillTraitResolver.resolveSkills(
      speciesSlug: _selectedSpecies,
      backgroundSlug: _selectedBackground,
      classSlug: curClass.id.slug,
      requestedClassSkills: _wizardSelectedSkills,
      compensatoryPicks: _compensatorySkillPicks,
      edition: _selectedRuleset == RulesetVersion.v2024 ? DmRulesEdition.v2024 : DmRulesEdition.v2014,
    );
    final skillMap = Map<SkillType, SkillProficiencyLevel>.from(skillReport.resolvedProficiencies);
    for (final sk in _speciesBonusSkillPicks) {
      skillMap[sk] = SkillProficiencyLevel.proficient;
    }

    // Starting equipment and purse from chosen SRD package
    final classPackages = SrdEquipmentLibrary.getPackagesForClass(curClass.id.slug);
    final selectedPkg = SrdEquipmentLibrary.findPackageById(_selectedStartingEquipmentPreset) ?? classPackages.first;
    final equipRequests = List<StartingEquipmentItemRequest>.from(selectedPkg.items);
    final startingPurse = PartyPurse(gp: selectedPkg.startingGold);

    final is2024 = _selectedRuleset == RulesetVersion.v2024;
    final hasFeat = is2024 || curSpecies.grantsBonusFeat;
    final cantripRefs = _selectedWizardCantrips.map((id) {
      final spell = SpellbookLibrary.getSpellById(id);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: id,
        displayName: spell?.name ?? id,
      );
    }).toList();

    final allSelectedSpells = List<String>.from(_selectedWizardSpells);
    final autoGrantedSubclassSpells = SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: curClass.id.slug,
      subclassSlug: _wizardSelectedSubclass,
      classLevel: 1,
      edition: _selectedRuleset == RulesetVersion.v2024 ? DmRulesEdition.v2024 : DmRulesEdition.v2014,
    );
    for (final s in autoGrantedSubclassSpells) {
      if (!allSelectedSpells.contains(s.id)) {
        allSelectedSpells.add(s.id);
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

    final calculatedBonuses = _calculateBonusScores(curSpecies, curBackground, _selectedRuleset);

    EntityReference<DomainEntity>? startingSubclassRef;
    if (curClass.getSubclassLevel(_selectedRuleset) == 1 && curClass.subclasses.isNotEmpty) {
      final chosenSubSlug = _wizardSelectedSubclass ?? curClass.subclasses.first.id.slug;
      final sub = curClass.subclasses.firstWhere(
        (s) => s.id.slug == chosenSubSlug,
        orElse: () => curClass.subclasses.first,
      );
      startingSubclassRef = EntityReference<DomainEntity>(
        refType: EntityType.subclass,
        slug: sub.id.slug,
        displayName: sub.name,
      );
    }

    final request = CharacterCreationRequest(
      characterName: _nameController.text.trim().isEmpty ? 'Adventurer' : _nameController.text.trim(),
      ruleset: _selectedRuleset,
      speciesRef: EntityReference(
        refType: EntityType.species,
        slug: curSpecies.id.slug,
        displayName: curSpecies.name,
      ),
      backgroundRef: EntityReference(
        refType: EntityType.background,
        slug: curBackground.id.slug,
        displayName: curBackground.name,
      ),
      startingClassSlug: curClass.id.slug,
      startingClassDisplayName: curClass.name,
      startingClassHitDie: curClass.hitDie,
      baseScores: _wizardBaseScores,
      bonusScores: calculatedBonuses,
      savingThrowProficiencies: saveProficiencies,
      skillProficiencies: skillMap,
      originFeats: [
        if (hasFeat)
          EntityReference(
            refType: EntityType.feat,
            slug: _selectedFeat,
            displayName: SrdFeatsLibrary.findBySlug(_selectedFeat)?.name ?? 'Feat',
          ),
      ],
      startingEquipment: equipRequests,
      startingPurse: startingPurse,
      cantrips: cantripRefs,
      spellsKnown: spellRefs,
      spellsPrepared: spellRefs,
      startingSubclassRef: startingSubclassRef,
      selectedFeatureOptions: Map<String, List<String>>.from(_wizardSelectedFeatureOptions),
    );

    final newChar = CharacterFactory.createLevel1Character(request);
    _persistenceService.saveCharacter(newChar).then((updated) {
      if (mounted) {
        setState(() {
          _characterRoster = updated;
          _character = newChar;
          _isSelectorView = false;
          _wizardStep = 0;
          _recalculateStats();
          _syncTabController();
          _tabController.animateTo(0);
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created ${newChar.name} successfully!')),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: INVENTORY & ATOMICS LOOT TRANSFERS
  // --------------------------------------------------------------------------
  Widget _buildInventoryTab(ThemeData theme) {
    final char = _character;
    if (char == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              const Text('No Active Character',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Select or create a character to manage inventory and equipment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: const Text('Go to Character Roster'),
                onPressed: () {
                  setState(() {
                    _isSelectorView = true;
                    _syncTabController();
                    _tabController.animateTo(0);
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Attunement Counter Card
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Attunement: ${char.attunedItemCount} / ${char.maxAttunementSlots} Slots',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Text('Gold: ${char.purse.gp} GP',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CHARACTER INVENTORY',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text('Add SRD Item'),
              onPressed: () => _showAddSrdItemDialog(char),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...char.inventory.map((item) {
          return Card(
            color: const Color(0xFF1E293B),
            child: ListTile(
              title: Text(item.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Qty: ${item.quantity} • ${item.isEquipped ? "Equipped in ${item.equippedSlot?.displayName}" : "In Backpack"}${item.requiresAttunement ? (item.isAttuned ? " • [Attuned]" : " • [Unattuned]") : ""}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.requiresAttunement)
                    IconButton(
                      icon: Icon(item.isAttuned ? Icons.star : Icons.star_border,
                          color: item.isAttuned ? Colors.purpleAccent : Colors.white60),
                      tooltip: item.isAttuned ? 'Unattune' : 'Attune',
                      onPressed: () {
                        try {
                          final updated = InventoryTransactionService.attuneItem(
                              char, item.instanceId, !item.isAttuned);
                          setState(() {
                            _character = updated;
                            _recalculateStats();
                          });
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                    ),
                  IconButton(
                    icon: Icon(item.isEquipped ? Icons.check_box : Icons.check_box_outline_blank,
                        color: item.isEquipped ? Colors.cyanAccent : Colors.white60),
                    tooltip: item.isEquipped ? 'Unequip' : 'Equip',
                    onPressed: () {
                      final updated = item.isEquipped
                          ? InventoryTransactionService.unequipItem(char, item.instanceId)
                          : InventoryTransactionService.equipItem(char, item.instanceId, EquipmentSlot.mainHand);
                      setState(() {
                        _character = updated;
                        _recalculateStats();
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }),

        if (char.inventory.isEmpty)
          const Card(
            color: Color(0xFF1E293B),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Inventory is empty. Tap "Add SRD Item" above to add gear and equipment.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showAddSrdItemDialog(Character char) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allItems = MagicItemLibrary.allItems;
            final filtered = searchQuery.trim().isEmpty
                ? allItems.take(50).toList()
                : allItems
                    .where((item) =>
                        item.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        item.category.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        item.tags.any((t) => t.toLowerCase().contains(searchQuery.toLowerCase())))
                    .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2, color: Colors.cyanAccent),
                              SizedBox(width: 8),
                              Text('SRD Equipment & Magic Items',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search SRD weapons, armor, potions, gear...',
                          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Card(
                              color: const Color(0xFF1E293B),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                subtitle: Text(
                                  '${item.category.name.toUpperCase()} • ${item.rarity.name}${item.cost != null ? " • ${item.cost}" : ""}\n${item.rules2024.summary.isNotEmpty ? item.rules2024.summary : item.rules2014.summary}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                                ),
                                trailing: ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    final newInstance = InventoryItemInstance(
                                      instanceId: 'srd-${item.id}-${DateTime.now().millisecondsSinceEpoch}',
                                      itemRef: EntityReference(
                                        refType: EntityType.equipment,
                                        slug: item.id.replaceAll('_', '-'),
                                        displayName: item.name,
                                      ),
                                      quantity: 1,
                                      requiresAttunement: item.requiresAttunement,
                                    );
                                    final updatedInventory = List<InventoryItemInstance>.from(char.inventory)..add(newInstance);
                                    final updatedChar = char.copyWith(inventory: updatedInventory);
                                    _persistenceService.saveCharacter(updatedChar).then((_) {
                                      if (mounted) {
                                        setState(() {
                                          _character = updatedChar;
                                          _recalculateStats();
                                        });
                                      }
                                    });
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(content: Text('Added ${item.name} to inventory!')),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // TAB 4: LEVEL UP & MULTICLASSING PIPELINE
  // --------------------------------------------------------------------------
  Widget _buildLevelUpTab(ThemeData theme) {
    final char = _character;
    if (char == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upgrade, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              const Text('No Active Character',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Select or create a character to advance levels.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: const Text('Go to Character Roster'),
                onPressed: () {
                  setState(() {
                    _isSelectorView = true;
                    _syncTabController();
                    _tabController.animateTo(0);
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    final primaryClass = char.progression.classes.firstOrNull;
    final primaryClassName = primaryClass?.classRef.displayName.isNotEmpty == true
        ? primaryClass!.classRef.displayName
        : 'Adventurer';
    final nextLevel = char.totalLevel + 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Level Up Launchpad Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E293B),
                Colors.purple.shade900.withValues(alpha: 0.35),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.upgrade, color: Colors.purpleAccent, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level Up ${char.name}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current: Level ${char.totalLevel} $primaryClassName  ➔  Next: Level $nextLevel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.purpleAccent.shade100,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 12),
              Text(
                'Ready to advance your character? The 5e Level Up Wizard will guide you step-by-step through:',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              _buildLevelUpFeatureBullet(Icons.health_and_safety_outlined, 'Hit Points & Hit Die Scaling (Average vs Interactive Roll)'),
              _buildLevelUpFeatureBullet(Icons.auto_awesome, 'Class Archetypes & Subclass Selection at Milestone Levels'),
              _buildLevelUpFeatureBullet(Icons.fitness_center, 'Ability Score Improvements (ASI) or Feats (+2 / +1+1 / Feat)'),
              _buildLevelUpFeatureBullet(Icons.menu_book, 'Spellcasting & Spell Slot Scaling according to 5e rules'),
              _buildLevelUpFeatureBullet(Icons.alt_route, 'Multiclassing with Prerequisite Verification (13+ stat requirement)'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purpleAccent.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.rocket_launch, size: 20),
                  label: const Text(
                    'LAUNCH LEVEL UP WIZARD',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                  ),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    LevelUpWizardDialog.show(
                      context,
                      character: char,
                      onLevelUpApplied: (upgraded) {
                        _persistenceService.saveCharacter(upgraded).then((updatedRoster) {
                          if (mounted) {
                            setState(() {
                              _characterRoster = updatedRoster;
                              _character = upgraded;
                              _recalculateStats();
                              _tabController.animateTo(0);
                            });
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLevelUpFeatureBullet(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.purpleAccent.shade100),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
