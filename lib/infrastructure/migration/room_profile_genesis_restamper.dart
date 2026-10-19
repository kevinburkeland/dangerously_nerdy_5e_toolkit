import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';

/// Compatibility migration: re-stamps genesis-stamped RoomNodeState title/description
/// on opened campaign profiles to allow clean last-writer-wins convergence.
///
/// Implements Cold Iron Birdcage Pass 7.1 (Q4).
class RoomProfileGenesisRestamper {
  static bool isGenesisTimestamp(HybridLogicalClock ts) {
    return ts.nodeId == 'genesis' || ts.physicalTime == 0;
  }

  static CampaignProfile restampIfNeeded({
    required CampaignProfile profile,
    required StatefulHlcClock clock,
  }) {
    final roomState = profile.roomState;
    final needsTitle = isGenesisTimestamp(roomState.titleRegister.timestamp);
    final needsDesc = isGenesisTimestamp(roomState.descriptionRegister.timestamp);

    if (!needsTitle && !needsDesc) {
      return profile;
    }

    final newTitleTs =
        needsTitle ? clock.nextTimestamp() : roomState.titleRegister.timestamp;
    final newDescTs =
        needsDesc ? clock.nextTimestamp() : roomState.descriptionRegister.timestamp;

    final updatedRoomState = roomState.copyWith(
      titleTimestamp: newTitleTs,
      descriptionTimestamp: newDescTs,
    );

    return profile.copyWith(roomState: updatedRoomState);
  }
}
