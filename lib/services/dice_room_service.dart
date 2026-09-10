import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/ports/i_p2p_transport_port.dart';
import '../infrastructure/di/injection_container.dart';
import '../models/room_roll.dart';
import '../utils/secure_random.dart';
import 'logging_service.dart';

class RoomSession {
  final String roomCode;
  final String playerName;
  final bool isRemembered;

  RoomSession({
    required this.roomCode,
    required this.playerName,
    this.isRemembered = true,
  });
}

class DiceRoomService {
  static const _kPersistedRoomCode = 'dice_room_persisted_code';
  static const _kPersistedPlayerName = 'dice_room_persisted_player_name';
  static const _kPersistedRemember = 'dice_room_persisted_remember';

  static final DiceRoomService _instance = DiceRoomService._internal();
  factory DiceRoomService() => _instance;

  DiceRoomService._internal() {
    _restorePersistedSession();
  }

  @visibleForTesting
  DiceRoomService.newInstance();

  // Centralized active room session notifier
  final ValueNotifier<RoomSession?> activeSessionNotifier = ValueNotifier<RoomSession?>(null);

  String? get activeRoomCode => activeSessionNotifier.value?.roomCode;
  String? get playerName => activeSessionNotifier.value?.playerName;
  bool get isSessionRemembered => activeSessionNotifier.value?.isRemembered ?? false;

