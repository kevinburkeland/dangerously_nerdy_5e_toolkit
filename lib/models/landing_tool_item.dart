import 'package:flutter/material.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../screens/arena_simulator_screen.dart';
import '../screens/character_builder_screen.dart';
import '../screens/dice_roller_screen.dart';
import '../screens/dm_reference_screen.dart';
import '../screens/dpr_calculator_screen.dart';
import '../screens/glyph_showcase_screen.dart';
import '../screens/homebrew_studio_screen.dart';
import '../screens/item_compendium_screen.dart';
import '../screens/minion_tool_screen.dart';
import '../screens/monster_codex_screen.dart';
import '../screens/party_room_screen.dart';
import '../screens/spellbook_screen.dart';
import '../screens/table_index_screen.dart';
import '../services/haptic_service.dart';
import '../services/party/campaign_registry_service.dart';
import '../widgets/party/campaign_dialogs.dart';

/// Data class representing a launcher tool or companion card on the Landing Screen.
class LandingToolItem {
  final String id;
  final String title;
  final String category;
  final String badgeText;
  final Color badgeColor;
  final IconData icon;
  final Color accentColor;
  final String description;
  final List<String> keywords;
  final void Function(BuildContext context) onLaunch;

  const LandingToolItem({
    required this.id,
    required this.title,
    required this.category,
    required this.badgeText,
    required this.badgeColor,
    required this.icon,
    required this.accentColor,
    required this.description,
    required this.keywords,
    required this.onLaunch,
  });

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        badgeText.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        keywords.any((kw) => kw.toLowerCase().contains(q));
  }

  Color getLegibleAccent(bool isDark) {
    if (isDark) return accentColor;
    if (accentColor == Colors.cyanAccent) return const Color(0xFF0369A1);
    if (accentColor == Colors.amberAccent || accentColor == Colors.amber) return const Color(0xFFB45309);
    if (accentColor == Colors.purpleAccent || accentColor == Colors.purple || accentColor == const Color(0xFFC084FC)) return const Color(0xFF7E22CE);
    if (accentColor == Colors.orangeAccent || accentColor == Colors.orange) return const Color(0xFFC2410C);
    if (accentColor == Colors.greenAccent || accentColor == Colors.green) return const Color(0xFF047857);
    if (accentColor == Colors.redAccent || accentColor == Colors.red) return const Color(0xFFB91C1C);
    return accentColor;
  }

  Color getLegibleBadge(bool isDark) {
    if (isDark) return badgeColor;
    if (badgeColor == Colors.cyanAccent) return const Color(0xFF0369A1);
    if (badgeColor == Colors.amberAccent || badgeColor == Colors.amber) return const Color(0xFFB45309);
    if (badgeColor == Colors.purpleAccent || badgeColor == Colors.purple || badgeColor == const Color(0xFFC084FC)) return const Color(0xFF7E22CE);
    if (badgeColor == Colors.orangeAccent || badgeColor == Colors.orange) return const Color(0xFFC2410C);
    if (badgeColor == Colors.greenAccent || badgeColor == Colors.green) return const Color(0xFF047857);
    if (badgeColor == Colors.redAccent || badgeColor == Colors.red) return const Color(0xFFB91C1C);
    return badgeColor;
  }
}

/// Centralized registry providing all default tools and summon companions for the toolkit.
class LandingToolRegistry {
  LandingToolRegistry._();

