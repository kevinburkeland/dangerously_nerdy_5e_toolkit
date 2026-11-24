import 'package:material_ui/material_ui.dart';

import '../../models/campaign_profile.dart';
import '../../models/dm_screen_data.dart';
import '../../providers/dm_dashboard_controller.dart';
import '../../screens/rules_compendium_screen.dart';
import '../../services/haptic_service.dart';
import '../dm_reference/dm_interactive_tools.dart';
import '../dm_reference/dm_rule_card.dart';

/// Pinned DM quick-reference rules card for the DM Dashboard.
class DmPinnedRulesCard extends StatelessWidget {
  final CampaignProfile? activeProfile;
  final DmDashboardController controller;

  const DmPinnedRulesCard({
    super.key,
    required this.activeProfile,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = activeProfile!;
    final pinned = profile.pinnedRuleIds;
    final allItems = DmScreenLibrary.allItems;
    final pinnedItems = allItems.where((i) => pinned.contains(i.id)).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.push_pin,
                    color: Colors.lightGreenAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quick-Pinned Rules & Calculators',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${pinnedItems.length} Pinned (${profile.rulesEdition.label})',
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const Divider(height: 20),
            // Always available embedded core tools
            const ConcentrationCalculatorWidget(),
            const SizedBox(height: 10),
            const FallingDamageCalculatorWidget(),
            const SizedBox(height: 10),
            const GrappleShoveCalculatorWidget(),
            if (pinnedItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.menu_book,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'PINNED RULEBOOK ENTRIES (${profile.rulesEdition.label})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...pinnedItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DmRuleCard(
                      item: item,
                      edition: profile.rulesEdition,
                      isPinned: true,
                      onTogglePin: () async {
                        await controller.togglePinnedRule(item.id);
                      },
                      onTap: () {},
                    ),
                  )),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.menu_book, size: 16),
                label: const Text('Browse Full 5e Rules Compendium...',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticService.selectionTick(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RulesCompendiumScreen(
                        initialEdition: profile.rulesEdition,
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

  // --- Widget 5: Live Session Markdown Scratchpad & Purse Tracker ---


}
