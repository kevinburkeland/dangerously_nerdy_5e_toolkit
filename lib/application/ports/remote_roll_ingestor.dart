import 'package:vtt_engine_core/models/room_roll.dart';

/// Pure Dart port for ingesting remote dice rolls received over room sync.
abstract class IRemoteRollIngestor {
  void ingestRemoteRoll(RoomRoll roll);
}
