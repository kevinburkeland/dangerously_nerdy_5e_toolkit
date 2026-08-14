import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../providers/settings_provider.dart';
import '../../services/haptic_service.dart';

class ActionEconomyDialog extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ActionEconomyDialog({super.key, this.initialEdition});

  static void show(BuildContext context, {DmRulesEdition? edition}) {
    showDialog(
      context: context,
      builder: (ctx) => ActionEconomyDialog(initialEdition: edition),
    );
  }

  @override
  State<ActionEconomyDialog> createState() => _ActionEconomyDialogState();
}

class _ActionEconomyDialogState extends State<ActionEconomyDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DmRulesEdition? _localEditionOverride;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _standardActions2014 = [
    (
      title: 'Attack',
      cost: '1 Action',
      icon: Icons.sports_kabaddi,
      color: Colors.amber,
      desc: 'Make one melee or ranged weapon/unarmed attack. Features like Extra Attack allow multiple attacks per Attack action. Draw/sheathe only 1 weapon for free on your turn.',
    ),
    (
      title: 'Cast a Spell',
      cost: '1 Action (or Bonus Action / Reaction)',
      icon: Icons.auto_awesome,
      color: Colors.purpleAccent,
      desc: 'Cast a spell with a casting time of 1 Action. Observe V, S, M component rules and concentration limits.',
    ),
    (
      title: 'Dash',
      cost: '1 Action',
      icon: Icons.directions_run,
      color: Colors.cyanAccent,
      desc: 'Gain extra movement for the current turn equal to your Speed (e.g. 30 ft becomes 60 ft total).',
    ),
    (
      title: 'Disengage',
      cost: '1 Action',
      icon: Icons.transit_enterexit,
      color: Colors.greenAccent,
      desc: 'Your movement does not provoke opportunity attacks for the rest of the turn.',
    ),
    (
      title: 'Dodge',
      cost: '1 Action',
      icon: Icons.shield,
      color: Colors.blueAccent,
      desc: 'Until your next turn, attack rolls against you have Disadvantage (if you can see the attacker), and you have Advantage on DEX saves.',
    ),
    (
      title: 'Help',
      cost: '1 Action',
      icon: Icons.handshake,
      color: Colors.tealAccent,
      desc: 'Give an ally Advantage on their next ability check, or Advantage on their next attack roll against a creature within 5 ft of you.',
    ),
    (
      title: 'Hide',
      cost: '1 Action',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      desc: 'Make a Dexterity (Stealth) check contested by enemies\' Passive Perception to become unseen and unheard.',
    ),
    (
      title: 'Ready',
      cost: '1 Action + Reaction',
      icon: Icons.hourglass_top,
      color: Colors.orangeAccent,
      desc: 'Specify a perceivable trigger and an action (or spell) to execute as a Reaction before your next turn.',
    ),
    (
      title: 'Search',
      cost: '1 Action',
      icon: Icons.search,
      color: Colors.lightGreenAccent,
      desc: 'Devote attention to finding something. The DM might call for a Wisdom (Perception) or Intelligence (Investigation) check.',
    ),
    (
      title: 'Use an Object',
      cost: '1 Action',
      icon: Icons.touch_app,
      color: Colors.pinkAccent,
      desc: 'Interact with a second object on your turn, or use a complex item (like applying a potion or pulling a lever).',
    ),
    (
      title: 'Drink / Administer a Potion (2014 RAW)',
      cost: '1 Action',
      icon: Icons.liquor,
      color: Colors.redAccent,
      desc: 'Drinking a potion or administering a potion to an unconscious ally requires 1 Action in 2014 rules.',
    ),
    (
      title: 'Grapple (2014 Contested)',
      cost: '1 Attack (Part of Attack Action)',
      icon: Icons.sports_mma,
      color: Colors.deepOrangeAccent,
      desc: 'Strength (Athletics) check contested by target Athletics or Acrobatics. Target Speed becomes 0 if successful.',
    ),
    (
      title: 'Shove / Push (2014 Contested)',
      cost: '1 Attack (Part of Attack Action)',
      icon: Icons.swipe_right,
      color: Colors.deepOrange,
      desc: 'Strength (Athletics) check contested by target Athletics or Acrobatics. Knock the target Prone or push it 5 feet away.',
    ),
  ];

  static const _standardActions2024 = [
    (
      title: 'Attack & Weapon Swapping',
      cost: '1 Action',
      icon: Icons.sports_kabaddi,
      color: Colors.amber,
      desc: 'Make one attack with a weapon or Unarmed Strike (Damage, Grapple, or Shove). You can draw or stow one weapon before or after EACH attack.',
    ),
    (
      title: 'Cast a Spell (2024 Slot Limit)',
      cost: '1 Action (or Bonus Action / Reaction)',
      icon: Icons.auto_awesome,
      color: Colors.purpleAccent,
      desc: 'Cast a spell. On your turn, you can expend only ONE spell slot (you may cast multiple spells if only one uses a slot, e.g., slot + cantrip).',
    ),
    (
      title: 'Dash',
      cost: '1 Action',
      icon: Icons.directions_run,
      color: Colors.cyanAccent,
      desc: 'Gain extra movement for the current turn equal to your Speed.',
    ),
    (
      title: 'Disengage',
      cost: '1 Action',
      icon: Icons.transit_enterexit,
      color: Colors.greenAccent,
      desc: 'Your movement does not provoke opportunity attacks for the rest of the turn.',
    ),
    (
      title: 'Dodge',
      cost: '1 Action',
      icon: Icons.shield,
      color: Colors.blueAccent,
      desc: 'Until your next turn, attacks against you have Disadvantage (if visible), and you have Advantage on DEX saves.',
    ),
    (
      title: 'Help',
      cost: '1 Action',
      icon: Icons.handshake,
      color: Colors.tealAccent,
      desc: 'Give an ally Advantage on their next ability check (if you are proficient), or Advantage on an attack roll against a creature within 5 ft.',
    ),
    (
      title: 'Hide (2024 DC 15)',
      cost: '1 Action',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      desc: 'Make a DC 15 Dexterity (Stealth) check while heavily obscured or behind 3/4+ cover. On success, you gain the Invisible condition!',
    ),
    (
      title: 'Study (2024 New Action)',
      cost: '1 Action',
      icon: Icons.menu_book,
      color: Colors.teal,
      desc: 'Make an Intelligence check (Arcana, History, Nature, Religion, Investigation) to deduce monster stats, traits, weaknesses, or lore.',
    ),
    (
      title: 'Influence (2024 New Action)',
      cost: '1 Action',
      icon: Icons.record_voice_over,
      color: Colors.pinkAccent,
      desc: 'Influence an NPC attitude: Friendly DC 10, Indifferent DC 15, Hostile DC 20 with Persuasion, Deception, Animal Handling, or Intimidation.',
    ),
    (
      title: 'Search (2024 Codified)',
      cost: '1 Action',
      icon: Icons.search,
      color: Colors.lightGreenAccent,
      desc: 'Make a Wisdom check (Insight, Perception, Survival) to discern motives or locate concealed creatures/items.',
    ),
    (
      title: 'Ready',
      cost: '1 Action + Reaction',
      icon: Icons.hourglass_top,
      color: Colors.orangeAccent,
      desc: 'Specify a trigger and action. Readied spells require concentration until released as a reaction.',
    ),
    (
      title: 'Grapple (2024 Save DC)',
      cost: '1 Unarmed Strike (Attack Action)',
      icon: Icons.sports_mma,
      color: Colors.deepOrangeAccent,
      desc: 'Target makes STR/DEX save vs DC = 8 + STR + Prof. On fail, gains Grappled (Disadvantage on attacks against anyone other than grappler).',
    ),
    (
      title: 'Shove (2024 Save DC)',
      cost: '1 Unarmed Strike (Attack Action)',
      icon: Icons.swipe_right,
      color: Colors.deepOrange,
      desc: 'Target makes STR/DEX save vs DC = 8 + STR + Prof. On fail, target is knocked Prone or pushed 5 feet away.',
    ),
  ];

  static const _bonusActions2014 = [
    (
      title: 'Two-Weapon Fighting (Off-Hand)',
      cost: '1 Bonus Action',
      icon: Icons.content_cut,
      color: Colors.amber,
      desc: 'When you take the Attack action with a light melee weapon in one hand, attack with a different light melee weapon in the other hand (no ability mod to damage unless negative).',
    ),
    (
      title: 'Bonus Action Spells (2014 Rule)',
      cost: '1 Bonus Action',
      icon: Icons.bolt,
      color: Colors.purpleAccent,
      desc: 'If you cast a Bonus Action spell (e.g. Healing Word, Misty Step), you cannot cast another spell on the same turn except for a Cantrip with a casting time of 1 Action.',
    ),
    (
      title: 'Class & Item Features',
      cost: '1 Bonus Action',
      icon: Icons.star,
      color: Colors.cyanAccent,
      desc: 'Features explicitly designated as Bonus Actions (Cunning Action, Bardic Inspiration, Rage, Second Wind, Command Minions).',
    ),
  ];

  static const _bonusActions2024 = [
    (
      title: 'Drink or Administer a Potion (2024)',
      cost: '1 Bonus Action',
      icon: Icons.liquor,
      color: Colors.redAccent,
      desc: 'In the 2024 rules, drinking any potion or administering a potion to an ally requires only 1 Bonus Action!',
    ),
    (
      title: 'Two-Weapon Fighting (Light Property)',
      cost: '1 Bonus Action (or Part of Attack with Nick)',
      icon: Icons.content_cut,
      color: Colors.amber,
      desc: 'Attack with an off-hand Light weapon. With the Nick weapon mastery property, this extra attack is part of the Attack action itself without using a Bonus Action.',
    ),
    (
      title: 'Bonus Action Spells',
      cost: '1 Bonus Action',
      icon: Icons.bolt,
      color: Colors.purpleAccent,
      desc: 'Cast a spell with a casting time of 1 Bonus Action. Follows the 1-spell-slot-per-turn limitation.',
    ),
    (
      title: 'Class Features',
      cost: '1 Bonus Action',
      icon: Icons.star,
      color: Colors.cyanAccent,
      desc: 'Cunning Action, Bardic Inspiration, Second Wind, Rage, and specialized bonus action spells/abilities.',
    ),
  ];

  static const _reactions = [
    (
      title: 'Opportunity Attack',
      cost: '1 Reaction',
      icon: Icons.front_hand,
      color: Colors.redAccent,
      desc: 'When a hostile creature that you can see leaves your reach without Disengaging, make one melee weapon attack against it.',
    ),
    (
      title: 'Reaction Spells',
      cost: '1 Reaction',
      icon: Icons.security,
      color: Colors.purpleAccent,
      desc: 'Triggered by specific circumstances (e.g. Shield triggered by being hit, Absorb Elements by taking elemental damage, Counterspell by seeing a creature cast a spell).',
    ),
    (
      title: 'Readied Action Trigger',
      cost: '1 Reaction',
      icon: Icons.alarm_on,
      color: Colors.orangeAccent,
      desc: 'Execute your previously Readied action when its designated trigger condition occurs.',
    ),
  ];

  static const _coverRules = [
    (
      title: 'Half Cover (+2 AC / +2 DEX Saves)',
      cost: 'Environmental',
      icon: Icons.table_restaurant,
      color: Colors.lightGreenAccent,
      desc: 'A target has half cover if an obstacle blocks at least half of its body (e.g. low wall, large furniture, another creature).',
    ),
    (
      title: 'Three-Quarters Cover (+5 AC / +5 DEX Saves)',
      cost: 'Environmental',
      icon: Icons.fence,
      color: Colors.amber,
      desc: 'A target has three-quarters cover if about three-quarters of its body is covered (e.g. portcullis, arrow slit, thick tree trunk).',
    ),
    (
      title: 'Total Cover (Untargetable)',
      cost: 'Environmental',
      icon: Icons.door_front_door,
      color: Colors.redAccent,
      desc: 'A target with total cover cannot be targeted directly by an attack or spell, though some spells can reach it within an area of effect.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final is2024 = edition == DmRulesEdition.v2024;

    final standardActions = is2024 ? _standardActions2024 : _standardActions2014;
    final bonusActions = is2024 ? _bonusActions2024 : _bonusActions2014;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: const Color(0xFF1E1B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '5e Combat Action Economy',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Edition Toggle Button
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252236),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEditionChip(
                          label: '2014',
                          isActive: !is2024,
                          onTap: () {
                            HapticService.selectionTick(context);
                            setState(() => _localEditionOverride = DmRulesEdition.v2014);
                            settingsProvider?.setRulesEdition(DmRulesEdition.v2014);
                          },
                        ),
                        _buildEditionChip(
                          label: '2024',
                          isActive: is2024,
                          onTap: () {
                            HapticService.selectionTick(context);
                            setState(() => _localEditionOverride = DmRulesEdition.v2024);
                            settingsProvider?.setRulesEdition(DmRulesEdition.v2024);
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search actions (e.g., Dodge, Cover, Grapple, Potion)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.amber, size: 18),
                  filled: true,
                  fillColor: const Color(0xFF252236),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white54,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: '1 Action (Standard)'),
                Tab(text: 'Bonus Action'),
                Tab(text: 'Reaction'),
                Tab(text: 'Cover Rules'),
              ],
            ),
            const Divider(height: 1, color: Colors.white12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(standardActions),
                  _buildList(bonusActions),
                  _buildList(_reactions),
                  _buildList(_coverRules),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditionChip({required String label, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<({String title, String cost, IconData icon, Color color, String desc})> items) {
    final filtered = items.where((i) {
      if (_searchQuery.isEmpty) return true;
      return i.title.toLowerCase().contains(_searchQuery) ||
          i.desc.toLowerCase().contains(_searchQuery) ||
          i.cost.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No matching combat actions found.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Card(
          color: const Color(0xFF252236),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: item.color.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.cost,
                              style: TextStyle(color: item.color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.desc,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
