import 'dart:async';
import 'dart:typed_data';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import 'blob_channel_port.dart';
import 'blob_store_port.dart';
import 'blob_transfer_protocol.dart';
import 'blob_verifier.dart';

sealed class BlobFetchResult {
  const BlobFetchResult();
}

final class BlobFetched extends BlobFetchResult {
  const BlobFetched();

  @override
  bool operator ==(Object other) => identical(this, other) || other is BlobFetched;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'BlobFetched()';
}

enum BlobIncompleteReason { noDirectPeers, notAvailable, corrupt }

final class BlobFetchIncomplete extends BlobFetchResult {
  final BlobIncompleteReason reason;
  final int missingChunks;

  const BlobFetchIncomplete(this.reason, this.missingChunks);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobFetchIncomplete &&
          reason == other.reason &&
          missingChunks == other.missingChunks;

  @override
  int get hashCode => Object.hash(reason, missingChunks);

  @override
  String toString() => 'BlobFetchIncomplete($reason, $missingChunks)';
}

class _ActiveDownload {
  final BlobRef ref;
  final Set<String> campaignIds;
  final Completer<BlobFetchResult> completer = Completer<BlobFetchResult>();

  _ActiveDownload(this.ref, String initialCampaignId)
      : campaignIds = {initialCampaignId};
}

class _ActiveServe {
  final int id;
  bool isCancelled = false;

  _ActiveServe(this.id);

  void cancel() {
    isCancelled = true;
  }
}

class BlobTransferService {
  final BlobChannelPort channel;
  final BlobStorePort store;
  final Iterable<BlobRef> Function() servableRefs;
  final Duration stallTimeout;

  StreamSubscription<BlobChannelMessage>? _messageSub;
  StreamSubscription<Set<String>>? _peersChangedSub;

  final Map<String, _ActiveDownload> _activeDownloads = {};
  final Map<String, _ActiveServe> _activeServes = {};
  int _nextServeId = 1;

  final Map<String, Future<StoredBlob>> _servingBlobCache = {};
  final Map<String, int> _servingBlobRefCounts = {};

  final StreamController<BlobChannelMessage> _inboundMessages =
      StreamController<BlobChannelMessage>.broadcast();

  bool _isDisposed = false;

  BlobTransferService({
    required this.channel,
    required this.store,
    required this.servableRefs,
    this.stallTimeout = kBlobDefaultStallTimeout,
  });

  void start() {
    if (_isDisposed) return;
    _messageSub = channel.blobMessages.listen((msg) {
      if (_isDisposed) return;
      _inboundMessages.add(msg);
      _handleInboundMessage(msg);
    });
  }

  void dispose() {
    _isDisposed = true;
    _messageSub?.cancel();
    _peersChangedSub?.cancel();
    _inboundMessages.close();
    for (final serve in _activeServes.values) {
      serve.cancel();
    }
    _activeServes.clear();
    _servingBlobCache.clear();
    _servingBlobRefCounts.clear();
  }

  Future<StoredBlob> _retainServingBlob(String hash) {
    _servingBlobRefCounts[hash] = (_servingBlobRefCounts[hash] ?? 0) + 1;
    return _servingBlobCache.putIfAbsent(hash, () => store.get(hash));
  }

  void _releaseServingBlob(String hash) {
    final count = (_servingBlobRefCounts[hash] ?? 1) - 1;
    if (count <= 0) {
      _servingBlobRefCounts.remove(hash);
      _servingBlobCache.remove(hash);
    } else {
      _servingBlobRefCounts[hash] = count;
    }
  }

  void _handleInboundMessage(BlobChannelMessage msg) {
    if (!msg.isText) return;
    final control = parseBlobControl(msg.text!);
    if (control is! BlobWantMessage) return;

    final peerId = msg.peerId;
    final hash = control.sha256Hex;
    _handleWant(peerId, hash, control.missingIndices);
  }

