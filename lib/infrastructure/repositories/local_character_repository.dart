import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import '../../models/domain/character_models.dart';
import '../../services/logging_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../../services/rules/character_reparse_engine.dart';
import '../dtos/character_dto.dart';

/// Concrete infrastructure adapter implementing [ICharacterRepository]
/// using IndexedDB / Hive ([AppDatabaseService]) with fallback to [SharedPreferences].
class LocalCharacterRepository implements ICharacterRepository<Character> {
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
        final List<dynamic> items;
        if (raw is List) {
          items = raw;
        } else if (raw is String && raw.isNotEmpty) {
          items = json.decode(raw) as List<dynamic>;
        } else {
          items = const [];
        }

        if (items.isNotEmpty) {
          final roster = <Character>[];
          for (var i = 0; i < items.length; i++) {
            final item = items[i];
            try {
              final map = Map<String, dynamic>.from(
                  item is Map ? item : json.decode(item.toString()) as Map);
              roster.add(CharacterDto.fromMap(map).toDomain());
            } catch (e) {
              final idField = item is Map ? item['id'] : null;
              final slug = idField is Map ? idField['slug'] : idField?.toString();
              final identifier = slug ?? (item is Map ? item['name'] : null) ?? 'index $i';
              LoggingService().logWarning(
                'Corrupt character record at $identifier could not be loaded: $e',
                e,
              );
            }
          }
          return roster;
        }
      }

      // 2. Fallback / Migration from legacy SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final rosterJson = prefs.getString(_kSavedRosterKey);
      if (rosterJson != null && rosterJson.isNotEmpty) {
        final decoded = json.decode(rosterJson) as List<dynamic>;
        final list = <Character>[];
        for (var i = 0; i < decoded.length; i++) {
          final item = decoded[i];
          try {
            list.add(CharacterDto.fromMap(Map<String, dynamic>.from(item as Map))
                .toDomain());
          } catch (e) {
            final idField = item is Map ? item['id'] : null;
            final slug = idField is Map ? idField['slug'] : idField?.toString();
            final identifier = slug ?? (item is Map ? item['name'] : null) ?? 'index $i';
            LoggingService().logWarning(
              'Corrupt legacy character record at $identifier could not be migrated: $e',
              e,
            );
          }
        }
        if (list.isNotEmpty) {
          await _writeRawRosterToDisk(decoded);
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

  List<dynamic> _loadRawPersistedRoster() {
    final raw = _db.get(AppDatabaseService.boxCharacters, _kSavedRosterKey);
    if (raw is List) {
      return List<dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) return List<dynamic>.from(decoded);
      } catch (_) {}
    }
    return <dynamic>[];
  }

  String? _extractSlug(dynamic item) {
    if (item is Map) {
      final idField = item['id'];
      if (idField is Map && idField['slug'] != null) {
        return idField['slug'].toString();
      } else if (idField is String && idField.isNotEmpty) {
        return idField;
      }
      if (item['name'] != null && item['name'].toString().isNotEmpty) {
        return item['name'].toString();
      }
    }
    return null;
  }

  bool _isRecordMalformed(dynamic item) {
    try {
      final map = Map<String, dynamic>.from(
          item is Map ? item : json.decode(item.toString()) as Map);
      CharacterDto.fromMap(map).toDomain();
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> _writeRawRosterToDisk(List<dynamic> rawList) async {
    try {
      await _db.put(
        AppDatabaseService.boxCharacters,
        _kSavedRosterKey,
        rawList,
      );
    } catch (e) {
      LoggingService().logWarning(
        'Failed to save characters roster to repository: $e',
        e,
      );
    }
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

  /// Saves the character roster to disk while preserving any unparsed/rejected records.
  @override
  Future<void> saveRoster(List<Character> roster) async {
    final rawRoster = _loadRawPersistedRoster();
    final newSlugs = roster.map((c) => c.id.slug).toSet();

    final preservedMalformed = <dynamic>[];
    for (final rawItem in rawRoster) {
      if (_isRecordMalformed(rawItem)) {
        final slug = _extractSlug(rawItem);
        if (slug == null || !newSlugs.contains(slug)) {
          preservedMalformed.add(rawItem);
        }
      }
    }

    final listMaps = <dynamic>[
      ...roster.map((c) => CharacterDto.fromDomain(c).toMap()),
      ...preservedMalformed,
    ];

    await _writeRawRosterToDisk(listMaps);
  }

  /// Saves or updates a single character in place without deleting unparsed records.
  @override
  Future<void> saveCharacter(Character character) async {
    final rawRoster = _loadRawPersistedRoster();
    final targetSlug = character.id.slug;
    int targetIndex = -1;

    for (var i = 0; i < rawRoster.length; i++) {
      final slug = _extractSlug(rawRoster[i]);
      if (slug == targetSlug || (slug == character.name)) {
        targetIndex = i;
        break;
      }
    }

    final charMap = CharacterDto.fromDomain(character).toMap();
    if (targetIndex >= 0) {
      rawRoster[targetIndex] = charMap;
    } else {
      rawRoster.add(charMap);
    }

    await _writeRawRosterToDisk(rawRoster);
  }

  /// Saves multiple characters in place without deleting unparsed records.
  @override
  Future<void> saveCharacters(List<Character> characters) async {
    final rawRoster = _loadRawPersistedRoster();
    for (final char in characters) {
      final targetSlug = char.id.slug;
      int targetIndex = -1;
      for (var i = 0; i < rawRoster.length; i++) {
        final slug = _extractSlug(rawRoster[i]);
        if (slug == targetSlug || (slug == char.name)) {
          targetIndex = i;
          break;
        }
      }
      final charMap = CharacterDto.fromDomain(char).toMap();
      if (targetIndex >= 0) {
        rawRoster[targetIndex] = charMap;
      } else {
        rawRoster.add(charMap);
      }
    }

    await _writeRawRosterToDisk(rawRoster);
  }

  /// Deletes a character by id/slug from the raw roster.
  @override
  Future<void> deleteCharacter(String characterId) async {
    final rawRoster = _loadRawPersistedRoster();
    rawRoster.removeWhere((item) {
      final slug = _extractSlug(item);
      return slug == characterId;
    });
    await _writeRawRosterToDisk(rawRoster);
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
