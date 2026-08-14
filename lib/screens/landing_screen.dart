import 'package:flutter/material.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../services/haptic_service.dart';
import '../utils/pwa_helper.dart';
import '../widgets/dialogs/action_economy_dialog.dart';
import '../widgets/dialogs/condition_reference_dialog.dart';
import '../widgets/interactive/pressable_card.dart';
import '../widgets/legal_dialogs.dart';
import 'dice_roller_screen.dart';
import 'dm_screen_screen.dart';
import 'minion_tool_screen.dart';
import 'settings_screen.dart';

class _LandingToolItem {
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

  const _LandingToolItem({
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
    if (title.toLowerCase().contains(q)) return true;
    if (description.toLowerCase().contains(q)) return true;
    if (badgeText.toLowerCase().contains(q)) return true;
    if (category.toLowerCase().contains(q)) return true;
    for (final kw in keywords) {
      if (kw.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final List<_LandingToolItem> _tools;

  @override
  void initState() {
    super.initState();
    _tools = [
      // Core Utilities
      _LandingToolItem(
        id: 'dice_roller',
        title: 'Dice Roller & Party Rooms',
        category: 'Core Utilities',
        badgeText: 'Core Utility',
        badgeColor: Colors.cyanAccent,
        icon: Icons.casino,
        accentColor: Colors.cyanAccent,
        description:
            'Roll d4-d100, custom modifiers, advantage/disadvantage, JSON preset sharing, & live multiplayer party rooms.',
        keywords: ['dice', 'roller', 'd20', 'd6', 'party', 'room', 'advantage', 'disadvantage', 'pool', 'custom die', 'history'],
        onLaunch: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiceRollerScreen()),
          );
        },
      ),
      _LandingToolItem(
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
            MaterialPageRoute(builder: (_) => const DmScreenScreen()),
          );
        },
      ),

      // Spell Minion Companions
      _LandingToolItem(
        id: 'animate_objects',
        title: 'Animate Objects',
        category: 'Spell Minion Companions',
        badgeText: '5th-Level Spell',
        badgeColor: Colors.amber,
        icon: Icons.auto_awesome,
        accentColor: Colors.amber,
        description:
            'Track 10-18 object HP, point budget, and batch roll attack/damage for Tiny to Huge animated objects.',
        keywords: ['animate', 'objects', 'coins', 'silver', 'tiny', 'small', 'medium', 'large', 'huge', 'transmutation', '5th level'],
        onLaunch: (context) => _launchTool(
          context,
          preset: AnimateObjectsSummon.preset,
          title: 'Animate Objects Companion',
          defaultSlot: 5,
        ),
      ),
      _LandingToolItem(
        id: 'conjure_animals',
        title: 'Conjure Animals',
        category: 'Spell Minion Companions',
        badgeText: '3rd-Level Spell',
        badgeColor: Colors.lightGreenAccent,
        icon: Icons.pets,
        accentColor: Colors.lightGreenAccent,
        description:
            'Summon & batch roll for Wolves, Dire Wolves, Giant Hyenas, Giant Spiders, Apes, and Boars with Pack Tactics!',
        keywords: ['conjure', 'animals', 'wolves', 'wolf', 'dire wolf', 'hyena', 'spider', 'ape', 'boar', 'elk', 'pack tactics', 'beasts', 'druid', 'ranger', '3rd level'],
        onLaunch: (context) => _launchTool(
          context,
          preset: BeastSummons.conjureAnimalsPreset,
          title: 'Conjure Animals Squad Manager',
          defaultSlot: 3,
        ),
      ),
      _LandingToolItem(
        id: 'animate_dead',
        title: 'Animate Dead',
        category: 'Spell Minion Companions',
        badgeText: '3rd-Level Spell',
        badgeColor: Colors.redAccent,
        icon: Icons.dangerous,
        accentColor: Colors.redAccent,
        description:
            'Manage Skeleton archers and Zombie frontline HP, initiative, and batch ranged/melee attacks.',
        keywords: ['animate', 'dead', 'skeletons', 'skeleton', 'zombies', 'zombie', 'necromancy', 'wizard', 'cleric', 'undead', '3rd level'],
        onLaunch: (context) => _launchTool(
          context,
          preset: UndeadSummons.animateDeadPreset,
          title: 'Animate Dead Squad Tracker',
          defaultSlot: 3,
        ),
      ),
      _LandingToolItem(
        id: 'create_undead',
        title: 'Create Undead',
        category: 'Spell Minion Companions',
        badgeText: '6th-Level Spell',
        badgeColor: Colors.deepOrangeAccent,
        icon: Icons.coronavirus,
        accentColor: Colors.deepOrangeAccent,
        description:
            'Command higher-tier undead squads: Ghouls, Ghasts, Wights, and Mummies with full stat tracking.',
        keywords: ['create', 'undead', 'ghouls', 'ghoul', 'ghasts', 'ghast', 'wights', 'wight', 'mummies', 'mummy', 'necromancy', '6th level'],
        onLaunch: (context) => _launchTool(
          context,
          preset: UndeadSummons.createUndeadPreset,
          title: 'Create Undead Manager',
          defaultSlot: 6,
        ),
      ),
      _LandingToolItem(
        id: 'conjure_elementals',
        title: 'Conjure Elementals',
        category: 'Spell Minion Companions',
        badgeText: '4th-5th Level Spells',
        badgeColor: Colors.orangeAccent,
        icon: Icons.local_fire_department,
        accentColor: Colors.orangeAccent,
        description:
            'Summon Air, Earth, Fire, and Water Elementals, or swarm mephits and gargoyles with batch rolling.',
        keywords: ['conjure', 'elementals', 'elemental', 'fire', 'water', 'earth', 'air', 'mephit', 'gargoyle', 'conjuration', '4th level', '5th level'],
        onLaunch: (context) => _launchTool(
          context,
          preset: ElementalSummons.conjureElementalPreset,
          title: 'Conjure Elementals Companion',
          defaultSlot: 5,
        ),
      ),
      _LandingToolItem(
        id: 'giant_insect',
        title: 'Giant Insect',
        category: 'Spell Minion Companions',
        badgeText: '4th-Level Spell',
        badgeColor: Colors.lime,
        icon: Icons.bug_report,
        accentColor: Colors.lime,
        description:
            'Transform ordinary insects into Giant Centipedes or Giant Wasps with poisonous batch attacks.',
        keywords: ['giant', 'insect', 'centipede', 'wasp', 'spider', 'scorpion', 'druid', 'transmutation', 'poison', '4th level'],
        onLaunch: (context) => _launchTool(
          context,
          preset: InsectSummons.giantInsectPreset,
          title: 'Giant Insect Squad Tracker',
          defaultSlot: 4,
        ),
      ),

      // Magic Item Rollers
      _LandingToolItem(
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
        onLaunch: (context) => _launchTool(
          context,
          preset: BagOfTricksSummons.grayBagPreset,
          title: 'Gray Bag of Tricks Roller',
        ),
      ),
      _LandingToolItem(
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
        onLaunch: (context) => _launchTool(
          context,
          preset: BagOfTricksSummons.rustBagPreset,
          title: 'Rust Bag of Tricks Roller',
        ),
      ),
      _LandingToolItem(
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
        onLaunch: (context) => _launchTool(
          context,
          preset: BagOfTricksSummons.tanBagPreset,
          title: 'Tan Bag of Tricks Roller',
        ),
      ),
      _LandingToolItem(
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
        onLaunch: (context) => _launchTool(
          context,
          preset: ValhallaSummons.hornOfValhallaPreset,
          title: 'Horn of Valhalla Roller',
        ),
      ),
      _LandingToolItem(
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
        onLaunch: (context) => _launchTool(
          context,
          preset: FigurinesSummons.figurinesPreset,
          title: 'Figurines of Wondrous Power',
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearSearch() {
    HapticService.selectionTick(context);
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim();
    final isSearching = query.isNotEmpty;
    final searchResults = _tools.where((t) => t.matches(query)).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Row(
          children: [
            Semantics(
              label: 'DangerouslyNerdy Logo',
              image: true,
              child: Image.asset('assets/images/logo.png', width: 36, height: 36),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  'DangerouslyNerdy 5e Toolkit',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: Colors.amberAccent),
            tooltip: "DM's Screen & Rulebook (2014 / 2024)",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DmScreenScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            tooltip: 'Combat Action Economy Guide',
            onPressed: () => ActionEconomyDialog.show(context),
          ),
          IconButton(
            icon: Icon(Icons.medical_information_outlined, color: theme.colorScheme.secondary),
            tooltip: 'Status Effects & Conditions Guide',
            onPressed: () => ConditionReferenceDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Preferences & Theme Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.download_for_offline, color: theme.colorScheme.primary),
            tooltip: 'Install App',
            onPressed: PwaHelper.promptInstall,
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Semantics(
                                label: 'DangerouslyNerdy Dragon Logo',
                                image: true,
                                child: Image.asset('assets/images/logo.png', width: 68, height: 68),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Select a Tool',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose from the DangerouslyNerdy suite of dedicated 5th Edition (5e) compatible player tools designed for minion combat management, magic item rollers, dice math, and live party rooms.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // HIGH-CONTRAST SEARCH BAR
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSearching ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSearching ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
                      cursorColor: theme.colorScheme.primary,
                      decoration: InputDecoration(
                        hintText: 'Search tools, spells, summons (e.g. wolves, dice, undead, bag)...',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary, size: 22),
                        suffixIcon: isSearching
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
                                tooltip: 'Clear Search',
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (isSearching) ...[
                    // SEARCH RESULTS SECTION
                    _buildSectionHeader(
                      '🔍 SEARCH RESULTS (${searchResults.length})',
                      theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    if (searchResults.isNotEmpty)
                      _buildToolGrid(
                        context,
                        children: searchResults.map((tool) => _buildToolCardFromItem(context, tool)).toList(),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No tools found matching "$query"',
                              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try searching for spells, monsters, or dice keywords.',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear, size: 18),
                              label: const Text('Clear Search', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    // CATEGORY 1: GENERAL UTILITIES (CORE APP AT TOP)
                    _buildSectionHeader('🎲 CORE UTILITIES', theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Core Utilities')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 2: SPELL MINION COMPANIONS (ANIMATE OBJECTS & CONJURE SPELLS)
                    _buildSectionHeader('🔮 SPELL MINION COMPANIONS', theme.colorScheme.secondary),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Spell Minion Companions')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 3: MAGIC ITEMS & SUMMONING ARTIFACTS
                    _buildSectionHeader('📯 MAGIC ITEM ROLLERS & MINIONS', Colors.amberAccent),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Magic Item Rollers & Minions')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // FOOTER
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'DangerouslyNerdy 5e Toolkit • D&D 5e / SRD 5.1 Compatible Combat System',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () => LegalDialogs.showPrivacyPolicy(context),
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => LegalDialogs.showTermsOfService(context),
                              child: Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => LegalDialogs.showAttribution(context),
                              child: Text(
                                'Legal & SRD 5.1 Attribution',
                                style: TextStyle(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _launchTool(
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

  Widget _buildSectionHeader(String title, Color color) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildToolGrid(BuildContext context, {required List<Widget> children}) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 16)) / crossAxisCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildToolCardFromItem(BuildContext context, _LandingToolItem item) {
    return _buildToolCard(
      context,
      title: item.title,
      badgeText: item.badgeText,
      badgeColor: item.badgeColor,
      icon: item.icon,
      accentColor: item.accentColor,
      description: item.description,
      onTap: () {
        HapticService.selectionTick(context);
        item.onLaunch(context);
      },
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color accentColor,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return PressableCard(
      onTap: onTap,
      semanticLabel: '$title, $badgeText. $description. Tap to launch tool.',
      excludeChildSemantics: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Launch Tool',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: accentColor, size: 14),
            ],
          ),
        ],
      ),
    );
  }
}
