import 'package:flutter/material.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../../application/map/active_map_controller.dart';
import '../../../application/map/map_token_rules.dart';
import '../../../application/map/map_token_service.dart';

import '../../../infrastructure/di/injection_container.dart';

class MapTokenPanel extends StatefulWidget {
  final PlacedMapToken token;
  final MapTokenDetail? detail;
  final Map<String, String> characterNames;
  final Map<String, String> minionOwners;
  final Set<String> rosterSlugs;
  final bool canEditMap;
  final String campaignId;
  final BlobRef map;
  final MapTokenService? tokenService;
  final VoidCallback onClearSelection;

  const MapTokenPanel({
    super.key,
    required this.token,
    this.detail,
    required this.characterNames,
    required this.minionOwners,
    required this.rosterSlugs,
    required this.canEditMap,
    required this.campaignId,
    required this.map,
    this.tokenService,
    required this.onClearSelection,
  });

  @override
  State<MapTokenPanel> createState() => _MapTokenPanelState();
}

class _MapTokenPanelState extends State<MapTokenPanel> {
  String? _message;
  bool _isActing = false;

  String _displayName() {
    final t = widget.token.token;
    switch (t.kind) {
      case MapTokenKind.character:
        final fromTelemetry = widget.characterNames[t.refId]?.trim();
        return (fromTelemetry != null && fromTelemetry.isNotEmpty) ? fromTelemetry : t.refId;
      case MapTokenKind.monster:
      case MapTokenKind.minion:
        final fromDetail = widget.detail?.name?.trim();
        return (fromDetail != null && fromDetail.isNotEmpty) ? fromDetail : t.refId;
    }
  }

  String _kindDisplay() {
    switch (widget.token.token.kind) {
      case MapTokenKind.character:
        return 'Character';
      case MapTokenKind.monster:
        return 'Combatant';
      case MapTokenKind.minion:
        return 'Minion';
    }
  }

  String _formatOwner(String? ownerSlug) {
    if (ownerSlug == null || ownerSlug.isEmpty) return 'none';
    final name = widget.characterNames[ownerSlug]?.trim();
    return (name != null && name.isNotEmpty) ? name : ownerSlug;
  }

  Future<void> _handleRemoveToken() async {
    setState(() {
      _isActing = true;
      _message = null;
    });

    try {
      final service = widget.tokenService ?? sl<MapTokenService>();
      final result = await service.removeToken(
        widget.campaignId,
        const MapTokenActor.dm(),
        widget.token.token.id,
      );

      if (!mounted) return;

      if (result == MapTokenWriteResult.written) {
        widget.onClearSelection();
      } else {
        setState(() {
          _isActing = false;
          _message = _resultToMessage(result);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isActing = false;
        final msg = e.toString().replaceFirst('Exception: ', '');
        _message = "Couldn't save the token: $msg";
      });
    }
  }

  Future<void> _handleSetMinionOwner(String? newOwner) async {
    setState(() {
      _isActing = true;
      _message = null;
    });

    try {
      final service = widget.tokenService ?? sl<MapTokenService>();
      final result = await service.setMinionOwner(
        widget.campaignId,
        const MapTokenActor.dm(),
        widget.token.token.refId,
        newOwner,
      );

      if (!mounted) return;

      if (result == MapTokenWriteResult.written || result == MapTokenWriteResult.unchanged) {
        setState(() {
          _isActing = false;
        });
      } else {
        setState(() {
          _isActing = false;
          _message = _resultToMessage(result);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isActing = false;
        final msg = e.toString().replaceFirst('Exception: ', '');
        _message = "Couldn't save the token: $msg";
      });
    }
  }

  String _resultToMessage(MapTokenWriteResult result) {
    switch (result) {
      case MapTokenWriteResult.notAllowed:
        return "You can't move that token.";
      case MapTokenWriteResult.notFound:
        return 'That token was removed.';
      case MapTokenWriteResult.noGrid:
        return 'Set up the grid first.';
      case MapTokenWriteResult.offMap:
        return 'Tokens must stay on the map.';
      default:
        return 'Action failed ($result).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.token.token;
    final currentOwnerSlug = widget.minionOwners[t.refId];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(200),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _kindDisplay(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Close panel',
                onPressed: widget.onClearSelection,
              ),
            ],
          ),
          if (t.kind == MapTokenKind.minion) ...[
            const SizedBox(height: 8),
            if (!widget.canEditMap)
              Text('Owner: ${_formatOwner(currentOwnerSlug)}')
            else
              Row(
                children: [
                  const Text('Owner: '),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: widget.rosterSlugs.contains(currentOwnerSlug) ? currentOwnerSlug : null,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...widget.rosterSlugs.map((slug) {
                        return DropdownMenuItem<String?>(
                          value: slug,
                          child: Text(_formatOwner(slug)),
                        );
                      }),
                    ],
                    onChanged: _isActing ? null : (newVal) => _handleSetMinionOwner(newVal),
                  ),
                ],
              ),
          ],
          if (widget.canEditMap) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _isActing ? null : _handleRemoveToken,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove token'),
                ),
              ],
            ),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
