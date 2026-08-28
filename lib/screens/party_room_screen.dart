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

    _diceService.joinRoom(_roomCode, _playerName);
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
              // Party Roster & Character Management Button
              IconButton(
                icon: const Icon(Icons.groups, color: Colors.blueAccent),
                tooltip: 'Party Roster & Characters',
                onPressed: () => ManagePartyRosterDialog.show(
                  context,
                  roomCode: _roomCode,
                  currentName: _playerName,
                  initialRoster: session?.characterRoster ?? const [],
                  onActiveCharacterChanged: (newName) {
                    setState(() => _playerName = newName);
                  },
                ),
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
                  if (val == 'switchChar') {
                    SwitchActiveCharacterDialog.show(
                      context,
                      roomCode: _roomCode,
                      currentName: _playerName,
                      roster: session?.characterRoster ?? const [],
                      onCharacterSelected: (name) => setState(() => _playerName = name),
                    );
                  } else if (val == 'roster') {
                    ManagePartyRosterDialog.show(
                      context,
                      roomCode: _roomCode,
                      currentName: _playerName,
                      initialRoster: session?.characterRoster ?? const [],
                      onActiveCharacterChanged: (name) => setState(() => _playerName = name),
                    );
                  } else if (val == 'addLoot') {
                    AddLootItemDialog.show(context, roomCode: _roomCode, playerName: _playerName);
                  } else if (val == 'diceRoller') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DiceRollerScreen()));
                  } else if (val == 'passkey' && _currentMembership != null) {
                    ShareDmPasskeyDialog.show(context, _currentMembership!);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'switchChar',
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 18, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Switch Active Character'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'roster',
                    child: Row(
                      children: [
                        Icon(Icons.groups_outlined, size: 18, color: Colors.indigoAccent),
                        SizedBox(width: 8),
                        Text('Party Character Roster'),
                      ],
                    ),
                  ),
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
              _buildVaultTab(session, tabletop, isDark),
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

  Widget _buildVaultTab(PartySessionState? session, TabletopColors tabletop, bool isDark) {
    final purse = session?.partyPurse ?? const PartyPurse();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            // 0. ACTIVE CHARACTER & ROSTER BANNER
            _buildActiveCharacterBanner(session, colorScheme, isDark),
            const SizedBox(height: 14),

            // 1. COIN PURSE HERO CARD (SHARED PARTY VAULT / RESERVE)
            _buildCoinPurseCard(purse, split, session, tabletop, isDark, gemsAndArtTotal),
            const SizedBox(height: 14),

            // 1.5 INDIVIDUAL PARTY MEMBER GOLD STORES
            _buildMemberPursesCard(session, tabletop, colorScheme, isDark),
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
              ...filteredItems.map((item) => _buildLootItemCard(item, session, tabletop, isDark)),

            const SizedBox(height: 70), // Bottom padding for FAB
          ],
        );
      },
    );
  }

  Widget _buildActiveCharacterBanner(PartySessionState? session, ColorScheme colorScheme, bool isDark) {
    final roster = session?.characterRoster ?? const [];
    final myPurse = session?.getMemberPurse(_playerName) ?? const PartyPurse();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222738) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE CHARACTER / SESSION IDENTITY',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _playerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Switch', style: TextStyle(fontSize: 12)),
                onPressed: () => SwitchActiveCharacterDialog.show(
                  context,
                  roomCode: _roomCode,
                  currentName: _playerName,
                  roster: roster,
                  onCharacterSelected: (name) {
                    _diceService.joinRoom(_roomCode, name);
                    setState(() => _playerName = name);
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.groups_outlined, size: 20),
                tooltip: 'Party Roster',
                onPressed: () => ManagePartyRosterDialog.show(
                  context,
                  roomCode: _roomCode,
                  currentName: _playerName,
                  initialRoster: roster,
                  onActiveCharacterChanged: (name) {
                    _diceService.joinRoom(_roomCode, name);
                    setState(() => _playerName = name);
                  },
                ),
              ),
            ],
          ),

          // Personal Pouch summary for active character
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your Store: ~${myPurse.totalGpEquivalent.toStringAsFixed(1)} GP (${myPurse.pp} PP, ${myPurse.gp} GP, ${myPurse.ep} EP, ${myPurse.sp} SP, ${myPurse.cp} CP)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                InkWell(
                  onTap: () => MemberCoinTransactionDialog.show(
                    context,
                    roomCode: _roomCode,
                    characterName: _playerName,
                    performedBy: _playerName,
                    isDeposit: true,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('+Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => MemberCoinTransactionDialog.show(
                    context,
                    roomCode: _roomCode,
                    characterName: _playerName,
                    performedBy: _playerName,
                    isDeposit: false,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text('-Spend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
                ),
              ],
            ),
          ),

          if (roster.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Quick Roster Select (${roster.length}):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...roster.map((rName) {
                    final isCurrent = rName == _playerName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(
                          isCurrent ? Icons.check_circle : Icons.person_outline,
                          size: 14,
                          color: isCurrent ? Colors.white : colorScheme.primary,
                        ),
                        label: Text(rName, style: const TextStyle(fontSize: 11.5)),
                        selected: isCurrent,
                        selectedColor: colorScheme.primary,
                        onSelected: (selected) {
                          if (!isCurrent) {
                            _partyService.setActiveCharacter(
                              roomCode: _roomCode,
                              characterName: rName,
                            );
                            _diceService.joinRoom(_roomCode, rName);
                            setState(() => _playerName = rName);
                          }
                        },
                      ),
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: const Text('Add Member', style: TextStyle(fontSize: 11.5)),
                    onPressed: () => ManagePartyRosterDialog.show(
                      context,
                      roomCode: _roomCode,
                      currentName: _playerName,
                      initialRoster: roster,
                      onActiveCharacterChanged: (name) {
                        _diceService.joinRoom(_roomCode, name);
                        setState(() => _playerName = name);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberPursesCard(
    PartySessionState? session,
    TabletopColors tabletop,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final allMembers = <String>{
      if (session != null) ...session.characterRoster,
      if (session != null) ...session.activePlayers,
      if (session != null) ...session.memberPurses.keys,
    }.where((s) => s.trim().isNotEmpty).toList();

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
                const Icon(Icons.people_alt_outlined, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Character Gold Stores (${allMembers.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.currency_exchange, size: 14),
                  label: const Text('Disperse...', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    final purse = session?.partyPurse ?? const PartyPurse();
                    DisperseLootDialog.show(
                      context,
                      initialRoomCode: _roomCode,
                      purse: purse,
                      sourceTitle: 'Vault Funds',
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 14),
            ...allMembers.map((member) {
              final purse = session?.getMemberPurse(member) ?? const PartyPurse();
              final isMe = member == _playerName;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe
                      ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
                      : (isDark ? const Color(0xFF131622) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMe
                        ? colorScheme.primary.withValues(alpha: 0.4)
                        : (isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: isMe ? colorScheme.primary : Colors.grey.shade700,
                      child: const Icon(Icons.person, size: 14, color: Colors.white),
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
                                  fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
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
                        const PopupMenuItem(value: 'deposit', child: Text('Deposit Coins')),
                        const PopupMenuItem(value: 'withdraw', child: Text('Withdraw Coins')),
                        const PopupMenuItem(value: 'transfer_to_reserve', child: Text('Transfer to Party Reserve')),
                        const PopupMenuItem(value: 'withdraw_from_reserve', child: Text('Withdraw from Party Reserve')),
                      ],
                      onSelected: (action) {
                        if (action == 'deposit') {
                          MemberCoinTransactionDialog.show(
                            context,
                            roomCode: _roomCode,
                            characterName: member,
                            performedBy: _playerName,
                            isDeposit: true,
                          );
                        } else if (action == 'withdraw') {
                          MemberCoinTransactionDialog.show(
                            context,
                            roomCode: _roomCode,
                            characterName: member,
                            performedBy: _playerName,
                            isDeposit: false,
                          );
                        } else if (action == 'transfer_to_reserve') {
                          TransferCoinDialog.show(
                            context,
                            roomCode: _roomCode,
                            characterName: member,
                            performedBy: _playerName,
                            toReserve: true,
                          );
                        } else if (action == 'withdraw_from_reserve') {
                          TransferCoinDialog.show(
                            context,
                            roomCode: _roomCode,
                            characterName: member,
                            performedBy: _playerName,
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
    PartySessionState? session,
    TabletopColors tabletop,
    bool isDark, [
    double gemsAndArtTotal = 0.0,
  ]) {
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
                  'Party Coin Vault & Reserve',
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

            // Disperse Vault Funds Button
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.currency_exchange, size: 16),
                label: const Text('Disperse Vault Funds to Party...', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                onPressed: () => DisperseLootDialog.show(
                  context,
                  initialRoomCode: _roomCode,
                  purse: purse,
                  liquidatedGemsAndArtGp: gemsAndArtTotal,
                  sourceTitle: 'Party Vault Funds',
                ),
              ),
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
            if (session?.characterRoster.isNotEmpty == true && session!.characterRoster.length != _partySplitCount)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ActionChip(
                  avatar: const Icon(Icons.groups, size: 14),
                  label: Text('Set to Roster (${session.characterRoster.length} Players)', style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _partySplitCount = session.characterRoster.length),
                ),
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

  Widget _buildLootItemCard(PartyLootItem item, PartySessionState? session, TabletopColors tabletop, bool isDark) {
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
                              item.count > 1 ? '${item.name} (x${item.count})' : item.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          if (item.totalGpValue > 0)
                            Text(
                              '${item.totalGpValue.toStringAsFixed(0)} GP',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.categoryLabel,
                            style: TextStyle(fontSize: 12, color: categoryColor, fontWeight: FontWeight.bold),
                          ),
                          if (item.requiresAttunement) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Requires Attunement',
                                style: TextStyle(fontSize: 10.5, color: Colors.purple, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (item.sourceTableOrMonster != null && item.sourceTableOrMonster!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.sourceTableOrMonster!,
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                // Delete / Archive item button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Move to Vault Trash',
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
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                  tooltip: 'Assign to Character...',
                  onPressed: () async {
                    final chosen = await AssignLootDialog.show(
                      context,
                      itemName: item.name,
                      currentActiveName: _playerName,
                      roster: session?.characterRoster ?? const [],
                      activePlayers: session?.activePlayers ?? const [],
                    );
                    if (chosen == null) return;
                    if (chosen == '__unclaim__') {
                      await _partyService.claimLootItem(
                        roomCode: _roomCode,
                        lootId: item.id,
                        playerName: null,
                      );
                    } else {
                      await _partyService.claimLootItem(
                        roomCode: _roomCode,
                        lootId: item.id,
                        playerName: chosen,
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),
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