  Future<void> _handleWant(
    String peerId,
    String hash,
    List<int> missingIndices,
  ) async {
    // 1. If no ref in servableRefs() has hash H, or the store doesn't have H, send none for H.
    BlobRef? servableRef;
    for (final r in servableRefs()) {
      if (r.sha256Hex == hash) {
        servableRef = r;
        break;
      }
    }

    if (servableRef == null) {
      try {
        await channel.sendBlobText(peerId, encodeBlobNone(hash));
      } catch (_) {
        // intentional: peer disconnected or channel closed before none response
      }
      return;
    }

    final hasBlob = await store.has(hash);
    if (!hasBlob) {
      try {
        await channel.sendBlobText(peerId, encodeBlobNone(hash));
      } catch (_) {
        // intentional: peer disconnected or channel closed before none response
      }
      return;
    }

    // 2. Get the bytes with store.get(H). If stored ref doesn't equal servable ref, send none.
    StoredBlob stored;
    try {
      stored = await _retainServingBlob(hash);
    } catch (_) {
      try {
        await channel.sendBlobText(peerId, encodeBlobNone(hash));
      } catch (_) {
        // intentional: peer disconnected or channel closed before none response
      }
      return;
    }

    try {
      if (stored.ref != servableRef) {
        try {
          await channel.sendBlobText(peerId, encodeBlobNone(hash));
        } catch (_) {
          // intentional: peer disconnected or channel closed before none response
        }
        return;
      }

      // 3. If any index in the want is at or above the chunk count, ignore the whole want.
      final totalChunks = blobChunkCount(servableRef.byteSize);
      for (final idx in missingIndices) {
        if (idx >= totalChunks) return;
      }

      // 4. Send each listed chunk as a frame with sendBlobFrame, in the listed order.
      // At most one active serve per (peer, hash).
      final serveKey = '$peerId:$hash';
      _activeServes[serveKey]?.cancel();
      final serve = _ActiveServe(_nextServeId++);
      _activeServes[serveKey] = serve;

      final fullBytes = stored.bytes;
      for (final idx in missingIndices) {
        if (serve.isCancelled || _isDisposed) break;
        if (!channel.openBlobPeers.contains(peerId)) break;

        final chunkLen = blobChunkLength(servableRef.byteSize, idx);
        final offset = idx * kBlobChunkBytes;
        final payload = Uint8List.sublistView(fullBytes, offset, offset + chunkLen);
        final frame = encodeChunkFrame(
          sha256Hex: hash,
          index: idx,
          payload: payload,
        );

        try {
          await channel.sendBlobFrame(peerId, frame);
        } catch (_) {
          break;
        }
      }

      if (_activeServes[serveKey]?.id == serve.id) {
        _activeServes.remove(serveKey);
      }
    } finally {
      _releaseServingBlob(hash);
    }
  }

  Future<BlobFetchResult> fetch(BlobRef ref, {required String campaignId}) async {
    // 1. If store.addOwner(ref.sha256Hex, campaignId) returns true, return BlobFetched
    if (await store.addOwner(ref.sha256Hex, campaignId)) {
      return const BlobFetched();
    }

    // 2. Two fetch calls for the same hash at the same time share one download.
    final hash = ref.sha256Hex;
    final existing = _activeDownloads[hash];
    if (existing != null) {
      existing.campaignIds.add(campaignId);
      return existing.completer.future;
    }

    final download = _ActiveDownload(ref, campaignId);
    _activeDownloads[hash] = download;

    () async {
      try {
        final result = await _executeFetch(download);
        if (!download.completer.isCompleted) {
          _activeDownloads.remove(hash);
          download.completer.complete(result);
        }
      } catch (e, st) {
        _activeDownloads.remove(hash);
        if (!download.completer.isCompleted) {
          download.completer.completeError(e, st);
        }
      }
    }();

    return download.completer.future;
  }

