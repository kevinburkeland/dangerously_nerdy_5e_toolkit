import 'package:material_ui/material_ui.dart';
import '../../../services/party/party_room_service.dart';

class SwitchActiveCharacterDialog extends StatefulWidget {
  final String roomCode;
  final String currentName;
  final List<String> roster;
  final ValueChanged<String>? onCharacterSelected;

  const SwitchActiveCharacterDialog({
    super.key,
    required this.roomCode,
    required this.currentName,
    this.roster = const [],
    this.onCharacterSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required String roomCode,
    required String currentName,
    List<String> roster = const [],
    ValueChanged<String>? onCharacterSelected,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => SwitchActiveCharacterDialog(
        roomCode: roomCode,
        currentName: currentName,
        roster: roster,
        onCharacterSelected: onCharacterSelected,
      ),
    );
  }

  @override
  State<SwitchActiveCharacterDialog> createState() =>
      _SwitchActiveCharacterDialogState();
}

class _SwitchActiveCharacterDialogState
    extends State<SwitchActiveCharacterDialog> {
  late final TextEditingController _nameController;
  final PartyRoomService _partyService = PartyRoomService();
  bool _addToRoster = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    await _partyService.setActiveCharacter(
      roomCode: widget.roomCode,
      characterName: cleanName,
    );

    if (_addToRoster && !widget.roster.contains(cleanName)) {
      await _partyService.addCharacterToRoster(
        roomCode: widget.roomCode,
        characterName: cleanName,
        playerName: cleanName,
      );
    }

    widget.onCharacterSelected?.call(cleanName);
    if (mounted) Navigator.pop(context, cleanName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.badge, color: Colors.blueAccent),
          SizedBox(width: 10),
          Expanded(
            child: Text('Select Active Character',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your active player or character identity for this campaign session.',
              style: TextStyle(
                  fontSize: 12.5, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Character / Player Name',
                hintText: 'e.g. Thorek Ironbreaker (Fighter)',
                prefixIcon: const Icon(Icons.person),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: _selectName,
            ),
            if (widget.roster.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Or Pick from Campaign Roster:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.roster.map((rName) {
                  final isCurrent = rName == widget.currentName;
                  return ActionChip(
                    avatar: Icon(Icons.shield,
                        size: 14, color: isCurrent ? Colors.white : null),
                    label: Text(rName),
                    backgroundColor: isCurrent ? colorScheme.primary : null,
                    labelStyle: TextStyle(
                      color: isCurrent ? colorScheme.onPrimary : null,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                    onPressed: () {
                      _nameController.text = rName;
                      _selectName(rName);
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _addToRoster,
              onChanged: (val) => setState(() => _addToRoster = val ?? true),
              title: const Text('Save to campaign party roster',
                  style: TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => _selectName(_nameController.text),
          child: const Text('Confirm Identity'),
        ),
      ],
    );
  }
}

