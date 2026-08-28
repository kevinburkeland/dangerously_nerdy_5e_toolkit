import 'package:flutter/material.dart';
import '../../models/party/party_loot_item.dart';
import '../../services/haptic_service.dart';
import '../../services/party/party_room_service.dart';

/// Modal dialog for DMs / Host Key holders to inspect and resolve structural conflicts
/// between local offline edits and cloud / remote item updates.
class LootConflictResolutionDialog extends StatefulWidget {
  final String roomCode;
  final PartyLootItem item;
  final String hostKey;
  final String playerName;

  const LootConflictResolutionDialog({
    super.key,
    required this.roomCode,
    required this.item,
    required this.hostKey,
    required this.playerName,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String roomCode,
    required PartyLootItem item,
    required String hostKey,
    required String playerName,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LootConflictResolutionDialog(
        roomCode: roomCode,
        item: item,
        hostKey: hostKey,
        playerName: playerName,
      ),
    );
  }

  @override
  State<LootConflictResolutionDialog> createState() => _LootConflictResolutionDialogState();
}

class _LootConflictResolutionDialogState extends State<LootConflictResolutionDialog> {
  final PartyRoomService _partyService = PartyRoomService();
  bool _isLoading = false;
  late PartyLootItem _cloudItem;

  @override
  void initState() {
    super.initState();
    if (widget.item.conflictPayload != null) {
      _cloudItem = PartyLootItem.fromMap(widget.item.conflictPayload!);
    } else {
      _cloudItem = widget.item;
    }
  }

  Future<void> _resolveWithCloud() async {
    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      await _partyService.resolveConflictWithCloud(
        roomCode: widget.roomCode,
        lootId: widget.item.id,
        hostKey: widget.hostKey,
        playerName: widget.playerName,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted Cloud Version for "${_cloudItem.name}".'),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve conflict: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _resolveWithLocal() async {
    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      await _partyService.resolveConflictWithLocal(
        roomCode: widget.roomCode,
        lootId: widget.item.id,
        hostKey: widget.hostKey,
        playerName: widget.playerName,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Overwrote cloud with Local Version of "${widget.item.name}".'),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve conflict: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _resolveKeepBoth() async {
    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      await _partyService.resolveConflictKeepBoth(
        roomCode: widget.roomCode,
        lootId: widget.item.id,
        hostKey: widget.hostKey,
        playerName: widget.playerName,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kept both versions ("${_cloudItem.name}" and "${widget.item.name} (Copy)").'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve conflict: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 650;

    final local = widget.item;
    final cloud = _cloudItem;

    final nameDiff = local.name != cloud.name;
    final gpDiff = local.gpValue != cloud.gpValue;
    final catDiff = local.category != cloud.category;
    final attuneDiff = local.requiresAttunement != cloud.requiresAttunement || local.isAttuned != cloud.isAttuned;
    final claimDiff = local.claimedByPlayer != cloud.claimedByPlayer;
    final descDiff = (local.description ?? '') != (cloud.description ?? '');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync_problem, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resolve Sync Conflict',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  'Divergent offline & cloud versions detected for "${local.name}"',
                  style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: isWide ? 620 : double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Choose which version to preserve. Properties highlighted in amber differ between versions.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildVersionCard(
                        title: '☁️ Cloud / Server Version',
                        item: cloud,
                        accentColor: Colors.blueAccent,
                        isDark: isDark,
                        isCloud: true,
                        nameDiff: nameDiff,
                        gpDiff: gpDiff,
                        catDiff: catDiff,
                        attuneDiff: attuneDiff,
                        claimDiff: claimDiff,
                        descDiff: descDiff,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVersionCard(
                        title: '📱 Local Offline Version',
                        item: local,
                        accentColor: Colors.amber.shade700,
                        isDark: isDark,
                        isCloud: false,
                        nameDiff: nameDiff,
                        gpDiff: gpDiff,
                        catDiff: catDiff,
                        attuneDiff: attuneDiff,
                        claimDiff: claimDiff,
                        descDiff: descDiff,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildVersionCard(
                      title: '☁️ Cloud / Server Version',
                      item: cloud,
                      accentColor: Colors.blueAccent,
                      isDark: isDark,
                      isCloud: true,
                      nameDiff: nameDiff,
                      gpDiff: gpDiff,
                      catDiff: catDiff,
                      attuneDiff: attuneDiff,
                      claimDiff: claimDiff,
                      descDiff: descDiff,
                    ),
                    const SizedBox(height: 12),
                    _buildVersionCard(
                      title: '📱 Local Offline Version',
                      item: local,
                      accentColor: Colors.amber.shade700,
                      isDark: isDark,
                      isCloud: false,
                      nameDiff: nameDiff,
                      gpDiff: gpDiff,
                      catDiff: catDiff,
                      attuneDiff: attuneDiff,
                      claimDiff: claimDiff,
                      descDiff: descDiff,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
        else ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel / Decide Later'),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                ),
                icon: const Icon(Icons.cloud_download, size: 16),
                label: const Text('Use Cloud Version'),
                onPressed: _resolveWithCloud,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade800,
                  side: BorderSide(color: Colors.amber.shade800),
                ),
                icon: const Icon(Icons.publish, size: 16),
                label: const Text('Overwrite with Local'),
                onPressed: _resolveWithLocal,
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('Keep Both (Duplicate)'),
                onPressed: _resolveKeepBoth,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVersionCard({
    required String title,
    required PartyLootItem item,
    required Color accentColor,
    required bool isDark,
    required bool isCloud,
    required bool nameDiff,
    required bool gpDiff,
    required bool catDiff,
    required bool attuneDiff,
    required bool claimDiff,
    required bool descDiff,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1E2B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          _buildFieldRow('Name', item.name, nameDiff),
          _buildFieldRow('Category', item.categoryLabel, catDiff),
          _buildFieldRow('Value', '${item.gpValue} GP (x${item.count})', gpDiff),
          _buildFieldRow(
            'Attunement',
            item.requiresAttunement ? (item.isAttuned ? 'Attuned' : 'Requires Attunement') : 'None',
            attuneDiff,
          ),
          _buildFieldRow('Claimed By', item.isClaimed ? item.claimedByPlayer! : 'Vault (Unclaimed)', claimDiff),
          if (item.description != null && item.description!.isNotEmpty)
            _buildFieldRow('Notes/Desc', item.description!, descDiff),
        ],
      ),
    );
  }

  Widget _buildFieldRow(String label, String value, bool isDifferent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDifferent ? Colors.amber : Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: isDifferent ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1) : EdgeInsets.zero,
              decoration: isDifferent
                  ? BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isDifferent ? FontWeight.bold : FontWeight.normal,
                  color: isDifferent ? Colors.amber : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
