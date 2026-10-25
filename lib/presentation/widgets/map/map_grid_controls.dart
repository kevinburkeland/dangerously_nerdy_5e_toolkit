import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vtt_engine_core/models/value_objects/blob_ref.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';
import '../../../application/map/map_grid_service.dart';

/// Helper to toggle the shared map grid on/off.
void toggleMapGrid({
  required MapGridService gridService,
  required String campaignId,
  required BlobRef mapRef,
  required MapGrid? currentGrid,
}) {
  if (currentGrid == null) {
    gridService.setGrid(campaignId, gridService.defaultGridFor(mapRef));
  } else if (currentGrid.visible) {
    gridService.setGrid(
      campaignId,
      MapGrid(
        mapSha256Hex: currentGrid.mapSha256Hex,
        cellCentiPx: currentGrid.cellCentiPx,
        offsetXCentiPx: currentGrid.offsetXCentiPx,
        offsetYCentiPx: currentGrid.offsetYCentiPx,
        feetPerCell: currentGrid.feetPerCell,
        visible: false,
      ),
    );
  } else {
    gridService.setGrid(
      campaignId,
      MapGrid(
        mapSha256Hex: currentGrid.mapSha256Hex,
        cellCentiPx: currentGrid.cellCentiPx,
        offsetXCentiPx: currentGrid.offsetXCentiPx,
        offsetYCentiPx: currentGrid.offsetYCentiPx,
        feetPerCell: currentGrid.feetPerCell,
        visible: true,
      ),
    );
  }
}

/// Compact controls panel for configuring grid size, alignment, and scale.
class MapGridControls extends StatefulWidget {
  final String campaignId;
  final BlobRef mapRef;
  final MapGrid grid;
  final MapGridService gridService;
  final VoidCallback onStartSetCorner;
  final bool isSettingCorner;

  const MapGridControls({
    super.key,
    required this.campaignId,
    required this.mapRef,
    required this.grid,
    required this.gridService,
    required this.onStartSetCorner,
    this.isSettingCorner = false,
  });

  @override
  State<MapGridControls> createState() => _MapGridControlsState();
}

class _MapGridControlsState extends State<MapGridControls> {
  late double _cellSizePx;
  late int _offsetXCentiPx;
  late int _offsetYCentiPx;
  late int _feetPerCell;

  late TextEditingController _sizeController;
  late TextEditingController _feetController;

  String? _errorMessage;
  Timer? _debounceTimer;
  bool _hasPendingChange = false;

  @override
  void initState() {
    super.initState();
    _cellSizePx = widget.grid.cellCentiPx / 100.0;
    _offsetXCentiPx = widget.grid.offsetXCentiPx;
    _offsetYCentiPx = widget.grid.offsetYCentiPx;
    _feetPerCell = widget.grid.feetPerCell;

    _sizeController = TextEditingController(text: _formatSize(_cellSizePx));
    _feetController = TextEditingController(text: _feetPerCell.toString());
  }

  String _formatSize(double size) {
    if (size == size.roundToDouble()) {
      return size.toInt().toString();
    }
    final fixed1 = size.toStringAsFixed(1);
    if (double.parse(fixed1) == size) {
      return fixed1;
    }
    return size.toStringAsFixed(2);
  }

  @override
  void didUpdateWidget(MapGridControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.grid != oldWidget.grid && !_hasPendingChange) {
      _cellSizePx = widget.grid.cellCentiPx / 100.0;
      _offsetXCentiPx = widget.grid.offsetXCentiPx;
      _offsetYCentiPx = widget.grid.offsetYCentiPx;
      _feetPerCell = widget.grid.feetPerCell;
      _sizeController.text = _formatSize(_cellSizePx);
      _feetController.text = _feetPerCell.toString();
    }
  }

  void _scheduleDebouncedWrite() {
    _hasPendingChange = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _writeNow();
    });
  }

  void _writeNow() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    if (!_hasPendingChange) return;
    _hasPendingChange = false;
    if (_errorMessage != null) return;

    final cellCenti = (_cellSizePx * 100.0).round().clamp(1000, 51200);
    int offX = _offsetXCentiPx % cellCenti;
    if (offX < 0) offX += cellCenti;
    int offY = _offsetYCentiPx % cellCenti;
    if (offY < 0) offY += cellCenti;

    final updatedGrid = MapGrid(
      mapSha256Hex: widget.grid.mapSha256Hex,
      cellCentiPx: cellCenti,
      offsetXCentiPx: offX,
      offsetYCentiPx: offY,
      feetPerCell: _feetPerCell.clamp(1, 100),
      visible: widget.grid.visible,
    );
    widget.gridService.setGrid(widget.campaignId, updatedGrid);
  }

  void _stepSize(double delta) {
    final nextSize = ((_cellSizePx + delta) * 100.0).round() / 100.0;
    if (nextSize < 10.0 || nextSize > 512.0) {
      setState(() {
        _errorMessage = 'Square size must be between 10 and 512 px.';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _cellSizePx = nextSize;
      _sizeController.text = _formatSize(_cellSizePx);
    });
    _scheduleDebouncedWrite();
  }

  void _onSizeTextChanged(String text) {
    final val = double.tryParse(text);
    if (val == null || val < 10.0 || val > 512.0) {
      setState(() {
        _errorMessage = 'Square size must be between 10 and 512 px.';
        _debounceTimer?.cancel();
        _hasPendingChange = false;
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _cellSizePx = val;
    });
    _scheduleDebouncedWrite();
  }

  void _onFeetTextChanged(String text) {
    final val = int.tryParse(text);
    if (val == null || val < 1 || val > 100) {
      return;
    }
    setState(() {
      _feetPerCell = val;
    });
    _scheduleDebouncedWrite();
  }

  void _nudge(int dx, int dy) {
    final cellCenti = (_cellSizePx * 100.0).round();
    int newX = (_offsetXCentiPx + dx * 100) % cellCenti;
    if (newX < 0) newX += cellCenti;
    int newY = (_offsetYCentiPx + dy * 100) % cellCenti;
    if (newY < 0) newY += cellCenti;

    setState(() {
      _offsetXCentiPx = newX;
      _offsetYCentiPx = newY;
    });
    _scheduleDebouncedWrite();
  }

  @override
  void dispose() {
    _writeNow();
    _sizeController.dispose();
    _feetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.start,
              children: [
                // Square size section
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Size: ', style: TextStyle(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      tooltip: 'Decrease size',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => _stepSize(-0.5),
                    ),
                    SizedBox(
                      width: 58,
                      child: TextField(
                        controller: _sizeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: _onSizeTextChanged,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: 'Increase size',
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => _stepSize(0.5),
                    ),
                    const Text('px', style: TextStyle(fontSize: 13)),
                  ],
                ),
                // Line up section
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onStartSetCorner,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: widget.isSettingCorner
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                      child: Text(
                        widget.isSettingCorner ? 'Tap corner…' : 'Set a corner',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 18),
                      tooltip: 'Nudge left',
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      onPressed: () => _nudge(-1, 0),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      tooltip: 'Nudge up',
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      onPressed: () => _nudge(0, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      tooltip: 'Nudge down',
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      onPressed: () => _nudge(0, 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      tooltip: 'Nudge right',
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      onPressed: () => _nudge(1, 0),
                    ),
                  ],
                ),
                // Feet per square section
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Feet: ', style: TextStyle(fontSize: 13)),
                    SizedBox(
                      width: 46,
                      child: TextField(
                        controller: _feetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13),
                        onChanged: _onFeetTextChanged,
                      ),
                    ),
                    const Text(' ft', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
