import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/animated_object.dart';
import '../models/arena/arena_condition.dart';
import '../models/campaign_profile.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/character_models.dart';
import '../models/domain/core_types.dart';
import '../models/domain/entity_reference.dart';
import '../models/domain/session_graph_models.dart';
import '../models/party/party_purse.dart';
import '../services/app_services.dart';
import '../services/haptic_service.dart';
import '../utils/secure_random.dart';
import '../widgets/dm_reference/dm_interactive_tools.dart';

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
  CampaignProfile? _activeProfile;
  List<CampaignProfile> _allProfiles = [];
  bool _isLoading = true;
  int _currentRound = 1;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = AppServices.instance.campaignProfileService;
    final profiles = await service.loadAllProfiles();

    CampaignProfile active;
    if (widget.initialCampaignId != null) {
      final req = widget.initialCampaignId!.trim().toUpperCase();
      active = profiles.where((p) {
            final pid = p.id.toUpperCase();
            final rcode = p.roomState.roomCode.toUpperCase();
            return pid == req || pid == 'CAMPAIGN_$req' || rcode == req;
          }).firstOrNull ??
          await service.getActiveProfile();
    } else {
      active = await service.getActiveProfile();
    }

    if (mounted) {
      setState(() {
        _allProfiles = profiles;
        _activeProfile = active;
        _notesController.text = active.notesMarkdown;
        _isLoading = false;
      });
    }
  }

  void _persistActiveProfile({bool immediate = false}) {
    if (_activeProfile == null) return;
    final updated = _activeProfile!.copyWith(
      notesMarkdown: _notesController.text,
      lastPlayedAt: DateTime.now(),
    );
    _activeProfile = updated;

    final service = AppServices.instance.campaignProfileService;
    if (immediate) {
      service.saveProfileImmediate(updated);
    } else {
      service.saveProfile(updated);
    }
  }

  // --- Campaign Switching & Lifecycle Actions ---

  Future<void> _showCampaignPicker() async {
    HapticService.selectionTick(context);
    final service = AppServices.instance.campaignProfileService;
    _allProfiles = await service.loadAllProfiles();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final theme = Theme.of(ctx);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.hub_outlined, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Campaign Workspaces',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'New Campaign Profile',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCreateCampaignDialog();
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _allProfiles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final prof = _allProfiles[i];
                        final isCurrent = prof.id == _activeProfile?.id;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCurrent
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              isCurrent ? Icons.check : Icons.book,
                              color: isCurrent
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            prof.name,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '${prof.edition.label} Edition • ${prof.partyRoster.length} Players • ${prof.roomState.activeEncounter.length} Encounter',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) async {
                              if (val == 'clone') {
                                Navigator.pop(ctx);
                                _showCloneCampaignDialog(prof);
                              } else if (val == 'delete') {
                                Navigator.pop(ctx);
                                _showDeleteCampaignDialog(prof);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'clone',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy, size: 18),
                                    SizedBox(width: 8),
                                    Text('Clone Workspace'),
                                  ],
                                ),
                              ),
                              if (_allProfiles.length > 1)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text('Delete Workspace', style: TextStyle(color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _switchCampaign(prof.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _switchCampaign(String profileId) async {
    final service = AppServices.instance.campaignProfileService;
    await service.switchProfile(profileId);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to campaign: ${_activeProfile?.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showCreateCampaignDialog() async {
    final nameCtrl = TextEditingController();
    DmRulesEdition edition = _activeProfile?.edition ?? DmRulesEdition.v2024;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Create Campaign Workspace'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Campaign Title',
                      hintText: 'e.g. Friday Night Campaign',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text('Rules Edition:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SegmentedButton<DmRulesEdition>(
                    segments: const [
                      ButtonSegment(value: DmRulesEdition.v2024, label: Text('2024 SRD')),
                      ButtonSegment(value: DmRulesEdition.v2014, label: Text('2014 RAW')),
                    ],
                    selected: {edition},
                    onSelectionChanged: (set) => setDlgState(() => edition = set.first),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final enteredName = nameCtrl.text.trim();
                    final finalName = enteredName.isNotEmpty ? enteredName : 'My Campaign';
                    Navigator.pop(ctx);
                    final newProf = CampaignProfile.defaultProfile(
                      name: finalName,
                      edition: edition,
                    );
                    final service = AppServices.instance.campaignProfileService;
                    await service.saveProfileImmediate(newProf);
                    await service.switchProfile(newProf.id);
                    await _loadData();
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCloneCampaignDialog(CampaignProfile profile) async {
    final nameCtrl = TextEditingController(text: '${profile.name} (Clone)');
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clone Campaign'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Cloned Campaign Title',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final service = AppServices.instance.campaignProfileService;
                await service.cloneProfile(profile.id, nameCtrl.text.trim());
                await _loadData();
              },
              child: const Text('Clone'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteCampaignDialog(CampaignProfile profile) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Campaign?'),
          content: Text('Are you sure you want to permanently delete "${profile.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                final service = AppServices.instance.campaignProfileService;
                await service.deleteProfile(profile.id);
                await _loadData();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // --- Snapshot Export / Import ---

  Future<void> _exportProfileSnapshot() async {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    _persistActiveProfile(immediate: true);

    final backupService = AppServices.instance.dmBackupService;
    final jsonStr = backupService.exportProfileJson(_activeProfile!);
    await backupService.downloadProfileSnapshot(_activeProfile!);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download, color: Colors.cyanAccent),
              SizedBox(width: 8),
              Text('Campaign Snapshot Ready'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Snapshot JSON generated. You can copy it directly or use the downloaded backup file:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy JSON'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Campaign snapshot JSON copied to clipboard!')),
                );
                Navigator.pop(ctx);
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importProfileSnapshot() async {
    HapticService.selectionTick(context);
    final textCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_upload_outlined, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Import Campaign Snapshot'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste the JSON content of an exported campaign snapshot:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '{\n  "schemaVersion": 1,\n  "type": "campaign_profile",\n  "campaign": { ... }\n}',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final raw = textCtrl.text.trim();
                Navigator.pop(ctx);
                final backupService = AppServices.instance.dmBackupService;
                final imported = await backupService.validateAndImportProfile(raw);
                if (imported != null) {
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Campaign "${imported.name}" successfully imported!')),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to import campaign: Invalid or corrupted snapshot JSON.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: const Text('Validate & Import'),
            ),
          ],
        );
      },
    );
  }

  // --- Combat & Turn Tracker Handlers ---

  void _nextTurn() {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    final participants = List<EncounterParticipant>.from(_activeProfile!.roomState.activeEncounter);
    if (participants.isEmpty) return;

    final activeIndex = participants.indexWhere((p) => p.isActiveTurn);
    int nextIndex = (activeIndex + 1) % participants.length;

    if (nextIndex == 0 && activeIndex != -1) {
      setState(() => _currentRound++);
    }

    final updated = participants.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;
      return p.copyWith(isActiveTurn: i == nextIndex);
    }).toList();

    _updateEncounter(updated);
  }

  void _prevTurn() {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);
    final participants = List<EncounterParticipant>.from(_activeProfile!.roomState.activeEncounter);
    if (participants.isEmpty) return;

    final activeIndex = participants.indexWhere((p) => p.isActiveTurn);
    int prevIndex = activeIndex <= 0 ? participants.length - 1 : activeIndex - 1;

    final updated = participants.asMap().entries.map((entry) {
      final i = entry.key;
      final p = entry.value;
      return p.copyWith(isActiveTurn: i == prevIndex);
    }).toList();

    _updateEncounter(updated);
  }

  void _updateEncounter(List<EncounterParticipant> list) {
    if (_activeProfile == null) return;
    final updatedRoom = _activeProfile!.roomState.copyWith(activeEncounter: list);
    setState(() {
      _activeProfile = _activeProfile!.copyWith(roomState: updatedRoom);
    });
    _persistActiveProfile();
  }

  void _applyDamageOrHeal(String participantId, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final participants = _activeProfile!.roomState.activeEncounter.map((p) {
      if (p.participantId != participantId) return p;

      if (delta < 0) {
        // Damage: Deplete Temp HP first
        int dmg = delta.abs();
        int curTemp = p.tempHp;
        int curHp = p.currentHp;

        if (curTemp > 0) {
          if (dmg <= curTemp) {
            curTemp -= dmg;
            dmg = 0;
          } else {
            dmg -= curTemp;
            curTemp = 0;
          }
        }

        curHp = (curHp - dmg).clamp(0, p.maxHp);
        final isDefeated = curHp <= 0;
        return p.copyWith(
          currentHp: curHp,
          tempHp: curTemp,
          isDefeated: isDefeated,
        );
      } else {
        // Healing: Clamp to maxHp, doesn't modify tempHp
        final curHp = (p.currentHp + delta).clamp(0, p.maxHp);
        return p.copyWith(
          currentHp: curHp,
          isDefeated: curHp <= 0,
        );
      }
    }).toList();

    _updateEncounter(participants);
  }

  void _toggleCondition(String participantId, String conditionName) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final participants = _activeProfile!.roomState.activeEncounter.map((p) {
      if (p.participantId != participantId) return p;
      final conditions = List<String>.from(p.activeConditions);
      if (conditions.contains(conditionName)) {
        conditions.remove(conditionName);
      } else {
        conditions.add(conditionName);
      }
      return p.copyWith(activeConditions: conditions);
    }).toList();

    _updateEncounter(participants);
  }

  Future<void> _showAddCombatantDialog() async {
    final nameCtrl = TextEditingController(text: 'Goblin Scout');
    final hpCtrl = TextEditingController(text: '15');
    final acCtrl = TextEditingController(text: '13');
    final initCtrl = TextEditingController(text: '12');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Combatant to Encounter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name / Label', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hpCtrl,
                      decoration: const InputDecoration(labelText: 'Max HP', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: acCtrl,
                      decoration: const InputDecoration(labelText: 'AC', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: initCtrl,
                      decoration: const InputDecoration(labelText: 'Initiative', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final hp = int.tryParse(hpCtrl.text.trim()) ?? 10;
                final ac = int.tryParse(acCtrl.text.trim()) ?? 10;
                final init = int.tryParse(initCtrl.text.trim()) ?? 10;

                final now = DateTime.now().millisecondsSinceEpoch;
                final newCombatant = EncounterParticipant(
                  participantId: 'p_$now',
                  entityLink: RoomEntityLink(
                    refType: SessionRefType.monster,
                    entityId: 'monster_$now',
                    displayName: name,
                  ),
                  initiativeScore: init,
                  currentHp: hp,
                  maxHp: hp,
                  armorClass: ac,
                  isActiveTurn: _activeProfile?.roomState.activeEncounter.isEmpty ?? true,
                );

                final list = List<EncounterParticipant>.from(_activeProfile?.roomState.activeEncounter ?? [])
                  ..add(newCombatant);
                // Sort by initiative descending
                list.sort((a, b) => b.initiativeScore.compareTo(a.initiativeScore));

                Navigator.pop(ctx);
                _updateEncounter(list);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _rollAllInitiative() {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final participants = _activeProfile!.roomState.activeEncounter.map((p) {
      final roll = secureRandom.nextInt(20) + 1;
      return p.copyWith(initiativeScore: roll);
    }).toList();

    participants.sort((a, b) => b.initiativeScore.compareTo(a.initiativeScore));
    if (participants.isNotEmpty) {
      for (int i = 0; i < participants.length; i++) {
        participants[i] = participants[i].copyWith(isActiveTurn: i == 0);
      }
    }

    _updateEncounter(participants);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rerolled initiative for all active combatants!')),
    );
  }

  // --- Party Roster & Character Management ---

  void _modifyCharacterHp(String characterId, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final roster = _activeProfile!.partyRoster.map((c) {
      if (c.id.slug != characterId) return c;
      final curHp = (c.resources.currentHp + delta).clamp(0, 999);
      final updatedPool = c.resources.copyWith(currentHp: curHp);
      return c.copyWith(resources: updatedPool);
    }).toList();

    setState(() {
      _activeProfile = _activeProfile!.copyWith(partyRoster: roster);
    });
    _persistActiveProfile();
  }

  void _toggleSpellSlot(String characterId, int level) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final roster = _activeProfile!.partyRoster.map((c) {
      if (c.id.slug != characterId) return c;
      final maxSlots = c.resources.spellSlots.maxSlots[level] ?? 0;
      if (maxSlots <= 0) return c;

      final current = c.resources.spellSlots.currentSlots[level] ?? maxSlots;
      final next = current <= 0 ? maxSlots : current - 1;

      final updatedCur = Map<int, int>.from(c.resources.spellSlots.currentSlots);
      updatedCur[level] = next;

      final updatedPool = c.resources.copyWith(
        spellSlots: c.resources.spellSlots.copyWith(currentSlots: updatedCur),
      );
      return c.copyWith(resources: updatedPool);
    }).toList();

    setState(() {
      _activeProfile = _activeProfile!.copyWith(partyRoster: roster);
    });
    _persistActiveProfile();
  }

  Future<void> _showAddSampleCharacterDialog() async {
    final nameCtrl = TextEditingController(text: 'Valeros the Fighter');
    final levelCtrl = TextEditingController(text: '3');
    final acCtrl = TextEditingController(text: '16');
    final hpCtrl = TextEditingController(text: '28');
    final wisCtrl = TextEditingController(text: '12');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Character to Party Roster'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Character Name', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: levelCtrl,
                      decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: acCtrl,
                      decoration: const InputDecoration(labelText: 'AC', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hpCtrl,
                      decoration: const InputDecoration(labelText: 'Max HP', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: wisCtrl,
                      decoration: const InputDecoration(labelText: 'WIS Score', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final lvl = int.tryParse(levelCtrl.text.trim()) ?? 1;
                final hp = int.tryParse(hpCtrl.text.trim()) ?? 10;
                final wis = int.tryParse(wisCtrl.text.trim()) ?? 10;

                final now = DateTime.now().millisecondsSinceEpoch;
                final char = Character(
                  id: EntityId(slug: 'char_$now', ruleset: RulesetVersion.homebrew),
                  name: name,
                  speciesRef: const EntityReference(slug: 'human', refType: EntityType.species, displayName: 'Human'),
                  progression: CharacterProgression(
                    classes: [
                      ClassLevelProgression(
                        classRef: const EntityReference(slug: 'fighter', refType: EntityType.classDefinition, displayName: 'Fighter'),
                        level: lvl,
                        hitDie: 'd10',
                      ),
                    ],
                  ),
                  baseScores: AbilityScores(
                    strength: 16,
                    dexterity: 14,
                    constitution: 14,
                    intelligence: 10,
                    wisdom: wis,
                    charisma: 8,
                  ),
                  resources: CharacterResourcePool(
                    currentHp: hp,
                    spellSlots: SpellSlotPool(
                      maxSlots: lvl >= 3 ? const {1: 4, 2: 2} : const {},
                      currentSlots: lvl >= 3 ? const {1: 4, 2: 2} : const {},
                    ),
                  ),
                );

                final roster = List<Character>.from(_activeProfile?.partyRoster ?? [])..add(char);
                setState(() {
                  _activeProfile = _activeProfile!.copyWith(partyRoster: roster);
                });
                _persistActiveProfile();
                Navigator.pop(ctx);
              },
              child: const Text('Add Hero'),
            ),
          ],
        );
      },
    );
  }

  // --- Minions & Animated Objects Handlers ---

  void _modifyMinionHp(String minionId, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final minions = _activeProfile!.activeMinions.map((m) {
      if (m.id != minionId) return m;
      if (delta < 0) {
        m.takeDamage(delta.abs());
      } else {
        m.heal(delta);
      }
      return m;
    }).toList();

    setState(() {
      _activeProfile = _activeProfile!.copyWith(activeMinions: minions);
    });
    _persistActiveProfile();
  }

  Future<void> _showAddMinionDialog() async {
    ObjectSize selectedSize = ObjectSize.medium;
    final nameCtrl = TextEditingController(text: 'Animated Table');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Summon / Animate Object'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Minion Name', border: OutlineInputBorder()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  const Text('Size Classification:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ObjectSize.values.map((s) {
                      return ChoiceChip(
                        label: Text('${s.displayName} (HP ${s.maxHp})'),
                        selected: selectedSize == s,
                        selectedColor: s.accentColor.withValues(alpha: 0.3),
                        onSelected: (_) => setDlgState(() => selectedSize = s),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final minion = AnimatedObjectInstance(
                      id: 'minion_$now',
                      name: name,
                      size: selectedSize,
                      currentHp: selectedSize.maxHp,
                      maxHp: selectedSize.maxHp,
                    );

                    final minions = List<AnimatedObjectInstance>.from(_activeProfile?.activeMinions ?? [])..add(minion);
                    setState(() {
                      _activeProfile = _activeProfile!.copyWith(activeMinions: minions);
                    });
                    _persistActiveProfile();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Summon'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Party Purse Adjustments ---

  void _modifyPurseCoin(String coinKey, int delta) {
    if (_activeProfile == null) return;
    HapticService.selectionTick(context);

    final roster = List<Character>.from(_activeProfile!.partyRoster);
    if (roster.isNotEmpty) {
      final first = roster.first;
      final curPurse = first.purse;
      final newPurse = PartyPurse(
        cp: coinKey == 'cp' ? (curPurse.cp + delta).clamp(0, 999999) : curPurse.cp,
        sp: coinKey == 'sp' ? (curPurse.sp + delta).clamp(0, 999999) : curPurse.sp,
        ep: coinKey == 'ep' ? (curPurse.ep + delta).clamp(0, 999999) : curPurse.ep,
        gp: coinKey == 'gp' ? (curPurse.gp + delta).clamp(0, 999999) : curPurse.gp,
        pp: coinKey == 'pp' ? (curPurse.pp + delta).clamp(0, 999999) : curPurse.pp,
      );
      roster[0] = first.copyWith(purse: newPurse);
      setState(() {
        _activeProfile = _activeProfile!.copyWith(partyRoster: roster);
      });
      _persistActiveProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryAccent = theme.colorScheme.primary;

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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          // Rules Edition Toggle Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.edition.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryAccent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.auto_stories, size: 14, color: primaryAccent),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Campaign Snapshot',
            onPressed: _exportProfileSnapshot,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'switch') _showCampaignPicker();
              if (val == 'new') _showCreateCampaignDialog();
              if (val == 'clone') _showCloneCampaignDialog(profile);
              if (val == 'export') _exportProfileSnapshot();
              if (val == 'import') _importProfileSnapshot();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'switch', child: Text('Switch Campaign...')),
              const PopupMenuItem(value: 'new', child: Text('New Campaign...')),
              const PopupMenuItem(value: 'clone', child: Text('Clone Campaign...')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'export', child: Text('Export JSON Snapshot')),
              const PopupMenuItem(value: 'import', child: Text('Import Snapshot...')),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
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
                        _buildCombatTrackerCard(),
                        const SizedBox(height: 12),
                        _buildMinionsCard(),
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
                        _buildPartyVitalityCard(),
                        const SizedBox(height: 12),
                        _buildPinnedRulesCard(),
                        const SizedBox(height: 12),
                        _buildScratchpadAndPurseCard(),
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
                  _buildCombatTrackerCard(),
                  const SizedBox(height: 12),
                  _buildPartyVitalityCard(),
                  const SizedBox(height: 12),
                  _buildMinionsCard(),
                  const SizedBox(height: 12),
                  _buildPinnedRulesCard(),
                  const SizedBox(height: 12),
                  _buildScratchpadAndPurseCard(),
                ],
              ),
            );
          }
        },
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
          _buildCombatTrackerCard(),
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
          _buildPartyVitalityCard(),
          const SizedBox(height: 12),
          _buildMinionsCard(),
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
          _buildPinnedRulesCard(),
          const SizedBox(height: 12),
          _buildScratchpadAndPurseCard(),
        ],
      ),
    );
  }

  // --- Widget 1: Live Combat & Initiative Tracker ---

  Widget _buildCombatTrackerCard() {
    final theme = Theme.of(context);
    final participants = _activeProfile!.roomState.activeEncounter;

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
                const Icon(Icons.sports_kabaddi, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Combat & Turn Tracker',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Round $_currentRound',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.skip_previous, size: 16),
                  label: const Text('Prev'),
                  onPressed: participants.isNotEmpty ? _prevTurn : null,
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('Next Turn'),
                  onPressed: participants.isNotEmpty ? _nextTurn : null,
                ),
                IconButton(
                  icon: const Icon(Icons.casino, size: 20),
                  tooltip: 'Reroll All Initiative',
                  onPressed: participants.isNotEmpty ? _rollAllInitiative : null,
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  tooltip: 'Add Combatant',
                  onPressed: _showAddCombatantDialog,
                ),
              ],
            ),
            const Divider(height: 20),
            if (participants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined, size: 36, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 8),
                      Text(
                        'No active encounter participants.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Combatant'),
                        onPressed: _showAddCombatantDialog,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: participants.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = participants[i];
                  return _buildParticipantTile(p);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile(EncounterParticipant p) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = p.isActiveTurn;
    final hpPercent = (p.currentHp / (p.maxHp > 0 ? p.maxHp : 1)).clamp(0.0, 1.0);
    final hpColor = hpPercent > 0.5
        ? Colors.greenAccent
        : (hpPercent > 0.2 ? Colors.amberAccent : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.4)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isActive ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Init ${p.initiativeScore}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.entityLink.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: p.isDefeated ? Colors.redAccent : theme.colorScheme.onSurface,
                    decoration: p.isDefeated ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'AC ${p.armorClass}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  final list = List<EncounterParticipant>.from(_activeProfile!.roomState.activeEncounter)
                    ..removeWhere((item) => item.participantId == p.participantId);
                  _updateEncounter(list);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          // HP Bar & Quick Modifier Chips
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HP: ${p.currentHp}/${p.maxHp}${p.tempHp > 0 ? " (+${p.tempHp} Temp)" : ""}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: hpColor),
                        ),
                        Text('${(hpPercent * 100).toInt()}%', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: hpPercent,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick Damage / Heal Chips
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildHpModifierChip('-10', -10, p.participantId, Colors.redAccent),
              _buildHpModifierChip('-5', -5, p.participantId, Colors.redAccent),
              _buildHpModifierChip('-1', -1, p.participantId, Colors.redAccent),
              _buildHpModifierChip('+1', 1, p.participantId, Colors.greenAccent),
              _buildHpModifierChip('+5', 5, p.participantId, Colors.greenAccent),
              _buildHpModifierChip('+10', 10, p.participantId, Colors.greenAccent),
              PopupMenuButton<ArenaCondition>(
                icon: const Icon(Icons.add_alert, size: 16),
                tooltip: 'Add Condition',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onSelected: (cond) => _toggleCondition(p.participantId, cond.name),
                itemBuilder: (context) => ArenaCondition.values.map((c) {
                  return PopupMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 16, color: c.colorTheme),
                        const SizedBox(width: 8),
                        Text(c.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (p.activeConditions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: p.activeConditions.map((condName) {
                final cond = ArenaCondition.fromName(condName);
                return Chip(
                  avatar: cond != null ? Icon(cond.icon, size: 12, color: cond.colorTheme) : null,
                  label: Text(cond?.label ?? condName, style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onDeleted: () => _toggleCondition(p.participantId, condName),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHpModifierChip(String label, int delta, String participantId, Color color) {
    return InkWell(
      onTap: () => _applyDamageOrHeal(participantId, delta),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // --- Widget 2: Party Vitality HUD ---

  Widget _buildPartyVitalityCard() {
    final theme = Theme.of(context);
    final roster = _activeProfile!.partyRoster;

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
                const Icon(Icons.shield_moon, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Party Vitality HUD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt, size: 20),
                  tooltip: 'Add Party Member',
                  onPressed: _showAddSampleCharacterDialog,
                ),
              ],
            ),
            const Divider(height: 20),
            if (roster.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Hero to Party Roster'),
                    onPressed: _showAddSampleCharacterDialog,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: roster.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final char = roster[i];
                  return _buildCharacterVitalityTile(char);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterVitalityTile(Character char) {
    final theme = Theme.of(context);
    final curHp = char.resources.currentHp;
    final wisMod = char.baseScores.getModifier(AbilityType.wisdom);
    final isProficient = char.skillProficiencies.containsKey(SkillType.perception);
    final passivePerception = 10 + wisMod + (isProficient ? char.proficiencyBonus : 0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      char.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Lvl ${char.totalLevel} • AC 16 • Pass. Percept: $passivePerception',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                onPressed: () => _modifyCharacterHp(char.id.slug, -5),
              ),
              Text(
                '$curHp HP',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.greenAccent),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.greenAccent),
                onPressed: () => _modifyCharacterHp(char.id.slug, 5),
              ),
            ],
          ),
          // Spell Slots Matrix if caster
          if (char.resources.spellSlots.maxSlots.values.any((s) => s > 0)) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: List.generate(9, (slotIndex) {
                final level = slotIndex + 1;
                final max = char.resources.spellSlots.maxSlots[level] ?? 0;
                if (max <= 0) return const SizedBox.shrink();
                final current = char.resources.spellSlots.currentSlots[level] ?? max;

                return InkWell(
                  onTap: () => _toggleSpellSlot(char.id.slug, level),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'L$level: $current/$max',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // --- Widget 3: Minion & Summon HUD ---

  Widget _buildMinionsCard() {
    final theme = Theme.of(context);
    final minions = _activeProfile!.activeMinions;

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
                const Icon(Icons.pets, color: Colors.deepOrangeAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Minion & Summon Tracker',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 20),
                  tooltip: 'Summon Minion / Object',
                  onPressed: _showAddMinionDialog,
                ),
              ],
            ),
            const Divider(height: 20),
            if (minions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Animate Object / Minion'),
                    onPressed: _showAddMinionDialog,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: minions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = minions[i];
                  return _buildMinionTile(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinionTile(AnimatedObjectInstance m) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: m.accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: m.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              m.size.displayName,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: m.accentColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  'AC ${m.ac} • Dmg: ${m.damageFormula}',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Colors.redAccent),
            onPressed: () => _modifyMinionHp(m.id, -5),
          ),
          Text(
            '${m.currentHp}/${m.maxHp}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: Colors.greenAccent),
            onPressed: () => _modifyMinionHp(m.id, 5),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () {
              final updated = List<AnimatedObjectInstance>.from(_activeProfile!.activeMinions)
                ..removeWhere((item) => item.id == m.id);
              setState(() {
                _activeProfile = _activeProfile!.copyWith(activeMinions: updated);
              });
              _persistActiveProfile();
            },
          ),
        ],
      ),
    );
  }

  // --- Widget 4: Quick-Pinned DM Rules & Embedded Tools ---

  Widget _buildPinnedRulesCard() {
    final theme = Theme.of(context);
    final pinned = _activeProfile!.pinnedRuleIds;
    const allItems = DmScreenLibrary.allItems;
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
                const Icon(Icons.push_pin, color: Colors.lightGreenAccent, size: 22),
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
                  '${pinnedItems.length} Pinned',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
          ],
        ),
      ),
    );
  }

  // --- Widget 5: Live Session Markdown Scratchpad & Purse Tracker ---

  Widget _buildScratchpadAndPurseCard() {
    final theme = Theme.of(context);
    final roster = _activeProfile!.partyRoster;
    final purse = roster.isNotEmpty ? roster.first.purse : const PartyPurse();

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
                const Icon(Icons.note_alt_outlined, color: Colors.pinkAccent, size: 22),
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
              ],
            ),
            const Divider(height: 16),
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
                  _buildCoinColumn('PP', purse.pp, () => _modifyPurseCoin('pp', 1), () => _modifyPurseCoin('pp', -1)),
                  _buildCoinColumn('GP', purse.gp, () => _modifyPurseCoin('gp', 10), () => _modifyPurseCoin('gp', -10)),
                  _buildCoinColumn('EP', purse.ep, () => _modifyPurseCoin('ep', 1), () => _modifyPurseCoin('ep', -1)),
                  _buildCoinColumn('SP', purse.sp, () => _modifyPurseCoin('sp', 10), () => _modifyPurseCoin('sp', -10)),
                  _buildCoinColumn('CP', purse.cp, () => _modifyPurseCoin('cp', 10), () => _modifyPurseCoin('cp', -10)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'DM Scratchpad & Session Notes',
                hintText: 'Type running notes, secrets, clues, loot...',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _persistActiveProfile(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoinColumn(String label, int count, VoidCallback onAdd, VoidCallback onSub) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
        Text('$count', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
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
