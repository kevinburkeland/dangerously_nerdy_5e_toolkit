import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../providers/settings_provider.dart';
import '../../services/a11y_service.dart';
import '../../services/haptic_service.dart';

class ConditionReferenceDialog extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ConditionReferenceDialog({super.key, this.initialEdition});

  static void show(BuildContext context, {DmRulesEdition? edition}) {
    showDialog(
      context: context,
      builder: (ctx) => ConditionReferenceDialog(initialEdition: edition),
    );
  }

  @override
  State<ConditionReferenceDialog> createState() => _ConditionReferenceDialogState();
}

class _ConditionReferenceDialogState extends State<ConditionReferenceDialog> {
  DmRulesEdition? _localEditionOverride;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const _categories = ['All', 'Incapacitating', 'Movement', 'Combat / Checks', 'Exhaustion'];

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  static const _conditions = [
    (
      name: 'Blinded',
      category: 'Combat / Checks',
      icon: Icons.visibility_off,
      color: Colors.blueGrey,
      points2014: [
        'A blinded creature can’t see and automatically fails any ability check that requires sight.',
        'Attack rolls against the creature have Advantage.',
        'The creature’s attack rolls have Disadvantage.',
      ],
      points2024: [
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
      points2014: [
        'A charmed creature can’t attack the charmer or target the charmer with harmful abilities or magical effects.',
        'The charmer has Advantage on any ability check to interact socially with the creature.',
      ],
      points2024: [
        'A charmed creature can’t attack the charmer or target the charmer with harmful abilities or magical effects.',
        'The charmer has Advantage on any ability check to interact socially with the creature.',
      ],
    ),
    (
      name: 'Deafened',
      category: 'Combat / Checks',
      icon: Icons.hearing_disabled,
      color: Colors.tealAccent,
      points2014: [
        'A deafened creature can’t hear and automatically fails any ability check that requires hearing.',
      ],
      points2024: [
        'A deafened creature can’t hear and automatically fails any ability check that requires hearing.',
      ],
    ),
    (
      name: 'Frightened',
      category: 'Combat / Checks',
      icon: Icons.sentiment_very_dissatisfied,
      color: Colors.deepOrangeAccent,
      points2014: [
        'A frightened creature has Disadvantage on ability checks and attack rolls while the source of its fear is within line of sight.',
        'The creature can’t willingly move closer to the source of its fear.',
      ],
      points2024: [
        'A frightened creature has Disadvantage on ability checks and attack rolls while the source of its fear is visible.',
        'The creature can’t willingly move closer to the source of its fear.',
      ],
    ),
    (
      name: 'Grappled',
      category: 'Movement',
      icon: Icons.sports_mma,
      color: Colors.amber,
      points2014: [
        'A grappled creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'The condition ends if the grappler is Incapacitated.',
        'The condition also ends if an effect removes the grappled creature from reach (e.g. Thunderwave).',
        'Grappler can move with target at half speed.',
      ],
      points2024: [
        'Speed becomes 0 and cannot increase.',
        'Attacks: You have Disadvantage on attack rolls against anyone other than the grappler.',
        'Movable: The grappler can drag or carry you at half speed (full speed if you are Tiny or 2+ sizes smaller).',
        'Escape: Make a STR or DEX saving throw at the end of each of your turns against the escape DC.',
      ],
    ),
    (
      name: 'Incapacitated',
      category: 'Incapacitating',
      icon: Icons.do_not_disturb_on,
      color: Colors.redAccent,
      points2014: [
        'An incapacitated creature can’t take Actions or Reactions.',
        'Concentration on active spells is immediately broken.',
      ],
      points2024: [
        'You can’t take Actions, Bonus Actions, or Reactions.',
        'Your Concentration is immediately broken.',
        'Attack rolls against you have Advantage.',
        'You have Disadvantage on Initiative rolls.',
        'You cannot speak.',
      ],
    ),
    (
      name: 'Invisible',
      category: 'Combat / Checks',
      icon: Icons.blur_on,
      color: Colors.cyanAccent,
      points2014: [
        'An invisible creature is impossible to see without the aid of magic or a special sense. Heavily obscured for hiding purposes.',
        'Attack rolls against the creature have Disadvantage.',
        'The creature’s attack rolls have Advantage.',
      ],
      points2024: [
        'Concealed: You aren’t affected by any effect that requires its target to be seen (unless special sight).',
        'Attack rolls against you have Disadvantage; your attack rolls have Advantage.',
        'Initiative: If invisible when rolling Initiative, you have Advantage on the roll.',
      ],
    ),
    (
      name: 'Paralyzed',
      category: 'Incapacitating',
      icon: Icons.offline_bolt,
      color: Colors.yellowAccent,
      points2014: [
        'A paralyzed creature is Incapacitated (can’t take actions or reactions) and can’t move or speak.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet.',
      ],
      points2024: [
        'Incapacitated, can’t move or speak.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage.',
        'Any attack that hits from within 5 feet is a Critical Hit.',
      ],
    ),
    (
      name: 'Petrified',
      category: 'Incapacitating',
      icon: Icons.terrain,
      color: Colors.brown,
      points2014: [
        'Transformed into a solid inanimate substance (usually stone). Weight increases by a factor of ten, and ceases aging.',
        'The creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'Attack rolls against the creature have Advantage.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'The creature has Resistance to all damage and is Immune to poison and disease.',
      ],
      points2024: [
        'Transformed into solid stone (weight ×10), ceases aging.',
        'Incapacitated, can’t move or speak, unaware of surroundings.',
        'Attack rolls against have Advantage. Auto-fails STR and DEX saves.',
        'Resistance to all damage; Immune to poison damage and the Poisoned condition.',
      ],
    ),
    (
      name: 'Poisoned',
      category: 'Combat / Checks',
      icon: Icons.science,
      color: Colors.greenAccent,
      points2014: [
        'A poisoned creature has Disadvantage on attack rolls and ability checks.',
      ],
      points2024: [
        'A poisoned creature has Disadvantage on attack rolls and ability checks.',
      ],
    ),
    (
      name: 'Prone',
      category: 'Movement',
      icon: Icons.airline_seat_flat,
      color: Colors.lightGreenAccent,
      points2014: [
        'A prone creature’s only movement option is to crawl, unless it stands up and thereby ends the condition.',
        'Standing up costs an amount of movement equal to half the creature’s speed.',
        'The creature has Disadvantage on attack rolls.',
        'An attack roll against the creature has Advantage if the attacker is within 5 feet of the creature. Otherwise, the attack roll has Disadvantage.',
      ],
      points2024: [
        'Only movement options are crawling (costs extra movement) or standing up (costs half Speed).',
        'Disadvantage on attack rolls.',
        'Attack rolls from within 5 feet have Advantage; other attack rolls have Disadvantage.',
      ],
    ),
    (
      name: 'Restrained',
      category: 'Movement',
      icon: Icons.lock,
      color: Colors.orangeAccent,
      points2014: [
        'A restrained creature’s speed becomes 0, and it can’t benefit from any bonus to its speed.',
        'Attack rolls against the creature have Advantage, and the creature’s attack rolls have Disadvantage.',
        'The creature has Disadvantage on Dexterity saving throws.',
      ],
      points2024: [
        'Speed becomes 0 and cannot increase.',
        'Attack rolls against have Advantage, and creature’s attack rolls have Disadvantage.',
        'Disadvantage on Dexterity saving throws.',
      ],
    ),
    (
      name: 'Stunned',
      category: 'Incapacitating',
      icon: Icons.flash_on,
      color: Colors.purpleAccent,
      points2014: [
        'A stunned creature is Incapacitated, can’t move, and can speak only falteringly.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
      ],
      points2024: [
        'Incapacitated, can’t move, can speak only falteringly.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage.',
      ],
    ),
    (
      name: 'Unconscious',
      category: 'Incapacitating',
      icon: Icons.bedtime,
      color: Colors.indigoAccent,
      points2014: [
        'An unconscious creature is Incapacitated, can’t move or speak, and is unaware of its surroundings.',
        'The creature drops whatever it’s holding and falls Prone.',
        'The creature automatically fails Strength and Dexterity saving throws.',
        'Attack rolls against the creature have Advantage.',
        'Any attack that hits the creature is a Critical Hit if the attacker is within 5 feet of the creature.',
      ],
      points2024: [
        'Incapacitated, drops held items, falls Prone, unaware of surroundings.',
        'Auto-fails Strength and Dexterity saving throws.',
        'Attack rolls against have Advantage; hits from within 5 feet are Critical Hits.',
        'If asleep when combat begins, rolls Initiative with Disadvantage.',
      ],
    ),
    (
      name: 'Exhaustion',
      category: 'Exhaustion',
      icon: Icons.battery_alert,
      color: Colors.red,
      points2014: [
        'Level 1: Disadvantage on ability checks',
        'Level 2: Speed halved',
        'Level 3: Disadvantage on attack rolls and saving throws',
        'Level 4: Hit point maximum halved',
        'Level 5: Speed reduced to 0',
        'Level 6: Death',
        'Finishing a Long Rest with food/drink reduces exhaustion level by 1.',
      ],
      points2024: [
        'Cumulative penalty across 10 total levels.',
        'D20 Tests: Subtract 2 × exhaustion level from all D20 Tests (attack rolls, ability checks, saves) and spell save DC.',
        'Speed: Reduce speed by 5 feet × exhaustion level.',
        'Level 10: Death.',
        'Finishing a Long Rest with food/drink removes 1 exhaustion level.',
      ],
    ),
    (
      name: 'Surprise / Surprised',
      category: 'Combat / Checks',
      icon: Icons.priority_high,
      color: Colors.deepPurpleAccent,
      points2014: [
        'If surprised: You cannot move or take an Action on your first turn of combat.',
        'You cannot take a Reaction until that first turn ends.',
      ],
      points2024: [
        'No "Surprised" condition exists in 2024.',
        'If surprised when Initiative is rolled, you have Disadvantage on your Initiative roll.',
        'You can act normally on your first turn.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final is2024 = edition == DmRulesEdition.v2024;

    final filtered = _conditions.where((c) {
      if (_selectedCategory != 'All' && c.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final matchName = c.name.toLowerCase().contains(query);
      final points = is2024 ? c.points2024 : c.points2014;
      final matchPoints = points.any((p) => p.toLowerCase().contains(query));
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
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        '5e Status Effects & Conditions',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Edition Toggle Button
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252236),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEditionChip(
                          label: '2014',
                          isActive: !is2024,
                          onTap: () {
                            HapticService.selectionTick(context);
                            A11yService.announce('Switched to 2014 rules edition');
                            setState(() => _localEditionOverride = DmRulesEdition.v2014);
                            settingsProvider?.setRulesEdition(DmRulesEdition.v2014);
                          },
                        ),
                        _buildEditionChip(
                          label: '2024',
                          isActive: is2024,
                          onTap: () {
                            HapticService.selectionTick(context);
                            A11yService.announce('Switched to 2024 revised rules edition');
                            setState(() => _localEditionOverride = DmRulesEdition.v2024);
                            settingsProvider?.setRulesEdition(DmRulesEdition.v2024);
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    tooltip: 'Close dialog',
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
                        final bulletPoints = is2024 ? item.points2024 : item.points2014;
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
                                ...bulletPoints.map(
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

  Widget _buildEditionChip({required String label, required bool isActive, required VoidCallback onTap}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Semantics(
        button: true,
        selected: isActive,
        label: '$label Edition Rules',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? Colors.cyanAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
