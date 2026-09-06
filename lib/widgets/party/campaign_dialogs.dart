import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/domain/character_models.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/party/party_loot_item.dart';
import '../../models/party/party_purse.dart';
import '../../models/party/party_session_state.dart';
import '../../services/persistence/character_persistence_service.dart';
import '../../services/party/campaign_registry_service.dart';
import '../../services/party/party_room_service.dart';
import '../../utils/crypto_utils.dart';
import '../../services/haptic_service.dart';

/// Dialog to explicitly Create a New Campaign Room
class CreateCampaignDialog extends StatefulWidget {
  final Function(String roomCode)? onCreated;

  const CreateCampaignDialog({super.key, this.onCreated});

  static Future<void> show(BuildContext context, {Function(String roomCode)? onCreated}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CreateCampaignDialog(onCreated: onCreated),
    );
  }

  @override
  State<CreateCampaignDialog> createState() => _CreateCampaignDialogState();
}

class _CreateCampaignDialogState extends State<CreateCampaignDialog> {
  final _campaignController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void dispose() {
    _campaignController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final campaignName = _campaignController.text.trim();
    final playerName = _nameController.text.trim();

    if (campaignName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a campaign name.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticService.selectionTick(context);

    try {
      final session = await _partyService.createCampaign(
        campaignName: campaignName,
        playerName: playerName.isEmpty ? 'DM' : playerName,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated?.call(session.roomCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Campaign "${session.campaignName}" created! Room Code: ${session.roomCode}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create campaign: $e')),
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
          Icon(Icons.add_circle_outline, color: colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Create New Campaign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a live campaign party vault and shared dice room. A secure 6-character room code and private DM passkey will be generated automatically.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _campaignController,
              autofocus: true,
              maxLength: 60,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Campaign / Party Name',
                hintText: 'e.g. Crown of the Dragon King, Vault of Winter',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Your DM / Display Name',
                hintText: 'e.g. Dungeon Master Kevin',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 18),
          label: const Text('Create Campaign'),
        ),
      ],
    );
  }
}

/// Dialog to explicitly Join an Existing Campaign Room
class JoinCampaignDialog extends StatefulWidget {
  final String? initialRoomCode;
  final Function(String roomCode)? onJoined;

  const JoinCampaignDialog({super.key, this.initialRoomCode, this.onJoined});

