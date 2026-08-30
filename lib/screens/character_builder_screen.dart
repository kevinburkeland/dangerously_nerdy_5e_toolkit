import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/characters/srd_feats_library.dart';
import '../models/characters/srd_skills_library.dart';
import '../models/characters/srd_classes_library.dart';
import '../models/characters/srd_species_library.dart';
import '../models/characters/srd_backgrounds_library.dart';
import '../models/domain/core_types.dart';
import '../models/domain/character_models.dart';
import '../models/domain/entity_reference.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../models/domain/loot_models.dart';
import '../models/domain/spell_monster_equipment.dart';
import '../models/party/party_purse.dart';
import '../services/haptic_service.dart';
import '../services/repository/layered_priority_repository.dart';
import '../services/repository/reference_resolver.dart';
import '../services/rules/character_factory.dart';
import '../services/rules/character_stat_calculator.dart';
import '../services/rules/dnd_5e_rules_engine.dart';
import '../services/rules/inventory_transaction_service.dart';
import '../services/rules/level_up_pipeline.dart';
import '../services/persistence/character_persistence_service.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../providers/settings_provider.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/glyphs/dnd_glyph.dart';
import '../widgets/glyphs/glyph_tokens.dart';
import '../widgets/room_banner_widget.dart';

/// Interactive Character Generator, Live State Sheet, and Multiclassing Studio
class CharacterBuilderScreen extends StatefulWidget {
  const CharacterBuilderScreen({super.key});

  @override
  State<CharacterBuilderScreen> createState() => _CharacterBuilderScreenState();
}

