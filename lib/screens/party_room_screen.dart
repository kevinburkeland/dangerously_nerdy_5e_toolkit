import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import '../models/party/campaign_membership.dart';
import '../models/party/party_session_state.dart';
import '../models/room_roll.dart';
import '../services/dice_room_service.dart';
import '../services/haptic_service.dart';
import '../services/party/campaign_registry_service.dart';
import '../services/party/party_room_service.dart';
import '../services/logging_service.dart';
import '../services/persistence/character_persistence_service.dart';
import 'dice_roller_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/party/campaign_dialogs.dart';
import 'dm_dashboard_screen.dart';
import '../infrastructure/di/injection_container.dart';
import 'package:vtt_engine_core/ports/i_p2p_transport_port.dart';
import '../application/services/room_connection_telemetry.dart';
import '../application/services/room_sync_orchestrator.dart';
import '../presentation/widgets/room_connection_badge.dart';
import '../application/services/room_session_starter.dart';
import '../presentation/screens/map/map_screen.dart';
import '../widgets/party_room/party_dice_feed_tab.dart';
import '../widgets/party_room/party_history_and_trash_tab.dart';
import '../widgets/party_room/party_room_dialogs.dart';
import '../widgets/party_room/party_vault_tab.dart';

/// Comprehensive multi-tab Party Room Screen featuring Shared Party Vault,
/// Coin Purse with Party Share distribution, Live Dice Feed, and History/Audit Log with Host Trash Recovery.
class PartyRoomScreen extends StatefulWidget {
  final String roomCode;
  final String? initialPlayerName;
  final PartyRoomService partyService;
  final CampaignRegistryService registry;
  final DiceRoomService diceService;
  final RoomSyncOrchestrator? orchestrator;
  final IP2pTransportPort? router;

  PartyRoomScreen({
    super.key,
    required this.roomCode,
    this.initialPlayerName,
    PartyRoomService? partyService,
    CampaignRegistryService? registry,
    DiceRoomService? diceService,
    this.orchestrator,
    this.router,
  })  : partyService = partyService ?? PartyRoomService(),
        registry = registry ?? CampaignRegistryService(),
        diceService = diceService ?? DiceRoomService();

  @override
  State<PartyRoomScreen> createState() => _PartyRoomScreenState();
}

