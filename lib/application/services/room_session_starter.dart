import 'room_sync_orchestrator.dart';
import '../map/active_map_controller.dart';

class RoomSessionStarter {
  final RoomSyncOrchestrator orchestrator;
  final ActiveMapController maps;

  RoomSessionStarter({
    required this.orchestrator,
    required this.maps,
  });

  /// Starts room sync and map serving/fetching together. Safe to call more than once.
  void start() {
    orchestrator.startSynchronization();
    maps.start();
  }
}
