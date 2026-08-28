import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/party/party_loot_item.dart';
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
                hintText: 'e.g. Curse of Strahd, Waterdeep Heist',
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
  bool _isLoading = false;
  final PartyRoomService _partyService = PartyRoomService();

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: widget.initialRoomCode ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final roomCode = _roomController.text.trim().toUpperCase();
    final playerName = _nameController.text.trim();

    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room code.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticService.selectionTick(context);

    try {
      final session = await _partyService.joinCampaign(
        roomCode: roomCode,
        playerName: playerName.isEmpty ? 'Adventurer' : playerName,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onJoined?.call(session.roomCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined "${session.campaignName}" (${session.roomCode})!'),
            backgroundColor: Colors.green.shade700,
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
              'Enter the 6-character room code provided by your Dungeon Master to connect to the shared party vault and live dice feed.',
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
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Your Character / Player Name',
                hintText: 'e.g. Rogar the Barbarian',
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
              : const Icon(Icons.login, size: 18),
          label: const Text('Join Room'),
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

/// Dialog to Import a DM Passkey for Co-DM rights
class ImportDmPasskeyDialog extends StatefulWidget {
  final String? initialRoomCode;
  final Function(CampaignMembership membership)? onImported;

  const ImportDmPasskeyDialog({super.key, this.initialRoomCode, this.onImported});

  static Future<void> show(BuildContext context, {String? initialRoomCode, Function(CampaignMembership)? onImported}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => ImportDmPasskeyDialog(initialRoomCode: initialRoomCode, onImported: onImported),
    );
  }

  @override
  State<ImportDmPasskeyDialog> createState() => _ImportDmPasskeyDialogState();
}

class _ImportDmPasskeyDialogState extends State<ImportDmPasskeyDialog> {
  late final TextEditingController _roomController;
  final _campaignController = TextEditingController();
  final _passkeyController = TextEditingController();
  final _nameController = TextEditingController();
  final CampaignRegistryService _registry = CampaignRegistryService();

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(text: widget.initialRoomCode ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    _campaignController.dispose();
    _passkeyController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final roomCode = _roomController.text.trim().toUpperCase();
    final campaignName = _campaignController.text.trim();
    final passkey = _passkeyController.text.trim();
    final playerName = _nameController.text.trim();

    if (roomCode.isEmpty || passkey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both Room Code and Passkey.')),
      );
      return;
    }

    final membership = await _registry.importPasskey(
      roomCode: roomCode,
      campaignName: campaignName.isEmpty ? 'Imported DM Campaign' : campaignName,
      passkeyOrMnemonic: passkey,
      playerName: playerName.isEmpty ? 'Co-DM' : playerName,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onImported?.call(membership);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported Co-DM rights for ${membership.roomCode}!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.vpn_key, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          const Text('Import DM Passkey', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _roomController,
              maxLength: 30,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Room Code',
                hintText: 'e.g. ROOM-A1B2C3',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _campaignController,
              decoration: InputDecoration(
                labelText: 'Campaign Name (Optional)',
                hintText: 'e.g. Curse of Strahd',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passkeyController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '6-Word Mnemonic or UUID Passkey',
                hintText: 'e.g. dragon wizard shield potion goblin scroll',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name (Optional)',
                hintText: 'e.g. Co-DM Kevin',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Import Co-DM Rights')),
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
