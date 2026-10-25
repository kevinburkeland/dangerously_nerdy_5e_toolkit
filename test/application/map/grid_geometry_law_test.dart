import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';
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
  });
}
