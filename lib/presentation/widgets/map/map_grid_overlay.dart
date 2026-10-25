import 'package:flutter/material.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';
import '../../../application/map/grid_geometry.dart';

/// CustomPainter that renders grid lines across the map.
class MapGridPainter extends CustomPainter {
  final MapGrid? grid;
  final double scale;
  final int imageWidth;
  final int imageHeight;

  MapGridPainter({
    required this.grid,
    required this.scale,
    required this.imageWidth,
    required this.imageHeight,
  });

  /// Computed vertical line positions in image pixels, exposed for testing.
  List<double> get computedVerticalLines =>
      grid == null || !grid!.visible
          ? const []
          : verticalLines(grid!, imageWidth);

  /// Computed horizontal line positions in image pixels, exposed for testing.
  List<double> get computedHorizontalLines =>
      grid == null || !grid!.visible
          ? const []
          : horizontalLines(grid!, imageHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final g = grid;
    if (g == null || !g.visible) return;

    final effectiveScale = scale <= 0 ? 1.0 : scale;
    final strokeWidth = 1.0 / effectiveScale;

    final blackPaint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.5)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final whitePaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.3)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final vLines = computedVerticalLines;
    for (final x in vLines) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), blackPaint);
      canvas.drawLine(Offset(x + strokeWidth, 0), Offset(x + strokeWidth, size.height), whitePaint);
    }

    final hLines = computedHorizontalLines;
    for (final y in hLines) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), blackPaint);
      canvas.drawLine(Offset(0, y + strokeWidth), Offset(size.width, y + strokeWidth), whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant MapGridPainter oldDelegate) {
    return grid != oldDelegate.grid ||
        scale != oldDelegate.scale ||
        imageWidth != oldDelegate.imageWidth ||
        imageHeight != oldDelegate.imageHeight;
  }
}

/// Widget displaying the grid lines overlay.
class MapGridOverlay extends StatelessWidget {
  final MapGrid? grid;
  final double scale;
  final int width;
  final int height;

  const MapGridOverlay({
    super.key,
    required this.grid,
    required this.scale,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width.toDouble(), height.toDouble()),
      painter: MapGridPainter(
        grid: grid,
        scale: scale,
        imageWidth: width,
        imageHeight: height,
      ),
    );
  }
}

/// CustomPainter that renders the ruler line and endpoint dots.
class _RulerPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double scale;

  _RulerPainter({
    required this.start,
    required this.end,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final effectiveScale = scale <= 0 ? 1.0 : scale;
    final strokeWidth = 3.0 / effectiveScale;
    final dotRadius = 5.0 / effectiveScale;

    final linePaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..strokeWidth = strokeWidth + 2.0 / effectiveScale
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, shadowPaint);
    canvas.drawLine(start, end, linePaint);

    canvas.drawCircle(start, dotRadius + 1.0 / effectiveScale, shadowPaint..style = PaintingStyle.fill);
    canvas.drawCircle(start, dotRadius, dotPaint);

    canvas.drawCircle(end, dotRadius + 1.0 / effectiveScale, shadowPaint);
    canvas.drawCircle(end, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return start != oldDelegate.start ||
        end != oldDelegate.end ||
        scale != oldDelegate.scale;
  }
}

/// Widget displaying the measurement ruler and distance badge.
class MapRulerOverlay extends StatelessWidget {
  final Offset? start;
  final Offset? end;
  final String? label;
  final double scale;

  const MapRulerOverlay({
    super.key,
    required this.start,
    required this.end,
    required this.label,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    if (start == null || end == null || label == null) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: _RulerPainter(
            start: start!,
            end: end!,
            scale: scale,
          ),
        ),
        Positioned(
          left: end!.dx + 8.0,
          top: end!.dy - 24.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: Colors.black, width: 1.0),
            ),
            child: Text(
              label!,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
