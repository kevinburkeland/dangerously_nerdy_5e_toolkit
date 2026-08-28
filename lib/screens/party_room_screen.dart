import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/party/campaign_membership.dart';
import '../models/party/party_event.dart';
import '../models/party/party_loot_item.dart';
import '../models/party/party_purse.dart';
import '../models/party/party_session_state.dart';
import '../models/room_roll.dart';
import '../services/dice_room_service.dart';
import '../services/haptic_service.dart';
import '../services/party/campaign_registry_service.dart';
import '../services/party/party_room_service.dart';
import '../theme/app_theme.dart';
import '../widgets/party/campaign_dialogs.dart';
import 'dice_roller_screen.dart';

/// Comprehensive multi-tab Party Room Screen featuring Shared Party Vault,
/// Coin Purse with Party Share distribution, Live Dice Feed, and History/Audit Log with Host Trash Recovery.
class PartyRoomScreen extends StatefulWidget {
  final String roomCode;
  final String? initialPlayerName;
  final PartyRoomService partyService;
  final CampaignRegistryService registry;
  final DiceRoomService diceService;

  PartyRoomScreen({
    super.key,
    required this.roomCode,
    this.initialPlayerName,
    PartyRoomService? partyService,
    CampaignRegistryService? registry,
    DiceRoomService? diceService,
  })  : partyService = partyService ?? PartyRoomService(),
        registry = registry ?? CampaignRegistryService(),
        diceService = diceService ?? DiceRoomService();

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final PartyRoomService _partyService;
  late final CampaignRegistryService _registry;
  late final DiceRoomService _diceService;

  late String _roomCode;
  late String _playerName;

  // Filter state for vault items
  String _selectedCategoryFilter = 'all'; // 'all', 'magicItem', 'gem_art', 'gear', 'claimed', 'unclaimed'
  int _partySplitCount = 4;
  bool _includeLiquidatedInSplit = false;

