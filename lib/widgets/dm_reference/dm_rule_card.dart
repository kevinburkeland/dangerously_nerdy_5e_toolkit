import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../interactive/pressable_card.dart';

/// Modular, interactive card presenting a single 5e rulebook entry.
class DmRuleCard extends StatelessWidget {
  final DmReferenceItem item;
  final DmRulesEdition edition;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onTap;

  const DmRuleCard({
    super.key,
    required this.item,
    required this.edition,
    required this.isPinned,
    required this.onTogglePin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeRules = item.getRules(edition);

    return PressableCard(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPinned ? Colors.amber.withValues(alpha: 0.7) : item.color.withValues(alpha: 0.35),
          width: isPinned ? 1.5 : 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.category.label,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.isChangedIn2024) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.amber, size: 11),
                      SizedBox(width: 3),
                      Text(
                        '2024 Diff',
                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              IconButton(
                icon: Icon(
                  isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: isPinned ? Colors.amber : Colors.white38,
                  size: 20,
                ),
                tooltip: isPinned ? 'Unpin rule from top' : 'Pin rule to top',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                splashRadius: 18,
                onPressed: onTogglePin,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Summary
          Text(
            item.summary,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(height: 16, color: Colors.white10),

          // Rule Bullet points for current edition
          ...activeRules.map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: item.color, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        rule,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 8),

          // Bottom Action: Tap to Compare
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Compare 2014 vs 2024',
                style: TextStyle(
                  color: item.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.compare_arrows, color: item.color, size: 14),
            ],
          ),
        ],
      ),
    );
  }
}