  static Future<void> show(BuildContext context, {String? initialRoomCode, Function(String roomCode)? onJoined}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => JoinCampaignDialog(initialRoomCode: initialRoomCode, onJoined: onJoined),
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
  final CharacterPersistenceService _characterService = CharacterPersistenceService();

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
          if (_selectedExistingSlot == null && _detectedRosterSlots.isNotEmpty) {
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
    final roomMatch = RegExp(r'Room\s*:\s*([^\s\n\r]+)', caseSensitive: false).firstMatch(text);
    if (roomMatch != null && _roomController.text.trim().isEmpty) {
      _roomController.text = roomMatch.group(1)!.trim().toUpperCase();
    }

    setState(() => _isDmJoin = true);
    if (mounted) {
      HapticService.selectionTick(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DM Passkey pasted from clipboard!'), duration: Duration(seconds: 1)),
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

    final Character? linkedChar = (!_isDmJoin && _useSavedCharacter) ? _selectedCharacter : null;
    final String targetExistingSlot = _selectedExistingSlot ?? _existingSlotController.text.trim();

    String playerName;
    if (_isDmJoin) {
      playerName = _nameController.text.trim().isEmpty ? 'DM' : _nameController.text.trim();
    } else if (linkedChar != null) {
      playerName = _importAsNew
          ? linkedChar.name
          : (targetExistingSlot.isNotEmpty ? targetExistingSlot : linkedChar.name);
    } else {
      playerName = _nameController.text.trim().isEmpty ? 'Adventurer' : _nameController.text.trim();
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
        existingRosterName: (!_importAsNew && linkedChar != null && targetExistingSlot.isNotEmpty)
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
          SnackBar(content: Text('Error joining room: $e'), backgroundColor: Colors.redAccent),
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
          const Text('Join Existing Campaign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the room code provided by your Dungeon Master to connect to the shared party vault and sync character loot.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              autofocus: widget.initialRoomCode == null || widget.initialRoomCode!.isEmpty,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                TextInputFormatter.withFunction((oldVal, newVal) => newVal.copyWith(text: newVal.text.toUpperCase())),
              ],
              decoration: InputDecoration(
                labelText: 'Room Code',
                hintText: 'e.g. ROOM-A1B2C3',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),

            // Character Linking Options (if not DM join)
            if (!_isDmJoin && _savedCharacters.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_pin, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Character Vault Link',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Character?>(
                      initialValue: _useSavedCharacter ? _selectedCharacter : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Character',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: [
                        ..._savedCharacters.map((c) => DropdownMenuItem<Character?>(
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
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _importAsNew = true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            children: [
                              Icon(
                                _importAsNew ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 18,
                                color: _importAsNew ? colorScheme.primary : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Import as new character', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(
                                      'Adds ${_selectedCharacter!.name} to campaign roster and shares sheet with DM',
                                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            children: [
                              Icon(
                                !_importAsNew ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 18,
                                color: !_importAsNew ? colorScheme.primary : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Link to existing character slot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text(
                                      'Take over an existing DM slot or hero name in the campaign',
                                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
                            initialValue: _detectedRosterSlots.contains(_selectedExistingSlot)
                                ? _selectedExistingSlot
                                : _detectedRosterSlots.first,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Existing Campaign Character Slot',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: _detectedRosterSlots
                                .map((slot) => DropdownMenuItem(
                                      value: slot,
                                      child: Text(slot),
                                    ))
                                .toList(),
                            onChanged: (val) => setState(() => _selectedExistingSlot = val),
                          )
                        else
                          TextField(
                            controller: _existingSlotController,
                            decoration: InputDecoration(
                              labelText: 'Existing Character / Slot Name',
                              hintText: 'e.g. Valeros or Fighter 1',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  labelText: _isDmJoin ? 'Your DM / Display Name' : 'Your Character / Player Name',
                  hintText: _isDmJoin ? 'e.g. Dungeon Master' : 'e.g. Rogar the Barbarian',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                      _isDmJoin ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20,
                      color: _isDmJoin ? Colors.amber.shade700 : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'I have a DM Passkey / Host Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isDmJoin ? Colors.amber.shade800 : colorScheme.onSurface,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_isDmJoin ? Icons.vpn_key : Icons.login, size: 18),
          label: Text(_isDmJoin ? 'Join as DM' : 'Join Room'),
        ),
      ],
    );
  }
}

/// Dialog to Share DM Passkey via 6-Word Mnemonic or Raw Key
class ShareDmPasskeyDialog extends StatelessWidget {
  final CampaignMembership membership;

  const ShareDmPasskeyDialog({super.key, required this.membership});

  static void show(BuildContext context, CampaignMembership membership) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ShareDmPasskeyDialog(membership: membership),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hostKey = membership.hostKey ?? '';
    final mnemonic = CryptoUtils.encodeHostKeyToMnemonic(hostKey);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.key, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('DM Passkey Delegation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this passwordless passkey with a Co-DM or secondary device to grant administrative rights (rehydrating dormant campaigns, restoring trash items, and resetting party funds).',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text('6-Word Mnemonic Passkey:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                mnemonic,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Room Code:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(
              membership.roomCode,
              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text('Raw Cryptographic Host Key:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            SelectableText(
              hostKey,
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'Room: ${membership.roomCode}\nPasskey Mnemonic: $mnemonic\nHostKey: $hostKey'));
            HapticService.lightImpact(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('DM Passkey copied to clipboard!')),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 6),
              Text('Copy Passkey'),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Dialog to Enter a DM Passkey / Host Key to Claim DM or Co-DM Rights
class ClaimDmPasskeyDialog extends StatefulWidget {
  final String? initialRoomCode;
  final String? initialPlayerName;
  final Function(CampaignMembership membership)? onClaimed;
  final Function(CampaignMembership membership)? onImported;

  const ClaimDmPasskeyDialog({
    super.key,
    this.initialRoomCode,
    this.initialPlayerName,
    this.onClaimed,
    this.onImported,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialRoomCode,
    String? initialPlayerName,
    Function(CampaignMembership)? onClaimed,
    Function(CampaignMembership)? onImported,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ClaimDmPasskeyDialog(
        initialRoomCode: initialRoomCode,
        initialPlayerName: initialPlayerName,
        onClaimed: onClaimed ?? onImported,
      ),
    );
  }

  @override
  State<ClaimDmPasskeyDialog> createState() => _ClaimDmPasskeyDialogState();
}

/// Backward-compatible alias for ClaimDmPasskeyDialog
typedef ImportDmPasskeyDialog = ClaimDmPasskeyDialog;

class _ClaimDmPasskeyDialogState extends State<ClaimDmPasskeyDialog> {
  late final TextEditingController _roomController;
  late final TextEditingController _nameController;
  final _passkeyController = TextEditingController();
  CampaignRole _selectedRole = CampaignRole.host;
  bool _isLoading = false;
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: widget.initialRoomCode ?? '');
    _nameController = TextEditingController(text: widget.initialPlayerName ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
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

    final roomMatch = RegExp(r'Room\s*:\s*([^\s\n\r]+)', caseSensitive: false).firstMatch(text);
    if (roomMatch != null && _roomController.text.trim().isEmpty) {
      _roomController.text = roomMatch.group(1)!.trim().toUpperCase();
    }

    if (mounted) {
      HapticService.selectionTick(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DM Passkey pasted from clipboard!'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _submit() async {
    final roomCode = _roomController.text.trim().toUpperCase();
    final passkey = _passkeyController.text.trim();
    final playerName = _nameController.text.trim();

    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code.')),
      );
      return;
    }

    if (passkey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the DM passkey.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticService.selectionTick(context);

    try {
      final membership = await _partyService.claimDmRole(
        roomCode: roomCode,
        hostKeyOrPasskey: passkey,
        targetRole: _selectedRole,
        playerName: playerName.isNotEmpty ? playerName : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onClaimed?.call(membership);
        widget.onImported?.call(membership);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedRole == CampaignRole.host ? "Dungeon Master" : "Co-DM"} privileges activated for "${membership.campaignName}" (${membership.roomCode})!',
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
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
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
          Icon(Icons.vpn_key, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('Claim DM / Co-DM Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the private DM passkey or host key provided by the campaign creator to unlock administrative authority (restoring deleted loot, resetting party funds, resolving cloud sync conflicts, and delegating passkeys).',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              autofocus: widget.initialRoomCode == null || widget.initialRoomCode!.isEmpty,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Room Code',
                hintText: 'e.g. ROOM-A1B2C3',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passkeyController,
              autofocus: widget.initialRoomCode != null && widget.initialRoomCode!.isNotEmpty,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'DM Passkey / Host Key',
                hintText: 'Paste UUID or 6-word mnemonic passkey',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste, size: 20),
                  tooltip: 'Paste from clipboard',
                  onPressed: _pasteFromClipboard,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your DM / Display Name (Optional)',
                hintText: 'e.g. Dungeon Master Kevin',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Role: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('DM / Host'),
                  selected: _selectedRole == CampaignRole.host,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedRole = CampaignRole.host);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Co-DM'),
                  selected: _selectedRole == CampaignRole.coDm,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedRole = CampaignRole.coDm);
                  },
                ),
              ],
            ),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.vpn_key, size: 18),
          label: const Text('Claim DM Role'),
        ),
      ],
    );
  }
}

/// Dialog to Add a Custom Loot Item to the Vault
class AddLootItemDialog extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const AddLootItemDialog({super.key, required this.roomCode, required this.playerName});

  static Future<void> show(BuildContext context, {required String roomCode, required String playerName}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AddLootItemDialog(roomCode: roomCode, playerName: playerName),
    );
  }

  @override
  State<AddLootItemDialog> createState() => _AddLootItemDialogState();
}

class _AddLootItemDialogState extends State<AddLootItemDialog> {
  final _nameController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _gpController = TextEditingController(text: '0');
  String _category = 'gear';
  bool _requiresAttunement = false;
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _gpController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final count = int.tryParse(_countController.text) ?? 1;
    final gp = double.tryParse(_gpController.text) ?? 0.0;
    final itemId = 'loot_${DateTime.now().millisecondsSinceEpoch}_${name.replaceAll(RegExp(r'\W+'), '_').toLowerCase()}';

