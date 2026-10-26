import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../../application/blob/blob_store_port.dart';
import '../../../application/map/active_map_controller.dart';
import '../../../application/map/grid_geometry.dart';
import '../../../application/map/map_grid_editor.dart';
import '../../../application/map/map_grid_service.dart';
import '../../../application/map/map_image_intake_port.dart';
import '../../../application/map/map_intake_service.dart';
import '../../../infrastructure/di/injection_container.dart';
import '../../../services/logging_service.dart';
import 'map_grid_controls.dart';
import 'map_grid_overlay.dart';

String _formatThousands(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  final offset = s.length % 3;
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (i - offset) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(s[i]);
  }
  return buffer.toString();
}

class MapView extends StatefulWidget {
  final ActiveMapController controller;
  final MapIntakeService? intakeService;
  final MapImageIntakePort? intake;
  final MapGridService? gridService;
  final TransformationController? transformationController;
  final bool canEditMap;

  const MapView({
    super.key,
    required this.controller,
    this.intakeService,
    this.intake,
    this.gridService,
    this.transformationController,
    this.canEditMap = false,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  bool _isPreparing = false;
  String? _statusMessage;
  Object? _lastLoggedFailedError;
  late ActiveMapViewState _currentState;
  StreamSubscription<ActiveMapViewState>? _sub;

  late final TransformationController _internalTransformController;
  TransformationController get _transformController =>
      widget.transformationController ?? _internalTransformController;

  double _currentScale = 1.0;
  String? _lastFittedRefSha;
  String? _lastMapSha;
  Size? _currentViewportSize;

  bool _isMeasuring = false;
  bool _isSettingCorner = false;
  Offset? _rulerStart;
  Offset? _rulerEnd;
  String? _rulerLabel;

  MapGridEditor? _gridEditor;

  MapGridService get _gridService =>
      widget.gridService ?? sl<MapGridService>();

  @override
  void initState() {
    super.initState();
    _internalTransformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
    _currentState = widget.controller.current;
    _syncGridAndRulerState(_currentState);
    _syncGridEditor(_currentState);
    _sub = widget.controller.states.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
          _syncGridAndRulerState(state);
          _syncGridEditor(state);
        });
      }
    });
  }

  void _onTransformChanged() {
    final s = _transformController.value.getMaxScaleOnAxis();
    if (s > 0 && (s - _currentScale).abs() > 1e-4 && mounted) {
      setState(() {
        _currentScale = s;
      });
    }
  }

  void _syncGridAndRulerState(ActiveMapViewState state) {
    if (state is MapReady) {
      if (_lastMapSha != state.ref.sha256Hex ||
          state.grid == null ||
          !state.grid!.visible) {
        _isMeasuring = false;
        _isSettingCorner = false;
        _rulerStart = null;
        _rulerEnd = null;
        _rulerLabel = null;
      }
      _lastMapSha = state.ref.sha256Hex;
    } else {
      _isMeasuring = false;
      _isSettingCorner = false;
      _rulerStart = null;
      _rulerEnd = null;
      _rulerLabel = null;
      _lastMapSha = null;
    }
  }

  void _syncGridEditor(ActiveMapViewState state) {
    if (state is MapReady) {
      final campaignId = widget.controller.campaignId;
      final service = _gridService;
      if (campaignId == null) {
        _gridEditor?.dispose();
        _gridEditor = null;
        return;
      }
      if (_gridEditor == null ||
          _gridEditor!.map.sha256Hex != state.ref.sha256Hex ||
          _gridEditor!.campaignId != campaignId) {
        _gridEditor?.dispose();
        _gridEditor = MapGridEditor(
          service: service,
          campaignId: campaignId,
          map: state.ref,
        );
      } else {
        _gridEditor!.latestArrived();
      }
    } else {
      _gridEditor?.dispose();
      _gridEditor = null;
    }
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _sub?.cancel();
      _currentState = widget.controller.current;
      _syncGridAndRulerState(_currentState);
      _syncGridEditor(_currentState);
      _sub = widget.controller.states.listen((state) {
        if (mounted) {
          setState(() {
            _currentState = state;
            _syncGridAndRulerState(state);
            _syncGridEditor(state);
          });
        }
      });
    }
    if (oldWidget.transformationController != widget.transformationController) {
      oldWidget.transformationController?.removeListener(_onTransformChanged);
      _transformController.addListener(_onTransformChanged);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _transformController.removeListener(_onTransformChanged);
    _internalTransformController.dispose();
    _gridEditor?.dispose();
    _gridEditor = null;
    super.dispose();
  }

  void _checkLogging(ActiveMapViewState state) {
    if (state is MapFailed && !identical(state.error, _lastLoggedFailedError)) {
      _lastLoggedFailedError = state.error;
      LoggingService().logNonFatal(state.error, null, reason: 'Map loading failed');
    }
  }

  void _handleChooseMap() {
    final intake = widget.intake ?? sl<MapImageIntakePort>();
    final intakeService = widget.intakeService ?? sl<MapIntakeService>();
    _chooseMap(intake, intakeService);
  }

  Future<void> _chooseMap(MapImageIntakePort intake, MapIntakeService intakeService) async {
    final source = await intake.pick();
    if (!mounted) return;
    if (source == null) return;

    setState(() {
      _isPreparing = true;
      _statusMessage = null;
    });

    final campaignId = widget.controller.campaignId;
    if (campaignId == null) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _statusMessage = "The map couldn't be shared: No active campaign";
      });
      return;
    }

    try {
      final res = await intakeService.setMapFromSource(source, campaignId: campaignId);
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        if (res.scaledDown) {
          _statusMessage =
              'Map shared. Scaled down from ${_formatThousands(res.originalWidth)} × ${_formatThousands(res.originalHeight)} to ${_formatThousands(res.ref.width)} × ${_formatThousands(res.ref.height)} px.';
        } else {
          _statusMessage = 'Map shared.';
        }
      });
    } on MapIntakeRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        switch (e.reason) {
          case MapRejectReason.fileTooLarge:
            final mb = e.byteSize != null ? (e.byteSize! / (1024 * 1024)).round() : 0;
            _statusMessage = 'This file is $mb MB. The largest file you can pick is 200 MB.';
          case MapRejectReason.tooManyPixels:
            _statusMessage =
                'This image is ${_formatThousands(e.width ?? 0)} × ${_formatThousands(e.height ?? 0)} px. The largest image you can pick is 8,192 px on its longest side.';
          case MapRejectReason.unsupportedFormat:
            _statusMessage =
                "This file type can't be used as a map. Export it as PNG or WebP and try again.";
          case MapRejectReason.unreadable:
          case MapRejectReason.undecodable:
            _statusMessage =
                "This image couldn't be read. Export it again as PNG or WebP.";
          case MapRejectReason.outputTooLarge:
            _statusMessage =
                'This map is still over 10 MB after compression. Try a smaller or simpler image.';
          case MapRejectReason.encoderMismatch:
            _statusMessage =
                'This browser produced an unexpected image. Try another browser.';
          case MapRejectReason.orientationMismatch:
            _statusMessage =
                'This browser turned the image differently than expected. Rotate it in a photo editor, save it, and try again.';
        }
      });
    } on MapIntakeUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _statusMessage = "The map couldn't be shared: ${e.message}";
      });
    } on BlobStoreUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        _statusMessage = "The map couldn't be shared: ${e.message}";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPreparing = false;
        final msg = e.toString().replaceFirst('Exception: ', '');
        _statusMessage = "The map couldn't be shared: $msg";
      });
    }
  }

  Future<void> _handleClearMap() async {
    final campaignId = widget.controller.campaignId;
    if (campaignId == null) return;
    try {
      final intakeService = widget.intakeService ?? sl<MapIntakeService>();
      await intakeService.clearMap(campaignId: campaignId);
    } catch (_) {
      // intentional: clearMap failure non-fatal to view display
    }
  }

  void _handleToggleGrid() {
    _gridEditor?.clearWriteError();
    _gridEditor?.toggleVisible();
  }

  Matrix4 _computeFitMatrix(Size viewportSize, BlobRef ref) {
    final scaleX = viewportSize.width / ref.width;
    final scaleY = viewportSize.height / ref.height;
    final fitScale = math.min(scaleX, scaleY).clamp(0.05, 8.0);
    final tx = (viewportSize.width - ref.width * fitScale) / 2.0;
    final ty = (viewportSize.height - ref.height * fitScale) / 2.0;
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(fitScale, fitScale, 1.0, 1.0);
  }

  void _applyFitMatrix(Size viewportSize, BlobRef ref) {
    final matrix = _computeFitMatrix(viewportSize, ref);
    _transformController.removeListener(_onTransformChanged);
    _transformController.value = matrix;
    _currentScale = matrix.getMaxScaleOnAxis();
    _transformController.addListener(_onTransformChanged);
  }

  void _initFit(Size viewportSize, BlobRef ref) {
    if (_lastFittedRefSha == ref.sha256Hex) return;
    _lastFittedRefSha = ref.sha256Hex;
    _applyFitMatrix(viewportSize, ref);
  }

  void _handleRecenter() {
    final state = _currentState;
    if (state is! MapReady) return;
    final size = _currentViewportSize;
    if (size != null && size.width > 0 && size.height > 0) {
      _applyFitMatrix(size, state.ref);
      setState(() {});
    }
  }

  Widget _buildStateContent(ActiveMapViewState state) {
    switch (state) {
      case MapNone():
        return const Center(child: Text("No map yet. The DM hasn't shared one."));
      case MapLoading():
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening map…'),
            ],
          ),
        );
      case MapDownloading():
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Downloading map, ${state.percent}%'),
            ],
          ),
        );
      case MapWaitingForPeer():
        return const Center(child: Text('Waiting for a player who has the map'));
      case MapConnecting():
        return const Center(child: Text('Connecting to other players…'));
      case MapRelayOnly():
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              "This map can't reach you over the relay connection. Ask the DM to connect you directly.",
              textAlign: TextAlign.center,
            ),
          ),
        );
      case MapStoreUnavailable():
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text('Maps can\'t be stored in this browser: ${state.message}'),
          ),
        );
      case MapReady():
        final displayedGrid = (state.grid != null && _gridEditor != null)
            ? _gridEditor!.displayed(state.grid!)
            : state.grid;

        return LayoutBuilder(
          builder: (context, constraints) {
            final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
            _currentViewportSize = currentSize;
            _initFit(currentSize, state.ref);
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: _isSettingCorner && displayedGrid != null
                  ? (details) {
                      final scene = _transformController.toScene(details.localPosition);
                      _gridEditor?.clearWriteError();
                      _gridEditor?.setCornerAt(scene.dx, scene.dy);
                      setState(() {
                        _isSettingCorner = false;
                      });
                    }
                  : null,
              child: InteractiveViewer(
                boundaryMargin: const EdgeInsets.all(double.infinity),
                constrained: false,
                minScale: 0.05,
                maxScale: 8.0,
                transformationController: _transformController,
                panEnabled: !_isMeasuring && !_isSettingCorner,
                scaleEnabled: true,
                onInteractionStart: (details) {
                  if (_isMeasuring && displayedGrid != null && details.pointerCount == 1) {
                    final scene = _transformController.toScene(details.localFocalPoint);
                    final snapped = snapToCellCenter(displayedGrid, scene.dx, scene.dy);
                    setState(() {
                      _rulerStart = Offset(snapped.x, snapped.y);
                      _rulerEnd = Offset(snapped.x, snapped.y);
                      final c1 = cellAt(displayedGrid, snapped.x, snapped.y);
                      final sq = gridDistanceSquares(c1.col, c1.row, c1.col, c1.row);
                      final ft = gridDistanceFeet(displayedGrid, c1.col, c1.row, c1.col, c1.row);
                      _rulerLabel = '$sq squares · $ft ft';
                    });
                  }
                },
                onInteractionUpdate: (details) {
                  if (_isMeasuring && displayedGrid != null && details.pointerCount == 1) {
                    final scene = _transformController.toScene(details.localFocalPoint);
                    final snapped = snapToCellCenter(displayedGrid, scene.dx, scene.dy);
                    setState(() {
                      _rulerEnd = Offset(snapped.x, snapped.y);
                      if (_rulerStart != null) {
                        final c1 = cellAt(displayedGrid, _rulerStart!.dx, _rulerStart!.dy);
                        final c2 = cellAt(displayedGrid, snapped.x, snapped.y);
                        final sq = gridDistanceSquares(c1.col, c1.row, c2.col, c2.row);
                        final ft = gridDistanceFeet(displayedGrid, c1.col, c1.row, c2.col, c2.row);
                        _rulerLabel = sq == 1 ? '1 square · $ft ft' : '$sq squares · $ft ft';
                      }
                    });
                  }
                },
                child: SizedBox(
                  width: state.ref.width.toDouble(),
                  height: state.ref.height.toDouble(),
                  child: Stack(
                    children: [
                      Image.memory(
                        state.bytes,
                        width: state.ref.width.toDouble(),
                        height: state.ref.height.toDouble(),
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                      MapGridOverlay(
                        grid: displayedGrid,
                        scale: _currentScale,
                        width: state.ref.width,
                        height: state.ref.height,
                      ),
                      MapRulerOverlay(
                        start: _rulerStart,
                        end: _rulerEnd,
                        label: _rulerLabel,
                        scale: _currentScale,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      case MapFailed():
        final msg = state.error.toString().replaceFirst('Exception: ', '');
        return Center(child: Text('The map couldn\'t be loaded: $msg'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _currentState;
    _checkLogging(state);

    final isMapSet = state is! MapNone;
    final displayedGrid = (state is MapReady && state.grid != null && _gridEditor != null)
        ? _gridEditor!.displayed(state.grid!)
        : (state is MapReady ? state.grid : null);
    final hasVisibleGrid = displayedGrid != null && displayedGrid.visible;
    final showControlsRow = widget.canEditMap || state is MapReady;

    return Column(
      children: [
        if (showControlsRow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.canEditMap) ...[
                  ElevatedButton.icon(
                    onPressed: _isPreparing ? null : _handleChooseMap,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose map image'),
                  ),
                  if (isMapSet)
                    TextButton.icon(
                      onPressed: _isPreparing ? null : _handleClearMap,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear map'),
                    ),
                  if (state is MapReady)
                    OutlinedButton.icon(
                      onPressed: _isPreparing ? null : _handleToggleGrid,
                      icon: const Icon(Icons.grid_on),
                      label: const Text('Grid'),
                    ),
                ],
                if (state is MapReady)
                  OutlinedButton.icon(
                    onPressed: _handleRecenter,
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Recenter'),
                  ),
                if (hasVisibleGrid)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isMeasuring = !_isMeasuring;
                        if (!_isMeasuring) {
                          _rulerStart = null;
                          _rulerEnd = null;
                          _rulerLabel = null;
                        }
                      });
                    },
                    icon: const Icon(Icons.straighten),
                    label: const Text('Measure'),
                    style: _isMeasuring
                        ? OutlinedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                          )
                        : null,
                  ),
              ],
            ),
          ),
        if (widget.canEditMap && _isPreparing)
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Preparing map…'),
              ],
            ),
          ),
        if (widget.canEditMap && _statusMessage != null && !_isPreparing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ),
        if (widget.canEditMap && state is MapReady && displayedGrid != null && displayedGrid.visible && widget.controller.campaignId != null) ...[
          if (_gridEditor?.lastWriteError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(
                "Couldn't save the grid: ${_gridEditor!.lastWriteError.toString().replaceFirst('Exception: ', '')}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          MapGridControls(
            grid: displayedGrid,
            onCellSizeChanged: (cellCentiPx) {
              _gridEditor?.clearWriteError();
              _gridEditor?.setCellCentiPx(state.grid!, cellCentiPx);
              setState(() {});
            },
            onNudge: (dx, dy) {
              _gridEditor?.clearWriteError();
              _gridEditor?.nudge(state.grid!, dx, dy);
              setState(() {});
            },
            onFeetChanged: (feet) {
              _gridEditor?.clearWriteError();
              _gridEditor?.setFeetPerCell(state.grid!, feet);
              setState(() {});
            },
            onStartSetCorner: () {
              _gridEditor?.clearWriteError();
              setState(() {
                _isSettingCorner = !_isSettingCorner;
              });
            },
            isSettingCorner: _isSettingCorner,
          ),
        ],
        Expanded(
          child: _buildStateContent(state),
        ),
      ],
    );
  }
}
