import 'package:material_ui/material_ui.dart';
import '../models/campaign_profile.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/session_graph_models.dart';
import '../providers/dm_dashboard_controller.dart';
import '../providers/settings_provider.dart';
import '../services/app_services.dart';
import '../services/logging_service.dart';
import '../services/haptic_service.dart';
import '../utils/secure_random.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../services/persistence/campaign_profile_service.dart';
import 'character_sheet_view.dart';
import '../presentation/widgets/room_connection_badge.dart';
import '../widgets/party/campaign_dialogs.dart';
import '../application/services/combat_encounter_service.dart';
import '../application/services/room_sync_orchestrator.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import '../infrastructure/di/injection_container.dart';
import '../presentation/screens/map/map_screen.dart';
import '../widgets/dm_dashboard/dm_campaign_dialogs.dart';
import '../widgets/dm_dashboard/dm_combat_tracker_card.dart';
import '../widgets/dm_dashboard/dm_encounter_dialogs.dart';
import '../widgets/dm_dashboard/dm_minions_card.dart';
import '../widgets/dm_dashboard/dm_party_vitality_card.dart';
import '../widgets/dm_dashboard/dm_pinned_rules_card.dart';
import '../widgets/dm_dashboard/dm_scratchpad_and_purse_card.dart';

/// Comprehensive Dungeon Master Command Console and multi-campaign dashboard.
class DmDashboardScreen extends StatefulWidget {
  final String? initialCampaignId;

  const DmDashboardScreen({
    super.key,
    this.initialCampaignId,
  });

  @override
  State<DmDashboardScreen> createState() => _DmDashboardScreenState();
}

