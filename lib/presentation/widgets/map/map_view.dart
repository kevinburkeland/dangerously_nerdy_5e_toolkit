import 'dart:async';
import 'package:flutter/material.dart';

import '../../../application/blob/blob_store_port.dart';
import '../../../application/map/active_map_controller.dart';
import '../../../application/map/map_image_intake_port.dart';
import '../../../application/map/map_intake_service.dart';
import '../../../infrastructure/di/injection_container.dart';
import '../../../services/logging_service.dart';

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
  final bool canEditMap;

  const MapView({
    super.key,
    required this.controller,
    this.intakeService,
    this.intake,
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

  @override
  void initState() {
    super.initState();
    _currentState = widget.controller.current;
    _sub = widget.controller.states.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _sub?.cancel();
      _currentState = widget.controller.current;
      _sub = widget.controller.states.listen((state) {
        if (mounted) {
          setState(() {
            _currentState = state;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _checkLogging(ActiveMapViewState state) {
    if (state is MapFailed && !identical(state.error, _lastLoggedFailedError)) {
      _lastLoggedFailedError = state.error;
      LoggingService().logNonFatal(state.error, null, reason: 'Map loading failed');
    }
  }

  Future<void> _handleChooseMap() async {
    final intake = widget.intake ??
        (sl.isRegistered<MapImageIntakePort>()
            ? sl<MapImageIntakePort>()
            : null);
    final intakeService = widget.intakeService ??
        (sl.isRegistered<MapIntakeService>()
            ? sl<MapIntakeService>()
            : null);
    if (intake == null || intakeService == null) return;

    final source = await intake.pick();
    if (source == null) return;

    setState(() {
      _isPreparing = true;
      _statusMessage = null;
    });

    final campaignId = widget.controller.campaignId;
    if (campaignId == null) {
      setState(() {
        _isPreparing = false;
        _statusMessage = 'The map couldn\'t be shared: No active campaign';
      });
      return;
    }

    try {
      final res = await intakeService.setMapFromSource(source, campaignId: campaignId);
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
        }
      });
    } on MapIntakeUnavailableException catch (e) {
      setState(() {
        _isPreparing = false;
        _statusMessage = "The map couldn't be shared: ${e.message}";
      });
    } on BlobStoreUnavailableException catch (e) {
      setState(() {
        _isPreparing = false;
        _statusMessage = "The map couldn't be shared: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _isPreparing = false;
        final msg = e.toString().replaceFirst('Exception: ', '');
        _statusMessage = "The map couldn't be shared: $msg";
      });
    }
  }

  Future<void> _handleClearMap() async {
    final intakeService = widget.intakeService ??
        (sl.isRegistered<MapIntakeService>()
            ? sl<MapIntakeService>()
            : null);
    final cId = widget.controller.campaignId;
    if (intakeService != null && cId != null) {
      await intakeService.clearMap(campaignId: cId);
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
        return InteractiveViewer(
          minScale: 0.1,
          maxScale: 8.0,
          child: Center(
            child: Image.memory(
              state.bytes,
              gaplessPlayback: true,
              fit: BoxFit.contain,
            ),
          ),
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

    return Column(
      children: [
        if (widget.canEditMap) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
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
              ],
            ),
          ),
          if (_isPreparing)
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
          if (_statusMessage != null && !_isPreparing)
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
        ],
        Expanded(
          child: _buildStateContent(state),
        ),
      ],
    );
  }
}
