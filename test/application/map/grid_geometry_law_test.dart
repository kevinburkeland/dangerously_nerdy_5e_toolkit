import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';
import 'package:vtt_engine_core/models/value_objects/map_token.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/map/grid_geometry.dart';

MapGrid _randomGrid(Random rand) {
  final cell = 1000 + rand.nextInt(50201); // 1000..51200
  return MapGrid(
    mapSha256Hex: 'a' * 64,
    cellCentiPx: cell,
    offsetXCentiPx: rand.nextInt(cell),
    offsetYCentiPx: rand.nextInt(cell),
    feetPerCell: 1 + rand.nextInt(100),
    visible: rand.nextBool(),
  );
}

void main() {
  group('Grid Geometry Law Suite', () {
    test('GG2 explicit examples', () {
      expect(gridDistanceSquares(0, 0, 3, 0), equals(3));
      expect(gridDistanceSquares(0, 0, 3, 3), equals(3));
      expect(gridDistanceSquares(0, 0, 3, 5), equals(5));
      expect(gridDistanceSquares(2, 7, -1, 4), equals(3));

      final g5 = MapGrid(
        mapSha256Hex: 'a' * 64,
        cellCentiPx: 5000,
        offsetXCentiPx: 0,
        offsetYCentiPx: 0,
        feetPerCell: 5,
        visible: true,
      );
      expect(gridDistanceFeet(g5, 2, 7, -1, 4), equals(15));
    });

    test('GG1-GG5 geometry law across 2000 seeds', () {
      for (int seed = 0; seed < 2000; seed++) {
        final rand = Random(seed);
        final g = _randomGrid(rand);
        final cellPx = g.cellCentiPx / 100.0;

        // Points inside and outside 4096x4096
        final x = (rand.nextDouble() * 8192.0) - 2048.0;
        final y = (rand.nextDouble() * 8192.0) - 2048.0;

        // GG1
        final col = rand.nextInt(400) - 200;
        final row = rand.nextInt(400) - 200;
        final center = cellCenter(g, col, row);
        final recovered = cellAt(g, center.x, center.y);
        expect(recovered.col, equals(col), reason: 'Seed $seed GG1 col mismatch');
        expect(recovered.row, equals(row), reason: 'Seed $seed GG1 row mismatch');

        final snapped = snapToCellCenter(g, x, y);
        final snappedAgain = snapToCellCenter(g, snapped.x, snapped.y);
        expect(snappedAgain.x, equals(snapped.x), reason: 'Seed $seed GG1 snap idempotent x');
        expect(snappedAgain.y, equals(snapped.y), reason: 'Seed $seed GG1 snap idempotent y');
        expect((snapped.x - x).abs(), lessThanOrEqualTo(cellPx / 2.0 + 1e-4), reason: 'Seed $seed GG1 snap x within half cell');
        expect((snapped.y - y).abs(), lessThanOrEqualTo(cellPx / 2.0 + 1e-4), reason: 'Seed $seed GG1 snap y within half cell');

        // GG2
        final c1 = rand.nextInt(200) - 100;
        final r1 = rand.nextInt(200) - 100;
        final c2 = rand.nextInt(200) - 100;
        final r2 = rand.nextInt(200) - 100;
        final c3 = rand.nextInt(200) - 100;
        final r3 = rand.nextInt(200) - 100;

        final d12 = gridDistanceSquares(c1, r1, c2, r2);
        final d21 = gridDistanceSquares(c2, r2, c1, r1);
        expect(d12, equals(d21), reason: 'Seed $seed GG2 symmetry');
        expect(gridDistanceSquares(c1, r1, c1, r1), equals(0), reason: 'Seed $seed GG2 zero for same cell');
        if (c1 != c2 || r1 != r2) {
          expect(d12, greaterThan(0), reason: 'Seed $seed GG2 non-zero for different cells');
        }
        final d23 = gridDistanceSquares(c2, r2, c3, r3);
        final d13 = gridDistanceSquares(c1, r1, c3, r3);
        expect(d13, lessThanOrEqualTo(d12 + d23), reason: 'Seed $seed GG2 triangle inequality');
        expect(d12, equals(max((c1 - c2).abs(), (r1 - r2).abs())), reason: 'Seed $seed GG2 max axis diff');
        expect(gridDistanceFeet(g, c1, r1, c2, r2), equals(d12 * g.feetPerCell), reason: 'Seed $seed GG2 feet');

        // GG3
        final imgW = rand.nextInt(4097);
        final imgH = rand.nextInt(4097);
        final vLines = verticalLines(g, imgW);
        final expectedVCount = max(0, ((imgW * 100 - g.offsetXCentiPx) / g.cellCentiPx).floor() + 1);
        expect(vLines.length, equals(expectedVCount), reason: 'Seed $seed GG3 vertical count');
        if (vLines.isNotEmpty) {
          expect(vLines.first, equals(g.offsetXCentiPx / 100.0), reason: 'Seed $seed GG3 vertical first');
          for (int i = 0; i < vLines.length; i++) {
            expect(vLines[i], greaterThanOrEqualTo(0.0), reason: 'Seed $seed GG3 vertical >= 0');
            expect(vLines[i], lessThanOrEqualTo(imgW.toDouble()), reason: 'Seed $seed GG3 vertical <= W');
            if (i > 0) {
              expect((vLines[i] - vLines[i - 1] - cellPx).abs(), lessThan(1e-4), reason: 'Seed $seed GG3 vertical consecutive spacing');
            }
          }
        }

        final hLines = horizontalLines(g, imgH);
        final expectedHCount = max(0, ((imgH * 100 - g.offsetYCentiPx) / g.cellCentiPx).floor() + 1);
        expect(hLines.length, equals(expectedHCount), reason: 'Seed $seed GG3 horizontal count');
        if (hLines.isNotEmpty) {
          expect(hLines.first, equals(g.offsetYCentiPx / 100.0), reason: 'Seed $seed GG3 horizontal first');
          for (int i = 0; i < hLines.length; i++) {
            expect(hLines[i], greaterThanOrEqualTo(0.0), reason: 'Seed $seed GG3 horizontal >= 0');
            expect(hLines[i], lessThanOrEqualTo(imgH.toDouble()), reason: 'Seed $seed GG3 horizontal <= H');
            if (i > 0) {
              expect((hLines[i] - hLines[i - 1] - cellPx).abs(), lessThan(1e-4), reason: 'Seed $seed GG3 horizontal consecutive spacing');
            }
          }
        }

        // GG4
        final cornerGrid = gridWithCornerAt(g, x, y);
        expect(cornerGrid.offsetXCentiPx, greaterThanOrEqualTo(0), reason: 'Seed $seed GG4 offsetX >= 0');
        expect(cornerGrid.offsetXCentiPx, lessThan(cornerGrid.cellCentiPx), reason: 'Seed $seed GG4 offsetX < cell');
        expect(cornerGrid.offsetYCentiPx, greaterThanOrEqualTo(0), reason: 'Seed $seed GG4 offsetY >= 0');
        expect(cornerGrid.offsetYCentiPx, lessThan(cornerGrid.cellCentiPx), reason: 'Seed $seed GG4 offsetY < cell');

        if (x >= 0 && x <= 4096) {
          final cornerVLines = verticalLines(cornerGrid, 4096);
          final hasMatchingLine = cornerVLines.any((l) => (l - x).abs() <= 0.01 + 1e-4);
          expect(hasMatchingLine, isTrue, reason: 'Seed $seed GG4 corner line within 0.01 px of x=$x');
        }

        // Test GG4 with points exactly on a line and negative points
        if (vLines.isNotEmpty) {
          final exactLineX = vLines[rand.nextInt(vLines.length)];
          final exactCorner = gridWithCornerAt(g, exactLineX, -50.0);
          expect(exactCorner.offsetXCentiPx, greaterThanOrEqualTo(0));
          expect(exactCorner.offsetXCentiPx, lessThan(exactCorner.cellCentiPx));
        }

        // GG5: Half-open edges for 100 seeded lines
        if (seed < 100 && vLines.isNotEmpty) {
          for (int i = 0; i < min(5, vLines.length); i++) {
            final lineX = vLines[i];
            final cell = cellAt(g, lineX, 0.0);
            expect(cell.col, equals(i), reason: 'Seed $seed GG5 line $i at $lineX must belong to column $i');
          }
        }
      }
    });

    test('GG6 (law over 2000 seeds): isCellOnMap equals cellCenter in [0, width) x [0, height)', () {
      for (int seed = 0; seed < 2000; seed++) {
        final rand = Random(seed);
        final g = _randomGrid(rand);
        final imageWidth = 1 + rand.nextInt(4096);
        final imageHeight = 1 + rand.nextInt(4096);

        // Random cells in range [-1, 4095]
        for (int k = 0; k < 5; k++) {
          final int col;
          final int row;
          if (rand.nextBool()) {
            // Around map borders
            final cell = cellAt(g, rand.nextDouble() * imageWidth, rand.nextDouble() * imageHeight);
            col = (cell.col + rand.nextInt(5) - 2).clamp(-1, 4095);
            row = (cell.row + rand.nextInt(5) - 2).clamp(-1, 4095);
          } else {
            col = rand.nextInt(4097) - 1;
            row = rand.nextInt(4097) - 1;
          }
          final cellObj = MapTokenCell(col: col, row: row);
          final center = cellCenter(g, col, row);
          final expected = center.x >= 0.0 && center.x < imageWidth && center.y >= 0.0 && center.y < imageHeight;
          expect(isCellOnMap(g, imageWidth, imageHeight, cellObj), equals(expected),
              reason: 'Seed $seed cell ($col, $row) on ($imageWidth x $imageHeight)');
        }

        // Edge-aligned cases
        if (seed % 10 == 0) {
          final kCol = rand.nextInt(10);
          final edgeGrid = MapGrid(
            mapSha256Hex: 'a' * 64,
            cellCentiPx: 2000,
            offsetXCentiPx: 0,
            offsetYCentiPx: 0,
            feetPerCell: 5,
            visible: true,
          );
          final exactW = (2 * kCol + 1) * 10;
          final exactCell = MapTokenCell(col: kCol, row: 0);
          final exactCenter = cellCenter(edgeGrid, kCol, 0);
          expect(exactCenter.x, equals(exactW.toDouble()));
          expect(isCellOnMap(edgeGrid, exactW, 100, exactCell), isFalse);

          final kRow = rand.nextInt(10);
          final exactH = (2 * kRow + 1) * 10;
          final exactCellY = MapTokenCell(col: 0, row: kRow);
          final exactCenterY = cellCenter(edgeGrid, 0, kRow);
          expect(exactCenterY.y, equals(exactH.toDouble()));
          expect(isCellOnMap(edgeGrid, 100, exactH, exactCellY), isFalse);
        }
      }
    });

    test('GG7 (law, at least 2,000 seeds) nearestOnMapCell', () {
      int onImageCount = 0;
      int leftCount = 0;
      int rightCount = 0;
      int noOnImageCount = 0;

      int refAxis(int offsetCentiPx, int cellCentiPx, int imageDim, int target) {
        final onImage = <int>[];
        for (int c = -1; c <= 4095; c++) {
          final cx = 2 * offsetCentiPx + (2 * c + 1) * cellCentiPx;
          if (cx >= 0 && cx < 200 * imageDim) {
            onImage.add(c);
          }
        }
        if (onImage.isEmpty) return 0;
        if (target <= onImage.first) return onImage.first;
        if (target >= onImage.last) return onImage.last;
        return target;
      }

      for (int seed = 0; seed < 2000; seed++) {
        final rand = Random(seed + 9000);
        final MapGrid g;
        final int imageWidth;
        final int imageHeight;

        if (seed % 30 == 0) {
          // Grid with no on-image columns / rows
          g = MapGrid(
            mapSha256Hex: 'a' * 64,
            cellCentiPx: 50000,
            offsetXCentiPx: 49000,
            offsetYCentiPx: 49000,
            feetPerCell: 5,
            visible: true,
          );
          imageWidth = 1;
          imageHeight = 1;
        } else {
          g = _randomGrid(rand);
          imageWidth = 1 + rand.nextInt(8192);
          imageHeight = 1 + rand.nextInt(8192);
        }

        // Compute on-image columns for reference
        final onImageCols = <int>[];
        for (int c = -1; c <= 4095; c++) {
          final cx = 2 * g.offsetXCentiPx + (2 * c + 1) * g.cellCentiPx;
          if (cx >= 0 && cx < 200 * imageWidth) {
            onImageCols.add(c);
          }
        }

        final int colInput;
        if (onImageCols.isEmpty) {
          noOnImageCount++;
          colInput = rand.nextInt(20001) - 10000;
        } else {
          final mode = rand.nextInt(4);
          if (mode == 0) {
            // Strictly left
            colInput = onImageCols.first - 1 - rand.nextInt(500);
            leftCount++;
          } else if (mode == 1) {
            // Strictly right
            colInput = onImageCols.last + 1 + rand.nextInt(500);
            rightCount++;
          } else if (mode == 2) {
            // Strictly on-image
            colInput = onImageCols[rand.nextInt(onImageCols.length)];
            onImageCount++;
          } else {
            // Random in [-10000, 10000]
            colInput = rand.nextInt(20001) - 10000;
            if (colInput < onImageCols.first) {
              leftCount++;
            } else if (colInput > onImageCols.last) {
              rightCount++;
            } else {
              onImageCount++;
            }
          }
        }

        final rowInput = rand.nextInt(20001) - 10000;

        final actual = nearestOnMapCell(g, imageWidth, imageHeight, colInput, rowInput);
        final expCol = refAxis(g.offsetXCentiPx, g.cellCentiPx, imageWidth, colInput);
        final expRow = refAxis(g.offsetYCentiPx, g.cellCentiPx, imageHeight, rowInput);

        expect(actual.col, equals(expCol), reason: 'Seed $seed nearestOnMapCell col mismatch');
        expect(actual.row, equals(expRow), reason: 'Seed $seed nearestOnMapCell row mismatch');

        // Result fits MapTokenCell
        expect(actual.col, greaterThanOrEqualTo(MapTokenCell.minIndex));
        expect(actual.col, lessThanOrEqualTo(MapTokenCell.maxIndex));
        expect(actual.row, greaterThanOrEqualTo(MapTokenCell.minIndex));
        expect(actual.row, lessThanOrEqualTo(MapTokenCell.maxIndex));

        // An on-image input comes back unchanged
        if (onImageCols.contains(colInput)) {
          expect(actual.col, equals(colInput));
        }
      }

      // ignore: avoid_print
      print('GG7 coverage counts: onImage=$onImageCount, left=$leftCount, right=$rightCount, noOnImage=$noOnImageCount');
      expect(onImageCount, greaterThanOrEqualTo(300));
      expect(leftCount, greaterThanOrEqualTo(300));
      expect(rightCount, greaterThanOrEqualTo(300));
    });

    test('GG8 (law, at least 2,000 seeds) tokenAt', () {
      int singleHitCount = 0;
      int multiHitCount = 0;
      int missCount = 0;

      for (int seed = 0; seed < 2000; seed++) {
        final rand = Random(seed + 15000);
        final g = _randomGrid(rand);
        final squareSize = g.cellCentiPx / 100.0;

        final entryCount = rand.nextInt(9); // 0 to 8 entries
        final drawn = <({String id, int col, int row})>[];

        // Choose 1 to 4 distinct squares
        final distinctSquareCount = 1 + rand.nextInt(4);
        final squares = <({int col, int row})>[];
        for (int i = 0; i < distinctSquareCount; i++) {
          squares.add((col: rand.nextInt(60) - 10, row: rand.nextInt(60) - 10));
        }

        for (int i = 0; i < entryCount; i++) {
          final sq = squares[rand.nextInt(squares.length)];
          drawn.add((id: 'tok_$i', col: sq.col, row: sq.row));
        }

        // Count entries on each square
        final entriesOnSquare = <String, List<String>>{};
        for (final entry in drawn) {
          entriesOnSquare.putIfAbsent('${entry.col},${entry.row}', () => []).add(entry.id);
        }

        final ({int col, int row}) targetSquare;
        final targetChoice = rand.nextInt(3);
        final singles = entriesOnSquare.entries.where((e) => e.value.length == 1).toList();
        final multis = entriesOnSquare.entries.where((e) => e.value.length >= 2).toList();

        if (targetChoice == 0 && singles.isNotEmpty) {
          final chosen = singles[rand.nextInt(singles.length)];
          final parts = chosen.key.split(',');
          targetSquare = (col: int.parse(parts[0]), row: int.parse(parts[1]));
        } else if (targetChoice == 1 && multis.isNotEmpty) {
          final chosen = multis[rand.nextInt(multis.length)];
          final parts = chosen.key.split(',');
          targetSquare = (col: int.parse(parts[0]), row: int.parse(parts[1]));
        } else {
          // Miss (square with no entry)
          int missCol = rand.nextInt(100) + 100;
          int missRow = rand.nextInt(100) + 100;
          while (entriesOnSquare.containsKey('$missCol,$missRow')) {
            missCol++;
          }
          targetSquare = (col: missCol, row: missRow);
        }

        // Point strictly inside targetSquare (between 0.01 px and squareSize - 0.01 px)
        final topLeftX = (g.offsetXCentiPx + targetSquare.col * g.cellCentiPx) / 100.0;
        final topLeftY = (g.offsetYCentiPx + targetSquare.row * g.cellCentiPx) / 100.0;
        final dx = 0.01 + rand.nextDouble() * (squareSize - 0.02);
        final dy = 0.01 + rand.nextDouble() * (squareSize - 0.02);
        final px = topLeftX + dx;
        final py = topLeftY + dy;

        // Reference: last entry on that square
        String? expId;
        for (int i = drawn.length - 1; i >= 0; i--) {
          if (drawn[i].col == targetSquare.col && drawn[i].row == targetSquare.row) {
            expId = drawn[i].id;
            break;
          }
        }

        final actualId = tokenAt(drawn, g, px, py);
        expect(actualId, equals(expId), reason: 'Seed $seed tokenAt mismatch');

        final count = entriesOnSquare['${targetSquare.col},${targetSquare.row}']?.length ?? 0;
        if (count == 0) {
          missCount++;
        } else if (count == 1) {
          singleHitCount++;
        } else {
          multiHitCount++;
        }
      }

      // ignore: avoid_print
      print('GG8 coverage counts: singleHit=$singleHitCount, multiHit=$multiHitCount, miss=$missCount');
      expect(singleHitCount, greaterThanOrEqualTo(200));
      expect(multiHitCount, greaterThanOrEqualTo(200));
      expect(missCount, greaterThanOrEqualTo(200));
    });
  });
}

