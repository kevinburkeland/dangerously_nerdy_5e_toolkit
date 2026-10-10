import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import '../../models/domain/character_models.dart';
import '../../services/logging_service.dart';
import '../rules/character_homebrew_validator.dart';
import '../rules/character_reparse_engine.dart';
import 'app_database_service.dart';

/// Persistence service for saving, loading, and deleting characters in local storage.
/// Implements [ICharacterRepository] for domain port compatibility.
class CharacterPersistenceService implements ICharacterRepository<Character> {
  static const String _kSavedRosterKey = 'saved_characters_roster_v1';
  static const String _kActiveCharacterIdKey = 'saved_active_character_id_v1';

  static final CharacterPersistenceService _instance =
      CharacterPersistenceService._internal();
  factory CharacterPersistenceService() => _instance;
  CharacterPersistenceService._internal();

  final AppDatabaseService _db = AppDatabaseService.instance;

  /// Loads all saved characters from local database.
  /// Automatically migrates legacy records from SharedPreferences if database is unseeded.
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
              roster.add(Character.fromMap(map));
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
            list.add(Character.fromMap(Map<String, dynamic>.from(item as Map)));
          } catch (e) {
            final identifier = item is Map
                ? (item['id']?['slug'] ?? item['id'] ?? item['name'] ?? 'index $i')
                : 'index $i';
            LoggingService().logWarning(
              'Corrupt legacy character record at $identifier could not be migrated: $e',
              e,
            );
          }
        }
        if (list.isNotEmpty) {
          // One-time migration into database - preserve full raw decoded roster including any unparsed entries
          await _writeRawRosterToDisk(decoded);
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
      Character.fromMap(map);
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

      // Best-effort sync to SharedPreferences for backwards compatibility
      try {
        final prefs = await SharedPreferences.getInstance();
        final encoded = json.encode(rawList);
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

  /// Saves the complete character roster to local database and syncs to SharedPreferences for safety.
  /// Preserves any previously rejected/malformed raw records so an unrelated save cannot destroy data.
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
      ...roster.map((c) => c.toMap()),
      ...preservedMalformed,
    ];
    await _writeRawRosterToDisk(listMaps);
  }

  /// Saves or updates a single character in the roster while preserving raw unparsed entries.
  @override
  Future<void> saveCharacter(Character character) async {
    var charToSave = character;
    if (charToSave.customProperties['usedHomebrew'] == null) {
      final deps =
          CharacterHomebrewValidator.collectHomebrewDependencies(charToSave);
      if (deps.isNotEmpty) {
        final updatedCp =
            Map<String, dynamic>.from(charToSave.customProperties);
        updatedCp['usedHomebrew'] = deps;
        charToSave = charToSave.copyWith(customProperties: updatedCp);
      }
    }

    final rawRoster = _loadRawPersistedRoster();
    final targetSlug = charToSave.id.slug;
    int targetIndex = -1;

    for (var i = 0; i < rawRoster.length; i++) {
      final slug = _extractSlug(rawRoster[i]);
      if (slug == targetSlug || (slug == charToSave.name)) {
        targetIndex = i;
        break;
      }
    }

    final charMap = charToSave.toMap();
    if (targetIndex >= 0) {
      rawRoster[targetIndex] = charMap;
    } else {
      rawRoster.add(charMap);
    }

    await _writeRawRosterToDisk(rawRoster);
  }

  /// Fetches characters matching the given IDs/slugs, preserving the order of the requested IDs.
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async {
    if (ids.isEmpty) return <Character>[];
    final all = await loadCharacters();
    final map = {for (final c in all) c.id.slug: c};
    return ids.map((id) => map[id]).whereType<Character>().toList();
  }

  /// Fetches a single character by ID/slug, or null if not found.
  @override
  Future<Character?> getCharacter(String id) async {
    final list = await getCharactersByIds([id]);
    return list.firstOrNull;
  }

  /// Saves multiple characters to persistence in bulk while preserving raw unparsed entries.
  @override
  Future<void> saveCharacters(List<Character> characters) async {
    if (characters.isEmpty) return;
    final rawRoster = _loadRawPersistedRoster();
    for (final charToSave in characters) {
      final targetSlug = charToSave.id.slug;
      int targetIndex = -1;
      for (var i = 0; i < rawRoster.length; i++) {
        final slug = _extractSlug(rawRoster[i]);
        if (slug == targetSlug || (slug == charToSave.name)) {
          targetIndex = i;
          break;
        }
      }
      final charMap = charToSave.toMap();
      if (targetIndex >= 0) {
        rawRoster[targetIndex] = charMap;
      } else {
        rawRoster.add(charMap);
      }
    }
    await _writeRawRosterToDisk(rawRoster);
  }

  /// Deletes a character by slug from the roster.
  @override
  Future<void> deleteCharacter(String characterSlug) async {
    final rawRoster = _loadRawPersistedRoster();
    rawRoster.removeWhere((item) {
      final slug = _extractSlug(item);
      return slug == characterSlug;
    });
    await _writeRawRosterToDisk(rawRoster);
  }

  /// Loads the active character ID.
  @override
  Future<String?> loadActiveCharacterId() async {
    try {
      final dbVal =
          _db.get(AppDatabaseService.boxCharacters, _kActiveCharacterIdKey);
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
  @override
  Future<void> saveActiveCharacterId(String slug) async {
    try {
      await _db.put(
          AppDatabaseService.boxCharacters, _kActiveCharacterIdKey, slug);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveCharacterIdKey, slug);
    } catch (e) {
      // Non-fatal
    }
  }

  /// Clears the active character ID.
  @override
  Future<void> clearActiveCharacterId() async {
    try {
      await _db.delete(
          AppDatabaseService.boxCharacters, _kActiveCharacterIdKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveCharacterIdKey);
    } catch (e) {
      // Non-fatal
    }
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
