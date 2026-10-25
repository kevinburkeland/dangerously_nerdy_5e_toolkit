import 'package:flutter/material.dart';

import '../../../application/map/active_map_controller.dart';
import '../../../application/map/map_image_intake_port.dart';
import '../../../application/map/map_intake_service.dart';
import '../../../infrastructure/di/injection_container.dart';
import '../../widgets/map/map_view.dart';

class MapScreen extends StatefulWidget {
  final bool canEditMap;
  final ActiveMapController? controller;
  final MapIntakeService? intakeService;
  final MapImageIntakePort? intake;

  const MapScreen({
    super.key,
    this.canEditMap = false,
    this.controller,
    this.intakeService,
    this.intake,
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
      ),
    );
  }
}
