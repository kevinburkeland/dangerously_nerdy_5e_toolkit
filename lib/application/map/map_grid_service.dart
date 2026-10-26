import 'package:meta/meta.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/value_objects/blob_ref.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

import 'grid_geometry.dart';

/// A small immutable value representing changes to a [MapGrid].
@immutable
class MapGridEdit {
  final int? cellCentiPx;
  final int? offsetXCentiPx;
  final int? offsetYCentiPx;
  final int? feetPerCell;

  const MapGridEdit({
    this.cellCentiPx,
    this.offsetXCentiPx,
    this.offsetYCentiPx,
    this.feetPerCell,
  });

  /// True if no fields are set.
  bool get isEmpty =>
      cellCentiPx == null &&
      offsetXCentiPx == null &&
      offsetYCentiPx == null &&
      feetPerCell == null;

  /// Merges this edit with [later], where fields set in [later] win.
  MapGridEdit merge(MapGridEdit later) {
    return MapGridEdit(
      cellCentiPx: later.cellCentiPx ?? cellCentiPx,
      offsetXCentiPx: later.offsetXCentiPx ?? offsetXCentiPx,
      offsetYCentiPx: later.offsetYCentiPx ?? offsetYCentiPx,
      feetPerCell: later.feetPerCell ?? feetPerCell,
    );
  }

  /// Copies [base], replacing fields set in this edit, and reducing offsets
  /// modulo the resulting cell size into [0, cellCentiPx).
  /// [visible] and [mapSha256Hex] always come from [base].
  MapGrid applyTo(MapGrid base) {
    final newCell = cellCentiPx ?? base.cellCentiPx;
    final rawX = offsetXCentiPx ?? base.offsetXCentiPx;
    final rawY = offsetYCentiPx ?? base.offsetYCentiPx;
    var newX = rawX % newCell;
    if (newX < 0) newX += newCell;
    var newY = rawY % newCell;
    if (newY < 0) newY += newCell;

    return MapGrid(
      mapSha256Hex: base.mapSha256Hex,
      cellCentiPx: newCell,
      offsetXCentiPx: newX,
      offsetYCentiPx: newY,
      feetPerCell: feetPerCell ?? base.feetPerCell,
      visible: base.visible,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapGridEdit &&
          cellCentiPx == other.cellCentiPx &&
          offsetXCentiPx == other.offsetXCentiPx &&
          offsetYCentiPx == other.offsetYCentiPx &&
          feetPerCell == other.feetPerCell;

  @override
  int get hashCode => Object.hash(
        cellCentiPx,
        offsetXCentiPx,
        offsetYCentiPx,
        feetPerCell,
      );

  @override
  String toString() =>
      'MapGridEdit(cell: $cellCentiPx, offset: ($offsetXCentiPx, $offsetYCentiPx), feet: $feetPerCell)';
}

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

  /// Applies [edit] to the profile's grid if present and matching [map].
  /// If the profile's grid is null or its hash differs from [map.sha256Hex],
  /// returns the profile unchanged.
  Future<void> applyEdit(String campaignId, BlobRef map, MapGridEdit edit) async {
    await campaignRepo.updateProfile(campaignId, (current) {
      final grid = current.mapGrid;
      if (grid == null || grid.mapSha256Hex != map.sha256Hex) {
        return current;
      }
      return current.withMapGrid(edit.applyTo(grid), clock.nextTimestamp());
    });
  }

  /// Toggles visibility of the grid for [map].
  /// - No grid for this map -> write defaultGridFor(map)
  /// - Visible grid -> write it with visible: false
  /// - Hidden grid -> write it with visible: true
  Future<void> toggleVisible(String campaignId, BlobRef map) async {
    await campaignRepo.updateProfile(campaignId, (current) {
      final grid = current.mapGrid;
      final MapGrid newGrid;
      if (grid == null || grid.mapSha256Hex != map.sha256Hex) {
        newGrid = defaultGridFor(map);
      } else if (grid.visible) {
        newGrid = MapGrid(
          mapSha256Hex: grid.mapSha256Hex,
          cellCentiPx: grid.cellCentiPx,
          offsetXCentiPx: grid.offsetXCentiPx,
          offsetYCentiPx: grid.offsetYCentiPx,
          feetPerCell: grid.feetPerCell,
          visible: false,
        );
      } else {
        newGrid = MapGrid(
          mapSha256Hex: grid.mapSha256Hex,
          cellCentiPx: grid.cellCentiPx,
          offsetXCentiPx: grid.offsetXCentiPx,
          offsetYCentiPx: grid.offsetYCentiPx,
          feetPerCell: grid.feetPerCell,
          visible: true,
        );
      }
      return current.withMapGrid(newGrid, clock.nextTimestamp());
    });
  }

  /// Sets grid corner alignment to (x, y).
  /// - No grid for this map -> no write (profile returned unchanged)
  /// - Otherwise -> write gridWithCornerAt(grid, x, y)
  Future<void> setCornerAt(String campaignId, BlobRef map, double x, double y) async {
    await campaignRepo.updateProfile(campaignId, (current) {
      final grid = current.mapGrid;
      if (grid == null || grid.mapSha256Hex != map.sha256Hex) {
        return current;
      }
      return current.withMapGrid(gridWithCornerAt(grid, x, y), clock.nextTimestamp());
    });
  }
}
