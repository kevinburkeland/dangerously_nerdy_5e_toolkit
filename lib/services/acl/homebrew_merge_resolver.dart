import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/homebrew_bundle.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';

/// Disposition category for an incoming entity during bundle analysis.
enum ImportDisposition {
  novel, // Brand new entity (does not exist locally)
  identical, // Exactly identical to an existing local entity
  collision, // Shares an ID/slug with local entity, but content differs
}

/// Action to perform when a collision is detected.
enum CollisionResolution {
  overwrite, // Replace local version with incoming
  keepLocal, // Skip/discard incoming version
  duplicateRename, // Import incoming version under an incremented slug (e.g. slug-copy)
}

/// Analysis descriptor for a single incoming entity.
class ImportAnalysisItem<T extends DomainEntity> {
  final T incomingEntity;
  final T? localEntity;
  final ImportDisposition disposition;
  CollisionResolution resolution;
  bool isSelected;
  final String diffSummary;

  ImportAnalysisItem({
    required this.incomingEntity,
    this.localEntity,
    required this.disposition,
    this.resolution = CollisionResolution.overwrite,
    bool? isSelected,
    this.diffSummary = '',
  }) : isSelected = isSelected ?? (disposition != ImportDisposition.identical);

  String get displayName => incomingEntity.name;
  String get slug => incomingEntity.id.slug;
  EntityType get entityType => incomingEntity.entityType;
}

/// Comprehensive analysis result of analyzing an incoming HomebrewBundle against local libraries.
class ImportAnalysisResult {
  final List<ImportAnalysisItem<Spell>> spells;
  final List<ImportAnalysisItem<Monster>> monsters;
  final List<ImportAnalysisItem<EquipmentItem>> items;
  final List<ImportAnalysisItem<CharacterClass>> classes;
  final List<ImportAnalysisItem<Subclass>> subclasses;
  final List<ImportAnalysisItem<Race>> races;
  final List<ImportAnalysisItem<Feat>> feats;
  final List<ImportAnalysisItem<Background>> backgrounds;
  final List<ImportAnalysisItem<HomebrewCompendiumEntry>> otherEntries;
  final List<String> warnings;

  const ImportAnalysisResult({
    this.spells = const [],
    this.monsters = const [],
    this.items = const [],
    this.classes = const [],
    this.subclasses = const [],
    this.races = const [],
    this.feats = const [],
    this.backgrounds = const [],
    this.otherEntries = const [],
    this.warnings = const [],
  });

  List<ImportAnalysisItem<DomainEntity>> get allItems => [
        ...spells,
        ...monsters,
        ...items,
        ...classes,
        ...subclasses,
        ...races,
        ...feats,
        ...backgrounds,
        ...otherEntries,
      ];

  int get totalIncoming => allItems.length;
  int get novelCount => allItems.where((i) => i.disposition == ImportDisposition.novel).length;
  int get identicalCount => allItems.where((i) => i.disposition == ImportDisposition.identical).length;
  int get collisionCount => allItems.where((i) => i.disposition == ImportDisposition.collision).length;
  int get selectedCount => allItems.where((i) => i.isSelected).length;

  bool get hasCollisions => collisionCount > 0;
  bool get hasSelected => selectedCount > 0;
}

/// Deduplication & Conflict Detection Engine.
/// Compares incoming bundle entities against existing local storage records.
class HomebrewMergeResolver {
  const HomebrewMergeResolver();