class _DmDashboardScreenState extends State<DmDashboardScreen> {
  late final DmDashboardController _controller = () {
    final clock = sl<StatefulHlcClock>();
    return DmDashboardController(
      replicaId: clock.replicaId,
      clock: clock,
      campaignRepository: sl<ICampaignRepository>(),
      characterRepository:
          sl<ICharacterRepository>() as ICharacterRepository<Character>,
      combatEncounterService: sl<CombatEncounterService>(),
      roomSyncOrchestrator: sl<RoomSyncOrchestrator>(),
    );
  }();
  CampaignProfile? _activeProfile;
  bool _isLoading = true;
  int _currentRound = 1;
  final TextEditingController _notesController = TextEditingController();
  String? _lastLoadedProfileId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _loadData();
  }

  void _onControllerChanged() {
    if (mounted) {
      final active = _controller.activeProfile;
      if (active != null && active.id != _lastLoadedProfileId) {
        _lastLoadedProfileId = active.id;
        _notesController.text = active.notesMarkdown;
      }
      setState(() {
        _activeProfile = active;
        _isLoading = _controller.isLoading;
        _currentRound = _controller.currentRound;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _controller.loadData(initialCampaignId: widget.initialCampaignId);
  }

  void _persistActiveProfile({bool immediate = false}) {
    if (_activeProfile == null) return;
    _controller.updateNotes(_notesController.text, immediate: immediate);
  }

  void _onEditionChanged(DmRulesEdition newEdition) {
    if (_activeProfile == null) return;
    if (_activeProfile!.edition == newEdition) return;
    HapticService.selectionTick(context);
    SettingsScope.maybeOf(context)?.setRulesEdition(newEdition);
    _controller.changeEdition(newEdition);
  }

  // --- Campaign Switching & Lifecycle Actions ---


  Future<void> _showCampaignPicker() => showDmCampaignPickerSheet(
        context: context,
        activeProfile: _activeProfile,
        onSwitchCampaign: _switchCampaign,
        onCreateCampaign: _showCreateCampaignDialog,
        onCloneCampaign: _showCloneCampaignDialog,
        onDeleteCampaign: _showDeleteCampaignDialog,
      );

  Future<void> _showCreateCampaignDialog() => showDmCreateCampaignDialog(
        context: context,
        activeProfile: _activeProfile,
        controller: _controller,
        onReload: _loadData,
      );

  Future<void> _showCloneCampaignDialog(CampaignProfile profile) =>
      showDmCloneCampaignDialog(
        context: context,
        profile: profile,
        onReload: _loadData,
      );

  Future<void> _exportProfileSnapshot() => showDmExportProfileSnapshotDialog(
        context: context,
        activeProfile: _activeProfile,
        onPersistNotes: _persistActiveProfile,
      );

  Future<void> _importProfileSnapshot() => showDmImportProfileSnapshotDialog(
        context: context,
        onReload: _loadData,
      );

  Future<void> _showAddCombatantDialog() => showDmAddCombatantDialog(
        context: context,
        activeProfile: _activeProfile,
        onUpdateEncounter: _updateEncounter,
      );

  Future<void> _showAddSampleCharacterDialog() => showDmAddPartyMemberDialog(
        context: context,
        activeProfile: _activeProfile,
        controller: _controller,
      );

  Future<void> _showAddMinionDialog() => showDmAddMinionDialog(
        context: context,
        controller: _controller,
      );
  Future<void> _switchCampaign(String profileId) async {
    await _controller.switchProfile(profileId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to campaign: ${_activeProfile?.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showOpenPartyRoomDialog(CampaignProfile profile) async {
    await CreateCampaignDialog.show(
      context,
      linkProfileId: profile.id,
      initialCampaignName: profile.name,
      onCreated: (roomCode) async {
        await _loadData();
      },
    );
  }

  Future<void> _showDeleteCampaignDialog(CampaignProfile profile) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Campaign?'),
          content: Text(
              'Are you sure you want to permanently delete "${profile.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final service = AppServices.instance.campaignProfileService;
                try {
                  await service.deleteProfile(profile.id);
                  await _loadData();
                } on MapFilesNotRemovedException catch (e) {
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Removed. Map files on this device couldn't be deleted: ${e.cause}"),
                      ),
                    );
                  }
                } catch (e, st) {
                  LoggingService().logNonFatal(
                    e,
                    st,
                    reason: 'Failed to delete campaign profile',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to delete campaign from storage')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // --- Snapshot Export / Import ---

  void _nextTurn() {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    final updated = _controller.combatEncounterService.nextTurn(
      _activeProfile!.roomState.activeEncounterList,
      onNewRound: (round) {
        _controller.setRound(round);
        setState(() => _currentRound = round);
      },
      currentRound: _currentRound,
    );
    _updateEncounter(updated);
  }

  void _prevTurn() {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    final updated = _controller.combatEncounterService.prevTurn(
      _activeProfile!.roomState.activeEncounterList,
    );
    _updateEncounter(updated);
  }

  void _updateEncounter(List<EncounterParticipant> list) async {
    if (_activeProfile == null) return;
    await _controller.updateEncounter(list);
    if (!mounted) return;
    setState(() {
      _activeProfile = _controller.activeProfile;
    });
  }

  void _applyDamageOrHeal(String participantId, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    final updated =
        _controller.combatEncounterService.applyParticipantDamageOrHeal(
      participants: _activeProfile!.roomState.activeEncounterList,
      participantId: participantId,
      delta: delta > 0 ? delta - 1 : delta,
    );
    _updateEncounter(updated);
  }

  void _toggleCondition(String participantId, String conditionName) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    final updated =
        _controller.combatEncounterService.toggleParticipantCondition(
      participants: _activeProfile!.roomState.activeEncounterList,
      participantId: participantId,
      conditionName: conditionName,
    );
    _updateEncounter(updated);
  }

  void _rollAllInitiative() {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final participants = _activeProfile!.roomState.activeEncounterList.map((p) {
      final roll = secureRandom.nextInt(20) + 1;
      return p.copyWith(initiativeScore: roll);
    }).toList();

    participants.sort((a, b) => (b.initiativeScore ?? 0).compareTo(a.initiativeScore ?? 0));
    if (participants.isNotEmpty) {
      for (int i = 0; i < participants.length; i++) {
        participants[i] = participants[i].copyWith(isActiveTurn: i == 0);
      }
    }

    _updateEncounter(participants);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Rerolled initiative for all active combatants!')),
    );
  }

  // --- Party Roster & Character Management ---

  void _modifyCharacterHp(String characterId, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    _controller.modifyCharacterHp(characterId, delta);
  }

  void _toggleSpellSlot(String characterId, int level) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    _controller.toggleSpellSlot(characterId, level);
  }

  Future<void> _openCharacterSheet(Character char) async {
    final updated = await Navigator.push<Character?>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSheetView(
          character: char,
          isDmMode: true,
        ),
      ),
    );
    if (updated != null) {
      await _controller.updateCharacter(updated);
    } else {
      await _controller.reloadCharacter(char.id.slug);
    }
  }

  void _modifyMinionHp(String minionId, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    _controller.modifyMinionHp(minionId, delta);
  }

  void _modifyPurseCoin(String coinKey, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    _controller.modifyPartyPurseCoin(coinKey, delta);
  }

  void _modifyCharacterPurseCoin(
      String characterId, String coinKey, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    _controller.modifyCharacterPurseCoin(characterId, coinKey, delta);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading || _activeProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('DM Dashboard & Command Console')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final profile = _activeProfile!;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: InkWell(
          onTap: _showCampaignPicker,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    profile.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          // P2P Room Connection Telemetry Badge
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: RoomConnectionBadge(
              telemetryStream:
                  _controller.telemetryStream ?? const Stream.empty(),
            ),
          ),
          // Interactive Rules Edition Toggle (2014 RAW / 2024 Revised)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: RulesEditionToggle(
              currentEdition: profile.rulesEdition,
              isDense: true,
              showIcons: true,
              onEditionChanged: _onEditionChanged,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Campaign Snapshot',
            onPressed: _exportProfileSnapshot,
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Map',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MapScreen(
                    canEditMap: true,
                    characterNames: characterNamesFromTelemetry(_controller.remoteTelemetryMap),
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'open_room') _showOpenPartyRoomDialog(profile);
              if (val == 'switch') _showCampaignPicker();
              if (val == 'new') _showCreateCampaignDialog();
              if (val == 'clone') _showCloneCampaignDialog(profile);
              if (val == 'export') _exportProfileSnapshot();
              if (val == 'import') _importProfileSnapshot();
            },
            itemBuilder: (context) => [
              if (profile.roomState.roomCode.trim().isEmpty)
                const PopupMenuItem(
                    value: 'open_room', child: Text('Open Party Room...')),
              const PopupMenuItem(
                  value: 'switch', child: Text('Switch Campaign...')),
              const PopupMenuItem(value: 'new', child: Text('New Campaign...')),
              const PopupMenuItem(
                  value: 'clone', child: Text('Clone Campaign...')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                  value: 'export', child: Text('Export JSON Snapshot')),
              const PopupMenuItem(
                  value: 'import', child: Text('Import Snapshot...')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUnderConstructionBanner(theme, isDark),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                if (width >= 1200) {
                  // 3-Column Tactical HUD
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: _buildCombatInitiativeColumn()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 4, child: _buildPartyAndMinionsColumn()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 4, child: _buildRulesAndNotesColumn()),
                    ],
                  );
                } else if (width >= 800) {
                  // 2-Column Tactical HUD
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DmCombatTrackerCard(
      activeProfile: _activeProfile,
      currentRound: _currentRound,
      onPrevTurn: _prevTurn,
      onNextTurn: _nextTurn,
      onRollAllInitiative: _rollAllInitiative,
      onAddCombatant: _showAddCombatantDialog,
      onUpdateEncounter: _updateEncounter,
      onApplyDamageOrHeal: _applyDamageOrHeal,
      onToggleCondition: _toggleCondition,
    ),
                              const SizedBox(height: 12),
                              DmMinionsCard(
      controller: _controller,
      onAddMinion: _showAddMinionDialog,
      onModifyMinionHp: _modifyMinionHp,
    ),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DmPartyVitalityCard(
      controller: _controller,
      onAddPartyMember: _showAddSampleCharacterDialog,
      onOpenCharacterSheet: _openCharacterSheet,
      onModifyCharacterHp: _modifyCharacterHp,
      onToggleSpellSlot: _toggleSpellSlot,
      onModifyCharacterPurseCoin: _modifyCharacterPurseCoin,
    ),
                              const SizedBox(height: 12),
                              DmPinnedRulesCard(
      activeProfile: _activeProfile,
      controller: _controller,
    ),
                              const SizedBox(height: 12),
                              DmScratchpadAndPurseCard(
      controller: _controller,
      notesController: _notesController,
      onPersistNotes: _persistActiveProfile,
      onModifyPurseCoin: _modifyPurseCoin,
      onOpenCharacterSheet: _openCharacterSheet,
    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // 1-Column Mobile Layout
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DmCombatTrackerCard(
      activeProfile: _activeProfile,
      currentRound: _currentRound,
      onPrevTurn: _prevTurn,
      onNextTurn: _nextTurn,
      onRollAllInitiative: _rollAllInitiative,
      onAddCombatant: _showAddCombatantDialog,
      onUpdateEncounter: _updateEncounter,
      onApplyDamageOrHeal: _applyDamageOrHeal,
      onToggleCondition: _toggleCondition,
    ),
                        const SizedBox(height: 12),
                        DmPartyVitalityCard(
      controller: _controller,
      onAddPartyMember: _showAddSampleCharacterDialog,
      onOpenCharacterSheet: _openCharacterSheet,
      onModifyCharacterHp: _modifyCharacterHp,
      onToggleSpellSlot: _toggleSpellSlot,
      onModifyCharacterPurseCoin: _modifyCharacterPurseCoin,
    ),
                        const SizedBox(height: 12),
                        DmMinionsCard(
      controller: _controller,
      onAddMinion: _showAddMinionDialog,
      onModifyMinionHp: _modifyMinionHp,
    ),
                        const SizedBox(height: 12),
                        DmPinnedRulesCard(
      activeProfile: _activeProfile,
      controller: _controller,
    ),
                        const SizedBox(height: 12),
                        DmScratchpadAndPurseCard(
      controller: _controller,
      notesController: _notesController,
      onPersistNotes: _persistActiveProfile,
      onModifyPurseCoin: _modifyPurseCoin,
      onOpenCharacterSheet: _openCharacterSheet,
    ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderConstructionBanner(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2E2005) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.amber.shade700,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            '🚧',
            style: TextStyle(fontSize: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'UNDER CONSTRUCTION / PREVIEW MODE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: isDark
                            ? Colors.amberAccent
                            : const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'WIP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.amberAccent
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'The DM Command Console is undergoing active overhaul. Core character sheet systems and combat linking are currently in progress.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? Colors.amber.shade100
                        : const Color(0xFF78350F),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Multi-Column Sub-Layouts ---

  Widget _buildCombatInitiativeColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DmCombatTrackerCard(
      activeProfile: _activeProfile,
      currentRound: _currentRound,
      onPrevTurn: _prevTurn,
      onNextTurn: _nextTurn,
      onRollAllInitiative: _rollAllInitiative,
      onAddCombatant: _showAddCombatantDialog,
      onUpdateEncounter: _updateEncounter,
      onApplyDamageOrHeal: _applyDamageOrHeal,
      onToggleCondition: _toggleCondition,
    ),
        ],
      ),
    );
  }

  Widget _buildPartyAndMinionsColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DmPartyVitalityCard(
      controller: _controller,
      onAddPartyMember: _showAddSampleCharacterDialog,
      onOpenCharacterSheet: _openCharacterSheet,
      onModifyCharacterHp: _modifyCharacterHp,
      onToggleSpellSlot: _toggleSpellSlot,
      onModifyCharacterPurseCoin: _modifyCharacterPurseCoin,
    ),
          const SizedBox(height: 12),
          DmMinionsCard(
      controller: _controller,
      onAddMinion: _showAddMinionDialog,
      onModifyMinionHp: _modifyMinionHp,
    ),
        ],
      ),
    );
  }

  Widget _buildRulesAndNotesColumn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DmPinnedRulesCard(
      activeProfile: _activeProfile,
      controller: _controller,
    ),
          const SizedBox(height: 12),
          DmScratchpadAndPurseCard(
      controller: _controller,
      notesController: _notesController,
      onPersistNotes: _persistActiveProfile,
      onModifyPurseCoin: _modifyPurseCoin,
      onOpenCharacterSheet: _openCharacterSheet,
    ),
        ],
      ),
    );
  }

  // --- Widget 1: Live Combat & Initiative Tracker ---


}
