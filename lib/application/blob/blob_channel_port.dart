import 'dart:async';
import 'dart:typed_data';

class BlobChannelMessage {
  final String peerId;
  final String? text;
  final Uint8List? bytes;

  const BlobChannelMessage.text(this.peerId, String this.text) : bytes = null;
  const BlobChannelMessage.bytes(this.peerId, Uint8List this.bytes) : text = null;

  bool get isText => text != null;
  bool get isBinary => bytes != null;
}

abstract interface class BlobChannelPort {
  /// Peers whose dn5e_blob channel is open.
  Set<String> get openBlobPeers;
  Stream<Set<String>> get onBlobPeersChanged;
  Stream<BlobChannelMessage> get blobMessages; // peerId plus either text or bytes
  Future<void> sendBlobText(String peerId, String text);
  /// Completes after the frame is handed to the channel. Waits first while the
  /// channel's bufferedAmount is above kBlobHighWaterBytes.
  Future<void> sendBlobFrame(String peerId, Uint8List frame);
}
