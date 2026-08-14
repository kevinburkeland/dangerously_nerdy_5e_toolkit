import 'package:flutter/material.dart';

class ConditionReferenceDialog extends StatefulWidget {
  const ConditionReferenceDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const ConditionReferenceDialog(),
    );
  }

  @override
  State<ConditionReferenceDialog> createState() => _ConditionReferenceDialogState();
}

class _ConditionReferenceDialogState extends State<ConditionReferenceDialog> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const _categories = ['All', 'Incapacitating', 'Movement', 'Combat / Checks', 'Exhaustion'];

  static const _conditions = [
    (
      name: 'Blinded',
      category: 'Combat / Checks',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      bulletPoints: [
        'A blinded creature can’t see and automatically fails any ability check that requires sight.',
        'Attack rolls against the creature have Advantage.',
        'The creature’s attack rolls have Disadvantage.',
      ],
    ),
    (
      name: 'Charmed',
      category: 'Combat / Checks',
      icon: Icons.favorite,
      color: Colors.pinkAccent,
      bulletPoints: [
        'A charmed creature can’t attack the charmer or target the charmer with harmful abilities or magical effects.',
        'The charmer has Advantage on any ability check to interact socially with the creature.',
      ],
    ),
    (
      name: 'Deafened',
      category: 'Combat / Checks',
      icon: Icons.hearing_disabled,
      color: Colors.tealAccent,
      bulletPoints: [
        'A deafened creature can’t hear and automatically fails any ability check that requires hearing.',
      ],
    ),
    (
      name: 'Frightened',
      category: 'Combat / Checks',
      icon: Icons.sentiment_very_dissatisfied,
      color: Colors.deepOrangeAccent,
      bulletPoints: [
        'A frightened creature has Disadvantage on ability checks and attack rolls while the source of its fear is within line of sight.',
        'The creature can’t willingly move closer to the source of its fear.',
      ],
    ),
    (
      name: 'Grappled',
      category: 'Movement',
      icon: Icons.sports_mma,
      color: Colors.amber,
      bulletPoints: [
        'A grappled creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'The condition ends if the grappler is Incapacitated.',
        'The condition also ends if an effect removes the grappled creature from the reach of the grappler or grappling effect (e.g. Thunderwave).',
      ],
    ),
    (
      name: 'Incapacitated',
      category: 'Incapacitating',
      icon: Icons.do_not_disturb_on,
      color: Colors.redAccent,
      bulletPoints: [
        'An incapacitated creature can’t take Actions or Reactions.',
        'Concentration on active spells is immediately broken.',
      ],
    ),
    (
      name: 'Invisible',
      category: 'Combat / Checks',
      icon: Icons.blur_on,
      color: Colors.cyanAccent,
      bulletPoints: [
        'An invisible creature is impossible to see without the aid of magic or a special sense. Heavily obscured for hiding purposes.',
        'Attack rolls against the creature have Disadvantage.',
        'The creature’s attack rolls have Advantage.',
      ],
    ),
    (
      name: 'Paralyzed',
      category: 'Incapacitating',
      icon: Icons.offline_bolt,
      color: Colors.yellowAccent,
      bulletPoints: [
        'A paralyzed creature is Incapacitated (can’t take actions or reactions) and can’t move or speak.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet.',
      ],
    ),
    (
      name: 'Petrified',
      category: 'Incapacitating',
      icon: Icons.terrain,
      color: Colors.brown,
      bulletPoints: [
        'Transformed into a solid inanimate substance (usually stone). Weight increases by a factor of ten, and ceases aging.',
        'The creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'Attack rolls against the creature have Advantage.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'The creature has Resistance to all damage and is Immune to poison and disease.',
      ],
    ),
    (
      name: 'Poisoned',
      category: 'Combat / Checks',
      icon: Icons.science,
      color: Colors.greenAccent,
      bulletPoints: [
        'A poisoned creature has Disadvantage on attack rolls and ability checks.',
      ],
    ),
    (
      name: 'Prone',
      category: 'Movement',
      icon: Icons.airline_seat_flat,
      color: Colors.lightGreenAccent,
      bulletPoints: [
        'A prone creature’s only movement option is to crawl, unless it stands up and thereby ends the condition.',
        'Standing up costs an amount of movement equal to half the creature’s speed.',
        'The creature has Disadvantage on attack rolls.',
        'An attack roll against the creature has Advantage if the attacker is within 5 feet of the creature. Otherwise, the attack roll has Disadvantage.',
      ],
    ),
    (
      name: 'Restrained',
      category: 'Movement',
      icon: Icons.lock,
      color: Colors.orangeAccent,
      bulletPoints: [
        'A restrained creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'Attack rolls against the creature have Advantage, and the creature’s attack rolls have Disadvantage.',
        'The creature has Disadvantage on Dexterity saving throws.',
      ],
    ),
    (
      name: 'Stunned',
      category: 'Incapacitating',
      icon: Icons.flash_on,
      color: Colors.purpleAccent,
      bulletPoints: [
        'A stunned creature is Incapacitated, can’t move, and can speak only falteringly.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
      ],
    ),
    (
      name: 'Unconscious',
      category: 'Incapacitating',
      icon: Icons.bedtime,
      color: Colors.indigoAccent,
      bulletPoints: [
        'An unconscious creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'The creature drops whatever it’s holding and falls Prone.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet of the creature.',
      ],
    ),
    (
      name: 'Exhaustion (6 Cumulative Levels)',
      category: 'Exhaustion',
      icon: Icons.battery_alert,
      color: Colors.red,
      bulletPoints: [
        'Level 1: Disadvantage on ability checks',
        'Level 2: Speed halved',
        'Level 3: Disadvantage on attack rolls and saving throws',
        'Level 4: Hit point maximum halved',
        'Level 5: Speed reduced to 0',
        'Level 6: Death',
        'Finishing a Long Rest reduces a creature’s exhaustion level by 1, provided the creature has also ingested some food and drink.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _conditions.where((c) {
      if (_selectedCategory != 'All' && c.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final matchName = c.name.toLowerCase().contains(query);
      final matchPoints = c.bulletPoints.any((p) => p.toLowerCase().contains(query));
      return matchName || matchPoints;
    }).toList();

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
                  const Icon(Icons.medical_information_outlined, color: Colors.cyanAccent, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '5e Status Effects & Conditions',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  hintText: 'Search conditions (e.g. Advantage, Saving throw, Crit, Speed 0)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 18),
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

            // Category Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white70)),
                        selected: isSelected,
                        selectedColor: Colors.cyanAccent,
                        backgroundColor: const Color(0xFF252236),
                        checkmarkColor: Colors.black,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),

            // List of Conditions
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching conditions found.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return Card(
                          color: const Color(0xFF252236),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: item.color.withValues(alpha: 0.35)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: item.color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(item.icon, color: item.color, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: TextStyle(
                                          color: item.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item.category,
                                        style: const TextStyle(color: Colors.white60, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...item.bulletPoints.map(
                                  (pt) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(color: item.color, fontWeight: FontWeight.bold),
                                        ),
                                        Expanded(
                                          child: Text(
                                            pt,
                                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
