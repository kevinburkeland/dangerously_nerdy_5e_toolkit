import 'package:flutter/material.dart';
import '../models/domain/core_types.dart';
import '../models/domain/character_models.dart';
import '../models/domain/entity_reference.dart';
import '../models/domain/loot_models.dart';
import '../models/domain/spell_monster_equipment.dart';
import '../models/party/party_purse.dart';
import '../services/haptic_service.dart';
import '../services/repository/layered_priority_repository.dart';
import '../services/repository/reference_resolver.dart';
import '../services/rules/character_factory.dart';
import '../services/rules/character_stat_calculator.dart';
import '../services/rules/inventory_transaction_service.dart';
import '../services/rules/level_up_pipeline.dart';
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

  // Active Character
  late Character _character;
  late ComputedCharacterStats _computedStats;

  // Sample Room Loot Container
  late LootContainer _roomChest;

  // Generator Wizard State
  RulesetVersion _selectedRuleset = RulesetVersion.v2024;
  final TextEditingController _nameController =
      TextEditingController(text: 'Valeros the Bold');
  String _selectedSpecies = 'human';
  String _selectedClass = 'fighter';
  String _selectedBackground = 'soldier';
  AbilityScores _wizardBaseScores = const AbilityScores.standardArray();
  bool _usePointBuy = false;

  // Level Up Wizard State
  String _levelUpTargetClass = 'fighter';
  bool _levelUpUseAverage = true;
  int _levelUpRolledHp = 6;
  bool _levelUpIsAsi = true;
  AbilityType _asiAbility1 = AbilityType.strength;
  AbilityType _asiAbility2 = AbilityType.constitution;

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

    // Register baseline SRD items
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
      descriptionMarkdown: 'Versatile 1d8 slashing.',
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
      id: const EntityId(slug: 'ring-of-protection', ruleset: RulesetVersion.v2024),
      name: 'Ring of Protection',
      itemType: 'Ring',
      rarity: 'Rare',
      requiresAttunement: true,
      descriptionMarkdown: '+1 AC and Saving Throws when attuned.',
      customProperties: const {'acBonus': 1},
    ));

    baseLayer.registerEntity(EquipmentItem(
      id: const EntityId(
          slug: 'gauntlets-of-ogre-power', ruleset: RulesetVersion.v2024),
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
      id: const EntityId(
          slug: 'potion-of-healing', ruleset: RulesetVersion.v2024),
      name: 'Potion of Healing',
      itemType: 'Potion',
      rarity: 'Common',
      requiresAttunement: false,
      descriptionMarkdown: 'Heals 2d4 + 2 HP.',
      customProperties: const {},
    ));

    _repository.addLayer(baseLayer);
  }

  void _initDefaultCharacter() {
    const request = CharacterCreationRequest(
      characterName: 'Valeros the Bold',
      ruleset: RulesetVersion.v2024,
      speciesRef: EntityReference(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      backgroundRef: EntityReference(
        refType: EntityType.background,
        slug: 'soldier',
        displayName: 'Soldier',
      ),
      startingClassSlug: 'fighter',
      startingClassDisplayName: 'Fighter',
      startingClassHitDie: 'd10',
      baseScores: AbilityScores.standardArray(),
      bonusScores: AbilityScores(strength: 2, constitution: 1),
      savingThrowProficiencies: {
        AbilityType.strength,
        AbilityType.constitution
      },
      skillProficiencies: {
        SkillType.athletics: SkillProficiencyLevel.proficient,
        SkillType.intimidation: SkillProficiencyLevel.proficient,
        SkillType.perception: SkillProficiencyLevel.proficient,
      },
      originFeats: [
        EntityReference(
          refType: EntityType.feat,
          slug: 'savage-attacker',
          displayName: 'Savage Attacker',
        ),
      ],
      startingEquipment: [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'chain-mail',
            displayName: 'Chain Mail',
          ),
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'longsword',
            displayName: 'Longsword',
          ),
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'shield',
            displayName: 'Shield',
          ),
          equipImmediately: true,
          defaultSlot: EquipmentSlot.shield,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'ring-of-protection',
            displayName: 'Ring of Protection',
          ),
          equipImmediately: true,
          defaultSlot: EquipmentSlot.ring1,
          requiresAttunement: true,
        ),
      ],
      startingPurse: PartyPurse(gp: 25, sp: 40),
    );

    _character = CharacterFactory.createLevel1Character(request);
    // Attune the Ring of Protection by default
    _character = InventoryTransactionService.attuneItem(
        _character, _character.inventory.last.instanceId, true);
    _recalculateStats();
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
    setState(() {
      _computedStats = CharacterStatCalculator.compute(_character, _resolver);
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.person_add_alt_1, color: Colors.cyanAccent),
            const SizedBox(width: 10),
            Text(_character.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Live Sheet'),
            Tab(icon: Icon(Icons.auto_awesome), text: 'Generator'),
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
                _buildGeneratorTab(theme),
                _buildInventoryTab(theme),
                _buildLevelUpTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 1: LIVE SHEET & REACTIVE STATS
  // --------------------------------------------------------------------------
  Widget _buildLiveSheetTab(ThemeData theme) {
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _character.name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Level ${_character.totalLevel} ${_character.progression.classes.map((c) => "${c.classRef.displayName} ${c.level}").join(" / ")} • ${_character.speciesRef.displayName}',
                          style: TextStyle(color: Colors.cyanAccent.shade100),
                        ),
                      ],
                    ),
                    Chip(
                      backgroundColor: Colors.cyan.shade900,
                      label: Text(
                        _character.ruleset.name.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white24),
                // Core Quick Vitals
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatPill('ARMOR CLASS', '${_computedStats.armorClass}',
                        Colors.amberAccent, Icons.shield),
                    _buildStatPill('MAX HP', '${_computedStats.maxHp}',
                        Colors.redAccent, Icons.favorite),
                    _buildStatPill(
                        'PROF BONUS',
                        '+${_computedStats.proficiencyBonus}',
                        Colors.cyanAccent,
                        Icons.star),
                    _buildStatPill(
                        'SPEED',
                        '${_computedStats.speedFeet} ft',
                        Colors.greenAccent,
                        Icons.directions_run),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'AC Formula: ${_computedStats.armorClassBreakdown}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Unresolved Warning Chips (if any)
        if (_computedStats.unresolvedReferences.isNotEmpty)
          Card(
            color: Colors.amber.shade900.withValues(alpha: 0.4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                      SizedBox(width: 8),
                      Text(
                        'Unresolved Reference Stubs',
                        style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _computedStats.unresolvedReferences
                        .map((u) => Chip(
                              backgroundColor: Colors.red.shade900,
                              label: Text(u.name,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Ability Scores Row
        Text('ABILITY SCORES & MODIFIERS',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: AbilityType.values.map((ab) {
            final score = _computedStats.effectiveScores.getScore(ab);
            final mod = _computedStats.abilityModifiers[ab]!;
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
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(modStr,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent)),
                    Text('$score',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Attack Profiles
        Text('ATTACK PROFILES & WEAPONS',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        ..._computedStats.attackProfiles.map((atk) => Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                leading: const Icon(Icons.colorize, color: Colors.redAccent),
                title: Text(atk.weaponName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(
                    'To Hit: ${atk.attackBonusString} • Damage: ${atk.damageFormula} ${atk.damageType.name}',
                    style: const TextStyle(color: Colors.white70)),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade700,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.casino, size: 16),
                  label: const Text('Roll'),
                  onPressed: () {
                    HapticService.selectionTick(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Rolled ${atk.weaponName}: Attack ${atk.attackBonusString}, Damage ${atk.damageFormula}'),
                    ));
                  },
                ),
              ),
            )),

        const SizedBox(height: 16),

        // Passive Skills & Passives
        Text('PASSIVE SENSES & SKILLS',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildPassiveBadge('Passive Perception',
                _computedStats.passivePerception, Colors.cyanAccent),
            _buildPassiveBadge('Passive Investigation',
                _computedStats.passiveInvestigation, Colors.amberAccent),
            _buildPassiveBadge('Passive Insight',
                _computedStats.passiveInsight, Colors.purpleAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildStatPill(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white60)),
      ],
    );
  }

  Widget _buildPassiveBadge(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 2: CHARACTER CREATION WIZARD
  // --------------------------------------------------------------------------
  Widget _buildGeneratorTab(ThemeData theme) {
    final pointBuyCost =
        CharacterFactory.calculatePointBuyCost(_wizardBaseScores);
    final pointsRemaining = 27 - pointBuyCost;

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
                Text('Ruleset Standard',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<RulesetVersion>(
                  segments: const [
                    ButtonSegment(
                        value: RulesetVersion.v2024,
                        label: Text('2024 SRD (Revised)')),
                    ButtonSegment(
                        value: RulesetVersion.v2014,
                        label: Text('2014 SRD (Classic)')),
                  ],
                  selected: {_selectedRuleset},
                  onSelectionChanged: (set) {
                    setState(() => _selectedRuleset = set.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Character Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSpecies,
                  decoration: const InputDecoration(
                    labelText: 'Species / Race',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'human', child: Text('Human')),
                    DropdownMenuItem(value: 'elf', child: Text('Elf (High Elf)')),
                    DropdownMenuItem(value: 'dwarf', child: Text('Dwarf (Mountain Dwarf)')),
                    DropdownMenuItem(value: 'halfling', child: Text('Halfling')),
                    DropdownMenuItem(value: 'dragonborn', child: Text('Dragonborn')),
                    DropdownMenuItem(value: 'gnome', child: Text('Gnome')),
                    DropdownMenuItem(value: 'tiefling', child: Text('Tiefling')),
                  ],
                  onChanged: (v) => setState(() => _selectedSpecies = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedClass,
                  decoration: const InputDecoration(
                    labelText: 'Starting Class',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'fighter', child: Text('Fighter (d10)')),
                    DropdownMenuItem(value: 'wizard', child: Text('Wizard (d6)')),
                    DropdownMenuItem(value: 'rogue', child: Text('Rogue (d8)')),
                    DropdownMenuItem(value: 'cleric', child: Text('Cleric (d8)')),
                    DropdownMenuItem(value: 'barbarian', child: Text('Barbarian (d12)')),
                    DropdownMenuItem(value: 'paladin', child: Text('Paladin (d10)')),
                    DropdownMenuItem(value: 'ranger', child: Text('Ranger (d10)')),
                    DropdownMenuItem(value: 'warlock', child: Text('Warlock (d8)')),
                    DropdownMenuItem(value: 'bard', child: Text('Bard (d8)')),
                    DropdownMenuItem(value: 'sorcerer', child: Text('Sorcerer (d6)')),
                    DropdownMenuItem(value: 'monk', child: Text('Monk (d8)')),
                    DropdownMenuItem(value: 'druid', child: Text('Druid (d8)')),
                  ],
                  onChanged: (v) => setState(() => _selectedClass = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBackground,
                  decoration: const InputDecoration(
                    labelText: 'Background & Origin Package',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'soldier', child: Text('Soldier (Savage Attacker)')),
                    DropdownMenuItem(value: 'sage', child: Text('Sage (Magic Initiate)')),
                    DropdownMenuItem(value: 'acolyte', child: Text('Acolyte (Healer)')),
                    DropdownMenuItem(value: 'criminal', child: Text('Criminal (Alert)')),
                    DropdownMenuItem(value: 'entertainer', child: Text('Entertainer (Musician)')),
                  ],
                  onChanged: (v) => setState(() => _selectedBackground = v!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Ability Scores Allocation
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ability Scores (${_usePointBuy ? "Point Buy" : "Standard Array"})',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Switch(
                      value: _usePointBuy,
                      onChanged: (v) => setState(() => _usePointBuy = v),
                    ),
                  ],
                ),
                if (_usePointBuy)
                  Text('Points Remaining: $pointsRemaining / 27',
                      style: TextStyle(
                        color: pointsRemaining >= 0 ? Colors.greenAccent : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      )),
                const SizedBox(height: 12),
                ...AbilityType.values.map((ab) {
                  final score = _wizardBaseScores.getScore(ab);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ab.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          if (_usePointBuy)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: score > 8
                                  ? () {
                                      setState(() {
                                        _wizardBaseScores = _adjustScore(_wizardBaseScores, ab, -1);
                                      });
                                    }
                                  : null,
                            ),
                          Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (_usePointBuy)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: score < 15
                                  ? () {
                                      setState(() {
                                        _wizardBaseScores = _adjustScore(_wizardBaseScores, ab, 1);
                                      });
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.shade700,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('GENERATE LEVEL 1 CHARACTER',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      HapticService.selectionTick(context);
                      _generateCharacterFromWizard();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
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

  void _generateCharacterFromWizard() {
    final hitDie = switch (_selectedClass) {
      'barbarian' => 'd12',
      'fighter' || 'paladin' || 'ranger' => 'd10',
      'wizard' || 'sorcerer' => 'd6',
      _ => 'd8',
    };

    final request = CharacterCreationRequest(
      characterName: _nameController.text.trim().isEmpty ? 'Adventurer' : _nameController.text.trim(),
      ruleset: _selectedRuleset,
      speciesRef: EntityReference(
        refType: EntityType.species,
        slug: _selectedSpecies,
        displayName: _selectedSpecies.toUpperCase(),
      ),
      backgroundRef: EntityReference(
        refType: EntityType.background,
        slug: _selectedBackground,
        displayName: _selectedBackground.toUpperCase(),
      ),
      startingClassSlug: _selectedClass,
      startingClassDisplayName: _selectedClass.toUpperCase(),
      startingClassHitDie: hitDie,
      baseScores: _wizardBaseScores,
      bonusScores: const AbilityScores(strength: 2, constitution: 1),
      startingEquipment: const [
        StartingEquipmentItemRequest(
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'chain-mail',
            displayName: 'Chain Mail',
          ),
          equipImmediately: true,
          defaultSlot: EquipmentSlot.armor,
        ),
        StartingEquipmentItemRequest(
          itemRef: EntityReference(
            refType: EntityType.equipment,
            slug: 'longsword',
            displayName: 'Longsword',
          ),
          equipImmediately: true,
          defaultSlot: EquipmentSlot.mainHand,
        ),
      ],
      startingPurse: const PartyPurse(gp: 15),
    );

    setState(() {
      _character = CharacterFactory.createLevel1Character(request);
      _recalculateStats();
      _tabController.animateTo(0);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Created ${_character.name} successfully!')),
    );
  }

  // --------------------------------------------------------------------------
  // TAB 3: INVENTORY & ATOMICS LOOT TRANSFERS
  // --------------------------------------------------------------------------
  Widget _buildInventoryTab(ThemeData theme) {
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
                      'Attunement: ${_character.attunedItemCount} / ${_character.maxAttunementSlots} Slots',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Text('Gold: ${_character.purse.gp} GP',
                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Text('CHARACTER INVENTORY',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),

        ..._character.inventory.map((item) {
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
                              _character, item.instanceId, !item.isAttuned);
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
                          ? InventoryTransactionService.unequipItem(_character, item.instanceId)
                          : InventoryTransactionService.equipItem(_character, item.instanceId, EquipmentSlot.mainHand);
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
        // Room Chest Demo Section
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
                            destinationCharacter: _character,
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
                            destinationCharacter: _character,
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
    final validation = LevelUpPipeline.validateMulticlass(_character, _levelUpTargetClass);

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

    final updated = LevelUpPipeline.applyLevelUp(_character, request, resolver: _resolver);
    setState(() {
      _character = updated;
      _recalculateStats();
      _tabController.animateTo(0);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_character.name} is now Level ${_character.totalLevel}!')),
    );
  }
}
