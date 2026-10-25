import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_channel_port.dart';
import 'package:dangerously_nerdy_5e_toolkit/application/blob/blob_transfer_protocol.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';

enum PeerBehavior {
  honest,
  answersNone,
  stallsAfterK,
  leavesAfterK,
  servesFlippedByte,
  sendsWrongLengthFrame,
  duplicatesEverything,
}

class SentMessageRecord {
  final String sender;
  final String recipient;
  final String? text;
  final Uint8List? frame;

  const SentMessageRecord({
    required this.sender,
    required this.recipient,
    this.text,
    this.frame,
  });

  bool get isText => text != null;
  bool get isFrame => frame != null;
}

class FakeBlobNetwork {
  final Map<String, FakeBlobChannelPort> _channels = {};
  final Set<String> _oldBuildPeers = {};
  final List<SentMessageRecord> sentMessages = [];

  Random? random;
  bool duplicateAllFrames = false;

  FakeBlobChannelPort createChannel(String peerId) {
    final port = FakeBlobChannelPort(peerId: peerId, network: this);
    _channels[peerId] = port;
    return port;
  }

  void markAsOldBuild(String peerId) {
    _oldBuildPeers.add(peerId);
  }

  void openChannelBetween(String peerA, String peerB) {
    if (_oldBuildPeers.contains(peerA) || _oldBuildPeers.contains(peerB)) {
      return;
    }
    _channels[peerA]?._addOpenPeer(peerB);
    _channels[peerB]?._addOpenPeer(peerA);
  }

  void closeChannelBetween(String peerA, String peerB) {
    _channels[peerA]?._removeOpenPeer(peerB);
    _channels[peerB]?._removeOpenPeer(peerA);
  }

  void deliverText({
    required String sender,
    required String recipient,
    required String text,
  }) {
    sentMessages.add(SentMessageRecord(
      sender: sender,
      recipient: recipient,
      text: text,
    ));

    final target = _channels[recipient];
    if (target != null && target.openBlobPeers.contains(sender)) {
      target._inboundMessagesController.add(
        BlobChannelMessage.text(sender, text),
      );
    }
  }

  void deliverFrame({
    required String sender,
    required String recipient,
    required Uint8List frame,
  }) {
    sentMessages.add(SentMessageRecord(
      sender: sender,
      recipient: recipient,
      frame: frame,
    ));

    final target = _channels[recipient];
    if (target != null && target.openBlobPeers.contains(sender)) {
      if (duplicateAllFrames) {
        target._inboundMessagesController.add(
          BlobChannelMessage.bytes(sender, frame),
        );
      }
      target._inboundMessagesController.add(
        BlobChannelMessage.bytes(sender, frame),
      );
    }
  }
}

class FakeBlobChannelPort implements BlobChannelPort {
  final String peerId;
  final FakeBlobNetwork network;

  final Set<String> _openBlobPeers = {};
  final StreamController<Set<String>> _peersChangedController =
      StreamController<Set<String>>.broadcast();
  final StreamController<BlobChannelMessage> _inboundMessagesController =
      StreamController<BlobChannelMessage>.broadcast();

  FakeBlobChannelPort({
    required this.peerId,
    required this.network,
  });

  @override
  Set<String> get openBlobPeers => Set.unmodifiable(_openBlobPeers);

  @override
  Stream<Set<String>> get onBlobPeersChanged => _peersChangedController.stream;

  @override
  Stream<BlobChannelMessage> get blobMessages => _inboundMessagesController.stream;

  void _addOpenPeer(String otherPeerId) {
    if (_openBlobPeers.add(otherPeerId)) {
      _peersChangedController.add(openBlobPeers);
    }
  }

  void _removeOpenPeer(String otherPeerId) {
    if (_openBlobPeers.remove(otherPeerId)) {
      _peersChangedController.add(openBlobPeers);
    }
  }

  @override
  Future<void> sendBlobText(String peerId, String text) async {
    if (!_openBlobPeers.contains(peerId)) {
      throw StateError('FakeBlobChannel: peer $peerId is not open');
    }
    network.deliverText(sender: this.peerId, recipient: peerId, text: text);
  }

  @override
  Future<void> sendBlobFrame(String peerId, Uint8List frame) async {
    if (frame.length > kBlobFrameHeaderBytes + kBlobChunkBytes) {
      throw ArgumentError('Frame length exceeds maximum');
    }
    if (!_openBlobPeers.contains(peerId)) {
      throw StateError('FakeBlobChannel: peer $peerId is not open');
    }
    network.deliverFrame(sender: this.peerId, recipient: peerId, frame: frame);
  }