  Future<BlobFetchResult> _executeFetch(_ActiveDownload download) async {
    final ref = download.ref;
    final totalChunks = blobChunkCount(ref.byteSize);

    // Initial check for candidates
    final initialCandidates = channel.openBlobPeers;
    if (initialCandidates.isEmpty) {
      return BlobFetchIncomplete(BlobIncompleteReason.noDirectPeers, totalChunks);
    }

    final chunks = <int, Uint8List>{};
    final excludedPeers = <String>{};
    bool hadCorruptAttempt = false;

    while (chunks.length < totalChunks) {
      final attemptPeers = <String>{};
      final peerContributors = <String>{};

      while (chunks.length < totalChunks) {
        // 3. Candidates are channel.openBlobPeers, sorted by peer id,
        // minus peers already tried in this attempt and minus excluded peers.
        final candidates = channel.openBlobPeers
            .where((p) => !attemptPeers.contains(p) && !excludedPeers.contains(p))
            .toList()
          ..sort();

        if (candidates.isEmpty) {
          // No candidates left in this attempt
          break;
        }

        final currentPeer = candidates.first;
        attemptPeers.add(currentPeer);

        // 4. Ask one peer at a time with a want listing only the chunk indices still missing.
        final missingIndices = <int>[];
        for (var i = 0; i < totalChunks; i++) {
          if (!chunks.containsKey(i)) missingIndices.add(i);
        }

        // Wait for chunks from currentPeer with stallTimeout
        final completer = Completer<void>();
        Timer? timer;

        void resetStallTimer() {
          timer?.cancel();
          timer = Timer(stallTimeout, () {
            if (!completer.isCompleted) completer.complete();
          });
        }

        // Listen for peer leaving openBlobPeers
        StreamSubscription<Set<String>>? peerLeaveSub;
        peerLeaveSub = channel.onBlobPeersChanged.listen((peers) {
          if (!peers.contains(currentPeer)) {
            if (!completer.isCompleted) completer.complete();
          }
        });

        // Listen for messages from currentPeer
        StreamSubscription<BlobChannelMessage>? msgSub;
        msgSub = _inboundMessages.stream.listen((msg) {
          if (completer.isCompleted) return;

          if (msg.peerId != currentPeer) {
            // Ignored frames don't reset stall timer
            return;
          }

          if (msg.isText) {
            final control = parseBlobControl(msg.text!);
            if (control is BlobNoneMessage && control.sha256Hex == ref.sha256Hex) {
              // Current peer answers none for this hash -> move to next candidate
              if (!completer.isCompleted) completer.complete();
            }
            return;
          }

          if (msg.isBinary) {
            final frame = decodeChunkFrame(msg.bytes!);
            if (frame == null) {
              // Malformed frame from current peer -> protocol violation
              excludedPeers.add(currentPeer);
              if (!completer.isCompleted) completer.complete();
              return;
            }

            if (frame.sha256Hex != ref.sha256Hex) {
              // Frame for another hash -> ignored
              return;
            }

            // Check index validity and payload length
            if (frame.index >= totalChunks) {
              // Protocol violation: out-of-range index
              excludedPeers.add(currentPeer);
              if (!completer.isCompleted) completer.complete();
              return;
            }

            final expectedLen = blobChunkLength(ref.byteSize, frame.index);
            if (frame.payload.length != expectedLen) {
              // Protocol violation: wrong payload length
              excludedPeers.add(currentPeer);
              if (!completer.isCompleted) completer.complete();
              return;
            }

            if (chunks.containsKey(frame.index)) {
              // Duplicate frame -> ignored
              return;
            }

            // Accept chunk!
            chunks[frame.index] = frame.payload;
            peerContributors.add(currentPeer);
            resetStallTimer();

            if (chunks.length == totalChunks) {
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          }
        });

        try {
          resetStallTimer();
          final wantText = encodeBlobWant(ref.sha256Hex, missingIndices);
          try {
            await channel.sendBlobText(currentPeer, wantText);
          } catch (_) {
            if (!completer.isCompleted) completer.complete();
          }
          await completer.future;
        } finally {
          timer?.cancel();
          peerLeaveSub.cancel();
          msgSub.cancel();
        }
      }

      // Check if we got all chunks
      if (chunks.length == totalChunks) {
        // 7. Join them and run verifyBlob
        final fullBytes = Uint8List(ref.byteSize);
        var offset = 0;
        for (var i = 0; i < totalChunks; i++) {
          final chunk = chunks[i]!;
          fullBytes.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }

        final verdict = verifyBlob(ref, fullBytes);
        if (verdict == BlobVerdict.ok) {
          final recordedOwners = <String>{};
          final firstCampaign = download.campaignIds.first;
          await store.put(ref, fullBytes, campaignId: firstCampaign);
          recordedOwners.add(firstCampaign);

          while (true) {
            final unrecorded = download.campaignIds.difference(recordedOwners);
            if (unrecorded.isEmpty) {
              _activeDownloads.remove(ref.sha256Hex);
              download.completer.complete(const BlobFetched());
              break;
            }
            for (final c in unrecorded.toList()) {
              await store.addOwner(ref.sha256Hex, c);
              recordedOwners.add(c);
            }
          }
          return const BlobFetched();
        } else {
          hadCorruptAttempt = true;
          // Throw away every chunk
          chunks.clear();
          // Exclude every peer that contributed a chunk to this attempt
          excludedPeers.addAll(peerContributors);
          // Start a new attempt with the remaining peers
          continue;
        }
      } else {
        // No candidates left and chunks incomplete
        break;
      }
    }

    final missingChunks = totalChunks - chunks.length;
    return BlobFetchIncomplete(
      hadCorruptAttempt ? BlobIncompleteReason.corrupt : BlobIncompleteReason.notAvailable,
      missingChunks,
    );
  }
}
