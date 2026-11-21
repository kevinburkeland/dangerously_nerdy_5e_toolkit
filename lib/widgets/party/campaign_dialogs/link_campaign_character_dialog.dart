import 'package:material_ui/material_ui.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../../../services/haptic_service.dart';
import '../../../services/party/party_room_service.dart';
import '../../../services/persistence/character_persistence_service.dart';

/// Dialog to Link or Switch a Saved Character to an active Campaign Room
class LinkCampaignCharacterDialog extends StatefulWidget {
  final String roomCode;
  final VoidCallback? onLinked;

  const LinkCampaignCharacterDialog({
    super.key,
    required this.roomCode,
    this.onLinked,
  });

  static Future<void> show(BuildContext context,
      {required String roomCode, VoidCallback? onLinked}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) =>
          LinkCampaignCharacterDialog(roomCode: roomCode, onLinked: onLinked),
    );
  }

  @override
  State<LinkCampaignCharacterDialog> createState() =>
      _LinkCampaignCharacterDialogState();
}

class _LinkCampaignCharacterDialogState
    extends State<LinkCampaignCharacterDialog> {
  final PartyRoomService _partyService = PartyRoomService();
  final CharacterPersistenceService _characterService =
      CharacterPersistenceService();

  List<Character> _savedCharacters = [];
  Character? _selectedCharacter;
  bool _importAsNew = true;
  String? _selectedExistingSlot;
  List<String> _rosterSlots = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final chars = await _characterService.loadCharacters();
    final session = _partyService.getCachedSession(widget.roomCode);
    if (mounted) {
      setState(() {
        _savedCharacters = chars;
        if (chars.isNotEmpty) {
          _selectedCharacter = chars.first;
        }
        if (session != null) {
          _rosterSlots = session.characterRoster;
          if (_rosterSlots.isNotEmpty) {
            _selectedExistingSlot = _rosterSlots.first;
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCharacter == null) return;
    setState(() => _isLoading = true);
    HapticService.selectionTick(context);

    try {
      await _partyService.linkCharacterToCampaign(
        roomCode: widget.roomCode,
        character: _selectedCharacter!,
        existingRosterName: !_importAsNew ? _selectedExistingSlot : null,
        isNewImport: _importAsNew,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onLinked?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Linked "${_selectedCharacter!.name}" to campaign room!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed linking character: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.link, color: colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Link Character to Campaign',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link a character from your vault to "${widget.roomCode}". This shares your stats with the DM and automatically syncs gold and claimed loot to your sheet.',
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_savedCharacters.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No saved characters found in your vault. Create a character first in the Character Builder.',
                  style: TextStyle(color: colorScheme.error, fontSize: 13),
                ),
              )
            else ...[
              DropdownButtonFormField<Character>(
                initialValue: _selectedCharacter,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Select Character',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: _savedCharacters
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                              '${c.name} (Lvl ${c.totalLevel} ${c.speciesRef.displayName})'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCharacter = val),
              ),
              const SizedBox(height: 14),
              const Text('Campaign Roster Mode:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _importAsNew = true),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        _importAsNew
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: _importAsNew
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Import as new character',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              'Adds ${_selectedCharacter?.name ?? "character"} as a new hero in the campaign roster',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _importAsNew = false),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        !_importAsNew
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: !_importAsNew
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Link to existing character slot',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              'Associate with a pre-existing roster name in the room',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_importAsNew && _rosterSlots.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _rosterSlots.contains(_selectedExistingSlot)
                      ? _selectedExistingSlot
                      : _rosterSlots.first,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Existing Campaign Character Slot',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _rosterSlots
                      .map((slot) =>
                          DropdownMenuItem(value: slot, child: Text(slot)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedExistingSlot = val),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: const Icon(Icons.link, size: 18),
          label: Text(_isLoading ? 'Linking...' : 'Link Character'),
          onPressed:
              (_isLoading || _selectedCharacter == null) ? null : _submit,
        ),
      ],
    );
  }
}
