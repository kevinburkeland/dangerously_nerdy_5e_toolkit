import 'package:flutter/material.dart';
import '../../models/arena/arena_combatant.dart';
import 'arena_condition_chip.dart';

/// Interactive modal sheet/dialog for DMs to quickly inspect, toggle, and configure status conditions on a fighter token.
class ArenaConditionToggleDialog extends StatefulWidget {
  final ArenaCombatant combatant;
  final VoidCallback? onUpdated;

  const ArenaConditionToggleDialog({
    super.key,
    required this.combatant,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required ArenaCombatant combatant,
    VoidCallback? onUpdated,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ArenaConditionToggleDialog(
        combatant: combatant,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<ArenaConditionToggleDialog> createState() => _ArenaConditionToggleDialogState();
}

class _ArenaConditionToggleDialogState extends State<ArenaConditionToggleDialog> {
  int? _selectedDuration; // null = indefinite, 1 = 1 round, 10 = 1 min
  final TextEditingController _sourceController = TextEditingController();

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  void _toggle(ArenaCondition condition) {
    setState(() {
      final source = _sourceController.text.trim().isNotEmpty
          ? _sourceController.text.trim()
          : null;
      widget.combatant.toggleCondition(
        condition,
        durationRounds: _selectedDuration,
        source: source,
      );
    });
    widget.onUpdated?.call();
  }

  void _clearAll() {
    setState(() {
      widget.combatant.clearConditions();
    });
    widget.onUpdated?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final combatant = widget.combatant;
    final teamColor = combatant.team.color;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF181A24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: teamColor.withAlpha(120), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.medical_information_outlined, color: teamColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status Conditions: ${combatant.displayName}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${combatant.team.label} • HP ${combatant.currentHp}/${combatant.maxHp}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  if (combatant.conditions.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 16, color: Colors.redAccent),
                      label: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      onPressed: _clearAll,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Active Conditions Preview Bar
            if (combatant.activeConditions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: isDark ? const Color(0xFF13151F) : const Color(0xFFF8FAFC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVE ON TOKEN (Tap to remove):',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: combatant.activeConditions.map((a) {
                        return ArenaConditionChip(
                          activeCondition: a,
                          showLabel: true,
                          onRemove: () => _toggle(a.condition),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            // Duration & Source Configuration Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  const Text('Duration:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('Indefinite (Saved)', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == null,
                          onSelected: (s) => setState(() => _selectedDuration = null),
                        ),
                        ChoiceChip(
                          label: const Text('1 Round', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == 1,
                          onSelected: (s) => setState(() => _selectedDuration = s ? 1 : null),
                        ),
                        ChoiceChip(
                          label: const Text('1 Min (10r)', style: TextStyle(fontSize: 11)),
                          selected: _selectedDuration == 10,
                          onSelected: (s) => setState(() => _selectedDuration = s ? 10 : null),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 16),

            // Conditions Grid
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'All 5e Conditions & Statuses (Click to Toggle):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ArenaCondition.values.map((cond) {
                      final isActive = combatant.hasCondition(cond);
                      final color = cond.colorTheme;

                      return InkWell(
                        onTap: () => _toggle(cond),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withAlpha(isDark ? 55 : 40)
                                : (isDark ? const Color(0xFF222634) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive ? color : (isDark ? Colors.white12 : Colors.black12),
                              width: isActive ? 1.5 : 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: color.withAlpha(isDark ? 60 : 35),
                                      blurRadius: 6,
                                      spreadRadius: 0.5,
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cond.icon,
                                size: 16,
                                color: isActive ? color : (isDark ? Colors.white70 : Colors.black54),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cond.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                  color: isActive ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (isActive)
                                Icon(Icons.check_circle, size: 14, color: color)
                              else
                                Icon(Icons.add_circle_outline, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: teamColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
