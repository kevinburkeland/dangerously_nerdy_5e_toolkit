import 'package:flutter/material.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';

/// Compact controls panel for configuring grid size, alignment, and scale.
class MapGridControls extends StatefulWidget {
  final MapGrid grid;
  final ValueChanged<int> onCellSizeChanged;
  final void Function(int dx, int dy) onNudge;
  final ValueChanged<int> onFeetChanged;
  final VoidCallback onStartSetCorner;
  final bool isSettingCorner;

  const MapGridControls({
    super.key,
    required this.grid,
    required this.onCellSizeChanged,
    required this.onNudge,
    required this.onFeetChanged,
    required this.onStartSetCorner,
    this.isSettingCorner = false,
  });

  @override
  State<MapGridControls> createState() => _MapGridControlsState();
}

class _MapGridControlsState extends State<MapGridControls> {
  late TextEditingController _sizeController;
  late TextEditingController _feetController;
  late FocusNode _sizeFocusNode;
  late FocusNode _feetFocusNode;

  String? _sizeError;
  String? _feetError;

  @override
  void initState() {
    super.initState();
    final displayedSizePx = widget.grid.cellCentiPx / 100.0;
    _sizeController = TextEditingController(text: _formatSize(displayedSizePx));
    _feetController = TextEditingController(text: widget.grid.feetPerCell.toString());
    _sizeFocusNode = FocusNode();
    _feetFocusNode = FocusNode();
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
    if (!_sizeFocusNode.hasFocus) {
      final parsedSize = double.tryParse(_sizeController.text);
      final displayedSizePx = widget.grid.cellCentiPx / 100.0;
      if (parsedSize == null || (parsedSize - displayedSizePx).abs() > 0.001) {
        _sizeController.text = _formatSize(displayedSizePx);
        if (_sizeError != null) {
          setState(() {
            _sizeError = null;
          });
        }
      }
    }
    if (!_feetFocusNode.hasFocus) {
      final parsedFeet = int.tryParse(_feetController.text);
      if (parsedFeet != widget.grid.feetPerCell) {
        _feetController.text = widget.grid.feetPerCell.toString();
        if (_feetError != null) {
          setState(() {
            _feetError = null;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _feetController.dispose();
    _sizeFocusNode.dispose();
    _feetFocusNode.dispose();
    super.dispose();
  }

  void _stepSize(double delta) {
    final curSizePx = widget.grid.cellCentiPx / 100.0;
    final nextSize = ((curSizePx + delta) * 100.0).round() / 100.0;
    if (nextSize < 10.0 || nextSize > 512.0) {
      setState(() {
        _sizeError = 'Square size must be between 10 and 512 px.';
      });
      return;
    }
    setState(() {
      _sizeError = null;
    });
    final nextCentiPx = (nextSize * 100.0).round();
    _sizeController.text = _formatSize(nextSize);
    widget.onCellSizeChanged(nextCentiPx);
  }

  void _onSizeTextChanged(String text) {
    final val = double.tryParse(text);
    if (val == null || val < 10.0 || val > 512.0) {
      setState(() {
        _sizeError = 'Square size must be between 10 and 512 px.';
      });
      return;
    }
    setState(() {
      _sizeError = null;
    });
    final nextCentiPx = (val * 100.0).round();
    widget.onCellSizeChanged(nextCentiPx);
  }

  void _onFeetTextChanged(String text) {
    final val = int.tryParse(text);
    if (val == null || val < 1 || val > 100) {
      setState(() {
        _feetError = 'Feet per square must be a whole number from 1 to 100.';
      });
      return;
    }
    setState(() {
      _feetError = null;
    });
    widget.onFeetChanged(val);
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Size controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Size: ', style: TextStyle(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Decrease size',
                      onPressed: () => _stepSize(-0.5),
                    ),
                    SizedBox(
                      width: 52,
                      child: TextField(
                        controller: _sizeController,
                        focusNode: _sizeFocusNode,
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
                      icon: const Icon(Icons.add, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Increase size',
                      onPressed: () => _stepSize(0.5),
                    ),
                    const Text('px', style: TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(width: 12),
                // Nudge controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nudge: ', style: TextStyle(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Nudge left',
                      onPressed: () => widget.onNudge(-1, 0),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Nudge up',
                      onPressed: () => widget.onNudge(0, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Nudge down',
                      onPressed: () => widget.onNudge(0, 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Nudge right',
                      onPressed: () => widget.onNudge(1, 0),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                // Set corner
                OutlinedButton.icon(
                  onPressed: widget.onStartSetCorner,
                  icon: const Icon(Icons.crop_free, size: 16),
                  label: const Text('Set a corner', style: TextStyle(fontSize: 13)),
                  style: widget.isSettingCorner
                      ? OutlinedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Feet per square
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Feet: ', style: TextStyle(fontSize: 13)),
                    SizedBox(
                      width: 46,
                      child: TextField(
                        controller: _feetController,
                        focusNode: _feetFocusNode,
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
          if (_sizeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _sizeError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          if (_feetError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _feetError!,
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
