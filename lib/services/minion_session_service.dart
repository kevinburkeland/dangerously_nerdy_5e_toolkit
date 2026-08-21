import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/animated_object.dart';
import '../models/spell_session.dart';
import '../models/srd_summons/srd_summons_library.dart';
import 'logging_service.dart';
import 'persistence/debounced_storage_service.dart';

/// Service that persists active spell and minion squad sessions in memory
/// and local storage across screen navigations, tool changes, and app restarts.
class MinionSessionService {
  static const String _kPersistedSessionsKey = 'minion_persisted_sessions_v1';

  static final MinionSessionService _instance = MinionSessionService._internal();
  factory MinionSessionService() => _instance;
  MinionSessionService._internal() {
    _loadPersistedSessions();
  }

  final Map<String, SpellSession> _sessions = {};

  /// Asynchronously hydrates stored minion sessions from disk
  Future<void> _loadPersistedSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_kPersistedSessionsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          if (entry.value is Map) {
            try {
              final session = SpellSession.fromMap(
                Map<String, dynamic>.from(entry.value as Map),
              );
              _sessions[entry.key] = session;
            } catch (e, stackTrace) {
              LoggingService().logNonFatal(
                e,
                stackTrace,
                reason: 'Failed to deserialize minion session for ${entry.key}',
              );
            }
          }
        }
      }
    } catch (_) {
      // Ignored during testing if ServicesBinding is not yet initialized
    }
  }

  /// Explicitly reloads persisted sessions from disk
  Future<void> reloadFromDisk() async {
    _sessions.clear();
    await _loadPersistedSessions();
  }

  /// Retrieves an existing session for [preset], or initializes and caches a new one
  /// with default minions if no session exists yet.
  SpellSession getOrCreateSession(SummonPreset preset, {int? defaultSpellLevel}) {
    if (_sessions.containsKey(preset.id)) {
      return _sessions[preset.id]!;
    }
    final session = SpellSession(
      activePreset: preset,
      spellLevel: defaultSpellLevel ?? 5,
    );
    populateDefaultMinions(session, preset);
    _sessions[preset.id] = session;
    return session;
  }

  /// Checks if a session has already been initialized for [presetId].
  bool hasSession(String presetId) => _sessions.containsKey(presetId);

  /// Retrieves an existing session for [presetId] if present, otherwise returns null.
  SpellSession? getSession(String presetId) => _sessions[presetId];

  /// Populates the initial default minions for [session] according to [preset].
  static void populateDefaultMinions(SpellSession session, SummonPreset preset) {
    session.clearAll();
    final id = preset.id;

    if (id == 'animate_objects') {
      for (int i = 1; i <= preset.defaultMinionCount; i++) {
        session.addObject(ObjectSize.tiny, customName: 'Silver Coin #$i');
      }
    } else if (id.startsWith('bag_of_tricks') || id == 'bag_of_tricks') {
      session.rollBagOfTricks();
    } else if (id.startsWith('horn_of_valhalla') || id == 'horn_of_valhalla') {
      final variant = id.contains('brass')
          ? 'brass'
          : id.contains('bronze')
              ? 'bronze'
              : id.contains('iron')
                  ? 'iron'
                  : 'silver';
      session.rollHornOfValhalla(variant);
    } else if (preset.statBlocks.isNotEmpty) {
      final defaultStat = preset.statBlocks.first;
      final count = preset.defaultMinionCount;
      for (int i = 0; i < count; i++) {
        session.addMinionFromStatBlock(defaultStat);
      }
    }
  }

  /// Resets a specific preset session to its default spell level and initial minions.
  void resetSession(SummonPreset preset, {int? defaultSpellLevel}) {
    final session = SpellSession(
      activePreset: preset,
      spellLevel: defaultSpellLevel ?? 5,
    );
    populateDefaultMinions(session, preset);
    _sessions[preset.id] = session;
    saveSessionDebounced(preset.id);
  }

  /// Debounces saving minion squad sessions to disk to avoid I/O thrashing during HP adjustments.
  void saveSessionDebounced(String presetId) {
    DebouncedStorageService().scheduleWrite('minion_session_$presetId', () async {
      await persistAllSessions();
    });
  }

  /// Flushes all active minion sessions to persistent storage.
  Future<void> persistAllSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> rawMap = {};
      for (final entry in _sessions.entries) {
        rawMap[entry.key] = entry.value.toMap();
      }
      await prefs.setString(_kPersistedSessionsKey, json.encode(rawMap));
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to persist minion sessions to SharedPreferences',
      );
    }
  }

  /// Clears in-memory and persisted cached sessions.
  Future<void> clearAllSessions() async {
    _sessions.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPersistedSessionsKey);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to clear persisted minion sessions',
      );
    }
  }

  /// Clears in-memory cached sessions (primarily for unit tests).
  void clearCacheForTesting() {
    _sessions.clear();
  }
}
