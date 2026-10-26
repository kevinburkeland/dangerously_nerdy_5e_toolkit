import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../../application/map/grid_geometry.dart';
import '../../../application/map/map_token_candidates.dart';
import '../../../application/map/map_token_rules.dart';
import '../../../application/map/map_token_service.dart';

import '../../../infrastructure/di/injection_container.dart';

class MapTokenPickerDialog extends StatefulWidget {
  final ICampaignRepository? campaignRepo;
  final MapTokenService? tokenService;
  final String campaignId;
  final BlobRef map;
  final MapGrid grid;
  final Map<String, String> characterNames;
  final Offset viewCenterScene;

  const MapTokenPickerDialog({
    super.key,
    this.campaignRepo,
    this.tokenService,
    required this.campaignId,
    required this.map,
    required this.grid,
    required this.characterNames,
    required this.viewCenterScene,
  });

  @override
  State<MapTokenPickerDialog> createState() => _MapTokenPickerDialogState();
}

class _MapTokenPickerDialogState extends State<MapTokenPickerDialog> {
  late final List<MapTokenCandidate> _candidates;
  MapTokenCandidate? _selectedCandidate;
  late final TextEditingController _labelController;
  String? _errorMessage;
  bool _isPlacing = false;

  final _labelRegex = RegExp(r'^[A-Z0-9]{1,3}$');

  @override
  void initState() {
    super.initState();
    final repo = widget.campaignRepo ?? sl<ICampaignRepository>();
    final profile = repo.activeProfile;
    _candidates = profile != null
        ? tokenCandidates(profile, widget.map.sha256Hex, widget.characterNames)
        : const [];
    _labelController = TextEditingController();
    _labelController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _selectCandidate(MapTokenCandidate candidate) {
    if (candidate.onThisMap) return;
    setState(() {
      _selectedCandidate = candidate;
      _labelController.text = candidate.suggestedLabel;
      _errorMessage = null;
    });
  }

  Future<void> _handlePlace() async {
    final candidate = _selectedCandidate;
    if (candidate == null) return;
    final label = _labelController.text.trim();
    if (!_labelRegex.hasMatch(label)) return;

    setState(() {
      _isPlacing = true;
      _errorMessage = null;
    });

    final centerCell = cellAt(widget.grid, widget.viewCenterScene.dx, widget.viewCenterScene.dy);
    final clamped = nearestOnMapCell(
      widget.grid,
      widget.map.width,
      widget.map.height,
      centerCell.col,
      centerCell.row,
    );
    final cell = MapTokenCell(col: clamped.col, row: clamped.row);

    try {
      final service = widget.tokenService ?? sl<MapTokenService>();
      final result = await service.placeToken(
        widget.campaignId,
        widget.map,
        const MapTokenActor.dm(),
        kind: candidate.kind,
        refId: candidate.refId,
        label: label,
        cell: cell,
      );

      if (!mounted) return;

      if (result == MapTokenWriteResult.written) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isPlacing = false;
          switch (result) {
            case MapTokenWriteResult.duplicate:
              _errorMessage = 'That one is already on this map.';
            case MapTokenWriteResult.unknownRef:
              _errorMessage = 'That character, combatant or minion is gone.';
            case MapTokenWriteResult.noGrid:
              _errorMessage = 'Set up the grid first.';
            case MapTokenWriteResult.offMap:
              _errorMessage = 'Tokens must stay on the map.';
            case MapTokenWriteResult.notAllowed:
              _errorMessage = 'Only the DM can add tokens.';
            default:
              _errorMessage = 'Failed to place token ($result).';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlacing = false;
        final msg = e.toString().replaceFirst('Exception: ', '');
        _errorMessage = "Couldn't save the token: $msg";
      });
    }
  }

  Widget _buildSection(String title, List<MapTokenCandidate> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'None yet',
              style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
            ),
          )
        else
          ...items.map((candidate) {
            final isSelected = _selectedCandidate == candidate;
            final disabled = candidate.onThisMap;
            return ListTile(
              dense: true,
              selected: isSelected,
              enabled: !disabled,
              leading: Icon(
                candidate.kind == MapTokenKind.character
                    ? Icons.person
                    : (candidate.kind == MapTokenKind.monster
                        ? Icons.shield
                        : Icons.pets),
                size: 20,
              ),
              title: Text(candidate.name),
              trailing: disabled
                  ? const Text('On this map', style: TextStyle(color: Colors.white38, fontSize: 12))
                  : null,
              onTap: disabled ? null : () => _selectCandidate(candidate),
            );
          }),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final characters = _candidates.where((c) => c.kind == MapTokenKind.character).toList();
    final combatants = _candidates.where((c) => c.kind == MapTokenKind.monster).toList();
    final minions = _candidates.where((c) => c.kind == MapTokenKind.minion).toList();

    final label = _labelController.text.trim();
    final canPlace = _selectedCandidate != null &&
        !_isPlacing &&
        _labelRegex.hasMatch(label);

    return AlertDialog(
      title: const Text('Add token'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                  ),
                ),
              _buildSection('Characters', characters),
              _buildSection('Combatants', combatants),
              _buildSection('Minions', minions),
              if (_selectedCandidate != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                TextField(
                  controller: _labelController,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    TextInputFormatter.withFunction((oldVal, newVal) {
                      return newVal.copyWith(text: newVal.text.toUpperCase());
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Token label (1-3 letters/digits)',
                    counterText: '',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPlacing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canPlace ? _handlePlace : null,
          child: const Text('Place'),
        ),
      ],
    );
  }
}
