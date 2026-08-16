import 'package:flutter/material.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../screens/dice_roller_screen.dart';
import '../screens/dm_reference_screen.dart';
import '../screens/glyph_showcase_screen.dart';
import '../screens/minion_tool_screen.dart';
import '../services/haptic_service.dart';

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
          id: 'dm_screen',
          title: "DM's Screen & Rulebook",
          category: 'Core Utilities',
          badgeText: '2014 & 2024 Rules',
          badgeColor: Colors.amberAccent,
          icon: Icons.shield_outlined,
          accentColor: Colors.amberAccent,
          description:
              "Instant rules reference with 2014 RAW vs 2024 Revised switch, side-by-side comparison, conditions, DC tables, and quick roller.",
          keywords: [
            'dm',
            'dungeon master',
            'screen',
            'rules',
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
              MaterialPageRoute(builder: (_) => const DmReferenceScreen()),
            );
          },
        ),
        // Core Utilities
        // (Glyph Studio moved to bottom Art Tools category)

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
          id: 'horn_of_valhalla',
          title: 'Horn of Valhalla',
          category: 'Magic Item Rollers & Minions',
          badgeText: 'Magic Item',
          badgeColor: Colors.deepOrange,
          icon: Icons.sports_kabaddi,
          accentColor: Colors.deepOrange,
          description:
              'Blow the Silver, Brass, Bronze, or Iron Horn to roll random Berserker squads (2d4+2 up to 5d4+5).',
          keywords: ['horn', 'valhalla', 'berserker', 'silver', 'brass', 'bronze', 'iron', 'warrior', 'magic item'],
          onLaunch: (context) => _launchMinionTool(
            context,
            preset: ValhallaSummons.hornOfValhallaPreset,
            title: 'Horn of Valhalla Roller',
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