    final item = PartyLootItem(
      id: itemId,
      name: name,
      category: _category,
      count: count.clamp(1, 9999),
      gpValue: gp.clamp(0.0, 9999999.0),
      requiresAttunement: _requiresAttunement,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );

    _partyService.addLootItem(
      roomCode: widget.roomCode,
      playerName: widget.playerName,
      item: item,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Vault Item', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item Name', hintText: 'e.g. Cloak of Protection'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _category,
              items: const [
                DropdownMenuItem(value: 'gear', child: Text('Adventuring Gear / Equipment')),
                DropdownMenuItem(value: 'magicItem', child: Text('✨ Magic Item')),
                DropdownMenuItem(value: 'gem', child: Text('💎 Gemstone')),
                DropdownMenuItem(value: 'art', child: Text('🎨 Art Object')),
                DropdownMenuItem(value: 'currency', child: Text('💰 Currency / Ingot')),
              ],
              onChanged: (val) => setState(() => _category = val ?? 'gear'),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _gpController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'GP Value Each'),
                  ),
                ),
              ],
            ),
            if (_category == 'magicItem') ...[
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Requires Attunement'),
                value: _requiresAttunement,
                onChanged: (val) => setState(() => _requiresAttunement = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Add to Vault')),
      ],
    );
  }
}

/// Dialog for Quick Coin Deposit & Withdrawal
class CoinTransactionDialog extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isDeposit;

  const CoinTransactionDialog({
    super.key,
    required this.roomCode,
    required this.playerName,
    this.isDeposit = true,
  });

  static Future<void> show(BuildContext context, {required String roomCode, required String playerName, bool isDeposit = true}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CoinTransactionDialog(roomCode: roomCode, playerName: playerName, isDeposit: isDeposit),
    );
  }

  @override
  State<CoinTransactionDialog> createState() => _CoinTransactionDialogState();
}

