import 'package:material_ui/material_ui.dart';

import '../../models/party/party_purse.dart';
import '../../models/party/party_session_state.dart';
import '../../theme/app_theme.dart';
import '../party/campaign_dialogs.dart';

/// Displays individual party member coin purses.
class PartyMemberPursesCard extends StatelessWidget {
  final PartySessionState? session;
  final TabletopColors tabletop;
  final bool isDark;
  final String roomCode;
  final String playerName;

  const PartyMemberPursesCard({
    super.key,
    required this.session,
    required this.tabletop,
    required this.isDark,
    required this.roomCode,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roster =
        session?.characterRoster.where((s) => s.trim().isNotEmpty).toList() ??
            [];
    final allMembers = roster.isNotEmpty
        ? roster
        : [playerName].where((s) => s.trim().isNotEmpty).toList();

    if (allMembers.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Character Gold Stores (${allMembers.length})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.currency_exchange, size: 14),
                  label:
                      const Text('Disperse...', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final purse = session?.partyPurse ?? const PartyPurse.empty();
                    DisperseLootDialog.show(
                      context,
                      initialRoomCode: roomCode,
                      purse: purse,
                      sourceTitle: 'Vault Funds',
                      isVaultDispersal: true,
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 14),
            ...allMembers.map((member) {
              final purse =
                  session?.getMemberPurse(member) ?? const PartyPurse.empty();
              final isMe = member == playerName;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe
                      ? colorScheme.primary
                          .withValues(alpha: isDark ? 0.15 : 0.08)
                      : (isDark ? const Color(0xFF131622) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMe
                        ? colorScheme.primary.withValues(alpha: 0.4)
                        : (isDark
                            ? const Color(0xFF2A2E3D)
                            : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor:
                          isMe ? colorScheme.primary : Colors.grey.shade700,
                      child: const Icon(Icons.person,
                          size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                member + (isMe ? ' (You)' : ''),
                                style: TextStyle(
                                  fontWeight:
                                      isMe ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '~${purse.totalGpEquivalent.toStringAsFixed(1)} GP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${purse.pp} PP, ${purse.gp} GP, ${purse.ep} EP, ${purse.sp} SP, ${purse.cp} CP',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      padding: EdgeInsets.zero,
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                            value: 'deposit', child: Text('Deposit Coins')),
                        const PopupMenuItem(
                            value: 'withdraw', child: Text('Withdraw Coins')),
                        const PopupMenuItem(
                            value: 'transfer_to_reserve',
                            child: Text('Transfer to Party Reserve')),
                        const PopupMenuItem(
                            value: 'withdraw_from_reserve',
                            child: Text('Withdraw from Party Reserve')),
                      ],
                      onSelected: (action) {
                        if (action == 'deposit') {
                          MemberCoinTransactionDialog.show(
                            context,
                            roomCode: roomCode,
                            characterName: member,
                            performedBy: playerName,
                            isDeposit: true,
                          );
                        } else if (action == 'withdraw') {
                          MemberCoinTransactionDialog.show(
                            context,
                            roomCode: roomCode,
                            characterName: member,
                            performedBy: playerName,
                            isDeposit: false,
                          );
                        } else if (action == 'transfer_to_reserve') {
                          TransferCoinDialog.show(
                            context,
                            roomCode: roomCode,
                            characterName: member,
                            performedBy: playerName,
                            toReserve: true,
                          );
                        } else if (action == 'withdraw_from_reserve') {
                          TransferCoinDialog.show(
                            context,
                            roomCode: roomCode,
                            characterName: member,
                            performedBy: playerName,
                            toReserve: false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }


}

/// Displays shared party coin purse and party share split calculator.
class PartyCoinPurseCard extends StatelessWidget {
  final PartySessionState? session;
  final PartyPurse purse;
  final double gemsAndArtTotal;
  final PartyPurseSplit split;
  final TabletopColors tabletop;
  final bool isDark;
  final String roomCode;
  final String playerName;
  final int partySplitCount;
  final bool includeLiquidatedInSplit;
  final ValueChanged<int> onSplitCountChanged;
  final ValueChanged<bool> onIncludeLiquidatedChanged;

  const PartyCoinPurseCard({
    super.key,
    required this.session,
    required this.purse,
    required this.gemsAndArtTotal,
    required this.split,
    required this.tabletop,
    required this.isDark,
    required this.roomCode,
    required this.playerName,
    required this.partySplitCount,
    required this.includeLiquidatedInSplit,
    required this.onSplitCountChanged,
    required this.onIncludeLiquidatedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Party Coin Vault & Reserve',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '~${purse.totalGpEquivalent.toStringAsFixed(1)} GP',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFFF59E0B)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // High-Contrast Coin Counters
            Row(
              children: [
                _buildCoinBadge(
                    'PP', purse.pp, const Color(0xFFCBD5E1), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge(
                    'GP', purse.gp, const Color(0xFFF59E0B), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge(
                    'EP', purse.ep, const Color(0xFF93C5FD), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge(
                    'SP', purse.sp, const Color(0xFFE2E8F0), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge(
                    'CP', purse.cp, const Color(0xFFB45309), isDark),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons: Deposit & Withdraw
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Deposit Coins'),
                    onPressed: () => CoinTransactionDialog.show(
                      context,
                      roomCode: roomCode,
                      playerName: playerName,
                      isDeposit: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Withdraw'),
                    onPressed: () => CoinTransactionDialog.show(
                      context,
                      roomCode: roomCode,
                      playerName: playerName,
                      isDeposit: false,
                    ),
                  ),
                ),
              ],
            ),

            // Disperse Vault Funds Button
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: BorderSide(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.currency_exchange, size: 16),
                label: const Text('Disperse Vault Funds to Party...',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                onPressed: () => DisperseLootDialog.show(
                  context,
                  initialRoomCode: roomCode,
                  purse: purse,
                  liquidatedGemsAndArtGp: gemsAndArtTotal,
                  sourceTitle: 'Party Vault Funds',
                  isVaultDispersal: true,
                ),
              ),
            ),

            const Divider(height: 24),

            // Live Party Share Calculator
            Row(
              children: [
                const Icon(Icons.pie_chart_outline,
                    size: 18, color: Colors.blueAccent),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Party Share Calculator',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                DropdownButton<int>(
                  value: partySplitCount,
                  isDense: true,
                  underline: const SizedBox(),
                  items: [2, 3, 4, 5, 6, 7, 8].map((n) {
                    return DropdownMenuItem(
                        value: n, child: Text('$n Players'));
                  }).toList(),
                  onChanged: (val) =>
                      onSplitCountChanged(val ?? 4),
                ),
              ],
            ),
            if (session?.characterRoster.isNotEmpty == true &&
                session!.characterRoster.length != partySplitCount)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.groups, size: 14),
                  label: Text(
                      'Set to Roster (${session!.characterRoster.length} Players)',
                      style: const TextStyle(fontSize: 11)),
                  onPressed: () =>
                      onSplitCountChanged(session!.characterRoster.length),
                ),
              ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: includeLiquidatedInSplit,
              onChanged: (val) =>
                  onIncludeLiquidatedChanged(val ?? false),
              title: const Text('Include gems & art liquidation in split',
                  style: TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Each Player Receives:',
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '~${split.perPlayerGpEquivalent.toStringAsFixed(1)} GP',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinBadge(
      String denomination, int amount, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Text(
              denomination,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$amount',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