  static void _launchMinionTool(
    BuildContext context, {
    required SummonPreset preset,
    required String title,
    int defaultSlot = 5,
  }) {
    HapticService.selectionTick(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MinionToolScreen(
          preset: preset,
          customTitle: title,
          defaultSpellLevel: defaultSlot,
        ),
      ),
    );
  }

  static List<LandingToolItem> get defaultTools => [
        // Core Utilities
        LandingToolItem(
          id: 'character_builder',
          title: 'Character Generator & Live Sheet',
          category: 'Core Utilities',
          badgeText: '2014 & 2024 SRD',
          badgeColor: Colors.cyanAccent,
          icon: Icons.person_add_alt_1,
          accentColor: Colors.cyanAccent,
          description:
              'Interactive 5e character creator with Point Buy / Standard Array, reactive AC & HP calculation, dynamic equipment attunement, room loot transfer, and multiclassing level-up studio.',
          keywords: [
            'character',
            'builder',
            'creator',
            'sheet',
            'generator',
            'multiclass',
            'level up',
            'point buy',
            'stats',
            'inventory',
            'attunement',
            '2024',
            '2014',
            'srd'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CharacterBuilderScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'party_room_vault',
          title: 'Party Room & Shared Vault',
          category: 'Core Utilities',
          badgeText: 'Party Hub',
          badgeColor: Colors.amberAccent,
          icon: Icons.shield_moon,
          accentColor: Colors.amberAccent,
          description:
              'Multi-campaign shared loot tracker, high-contrast party purse, share calculator, and live dice broadcast room.',
          keywords: [
            'party',
            'room',
            'vault',
            'loot',
            'campaign',
            'gold',
            'purse',
            'coins',
            'dice',
            'hoard',
            'tracker',
            'dm'
          ],
          onLaunch: (context) {
            final active = CampaignRegistryService().activeCampaign;
            if (active != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PartyRoomScreen(roomCode: active.roomCode),
                ),
              );
            } else {
              JoinCampaignDialog.show(
                context,
                onJoined: (code) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PartyRoomScreen(roomCode: code),
                    ),
                  );
                },
              );
            }
          },
        ),
        LandingToolItem(
          id: 'dice_roller',
          title: 'Dice Roller & Party Rooms',
          category: 'Core Utilities',
          badgeText: 'Core Utility',
          badgeColor: Colors.cyanAccent,
          icon: Icons.casino,
          accentColor: Colors.cyanAccent,
          description:
              'Roll d4-d100, custom modifiers, advantage/disadvantage, JSON preset sharing, & live multiplayer party rooms.',
          keywords: [
            'dice',
            'roller',
            'd20',
            'd6',
            'party',
            'room',
            'advantage',
            'disadvantage',
            'pool',
            'custom die',
            'history'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiceRollerScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'dpr_calculator',
          title: 'DPR Calculator & Graph',
          category: 'Tools for Nerds',
          badgeText: 'Combat Math & DPS',
          badgeColor: Colors.purpleAccent,
          icon: Icons.auto_graph,
          accentColor: Colors.cyanAccent,
          description:
              'Damage Per Round (DPR) analyzer with interactive animated graphs, accuracy curves, GWM & Sharpshooter break-even AC, and damage breakdown.',
          keywords: [
            'dpr',
            'dps',
            'calculator',
            'damage',
            'gwm',
            'great weapon master',
            'sharpshooter',
            'graph',
            'ac',
            'break-even',
            'accuracy',
            'math',
            'combat',
            'nerd',
            'theorycraft'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DprCalculatorScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'monster_arena',
          title: 'Monster Fighting Arena',
          category: 'Tools for Nerds',
          badgeText: 'Pit Fight Simulator',
          badgeColor: const Color(0xFFC084FC),
          icon: Icons.sports_kabaddi,
          accentColor: const Color(0xFFC084FC),
          description:
              'Pit X monsters against Y monsters in automated turn-by-turn 5e combat. Watch attacks, multiattacks, recharges, and dice rolls play out or skip to the end with Monte Carlo win odds.',
          keywords: [
            'arena',
            'monster',
            'fight',
            'pit fight',
            'combat',
            'simulator',
            'simulation',
            'monte carlo',
            'probability',
            'odds',
            'dps',
            'vs',
            'versus',
            't-rex',
            'dragon',
            'theorycraft',
            'nerd'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArenaSimulatorScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'homebrew_studio',
          title: 'Homebrew Studio & Importer',
          category: 'Tools for Nerds',
          badgeText: 'Builders & JSON',
          badgeColor: Colors.pinkAccent,
          icon: Icons.dashboard_customize_outlined,
          accentColor: Colors.pinkAccent,
          description:
              'Craft custom spells, monsters, and magic items with interactive builders, or import community JSON compendium packs (classes, subclasses, races, feats, backgrounds, spells, monsters, items, tables).',
          keywords: [
            'homebrew',
            'custom',
            'builder',
            'importer',
            'json',
            'class',
            'classes',
            'subclass',
            'subclasses',
            'race',
            'races',
            'species',
            'feat',
            'feats',
            'background',
            'backgrounds',
            'spell builder',
            'monster builder',
            'item builder',
            'compendium',
            'pack',
            'create',
            'nerd',
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomebrewStudioScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'rules_compendium',
          title: "Rules Compendium",
          category: 'Core Utilities',
          badgeText: '2014 & 2024 Rules',
          badgeColor: Colors.amberAccent,
          icon: Icons.menu_book_rounded,
          accentColor: Colors.amberAccent,
          description:
              "Instant rules reference engine with 2014 RAW vs 2024 Revised comparative diffs, tokenized search, interactive math calculators, conditions, and DC tables.",
          keywords: [
            'rules',
            'compendium',
            'rules compendium',
            'srd',
            'dm',
            'dungeon master',
            'screen',
            'dm screen',
            '2024',
            '2014',
            'conditions',
            'actions',
            'dc',
            'cover',
            'exhaustion',
            'grapple',
            'potion',
            'rest',
            'concentration',
            'travel',
            'revised'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RulesCompendiumScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'srd_spellbook',
          title: 'Spellbook Companion',
          category: 'Core Utilities',
          badgeText: '2014 vs 2024',
          badgeColor: Colors.purpleAccent,
          icon: Icons.menu_book_rounded,
          accentColor: Colors.purpleAccent,
          description:
              'Search SRD cantrips & spells, compare 2014 RAW vs 2024 revisions side-by-side, filter by class/school, and manage your Personal Spellbook.',
          keywords: [
            'spell',
            'spellbook',
            'cantrip',
            'magic',
            'slots',
            '2024',
            '2014',
            'diff',
            'personal',
            'pinned',
            'prepared',
            'wizard',
            'cleric',
            'sorcerer',
            'druid',
            'paladin',
            'ranger',
            'warlock',
            'bard',
            'fireball',
            'cure wounds',
            'healing'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SpellbookScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'monster_codex',
          title: 'Monster Codex',
          category: 'Core Utilities',
          badgeText: 'SRD Stat Blocks',
          badgeColor: Colors.greenAccent,
          icon: Icons.pets,
          accentColor: Colors.greenAccent,
          description:
              'Browse SRD creature stat blocks from summon and item companions, filter by type/size, and open full monster details.',
          keywords: [
            'monster',
            'codex',
            'stat block',
            'creature',
            'beast',
            'undead',
            'elemental',
            'construct',
            'srd',
            'ac',
            'hp',
            'cr'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MonsterCodexScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'item_compendium',
          title: 'Item Codex',
          category: 'Core Utilities',
          badgeText: 'SRD Magic & Loot',
          badgeColor: Colors.tealAccent,
          icon: Icons.auto_fix_high,
          accentColor: Colors.tealAccent,
          description:
              'Browse SRD magic items, gemstones, art objects, trinkets, and adventuring gear by category and rarity, filter by attunement, view glyphs, and bookmark favorites to your Reliquary.',
          keywords: [
            'item',
            'items',
            'codex',
            'magic',
            'compendium',
            'loot',
            'gem',
            'gems',
            'gemstones',
            'art',
            'art objects',
            'trinket',
            'trinkets',
            'weapon',
            'armor',
            'potion',
            'ring',
            'rod',
            'scroll',
            'staff',
            'wand',
            'wondrous',
            'attunement',
            'rarity',
            'flame tongue',
            'bag of holding',
            'reliquary',
            'legendary',
            'rare',
            'uncommon',
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ItemCompendiumScreen()),
            );
          },
        ),
        LandingToolItem(
          id: 'table_index',
          title: 'Table Index',
          category: 'Core Utilities',
          badgeText: 'SRD Rollables & Loot',
          badgeColor: const Color(0xFFF59E0B),
          icon: Icons.table_chart,
          accentColor: const Color(0xFFF59E0B),
          description:
              'Browse and roll on all 5e SRD tables: Treasure Hoards, Magic Item Tables A-I, Gemstones, Art Objects, 100 Trinkets, Wild Magic Surge, Madness, and Party Share Calculator.',
          keywords: [
            'table',
            'tables',
            'index',
            'loot',
            'treasure',
            'hoard',
            'party share',
            'share',
            'coins',
            'gems',
            'gemstones',
            'art',
            'trinket',
            'trinkets',
            'wild magic',
            'surge',
            'madness',
            'confusion',
            'reincarnate',
            'magic items',
            'roller',
            'oracle',
            'generator',
            'gold',
            'appraisal',
            'srd'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TableIndexScreen()),
            );
          },
        ),
        // Spell Minion Companions
        LandingToolItem(
          id: 'animate_objects',
          title: 'Animate Objects',
          category: 'Spell Minion Companions',
          badgeText: '5th-Level Spell',
          badgeColor: Colors.amber,
          icon: Icons.auto_awesome,
          accentColor: Colors.amber,
          description:
              'Track 10-18 object HP, point budget, and batch roll attack/damage for Tiny to Huge animated objects.',
          keywords: [
            'animate',
            'objects',
            'coins',
            'silver',
            'tiny',
            'small',
            'medium',
            'large',
            'huge',
            'transmutation',
            '5th level'
          ],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: AnimateObjectsSummon.preset,
            title: 'Animate Objects Companion',
            defaultSlot: 5,
          ),
        ),
        LandingToolItem(
          id: 'conjure_animals',
          title: 'Conjure Animals',
          category: 'Spell Minion Companions',
          badgeText: '3rd-Level Spell',
          badgeColor: Colors.lightGreenAccent,
          icon: Icons.pets,
          accentColor: Colors.lightGreenAccent,
          description:
              'Summon & batch roll for Wolves, Dire Wolves, Giant Hyenas, Giant Spiders, Apes, and Boars with Pack Tactics!',
          keywords: [
            'conjure',
            'animals',
            'wolves',
            'wolf',
            'dire wolf',
            'hyena',
            'spider',
            'ape',
            'boar',
            'elk',
            'pack tactics',
            'beasts',
            'druid',
            'ranger',
            '3rd level'
          ],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: BeastSummons.conjureAnimalsPreset,
            title: 'Conjure Animals Squad Manager',
            defaultSlot: 3,
          ),
        ),
        LandingToolItem(
          id: 'animate_dead',
          title: 'Animate Dead',
          category: 'Spell Minion Companions',
          badgeText: '3rd-Level Spell',
          badgeColor: Colors.redAccent,
          icon: Icons.dangerous,
          accentColor: Colors.redAccent,
          description:
              'Manage Skeleton archers and Zombie frontline HP, initiative, and batch ranged/melee attacks.',
          keywords: [
            'animate',
            'dead',
            'skeletons',
            'skeleton',
            'zombies',
            'zombie',
            'necromancy',
            'wizard',
            'cleric',
            'undead',
            '3rd level'
          ],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: UndeadSummons.animateDeadPreset,
            title: 'Animate Dead Squad Tracker',
            defaultSlot: 3,
          ),
        ),
        LandingToolItem(
          id: 'create_undead',
          title: 'Create Undead',
          category: 'Spell Minion Companions',
          badgeText: '6th-Level Spell',
          badgeColor: Colors.deepOrangeAccent,
          icon: Icons.coronavirus,
          accentColor: Colors.deepOrangeAccent,
          description:
              'Command higher-tier undead squads: Ghouls, Ghasts, Wights, and Mummies with full stat tracking.',
          keywords: [
            'create',
            'undead',
            'ghouls',
            'ghoul',
            'ghasts',
            'ghast',
            'wights',
            'wight',
            'mummies',
            'mummy',
            'necromancy',
            '6th level'
          ],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: UndeadSummons.createUndeadPreset,
            title: 'Create Undead Manager',
            defaultSlot: 6,
          ),
        ),
        LandingToolItem(
          id: 'conjure_elementals',
          title: 'Conjure Elementals',
          category: 'Spell Minion Companions',
          badgeText: '4th-5th Level Spells',
          badgeColor: Colors.orangeAccent,
          icon: Icons.local_fire_department,
          accentColor: Colors.orangeAccent,
          description:
              'Summon Air, Earth, Fire, and Water Elementals, or swarm mephits and gargoyles with batch rolling.',
          keywords: [
            'conjure',
            'elementals',
            'elemental',
            'fire',
            'water',
            'earth',
            'air',
            'mephit',
            'gargoyle',
            'conjuration',
            '4th level',
            '5th level'
          ],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: ElementalSummons.conjureElementalPreset,
            title: 'Conjure Elementals Companion',
            defaultSlot: 5,
          ),
        ),
        LandingToolItem(
          id: 'giant_insect',
          title: 'Giant Insect',
          category: 'Spell Minion Companions',
          badgeText: '4th-Level Spell',
          badgeColor: Colors.lime,
          icon: Icons.bug_report,
          accentColor: Colors.lime,
          description:
              'Transform ordinary insects into Giant Centipedes or Giant Wasps with poisonous batch attacks.',
          keywords: [
            'giant',
            'insect',
            'centipede',
            'wasp',
            'spider',
            'scorpion',
            'druid',
            'transmutation',
            'poison',
            '4th level'
          ],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: InsectSummons.giantInsectPreset,
            title: 'Giant Insect Squad Tracker',
            defaultSlot: 4,
          ),
        ),

        // Magic Item Rollers
        LandingToolItem(
          id: 'gray_bag',
          title: 'Gray Bag of Tricks',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Magic Item',
          badgeColor: Colors.blueGrey,
          icon: Icons.casino_outlined,
          accentColor: Colors.blueGrey,
          description:
              'Roll d8 on the Gray Bag table: Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, or Giant Elk!',
          keywords: ['gray', 'bag', 'tricks', 'weasel', 'rat', 'badger', 'boar', 'panther', 'elk', 'magic item'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: BagOfTricksSummons.grayBagPreset,
            title: 'Gray Bag of Tricks Roller',
          ),
        ),
        LandingToolItem(
          id: 'rust_bag',
          title: 'Rust Bag of Tricks',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Magic Item',
          badgeColor: Colors.deepOrangeAccent,
          icon: Icons.casino_outlined,
          accentColor: Colors.deepOrangeAccent,
          description:
              'Roll d8 on the Rust Bag table: Rat, Owl, Mastiff, Goat, Giant Goat, Giant Boar, Lion, or Brown Bear!',
          keywords: ['rust', 'bag', 'tricks', 'rat', 'owl', 'mastiff', 'goat', 'lion', 'bear', 'magic item'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: BagOfTricksSummons.rustBagPreset,
            title: 'Rust Bag of Tricks Roller',
          ),
        ),
        LandingToolItem(
          id: 'tan_bag',
          title: 'Tan Bag of Tricks',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Magic Item',
          badgeColor: Colors.amber,
          icon: Icons.casino_outlined,
          accentColor: Colors.amber,
          description:
              'Roll d8 on the Tan Bag table: Jackal, Ape, Baboon, Axe Beak, Black Bear, Giant Weasel, Giant Hyena, or Tiger!',
          keywords: ['tan', 'bag', 'tricks', 'jackal', 'ape', 'baboon', 'axe beak', 'bear', 'tiger', 'hyena', 'magic item'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: BagOfTricksSummons.tanBagPreset,
            title: 'Tan Bag of Tricks Roller',
          ),
        ),
        LandingToolItem(
          id: 'horn_of_valhalla_silver',
          title: 'Silver Horn of Valhalla',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Rare',
          badgeColor: const Color(0xFF94A3B8),
          icon: Icons.sports_kabaddi,
          accentColor: const Color(0xFFCBD5E1),
          description:
              'Blow the Silver Horn to summon a squad of 2d4 + 2 heroic Berserkers for 1 hour.',
          keywords: ['silver', 'horn', 'valhalla', 'berserker', 'warrior', 'magic item', '2d4+2'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: ValhallaSummons.silverHornPreset,
            title: 'Silver Horn of Valhalla Roller',
          ),
        ),
        LandingToolItem(
          id: 'horn_of_valhalla_brass',
          title: 'Brass Horn of Valhalla',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Rare',
          badgeColor: const Color(0xFFF59E0B),
          icon: Icons.sports_kabaddi,
          accentColor: const Color(0xFFFBBF24),
          description:
              'Blow the Brass Horn to summon a squad of 3d4 + 3 heroic Berserkers for 1 hour.',
          keywords: ['brass', 'horn', 'valhalla', 'berserker', 'warrior', 'magic item', '3d4+3'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: ValhallaSummons.brassHornPreset,
            title: 'Brass Horn of Valhalla Roller',
          ),
        ),
        LandingToolItem(
          id: 'horn_of_valhalla_bronze',
          title: 'Bronze Horn of Valhalla',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Very Rare',
          badgeColor: const Color(0xFFD97706),
          icon: Icons.sports_kabaddi,
          accentColor: const Color(0xFFF59E0B),
          description:
              'Blow the Bronze Horn to summon a squad of 4d4 + 4 heroic Berserkers for 1 hour.',
          keywords: ['bronze', 'horn', 'valhalla', 'berserker', 'warrior', 'magic item', '4d4+4'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: ValhallaSummons.bronzeHornPreset,
            title: 'Bronze Horn of Valhalla Roller',
          ),
        ),
        LandingToolItem(
          id: 'horn_of_valhalla_iron',
          title: 'Iron Horn of Valhalla',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Legendary',
          badgeColor: const Color(0xFFEF4444),
          icon: Icons.sports_kabaddi,
          accentColor: const Color(0xFFF87171),
          description:
              'Blow the Iron Horn to summon a massive vanguard of 5d4 + 5 heroic Berserkers for 1 hour.',
          keywords: ['iron', 'horn', 'valhalla', 'berserker', 'warrior', 'magic item', '5d4+5'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: ValhallaSummons.ironHornPreset,
            title: 'Iron Horn of Valhalla Roller',
          ),
        ),
        LandingToolItem(
          id: 'figurines_of_wondrous_power',
          title: 'Figurines of Wondrous Power',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Magic Item',
          badgeColor: Colors.tealAccent,
          icon: Icons.token,
          accentColor: Colors.tealAccent,
          description:
              'Animate Bronze Griffon, Onyx Dog, or Marble Elephant statblocks with quick batch attack rolling.',
          keywords: ['figurines', 'wondrous', 'power', 'griffon', 'dog', 'elephant', 'magic item', 'statblock'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: FigurinesSummons.figurinesPreset,
            title: 'Figurines of Wondrous Power',
          ),
        ),

        // Art & Design Tools (Moved to bottom section)
        LandingToolItem(
          id: 'glyph_studio',
          title: 'D&D Techno-Rune Glyph Studio & Codex',
          category: 'Art & Design Tools',
          badgeText: 'Art Studio',
          badgeColor: const Color(0xFFA855F7),
          icon: Icons.auto_awesome,
          accentColor: const Color(0xFFC084FC),
          description:
              'Interactive Custom Glyph Builder, Full Style Guide Codex, Spellbook Schematics, & Minion Matrix with dynamic damage trait rings.',
          keywords: [
            'glyph',
            'icons',
            'spells',
            'schools',
            'monsters',
            'creatures',
            'runes',
            'builder',
            'style guide',
            'vector',
            'art',
            'custom',
            'wireframe',
            'hud'
          ],
          onLaunch: (context) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlyphShowcaseScreen()),
            );
          },
        ),
      ];
}
