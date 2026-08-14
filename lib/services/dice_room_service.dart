import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/room_roll.dart';
import '../utils/secure_random.dart';
import 'base_room_service.dart';
import 'logging_service.dart';

class RoomSession {
  final String roomCode;
  final String playerName;

  RoomSession({
    required this.roomCode,
    required this.playerName,
  });
}

class DiceRoomService implements BaseRoomService {
  static final DiceRoomService _instance = DiceRoomService._internal();
  factory DiceRoomService() => _instance;
  DiceRoomService._internal();

  // Centralized active room session notifier
  @override
  final ValueNotifier<RoomSession?> activeSessionNotifier = ValueNotifier<RoomSession?>(null);

  @override
  String? get activeRoomCode => activeSessionNotifier.value?.roomCode;
  @override
  String? get playerName => activeSessionNotifier.value?.playerName;

  @override
  void joinRoom(String roomCode, String playerName) {
    final cleanCode = roomCode.trim().toUpperCase();
    final cleanName = playerName.trim();
    if (cleanCode.isNotEmpty && cleanName.isNotEmpty) {
      activeSessionNotifier.value = RoomSession(
        roomCode: cleanCode,
        playerName: cleanName,
      );
    }
  }

  @override
  void leaveRoom() {
    final currentCode = activeRoomCode;
    if (currentCode != null) {
      disposeRoomStream(currentCode);
    }
    activeSessionNotifier.value = null;
  }

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
  @override
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
        }).handleError((error, stackTrace) {
          LoggingService().logNonFatal(
            error,
            stackTrace,
            reason: 'Firestore streamRoomRolls error for room $cleanCode',
          );
          return <RoomRoll>[];
        });
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason: 'Firestore stream initialization failed for room $cleanCode; falling back to in-memory',
        );
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
  @override
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
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason: 'Firestore broadcastRoll failed for room $cleanCode; falling back to in-memory',
        );
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

  /// Helper to generate a random 6-character uppercase room code
  @override
  String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = SecureRng.instance;
    String result = '';
    for (int i = 0; i < 6; i++) {
      result += chars[rng.nextInt(chars.length)];
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

