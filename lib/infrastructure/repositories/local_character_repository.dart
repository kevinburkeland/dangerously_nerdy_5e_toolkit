import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/models/character_models.dart';
import '../../services/logging_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../../services/rules/character_reparse_engine.dart';
import '../dtos/character_dto.dart';

/// Concrete infrastructure adapter implementing [ICharacterRepository]
/// using IndexedDB / Hive ([AppDatabaseService]) with fallback to [SharedPreferences].
class LocalCharacterRepository implements ICharacterRepository {
  static const String _kSavedRosterKey = 'saved_characters_roster_v1';
  static const String _kActiveCharacterIdKey = 'saved_active_character_id_v1';

  final AppDatabaseService _db;

  LocalCharacterRepository({AppDatabaseService? db})
      : _db = db ?? AppDatabaseService.instance;

  @override
  Future<List<Character>> loadCharacters() async {
    try {
      // 1. Check local IndexedDB / Hive database
      final raw = _db.get(AppDatabaseService.boxCharacters, _kSavedRosterKey);
      if (raw != null) {
        if (raw is List) {
          final roster = raw
              .map((item) => CharacterDto.fromMap(Map<String, dynamic>.from(
                      item is Map ? item : json.decode(item.toString()) as Map))
                  .toDomain())
              .toList();
          return roster;
        } else if (raw is String && raw.isNotEmpty) {
          final decoded = json.decode(raw) as List<dynamic>;
          final roster = decoded
              .map((item) =>
                  CharacterDto.fromMap(Map<String, dynamic>.from(item as Map))
                      .toDomain())
              .toList();
          return roster;
        }
      }

      // 2. Fallback / Migration from legacy SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final rosterJson = prefs.getString(_kSavedRosterKey);
      if (rosterJson != null && rosterJson.isNotEmpty) {
        final decoded = json.decode(rosterJson) as List<dynamic>;
        final list = decoded
            .map((item) =>
                CharacterDto.fromMap(Map<String, dynamic>.from(item as Map))
                    .toDomain())
            .toList();
        if (list.isNotEmpty) {
          await _persistRosterToDisk(list);
          return list;
        }
      }
    } catch (e) {
      LoggingService().logWarning(
        'Failed to load characters from repository: $e',
        e,
      );
    }
    return <Character>[];
  }

  @override
  Future<Character?> getCharacter(String id) async {
    final roster = await loadCharacters();
    try {
      return roster.firstWhere(
        (c) => c.id.slug == id || c.name == id,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async {
    if (ids.isEmpty) return <Character>[];
    final all = await loadCharacters();
    final map = {for (final c in all) c.id.slug: c};
    return ids.map((id) => map[id]).whereType<Character>().toList();
  }

  Future<void> _persistRosterToDisk(List<Character> roster) async {
    try {
      final listMaps =
          roster.map((c) => CharacterDto.fromDomain(c).toMap()).toList();
      await _db.put(
        AppDatabaseService.boxCharacters,
        _kSavedRosterKey,
        listMaps,
      );
    } catch (e) {
      LoggingService().logWarning(
        'Failed to save characters roster to repository: $e',
        e,
      );
    }
  }

  @override
  Future<void> saveRoster(List<Character> roster) async {
    await _persistRosterToDisk(roster);
  }

  @override
  Future<void> saveCharacter(Character character) async {
    final roster = await loadCharacters();
    final index = roster.indexWhere(
      (c) =>
          c.id.slug == character.id.slug ||
          (c.id.slug.isEmpty && c.name == character.name),
    );

    if (index >= 0) {
      roster[index] = character;
    } else {
      roster.add(character);
    }

    await _persistRosterToDisk(roster);
  }

  @override
  Future<void> saveCharacters(List<Character> characters) async {
    final roster = await loadCharacters();
    for (final char in characters) {
      final index = roster.indexWhere(
        (c) =>
            c.id.slug == char.id.slug ||
            (c.id.slug.isEmpty && c.name == char.name),
      );
      if (index >= 0) {
        roster[index] = char;
      } else {
        roster.add(char);
      }
    }

    await _persistRosterToDisk(roster);
  }

  @override
  Future<void> deleteCharacter(String characterId) async {
    final roster = await loadCharacters();
    roster.removeWhere(
      (c) => c.id.slug == characterId || c.name == characterId,
    );
    await _persistRosterToDisk(roster);
  }

  @override
  Future<String?> loadActiveCharacterId() async {
    try {
      final id =
          _db.get(AppDatabaseService.boxCharacters, _kActiveCharacterIdKey);
      if (id != null && id.toString().isNotEmpty) {
        return id.toString();
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kActiveCharacterIdKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveActiveCharacterId(String id) async {
    try {
      await _db.put(
          AppDatabaseService.boxCharacters, _kActiveCharacterIdKey, id);
    } catch (_) {}
  }

  @override
  Future<void> clearActiveCharacterId() async {
    try {
      await _db.delete(
          AppDatabaseService.boxCharacters, _kActiveCharacterIdKey);
    } catch (_) {}
  }

  /// Reparses and updates a single character against current compendiums and rules.
  @override
  Future<Character> reparseCharacter(Character character) async {
    final updated = CharacterReparseEngine.reparse(character);
    await saveCharacter(updated);
    return updated;
  }

  /// Reparses and updates all characters in the roster against current compendiums and rules.
  @override
  Future<List<Character>> reparseAllCharacters() async {
    final roster = await loadCharacters();
    final updatedRoster = <Character>[];
    for (final c in roster) {
      final updated = CharacterReparseEngine.reparse(c);
      updatedRoster.add(updated);
    }
    await saveRoster(updatedRoster);
    return updatedRoster;
  }
}
