import 'package:material_ui/material_ui.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../../../screens/character_sheet_view.dart';
import '../../../services/logging_service.dart';
import '../../../services/party/party_room_service.dart';
import '../../../services/persistence/character_persistence_service.dart';

// ===========================================================================
// 8. MANAGE PARTY ROSTER DIALOG
// ===========================================================================

class ManagePartyRosterDialog extends StatefulWidget {
  final String roomCode;
  final String currentName;
  final List<String> initialRoster;
  final ValueChanged<String>? onActiveCharacterChanged;

  const ManagePartyRosterDialog({
    super.key,
    required this.roomCode,
    required this.currentName,
    required this.initialRoster,
    this.onActiveCharacterChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomCode,
    required String currentName,
    required List<String> initialRoster,
    ValueChanged<String>? onActiveCharacterChanged,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ManagePartyRosterDialog(
        roomCode: roomCode,
        currentName: currentName,
        initialRoster: initialRoster,
        onActiveCharacterChanged: onActiveCharacterChanged,
      ),
    );
  }

  @override
  State<ManagePartyRosterDialog> createState() =>
      _ManagePartyRosterDialogState();
}

class _ManagePartyRosterDialogState extends State<ManagePartyRosterDialog> {
  final PartyRoomService _partyService = PartyRoomService();
  final TextEditingController _addController = TextEditingController();
  late List<String> _roster;

  @override
  void initState() {
    super.initState();
    _roster = List<String>.from(widget.initialRoster);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addCharacter() async {
    final text = _addController.text.trim();
    if (text.isEmpty || _roster.contains(text)) return;
    setState(() => _roster.add(text));
    _addController.clear();

    await _partyService.addCharacterToRoster(
      roomCode: widget.roomCode,
      characterName: text,
      playerName: widget.currentName,
    );
  }

  Future<void> _removeCharacter(String name) async {
    setState(() => _roster.remove(name));
    await _partyService.removeCharacterFromRoster(
      roomCode: widget.roomCode,
      characterName: name,
      playerName: widget.currentName,
    );
  }

  Future<void> _playAs(String name) async {
    await _partyService.setActiveCharacter(
      roomCode: widget.roomCode,
      characterName: name,
    );
    widget.onActiveCharacterChanged?.call(name);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _openSheetForRosterCharacter(String name) async {
    // 1. Check local device persistence first
    final localChars = await CharacterPersistenceService().loadCharacters();
    Character? targetChar = localChars
        .where((c) =>
            c.name.toLowerCase() == name.toLowerCase() || c.id.slug == name)
        .firstOrNull;

    // 2. Fall back to sharedCharacters only if not present locally
    final session = _partyService.getCachedSession(widget.roomCode);
    if (targetChar == null &&
        session != null &&
        session.sharedCharacters.isNotEmpty) {
      final rawMap = session.sharedCharacters[name];
      if (rawMap != null) {
        try {
          targetChar = Character.fromMap(rawMap);
        } catch (e, st) {
          LoggingService().logNonFatal(e, st,
              reason: 'Failed to deserialize character from sharedCharacters');
        }
      }
    }

    if (!mounted) return;

    final updated = await Navigator.push<Character?>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSheetView(
          character: targetChar,
          isDmMode: true,
        ),
      ),
    );

    // 3. Reload latest from persistence and sync to room
    final localCharsAfter =
        await CharacterPersistenceService().loadCharacters();
    final latestChar = localCharsAfter
            .where((c) =>
                c.name.toLowerCase() == name.toLowerCase() ||
                c.id.slug == (targetChar?.id.slug ?? name))
            .firstOrNull ??
        updated ??
        targetChar;

    if (latestChar != null) {
      await _partyService.linkCharacterToCampaign(
        roomCode: widget.roomCode,
        character: latestChar,
        existingRosterName: name,
        isNewImport: false,
      );
      await _partyService.updateCharacterTelemetry(
        roomCode: widget.roomCode,
        character: latestChar,
        existingRosterName: name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.groups, color: Colors.indigoAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text('Party Character Roster',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: const InputDecoration(
                      labelText: 'Add Character / Player',
                      hintText: 'e.g. Sylas (Ranger)',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCharacter(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addCharacter,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_roster.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'No characters in roster yet. Add your party members above!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _roster.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final name = _roster[idx];
                    final isCurrent = name == widget.currentName;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCurrent ? Icons.person_pin : Icons.shield_outlined,
                        color: isCurrent ? Colors.green : colorScheme.primary,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                      subtitle: isCurrent
                          ? const Text('Active Session Character',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.green))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.badge_outlined,
                                size: 18, color: Colors.blueAccent),
                            tooltip: 'View Character Sheet',
                            onPressed: () => _openSheetForRosterCharacter(name),
                          ),
                          if (!isCurrent)
                            TextButton(
                              onPressed: () => _playAs(name),
                              child: const Text('Play As',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                size: 16, color: Colors.grey),
                            tooltip: 'Remove from Roster',
                            onPressed: () => _removeCharacter(name),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
            onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

// ===========================================================================
// 9. ASSIGN LOOT ITEM DIALOG
// ===========================================================================

