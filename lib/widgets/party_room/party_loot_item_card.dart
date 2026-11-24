import 'package:material_ui/material_ui.dart';

import '../../models/party/campaign_membership.dart';
import '../../models/party/party_loot_item.dart';
import '../../models/party/party_session_state.dart';
import '../../services/party/party_room_service.dart';
import '../../theme/app_theme.dart';
import '../party/campaign_dialogs.dart';
import '../party/loot_conflict_resolution_dialog.dart';

/// Displays a single loot item card in the Party Room Vault tab.
class PartyLootItemCard extends StatelessWidget {
  final PartyLootItem item;
  final PartySessionState? session;
  final TabletopColors tabletop;
  final bool isDark;
  final String roomCode;
  final String playerName;
  final CampaignMembership? currentMembership;
  final PartyRoomService partyService;

  const PartyLootItemCard({
    super.key,
    required this.item,
    required this.session,
    required this.tabletop,
    required this.isDark,
    required this.roomCode,
    required this.playerName,
    required this.currentMembership,
    required this.partyService,
  });

  @override
  Widget build(BuildContext context) {
    final isClaimedByMe = item.claimedByPlayer == playerName;

    Color categoryColor = Colors.blueGrey;
    IconData categoryIcon = Icons.inventory_2_outlined;

    if (item.category == 'magicItem') {
      categoryColor = Colors.purple;
      categoryIcon = Icons.auto_awesome;
    } else if (item.category == 'gem') {
      categoryColor = Colors.cyan;
      categoryIcon = Icons.diamond_outlined;
    } else if (item.category == 'art') {
      categoryColor = Colors.orange;
      categoryIcon = Icons.palette_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.count > 1
                                  ? '${item.name} (x${item.count})'
                                  : item.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          if (item.totalGpValue > 0)
                            Text(
                              '${item.totalGpValue.toStringAsFixed(0)} GP',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.categoryLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: categoryColor,
                                fontWeight: FontWeight.bold),
                          ),
                          if (item.requiresAttunement) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Requires Attunement',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.sourceTableOrMonster != null &&
                          item.sourceTableOrMonster!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.sourceTableOrMonster!,
                          style: const TextStyle(
                              fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                      if (item.hasConflict) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            final hostKey = currentMembership?.hostKey ?? '';
                            LootConflictResolutionDialog.show(
                              context,
                              roomCode: roomCode,
                              item: item,
                              hostKey: hostKey,
                              playerName: playerName,
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.65)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sync_problem,
                                    size: 14, color: Colors.amber),
                                SizedBox(width: 4),
                                Text(
                                  'Sync Conflict (Tap to Resolve)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Delete / Archive item button
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.grey),
                  tooltip: 'Move to Vault Trash',
                  onPressed: () => partyService.archiveLootItem(
                    roomCode: roomCode,
                    lootId: item.id,
                    playerName: playerName,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            // Claim and Attunement Row
            Row(
              children: [
                if (item.isClaimed)
                  Chip(
                    avatar: Icon(Icons.person,
                        size: 14, color: isClaimedByMe ? Colors.white : null),
                    label: Text(
                      isClaimedByMe
                          ? 'Claimed by You'
                          : 'Claimed: ${item.claimedByPlayer}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isClaimedByMe ? Colors.white : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor:
                        isClaimedByMe ? Colors.green.shade700 : null,
                  )
                else
                  const Chip(
                    label: Text('In Vault (Unclaimed)',
                        style: TextStyle(fontSize: 11)),
                  ),
                const Spacer(),
                if (item.requiresAttunement && item.isClaimed)
                  TextButton.icon(
                    icon: Icon(
                      item.isAttuned ? Icons.link : Icons.link_off,
                      size: 16,
                      color: item.isAttuned ? Colors.purple : Colors.grey,
                    ),
                    label: Text(
                      item.isAttuned ? 'Attuned' : 'Attune',
                      style: TextStyle(
                        fontSize: 12,
                        color: item.isAttuned ? Colors.purple : null,
                      ),
                    ),
                    onPressed: () => partyService.toggleAttunement(
                      roomCode: roomCode,
                      lootId: item.id,
                      isAttuned: !item.isAttuned,
                      playerName: playerName,
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                  tooltip: 'Assign to Character...',
                  onPressed: () async {
                    final chosen = await AssignLootDialog.show(
                      context,
                      itemName: item.name,
                      currentActiveName: playerName,
                      roster: session?.characterRoster ?? const [],
                      activePlayers: session?.activePlayers ?? const [],
                    );
                    if (chosen == null) return;
                    if (chosen == '__unclaim__') {
                      await partyService.claimLootItem(
                        roomCode: roomCode,
                        lootId: item.id,
                        playerName: null,
                      );
                    } else {
                      await partyService.claimLootItem(
                        roomCode: roomCode,
                        lootId: item.id,
                        playerName: chosen,
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    if (item.isClaimed) {
                      partyService.claimLootItem(
                        roomCode: roomCode,
                        lootId: item.id,
                        playerName: null,
                      );
                    } else {
                      partyService.claimLootItem(
                        roomCode: roomCode,
                        lootId: item.id,
                        playerName: playerName,
                      );
                    }
                  },
                  child: Text(
                    item.isClaimed
                        ? (isClaimedByMe ? 'Unclaim' : 'Take Claim')
                        : 'Claim',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 2: LIVE DICE FEED
  // =========================================================================


}