class _PartyRoomScreenState extends State<PartyRoomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final PartyRoomService _partyService;
  late final CampaignRegistryService _registry;
  late final DiceRoomService _diceService;

  RoomSyncOrchestrator? _orchestrator;
  IP2pTransportPort? _router;
  Stream<RoomConnectionTelemetry>? _telemetryStream;

  late String _roomCode;
  late String _playerName;

  late Stream<List<RoomRoll>> _rollStream;

  StreamSubscription<ClaimConflictEvent>? _claimConflictSub;
  StreamSubscription<PurseOverdraftEvent>? _overdraftSub;

  // Filter state for vault items
  String _selectedCategoryFilter =
      'all'; // 'all', 'magicItem', 'gem_art', 'gear', 'claimed', 'unclaimed'
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
    _rollStream = _diceService.streamRoomRolls(_roomCode);
    _registry.updateLastPlayed(_roomCode);

    _initSyncServices();

    _claimConflictSub = _partyService.claimConflictStream.listen((event) {
      if (mounted && event.roomCode == _roomCode) {
        if (event.attemptedPlayer == _playerName) {
          HapticService.heavyImpact(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚡ "${event.itemName}" was already claimed by ${event.winnerPlayer} (first to server)',
              ),
              backgroundColor: Colors.deepOrange.shade800,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    _overdraftSub = _partyService.overdraftStream.listen((event) {
      if (mounted && event.roomCode == _roomCode && _isDmOrCoDm) {
        HapticService.mediumImpact(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Purse Overdraft: ${event.denomination} balance clamped to 0 after spend by ${event.playerName}.',
            ),
            backgroundColor: Colors.amber.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _initSyncServices() async {
    // Whenever someone opens or connects to the room, rehydrate and reset 30-day lease
    unawaited(() async {
      try {
        await _partyService.ensureRoomExists(
          roomCode: _roomCode,
          campaignName: _currentMembership?.campaignName,
          hostKey: _currentMembership?.hostKey,
        );
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'ensureRoomExists failed in PartyRoomScreen for $_roomCode',
        );
      }
    }());

    // Flush any pending outbox actions immediately upon entering the room
    unawaited(_partyService.flushOutbox(_roomCode));

    // Push active local character telemetry to room immediately upon entering
    try {
      final localChars = await CharacterPersistenceService().loadCharacters();
      final myChar = localChars
          .where((c) =>
              c.id.slug == _currentMembership?.characterId ||
              c.name.toLowerCase() == _playerName.toLowerCase())
          .firstOrNull;
      if (myChar != null) {
        unawaited(_partyService.linkCharacterToCampaign(
          roomCode: _roomCode,
          character: myChar,
          existingRosterName: _playerName,
          isNewImport: false,
        ));
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to link initial character in party room');
    }

    if (widget.orchestrator != null) {
      _orchestrator = widget.orchestrator;
      _router = widget.router;
      _telemetryStream = widget.orchestrator!.watchTelemetry();
      if (mounted) setState(() {});
      return;
    }

    final orchestrator = sl<RoomSyncOrchestrator>();
    _orchestrator = orchestrator;
    _router = widget.router ?? sl<IP2pTransportPort>();
    _telemetryStream = orchestrator.watchTelemetry();

    final localNodeId =
        '$_playerName-${_roomCode.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch % 100000}';
    if (_router != null) {
      unawaited(_router!.initializeRoom(_roomCode, localNodeId));
    }
    try {
      await _partyService.openRoomProfile(_roomCode);
      sl<RoomSessionStarter>().start(isHost: false);
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to open room profile for $_roomCode in PartyRoomScreen',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open room profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) setState(() {});
    return;
  }

  @override
  void didUpdateWidget(covariant PartyRoomScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cleanCode = widget.roomCode.trim().toUpperCase();
    if (oldWidget.roomCode.trim().toUpperCase() != cleanCode ||
        oldWidget.diceService != widget.diceService) {
      _diceService = widget.diceService;
      _roomCode = cleanCode;
      _rollStream = _diceService.streamRoomRolls(_roomCode);
    }
  }

  @override
  void dispose() {
    _orchestrator?.stopSynchronization();
    _router?.disconnect();
    _diceService.leaveRoom();
    _claimConflictSub?.cancel();
    _overdraftSub?.cancel();
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


  CampaignMembership? get _currentMembership =>
      _registry.getMembership(_roomCode);
  bool get _isDmOrCoDm => _currentMembership?.isDmOrCoDm ?? false;

  Future<void> _confirmLeaveCampaign(String campaignName) =>
      showConfirmLeaveCampaignDialog(
        context: context,
        campaignName: campaignName,
        roomCode: _roomCode,
        playerName: _playerName,
        partyService: _partyService,
      );

  Future<void> _confirmDeleteCampaign(String campaignName) =>
      showConfirmDeleteCampaignDialog(
        context: context,
        campaignName: campaignName,
        roomCode: _roomCode,
        currentMembership: _currentMembership,
        partyService: _partyService,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final tabletop = theme.extension<TabletopColors>() ??
        (isDark ? TabletopColors.dark : TabletopColors.light);

    return ValueListenableBuilder<List<CampaignMembership>>(
      valueListenable: _registry.membershipsNotifier,
      builder: (context, _, _) {
        return StreamBuilder<PartySessionState?>(
          stream: _partyService.streamSession(_roomCode),
          builder: (context, sessionSnap) {
            final session = sessionSnap.data;
            final campaignName = session?.campaignName ??
                _currentMembership?.campaignName ??
                'Party Room';

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
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isDmOrCoDm) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _currentMembership?.role == CampaignRole.host
                                  ? 'DM'
                                  : 'Co-DM',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
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
                          Flexible(
                            child: Text(
                              _roomCode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy,
                              size: 12, color: colorScheme.primary),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  // P2P Room Connection Telemetry Badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.sizeOf(context).width < 600 ? 110 : 200,
                      ),
                      child: RoomConnectionBadge(
                        compact: MediaQuery.sizeOf(context).width < 600,
                        telemetryStream: _telemetryStream ??
                            sl<RoomSyncOrchestrator>().watchTelemetry(),
                        initialTelemetry: _orchestrator?.currentTelemetry ??
                            sl<RoomSyncOrchestrator>().currentTelemetry,
                      ),
                    ),
                  ),
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
                            label: Text('Syncing ($count)',
                                style: const TextStyle(fontSize: 11)),
                            tooltip:
                                'Syncing $count pending update(s) to cloud. Tap to force sync now.',
                            onPressed: () =>
                                _partyService.flushOutbox(_roomCode),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  if (MediaQuery.sizeOf(context).width >= 600) ...[
                    // Link Character Button
                    IconButton(
                      icon: const Icon(Icons.link, color: Colors.tealAccent),
                      tooltip: 'Link Character to Campaign',
                      onPressed: () => LinkCampaignCharacterDialog.show(
                        context,
                        roomCode: _roomCode,
                        onLinked: () => setState(() {}),
                      ),
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
                    // Claim DM Passkey Button (if player)
                    if (!_isDmOrCoDm)
                      IconButton(
                        icon: const Icon(Icons.vpn_key_outlined,
                            color: Colors.amber),
                        tooltip: 'Claim DM / Enter Passkey',
                        onPressed: () => ClaimDmPasskeyDialog.show(
                          context,
                          initialRoomCode: _roomCode,
                          initialPlayerName: _playerName,
                        ),
                      ),
                    // DM Passkey Export Button (if DM)
                    if (_isDmOrCoDm && _currentMembership != null)
                      IconButton(
                        icon: const Icon(Icons.key, color: Colors.amber),
                        tooltip: 'Share DM Passkey',
                        onPressed: () => ShareDmPasskeyDialog.show(
                            context, _currentMembership!),
                      ),
                    // DM Dashboard / Console Direct Button (if DM)
                    if (_isDmOrCoDm)
                      IconButton(
                        icon: const Icon(Icons.dashboard_customize_outlined,
                            color: Colors.purpleAccent),
                        tooltip: 'Open DM Screen / Command Console',
                        onPressed: () {
                          HapticService.selectionTick(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DmDashboardScreen(
                                  initialCampaignId: 'campaign_$_roomCode'),
                            ),
                          );
                        },
                      ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    tooltip: 'Map',
                    onPressed: () async {
                      List<({String slug, String name})> localChars = const [];
                      try {
                        final loaded = await CharacterPersistenceService().loadCharacters();
                        localChars = loaded.map((c) => (slug: c.id.slug, name: c.name)).toList();
                      } catch (e, st) {
                        LoggingService().logNonFatal(e, st,
                            reason: 'Failed to load local characters for map');
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapScreen(
                            canEditMap: _isDmOrCoDm,
                            membershipCharacterId: _currentMembership?.characterId,
                            playerName: _playerName,
                            localCharacters: localChars,
                            characterNames: characterNamesFromTelemetry(session?.partyTelemetry ?? const {}),
                          ),
                        ),
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (val) {
                      if (val == 'dmDashboard') {
                        HapticService.selectionTick(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DmDashboardScreen(
                                initialCampaignId: 'campaign_$_roomCode'),
                          ),
                        );
                      } else if (val == 'linkChar') {
                        LinkCampaignCharacterDialog.show(
                          context,
                          roomCode: _roomCode,
                          onLinked: () => setState(() {}),
                        );
                      } else if (val == 'switchChar') {
                        SwitchActiveCharacterDialog.show(
                          context,
                          roomCode: _roomCode,
                          currentName: _playerName,
                          roster: session?.characterRoster ?? const [],
                          onCharacterSelected: (name) =>
                              setState(() => _playerName = name),
                        );
                      } else if (val == 'roster') {
                        ManagePartyRosterDialog.show(
                          context,
                          roomCode: _roomCode,
                          currentName: _playerName,
                          initialRoster: session?.characterRoster ?? const [],
                          onActiveCharacterChanged: (name) =>
                              setState(() => _playerName = name),
                        );
                      } else if (val == 'addLoot') {
                        AddLootItemDialog.show(context,
                            roomCode: _roomCode, playerName: _playerName);
                      } else if (val == 'diceRoller') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiceRollerScreen(
                              roomService: _diceService,
                            ),
                          ),
                        );
                      } else if (val == 'claimDm') {
                        ClaimDmPasskeyDialog.show(
                          context,
                          initialRoomCode: _roomCode,
                          initialPlayerName: _playerName,
                        );
                      } else if (val == 'passkey' &&
                          _currentMembership != null) {
                        ShareDmPasskeyDialog.show(context, _currentMembership!);
                      } else if (val == 'leaveCampaign') {
                        _confirmLeaveCampaign(campaignName);
                      } else if (val == 'deleteCampaign') {
                        _confirmDeleteCampaign(campaignName);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'linkChar',
                        child: Row(
                          children: [
                            Icon(Icons.link,
                                size: 18, color: Colors.tealAccent),
                            SizedBox(width: 8),
                            Text('Link Character'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'switchChar',
                        child: Row(
                          children: [
                            Icon(Icons.badge_outlined,
                                size: 18, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Switch Active Character'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'roster',
                        child: Row(
                          children: [
                            Icon(Icons.groups_outlined,
                                size: 18, color: Colors.indigoAccent),
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
                      if (!_isDmOrCoDm) ...[
                        const PopupMenuItem(
                          value: 'claimDm',
                          child: Row(
                            children: [
                              Icon(Icons.vpn_key_outlined,
                                  size: 18, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('Claim DM / Enter Passkey'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'leaveCampaign',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app,
                                  size: 18, color: Colors.orangeAccent),
                              SizedBox(width: 8),
                              Text('Leave Campaign',
                                  style: TextStyle(color: Colors.orangeAccent)),
                            ],
                          ),
                        ),
                      ],
                      if (_isDmOrCoDm) ...[
                        const PopupMenuItem(
                          value: 'dmDashboard',
                          child: Row(
                            children: [
                              Icon(Icons.dashboard_customize_outlined,
                                  size: 18, color: Colors.purpleAccent),
                              SizedBox(width: 8),
                              Text('Open DM Screen / Console'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'passkey',
                          child: Row(
                            children: [
                              Icon(Icons.key_outlined,
                                  size: 18, color: Colors.amber),
                              SizedBox(width: 8),
                              Text('Share DM Passkey'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'deleteCampaign',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever,
                                  size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Delete Campaign',
                                  style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: colorScheme.primary,
                  tabs: const [
                    Tab(
                        icon: Icon(Icons.shield_moon_outlined),
                        text: 'Party Vault'),
                    Tab(icon: Icon(Icons.casino_outlined), text: 'Dice Feed'),
                    Tab(
                        icon: Icon(Icons.history_edu),
                        text: 'Loot & Trash Log'),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  _KeepAliveTab(
                      child: PartyVaultTab(
                      session: session,
                      tabletop: tabletop,
                      isDark: isDark,
                      roomCode: _roomCode,
                      playerName: _playerName,
                      isDmOrCoDm: _isDmOrCoDm,
                      currentMembership: _currentMembership,
                      partyService: _partyService,
                      diceService: _diceService,
                      selectedCategoryFilter: _selectedCategoryFilter,
                      onCategoryFilterChanged: (val) =>
                          setState(() => _selectedCategoryFilter = val),
                      partySplitCount: _partySplitCount,
                      includeLiquidatedInSplit: _includeLiquidatedInSplit,
                      onSplitCountChanged: (val) =>
                          setState(() => _partySplitCount = val),
                      onIncludeLiquidatedChanged: (val) =>
                          setState(() => _includeLiquidatedInSplit = val),
                      onPlayerNameChanged: (name) => setState(() => _playerName = name),
                      onRefresh: () => setState(() {}),
                    )),
                  _KeepAliveTab(child: PartyDiceFeedTab(
                      tabletop: tabletop,
                      isDark: isDark,
                      roomCode: _roomCode,
                      rollStream: _rollStream,
                      diceService: _diceService,
                    )),
                  _KeepAliveTab(
                      child: PartyHistoryAndTrashTab(
                      tabletop: tabletop,
                      isDark: isDark,
                      roomCode: _roomCode,
                      playerName: _playerName,
                      isDmOrCoDm: _isDmOrCoDm,
                      currentMembership: _currentMembership,
                      partyService: _partyService,
                    )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // TAB 1: PARTY VAULT & COIN PURSE
  // =========================================================================


}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
