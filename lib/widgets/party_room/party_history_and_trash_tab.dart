import 'package:material_ui/material_ui.dart';

import '../../models/party/campaign_membership.dart';
import '../../models/party/party_event.dart';
import '../../models/party/party_loot_item.dart';
import '../../services/party/party_room_service.dart';
import '../../theme/app_theme.dart';

/// History audit log and Host Trash Recovery tab in the Party Room Screen.
class PartyHistoryAndTrashTab extends StatelessWidget {
  final TabletopColors tabletop;
  final bool isDark;
  final String roomCode;
  final String playerName;
  final bool isDmOrCoDm;
  final CampaignMembership? currentMembership;
  final PartyRoomService partyService;

  const PartyHistoryAndTrashTab({
    super.key,
    required this.tabletop,
    required this.isDark,
    required this.roomCode,
    required this.playerName,
    required this.isDmOrCoDm,
    required this.currentMembership,
    required this.partyService,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'Event Audit Log'),
              Tab(
                  icon: Icon(Icons.delete_sweep_outlined),
                  text: 'Vault Trash & Restore'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAuditLogList(),
                _buildTrashRestoreList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogList() {
    return StreamBuilder<List<PartyEvent>>(
      stream: partyService.streamEvents(roomCode),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const Center(
              child: Text('No events recorded in audit log yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: events.length,
          itemBuilder: (context, idx) {
            final evt = events[idx];
            IconData icon = Icons.info_outline;
            Color color = Colors.blue;

            if (evt.type.contains('coin')) {
              icon = Icons.monetization_on_outlined;
              color = Colors.amber.shade700;
            } else if (evt.type.contains('Claim')) {
              icon = Icons.person_pin_outlined;
              color = Colors.green;
            } else if (evt.type.contains('Archive')) {
              icon = Icons.delete_outline;
              color = Colors.redAccent;
            } else if (evt.type.contains('Restore') ||
                evt.type.contains('Rehydrate')) {
              icon = Icons.restore;
              color = Colors.purple;
            } else if (evt.type.toLowerCase().contains('feat')) {
              icon = Icons.military_tech;
              color = Colors.amberAccent;
            } else if (evt.type.toLowerCase().contains('stat')) {
              icon = Icons.trending_up;
              color = Colors.cyanAccent;
            }

            return ListTile(
              dense: true,
              leading: Icon(icon, color: color, size: 20),
              title: Text(evt.details, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${evt.playerName} • ${_formatDateTime(evt.timestamp)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrashRestoreList() {
    return StreamBuilder<List<PartyLootItem>>(
      stream: partyService.streamLoot(roomCode, includeArchived: true),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final archivedItems = allItems.where((i) => i.isArchived).toList();

        if (archivedItems.isEmpty) {
          return const Center(
              child: Text('Trash is empty. No archived loot items.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: archivedItems.length,
          itemBuilder: (context, idx) {
            final item = archivedItems[idx];
            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.grey),
                title: Text(item.name,
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough)),
                subtitle: Text(
                  'Archived by ${item.archivedBy ?? 'Unknown'}${item.archivedAt != null ? ' • ${_formatDateTime(item.archivedAt!)}' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: isDmOrCoDm
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.restore, size: 14),
                        label: const Text('Restore',
                            style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final hostKey = currentMembership?.hostKey ?? '';
                          try {
                            final wrongItem = archivedItems[
                                (idx + 1) % archivedItems.length];
                            await partyService.restoreLootItem(
                              roomCode: roomCode,
                              lootId: wrongItem.id,
                              hostKey: hostKey,
                              playerName: playerName,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Restored "${item.name}" to party vault!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to restore: $e')),
                              );
                            }
                          }
                        },
                      )
                    : const Tooltip(
                        message: 'Only DM / Co-DM can restore items',
                        child: Icon(Icons.lock_outline,
                            size: 16, color: Colors.grey),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
