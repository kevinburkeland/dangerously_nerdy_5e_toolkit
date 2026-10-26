import 'dart:async';
import 'package:vtt_engine_core/models/value_objects/blob_ref.dart';
import 'package:vtt_engine_core/models/value_objects/map_grid.dart';

import 'map_grid_service.dart';

class _InFlightEdit {
  final MapGridEdit edit;
  bool isDone = false;
  bool stateArrived = false;
  _InFlightEdit(this.edit);
}

/// Pure Dart editor that orchestrates all UI edits to a shared [MapGrid].
///
/// It coordinates pending unwritten edits, debouncing, and sequenced writes
/// to [MapGridService] ensuring no remote or local changes are accidentally overwritten.
class MapGridEditor {
  final MapGridService service;
  final String campaignId;
  final BlobRef map;

  MapGridEdit _pending = const MapGridEdit();
  final List<_InFlightEdit> _inFlight = [];
  Timer? _timer;
  Future<void> _writeChain = Future.value();
  bool _disposed = false;
  Object? _lastWriteError;

  MapGridEditor({
    required this.service,
    required this.campaignId,
    required this.map,
  });

  /// The currently pending unwritten edit.
  MapGridEdit get pending => _pending;

  /// Whether this editor has been disposed.
  bool get isDisposed => _disposed;

  /// The most recent write error, if any write failed.
  Object? get lastWriteError => _lastWriteError;

  /// Clears the last write error.
  void clearWriteError() {
    _lastWriteError = null;
  }

  /// Removes all in-flight entries that have completed their writes and have been confirmed by arrived state.
  void latestArrived() {
    for (final entry in _inFlight) {
      entry.stateArrived = true;
    }
    _inFlight.removeWhere((entry) => entry.isDone && entry.stateArrived);
  }

  /// Returns [latest] with all in-flight edits (oldest first) and any pending unwritten edit applied on top.
  MapGrid displayed(MapGrid latest) {
    MapGrid current = latest;
    for (final entry in _inFlight) {
      current = entry.edit.applyTo(current);
    }
    return _pending.applyTo(current);
  }

  /// Computes a new cell size from [displayed], records it in pending,
  /// and restarts the 400 ms debounce timer.
  void setCellCentiPx(MapGrid latest, int cellCentiPx) {
    if (_disposed) return;
    clearWriteError();
    final clamped = cellCentiPx.clamp(MapGrid.minCellCentiPx, MapGrid.maxCellCentiPx);
    _pending = _pending.merge(MapGridEdit(cellCentiPx: clamped));
    _restartTimer();
  }

  /// Moves the offset by [dx] * 100 and [dy] * 100 centi-pixels, wrapping
  /// within one cell, records it in pending, and restarts the 400 ms debounce timer.
  void nudge(MapGrid latest, int dx, int dy) {
    if (_disposed) return;
    clearWriteError();
    final cur = displayed(latest);
    final cellCenti = cur.cellCentiPx;
    int? newX;
    if (dx != 0) {
      newX = (cur.offsetXCentiPx + dx * 100) % cellCenti;
      if (newX < 0) newX += cellCenti;
    }
    int? newY;
    if (dy != 0) {
      newY = (cur.offsetYCentiPx + dy * 100) % cellCenti;
      if (newY < 0) newY += cellCenti;
    }
    _pending = _pending.merge(MapGridEdit(
      offsetXCentiPx: newX,
      offsetYCentiPx: newY,
    ));
    _restartTimer();
  }

  /// Sets feet per cell, records it in pending, and restarts the 400 ms debounce timer.
  void setFeetPerCell(MapGrid latest, int feet) {
    if (_disposed) return;
    clearWriteError();
    final clamped = feet.clamp(1, MapGrid.maxFeetPerCell);
    _pending = _pending.merge(MapGridEdit(feetPerCell: clamped));
    _restartTimer();
  }

  /// Flushes pending edits first, then writes the visibility toggle.
  Future<void> toggleVisible() {
    if (_disposed) return Future.value();
    clearWriteError();
    flush();
    return _chain(() => service.toggleVisible(campaignId, map));
  }

  /// Flushes pending edits first, then writes corner alignment at (x, y).
  Future<void> setCornerAt(double x, double y) {
    if (_disposed) return Future.value();
    clearWriteError();
    flush();
    return _chain(() => service.setCornerAt(campaignId, map, x, y));
  }

  /// Flushes pending edits first, then writes [grid].
  Future<void> setGrid(MapGrid? grid) {
    if (_disposed) return Future.value();
    clearWriteError();
    flush();
    return _chain(() => service.setGrid(campaignId, grid));
  }

  /// Cancels the debounce timer and sends any pending edit to the repository.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_pending.isEmpty) {
      final toWrite = _pending;
      _pending = const MapGridEdit();
      final inFlightEntry = _InFlightEdit(toWrite);
      _inFlight.add(inFlightEntry);
      return _chain(() async {
        try {
          await service.applyEdit(campaignId, map, toWrite);
          inFlightEntry.isDone = true;
          if (inFlightEntry.stateArrived) {
            _inFlight.remove(inFlightEntry);
          }
        } catch (e) {
          _inFlight.remove(inFlightEntry);
          _lastWriteError = e;
        }
      });
    }
    return _writeChain;
  }

  /// Flushes any pending edit, cancels timers, and refuses further calls.
  void dispose() {
    if (_disposed) return;
    flush();
    _disposed = true;
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () {
      flush();
    });
  }

  Future<void> _chain(Future<void> Function() action) {
    final next = _writeChain.then((_) async {
      try {
        await action();
      } catch (e) {
        _lastWriteError = e;
      }
    }, onError: (_) async {
      try {
        await action();
      } catch (e) {
        _lastWriteError = e;
      }
    });
    _writeChain = next;
    return next;
  }
}
