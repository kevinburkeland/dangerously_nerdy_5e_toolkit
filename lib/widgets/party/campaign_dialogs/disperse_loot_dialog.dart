import 'package:material_ui/material_ui.dart';
import '../../../models/party/party_purse.dart';
import '../../../models/party/party_session_state.dart';
import '../../../services/haptic_service.dart';
import '../../../services/party/campaign_registry_service.dart';
import '../../../services/party/party_room_service.dart';

/// Dialog to Disperse Rolled or Vault Coins/Valuables among Party Member Stores
class DisperseLootDialog extends StatefulWidget {
  final String? initialRoomCode;
  final PartyPurse purse;
  final double liquidatedGemsAndArtGp;
  final String? sourceTitle;
  final bool isVaultDispersal;

  const DisperseLootDialog({
    super.key,
    this.initialRoomCode,
    required this.purse,
    this.liquidatedGemsAndArtGp = 0.0,
    this.sourceTitle,
    this.isVaultDispersal = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialRoomCode,
    required PartyPurse purse,
    double liquidatedGemsAndArtGp = 0.0,
    String? sourceTitle,
    bool isVaultDispersal = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => DisperseLootDialog(
        initialRoomCode: initialRoomCode,
        purse: purse,
        liquidatedGemsAndArtGp: liquidatedGemsAndArtGp,
        sourceTitle: sourceTitle,
        isVaultDispersal: isVaultDispersal,
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
          final roster =
              session.characterRoster.where((s) => s.trim().isNotEmpty).toSet();
          final currentMemberChar =
              _registry.getMembership(_selectedRoomCode)?.characterId;
          final allCandidates = roster.isNotEmpty
              ? roster
              : (currentMemberChar != null && currentMemberChar.isNotEmpty
                  ? {currentMemberChar}
                  : <String>{});

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
        const SnackBar(
            content: Text(
                'Please select at least one party member or include the party reserve.')),
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
        isVaultDispersal: widget.isVaultDispersal,
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
          SnackBar(
              content: Text('Failed to disperse coins: $e'),
              backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final memberships = _registry.memberships;

    final roster = _sessionState?.characterRoster
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        [];
    final currentMemberChar =
        _registry.getMembership(_selectedRoomCode)?.characterId;
    final candidates = roster.isNotEmpty
        ? roster
        : (currentMemberChar != null && currentMemberChar.isNotEmpty
            ? [currentMemberChar]
            : <String>[]);

    final shareCount =
        _selectedRecipients.length + (_includePartyReserve ? 1 : 0);

    // Calculate preview numbers
    String perShareText = '';
    String reserveText = '';

    if (shareCount > 0) {
      if (_includeLiquidated && widget.liquidatedGemsAndArtGp > 0) {
        final totalGp =
            widget.purse.totalGpEquivalent + widget.liquidatedGemsAndArtGp;
        final perShareGp = (totalGp / shareCount).floor();
        final remGp = (totalGp - (perShareGp * shareCount)).round();
        perShareText = '~$perShareGp GP';
        reserveText = _includePartyReserve
            ? '~${perShareGp + remGp} GP'
            : (remGp > 0 ? '~$remGp GP (Remainder)' : '0 GP');
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
              widget.sourceTitle != null
                  ? 'Disperse ${widget.sourceTitle}'
                  : 'Disperse Loot to Party',
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
              const Text('Destination Campaign:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoomCode.isNotEmpty
                    ? _selectedRoomCode
                    : memberships.first.roomCode,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                items: memberships.map((m) {
                  return DropdownMenuItem(
                    value: m.roomCode,
                    child: Text('${m.campaignName} (${m.roomCode})',
                        style: const TextStyle(fontSize: 13)),
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
                  const Text('Total to Disperse:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '~${(widget.purse.totalGpEquivalent + (_includeLiquidated ? widget.liquidatedGemsAndArtGp : 0)).toStringAsFixed(1)} GP',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Checkbox: Share for Party Reserve
            CheckboxListTile(
              value: _includePartyReserve,
              onChanged: (val) =>
                  setState(() => _includePartyReserve = val ?? true),
              title: const Text('A share for the Party Reserve',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text(
                  'Deposits 1 equal share + any coin remainders into the shared Vault',
                  style: TextStyle(fontSize: 11)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),

            // Checkbox: Liquidate Gems & Art
            if (widget.liquidatedGemsAndArtGp > 0) ...[
              CheckboxListTile(
                value: _includeLiquidated,
                onChanged: (val) =>
                    setState(() => _includeLiquidated = val ?? false),
                title: Text(
                    'Liquidate gems & art (+${widget.liquidatedGemsAndArtGp.toStringAsFixed(0)} GP)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text(
                    'Converts art and gemstone values directly into gold split',
                    style: TextStyle(fontSize: 11)),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12.5),
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
                    _selectedRecipients.length == candidates.length
                        ? 'Deselect All'
                        : 'Select All',
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
                  style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant),
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
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Split into $shareCount shares (${_selectedRecipients.length} members + ${_includePartyReserve ? 1 : 0} reserve):',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Each Character Gets:',
                          style: TextStyle(fontSize: 12)),
                      Text(perShareText,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Party Reserve Gets:',
                          style: TextStyle(fontSize: 12)),
                      Text(reserveText,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent)),
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
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check, size: 18),
          label: Text('Disperse ($shareCount Shares)'),
        ),
      ],
    );
  }
}

/// Dialog for Personal Member Purse Deposit/Withdraw
