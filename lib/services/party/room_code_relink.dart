import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';

/// Pure operation encapsulating campaign profile room code and room ID relinking.
class RoomCodeRelink {
  const RoomCodeRelink._();

  /// Relinks a [CampaignProfile] to a new [newRoomCode].
  ///
  /// Sets `roomId` to `room_<CODE>` and `roomCode` to the cleaned uppercase code.
  /// If [stampStagingTitle] is true, updates the staging title to 'Campaign $clean Staging'
  /// and stamps `titleTimestamp` using the injected [clock] (or preserves zero timestamp if placeholder).
  /// Returns the profile unchanged when the room code already matches [newRoomCode].
  static CampaignProfile relink(
    CampaignProfile profile,
    String newRoomCode,
    StatefulHlcClock clock, {
    bool stampStagingTitle = false,
  }) {
    final clean = newRoomCode.trim().toUpperCase();
    if (profile.roomState.roomCode.trim().toUpperCase() == clean) {
      return profile;
    }

    if (stampStagingTitle) {
      final isPlaceholder =
          profile.roomState.titleRegister.timestamp.physicalTime == 0;
      final newTs =
          isPlaceholder ? HybridLogicalClock.genesis : clock.nextTimestamp();
      return profile.copyWith(
        roomState: profile.roomState.copyWith(
          roomId: 'room_$clean',
          roomCode: clean,
          title: 'Campaign $clean Staging',
          titleTimestamp: newTs,
        ),
      );
    }

    return profile.copyWith(
      roomState: profile.roomState.copyWith(
        roomId: 'room_$clean',
        roomCode: clean,
      ),
    );
  }
}
