import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../application/services/cascading_transport_router.dart' show TransportState;
import '../../../domain/ports/i_p2p_transport_port.dart';
import 'firebase_signaling_adapter.dart';
import 'signaling_message.dart';

/// Pluggable peer connection factory interface allowing headless tests
/// to mock WebRTC native platform channels.
abstract class IRtcPeerConnectionFactory {
  Future<RTCPeerConnection> createConnection(Map<String, dynamic> configuration);
}

class DefaultRtcPeerConnectionFactory implements IRtcPeerConnectionFactory {
  const DefaultRtcPeerConnectionFactory();

  @override
  Future<RTCPeerConnection> createConnection(Map<String, dynamic> configuration) {
    return createPeerConnection(configuration);
  }
}

/// WebRTC P2P DataChannel Mesh adapter implementing [IP2pTransportPort].
/// Maintains full mesh DataChannels between all peers in the room, handles
/// heartbeat ping/pong keepalives, and tracks peer activity timestamps.
class WebRtcMeshAdapter implements IP2pTransportPort {
  final FirebaseSignalingAdapter? _signalingAdapter;
  final IRtcPeerConnectionFactory _connectionFactory;
  final Map<String, dynamic> _rtcConfiguration;

  String? _roomCode;
  String? _localNodeId;
  bool _isDisposed = false;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, int> _peerLastActiveTimestamps = {};

  StreamController<String> _incomingPayloadsController =
      StreamController<String>.broadcast();
  StreamController<Set<String>> _peersChangedController =
      StreamController<Set<String>>.broadcast();
  StreamSubscription<SignalingMessage>? _signalingSubscription;
  Timer? _heartbeatTimer;