class _CoinTransactionDialogState extends State<CoinTransactionDialog> {
  final _cp = TextEditingController(text: '0');
  final _sp = TextEditingController(text: '0');
  final _ep = TextEditingController(text: '0');
  final _gp = TextEditingController(text: '0');
  final _pp = TextEditingController(text: '0');
  final _note = TextEditingController();
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void dispose() {
    _cp.dispose();
    _sp.dispose();
    _ep.dispose();
    _gp.dispose();
    _pp.dispose();
    _note.dispose();
    super.dispose();
  }

  void _addQuickGp(int amount) {
    final current = int.tryParse(_gp.text) ?? 0;
    _gp.text = (current + amount).toString();
    setState(() {});
  }

  void _submit() {
    final cp = int.tryParse(_cp.text) ?? 0;
    final sp = int.tryParse(_sp.text) ?? 0;
    final ep = int.tryParse(_ep.text) ?? 0;
    final gp = int.tryParse(_gp.text) ?? 0;
    final pp = int.tryParse(_pp.text) ?? 0;
    final note = _note.text.trim();

    if (cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0) {
      Navigator.pop(context);
      return;
    }

    if (widget.isDeposit) {
      _partyService.depositCoins(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        note: note.isNotEmpty ? note : null,
      );
    } else {
      _partyService.withdrawCoins(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        cp: cp,
        sp: sp,
        ep: ep,
        gp: gp,
        pp: pp,
        note: note.isNotEmpty ? note : null,
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;
    final color = isDeposit ? Colors.green : Colors.amber.shade800;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: color),
          const SizedBox(width: 10),
          Text(isDeposit ? 'Deposit Coins' : 'Withdraw Coins', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Add Gold (GP):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(label: const Text('+10 GP'), onPressed: () => _addQuickGp(10)),
                ActionChip(label: const Text('+50 GP'), onPressed: () => _addQuickGp(50)),
                ActionChip(label: const Text('+100 GP'), onPressed: () => _addQuickGp(100)),
                ActionChip(label: const Text('+500 GP'), onPressed: () => _addQuickGp(500)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: TextField(controller: _pp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PP (Plat)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _gp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GP (Gold)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _ep, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'EP (Elec)'))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _sp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SP (Silv)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _cp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CP (Copp)'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Transaction Note / Source', hintText: 'e.g. Goblin Lair chest'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: Text(isDeposit ? 'Deposit' : 'Withdraw')),
      ],
    );
  }
}

// ===========================================================================
// 7. SWITCH ACTIVE CHARACTER / PLAYER IDENTITY DIALOG
// ===========================================================================

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
  State<SwitchActiveCharacterDialog> createState() => _SwitchActiveCharacterDialogState();
}