  @override
  void initState() {
    super.initState();
    _partyService = widget.partyService;
    _registry = widget.registry;
    _diceService = widget.diceService;
    _roomCode = widget.roomCode.trim().toUpperCase();
    _tabController = TabController(length: 3, vsync: this);

    final membership = _registry.getMembership(_roomCode);
    _playerName = widget.initialPlayerName ??
        membership?.characterId ??
        _diceService.playerName ??
        'Adventurer';

    _registry.updateLastPlayed(_roomCode);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: _roomCode));
    HapticService.lightImpact(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room Code "$_roomCode" copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  CampaignMembership? get _currentMembership => _registry.getMembership(_roomCode);
  bool get _isDmOrCoDm => _currentMembership?.isDmOrCoDm ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final tabletop = theme.extension<TabletopColors>() ?? (isDark ? TabletopColors.dark : TabletopColors.light);

    return StreamBuilder<PartySessionState?>(
      stream: _partyService.streamSession(_roomCode),
      builder: (context, sessionSnap) {
        final session = sessionSnap.data;
        final campaignName = session?.campaignName ?? _currentMembership?.campaignName ?? 'Party Room';

        return Scaffold(
          appBar: AppBar(
            elevation: 2,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        campaignName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isDmOrCoDm) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _currentMembership?.role == CampaignRole.host ? 'DM' : 'Co-DM',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                InkWell(
                  onTap: _copyRoomCode,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _roomCode,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.copy, size: 12, color: colorScheme.primary),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Connection / Outbox Sync Status Badge
              ValueListenableBuilder<int>(
                valueListenable: _partyService.pendingOutboxCount,
                builder: (context, count, _) {
                  if (count > 0) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        avatar: const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        label: Text('Syncing ($count)', style: const TextStyle(fontSize: 11)),
                        onPressed: () => _partyService.flushOutbox(_roomCode),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // DM Passkey Export Button
              if (_isDmOrCoDm && _currentMembership != null)
                IconButton(
                  icon: const Icon(Icons.key, color: Colors.amber),
                  tooltip: 'Share DM Passkey',
                  onPressed: () => ShareDmPasskeyDialog.show(context, _currentMembership!),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (val) {
                  if (val == 'addLoot') {
                    AddLootItemDialog.show(context, roomCode: _roomCode, playerName: _playerName);
                  } else if (val == 'diceRoller') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceRollerScreen()));
                  } else if (val == 'passkey' && _currentMembership != null) {
                    ShareDmPasskeyDialog.show(context, _currentMembership!);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'addLoot',
                    child: Row(
                      children: [
                        Icon(Icons.add_box_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Add Custom Loot Item'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'diceRoller',
                    child: Row(
                      children: [
                        Icon(Icons.casino_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Open Full Dice Roller'),
                      ],
                    ),
                  ),
                  if (_isDmOrCoDm)
                    const PopupMenuItem(
                      value: 'passkey',
                      child: Row(
                        children: [
                          Icon(Icons.key_outlined, size: 18, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Share DM Passkey'),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.shield_moon_outlined), text: 'Party Vault'),
                Tab(icon: Icon(Icons.casino_outlined), text: 'Dice Feed'),
                Tab(icon: Icon(Icons.history_edu), text: 'Loot & Trash Log'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildVaultTab(session?.partyPurse ?? const PartyPurse(), tabletop, isDark),
              _buildDiceFeedTab(tabletop, isDark),
              _buildHistoryAndTrashTab(tabletop, isDark),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => AddLootItemDialog.show(
              context,
              roomCode: _roomCode,
              playerName: _playerName,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Vault Item'),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TAB 1: PARTY VAULT & COIN PURSE
  // =========================================================================

  Widget _buildVaultTab(PartyPurse purse, TabletopColors tabletop, bool isDark) {
    return StreamBuilder<List<PartyLootItem>>(
      stream: _partyService.streamLoot(_roomCode),
      builder: (context, lootSnap) {
        final allItems = lootSnap.data ?? [];

        // Compute total gem & art gold value
        double gemsAndArtTotal = 0.0;
        for (final item in allItems) {
          if (item.category == 'gem' || item.category == 'art') {
            gemsAndArtTotal += item.totalGpValue;
          }
        }

        // Filter items
        final filteredItems = allItems.where((item) {
          if (_selectedCategoryFilter == 'magicItem') return item.category == 'magicItem';
          if (_selectedCategoryFilter == 'gem_art') return item.category == 'gem' || item.category == 'art';
          if (_selectedCategoryFilter == 'gear') return item.category == 'gear' || item.category == 'currency';
          if (_selectedCategoryFilter == 'claimed') return item.isClaimed;
          if (_selectedCategoryFilter == 'unclaimed') return !item.isClaimed;
          return true;
        }).toList();

        final split = purse.splitShares(
          _partySplitCount,
          includeLiquidatedGemsAndArt: _includeLiquidatedInSplit,
          liquidatedGemsAndArtGp: gemsAndArtTotal,
        );

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            // 1. COIN PURSE HERO CARD
            _buildCoinPurseCard(purse, split, tabletop, isDark),
            const SizedBox(height: 14),

            // 2. CATEGORY FILTER CHIPS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Items (${allItems.length})', 'all'),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '✨ Magic (${allItems.where((i) => i.category == 'magicItem').length})',
                    'magicItem',
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '💎 Gems & Art (${allItems.where((i) => i.category == 'gem' || i.category == 'art').length})',
                    'gem_art',
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    '⚔️ Gear (${allItems.where((i) => i.category == 'gear' || i.category == 'currency').length})',
                    'gear',
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip('🙋 Claimed', 'claimed'),
                  const SizedBox(width: 6),
                  _buildFilterChip('📦 Unclaimed', 'unclaimed'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. LOOT ITEMS LIST
            if (filteredItems.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade500),
                      const SizedBox(height: 10),
                      Text(
                        allItems.isEmpty
                            ? 'The party vault is currently empty.\nAdd drops or deposit treasure hoards!'
                            : 'No items match the selected filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredItems.map((item) => _buildLootItemCard(item, tabletop, isDark)),

            const SizedBox(height: 70), // Bottom padding for FAB
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedCategoryFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCategoryFilter = value),
    );
  }

  Widget _buildCoinPurseCard(
    PartyPurse purse,
    PartyPurseSplit split,
    TabletopColors tabletop,
    bool isDark,
  ) {
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
                const Icon(Icons.monetization_on, color: Color(0xFFF59E0B), size: 24),
                const SizedBox(width: 8),
                Text(
                  'Party Coin Vault',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '~${purse.totalGpEquivalent.toStringAsFixed(1)} GP',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFF59E0B)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // High-Contrast Coin Counters
            Row(
              children: [
                _buildCoinBadge('PP', purse.pp, const Color(0xFFCBD5E1), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge('GP', purse.gp, const Color(0xFFF59E0B), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge('EP', purse.ep, const Color(0xFF93C5FD), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge('SP', purse.sp, const Color(0xFFE2E8F0), isDark),
                const SizedBox(width: 6),
                _buildCoinBadge('CP', purse.cp, const Color(0xFFB45309), isDark),
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
                      roomCode: _roomCode,
                      playerName: _playerName,
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
                      roomCode: _roomCode,
                      playerName: _playerName,
                      isDeposit: false,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Live Party Share Calculator
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 6),
                const Text('Party Share Calculator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                DropdownButton<int>(
                  value: _partySplitCount,
                  isDense: true,
                  underline: const SizedBox(),
                  items: [2, 3, 4, 5, 6, 7, 8].map((n) {
                    return DropdownMenuItem(value: n, child: Text('$n Players'));
                  }).toList(),
                  onChanged: (val) => setState(() => _partySplitCount = val ?? 4),
                ),
              ],
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _includeLiquidatedInSplit,
              onChanged: (val) => setState(() => _includeLiquidatedInSplit = val ?? false),
              title: const Text('Include gems & art liquidation in split', style: TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Each Player Receives:',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  Text(
                    '~${split.perPlayerGpEquivalent.toStringAsFixed(1)} GP',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinBadge(String denomination, int amount, Color color, bool isDark) {
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
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$amount',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLootItemCard(PartyLootItem item, TabletopColors tabletop, bool isDark) {
    final theme = Theme.of(context);
    final isClaimedByMe = item.claimedByPlayer == _playerName;

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
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.count > 1 ? '${item.count}x ${item.name}' : item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                            ),
                          ),
                          if (item.requiresAttunement) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Attunement', style: TextStyle(color: Colors.white, fontSize: 9)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.gpValue} GP each (${item.totalGpValue} GP total)',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Soft-Delete (Trash) Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Move to Trash',
                  onPressed: () => _partyService.archiveLootItem(
                    roomCode: _roomCode,
                    lootId: item.id,
                    playerName: _playerName,
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
                    avatar: Icon(Icons.person, size: 14, color: isClaimedByMe ? Colors.white : null),
                    label: Text(
                      isClaimedByMe ? 'Claimed by You' : 'Claimed: ${item.claimedByPlayer}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isClaimedByMe ? Colors.white : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: isClaimedByMe ? Colors.green.shade700 : null,
                  )
                else
                  const Chip(
                    label: Text('In Vault (Unclaimed)', style: TextStyle(fontSize: 11)),
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
                    onPressed: () => _partyService.toggleAttunement(
                      roomCode: _roomCode,
                      lootId: item.id,
                      isAttuned: !item.isAttuned,
                      playerName: _playerName,
                    ),
                  ),
                const SizedBox(width: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    if (item.isClaimed) {
                      _partyService.claimLootItem(
                        roomCode: _roomCode,
                        lootId: item.id,
                        playerName: null,
                      );
                    } else {
                      _partyService.claimLootItem(
                        roomCode: _roomCode,
                        lootId: item.id,
                        playerName: _playerName,
                      );
                    }
                  },
                  child: Text(
                    item.isClaimed ? (isClaimedByMe ? 'Unclaim' : 'Take Claim') : 'Claim',
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

  Widget _buildDiceFeedTab(TabletopColors tabletop, bool isDark) {
    return StreamBuilder<List<RoomRoll>>(
      stream: _diceService.streamRoomRolls(_roomCode),
      builder: (context, snapshot) {
        final rolls = snapshot.data ?? [];

        if (rolls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.casino_outlined, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'No dice rolls logged yet for this room.\nRoll dice to broadcast in real time!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiceRollerScreen()),
                  ),
                  icon: const Icon(Icons.casino),
                  label: const Text('Open Dice Roller'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: rolls.length,
          itemBuilder: (context, index) {
            final roll = rolls[index];
            return _buildRollCard(roll, isDark);
          },
        );
      },
    );
  }

  Widget _buildRollCard(RoomRoll roll, bool isDark) {
    Color cardColor = isDark ? const Color(0xFF1E2230) : const Color(0xFFF8FAFC);
    Color totalColor = Colors.blueAccent;

    if (roll.isCrit) {
      totalColor = Colors.greenAccent.shade700;
    } else if (roll.isFumble) {
      totalColor = Colors.redAccent;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: totalColor.withValues(alpha: 0.2),
          child: Text(
            '${roll.total}',
            style: TextStyle(fontWeight: FontWeight.bold, color: totalColor),
          ),
        ),
        title: Row(
          children: [
            Text(roll.playerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            const SizedBox(width: 8),
            if (roll.isCrit)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                child: const Text('NAT 20', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            if (roll.isFumble)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: const Text('FUMBLE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text(
          '${roll.formulaString} (${roll.individualRolls.join(', ')})',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${roll.timestamp.hour.toString().padLeft(2, '0')}:${roll.timestamp.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 3: AUDIT HISTORY & HOST TRASH RESTORE
  // =========================================================================

  Widget _buildHistoryAndTrashTab(TabletopColors tabletop, bool isDark) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.history), text: 'Event Audit Log'),
              Tab(icon: Icon(Icons.delete_sweep_outlined), text: 'Vault Trash & Restore'),
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
      stream: _partyService.streamEvents(_roomCode),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const Center(child: Text('No events recorded in audit log yet.'));
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
            } else if (evt.type.contains('Restore') || evt.type.contains('Rehydrate')) {
              icon = Icons.restore;
              color = Colors.purple;
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
      stream: _partyService.streamLoot(_roomCode, includeArchived: true),
      builder: (context, snapshot) {
        final allItems = snapshot.data ?? [];
        final archivedItems = allItems.where((i) => i.isArchived).toList();

        if (archivedItems.isEmpty) {
          return const Center(child: Text('Trash is empty. No archived loot items.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: archivedItems.length,
          itemBuilder: (context, idx) {
            final item = archivedItems[idx];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.archive_outlined, color: Colors.grey),
                title: Text(item.name, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                subtitle: Text(
                  'Archived by ${item.archivedBy ?? 'Unknown'}${item.archivedAt != null ? ' • ${_formatDateTime(item.archivedAt!)}' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: _isDmOrCoDm
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.restore, size: 14),
                        label: const Text('Restore', style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final hostKey = _currentMembership?.hostKey ?? '';
                          try {
                            await _partyService.restoreLootItem(
                              roomCode: _roomCode,
                              lootId: item.id,
                              hostKey: hostKey,
                              playerName: _playerName,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Restored "${item.name}" to party vault!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to restore: $e')),
                              );
                            }
                          }
                        },
                      )
                    : const Tooltip(
                        message: 'Only DM / Co-DM can restore items',
                        child: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
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