  WebRtcMeshAdapter({
    FirebaseSignalingAdapter? signalingAdapter,
    IRtcPeerConnectionFactory connectionFactory = const DefaultRtcPeerConnectionFactory(),
    Map<String, dynamic>? rtcConfiguration,
  })  : _signalingAdapter = signalingAdapter,
        _connectionFactory = connectionFactory,
        _rtcConfiguration = rtcConfiguration ?? {
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
            {'urls': 'stun:stun1.l.google.com:19302'},
            {'urls': 'stun:stun2.l.google.com:19302'},
            {'urls': 'stun:stun.cloudflare.com:3478'},
          ],
          'sdpSemantics': 'unified-plan',
        };

  /// Ephemeral signaling adapter managing WebRTC handshakes.
  FirebaseSignalingAdapter? get signalingAdapter => _signalingAdapter;

  @override
  TransportState get currentState =>
      _isDisposed ? TransportState.offline : (_dataChannels.isNotEmpty ? TransportState.webRtc : TransportState.connecting);

  @override
  Map<String, int> get peerLastSeen => peerLastActiveTimestamps;

  /// Map of connected peer node IDs to their last active timestamp (epoch ms).
  Map<String, int> get peerLastActiveTimestamps =>
      Map.unmodifiable(_peerLastActiveTimestamps);

  /// Currently connected peer node IDs.
  Set<String> get connectedPeers => Set.unmodifiable(_dataChannels.keys);

  /// Reactive stream emitting the active set of connected peers on connection changes.
  Stream<Set<String>> get onPeersChanged => _peersChangedController.stream;

  @override
  Future<void> initializeRoom(String roomCode, String localNodeId) async {
    _roomCode = roomCode.trim().toUpperCase();
    _localNodeId = localNodeId;
    _isDisposed = false;

    if (_incomingPayloadsController.isClosed) {
      _incomingPayloadsController = StreamController<String>.broadcast();
    }
    if (_peersChangedController.isClosed) {
      _peersChangedController = StreamController<Set<String>>.broadcast();
    }

    final signaling = _signalingAdapter;
    if (signaling != null) {
      await signaling.initialize(
        roomCode: _roomCode!,
        localNodeId: _localNodeId!,
      );

      _signalingSubscription =
          signaling.watchIncomingSignals().listen(_handleIncomingSignal);

      // Broadcast join presence so existing peers can establish connections
      try {
        await signaling.broadcastJoin();
      } catch (_) {}
    }

    // Start sending periodic heartbeat pings (every 2 seconds)
    _startHeartbeatPings();
  }

  /// Sends periodic heartbeat pings to all connected data channels.
  void _startHeartbeatPings() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isDisposed) return;
      _sendHeartbeatPing();
    });
  }

  void _sendHeartbeatPing() {
    final pingPayload = jsonEncode({
      '_protocol': 'heartbeat_ping',
      'from': _localNodeId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    for (final entry in _dataChannels.entries) {
      try {
        entry.value.send(RTCDataChannelMessage(pingPayload));
      } catch (_) {
        // Handled during zombie pruning if unreachable
      }
    }
  }

  /// Handles incoming ephemeral signaling message (offer, answer, candidate, peerJoin).
  Future<void> _handleIncomingSignal(SignalingMessage message) async {
    if (_isDisposed || message.fromNodeId == _localNodeId) return;

    final peerId = message.fromNodeId;

    switch (message.type) {
      case SignalingType.peerJoin:
        if (peerId != _localNodeId) {
          if (!_dataChannels.containsKey(peerId) && !_peerConnections.containsKey(peerId)) {
            await connectToPeer(peerId);
          }
        }
        if (_signalingAdapter != null) {
          await _signalingAdapter?.deleteSignal(message.id);
        }
      case SignalingType.peerLeave:
        prunePeer(peerId);
        if (_signalingAdapter != null) {
          await _signalingAdapter?.deleteSignal(message.id);
        }
      case SignalingType.offer:
        await _handleOffer(peerId, message.sdp!, message.id);
      case SignalingType.answer:
        await _handleAnswer(peerId, message.sdp!, message.id);
      case SignalingType.candidate:
        if (message.candidate != null) {
          await _handleCandidate(peerId, message.candidate!, message.id);
        }
    }
  }

  /// Initiates connection to a new peer by creating an offer.
  Future<void> connectToPeer(String peerNodeId) async {
    if (_isDisposed || _peerConnections.containsKey(peerNodeId)) return;

    final pc = await _connectionFactory.createConnection(_rtcConfiguration);
    _peerConnections[peerNodeId] = pc;

    // Create outbound DataChannel
    final dcInit = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = 30;
    final dc = await pc.createDataChannel('dn5e_mesh', dcInit);
    _registerDataChannel(peerNodeId, dc);

    _setupPeerConnectionCallbacks(peerNodeId, pc);

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    final signaling = _signalingAdapter;
    if (signaling != null && offer.sdp != null) {
      await signaling.sendOffer(
        toNodeId: peerNodeId,
        sdp: offer.sdp!,
      );
    }
  }

  Future<void> _handleOffer(String peerId, String sdp, String signalId) async {
    // If we already have an open DataChannel to this peer, ignore duplicate offers
    if (_dataChannels[peerId]?.state == RTCDataChannelState.RTCDataChannelOpen) {
      final signaling = _signalingAdapter;
      if (signaling != null) {
        await signaling.deleteSignal(signalId);
      }
      return;
    }

    // Glare resolution: both nodes simultaneously initiated offers
    final existingPc = _peerConnections[peerId];
    if (existingPc != null) {
      final isLocalPrecedent = (_localNodeId ?? '').compareTo(peerId) > 0;
      if (isLocalPrecedent) {
        // Local node has priority; drop colliding offer and let remote peer answer our offer
        final signaling = _signalingAdapter;
        if (signaling != null) {
          await signaling.deleteSignal(signalId);
        }
        return;
      } else {
        // Remote node has priority; yield our in-flight connection
        prunePeer(peerId);
      }
    }

    final pc = await _connectionFactory.createConnection(_rtcConfiguration);
    _peerConnections[peerId] = pc;

    pc.onDataChannel = (channel) {
      _registerDataChannel(peerId, channel);
    };

    _setupPeerConnectionCallbacks(peerId, pc);

    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    final signaling = _signalingAdapter;
    if (signaling != null && answer.sdp != null) {
      await signaling.sendAnswer(
        toNodeId: peerId,
        sdp: answer.sdp!,
      );
      // Consume and delete the offer document
      await signaling.deleteSignal(signalId);
    }
  }

  Future<void> _handleAnswer(String peerId, String sdp, String signalId) async {
    final pc = _peerConnections[peerId];
    if (pc != null) {
      try {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      } catch (_) {}
      final signaling = _signalingAdapter;
      if (signaling != null) {
        // Consume and delete the answer document
        await signaling.deleteSignal(signalId);
      }
    }
  }

  Future<void> _handleCandidate(
    String peerId,
    Map<String, dynamic> candidateMap,
    String signalId,
  ) async {
    final pc = _peerConnections[peerId];
    if (pc != null) {
      try {
        final candidate = RTCIceCandidate(
          candidateMap['candidate'] as String?,
          candidateMap['sdpMid'] as String?,
          candidateMap['sdpMLineIndex'] as int?,
        );
        await pc.addCandidate(candidate);
      } catch (_) {}
      final signaling = _signalingAdapter;
      if (signaling != null) {
        await signaling.deleteSignal(signalId);
      }
    }
  }

  void _setupPeerConnectionCallbacks(String peerId, RTCPeerConnection pc) {
    pc.onIceCandidate = (candidate) {
      final signaling = _signalingAdapter;
      if (signaling != null && candidate.candidate != null) {
        signaling.sendIceCandidate(
          toNodeId: peerId,
          candidate: candidate.toMap(),
        );
      }
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        // Clean up lingering signaling documents for this peer once P2P is established!
        _signalingAdapter?.cleanUpPeerSignaling(peerId);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        prunePeer(peerId);
      }
    };
  }

  void _registerDataChannel(String peerId, RTCDataChannel dc) {
    _dataChannels[peerId] = dc;
    _peerLastActiveTimestamps[peerId] = DateTime.now().millisecondsSinceEpoch;

    dc.onMessage = (RTCDataChannelMessage message) {
      _peerLastActiveTimestamps[peerId] = DateTime.now().millisecondsSinceEpoch;

      if (message.isBinary) return;

      final text = message.text;
      if (text.startsWith('{"_protocol":"heartbeat_ping"')) {
        // Respond with heartbeat pong
        final pong = jsonEncode({
          '_protocol': 'heartbeat_pong',
          'from': _localNodeId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        try {
          dc.send(RTCDataChannelMessage(pong));
        } catch (_) {}
        return;
      } else if (text.startsWith('{"_protocol":"heartbeat_pong"')) {
        return;
      }

      // Application/CRDT payload
      _incomingPayloadsController.add(text);
    };

    dc.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _peerLastActiveTimestamps[peerId] = DateTime.now().millisecondsSinceEpoch;
        if (!_peersChangedController.isClosed) {
          _peersChangedController.add(connectedPeers);
        }
        // P2P DataChannel is open! Ephemeral cleanup guarantee for this peer
        _signalingAdapter?.cleanUpPeerSignaling(peerId);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        prunePeer(peerId);
      }
    };
  }

  /// Injects or updates a peer's heartbeat (useful for simulation/testing).
  void recordPeerActivity(String peerId, {int? timestamp}) {
    _peerLastActiveTimestamps[peerId] =
        timestamp ?? DateTime.now().millisecondsSinceEpoch;
  }

  /// Manually registers an active channel (for mocking/testing).
  void registerMockDataChannel(String peerId, RTCDataChannel dc) {
    _registerDataChannel(peerId, dc);
  }

  /// Prunes an inactive or closed peer connection from the mesh.
  void prunePeer(String peerId) {
    _dataChannels.remove(peerId)?.close();
    _peerConnections.remove(peerId)?.close();
    _peerLastActiveTimestamps.remove(peerId);
    if (!_peersChangedController.isClosed) {
      _peersChangedController.add(connectedPeers);
    }
  }

  @override
  Future<void> broadcastPayload(String jsonPayload) async {
    if (_dataChannels.isEmpty) {
      throw StateError('No active WebRTC data channels available.');
    }

    final errors = <dynamic>[];
    for (final dc in _dataChannels.values) {
      try {
        dc.send(RTCDataChannelMessage(jsonPayload));
      } catch (e) {
        errors.add(e);
      }
    }

    if (errors.length == _dataChannels.length) {
      throw StateError('Failed to broadcast payload to any WebRTC peer: $errors');
    }
  }

  @override
  Stream<String> watchIncomingPayloads() => _incomingPayloadsController.stream;

  @override
  Future<void> disconnect() async {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    await _signalingSubscription?.cancel();
    _signalingSubscription = null;

    final channels = List<RTCDataChannel>.from(_dataChannels.values);
    _dataChannels.clear();
    for (final dc in channels) {
      try {
        dc.close();
      } catch (_) {}
    }

    final pcs = List<RTCPeerConnection>.from(_peerConnections.values);
    _peerConnections.clear();
    for (final pc in pcs) {
      try {
        pc.close();
      } catch (_) {}
    }
    _peerLastActiveTimestamps.clear();

    await _signalingAdapter?.cleanUpSignalingSession();
    await _incomingPayloadsController.close();
    await _peersChangedController.close();
  }
}
