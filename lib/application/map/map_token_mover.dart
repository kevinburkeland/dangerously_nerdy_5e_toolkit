import 'dart:async';
import 'package:vtt_engine_core/models/value_objects/blob_ref.dart';
import 'package:vtt_engine_core/models/value_objects/map_token.dart';

import 'map_token_rules.dart';
import 'map_token_service.dart';

class _InFlightMove {
  final String tokenId;
  final MapTokenCell cell;
  bool isDone = false;
  _InFlightMove(this.tokenId, this.cell);
}

/// Token counterpart of MapGridEditor. Orchestrates in-flight move states and sequenced writes.
class MapTokenMover {
  final MapTokenService Function() _serviceGetter;
  final String campaignId;
  final BlobRef map;
  final MapTokenActor actor;

  final List<_InFlightMove> _inFlight = [];
  Future<void> _writeChain = Future.value();
  bool _disposed = false;
  MapTokenWriteResult? _lastRefusal;
  Object? _lastWriteError;

  MapTokenMover({
    MapTokenService? service,
    MapTokenService Function()? getService,
    required this.campaignId,
    required this.map,
    required this.actor,
  }) : _serviceGetter = (getService ?? (() => service!));

  /// The square to show for [tokenId]: the newest in-flight move for it, else [stored].
  MapTokenCell shownCell(String tokenId, MapTokenCell stored) {
    for (int i = _inFlight.length - 1; i >= 0; i--) {
      if (_inFlight[i].tokenId == tokenId) {
        return _inFlight[i].cell;
      }
    }
    return stored;
  }

  /// Shows [cell] at once, then writes it through service.moveToken. Writes run one at a
  /// time, in the order called. Returns the service's result, or null if the write threw.
  Future<MapTokenWriteResult?> move(String tokenId, MapTokenCell cell) {
    if (_disposed) return Future.value(null);
    final entry = _InFlightMove(tokenId, cell);
    _inFlight.add(entry);

    final completer = Completer<MapTokenWriteResult?>();
    final next = _writeChain.then((_) async {
      await _executeMove(entry, completer);
    }, onError: (_) async {
      await _executeMove(entry, completer);
    });
    _writeChain = next;
    return completer.future;
  }

  Future<void> _executeMove(_InFlightMove entry, Completer<MapTokenWriteResult?> completer) async {
    try {
      final result = await _serviceGetter().moveToken(
        campaignId,
        map,
        actor,
        entry.tokenId,
        entry.cell,
      );
      if (result == MapTokenWriteResult.written || result == MapTokenWriteResult.unchanged) {
        entry.isDone = true;
      } else {
        _inFlight.remove(entry);
        _lastRefusal = result;
      }
      completer.complete(result);
    } catch (e) {
      _inFlight.remove(entry);
      _lastWriteError = e;
      completer.complete(null);
    }
  }

  /// Removes every in-flight move marked done. The view calls it on each MapReady for this map.
  void latestArrived() {
    _inFlight.removeWhere((entry) => entry.isDone);
  }

  MapTokenWriteResult? get lastRefusal => _lastRefusal;
  Object? get lastWriteError => _lastWriteError;

  void clearMessages() {
    _lastRefusal = null;
    _lastWriteError = null;
  }

  void dispose() {
    _disposed = true;
  }
}
