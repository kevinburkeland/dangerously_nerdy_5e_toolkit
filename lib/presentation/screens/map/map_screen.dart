import 'package:flutter/material.dart';

import '../../../application/map/active_map_controller.dart';
import '../../../application/map/map_image_intake_port.dart';
import '../../../application/map/map_intake_service.dart';
import '../../../infrastructure/di/injection_container.dart';
import '../../widgets/map/map_view.dart';

import '../../../application/map/map_grid_service.dart';
import '../../../application/map/map_token_service.dart';
import '../../../infrastructure/dtos/character_telemetry_dto.dart';

Map<String, String> characterNamesFromTelemetry(Map<String, CharacterTelemetryDto> telemetry) {
  final result = <String, String>{};
  for (final entry in telemetry.entries) {
    if (entry.value.id == entry.key) {
      final trimmed = entry.value.name.trim();
      if (trimmed.isNotEmpty) {
        result[entry.key] = trimmed;
      }
    }
  }
  return result;
}

class MapScreen extends StatefulWidget {
  final bool canEditMap;
  final ActiveMapController? controller;
  final MapIntakeService? intakeService;
  final MapImageIntakePort? intake;
  final MapGridService? gridService;
  final TransformationController? transformationController;
  final MapTokenService? tokenService;
  final String? membershipCharacterId;
  final String playerName;
  final List<({String slug, String name})> localCharacters;
  final Map<String, String> characterNames;

  const MapScreen({
    super.key,
    this.canEditMap = false,
    this.controller,
    this.intakeService,
    this.intake,
    this.gridService,
    this.transformationController,
    this.tokenService,
    this.membershipCharacterId,
    this.playerName = '',
    this.localCharacters = const [],
    this.characterNames = const {},
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final ActiveMapController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? sl<ActiveMapController>();
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: MapView(
        controller: _controller,
        canEditMap: widget.canEditMap,
        intakeService: widget.intakeService,
        intake: widget.intake,
        gridService: widget.gridService,
        transformationController: widget.transformationController,
        tokenService: widget.tokenService,
        membershipCharacterId: widget.membershipCharacterId,
        playerName: widget.playerName,
        localCharacters: widget.localCharacters,
        characterNames: widget.characterNames,
      ),
    );
  }
}