  /// Analyzes an incoming [HomebrewBundle] against current local homebrew data collections.
  ImportAnalysisResult analyzeBundle({
    required HomebrewBundle incomingBundle,
    List<Spell> localSpells = const [],
    List<Monster> localMonsters = const [],
    List<EquipmentItem> localItems = const [],
    List<CharacterClass> localClasses = const [],
    List<Subclass> localSubclasses = const [],
    List<Race> localRaces = const [],
    List<Feat> localFeats = const [],
    List<Background> localBackgrounds = const [],
    List<HomebrewCompendiumEntry> localOtherEntries = const [],
  }) {
    final spellItems = _analyzeCategory<Spell>(
      incoming: incomingBundle.spells,
      local: localSpells,
    );

    final monsterItems = _analyzeCategory<Monster>(
      incoming: incomingBundle.monsters,
      local: localMonsters,
    );

    final equipmentItems = _analyzeCategory<EquipmentItem>(
      incoming: incomingBundle.items,
      local: localItems,
    );

    final classItems = _analyzeCategory<CharacterClass>(
      incoming: incomingBundle.classes,
      local: localClasses,
    );

    final subclassItems = _analyzeCategory<Subclass>(
      incoming: incomingBundle.subclasses,
      local: localSubclasses,
    );

    final raceItems = _analyzeCategory<Race>(
      incoming: incomingBundle.races,
      local: localRaces,
    );

    final featItems = _analyzeCategory<Feat>(
      incoming: incomingBundle.feats,
      local: localFeats,
    );

    final backgroundItems = _analyzeCategory<Background>(
      incoming: incomingBundle.backgrounds,
      local: localBackgrounds,
    );

    final otherItems = _analyzeCategory<HomebrewCompendiumEntry>(
      incoming: incomingBundle.otherEntries,
      local: localOtherEntries,
    );

    return ImportAnalysisResult(
      spells: spellItems,
      monsters: monsterItems,
      items: equipmentItems,
      classes: classItems,
      subclasses: subclassItems,
      races: raceItems,
      feats: featItems,
      backgrounds: backgroundItems,
      otherEntries: otherItems,
    );
  }

  List<ImportAnalysisItem<T>> _analyzeCategory<T extends DomainEntity>({
    required List<T> incoming,
    required List<T> local,
  }) {
    final results = <ImportAnalysisItem<T>>[];
    final localMap = <String, T>{};
    for (final l in local) {
      localMap['${l.id.slug}_${l.id.ruleset.name}'] = l;
    }

    for (final inc in incoming) {
      final key = '${inc.id.slug}_${inc.id.ruleset.name}';
      final existing = localMap[key];

      if (existing == null) {
        // Novel
        results.add(ImportAnalysisItem<T>(
          incomingEntity: inc,
          disposition: ImportDisposition.novel,
          resolution: CollisionResolution.overwrite,
          isSelected: true,
        ));
      } else {
        // Check if content matches identically
        final incJson = json.encode(inc.toMap());
        final localJson = json.encode(existing.toMap());

        if (incJson == localJson) {
          results.add(ImportAnalysisItem<T>(
            incomingEntity: inc,
            localEntity: existing,
            disposition: ImportDisposition.identical,
            resolution: CollisionResolution.keepLocal,
            isSelected: false,
            diffSummary: 'Identical match already in library.',
          ));
        } else {
          // Collision
          final diff = _generateDiffSummary(existing.toMap(), inc.toMap());
          results.add(ImportAnalysisItem<T>(
            incomingEntity: inc,
            localEntity: existing,
            disposition: ImportDisposition.collision,
            resolution: CollisionResolution.overwrite,
            isSelected: true,
            diffSummary: diff,
          ));
        }
      }
    }

    return results;
  }

  String _generateDiffSummary(Map<String, dynamic> local, Map<String, dynamic> incoming) {
    final changedKeys = <String>[];
    for (final key in incoming.keys) {
      if (key != 'id' && json.encode(local[key]) != json.encode(incoming[key])) {
        changedKeys.add(key);
      }
    }
    if (changedKeys.isEmpty) return 'Properties differ.';
    return 'Modified: ${changedKeys.take(4).join(', ')}${changedKeys.length > 4 ? ' (+${changedKeys.length - 4} more)' : ''}';
  }

  /// Generates a unique renamed slug when duplicate/rename is chosen.
  static String generateUniqueSlug(String baseSlug, Set<String> existingSlugs) {
    String candidate = '$baseSlug-copy';
    int counter = 2;
    while (existingSlugs.contains(candidate)) {
      candidate = '$baseSlug-copy-$counter';
      counter++;
    }
    return candidate;
  }
}