class _SwitchActiveCharacterDialogState extends State<SwitchActiveCharacterDialog> {
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
          Text('Select Active Character', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your active player or character identity for this campaign session.',
              style: TextStyle(fontSize: 12.5, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Character / Player Name',
                hintText: 'e.g. Thorin Oakenshield (Fighter)',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: _selectName,
            ),
            if (widget.roster.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Or Pick from Campaign Roster:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.roster.map((rName) {
                  final isCurrent = rName == widget.currentName;
                  return ActionChip(
                    avatar: Icon(Icons.shield, size: 14, color: isCurrent ? Colors.white : null),
                    label: Text(rName),
                    backgroundColor: isCurrent ? colorScheme.primary : null,
                    labelStyle: TextStyle(
                      color: isCurrent ? colorScheme.onPrimary : null,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
              title: const Text('Save to campaign party roster', style: TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => _selectName(_nameController.text),
          child: const Text('Confirm Identity'),
        ),
      ],
    );
  }
}

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
  State<ManagePartyRosterDialog> createState() => _ManagePartyRosterDialogState();
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
          Text('Party Character Roster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                      hintText: 'e.g. Legolas (Ranger)',
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
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_roster.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'No characters in roster yet. Add your party members above!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _roster.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
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
                        style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
                      ),
                      subtitle: isCurrent ? const Text('Active Session Character', style: TextStyle(fontSize: 11, color: Colors.green)) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isCurrent)
                            TextButton(
                              onPressed: () => _playAs(name),
                              child: const Text('Play As', style: TextStyle(fontSize: 12)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
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
        ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

// ===========================================================================
// 9. ASSIGN LOOT ITEM DIALOG
// ===========================================================================

class AssignLootDialog extends StatelessWidget {
  final String itemName;
  final String currentActiveName;
  final List<String> roster;
  final List<String> activePlayers;

  const AssignLootDialog({
    super.key,
    required this.itemName,
    required this.currentActiveName,
    this.roster = const [],
    this.activePlayers = const [],
  });

  static Future<String?> show(
    BuildContext context, {
    required String itemName,
    required String currentActiveName,
    List<String> roster = const [],
    List<String> activePlayers = const [],
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => AssignLootDialog(
        itemName: itemName,
        currentActiveName: currentActiveName,
        roster: roster,
        activePlayers: activePlayers,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCandidates = <String>{
      if (currentActiveName.trim().isNotEmpty) currentActiveName.trim(),
      ...roster.map((s) => s.trim()).where((s) => s.isNotEmpty),
    }.toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.assignment_ind, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assign "$itemName"',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select who will claim this item into their character inventory:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allCandidates.length,
                itemBuilder: (context, idx) {
                  final name = allCandidates[idx];
                  final isMe = name == currentActiveName;

                  return ListTile(
                    dense: true,
                    leading: Icon(isMe ? Icons.star : Icons.person_outline, color: isMe ? Colors.amber : Colors.blue),
                    title: Text(
                      name + (isMe ? ' (You)' : ''),
                      style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                    ),
                    onTap: () => Navigator.pop(context, name),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.archive_outlined, color: Colors.grey),
              title: const Text('Return to Vault (Unclaim / Shared)'),
              onTap: () => Navigator.pop(context, '__unclaim__'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}

/// Dialog to Disperse Rolled or Vault Coins/Valuables among Party Member Stores
class DisperseLootDialog extends StatefulWidget {
  final String? initialRoomCode;
  final PartyPurse purse;
  final double liquidatedGemsAndArtGp;
  final String? sourceTitle;

  const DisperseLootDialog({
    super.key,
    this.initialRoomCode,
    required this.purse,
    this.liquidatedGemsAndArtGp = 0.0,
    this.sourceTitle,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialRoomCode,
    required PartyPurse purse,
    double liquidatedGemsAndArtGp = 0.0,
    String? sourceTitle,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DisperseLootDialog(
        initialRoomCode: initialRoomCode,
        purse: purse,
        liquidatedGemsAndArtGp: liquidatedGemsAndArtGp,
        sourceTitle: sourceTitle,
      ),
    );
  }

  @override
  State<DisperseLootDialog> createState() => _DisperseLootDialogState();
}

class _DisperseLootDialogState extends State<DisperseLootDialog> {
  final PartyRoomService _partyService = PartyRoomService();
  final CampaignRegistryService _registry = CampaignRegistryService();

  late String _selectedRoomCode;
  bool _includePartyReserve = true;
  late bool _includeLiquidated;
  final Set<String> _selectedRecipients = {};
  bool _isLoading = false;
  PartySessionState? _sessionState;

  @override
  void initState() {
    super.initState();
    _includeLiquidated = widget.liquidatedGemsAndArtGp > 0;
    final memberships = _registry.memberships;
    _selectedRoomCode = widget.initialRoomCode ??
        _registry.activeCampaign?.roomCode ??
        (memberships.isNotEmpty ? memberships.first.roomCode : '');

    _loadSessionAndRecipients();
  }

  void _loadSessionAndRecipients() {
    if (_selectedRoomCode.isEmpty) return;
    _partyService.streamSession(_selectedRoomCode).first.then((session) {
      if (mounted && session != null) {
        setState(() {
          _sessionState = session;
          final roster = session.characterRoster.where((s) => s.trim().isNotEmpty).toSet();
          final currentMemberChar = _registry.getMembership(_selectedRoomCode)?.characterId;
          final allCandidates = roster.isNotEmpty
              ? roster
              : (currentMemberChar != null && currentMemberChar.isNotEmpty ? {currentMemberChar} : <String>{});

          if (_selectedRecipients.isEmpty) {
            _selectedRecipients.addAll(allCandidates);
          }
        });
      }
    });
  }

  Future<void> _submitDispersal() async {
    if (_selectedRoomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a campaign room first.')),
      );
      return;
    }

    if (_selectedRecipients.isEmpty && !_includePartyReserve) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one party member or include the party reserve.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      final membership = _registry.getMembership(_selectedRoomCode);
      final performedBy = membership?.characterId ?? 'DM';

      await _partyService.disperseCoinsToParty(
        roomCode: _selectedRoomCode,
        purseToDisperse: widget.purse,
        recipientCharacters: _selectedRecipients.toList(),
        performedBy: performedBy,
        includePartyReserve: _includePartyReserve,
        liquidatedGemsAndArtGp: widget.liquidatedGemsAndArtGp,
        includeLiquidatedInSplit: _includeLiquidated,
      );

      if (mounted) {
        Navigator.pop(context, true);
        final reserveSuffix = _includePartyReserve ? ' (+ Party Reserve)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Coins dispersed to ${_selectedRecipients.length} character stores$reserveSuffix!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to disperse coins: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final memberships = _registry.memberships;

    final roster = _sessionState?.characterRoster.where((s) => s.trim().isNotEmpty).toList() ?? [];
    final currentMemberChar = _registry.getMembership(_selectedRoomCode)?.characterId;
    final candidates = roster.isNotEmpty
        ? roster
        : (currentMemberChar != null && currentMemberChar.isNotEmpty ? [currentMemberChar] : <String>[]);

    final shareCount = _selectedRecipients.length + (_includePartyReserve ? 1 : 0);

    // Calculate preview numbers
    String perShareText = '';
    String reserveText = '';

    if (shareCount > 0) {
      if (_includeLiquidated && widget.liquidatedGemsAndArtGp > 0) {
        final totalGp = widget.purse.totalGpEquivalent + widget.liquidatedGemsAndArtGp;
        final perShareGp = (totalGp / shareCount).floor();
        final remGp = (totalGp - (perShareGp * shareCount)).round();
        perShareText = '~$perShareGp GP';
        reserveText = _includePartyReserve ? '~${perShareGp + remGp} GP' : (remGp > 0 ? '~$remGp GP (Remainder)' : '0 GP');
      } else {
        final ppPer = widget.purse.pp ~/ shareCount;
        final gpPer = widget.purse.gp ~/ shareCount;
        final epPer = widget.purse.ep ~/ shareCount;
        final spPer = widget.purse.sp ~/ shareCount;
        final cpPer = widget.purse.cp ~/ shareCount;

        final parts = <String>[];
        if (ppPer > 0) parts.add('$ppPer PP');
        if (gpPer > 0) parts.add('$gpPer GP');
        if (epPer > 0) parts.add('$epPer EP');
        if (spPer > 0) parts.add('$spPer SP');
        if (cpPer > 0) parts.add('$cpPer CP');
        perShareText = parts.isEmpty ? '0 GP' : parts.join(', ');

        final ppRem = widget.purse.pp % shareCount;
        final gpRem = widget.purse.gp % shareCount;
        final epRem = widget.purse.ep % shareCount;
        final spRem = widget.purse.sp % shareCount;
        final cpRem = widget.purse.cp % shareCount;

        final resParts = <String>[];
        if (_includePartyReserve) {
          if (ppPer + ppRem > 0) resParts.add('${ppPer + ppRem} PP');
          if (gpPer + gpRem > 0) resParts.add('${gpPer + gpRem} GP');
          if (epPer + epRem > 0) resParts.add('${epPer + epRem} EP');
          if (spPer + spRem > 0) resParts.add('${spPer + spRem} SP');
          if (cpPer + cpRem > 0) resParts.add('${cpPer + cpRem} CP');
        } else {
          if (ppRem > 0) resParts.add('$ppRem PP');
          if (gpRem > 0) resParts.add('$gpRem GP');
          if (epRem > 0) resParts.add('$epRem EP');
          if (spRem > 0) resParts.add('$spRem SP');
          if (cpRem > 0) resParts.add('$cpRem CP');
        }
        reserveText = resParts.isEmpty ? '0 GP' : resParts.join(', ');
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.currency_exchange, color: Colors.amber, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.sourceTitle != null ? 'Disperse ${widget.sourceTitle}' : 'Disperse Loot to Party',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Campaign selector if multiple
            if (memberships.length > 1) ...[
              const Text('Destination Campaign:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoomCode.isNotEmpty ? _selectedRoomCode : memberships.first.roomCode,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: memberships.map((m) {
                  return DropdownMenuItem(
                    value: m.roomCode,
                    child: Text('${m.campaignName} (${m.roomCode})', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRoomCode = val);
                    _loadSessionAndRecipients();
                  }
                },
              ),
              const SizedBox(height: 12),
            ],

            // Total Loot Amount Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total to Disperse:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '~${(widget.purse.totalGpEquivalent + (_includeLiquidated ? widget.liquidatedGemsAndArtGp : 0)).toStringAsFixed(1)} GP',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Checkbox: Share for Party Reserve
            CheckboxListTile(
              value: _includePartyReserve,
              onChanged: (val) => setState(() => _includePartyReserve = val ?? true),
              title: const Text('A share for the Party Reserve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Deposits 1 equal share + any coin remainders into the shared Vault', style: TextStyle(fontSize: 11)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

            // Checkbox: Liquidate Gems & Art
            if (widget.liquidatedGemsAndArtGp > 0) ...[
              CheckboxListTile(
                value: _includeLiquidated,
                onChanged: (val) => setState(() => _includeLiquidated = val ?? false),
                title: Text('Liquidate gems & art (+${widget.liquidatedGemsAndArtGp.toStringAsFixed(0)} GP)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('Converts art and gemstone values directly into gold split', style: TextStyle(fontSize: 11)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],

            const Divider(height: 18),

            // Recipients Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Party Member Recipients (${_selectedRecipients.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedRecipients.length == candidates.length) {
                        _selectedRecipients.clear();
                      } else {
                        _selectedRecipients.addAll(candidates);
                      }
                    });
                  },
                  child: Text(
                    _selectedRecipients.length == candidates.length ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),

            // Checklist of characters
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No characters found on campaign roster. Go to campaign to define party members.',
                  style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  itemBuilder: (context, idx) {
                    final name = candidates[idx];
                    final isChecked = _selectedRecipients.contains(name);

                    return CheckboxListTile(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedRecipients.add(name);
                          } else {
                            _selectedRecipients.remove(name);
                          }
                        });
                      },
                      title: Text(name, style: const TextStyle(fontSize: 12.5)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      dense: true,
                    );
                  },
                ),
              ),

            const SizedBox(height: 10),

            // Live Calculation Breakdown
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split into $shareCount shares (${_selectedRecipients.length} members + ${_includePartyReserve ? 1 : 0} reserve):',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Each Character Gets:', style: TextStyle(fontSize: 12)),
                      Text(perShareText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Party Reserve Gets:', style: TextStyle(fontSize: 12)),
                      Text(reserveText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submitDispersal,
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 18),
          label: Text('Disperse ($shareCount Shares)'),
        ),
      ],
    );
  }
}

/// Dialog for Personal Member Purse Deposit/Withdraw
class MemberCoinTransactionDialog extends StatefulWidget {
  final String roomCode;
  final String characterName;
  final String performedBy;
  final bool isDeposit;

  const MemberCoinTransactionDialog({
    super.key,
    required this.roomCode,
    required this.characterName,
    required this.performedBy,
    required this.isDeposit,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomCode,
    required String characterName,
    required String performedBy,
    required bool isDeposit,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MemberCoinTransactionDialog(
        roomCode: roomCode,
        characterName: characterName,
        performedBy: performedBy,
        isDeposit: isDeposit,
      ),
    );
  }

  @override
  State<MemberCoinTransactionDialog> createState() => _MemberCoinTransactionDialogState();
}

class _MemberCoinTransactionDialogState extends State<MemberCoinTransactionDialog> {
  final _cpController = TextEditingController(text: '0');
  final _spController = TextEditingController(text: '0');
  final _epController = TextEditingController(text: '0');
  final _gpController = TextEditingController(text: '0');
  final _ppController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  final PartyRoomService _partyService = PartyRoomService();
  bool _isLoading = false;

  @override
  void dispose() {
    _cpController.dispose();
    _spController.dispose();
    _epController.dispose();
    _gpController.dispose();
    _ppController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cp = int.tryParse(_cpController.text.trim()) ?? 0;
    final sp = int.tryParse(_spController.text.trim()) ?? 0;
    final ep = int.tryParse(_epController.text.trim()) ?? 0;
    final gp = int.tryParse(_gpController.text.trim()) ?? 0;
    final pp = int.tryParse(_ppController.text.trim()) ?? 0;
    final note = _noteController.text.trim();

    if (cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      final session = await _partyService.streamSession(widget.roomCode).first;
      final currentPurse = session?.getMemberPurse(widget.characterName) ?? const PartyPurse();

      final newPurse = widget.isDeposit
          ? currentPurse.depositCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp)
          : currentPurse.withdrawCoins(cp: cp, sp: sp, ep: ep, gp: gp, pp: pp);

      await _partyService.updateMemberPurse(
        roomCode: widget.roomCode,
        characterName: widget.characterName,
        newPurse: newPurse,
        performedBy: widget.performedBy,
        note: note.isNotEmpty ? note : (widget.isDeposit ? 'Deposit' : 'Withdrawal'),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isDeposit
                  ? 'Deposited coins to ${widget.characterName}\'s store'
                  : 'Withdrew coins from ${widget.characterName}\'s store',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeposit = widget.isDeposit;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(isDeposit ? Icons.add_circle : Icons.remove_circle, color: isDeposit ? Colors.green : Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${isDeposit ? "Deposit to" : "Withdraw from"} ${widget.characterName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildField('Platinum (PP)', _ppController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Gold (GP)', _gpController)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildField('Electrum (EP)', _epController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Silver (SP)', _spController)),
              ],
            ),
            const SizedBox(height: 8),
            _buildField('Copper (CP)', _cpController),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Reason / Note (Optional)',
                hintText: 'e.g. Bought potions, Tavern bill',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDeposit ? Colors.green.shade700 : Colors.amber.shade800,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: Text(isDeposit ? 'Deposit Coins' : 'Withdraw Coins'),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }
}

/// Dialog to Transfer Coins between Personal Store and Party Reserve
class TransferCoinDialog extends StatefulWidget {
  final String roomCode;
  final String characterName;
  final String performedBy;
  final bool toReserve;

  const TransferCoinDialog({
    super.key,
    required this.roomCode,
    required this.characterName,
    required this.performedBy,
    required this.toReserve,
  });

  static Future<void> show(
    BuildContext context, {
    required String roomCode,
    required String characterName,
    required String performedBy,
    required bool toReserve,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TransferCoinDialog(
        roomCode: roomCode,
        characterName: characterName,
        performedBy: performedBy,
        toReserve: toReserve,
      ),
    );
  }

  @override
  State<TransferCoinDialog> createState() => _TransferCoinDialogState();
}

class _TransferCoinDialogState extends State<TransferCoinDialog> {
  final _cpController = TextEditingController(text: '0');
  final _spController = TextEditingController(text: '0');
  final _epController = TextEditingController(text: '0');
  final _gpController = TextEditingController(text: '0');
  final _ppController = TextEditingController(text: '0');
  final PartyRoomService _partyService = PartyRoomService();
  bool _isLoading = false;

  @override
  void dispose() {
    _cpController.dispose();
    _spController.dispose();
    _epController.dispose();
    _gpController.dispose();
    _ppController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cp = int.tryParse(_cpController.text.trim()) ?? 0;
    final sp = int.tryParse(_spController.text.trim()) ?? 0;
    final ep = int.tryParse(_epController.text.trim()) ?? 0;
    final gp = int.tryParse(_gpController.text.trim()) ?? 0;
    final pp = int.tryParse(_ppController.text.trim()) ?? 0;

    if (cp == 0 && sp == 0 && ep == 0 && gp == 0 && pp == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    HapticService.mediumImpact(context);

    try {
      if (widget.toReserve) {
        await _partyService.transferMemberToReserve(
          roomCode: widget.roomCode,
          characterName: widget.characterName,
          performedBy: widget.performedBy,
          cp: cp,
          sp: sp,
          ep: ep,
          gp: gp,
          pp: pp,
        );
      } else {
        await _partyService.transferReserveToMember(
          roomCode: widget.roomCode,
          characterName: widget.characterName,
          performedBy: widget.performedBy,
          cp: cp,
          sp: sp,
          ep: ep,
          gp: gp,
          pp: pp,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.toReserve
                  ? 'Transferred coins from ${widget.characterName} to Party Reserve'
                  : 'Transferred coins from Party Reserve to ${widget.characterName}',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.sync_alt, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.toReserve ? 'Transfer to Party Reserve' : 'Withdraw from Party Reserve',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.toReserve
                  ? 'Move personal coins from ${widget.characterName} into the shared party vault.'
                  : 'Move funds from the shared party reserve into ${widget.characterName}\'s pouch.',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildField('Platinum (PP)', _ppController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Gold (GP)', _gpController)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildField('Electrum (EP)', _epController)),
                const SizedBox(width: 8),
                Expanded(child: _buildField('Silver (SP)', _spController)),
              ],
            ),
            const SizedBox(height: 8),
            _buildField('Copper (CP)', _cpController),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _submit,
          child: const Text('Confirm Transfer'),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }
}

/// Dialog to Link or Switch a Saved Character to an active Campaign Room
class LinkCampaignCharacterDialog extends StatefulWidget {
  final String roomCode;
  final VoidCallback? onLinked;

  const LinkCampaignCharacterDialog({
    super.key,
    required this.roomCode,
    this.onLinked,
  });

  static Future<void> show(BuildContext context, {required String roomCode, VoidCallback? onLinked}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => LinkCampaignCharacterDialog(roomCode: roomCode, onLinked: onLinked),
    );
  }

  @override
  State<LinkCampaignCharacterDialog> createState() => _LinkCampaignCharacterDialogState();
}

class _LinkCampaignCharacterDialogState extends State<LinkCampaignCharacterDialog> {
  final PartyRoomService _partyService = PartyRoomService();
  final CharacterPersistenceService _characterService = CharacterPersistenceService();

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
            content: Text('Linked "${_selectedCharacter!.name}" to campaign room!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed linking character: $e'), backgroundColor: Colors.redAccent),
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
          const Text('Link Character to Campaign', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Link a character from your vault to "${widget.roomCode}". This shares your stats with the DM and automatically syncs gold and claimed loot to your sheet.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _savedCharacters
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.name} (Lvl ${c.totalLevel} ${c.speciesRef.displayName})'),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCharacter = val),
              ),
              const SizedBox(height: 14),
              const Text('Campaign Roster Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _importAsNew = true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        _importAsNew ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18,
                        color: _importAsNew ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Import as new character', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              'Adds ${_selectedCharacter?.name ?? "character"} as a new hero in the campaign roster',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(
                        !_importAsNew ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18,
                        color: !_importAsNew ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Link to existing character slot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              'Associate with a pre-existing roster name in the room',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _rosterSlots
                      .map((slot) => DropdownMenuItem(value: slot, child: Text(slot)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedExistingSlot = val),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          icon: const Icon(Icons.link, size: 18),
          label: Text(_isLoading ? 'Linking...' : 'Link Character'),
          onPressed: (_isLoading || _selectedCharacter == null) ? null : _submit,
        ),
      ],
    );
  }
}