class _CharacterBuilderScreenState extends State<CharacterBuilderScreen>
    with SingleTickerProviderStateMixin {
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
  ComputedCharacterStats? _computedStats;
  int _currentHp = 12;
  int _tempHp = 0;
  int _deathSaveSuccesses = 0;
  int _deathSaveFailures = 0;
  bool _hasHeroicInspiration = false;

  // Live Sheet Filter
  String _skillSearchQuery = '';
  AbilityType? _selectedAbilityFilter;

  // Sample Room Loot Container
  late LootContainer _roomChest;

  // Guided Character Creation Wizard State
  int _wizardStep = 0;
  RulesetVersion _selectedRuleset = RulesetVersion.v2024;
  final TextEditingController _nameController = TextEditingController();
  String _selectedSpecies = 'human';
  String _selectedClass = 'fighter';
  String _selectedBackground = 'soldier';
  String _selectedFeat = 'savage-attacker';
  String _selectedStartingEquipmentPreset = 'chain_and_sword';
  Set<SkillType> _wizardSelectedSkills = {SkillType.athletics, SkillType.intimidation};

  // Ability Allocation Mode
  String _abilityScoreMode = 'standard'; // 'standard', 'pointBuy', 'custom'
  AbilityScores _wizardBaseScores = const AbilityScores.standardArray();
  final Map<AbilityType, int> _standardArrayPicks = {
    AbilityType.strength: 15,
    AbilityType.dexterity: 14,
    AbilityType.constitution: 13,
    AbilityType.intelligence: 12,
    AbilityType.wisdom: 10,
    AbilityType.charisma: 8,
  };

  // Level Up Wizard State
  String _levelUpTargetClass = 'fighter';
  bool _levelUpUseAverage = true;
  int _levelUpRolledHp = 6;
  bool _levelUpIsAsi = true;
  AbilityType _asiAbility1 = AbilityType.strength;
  AbilityType _asiAbility2 = AbilityType.constitution;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _repository = LayeredPriorityRepository();
    _resolver = ReferenceResolver(_repository);

    _initSampleRepository();
    _initDefaultCharacter();
    _initSampleChest();
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
          _currentHp = _computedStats?.maxHp ?? 10;
        } else {
          _character = null;
          _isSelectorView = true;
        }
      });
    }
  }

  void _selectCharacter(Character char) {
    HapticService.selectionTick(context);
    setState(() {
      _character = char;
      _currentHp = char.resources.currentHp > 0 ? char.resources.currentHp : 1;
      _tempHp = char.resources.tempHp;
      _rulesEdition = char.ruleset == RulesetVersion.v2024
          ? DmRulesEdition.v2024
          : DmRulesEdition.v2014;
      _isSelectorView = false;
      _recalculateStats();
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

  void _initSampleChest() {
    _roomChest = const LootContainer(
      containerId: 'chest-dungeon-1',
      name: 'Crypt Sarcophagus Chest',
      items: [
        InventoryItemInstance(
          instanceId: 'chest-loot-greatsword',
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'greatsword',
            displayName: 'Greatsword',
          ),
          quantity: 1,
        ),
        InventoryItemInstance(
          instanceId: 'chest-loot-gauntlets',
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'gauntlets-of-ogre-power',
            displayName: 'Gauntlets of Ogre Power',
          ),
          requiresAttunement: true,
          quantity: 1,
        ),
        InventoryItemInstance(
          instanceId: 'chest-loot-potion',
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'potion-of-healing',
            displayName: 'Potion of Healing',
          ),
          quantity: 3,
        ),
      ],
      purse: PartyPurse(gp: 150, sp: 75),
    );
  }

  void _recalculateStats() {
    final char = _character;
    if (char != null) {
      setState(() {
        _computedStats = CharacterStatCalculator.compute(char, _resolver);
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

  void _rollDie({
    required String title,
    required int modifier,
    bool advantage = false,
    bool disadvantage = false,
  }) {
    HapticService.heavyImpact(context);
    final d1 = math.Random().nextInt(20) + 1;
    final d2 = math.Random().nextInt(20) + 1;
    int d20 = d1;
    String rollDesc = '$d1';
    if (advantage) {
      d20 = math.max(d1, d2);
      rollDesc = 'max($d1, $d2) = $d20 [ADV]';
    } else if (disadvantage) {
      d20 = math.min(d1, d2);
      rollDesc = 'min($d1, $d2) = $d20 [DIS]';
    }

    final total = d20 + modifier;
    final isCrit = d20 == 20;
    final isFumble = d20 == 1;

    final sign = modifier >= 0 ? '+$modifier' : '$modifier';
    final resultSummary = isCrit
        ? 'NATURAL 20! Total: $total ($rollDesc $sign)'
        : (isFumble
            ? 'NATURAL 1! Total: $total ($rollDesc $sign)'
            : 'Result: $total (d20: $rollDesc $sign)');

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isCrit
            ? Colors.green.shade900
            : (isFumble ? Colors.red.shade900 : const Color(0xFF1E293B)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isCrit
                  ? Icons.stars
                  : (isFumble ? Icons.warning_amber : Icons.casino),
              color: isCrit
                  ? Colors.greenAccent
                  : (isFumble ? Colors.redAccent : Colors.cyanAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    resultSummary,
                    style: TextStyle(
                      color: isCrit
                          ? Colors.greenAccent
                          : (isFumble ? Colors.redAccent : Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
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
        _computedStats = CharacterStatCalculator.compute(_character!, _resolver);
      }
    }

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
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Live Sheet'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Guided Builder'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Inventory & Loot'),
            Tab(icon: Icon(Icons.upgrade), text: 'Level Up'),
          ],
        ),
      ),
      body: Column(
        children: [
          RoomBannerWidget(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLiveSheetTab(theme),
                _buildGuidedBuilderTab(theme),
                _buildInventoryTab(theme),
                _buildLevelUpTab(theme),
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
    final stats = _computedStats;
    if (char == null || stats == null) {
      return _buildCharacterSelectorView(theme);
    }
    final curClass = char.progression.classes.firstOrNull;
    final srdClass = curClass != null
        ? SrdClassesLibrary.findBySlug(curClass.classRef.slug)
        : null;
    final srdSpecies =
        SrdSpeciesLibrary.findBySlug(char.speciesRef.slug);
    final srdBackground = char.backgroundRef != null
        ? SrdBackgroundsLibrary.findBySlug(char.backgroundRef!.slug)
        : null;

    // Filter skills
    final filteredSkills = SkillType.values.where((sk) {
      if (_selectedAbilityFilter != null &&
          sk.defaultAbility != _selectedAbilityFilter) {
        return false;
      }
      if (_skillSearchQuery.isNotEmpty &&
          !sk.displayName
              .toLowerCase()
              .contains(_skillSearchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Summary Card
        Card(
          color: const Color(0xFF1E293B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(color: Colors.cyanAccent),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.groups_outlined, size: 16),
                      label: Text(
                          'Switch Hero (${_characterRoster.length})',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        HapticService.selectionTick(context);
                        setState(() => _isSelectorView = true);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      tooltip: 'Delete ${char.name}',
                      onPressed: () =>
                          _confirmDeleteCharacter(char),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (curClass != null && _findClassType(curClass.classRef.slug) != null) ...[
                      RepaintBoundary(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: DndGlyph.classFeature(
                              classType: _findClassType(curClass.classRef.slug)!,
                              size: 48,
                              isDarkMode: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            char.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Level ${char.totalLevel} ${char.progression.classes.map((c) => "${c.classRef.displayName} ${c.level}").join(" / ")} • ${char.speciesRef.displayName} • ${char.backgroundRef?.displayName ?? "Adventurer"}',
                            style: TextStyle(color: Colors.cyanAccent.shade100, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      backgroundColor: Colors.cyan.shade900,
                      label: Text(
                        char.ruleset == RulesetVersion.v2024 ? '2024 REVISED' : '2014 CLASSIC',
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white24),

                // Core Quick Vitals
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatPill('ARMOR CLASS', '${stats.armorClass}', Colors.amberAccent, Icons.shield),
                    _buildHpPill('HIT POINTS', '$_currentHp / ${stats.maxHp}', Colors.redAccent, Icons.favorite),
                    _buildStatPill('PROF BONUS', '+${stats.proficiencyBonus}', Colors.cyanAccent, Icons.star),
                    _buildStatPill('SPEED', '${stats.speedFeet} ft', Colors.greenAccent, Icons.directions_run),
                    _buildStatPill('INITIATIVE', stats.initiativeBonus >= 0 ? '+${stats.initiativeBonus}' : '${stats.initiativeBonus}', Colors.deepOrangeAccent, Icons.flash_on),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'AC Formula: ${stats.armorClassBreakdown}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.white60, fontStyle: FontStyle.italic),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.flash_on, size: 14),
                      label: const Text('Roll Init', style: TextStyle(fontSize: 11)),
                      onPressed: () => _rollDie(
                        title: 'Initiative Roll',
                        modifier: stats.initiativeBonus,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // HP, Temp HP & Interactive Adjustments
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'HP Tracker: $_currentHp / ${stats.maxHp}${_tempHp > 0 ? " (+$_tempHp Temp)" : ""}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16, color: Colors.redAccent),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  if (_currentHp > 0) {
                                    setState(() => _currentHp = math.max(0, _currentHp - 1));
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16, color: Colors.greenAccent),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  if (_currentHp < stats.maxHp) {
                                    setState(() => _currentHp = math.min(stats.maxHp, _currentHp + 1));
                                  }
                                },
                              ),
                              TextButton(
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Short/Long Rest', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  setState(() {
                                    _currentHp = stats.maxHp;
                                    _tempHp = 0;
                                    _deathSaveSuccesses = 0;
                                    _deathSaveFailures = 0;
                                  });
                                  HapticService.selectionTick(context);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stats.maxHp > 0 ? (_currentHp / stats.maxHp).clamp(0.0, 1.0) : 0.0,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _currentHp > (stats.maxHp * 0.5)
                                ? Colors.greenAccent
                                : (_currentHp > (stats.maxHp * 0.25)
                                    ? Colors.amberAccent
                                    : Colors.redAccent),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Hit Dice
                    Column(
                      children: [
                        const Text('HIT DICE', style: TextStyle(fontSize: 10, color: Colors.white60)),
                        Text('1 / ${char.totalLevel} (${char.progression.classes.firstOrNull?.hitDie ?? "d10"})',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                      ],
                    ),
                    // Death Saves
                    Column(
                      children: [
                        const Text('DEATH SAVES', style: TextStyle(fontSize: 10, color: Colors.white60)),
                        Row(
                          children: [
                            const Text('S: ', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                            ...List.generate(3, (i) => Icon(
                              i < _deathSaveSuccesses ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 14,
                              color: Colors.greenAccent,
                            )),
                            const SizedBox(width: 8),
                            const Text('F: ', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                            ...List.generate(3, (i) => Icon(
                              i < _deathSaveFailures ? Icons.cancel : Icons.radio_button_unchecked,
                              size: 14,
                              color: Colors.redAccent,
                            )),
                          ],
                        ),
                      ],
                    ),
                    // Heroic Inspiration
                    InkWell(
                      onTap: () {
                        HapticService.selectionTick(context);
                        setState(() => _hasHeroicInspiration = !_hasHeroicInspiration);
                      },
                      child: Column(
                        children: [
                          const Text('HEROIC INSP', style: TextStyle(fontSize: 10, color: Colors.white60)),
                          Row(
                            children: [
                              Icon(
                                _hasHeroicInspiration ? Icons.star : Icons.star_border,
                                color: _hasHeroicInspiration ? Colors.amberAccent : Colors.white38,
                                size: 16,
                              ),
                              Text(
                                _hasHeroicInspiration ? ' Active' : ' None',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _hasHeroicInspiration ? Colors.amberAccent : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Ability Scores Row
        Text('ABILITY SCORES & MODIFIERS',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: AbilityType.values.map((ab) {
            final score = stats.effectiveScores.getScore(ab);
            final mod = stats.abilityModifiers[ab]!;
            final modStr = mod >= 0 ? '+$mod' : '$mod';
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Text(ab.shortName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(modStr,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    Text('$score', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // SAVING THROWS SECTION
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.cyanAccent, size: 18),
                        const SizedBox(width: 8),
                        Text('SAVING THROWS',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      ],
                    ),
                    const Text('Proficient saves highlighted', style: TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
                const Divider(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: AbilityType.values.map((ab) {
                    final isProf = char.savingThrowProficiencies.contains(ab);
                    final mod = stats.savingThrowModifiers[ab] ?? stats.abilityModifiers[ab]!;
                    final modStr = mod >= 0 ? '+$mod' : '$mod';
                    return InkWell(
                      key: ValueKey('save_tile_${ab.name}'),
                      onTap: () => _rollDie(
                        title: '${ab.name.toUpperCase()} Saving Throw',
                        modifier: mod,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isProf ? Colors.cyan.shade900.withValues(alpha: 0.3) : Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isProf ? Colors.cyanAccent.withValues(alpha: 0.6) : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isProf ? Icons.check_circle : Icons.circle_outlined,
                                  size: 14,
                                  color: isProf ? Colors.cyanAccent : Colors.white38,
                                ),
                                const SizedBox(width: 6),
                                Text(ab.shortName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            Text(modStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isProf ? Colors.cyanAccent : Colors.white,
                                )),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // SKILLS SECTION WITH FILTER & SEARCH
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_stories_outlined, color: Colors.cyanAccent, size: 18),
                        const SizedBox(width: 8),
                        Text('SKILLS & PROFICIENCIES',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                      ],
                    ),
                    Text('${filteredSkills.length} Skills', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
                const SizedBox(height: 8),

                // Search Box
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search skills...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (val) => setState(() => _skillSearchQuery = val),
                ),
                const SizedBox(height: 8),

                // Ability Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All', style: TextStyle(fontSize: 11)),
                        selected: _selectedAbilityFilter == null,
                        onSelected: (s) => setState(() => _selectedAbilityFilter = null),
                      ),
                      const SizedBox(width: 6),
                      ...AbilityType.values.map((ab) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(ab.shortName, style: const TextStyle(fontSize: 11)),
                              selected: _selectedAbilityFilter == ab,
                              onSelected: (s) => setState(() => _selectedAbilityFilter = s ? ab : null),
                            ),
                          )),
                    ],
                  ),
                ),
                const Divider(height: 16),

                // Skills List
                ...filteredSkills.map((sk) {
                  final profLevel = char.skillProficiencies[sk] ?? SkillProficiencyLevel.none;
                  final mod = stats.skillModifiers[sk] ?? 0;
                  final modStr = mod >= 0 ? '+$mod' : '$mod';
                  final passive = 10 + mod;
                  final skillDef = SrdSkillsLibrary.getDefinition(sk);

                  final profColor = switch (profLevel) {
                    SkillProficiencyLevel.expertise => Colors.amberAccent,
                    SkillProficiencyLevel.proficient => Colors.cyanAccent,
                    SkillProficiencyLevel.jackOfAllTrades => Colors.purpleAccent,
                    SkillProficiencyLevel.none => Colors.white38,
                  };

                  final profLabel = switch (profLevel) {
                    SkillProficiencyLevel.expertise => 'Expertise (★)',
                    SkillProficiencyLevel.proficient => 'Proficient (●)',
                    SkillProficiencyLevel.jackOfAllTrades => 'Jack (½)',
                    SkillProficiencyLevel.none => 'None',
                  };

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: profLevel != SkillProficiencyLevel.none
                          ? Colors.cyan.shade900.withValues(alpha: 0.15)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: profLevel != SkillProficiencyLevel.none
                            ? Colors.cyanAccent.withValues(alpha: 0.3)
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          profLevel == SkillProficiencyLevel.expertise
                              ? Icons.star
                              : (profLevel == SkillProficiencyLevel.proficient
                                  ? Icons.check_circle
                                  : Icons.circle_outlined),
                          size: 14,
                          color: profColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(sk.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text('(${sk.defaultAbility.shortName})',
                                      style: const TextStyle(fontSize: 10, color: Colors.white60)),
                                ],
                              ),
                              Text('$profLabel • Passive: $passive',
                                  style: TextStyle(fontSize: 10.5, color: profColor.withValues(alpha: 0.8))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 16, color: Colors.white60),
                          tooltip: 'Skill Info',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('${skillDef.name} (${skillDef.defaultAbility.shortName})'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(skillDef.description),
                                      const SizedBox(height: 10),
                                      const Text('Typical Examples:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(skillDef.examples, style: const TextStyle(color: Colors.white70)),
                                      const SizedBox(height: 10),
                                      Text('2024 Action: ${skillDef.actionType2024}',
                                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(skillDef.keyChanges2024, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                                ],
                              ),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent.shade700,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.casino, size: 14),
                          label: Text(modStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _rollDie(
                            title: '${sk.displayName} (${sk.defaultAbility.shortName}) Check',
                            modifier: mod,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
        // ACTIONS & ATTACKS CARD
        Text('ACTIONS & ATTACKS',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),

        ...stats.attackProfiles.map((atk) => Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                leading: const Icon(Icons.colorize, color: Colors.redAccent),
                title: Text(atk.weaponName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text('To Hit: ${atk.attackBonusString} • Damage: ${atk.damageFormula} ${atk.damageType.name}',
                    style: const TextStyle(color: Colors.white70)),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.casino, size: 16),
                  label: const Text('Roll'),
                  onPressed: () => _rollDie(
                    title: '${atk.weaponName} Attack',
                    modifier: atk.attackBonus,
                  ),
                ),
              ),
            )),

        const SizedBox(height: 16),

        // FEATURES, TRAITS & FEATS
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech_outlined, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('FEATURES, TRAITS & FEATS',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ],
                ),
                const Divider(height: 16),
                if (srdSpecies != null) ...[
                  Text('Species: ${srdSpecies.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  Text(srdSpecies.traitsMarkdown, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                ],
                if (srdClass != null) ...[
                  Text('Class: ${srdClass.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  Text(srdClass.featuresMarkdown, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                ],
                if (srdBackground != null) ...[
                  Text('Background: ${srdBackground.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  Text(srdBackground.descriptionMarkdown, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 10),
                ],
                if (char.feats.isNotEmpty) ...[
                  const Text('Active Feats:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                  ...char.feats.map((fRef) {
                    final featObj = SrdFeatsLibrary.findBySlug(fRef.slug);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ${featObj?.name ?? fRef.displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (featObj != null)
                            Text(featObj.descriptionMarkdown, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // PROFICIENCIES & SENSES
        Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye_outlined, color: Colors.cyanAccent, size: 18),
                    const SizedBox(width: 8),
                    Text('PASSIVE SENSES & PROFICIENCIES',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPassiveBadge('Passive Perception', stats.passivePerception, Colors.cyanAccent),
                    _buildPassiveBadge('Passive Investigation', stats.passiveInvestigation, Colors.amberAccent),
                    _buildPassiveBadge('Passive Insight', stats.passiveInsight, Colors.purpleAccent),
                  ],
                ),
                const SizedBox(height: 12),
                if (srdClass != null) ...[
                  Text('Armor Proficiencies: ${srdClass.armorProficiencies.isEmpty ? "None" : srdClass.armorProficiencies.join(", ")}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Weapon Proficiencies: ${srdClass.weaponProficiencies.join(", ")}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 4),
                ],
                Text('Languages: ${char.languages.join(", ")}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatPill(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
      ],
    );
  }

  Widget _buildHpPill(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.white60)),
      ],
    );
  }

  Widget _buildPassiveBadge(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: GUIDED CHARACTER CREATION WIZARD (STEP-BY-STEP)
  // --------------------------------------------------------------------------
  Widget _buildGuidedBuilderTab(ThemeData theme) {
    final is2024 = _selectedRuleset == RulesetVersion.v2024;
    final isVariantHuman = _selectedSpecies == 'human-variant';
    final hasFeatStep = is2024 || isVariantHuman;
    final maxStepIndex = hasFeatStep ? 7 : 6;

    final curClass = SrdClassesLibrary.findBySlug(_selectedClass) ?? SrdClassesLibrary.fighter;
    final curSpecies = SrdSpeciesLibrary.findBySlug(_selectedSpecies) ?? SrdSpeciesLibrary.human;
    final curBackground = SrdBackgroundsLibrary.findBySlug(_selectedBackground) ?? SrdBackgroundsLibrary.soldier;
    final allowedClassSkills = (curClass.customProperties['allowedSkills'] as List? ?? [])
        .map((s) => SkillType.values.firstWhere((st) => st.name == s.toString(), orElse: () => SkillType.athletics))
        .toList();
    final allowedSkillCount = (curClass.customProperties['skillChoiceCount'] as num?)?.toInt() ?? 2;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stepper Progress Header
        Row(
          children: List.generate(hasFeatStep ? 8 : 7, (i) {
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
              if (hasFeatStep) {
                return switch (_wizardStep) {
                  0 => _buildStep0Basics(theme),
                  1 => _buildStep1Species(theme),
                  2 => _buildStep2Class(theme, curClass, allowedClassSkills, allowedSkillCount),
                  3 => _buildStep3Background(theme, curBackground),
                  4 => _buildStep4AbilityScores(theme),
                  5 => _buildStep5Feats(theme),
                  6 => _buildStep6Equipment(theme, hasFeatStep: true),
                  _ => _buildStep7Review(theme, curSpecies, curClass, curBackground),
                };
              } else {
                return switch (_wizardStep) {
                  0 => _buildStep0Basics(theme),
                  1 => _buildStep1Species(theme),
                  2 => _buildStep2Class(theme, curClass, allowedClassSkills, allowedSkillCount),
                  3 => _buildStep3Background(theme, curBackground),
                  4 => _buildStep4AbilityScores(theme),
                  5 => _buildStep6Equipment(theme, hasFeatStep: false),
                  _ => _buildStep7Review(theme, curSpecies, curClass, curBackground),
                };
              }
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
                    final isVariantHuman = _selectedSpecies == 'human-variant';
                    final hasFeatStep = is2024 || isVariantHuman;
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
            return FilterChip(
              label: Text(sk.displayName),
              selected: isChosen,
              onSelected: (selected) {
                HapticService.selectionTick(context);
                setState(() {
                  if (selected) {
                    if (_wizardSelectedSkills.length < allowedCount) {
                      _wizardSelectedSkills.add(sk);
                    }
                  } else {
                    _wizardSelectedSkills.remove(sk);
                  }
                });
              },
            );
          }).toList(),
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 5: Ability Score Allocation',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text('Assign your 6 core attributes using Standard Array or Point Buy.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'standard', label: Text('Standard Array (15,14,13,12,10,8)')),
            ButtonSegment(value: 'pointBuy', label: Text('Point Buy (27 pts)')),
          ],
          selected: {_abilityScoreMode},
          onSelectionChanged: (set) {
            HapticService.selectionTick(context);
            setState(() => _abilityScoreMode = set.first);
          },
        ),
        const SizedBox(height: 16),
        if (_abilityScoreMode == 'pointBuy') ...[
          Text('Points Remaining: $pointsRemaining / 27',
              style: TextStyle(
                color: pointsRemaining >= 0 ? Colors.greenAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
              )),
          const SizedBox(height: 12),
          ...AbilityType.values.map((ab) {
            final score = _wizardBaseScores.getScore(ab);
            final mod = score.dndModifier;
            final modStr = mod >= 0 ? '+$mod' : '$mod';
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${ab.name.toUpperCase()} ($modStr)', style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: score > 8
                          ? () {
                              setState(() => _wizardBaseScores = _adjustScore(_wizardBaseScores, ab, -1));
                            }
                          : null,
                    ),
                    Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: score < 15
                          ? () {
                              setState(() => _wizardBaseScores = _adjustScore(_wizardBaseScores, ab, 1));
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            );
          }),
        ] else ...[
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
      ],
    );
  }

  Widget _buildStep5Feats(ThemeData theme) {
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
              : 'Step 6: Variant Human Bonus Feat (2014 Optional)',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 6),
        Text(
          is2024
              ? 'Choose your 1st-level origin feat granted by your 2024 background.'
              : 'As a Variant Human, choose your 1st-level bonus feat from the 2014 SRD Feat Library.',
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
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.purpleAccent : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    RepaintBoundary(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: DndGlyph.feat(
                            category: feat.category == 'Origin' ? FeatCategory.origin : FeatCategory.general,
                            featId: feat.id.slug,
                            size: 32,
                            isDarkMode: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(feat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(feat.descriptionMarkdown, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
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

  Widget _buildStep6Equipment(ThemeData theme, {bool hasFeatStep = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step ${hasFeatStep ? 7 : 6}: Starting Equipment Preset',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text('Choose your starting loadout package based on your class proficiencies.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),
        _buildEquipmentPresetOption(
          id: 'chain_and_sword',
          title: 'Heavy Knight Loadout',
          subtitle: 'Chain Mail (AC 16), Longsword (1d8), Shield (+2 AC)',
        ),
        _buildEquipmentPresetOption(
          id: 'medium_skirmisher',
          title: 'Medium Skirmisher Loadout',
          subtitle: 'Breastplate (AC 14+DEX), Greatsword (2d6), Potion of Healing',
        ),
        _buildEquipmentPresetOption(
          id: 'light_scout',
          title: 'Light Scout Loadout',
          subtitle: 'Leather Armor (AC 11+DEX), Shortsword (1d6), Longbow (1d8)',
        ),
      ],
    );
  }

  Widget _buildEquipmentPresetOption({required String id, required String title, required String subtitle}) {
    final isSelected = _selectedStartingEquipmentPreset == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.amberAccent : Colors.white12,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: isSelected ? Colors.amberAccent : Colors.white54,
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.white70)),
          onTap: () {
            HapticService.selectionTick(context);
            setState(() => _selectedStartingEquipmentPreset = id);
          },
        ),
      ),
    );
  }

  Widget _buildStep7Review(ThemeData theme, Race sp, CharacterClass cls, Background bg) {
    final name = _nameController.text.trim().isEmpty ? 'Adventurer' : _nameController.text.trim();
    final is2024 = _selectedRuleset == RulesetVersion.v2024;
    final isVariantHuman = _selectedSpecies == 'human-variant';
    final hasFeat = is2024 || isVariantHuman;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step ${hasFeat ? 8 : 7}: Review & Finalize',
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
        Text('Skill Proficiencies: ${_wizardSelectedSkills.map((s) => s.displayName).join(", ")}', style: const TextStyle(fontSize: 12)),
        if (hasFeat)
          Text(is2024 ? 'Origin Feat: ${_selectedFeat.toUpperCase()}' : 'Feat: ${_selectedFeat.toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.purpleAccent)),
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

    // Map skill proficiencies
    final skillMap = <SkillType, SkillProficiencyLevel>{};
    for (final sk in _wizardSelectedSkills) {
      skillMap[sk] = SkillProficiencyLevel.proficient;
    }
    // Also grant background skills
    for (final bgSkStr in curBackground.skillProficiencies) {
      final bgSk = SkillType.values.firstWhere(
        (st) => st.displayName.toLowerCase() == bgSkStr.toLowerCase() || st.name.toLowerCase() == bgSkStr.toLowerCase(),
        orElse: () => SkillType.perception,
      );
      skillMap[bgSk] = SkillProficiencyLevel.proficient;
    }

    // Starting equipment
    final equipRequests = <StartingEquipmentItemRequest>[];
    if (_selectedStartingEquipmentPreset == 'chain_and_sword') {
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'chain-mail', displayName: 'Chain Mail'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.armor,
      ));
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'longsword', displayName: 'Longsword'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.mainHand,
      ));
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'shield', displayName: 'Shield'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.offHand,
      ));
    } else if (_selectedStartingEquipmentPreset == 'medium_skirmisher') {
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'breastplate', displayName: 'Breastplate'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.armor,
      ));
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'greatsword', displayName: 'Greatsword'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.mainHand,
      ));
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'potion-of-healing', displayName: 'Potion of Healing'),
        quantity: 1,
      ));
    } else {
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'leather-armor', displayName: 'Leather Armor'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.armor,
      ));
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'shortsword', displayName: 'Shortsword'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.mainHand,
      ));
      equipRequests.add(const StartingEquipmentItemRequest(
        itemRef: EntityReference(refType: EntityType.equipment, slug: 'longbow', displayName: 'Longbow'),
        equipImmediately: true,
        defaultSlot: EquipmentSlot.twoHand,
      ));
    }

    final is2024 = _selectedRuleset == RulesetVersion.v2024;
    final isVariantHuman = curSpecies.id.slug == 'human-variant';
    final hasFeat = is2024 || isVariantHuman;

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
      bonusScores: const AbilityScores(strength: 2, constitution: 1),
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
      startingPurse: const PartyPurse(gp: 20),
    );

    final newChar = CharacterFactory.createLevel1Character(request);
    _persistenceService.saveCharacter(newChar).then((updatedRoster) {
      if (mounted) {
        setState(() {
          _characterRoster = updatedRoster;
          _character = newChar;
          _isSelectorView = false;
          _recalculateStats();
          _currentHp = _computedStats?.maxHp ?? 10;
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
        Text('CHARACTER INVENTORY',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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

        const SizedBox(height: 24),
        // Room Chest Section
        Text('ROOM LOOT POOL: ${_roomChest.name}',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Card(
          color: Colors.amber.shade900.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.amber.withValues(alpha: 0.4))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Chest Contents (Gold: ${_roomChest.purse.gp} GP)',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    if (_roomChest.purse.gp > 0)
                      TextButton.icon(
                        icon: const Icon(Icons.monetization_on, size: 16),
                        label: const Text('Take 50 GP'),
                        onPressed: () {
                          final res = InventoryTransactionService.transferFromContainerToCharacter(
                            sourceContainer: _roomChest,
                            destinationCharacter: char,
                            instanceId: _roomChest.items.firstOrNull?.instanceId ?? '',
                            quantity: 0,
                            currency: const PartyPurse(gp: 50),
                          );
                          setState(() {
                            _roomChest = res.updatedContainer;
                            _character = res.updatedCharacter;
                            _recalculateStats();
                          });
                        },
                      ),
                  ],
                ),
                const Divider(),
                if (_roomChest.items.isEmpty)
                  const Text('Chest is empty.', style: TextStyle(fontStyle: FontStyle.italic)),
                ..._roomChest.items.map((lootItem) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(lootItem.displayName, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('Qty: ${lootItem.quantity}'),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Loot'),
                        onPressed: () {
                          HapticService.selectionTick(context);
                          final res = InventoryTransactionService.transferFromContainerToCharacter(
                            sourceContainer: _roomChest,
                            destinationCharacter: char,
                            instanceId: lootItem.instanceId,
                            quantity: 1,
                          );
                          setState(() {
                            _roomChest = res.updatedContainer;
                            _character = res.updatedCharacter;
                            _recalculateStats();
                          });
                        },
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
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
                    _tabController.animateTo(0);
                  });
                },
              ),
            ],
          ),
        ),
      );
    }
    final validation = LevelUpPipeline.validateMulticlass(char, _levelUpTargetClass);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advance Class or Multiclass',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _levelUpTargetClass,
                  decoration: const InputDecoration(
                    labelText: 'Target Class to Level Up',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'fighter', child: Text('Fighter (STR 13 or DEX 13)')),
                    DropdownMenuItem(value: 'wizard', child: Text('Wizard (INT 13)')),
                    DropdownMenuItem(value: 'rogue', child: Text('Rogue (DEX 13)')),
                    DropdownMenuItem(value: 'cleric', child: Text('Cleric (WIS 13)')),
                    DropdownMenuItem(value: 'paladin', child: Text('Paladin (STR 13 & CHA 13)')),
                    DropdownMenuItem(value: 'barbarian', child: Text('Barbarian (STR 13)')),
                    DropdownMenuItem(value: 'warlock', child: Text('Warlock (CHA 13)')),
                  ],
                  onChanged: (v) => setState(() => _levelUpTargetClass = v!),
                ),
                const SizedBox(height: 12),
                if (!validation.isValid)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(validation.errors.join('\n'),
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text('Hit Points Gain', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Fixed Average')),
                    ButtonSegment(value: false, label: Text('Manual Roll')),
                  ],
                  selected: {_levelUpUseAverage},
                  onSelectionChanged: (set) {
                    setState(() => _levelUpUseAverage = set.first);
                  },
                ),
                if (!_levelUpUseAverage) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Rolled Die Value: '),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _levelUpRolledHp,
                        items: List.generate(12, (i) => i + 1)
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                            .toList(),
                        onChanged: (v) => setState(() => _levelUpRolledHp = v!),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Ability Score Improvement or Feat', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Ability Score (+2 / +1+1)'),
                      selected: _levelUpIsAsi,
                      onSelected: (s) => setState(() => _levelUpIsAsi = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Tough Feat'),
                      selected: !_levelUpIsAsi,
                      onSelected: (s) => setState(() => _levelUpIsAsi = false),
                    ),
                  ],
                ),
                if (_levelUpIsAsi) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AbilityType>(
                          initialValue: _asiAbility1,
                          decoration: const InputDecoration(labelText: '+1 Score 1', border: OutlineInputBorder()),
                          items: AbilityType.values
                              .map((a) => DropdownMenuItem(value: a, child: Text(a.shortName)))
                              .toList(),
                          onChanged: (v) => setState(() => _asiAbility1 = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<AbilityType>(
                          initialValue: _asiAbility2,
                          decoration: const InputDecoration(labelText: '+1 Score 2', border: OutlineInputBorder()),
                          items: AbilityType.values
                              .map((a) => DropdownMenuItem(value: a, child: Text(a.shortName)))
                              .toList(),
                          onChanged: (v) => setState(() => _asiAbility2 = v!),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.upgrade),
                    label: const Text('APPLY LEVEL UP', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: validation.isValid
                        ? () {
                            HapticService.selectionTick(context);
                            _applyLevelUp();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _applyLevelUp() {
    final asiChoice = _levelUpIsAsi
        ? AsiOrFeatChoice.asi({
            _asiAbility1: 1,
            _asiAbility2: 1,
          })
        : const AsiOrFeatChoice.feat(EntityReference(
            refType: EntityType.feat,
            slug: 'tough',
            displayName: 'Tough',
          ));

    final request = LevelUpRequest(
      targetClassSlug: _levelUpTargetClass,
      targetClassDisplayName: _levelUpTargetClass.toUpperCase(),
      hpChoice: _levelUpUseAverage
          ? const HpProgressionChoice.average()
          : HpProgressionChoice.rolled(_levelUpRolledHp),
      asiOrFeat: asiChoice,
    );

    final char = _character;
    if (char == null) return;

    final updated = LevelUpPipeline.applyLevelUp(char, request, resolver: _resolver);
    _persistenceService.saveCharacter(updated).then((updatedRoster) {
      if (mounted) {
        setState(() {
          _characterRoster = updatedRoster;
          _character = updated;
          _isSelectorView = false;
          _recalculateStats();
          _currentHp = _computedStats?.maxHp ?? 10;
          _tabController.animateTo(0);
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updated.name} is now Level ${updated.totalLevel}!')),
    );
  }
}
