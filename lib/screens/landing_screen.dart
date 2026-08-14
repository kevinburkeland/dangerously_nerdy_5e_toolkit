import 'package:flutter/material.dart';
import '../models/srd_summons.dart';
import '../utils/pwa_helper.dart';
import '../widgets/dialogs/action_economy_dialog.dart';
import '../widgets/legal_dialogs.dart';
import 'dice_roller_screen.dart';
import 'minion_tool_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14121E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        elevation: 4,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 36, height: 36),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'DangerouslyNerdy 5e Toolkit',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            tooltip: 'Combat Action Economy Guide',
            onPressed: () => ActionEconomyDialog.show(context),
          ),
          const IconButton(
            icon: Icon(Icons.download_for_offline, color: Colors.cyanAccent),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E2452), Color(0xFF1E1B2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
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
                                    color: Colors.cyanAccent.withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Image.asset('assets/images/logo.png', width: 68, height: 68),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Select a Tool',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose from the DangerouslyNerdy suite of dedicated 5th Edition (5e) compatible player tools designed for minion combat management, magic item rollers, dice math, and live party rooms.',
                          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // CATEGORY 1: GENERAL UTILITIES (CORE APP AT TOP)
                  _buildSectionHeader('🎲 CORE UTILITIES', Colors.cyanAccent),
                  const SizedBox(height: 12),
                  _buildToolGrid(
                    context,
                    children: [
                      _buildToolCard(
                        context,
                        title: 'Dice Roller & Party Rooms',
                        badgeText: 'Core Utility',
                        badgeColor: Colors.cyanAccent,
                        icon: Icons.casino,
                        accentColor: Colors.cyanAccent,
                        description:
                            'Roll d4-d100, custom modifiers, advantage/disadvantage, JSON preset sharing, & live multiplayer party rooms.',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DiceRollerScreen()),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // CATEGORY 2: SPELL MINION TOOLS
                  _buildSectionHeader('🔮 SPELL MINION COMPANIONS', Colors.amber),
                  const SizedBox(height: 12),
                  _buildToolGrid(
                    context,
                    children: [
                      _buildToolCard(
                        context,
                        title: 'Animate Objects',
                        badgeText: '5th-Level Spell',
                        badgeColor: Colors.amber,
                        icon: Icons.auto_awesome,
                        accentColor: Colors.amber,
                        description:
                            'Track 10-18 object HP, point budget, and batch roll attack/damage for Tiny to Huge animated objects.',
                        onTap: () => _launchTool(
                          context,
                          preset: AnimateObjectsSummon.preset,
                          title: 'Animate Objects Companion',
                          defaultSlot: 5,
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Conjure Animals',
                        badgeText: '3rd-Level Spell',
                        badgeColor: Colors.lightGreenAccent,
                        icon: Icons.pets,
                        accentColor: Colors.lightGreenAccent,
                        description:
                            'Summon & batch roll for Wolves, Dire Wolves, Giant Hyenas, Giant Spiders, Apes, and Boars with Pack Tactics!',
                        onTap: () => _launchTool(
                          context,
                          preset: BeastSummons.conjureAnimalsPreset,
                          title: 'Conjure Animals Squad Manager',
                          defaultSlot: 3,
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Animate Dead',
                        badgeText: '3rd-Level Spell',
                        badgeColor: Colors.redAccent,
                        icon: Icons.dangerous,
                        accentColor: Colors.redAccent,
                        description:
                            'Manage Skeleton archers and Zombie frontline HP, initiative, and batch ranged/melee attacks.',
                        onTap: () => _launchTool(
                          context,
                          preset: UndeadSummons.animateDeadPreset,
                          title: 'Animate Dead Squad Tracker',
                          defaultSlot: 3,
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Create Undead',
                        badgeText: '6th-Level Spell',
                        badgeColor: Colors.deepOrangeAccent,
                        icon: Icons.coronavirus,
                        accentColor: Colors.deepOrangeAccent,
                        description:
                            'Command higher-tier undead squads: Ghouls, Ghasts, Wights, and Mummies with full stat tracking.',
                        onTap: () => _launchTool(
                          context,
                          preset: UndeadSummons.createUndeadPreset,
                          title: 'Create Undead Manager',
                          defaultSlot: 6,
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Conjure Elementals',
                        badgeText: '4th-5th Level Spells',
                        badgeColor: Colors.orangeAccent,
                        icon: Icons.local_fire_department,
                        accentColor: Colors.orangeAccent,
                        description:
                            'Summon Air, Earth, Fire, and Water Elementals, or swarm mephits and gargoyles with batch rolling.',
                        onTap: () => _launchTool(
                          context,
                          preset: ElementalSummons.conjureElementalPreset,
                          title: 'Conjure Elementals Companion',
                          defaultSlot: 5,
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Giant Insect',
                        badgeText: '4th-Level Spell',
                        badgeColor: Colors.lime,
                        icon: Icons.bug_report,
                        accentColor: Colors.lime,
                        description:
                            'Transform ordinary insects into Giant Centipedes or Giant Wasps with poisonous batch attacks.',
                        onTap: () => _launchTool(
                          context,
                          preset: InsectSummons.giantInsectPreset,
                          title: 'Giant Insect Squad Tracker',
                          defaultSlot: 4,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // CATEGORY 3: MAGIC ITEM TOOLS
                  _buildSectionHeader('📯 MAGIC ITEM ROLLERS & MINIONS', Colors.purpleAccent),
                  const SizedBox(height: 12),
                  _buildToolGrid(
                    context,
                    children: [
                      _buildToolCard(
                        context,
                        title: 'Gray Bag of Tricks',
                        badgeText: 'Magic Item',
                        badgeColor: Colors.blueGrey,
                        icon: Icons.casino_outlined,
                        accentColor: Colors.blueGrey,
                        description:
                            'Roll d8 on the Gray Bag table: Weasel, Giant Rat, Badger, Boar, Panther, Giant Badger, Dire Wolf, or Giant Elk!',
                        onTap: () => _launchTool(
                          context,
                          preset: BagOfTricksSummons.grayBagPreset,
                          title: 'Gray Bag of Tricks Roller',
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Rust Bag of Tricks',
                        badgeText: 'Magic Item',
                        badgeColor: Colors.deepOrangeAccent,
                        icon: Icons.casino_outlined,
                        accentColor: Colors.deepOrangeAccent,
                        description:
                            'Roll d8 on the Rust Bag table: Rat, Owl, Mastiff, Goat, Giant Goat, Giant Boar, Lion, or Brown Bear!',
                        onTap: () => _launchTool(
                          context,
                          preset: BagOfTricksSummons.rustBagPreset,
                          title: 'Rust Bag of Tricks Roller',
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Tan Bag of Tricks',
                        badgeText: 'Magic Item',
                        badgeColor: Colors.amber,
                        icon: Icons.casino_outlined,
                        accentColor: Colors.amber,
                        description:
                            'Roll d8 on the Tan Bag table: Jackal, Ape, Baboon, Axe Beak, Black Bear, Giant Weasel, Giant Hyena, or Tiger!',
                        onTap: () => _launchTool(
                          context,
                          preset: BagOfTricksSummons.tanBagPreset,
                          title: 'Tan Bag of Tricks Roller',
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Horn of Valhalla',
                        badgeText: 'Magic Item',
                        badgeColor: Colors.deepOrange,
                        icon: Icons.sports_kabaddi,
                        accentColor: Colors.deepOrange,
                        description:
                            'Blow the Silver, Brass, Bronze, or Iron Horn to roll random Berserker squads (2d4+2 up to 5d4+5).',
                        onTap: () => _launchTool(
                          context,
                          preset: ValhallaSummons.hornOfValhallaPreset,
                          title: 'Horn of Valhalla Roller',
                        ),
                      ),
                      _buildToolCard(
                        context,
                        title: 'Figurines of Wondrous Power',
                        badgeText: 'Magic Item',
                        badgeColor: Colors.tealAccent,
                        icon: Icons.token,
                        accentColor: Colors.tealAccent,
                        description:
                            'Animate Bronze Griffon, Onyx Dog, or Marble Elephant statblocks with quick batch attack rolling.',
                        onTap: () => _launchTool(
                          context,
                          preset: FigurinesSummons.figurinesPreset,
                          title: 'Figurines of Wondrous Power',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // LEGAL & PRIVACY FOOTER LINKS
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => LegalDialogs.showPrivacyPolicy(context),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                        const Text('•', style: TextStyle(color: Colors.white24, fontSize: 12)),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => LegalDialogs.showTermsOfService(context),
                          child: const Text(
                            'Terms of Service',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                        const Text('•', style: TextStyle(color: Colors.white24, fontSize: 12)),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => LegalDialogs.showAttribution(context),
                          child: const Text(
                            'Legal & SRD 5.1 Attribution',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
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
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildToolGrid(BuildContext context, {required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 2 ? 1.6 : 1.7,
          children: children,
        );
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
    return Card(
      color: const Color(0xFF1E1B2E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
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
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.3),
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
        ),
      ),
    );
  }
}
