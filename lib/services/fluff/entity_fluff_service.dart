import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../persistence/debounced_storage_service.dart';

/// Container for rich lore, background description, and image URLs attached to a 5e entity.
@immutable
class EntityFluff {
  final String entityType; // 'monster', 'spell', 'item', 'class', 'feat', 'race', 'background'
  final String slug;
  final String loreMarkdown;
  final List<String> images;
  final String? source;

  const EntityFluff({
    required this.entityType,
    required this.slug,
    required this.loreMarkdown,
    this.images = const [],
    this.source,
  });

  Map<String, dynamic> toMap() => {
        'entityType': entityType,
        'slug': slug,
        'loreMarkdown': loreMarkdown,
        'images': images,
        if (source != null) 'source': source,
      };

  factory EntityFluff.fromMap(Map<String, dynamic> map) {
    return EntityFluff(
      entityType: map['entityType'] as String? ?? 'generic',
      slug: map['slug'] as String? ?? '',
      loreMarkdown: map['loreMarkdown'] as String? ?? '',
      images: (map['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      source: map['source'] as String?,
    );
  }
}

/// Central reactive service managing imported lore/fluff entries and user-generated custom notes
/// across all 5e entities (Monsters, Spells, Items, Classes, Feats, Races/Species).
class EntityFluffService extends ChangeNotifier {
  static final EntityFluffService _instance = EntityFluffService._internal();
  factory EntityFluffService() => _instance;
  EntityFluffService._internal();

  static const String _kFluffStorageKey = 'dangerously_nerdy_entity_fluff_v1';
  static const String _kUserNotesStorageKey = 'dangerously_nerdy_user_notes_v1';

  final Map<String, EntityFluff> _fluffRegistry = {};
  final Map<String, String> _userNotesRegistry = {};
  bool _isHydrated = false;

  bool get isHydrated => _isHydrated;

  String _buildKey(String entityType, String slug) =>
      '${entityType.toLowerCase().trim()}:${slug.toLowerCase().trim()}';

  /// Initializes and hydrates fluff and notes from local SharedPreferences
  Future<void> init() async {
    if (_isHydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawFluff = prefs.getString(_kFluffStorageKey);
      if (rawFluff != null && rawFluff.isNotEmpty) {
        final decoded = json.decode(rawFluff) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            _fluffRegistry[k] = EntityFluff.fromMap(v);
          } else if (v is Map) {
            _fluffRegistry[k] = EntityFluff.fromMap(Map<String, dynamic>.from(v));
          }
        });
      }

      final rawNotes = prefs.getString(_kUserNotesStorageKey);
      if (rawNotes != null && rawNotes.isNotEmpty) {
        final decoded = json.decode(rawNotes) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          if (v is String) {
            _userNotesRegistry[k] = v;
          }
        });
      }
      _isHydrated = true;
      notifyListeners();
    } catch (e) {
      debugPrint('EntityFluffService initialization error: $e');
      _isHydrated = true;
    }
  }

  /// Retrieves lore/fluff for a specific entity
  EntityFluff? getFluff(String entityType, String slug) {
    return _fluffRegistry[_buildKey(entityType, slug)];
  }

  /// Sets or merges lore/fluff for a specific entity
  void setFluff(
    String entityType,
    String slug,
    String loreMarkdown, {
    List<String>? images,
    String? source,
    bool saveToDisk = true,
  }) {
    final key = _buildKey(entityType, slug);
    final existing = _fluffRegistry[key];
    final updatedImages = images ?? existing?.images ?? const [];
    
    // If fluff already exists, combine or update lore
    final updatedLore = existing != null && existing.loreMarkdown.isNotEmpty && existing.loreMarkdown != loreMarkdown
        ? '${existing.loreMarkdown}\n\n$loreMarkdown'.trim()
        : loreMarkdown.trim();

    _fluffRegistry[key] = EntityFluff(
      entityType: entityType.toLowerCase().trim(),
      slug: slug.toLowerCase().trim(),
      loreMarkdown: updatedLore,
      images: updatedImages,
      source: source ?? existing?.source,
    );

    if (saveToDisk) {
      _persistFluff();
    }
    notifyListeners();
  }

  /// Bulk register fluff items (e.g. from JSON ingestion pipeline)
  void batchRegisterFluff(List<EntityFluff> items, {bool saveToDisk = true}) {
    for (final item in items) {
      final key = _buildKey(item.entityType, item.slug);
      final existing = _fluffRegistry[key];
      if (existing == null) {
        _fluffRegistry[key] = item;
      } else {
        final combinedLore = existing.loreMarkdown.isNotEmpty && existing.loreMarkdown != item.loreMarkdown
            ? '${existing.loreMarkdown}\n\n${item.loreMarkdown}'.trim()
            : (item.loreMarkdown.isNotEmpty ? item.loreMarkdown : existing.loreMarkdown);
        _fluffRegistry[key] = EntityFluff(
          entityType: item.entityType,
          slug: item.slug,
          loreMarkdown: combinedLore,
          images: {...existing.images, ...item.images}.toList(),
          source: item.source ?? existing.source,
        );
      }
    }
    if (saveToDisk) {
      _persistFluff();
    }
    notifyListeners();
  }

  /// Retrieves user-authored custom notes for an entity
  String? getUserNotes(String entityType, String slug) {
    return _userNotesRegistry[_buildKey(entityType, slug)];
  }

  /// Updates user-authored custom notes for an entity
  void setUserNotes(String entityType, String slug, String notes, {bool saveToDisk = true}) {
    final key = _buildKey(entityType, slug);
    final trimmed = notes.trim();
    if (trimmed.isEmpty) {
      _userNotesRegistry.remove(key);
    } else {
      _userNotesRegistry[key] = trimmed;
    }

    if (saveToDisk) {
      _persistUserNotes();
    }
    notifyListeners();
  }

  /// Clears all user notes and imported fluff (e.g. on factory reset)
  void clearAll() {
    _fluffRegistry.clear();
    _userNotesRegistry.clear();
    _persistFluff();
    _persistUserNotes();
    notifyListeners();
  }

  /// Serializes all fluff to JSON Map for backup exports
  Map<String, dynamic> exportFluffMap() {
    return _fluffRegistry.map((k, v) => MapEntry(k, v.toMap()));
  }

  /// Serializes all user notes to JSON Map for backup exports
  Map<String, String> exportUserNotesMap() {
    return Map<String, String>.from(_userNotesRegistry);
  }

  /// Imports and hydrates fluff and user notes from backup payloads
  void importFromBackup({
    Map<String, dynamic>? fluffData,
    Map<String, dynamic>? userNotesData,
  }) {
    if (fluffData != null) {
      fluffData.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          _fluffRegistry[k] = EntityFluff.fromMap(v);
        } else if (v is Map) {
          _fluffRegistry[k] = EntityFluff.fromMap(Map<String, dynamic>.from(v));
        }
      });
      _persistFluff();
    }

    if (userNotesData != null) {
      userNotesData.forEach((k, v) {
        if (v is String && v.trim().isNotEmpty) {
          _userNotesRegistry[k] = v.trim();
        }
      });
      _persistUserNotes();
    }
    notifyListeners();
  }

  void _persistFluff() {
    DebouncedStorageService().scheduleWrite(_kFluffStorageKey, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFluffStorageKey, json.encode(exportFluffMap()));
    });
  }

  void _persistUserNotes() {
    DebouncedStorageService().scheduleWrite(_kUserNotesStorageKey, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserNotesStorageKey, json.encode(_userNotesRegistry));
    });
  }
}
