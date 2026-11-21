import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import '../../../services/haptic_service.dart';
import '../../../services/party/party_room_service.dart';
import '../../../services/persistence/character_persistence_service.dart';
import '../../../utils/crypto_utils.dart';

class JoinCampaignDialog extends StatefulWidget {
  final String? initialRoomCode;
  final Function(String roomCode)? onJoined;

  const JoinCampaignDialog({super.key, this.initialRoomCode, this.onJoined});

  static Future<void> show(BuildContext context,
      {String? initialRoomCode, Function(String roomCode)? onJoined}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => JoinCampaignDialog(
          initialRoomCode: initialRoomCode, onJoined: onJoined),
    );
  }

  @override
  State<JoinCampaignDialog> createState() => _JoinCampaignDialogState();
}

class _JoinCampaignDialogState extends State<JoinCampaignDialog> {
  late final TextEditingController _roomController;
  final _nameController = TextEditingController();
  final _existingSlotController = TextEditingController();
  final _passkeyController = TextEditingController();
  bool _isDmJoin = false;
  bool _isLoading = false;
  final PartyRoomService _partyService = PartyRoomService();
  final CharacterPersistenceService _characterService =
      CharacterPersistenceService();

  List<Character> _savedCharacters = [];
  Character? _selectedCharacter;
  bool _useSavedCharacter = true;
  bool _importAsNew = true;
  String? _selectedExistingSlot;
  List<String> _detectedRosterSlots = [];

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: widget.initialRoomCode ?? '');
    _roomController.addListener(_onRoomCodeChanged);
    _loadSavedCharacters();
  }

  void _onRoomCodeChanged() {
    final code = _roomController.text.trim().toUpperCase();
    final cached = _partyService.getCachedSession(code);
    if (cached != null && cached.characterRoster.isNotEmpty) {
      if (mounted) {
        setState(() {
          _detectedRosterSlots = cached.characterRoster;
          if (_selectedExistingSlot == null &&
              _detectedRosterSlots.isNotEmpty) {
            _selectedExistingSlot = _detectedRosterSlots.first;
          }
        });
      }
    }
  }

  Future<void> _loadSavedCharacters() async {
    final chars = await _characterService.loadCharacters();
    if (mounted) {
      setState(() {
        _savedCharacters = chars;
        if (chars.isNotEmpty) {
          _selectedCharacter = chars.first;
          _nameController.text = chars.first.name;
        }
      });
      _onRoomCodeChanged();
    }
  }

  @override
  void dispose() {
    _roomController.removeListener(_onRoomCodeChanged);
    _roomController.dispose();
    _nameController.dispose();
    _existingSlotController.dispose();
    _passkeyController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;

    final extractedKey = CryptoUtils.extractHostKey(text);
    if (extractedKey.isNotEmpty) {
      _passkeyController.text = extractedKey;
    } else {
      _passkeyController.text = text.trim();
    }

    // If room code is also present in copied block
    final roomMatch = RegExp(r'Room\s*:\s*([^\s\n\r]+)', caseSensitive: false)
        .firstMatch(text);
    if (roomMatch != null && _roomController.text.trim().isEmpty) {
      _roomController.text = roomMatch.group(1)!.trim().toUpperCase();
    }

    setState(() => _isDmJoin = true);
    if (mounted) {
      HapticService.selectionTick(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('DM Passkey pasted from clipboard!'),
            duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _submit() async {
    final roomCode = _roomController.text.trim().toUpperCase();
    final passkey = _isDmJoin ? _passkeyController.text.trim() : '';

    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code.')),
      );
      return;
    }

    final Character? linkedChar =
        (!_isDmJoin && _useSavedCharacter) ? _selectedCharacter : null;
    final String targetExistingSlot =
        _selectedExistingSlot ?? _existingSlotController.text.trim();

    String playerName;
    if (_isDmJoin) {
      playerName = _nameController.text.trim().isEmpty
          ? 'DM'
          : _nameController.text.trim();
    } else if (linkedChar != null) {
      playerName = _importAsNew
          ? linkedChar.name
          : (targetExistingSlot.isNotEmpty
              ? targetExistingSlot
              : linkedChar.name);
    } else {
      playerName = _nameController.text.trim().isEmpty
          ? 'Adventurer'
          : _nameController.text.trim();
    }

    setState(() => _isLoading = true);
    HapticService.selectionTick(context);

    try {
      final session = await _partyService.joinCampaign(
        roomCode: roomCode,
        playerName: playerName,
        hostKey: passkey.isNotEmpty ? passkey : null,
        characterId: linkedChar?.id.slug,
        characterSnapshot: linkedChar,
        existingRosterName: (!_importAsNew &&
                linkedChar != null &&
                targetExistingSlot.isNotEmpty)
            ? targetExistingSlot
            : null,
        isNewImport: _importAsNew || linkedChar == null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onJoined?.call(session.roomCode);
        final isDm = passkey.isNotEmpty;
        final linkMsg = linkedChar != null
            ? (_importAsNew
                ? ' (Linked "${linkedChar.name}")'
                : ' (Linked "${linkedChar.name}" to slot "$targetExistingSlot")')
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDm
                  ? 'Joined "${session.campaignName}" (${session.roomCode}) with DM privileges!'
                  : 'Joined "${session.campaignName}" (${session.roomCode})$linkMsg!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } on UnauthorizedHostActionException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on CampaignNotFoundException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error joining room: $e'),
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
          Icon(Icons.login, color: colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Join Existing Campaign',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the room code provided by your Dungeon Master to connect to the shared party vault and sync character loot.',
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              autofocus: widget.initialRoomCode == null ||
                  widget.initialRoomCode!.isEmpty,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                TextInputFormatter.withFunction((oldVal, newVal) =>
                    newVal.copyWith(text: newVal.text.toUpperCase())),
              ],
              decoration: InputDecoration(
                labelText: 'Room Code',
                hintText: 'e.g. ROOM-A1B2C3',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),

            // Character Linking Options (if not DM join)
            if (!_isDmJoin && _savedCharacters.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Character Vault Link',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Character?>(
                      initialValue:
                          _useSavedCharacter ? _selectedCharacter : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Character',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        ..._savedCharacters
                            .map((c) => DropdownMenuItem<Character?>(
                                  value: c,
                                  child: Text(
                                    '${c.name} (Lvl ${c.totalLevel} ${c.speciesRef.displayName})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                        const DropdownMenuItem<Character?>(
                          value: null,
                          child: Text('Custom / Guest Name (No Link)'),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          if (val == null) {
                            _useSavedCharacter = false;
                            _selectedCharacter = null;
                          } else {
                            _useSavedCharacter = true;
                            _selectedCharacter = val;
                            _nameController.text = val.name;
                          }
                        });
                      },
                    ),
                    if (_useSavedCharacter && _selectedCharacter != null) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Campaign Roster Placement:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _importAsNew = true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 2),
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
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      'Adds ${_selectedCharacter!.name} to campaign roster and shares sheet with DM',
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
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 2),
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
                                    const Text(
                                        'Link to existing character slot',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      'Take over an existing DM slot or hero name in the campaign',
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
                      if (!_importAsNew) ...[
                        const SizedBox(height: 6),
                        if (_detectedRosterSlots.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: _detectedRosterSlots
                                    .contains(_selectedExistingSlot)
                                ? _selectedExistingSlot
                                : _detectedRosterSlots.first,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Existing Campaign Character Slot',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _detectedRosterSlots
                                .map((slot) => DropdownMenuItem(
                                      value: slot,
                                      child: Text(slot),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedExistingSlot = val),
                          )
                        else
                          TextField(
                            controller: _existingSlotController,
                            decoration: InputDecoration(
                              labelText: 'Existing Character / Slot Name',
                              hintText: 'e.g. Valeros or Fighter 1',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!_useSavedCharacter || _isDmJoin) ...[
              TextField(
                controller: _nameController,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: _isDmJoin
                      ? 'Your DM / Display Name'
                      : 'Your Character / Player Name',
                  hintText: _isDmJoin
                      ? 'e.g. Dungeon Master'
                      : 'e.g. Rogar the Barbarian',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
            ],

            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() => _isDmJoin = !_isDmJoin);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      _isDmJoin
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: _isDmJoin
                          ? Colors.amber.shade700
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'I have a DM Passkey / Host Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isDmJoin
                              ? Colors.amber.shade800
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isDmJoin) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _passkeyController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'DM Passkey / Host Key',
                  hintText: 'Paste UUID or 6-word passkey',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, size: 20),
                    tooltip: 'Paste from clipboard',
                    onPressed: _pasteFromClipboard,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Grants full DM administrative privileges upon joining.',
                style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_isDmJoin ? Icons.vpn_key : Icons.login, size: 18),
          label: Text(_isDmJoin ? 'Join as DM' : 'Join Room'),
        ),
      ],
    );
  }
}

/// Dialog to Share DM Passkey via Raw Host Key