  /// Restores any previously remembered room session from persistent storage
  Future<void> _restorePersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_kPersistedRemember) ?? false;
      final savedRoom = prefs.getString(_kPersistedRoomCode);
      final savedName = prefs.getString(_kPersistedPlayerName);

      if (remember &&
          savedRoom != null &&
          savedRoom.isNotEmpty &&
          savedName != null &&
          savedName.isNotEmpty) {
        // Only set if not already overridden by an in-flight session
        if (activeSessionNotifier.value == null) {
          activeSessionNotifier.value = RoomSession(
            roomCode: savedRoom.trim().toUpperCase(),
            playerName: savedName.trim(),
            isRemembered: true,
          );
        }
      }
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to restore persisted dice room session',
      );
    }
  }

  /// Joins a room, with optional persistent storage across app visits
  void joinRoom(String roomCode, String playerName, {bool remember = true}) {
    final cleanCode = roomCode.trim().toUpperCase();
    final cleanName = playerName.trim();
    if (cleanCode.isNotEmpty && cleanName.isNotEmpty) {
      activeSessionNotifier.value = RoomSession(
        roomCode: cleanCode,
        playerName: cleanName,
        isRemembered: remember,
      );

      // Async write to persistent storage
      _persistSession(cleanCode, cleanName, remember);

      // Immediately touch/initialize room document in Firestore so campaign features & other players connect instantly
      if (isFirebaseAvailable) {
        _touchRoomInFirestore(cleanCode, cleanName);
      }
    }
  }

  Future<void> _touchRoomInFirestore(String roomCode, String playerName) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('rooms').doc(roomCode);
      final snapshot = await docRef.get();
      final now = DateTime.now();
      if (snapshot.exists && snapshot.data() != null) {
        // Document already exists (e.g. campaign created with DM's custom campaignName) -> preserve campaignName!
        await docRef.update({
          'activePlayers': FieldValue.arrayUnion([playerName]),
          'lastUpdated': now.toIso8601String(),
        });
      } else {
        // Only set default fallback name if document does NOT exist yet
        await docRef.set({
          'roomCode': roomCode,
          'code': roomCode,
          'campaignName': 'Dice Room $roomCode',
          'activePlayers': [playerName],
          'lastUpdated': now.toIso8601String(),
          'createdAt': now.toIso8601String(),
          'expiresAt': now.add(const Duration(days: 30)).toIso8601String(),
        });
      }
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to touch room $roomCode in Firestore on join',
      );
    }
  }

  Future<void> _persistSession(String roomCode, String playerName, bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (remember) {
        await Future.wait([
          prefs.setBool(_kPersistedRemember, true),
          prefs.setString(_kPersistedRoomCode, roomCode),
          prefs.setString(_kPersistedPlayerName, playerName),
        ]);
      } else {
        await Future.wait([
          prefs.remove(_kPersistedRemember),
          prefs.remove(_kPersistedRoomCode),
          prefs.remove(_kPersistedPlayerName),
        ]);
      }
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to write persisted dice room session',
      );
    }
  }

  /// Leaves the current room session and clears any remembered room persistence
  void leaveRoom() {
    final currentCode = activeRoomCode;
    if (currentCode != null) {
      disposeRoomStream(currentCode);
    }
    activeSessionNotifier.value = null;

    // Clear persisted room storage
    _clearPersistedSession();
  }

  Future<void> _clearPersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_kPersistedRemember),
        prefs.remove(_kPersistedRoomCode),
        prefs.remove(_kPersistedPlayerName),
      ]);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to clear persisted dice room session',
      );
    }
  }

  // Unified in-memory room rolls cache, broadcast stream controllers & Firestore subscriptions
  final Map<String, List<RoomRoll>> _localRooms = {};
  final Map<String, StreamController<List<RoomRoll>>> _localControllers = {};
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _firestoreSubscriptions = {};

  /// Deterministically checks if Firebase Core has been initialized with active apps.
  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  /// Returns a unified broadcast stream of real-time rolls for a given room code (last 24 hours, up to 100 rolls)
  Stream<List<RoomRoll>> streamRoomRolls(String roomCode) {
    final cleanCode = roomCode.trim().toUpperCase();
    final cutoff24h = DateTime.now().subtract(const Duration(hours: 24));

    // Ensure unified broadcast controller exists for this room
    if (!_localControllers.containsKey(cleanCode) || _localControllers[cleanCode]!.isClosed) {
      _localControllers[cleanCode] = StreamController<List<RoomRoll>>.broadcast();
      _localRooms[cleanCode] ??= [];
    }

    // Connect Firestore real-time listener if available and not already listening
    if (isFirebaseAvailable && !_firestoreSubscriptions.containsKey(cleanCode)) {
      try {
        _firestoreSubscriptions[cleanCode] = FirebaseFirestore.instance
            .collection('rooms')
            .doc(cleanCode)
            .collection('rolls')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .snapshots()
            .listen((snapshot) {
          final remoteRolls = snapshot.docs
              .map((doc) => RoomRoll.fromMap(doc.data()))
              .where((r) => r.timestamp.isAfter(cutoff24h))
              .toList();

          final localList = _localRooms[cleanCode] ?? [];
          final rollMap = <String, RoomRoll>{};
          for (final r in remoteRolls) {
            rollMap[r.id] = r;
          }
          for (final r in localList) {
            rollMap.putIfAbsent(r.id, () => r);
          }
          final merged = rollMap.values.toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _localRooms[cleanCode] = merged.take(100).toList();

          if (_localControllers.containsKey(cleanCode) && !_localControllers[cleanCode]!.isClosed) {
            _localControllers[cleanCode]!.add(List.unmodifiable(_localRooms[cleanCode]!));
          }
        }, onError: (error, stackTrace) {
          LoggingService().logNonFatal(
            error,
            stackTrace,
            reason: 'Firestore streamRoomRolls error for room $cleanCode; falling back to local rolls',
          );
        });
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason: 'Firestore stream initialization failed for room $cleanCode; falling back to in-memory',
        );
      }
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

  /// Ingests a roll received from a remote transport (P2P mesh, relay, or network bridge)
  void ingestRemoteRoll(RoomRoll roll) {
    final cleanCode = roll.roomCode.trim().toUpperCase();
    if (!_localRooms.containsKey(cleanCode)) {
      _localRooms[cleanCode] = [];
    }
    if (!_localControllers.containsKey(cleanCode) || _localControllers[cleanCode]!.isClosed) {
      _localControllers[cleanCode] = StreamController<List<RoomRoll>>.broadcast();
    }

    if (!_localRooms[cleanCode]!.any((r) => r.id == roll.id)) {
      _localRooms[cleanCode]!.insert(0, roll);
      _localRooms[cleanCode]!.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final cutoff24h = DateTime.now().subtract(const Duration(hours: 24));
      _localRooms[cleanCode] = _localRooms[cleanCode]!
          .where((r) => r.timestamp.isAfter(cutoff24h))
          .take(100)
          .toList();
      if (!_localControllers[cleanCode]!.isClosed) {
        _localControllers[cleanCode]!.add(List.unmodifiable(_localRooms[cleanCode]!));
      }
    }
  }

  /// Broadcasts a roll to the specified room across local cache, P2P mesh, and cloud Firestore
  Future<void> broadcastRoll(RoomRoll roll) async {
    final cleanCode = roll.roomCode.trim().toUpperCase();

    // 1. Immediately cache in local room list and notify local listeners for instant 0ms latency UI
    if (!_localRooms.containsKey(cleanCode)) {
      _localRooms[cleanCode] = [];
    }
    if (!_localControllers.containsKey(cleanCode) || _localControllers[cleanCode]!.isClosed) {
      _localControllers[cleanCode] = StreamController<List<RoomRoll>>.broadcast();
    }

    if (!_localRooms[cleanCode]!.any((r) => r.id == roll.id)) {
      _localRooms[cleanCode]!.insert(0, roll);
      final cutoff24h = DateTime.now().subtract(const Duration(hours: 24));
      _localRooms[cleanCode] = _localRooms[cleanCode]!
          .where((r) => r.timestamp.isAfter(cutoff24h))
          .take(100)
          .toList();
      if (!_localControllers[cleanCode]!.isClosed) {
        _localControllers[cleanCode]!.add(List.unmodifiable(_localRooms[cleanCode]!));
      }
    }

    // 2. Broadcast via P2P transport mesh if available
    try {
      if (sl.isRegistered<IP2pTransportPort>()) {
        final p2pPayload = jsonEncode({
          'type': 'dice_roll',
          'roomCode': cleanCode,
          'payload': roll.toMap(useFirestoreTimestamp: false),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        unawaited(sl<IP2pTransportPort>().broadcastPayload(p2pPayload));
      }
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'P2P broadcastRoll failed for room $cleanCode; cloud transport preserved',
      );
    }

    // 3. Broadcast to Firestore if available
    if (isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('rooms')
            .doc(cleanCode)
            .collection('rolls')
            .doc(roll.id)
            .set(roll.toMap());
      } catch (e, stackTrace) {
        LoggingService().logNonFatal(
          e,
          stackTrace,
          reason: 'Firestore broadcastRoll failed for room $cleanCode; local fallback preserved',
        );
      }
    }
  }

  /// Helper to generate a random 6-character uppercase room code
  String generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String result = '';
    for (int i = 0; i < 6; i++) {
      result += chars[secureRandom.nextInt(chars.length)];
    }
    return 'ROOM-$result';
  }

  void disposeRoomStream(String roomCode) {
    final cleanCode = roomCode.trim().toUpperCase();
    if (_firestoreSubscriptions.containsKey(cleanCode)) {
      _firestoreSubscriptions[cleanCode]?.cancel();
      _firestoreSubscriptions.remove(cleanCode);
    }
    if (_localControllers.containsKey(cleanCode)) {
      _localControllers[cleanCode]?.close();
      _localControllers.remove(cleanCode);
      _localRooms.remove(cleanCode);
    }
  }
}
