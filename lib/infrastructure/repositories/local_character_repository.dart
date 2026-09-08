import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/ports/i_character_repository.dart';
import '../../models/domain/character_models.dart';
import '../../services/logging_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../dtos/character_dto.dart';

/// Concrete infrastructure adapter implementing [ICharacterRepository]
/// using IndexedDB / Hive ([AppDatabaseService]) with fallback to [SharedPreferences].
class LocalCharacterRepository implements ICharacterRepository {
  static const String _kSavedRosterKey = 'saved_characters_roster_v1';
  static const String _kActiveCharacterIdKey = 'saved_active_character_id_v1';

  static final LocalCharacterRepository _instance = LocalCharacterRepository._internal();
  factory LocalCharacterRepository() => _instance;
  LocalCharacterRepository._internal();

  final AppDatabaseService _db = AppDatabaseService.instance;

  @override
  Future<List<Character>> loadCharacters() async {
    try {
      // 1. Check local IndexedDB / Hive database
      if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
        final raw = _db.get(AppDatabaseService.boxCharacters, _kSavedRosterKey);
        if (raw != null) {
          if (raw is List) {
            return raw
                .map((item) => CharacterDto.fromMap(
                    Map<String, dynamic>.from(item is Map ? item : json.decode(item.toString()) as Map)).toDomain())
                .toList();
          } else if (raw is String && raw.isNotEmpty) {
            final decoded = json.decode(raw) as List<dynamic>;
            return decoded
                .map((item) => CharacterDto.fromMap(Map<String, dynamic>.from(item as Map)).toDomain())
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
            .map((item) => CharacterDto.fromMap(Map<String, dynamic>.from(item as Map)).toDomain())
            .toList();
        if (list.isNotEmpty) {
          if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
            await _db.put(
              AppDatabaseService.boxCharacters,
              _kSavedRosterKey,
              list.map((c) => CharacterDto.fromDomain(c).toMap()).toList(),
            );
          }
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

  @override
  Future<void> saveRoster(List<Character> roster) async {
    try {
      final listMaps = roster.map((c) => CharacterDto.fromDomain(c).toMap()).toList();
      if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
        await _db.put(
          AppDatabaseService.boxCharacters,
          _kSavedRosterKey,
          listMaps,
        );
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = json.encode(listMaps);
        await prefs.setString(_kSavedRosterKey, encoded);
      } catch (_) {}
    } catch (e) {
      LoggingService().logWarning(
        'Failed to save characters roster to repository: $e',
        e,
      );
    }
  }

  @override
  Future<void> saveCharacter(Character character) async {
    final roster = await loadCharacters();
    final index = roster.indexWhere(
      (c) => c.id.slug == character.id.slug || (c.id.slug.isEmpty && c.name == character.name),
    );

    if (index >= 0) {
      roster[index] = character;
    } else {
      roster.add(character);
    }
    await saveRoster(roster);
  }

  @override
  Future<void> saveCharacters(List<Character> characters) async {
    final roster = await loadCharacters();
    for (final char in characters) {
      final index = roster.indexWhere(
        (c) => c.id.slug == char.id.slug || (c.id.slug.isEmpty && c.name == char.name),
      );
      if (index >= 0) {
        roster[index] = char;
      } else {
        roster.add(char);
      }
    }
    await saveRoster(roster);
  }

  @override
  Future<void> deleteCharacter(String characterId) async {
    final roster = await loadCharacters();
    roster.removeWhere(
      (c) => c.id.slug == characterId || c.name == characterId,
    );
    await saveRoster(roster);
  }

  @override
  Future<String?> loadActiveCharacterId() async {
    try {
      if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
        final id = _db.get(AppDatabaseService.boxCharacters, _kActiveCharacterIdKey);
        if (id != null && id.toString().isNotEmpty) {
          return id.toString();
        }
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
      if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
        await _db.put(AppDatabaseService.boxCharacters, _kActiveCharacterIdKey, id);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveCharacterIdKey, id);
    } catch (_) {}
  }

  @override
  Future<void> clearActiveCharacterId() async {
    try {
      if (_db.isBoxOpen(AppDatabaseService.boxCharacters)) {
        await _db.delete(AppDatabaseService.boxCharacters, _kActiveCharacterIdKey);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveCharacterIdKey);
    } catch (_) {}
  }
}
