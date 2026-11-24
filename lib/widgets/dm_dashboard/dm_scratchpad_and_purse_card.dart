import 'package:material_ui/material_ui.dart';

import '../../models/dm_screen_data.dart';
import '../../providers/dm_dashboard_controller.dart';

/// Session scratchpad notes and shared party purse card for the DM Dashboard.
class DmScratchpadAndPurseCard extends StatelessWidget {
  final DmDashboardController controller;
  final TextEditingController notesController;
  final void Function({bool immediate}) onPersistNotes;
  final void Function(String coinKey, int delta) onModifyPurseCoin;
  final void Function(Character character) onOpenCharacterSheet;

  const DmScratchpadAndPurseCard({
    super.key,
    required this.controller,
    required this.notesController,
    required this.onPersistNotes,
    required this.onModifyPurseCoin,
    required this.onOpenCharacterSheet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roster = controller.partyCharacters;
    final partyPurse = controller.partyPurse;
    final totalWealth = controller.totalPartyWealth;

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
                const Icon(Icons.account_balance,
                    color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Session Notes & Party Purse',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '~${totalWealth.totalGpEquivalent.toStringAsFixed(1)} GP Total Wealth',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              'SHARED PARTY TREASURY (~${partyPurse.totalGpEquivalent.toStringAsFixed(1)} GP)',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            // Party Purse HUD
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCoinColumn(
                      'PP',
                      partyPurse.pp,
                      () => onModifyPurseCoin('pp', 1),
                      () => onModifyPurseCoin('pp', -1)),
                  _buildCoinColumn(
                      'GP',
                      partyPurse.gp,
                      () => onModifyPurseCoin('gp', 10),
                      () => onModifyPurseCoin('gp', -10)),
                  _buildCoinColumn(
                      'EP',
                      partyPurse.ep,
                      () => onModifyPurseCoin('ep', 1),
                      () => onModifyPurseCoin('ep', -1)),
                  _buildCoinColumn(
                      'SP',
                      partyPurse.sp,
                      () => onModifyPurseCoin('sp', 10),
                      () => onModifyPurseCoin('sp', -10)),
                  _buildCoinColumn(
                      'CP',
                      partyPurse.cp,
                      () => onModifyPurseCoin('cp', 10),
                      () => onModifyPurseCoin('cp', -10)),
                ],
              ),
            ),
            if (roster.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'LINKED CHARACTER PURSES',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: roster.map((c) {
                  return InkWell(
                    onTap: () => onOpenCharacterSheet(c),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${c.name}: ${c.purse.gp} GP (~${c.purse.totalGpEquivalent.toStringAsFixed(0)} eq)',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'DM Scratchpad & Session Notes',
                hintText: 'Type running notes, secrets, clues, loot...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onPersistNotes(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinColumn(
      String label, int count, VoidCallback onAdd, VoidCallback onSub) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.amber)),
        Text('$count',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onSub,
              child: const Icon(Icons.remove, size: 14),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onAdd,
              child: const Icon(Icons.add, size: 14),
            ),
          ],
        ),
      ],
    );
  }

}
