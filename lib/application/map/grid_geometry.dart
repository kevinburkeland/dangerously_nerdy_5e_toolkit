import 'dart:math' as math;
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';
import 'package:vtt_engine_core/models/value_objects/map_token.dart';

int _coordToCell(double coord, int offsetCentiPx, int cellCentiPx) {
  final centi = coord * 100.0;
  final nearestInt = centi.round();
  final effectiveCenti = (centi - nearestInt).abs() < 1e-5 ? nearestInt.toDouble() : centi;
  return ((effectiveCenti - offsetCentiPx) / cellCentiPx).floor();
}

/// The square containing image point (x, y). Squares are half-open:
/// a point exactly on a line belongs to the square to its right/below.
/// Points left of or above the first line get negative indices.
({int col, int row}) cellAt(MapGrid g, double x, double y) {
  return (
    col: _coordToCell(x, g.offsetXCentiPx, g.cellCentiPx),
    row: _coordToCell(y, g.offsetYCentiPx, g.cellCentiPx),
  );
}

/// The center point in image pixels of the cell at (col, row).
({double x, double y}) cellCenter(MapGrid g, int col, int row) {
  return (
    x: (g.offsetXCentiPx + (col + 0.5) * g.cellCentiPx) / 100.0,
    y: (g.offsetYCentiPx + (row + 0.5) * g.cellCentiPx) / 100.0,
  );
}

/// Snaps the point (x, y) to the center of the cell containing it.
({double x, double y}) snapToCellCenter(MapGrid g, double x, double y) {
  final cell = cellAt(g, x, y);
  return cellCenter(g, cell.col, cell.row);
}

/// The D&D 5e grid rule, every square counts once, diagonals included.
int gridDistanceSquares(int col1, int row1, int col2, int row2) {
  return math.max((col1 - col2).abs(), (row1 - row2).abs());
}

/// Distance in feet using the D&D 5e grid rule.
int gridDistanceFeet(MapGrid g, int col1, int row1, int col2, int row2) {
  return gridDistanceSquares(col1, row1, col2, row2) * g.feetPerCell;
}

/// Every vertical line position from the offset, one cell apart, inside [0, imageWidth].
List<double> verticalLines(MapGrid g, int imageWidth) {
  if (imageWidth < 0) return const [];
  final maxI = ((imageWidth * 100 - g.offsetXCentiPx) / g.cellCentiPx).floor();
  if (maxI < 0) return const [];
  final count = maxI + 1;
  final lines = List<double>.filled(count, 0.0);
  for (int i = 0; i < count; i++) {
    lines[i] = (g.offsetXCentiPx + i * g.cellCentiPx) / 100.0;
  }
  return lines;
}

/// Every horizontal line position from the offset, one cell apart, inside [0, imageHeight].
List<double> horizontalLines(MapGrid g, int imageHeight) {
  if (imageHeight < 0) return const [];
  final maxI = ((imageHeight * 100 - g.offsetYCentiPx) / g.cellCentiPx).floor();
  if (maxI < 0) return const [];
  final count = maxI + 1;
  final lines = List<double>.filled(count, 0.0);
  for (int i = 0; i < count; i++) {
    lines[i] = (g.offsetYCentiPx + i * g.cellCentiPx) / 100.0;
  }
  return lines;
}

/// The same grid with its offsets moved so that a line crossing sits at (x, y).
MapGrid gridWithCornerAt(MapGrid g, double x, double y) {
  int newOffsetX = (x * 100.0).round() % g.cellCentiPx;
  if (newOffsetX < 0) newOffsetX += g.cellCentiPx;
  int newOffsetY = (y * 100.0).round() % g.cellCentiPx;
  if (newOffsetY < 0) newOffsetY += g.cellCentiPx;
  return MapGrid(
    mapSha256Hex: g.mapSha256Hex,
    cellCentiPx: g.cellCentiPx,
    offsetXCentiPx: newOffsetX,
    offsetYCentiPx: newOffsetY,
    feetPerCell: g.feetPerCell,
    visible: g.visible,
  );
}

/// Returns true if the centre of the square lies inside the image:
/// 0 <= 2*offsetXCentiPx + (2*col + 1)*cellCentiPx < 200*imageWidth
/// and similarly for row and imageHeight.
bool isCellOnMap(MapGrid g, int imageWidth, int imageHeight, MapTokenCell c) {
  final cx = 2 * g.offsetXCentiPx + (2 * c.col + 1) * g.cellCentiPx;
  final cy = 2 * g.offsetYCentiPx + (2 * c.row + 1) * g.cellCentiPx;
  return cx >= 0 && cx < 200 * imageWidth && cy >= 0 && cy < 200 * imageHeight;
}

int _nearestOnAxis(int offsetCentiPx, int cellCentiPx, int imageDimension, int coord) {
  if (imageDimension <= 0) return 0;
  final limit = 200 * imageDimension;

  // c is on the image when 0 <= 2*offsetCentiPx + (2*c + 1)*cellCentiPx < 200*imageDimension
  // In MapTokenCell range [-1, 4095]:
  // Minimum c:
  // 2*offset + (2*c + 1)*cell >= 0 <=> (2*c + 1)*cell >= -2*offset <=> 2*c + 1 >= (-2*offset)/cell
  // Since 0 <= offset < cell:
  // For c = -1: 2*offset - cell >= 0 <=> 2*offset >= cell
  // If 2*offset >= cell, c = -1 gives cx >= 0.
  // Otherwise, for c = 0: 2*offset + cell > 0 (always >= 0).
  final cMin = (2 * offsetCentiPx >= cellCentiPx) ? -1 : 0;
  final cxMin = 2 * offsetCentiPx + (2 * cMin + 1) * cellCentiPx;
  if (cxMin >= limit) {
    return 0; // No square's centre is on the image
  }

  // Maximum c in [-1, 4095]:
  // 2*offset + (2*c + 1)*cell < limit
  // 2*c*cell + cell < limit - 2*offset
  // 2*c*cell <= limit - 2*offset - cell - 1
  // c <= (limit - 2*offset - cell - 1) / (2*cell)
  final num = limit - 2 * offsetCentiPx - cellCentiPx - 1;
  final denom = 2 * cellCentiPx;
  int cMax = (num / denom).floor();
  if (cMax > MapTokenCell.maxIndex) {
    cMax = MapTokenCell.maxIndex;
  }
  if (cMax < cMin) {
    return 0;
  }

  if (coord <= cMin) return cMin;
  if (coord >= cMax) return cMax;
  return coord;
}

/// The square nearest (col, row) whose centre lies on the image (see isCellOnMap).
/// Column and row are chosen independently. Inputs may be any int.
({int col, int row}) nearestOnMapCell(MapGrid g, int imageWidth, int imageHeight, int col, int row) {
  return (
    col: _nearestOnAxis(g.offsetXCentiPx, g.cellCentiPx, imageWidth, col),
    row: _nearestOnAxis(g.offsetYCentiPx, g.cellCentiPx, imageHeight, row),
  );
}

/// The id of the last entry in [drawn] (drawing order, last = on top) whose square is
/// the square containing image point (x, y), using cellAt. Null if none.
String? tokenAt(List<({String id, int col, int row})> drawn, MapGrid g, double x, double y) {
  final target = cellAt(g, x, y);
  for (int i = drawn.length - 1; i >= 0; i--) {
    final entry = drawn[i];
    if (entry.col == target.col && entry.row == target.row) {
      return entry.id;
    }
  }
  return null;
}