  void close() {
    _openBlobPeers.clear();
    _peersChangedController.close();
    _inboundMessagesController.close();
  }
}

/// Helper that programs a peer on the fake network to serve blobs with a given behavior.
class ProgrammedServingPeer {
  final String peerId;
  final FakeBlobChannelPort channel;
  final BlobRef ref;
  final Uint8List originalBytes;
  final PeerBehavior behavior;
  final int kParam;
  final Random? random;

  StreamSubscription? _sub;

  ProgrammedServingPeer({
    required this.peerId,
    required this.channel,
    required this.ref,
    required this.originalBytes,
    required this.behavior,
    this.kParam = 3,
    this.random,
  });

  void start() {
    _sub = channel.blobMessages.listen((msg) async {
      try {
        if (!msg.isText) return;
        final control = parseBlobControl(msg.text!);
        if (control is! BlobWantMessage || control.sha256Hex != ref.sha256Hex) {
          return;
        }

        final requester = msg.peerId;

      switch (behavior) {
        case PeerBehavior.answersNone:
          await channel.sendBlobText(
            requester,
            encodeBlobNone(ref.sha256Hex),
          );

        case PeerBehavior.stallsAfterK:
          final indices = List<int>.from(control.missingIndices);
          if (random != null) {
            indices.shuffle(random);
          }
          final count = min(kParam, indices.length);
          for (var i = 0; i < count; i++) {
            await _sendChunk(requester, indices[i], originalBytes);
          }
          // Then stalls: sends nothing more!

        case PeerBehavior.leavesAfterK:
          final indices = List<int>.from(control.missingIndices);
          if (random != null) {
            indices.shuffle(random);
          }
          final count = min(kParam, indices.length);
          for (var i = 0; i < count; i++) {
            await _sendChunk(requester, indices[i], originalBytes);
          }
          // Leaves:
          channel.network.closeChannelBetween(peerId, requester);

        case PeerBehavior.servesFlippedByte:
          // Flips one byte in the first chunk served
          final corruptBytes = Uint8List.fromList(originalBytes);
          final flipIdx = min(originalBytes.length - 1, 15);
          corruptBytes[flipIdx] ^= 0xFF;
          final indices = List<int>.from(control.missingIndices);
          if (random != null) {
            indices.shuffle(random);
          }
          for (final idx in indices) {
            await _sendChunk(requester, idx, corruptBytes);
          }

        case PeerBehavior.sendsWrongLengthFrame:
          // Sends a frame with incorrect length on the first chunk
          if (control.missingIndices.isNotEmpty) {
            final idx = control.missingIndices.first;
            final chunkLen = blobChunkLength(ref.byteSize, idx);
            final int badPayloadLen = chunkLen < kBlobChunkBytes ? chunkLen + 1 : chunkLen - 1;
            final badPayload = Uint8List(badPayloadLen);
            final frame = encodeChunkFrame(
              sha256Hex: ref.sha256Hex,
              index: idx,
              payload: badPayload,
            );
            await channel.sendBlobFrame(requester, frame);
          }

        case PeerBehavior.duplicatesEverything:
          final indices = List<int>.from(control.missingIndices);
          if (random != null) {
            indices.shuffle(random);
          }
          for (final idx in indices) {
            await _sendChunk(requester, idx, originalBytes);
            await _sendChunk(requester, idx, originalBytes);
          }

        case PeerBehavior.honest:
          // Shuffled delivery if random is provided
          final indices = List<int>.from(control.missingIndices);
          if (random != null) {
            indices.shuffle(random);
          }
          for (final idx in indices) {
            await _sendChunk(requester, idx, originalBytes);
          }
      }
    } catch (_) {}
  });
  }

  Future<void> _sendChunk(String toPeer, int idx, Uint8List fullBytes) async {
    final chunkLen = blobChunkLength(ref.byteSize, idx);
    final offset = idx * kBlobChunkBytes;
    final payload = Uint8List.sublistView(fullBytes, offset, offset + chunkLen);
    final frame = encodeChunkFrame(
      sha256Hex: ref.sha256Hex,
      index: idx,
      payload: payload,
    );
    await channel.sendBlobFrame(toPeer, frame);
  }

  void stop() {
    _sub?.cancel();
  }
}
