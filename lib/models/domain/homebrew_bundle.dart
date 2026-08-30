import 'package:flutter/foundation.dart';
import 'homebrew_extended_entities.dart';
import 'spell_monster_equipment.dart';

/// Portable bundle envelope for sharing and transferring user-created homebrew entities.
@immutable
class HomebrewBundle {
  final int schemaVersion;
  final String appVersion;
  final DateTime exportedAt;
  final String? bundleName;
  final String? author;
  final String? description;
  final List<Spell> spells;
  final List<Monster> monsters;
  final List<EquipmentItem> items;
  final List<CharacterClass> classes;
  final List<Subclass> subclasses;
  final List<Race> races;
  final List<Feat> feats;
  final List<Background> backgrounds;
  final List<HomebrewCompendiumEntry> otherEntries;

  const HomebrewBundle({
    this.schemaVersion = 1,
    required this.appVersion,
    required this.exportedAt,
    this.bundleName,
    this.author,
    this.description,
    this.spells = const [],
    this.monsters = const [],
    this.items = const [],
    this.classes = const [],
    this.subclasses = const [],
    this.races = const [],
    this.feats = const [],
    this.backgrounds = const [],
    this.otherEntries = const [],
  });

  const HomebrewBundle.empty()
      : schemaVersion = 1,
        appVersion = '1.0.0',
        exportedAt = const _EpochDateTime(),
        bundleName = null,
        author = null,
        description = null,
        spells = const [],
        monsters = const [],
        items = const [],
        classes = const [],
        subclasses = const [],
        races = const [],
        feats = const [],
        backgrounds = const [],
        otherEntries = const [];

  int get totalCount =>
      spells.length +
      monsters.length +
      items.length +
      classes.length +
      subclasses.length +
      races.length +
      feats.length +
      backgrounds.length +
      otherEntries.length;

  bool get isEmpty => totalCount == 0;
  bool get isNotEmpty => totalCount > 0;

  Map<String, dynamic> toMap() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'exportedAt': exportedAt.toIso8601String(),
        if (bundleName != null) 'bundleName': bundleName,
        if (author != null) 'author': author,
        if (description != null) 'description': description,
        if (spells.isNotEmpty) 'spells': spells.map((s) => s.toMap()).toList(),
        if (monsters.isNotEmpty) 'monsters': monsters.map((m) => m.toMap()).toList(),
        if (items.isNotEmpty) 'items': items.map((i) => i.toMap()).toList(),
        if (classes.isNotEmpty) 'classes': classes.map((c) => c.toMap()).toList(),
        if (subclasses.isNotEmpty) 'subclasses': subclasses.map((s) => s.toMap()).toList(),
        if (races.isNotEmpty) 'races': races.map((r) => r.toMap()).toList(),
        if (feats.isNotEmpty) 'feats': feats.map((f) => f.toMap()).toList(),
        if (backgrounds.isNotEmpty) 'backgrounds': backgrounds.map((b) => b.toMap()).toList(),
        if (otherEntries.isNotEmpty)
          'otherEntries': otherEntries.map((o) => o.toMap()).toList(),
      };

  factory HomebrewBundle.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(map['exportedAt']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final spells = (map['spells'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Spell.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final monsters = (map['monsters'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Monster.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final items = (map['items'] as List? ?? [])
        .whereType<Map>()
        .map((m) => EquipmentItem.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final classes = (map['classes'] as List? ?? [])
        .whereType<Map>()
        .map((m) => CharacterClass.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final subclasses = (map['subclasses'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Subclass.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final races = (map['races'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Race.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final feats = (map['feats'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Feat.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final backgrounds = (map['backgrounds'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Background.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final otherEntries = (map['otherEntries'] as List? ?? [])
        .whereType<Map>()
        .map((m) => HomebrewCompendiumEntry.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    return HomebrewBundle(
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
      appVersion: map['appVersion']?.toString() ?? '1.0.0',
      exportedAt: parsedDate,
      bundleName: map['bundleName']?.toString(),
      author: map['author']?.toString(),
      description: map['description']?.toString(),
      spells: spells,
      monsters: monsters,
      items: items,
      classes: classes,
      subclasses: subclasses,
      races: races,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: otherEntries,
    );
  }

  HomebrewBundle copyWith({
    int? schemaVersion,
    String? appVersion,
    DateTime? exportedAt,
    String? bundleName,
    String? author,
    String? description,
    List<Spell>? spells,
    List<Monster>? monsters,
    List<EquipmentItem>? items,
    List<CharacterClass>? classes,
    List<Subclass>? subclasses,
    List<Race>? races,
    List<Feat>? feats,
    List<Background>? backgrounds,
    List<HomebrewCompendiumEntry>? otherEntries,
  }) {
    return HomebrewBundle(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      appVersion: appVersion ?? this.appVersion,
      exportedAt: exportedAt ?? this.exportedAt,
      bundleName: bundleName ?? this.bundleName,
      author: author ?? this.author,
      description: description ?? this.description,
      spells: spells ?? this.spells,
      monsters: monsters ?? this.monsters,
      items: items ?? this.items,
      classes: classes ?? this.classes,
      subclasses: subclasses ?? this.subclasses,
      races: races ?? this.races,
      feats: feats ?? this.feats,
      backgrounds: backgrounds ?? this.backgrounds,
      otherEntries: otherEntries ?? this.otherEntries,
    );
  }
}

class _EpochDateTime implements DateTime {
  const _EpochDateTime();
  @override
  int get millisecondsSinceEpoch => 0;
  @override
  int get microsecondsSinceEpoch => 0;
  @override
  bool isAfter(DateTime other) => false;
  @override
  bool isBefore(DateTime other) => true;
  @override
  bool isAtSameMomentAs(DateTime other) => other.millisecondsSinceEpoch == 0;
  @override
  int compareTo(DateTime other) => -1;
  @override
  DateTime add(Duration duration) => DateTime.fromMillisecondsSinceEpoch(0).add(duration);
  @override
  DateTime subtract(Duration duration) => DateTime.fromMillisecondsSinceEpoch(0).subtract(duration);
  @override
  Duration difference(DateTime other) => DateTime.fromMillisecondsSinceEpoch(0).difference(other);
  @override
  String toIso8601String() => '1970-01-01T00:00:00.000Z';
  @override
  DateTime toLocal() => DateTime.fromMillisecondsSinceEpoch(0).toLocal();
  @override
  DateTime toUtc() => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  @override
  String toString() => toIso8601String();
  @override
  int get year => 1970;
  @override
  int get month => 1;
  @override
  int get day => 1;
  @override
  int get hour => 0;
  @override
  int get minute => 0;
  @override
  int get second => 0;
  @override
  int get millisecond => 0;
  @override
  int get microsecond => 0;
  @override
  int get weekday => 4;
  @override
  String get timeZoneName => 'UTC';
  @override
  Duration get timeZoneOffset => Duration.zero;
  @override
  bool get isUtc => true;
}
