import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/value_objects/blob_ref.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

/// Application service for creating and updating shared map grid configurations.
class MapGridService {
  final ICampaignRepository campaignRepo;
  final StatefulHlcClock clock;

  const MapGridService({
    required this.campaignRepo,
    required this.clock,
  });

  /// Writes [grid] to the campaign profile at [campaignId] with a fresh timestamp.
  Future<void> setGrid(String campaignId, MapGrid? grid) async {
    final stamp = clock.nextTimestamp();
    await campaignRepo.updateProfile(campaignId, (current) {
      return current.withMapGrid(grid, stamp);
    });
  }

  /// Default grid configuration for [map]: 50 px cells, 0 offsets, 5 ft per cell, visible.
  MapGrid defaultGridFor(BlobRef map) {
    return MapGrid(
      mapSha256Hex: map.sha256Hex,
      cellCentiPx: 5000,
      offsetXCentiPx: 0,
      offsetYCentiPx: 0,
      feetPerCell: 5,
      visible: true,
    );
  }
}
