import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/room_roll.dart';

class DiceRoomService {
  static final DiceRoomService _instance = DiceRoomService._internal();
  factory DiceRoomService() => _instance;
  DiceRoomService._internal();

  // In-memory fallback stream for local/offline testing
  final Map<String, List<RoomRoll>> _localRooms = {};
  final Map<String, StreamController<List<RoomRoll>>> _localControllers = {};

  bool get isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns a stream of real-time rolls for a given room code (from last 24 hours, up to 100 rolls)
  Stream<List<RoomRoll>> streamRoomRolls(String roomCode) {
    final cleanCode = roomCode.trim().toUpperCase();
    final cutoff24h = DateTime.now().subtract(const Duration(hours: 24));

    if (isFirebaseAvailable) {
      try {
        return FirebaseFirestore.instance
            .collection('rooms')
            .doc(cleanCode)
            .collection('rolls')
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff24h))
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs.map((doc) => RoomRoll.fromMap(doc.data())).toList();
        });
      } catch (e) {
        // Fallback to local memory stream if Firestore query fails
      }
    }

    // Local in-memory broadcast fallback
    if (!_localControllers.containsKey(cleanCode)) {
      _localControllers[cleanCode] = StreamController<List<RoomRoll>>.broadcast();
      _localRooms[cleanCode] = [];
    }

    // Emit current list immediately on subscribe (filtered to last 24 hours)
    Future.microtask(() {
      if (_localControllers.containsKey(cleanCode) && !_localControllers[cleanCode]!.isClosed) {
        final recentRolls = (_localRooms[cleanCode] ?? [])
            .where((r) => r.timestamp.isAfter(cutoff24h))
            .toList();
        _localControllers[cleanCode]!.add(List.unmodifiable(recentRolls));
      }
    });

    return _localControllers[cleanCode]!.stream;
  }

  /// Broadcasts a roll to the specified room
  Future<void> broadcastRoll(RoomRoll roll) async {
    final cleanCode = roll.roomCode.trim().toUpperCase();

    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(cleanCode)
            .collection('rolls')
            .doc(roll.id)
            .set(roll.toMap());
        return;
      } catch (e) {
        // Fallback to local
      }
    }

    // Local in-memory fallback
    if (!_localRooms.containsKey(cleanCode)) {
      _localRooms[cleanCode] = [];
    }
    if (!_localControllers.containsKey(cleanCode)) {
      _localControllers[cleanCode] = StreamController<List<RoomRoll>>.broadcast();
    }

    _localRooms[cleanCode]!.insert(0, roll);

    // Keep only rolls from last 24 hours up to 100 max
    final cutoff24h = DateTime.now().subtract(const Duration(hours: 24));
    _localRooms[cleanCode] = _localRooms[cleanCode]!
        .where((r) => r.timestamp.isAfter(cutoff24h))
        .take(100)
        .toList();

    _localControllers[cleanCode]!.add(List.unmodifiable(_localRooms[cleanCode]!));
  }

  /// Helper to generate a random 4-character uppercase room code
  String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    String result = '';
    int val = random;
    for (int i = 0; i < 4; i++) {
      result += chars[val % chars.length];
      val = (val / chars.length).floor();
    }
    return 'ROOM-$result';
  }

  void disposeRoomStream(String roomCode) {
    final cleanCode = roomCode.trim().toUpperCase();
    if (_localControllers.containsKey(cleanCode)) {
      _localControllers[cleanCode]?.close();
      _localControllers.remove(cleanCode);
      _localRooms.remove(cleanCode);
    }
  }
}
