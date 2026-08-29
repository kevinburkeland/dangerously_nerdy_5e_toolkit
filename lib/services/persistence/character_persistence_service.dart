import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/domain/character_models.dart';
import '../../services/logging_service.dart';

/// Persistence service for saving, loading, and deleting characters in local storage.
class CharacterPersistenceService {
  static const String _kSavedRosterKey = 'saved_characters_roster_v1';
  static const String _kActiveCharacterIdKey = 'saved_active_character_id_v1';

  static final CharacterPersistenceService _instance =
      CharacterPersistenceService._internal();
  factory CharacterPersistenceService() => _instance;
  CharacterPersistenceService._internal();

  /// Loads all saved characters from SharedPreferences. Returns empty list if no characters are saved.
  Future<List<Character>> loadCharacters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rosterJson = prefs.getString(_kSavedRosterKey);
      if (rosterJson != null && rosterJson.isNotEmpty) {
        final decoded = json.decode(rosterJson) as List<dynamic>;
        final list = decoded
            .map((item) => Character.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      LoggingService().logWarning(
        'Failed to load characters from persistence: $e',
        e,
      );
    }
    return <Character>[];
  }

  /// Saves the complete character roster to SharedPreferences.
  Future<void> saveRoster(List<Character> roster) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(roster.map((c) => c.toMap()).toList());
      await prefs.setString(_kSavedRosterKey, encoded);
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
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kActiveCharacterIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Saves the active character ID.
  Future<void> saveActiveCharacterId(String slug) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveCharacterIdKey, slug);
    } catch (e) {
      // Non-fatal
    }
  }
}
