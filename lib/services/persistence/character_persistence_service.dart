import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/domain/character_models.dart';
import '../../services/logging_service.dart';
import 'app_database_service.dart';

/// Persistence service for saving, loading, and deleting characters in local storage.
/// Backed by Hive / IndexedDB via [AppDatabaseService], bypassing 5MB localStorage limits.
class CharacterPersistenceService {
  static const String _kSavedRosterKey = 'saved_characters_roster_v1';
  static const String _kActiveCharacterIdKey = 'saved_active_character_id_v1';

  static final CharacterPersistenceService _instance =
      CharacterPersistenceService._internal();
  factory CharacterPersistenceService() => _instance;
  CharacterPersistenceService._internal();

  final AppDatabaseService _db = AppDatabaseService.instance;

  /// Loads all saved characters from local database.
  /// Automatically migrates legacy records from SharedPreferences if database is unseeded.
  Future<List<Character>> loadCharacters() async {
    try {
      // 1. Check local IndexedDB / Hive database (if open)
      if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
        final raw = _db.get(AppDatabaseService.boxCharacters, _kSavedRosterKey);
        if (raw != null) {
          if (raw is List) {
            return raw
                .map((item) => Character.fromMap(
                    Map<String, dynamic>.from(item is Map ? item : json.decode(item.toString()) as Map)))
                .toList();
          } else if (raw is String && raw.isNotEmpty) {
            final decoded = json.decode(raw) as List<dynamic>;
            return decoded
                .map((item) => Character.fromMap(Map<String, dynamic>.from(item as Map)))
                .toList();
          }
        }
      }

      // 2. Fallback / Migration from legacy SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final rosterJson = prefs.getString(_kSavedRosterKey);
      if (rosterJson != null && rosterJson.isNotEmpty) {
        final decoded = json.decode(rosterJson) as List<dynamic>;
        final list = decoded
            .map((item) => Character.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (list.isNotEmpty) {
          // One-time migration into database if open
          if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
            await _db.put(
              AppDatabaseService.boxCharacters,
              _kSavedRosterKey,
              list.map((c) => c.toMap()).toList(),
            );
          }
          return list;
        }
      }
    } catch (e) {
      LoggingService().logWarning(
        'Failed to load characters from persistence: $e',
        e,
      );
    }
    return <Character>[];
  }

  /// Saves the complete character roster to local database and syncs to SharedPreferences for safety.
  Future<void> saveRoster(List<Character> roster) async {
    try {
      final listMaps = roster.map((c) => c.toMap()).toList();
      if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
        await _db.put(
          AppDatabaseService.boxCharacters,
          _kSavedRosterKey,
          listMaps,
        );
      }

      // Best-effort sync to SharedPreferences for backwards compatibility
      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = json.encode(listMaps);
        await prefs.setString(_kSavedRosterKey, encoded);
      } catch (_) {
        // Suppress quota errors from SharedPreferences if payload exceeds 5MB
      }
    } catch (e) {
      LoggingService().logWarning(
        'Failed to save characters roster to persistence: $e',
        e,
      );
    }
  }

  /// Saves or updates a single character in the roster.
  Future<List<Character>> saveCharacter(Character character) async {
    final roster = List<Character>.from(await loadCharacters());
    final index = roster.indexWhere((c) => c.id.slug == character.id.slug);
    if (index >= 0) {
      roster[index] = character;
    } else {
      roster.add(character);
    }
    await saveRoster(roster);
    return roster;
  }

  /// Deletes a character by slug from the roster.
  Future<List<Character>> deleteCharacter(String characterSlug) async {
    final roster = List<Character>.from(await loadCharacters());
    roster.removeWhere((c) => c.id.slug == characterSlug);
    await saveRoster(roster);
    return roster;
  }

  /// Loads the active character ID.
  Future<String?> loadActiveCharacterId() async {
    try {
      final dbVal = _db.get(AppDatabaseService.boxCharacters, _kActiveCharacterIdKey);
      if (dbVal != null && dbVal.toString().isNotEmpty) {
        return dbVal.toString();
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kActiveCharacterIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Saves the active character ID.
  Future<void> saveActiveCharacterId(String slug) async {
    try {
      await _db.put(AppDatabaseService.boxCharacters, _kActiveCharacterIdKey, slug);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveCharacterIdKey, slug);
    } catch (e) {
      // Non-fatal
    }
  }
}
