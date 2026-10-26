import 'package:flutter/material.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

import '../../../application/map/grid_geometry.dart';
import '../../../application/map/active_map_controller.dart';
import '../../../application/map/map_token_mover.dart';
import '../../../application/map/map_token_rules.dart';
import '../../../models/srd_summons/minion_stat_block.dart';
import '../../../widgets/glyphs/dnd_glyph.dart';

class MapTokenWidget extends StatelessWidget {
  final MapToken token;
  final bool movable;
  final bool selected;
  final bool faded;
  final bool showsGlyph;
  final MapTokenDetail? detail;
  final double size;

  const MapTokenWidget({
    super.key,
    required this.token,
    required this.movable,
    required this.selected,
    required this.faded,
    required this.showsGlyph,
    this.detail,
    required this.size,
  });

  Color _tokenFillColor() {
    switch (token.kind) {
      case MapTokenKind.character:
        return const Color(0xFF1E88E5); // Blue
      case MapTokenKind.monster:
        return const Color(0xFFE53935); // Red
      case MapTokenKind.minion:
        return const Color(0xFFFB8C00); // Amber/Orange
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    final minionInst = detail?.minion;
    if (showsGlyph && minionInst != null) {
      final sb = minionInst.statBlock;
      content = Stack(
        alignment: Alignment.center,
        children: [
          DndGlyph.monster(
            creatureType: sb.glyphCreatureType,
            crTier: sb.glyphCrTier,
            size: size,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              token.label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.32,
              ),
            ),
          ),
        ],
      );
    } else {
      content = Center(
        child: Text(
          token.label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
            shadows: const [
              Shadow(
                color: Colors.black87,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      );
    }

    final ringColor = selected
        ? Colors.amberAccent
        : (movable ? Colors.white : Colors.white24);
    final ringWidth = selected ? 3.5 : (movable ? 2.0 : 1.0);

    Widget tokenCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _tokenFillColor(),
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: ringWidth),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.amberAccent.withAlpha(150),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: ClipOval(child: content),
    );

    if (faded) {
      tokenCircle = Opacity(opacity: 0.45, child: tokenCircle);
    }

    return tokenCircle;
  }
}

class MapTokenLayer extends StatelessWidget {
  final MapGrid grid;
  final int imageWidth;
  final int imageHeight;
  final List<PlacedMapToken> tokens;
  final Map<String, MapTokenDetail> tokenDetails;
  final Set<String> rosterSlugs;
  final Map<String, String> minionOwners;
  final MapTokenActor actor;
  final MapTokenMover? mover;
  final String? selectedTokenId;
  final String? dragTokenId;
  final MapTokenCell? dragPreviewCell;
  final MapTokenCell? dragStartCell;

  const MapTokenLayer({
    super.key,
    required this.grid,
    required this.imageWidth,
    required this.imageHeight,
    required this.tokens,
    required this.tokenDetails,
    required this.rosterSlugs,
    required this.minionOwners,
    required this.actor,
    this.mover,
    this.selectedTokenId,
    this.dragTokenId,
    this.dragPreviewCell,
    this.dragStartCell,
  });

  @override
  Widget build(BuildContext context) {
    if (tokens.isEmpty) return const SizedBox.shrink();

    // Drawing order: tokens order, with the selected token moved to the end
    final sortedTokens = List<PlacedMapToken>.from(tokens);
    if (selectedTokenId != null) {
      final selIdx = sortedTokens.indexWhere((t) => t.token.id == selectedTokenId);
      if (selIdx != -1) {
        final selToken = sortedTokens.removeAt(selIdx);
        sortedTokens.add(selToken);
      }
    }

    final squareSize = grid.cellCentiPx / 100.0;
    final tokenDiameter = squareSize * 0.8;
    final radius = tokenDiameter / 2.0;

    final children = <Widget>[];

    for (final placed in sortedTokens) {
      final token = placed.token;
      final isDragged = token.id == dragTokenId;

      final MapTokenCell cellToUse;
      if (isDragged && dragPreviewCell != null) {
        cellToUse = dragPreviewCell!;
      } else if (mover != null) {
        cellToUse = mover!.shownCell(token.id, placed.cell);
      } else {
        cellToUse = placed.cell;
      }

      final clamped = nearestOnMapCell(grid, imageWidth, imageHeight, cellToUse.col, cellToUse.row);
      final center = cellCenter(grid, clamped.col, clamped.row);

      final isSelected = token.id == selectedTokenId;
      final isStoredOnMap = isCellOnMap(grid, imageWidth, imageHeight, placed.cell);
      final isFaded = !isStoredOnMap;
      final isMovable = canMoveTokenWith(
        rosterSlugs: rosterSlugs,
        minionOwners: minionOwners,
        token: token,
        actor: actor,
      );

      final detail = tokenDetails[token.id];
      final showsGlyph = token.kind == MapTokenKind.minion && detail?.minion != null;

      final tokenWidget = Positioned(
        left: center.x - radius,
        top: center.y - radius,
        child: MapTokenWidget(
          key: ValueKey('map-token-${token.id}'),
          token: token,
          movable: isMovable,
          selected: isSelected,
          faded: isFaded,
          showsGlyph: showsGlyph,
          detail: detail,
          size: tokenDiameter,
        ),
      );

      children.add(tokenWidget);

      // Drag distance badge if dragging
      if (isDragged && dragStartCell != null && dragPreviewCell != null) {
        final sq = gridDistanceSquares(dragStartCell!.col, dragStartCell!.row, clamped.col, clamped.row);
        final ft = gridDistanceFeet(grid, dragStartCell!.col, dragStartCell!.row, clamped.col, clamped.row);
        final distanceText = sq == 1 ? '1 square · $ft ft' : '$sq squares · $ft ft';

        children.add(
          Positioned(
            left: center.x - 70,
            top: center.y + radius + 4,
            child: SizedBox(
              width: 140,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white70, width: 1),
                  ),
                  child: Text(
                    distanceText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Stack(
      children: children,
    );
  }
}
