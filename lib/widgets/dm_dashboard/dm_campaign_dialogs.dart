import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/campaign_profile.dart';
import '../../models/dm_screen_data.dart';
import '../../services/app_services.dart';
import '../../services/haptic_service.dart';
import '../../providers/dm_dashboard_controller.dart';
import '../../services/logging_service.dart';
import '../dm_reference/rules_edition_toggle.dart';

Future<void> showDmCampaignPickerSheet({
  required BuildContext context,
  required CampaignProfile? activeProfile,
  required Future<void> Function(String profileId) onSwitchCampaign,
  required VoidCallback onCreateCampaign,
  required void Function(CampaignProfile profile) onCloneCampaign,
  required void Function(CampaignProfile profile) onDeleteCampaign,
}) async {
    List<CampaignProfile> allProfiles = [];
    HapticService.selectionTick(context);
    final service = AppServices.instance.campaignProfileService;
    try {
      allProfiles = await service.loadAllProfiles();
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to load campaigns for campaign picker',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load campaigns from storage')),
        );
      }
      return;
    }

    if (!context.mounted) return;

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
                      Icon(Icons.hub_outlined,
                          color: theme.colorScheme.primary),
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
                          onCreateCampaign();
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: allProfiles.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final prof = allProfiles[i];
                        final isCurrent = prof.id == activeProfile?.id;
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
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '${prof.roomState.roomCode.isNotEmpty ? prof.roomState.roomCode : "no room"} • ${prof.rulesEdition.label} Edition • ${prof.partyCharacterIds.length} Players • ${prof.roomState.activeEncounterList.length} Encounter',
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) async {
                              if (val == 'clone') {
                                Navigator.pop(ctx);
                                onCloneCampaign(prof);
                              } else if (val == 'delete') {
                                Navigator.pop(ctx);
                                onDeleteCampaign(prof);
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
                              if (allProfiles.length > 1)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: Colors.redAccent),
                                      SizedBox(width: 8),
                                      Text('Delete Workspace',
                                          style: TextStyle(
                                              color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);
                            await onSwitchCampaign(prof.id);
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


Future<void> showDmCreateCampaignDialog({
  required BuildContext context,
  required CampaignProfile? activeProfile,
  required DmDashboardController controller,
  required Future<void> Function() onReload,
}) async {
    final nameCtrl = TextEditingController();
    DmRulesEdition edition = activeProfile?.rulesEdition ?? DmRulesEdition.v2024;

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
                  const Text('Rules Edition:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  RulesEditionToggle(
                    currentEdition: edition,
                    isExpanded: true,
                    showIcons: true,
                    showSubtext: true,
                    onEditionChanged: (newEdition) =>
                        setDlgState(() => edition = newEdition),
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
                    final finalName =
                        enteredName.isNotEmpty ? enteredName : 'My Campaign';
                    Navigator.pop(ctx);
                    final newProf = CampaignProfile.defaultProfile(
                      name: finalName,
                      edition: edition,
                      nodeId: controller.nodeId,
                      clock: controller.clock,
                    );
                    final service = AppServices.instance.campaignProfileService;
                    try {
                      await service.saveProfileImmediate(newProf);
                      await service.switchProfile(newProf.id);
                      await onReload();
                    } catch (e, st) {
                      LoggingService().logNonFatal(
                        e,
                        st,
                        reason: 'Failed to create and save new campaign profile',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to save campaign to storage')),
                        );
                      }
                    }
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


Future<void> showDmCloneCampaignDialog({
  required BuildContext context,
  required CampaignProfile profile,
  required Future<void> Function() onReload,
}) async {
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
                try {
                  await service.cloneProfile(profile.id, nameCtrl.text.trim());
                  await onReload();
                } catch (e, st) {
                  LoggingService().logNonFatal(
                    e,
                    st,
                    reason: 'Failed to clone campaign profile',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to clone campaign to storage')),
                    );
                  }
                }
              },
              child: const Text('Clone'),
            ),
          ],
        );
      },
    );
  }


Future<void> showDmExportProfileSnapshotDialog({
  required BuildContext context,
  required CampaignProfile? activeProfile,
  required void Function({bool immediate}) onPersistNotes,
}) async {
    if (activeProfile == null) return;
    HapticService.selectionTick(context);
    onPersistNotes(immediate: true);

    final backupService = AppServices.instance.dmBackupService;
    final jsonStr = backupService.exportProfileJson(activeProfile);
    await backupService.downloadProfileSnapshot(activeProfile);

    if (!context.mounted) return;

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
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 11),
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
                  const SnackBar(
                      content:
                          Text('Campaign snapshot JSON copied to clipboard!')),
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


Future<void> showDmImportProfileSnapshotDialog({
  required BuildContext context,
  required Future<void> Function() onReload,
}) async {
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
                  hintText:
                      '{\n  "schemaVersion": 1,\n  "type": "campaign_profile",\n  "campaign": { ... }\n}',
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
                final imported =
                    await backupService.validateAndImportProfile(raw);
                if (imported != null) {
                  await onReload();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Campaign "${imported.name}" successfully imported!')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Failed to import campaign: Invalid or corrupted snapshot JSON.'),
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


