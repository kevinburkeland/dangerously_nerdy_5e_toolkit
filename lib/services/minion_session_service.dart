import '../models/animated_object.dart';
import '../models/spell_session.dart';
import '../models/srd_summons/srd_summons_library.dart';

/// Service that persists active spell and minion squad sessions in memory
/// across screen navigations and tool changes.
class MinionSessionService {
  static final MinionSessionService _instance = MinionSessionService._internal();
  factory MinionSessionService() => _instance;
  MinionSessionService._internal();

  final Map<String, SpellSession> _sessions = {};

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
  }

  /// Clears in-memory cached sessions (primarily for unit tests).
  void clearCacheForTesting() {
    _sessions.clear();
  }
}
