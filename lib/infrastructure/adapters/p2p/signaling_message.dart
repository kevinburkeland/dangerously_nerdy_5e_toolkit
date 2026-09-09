enum SignalingType {
  offer,
  answer,
  candidate,
  peerJoin,
  peerLeave,
}

/// Ephemeral signaling message exchanged between peers via Firestore
/// to establish WebRTC P2P DataChannel mesh connections.
class SignalingMessage {
  final String id;
  final String roomCode;
  final String fromNodeId;
  final String toNodeId;
  final SignalingType type;
  final String? sdp;
  final Map<String, dynamic>? candidate;
  final int timestamp;

  const SignalingMessage({
    required this.id,
    required this.roomCode,
    required this.fromNodeId,
    required this.toNodeId,
    required this.type,
    this.sdp,
    this.candidate,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomCode': roomCode,
      'fromNodeId': fromNodeId,
      'toNodeId': toNodeId,
      'type': type.name,
      if (sdp != null) 'sdp': sdp,
      if (candidate != null) 'candidate': candidate,
      'timestamp': timestamp,
    };
  }

  factory SignalingMessage.fromMap(Map<String, dynamic> map, {String? docId}) {
    final typeStr = map['type'] as String? ?? 'candidate';
    final type = SignalingType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => SignalingType.candidate,
    );

    return SignalingMessage(
      id: docId ?? (map['id'] as String? ?? ''),
      roomCode: map['roomCode'] as String? ?? '',
      fromNodeId: map['fromNodeId'] as String? ?? '',
      toNodeId: map['toNodeId'] as String? ?? '',
      type: type,
      sdp: map['sdp'] as String?,
      candidate: map['candidate'] != null
          ? Map<String, dynamic>.from(map['candidate'] as Map)
          : null,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}
