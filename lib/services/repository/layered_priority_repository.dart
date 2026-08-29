import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';

/// Priority tier enumeration for deterministic evaluation order.
enum LayerPriority {
  campaignOverrides(100),
  homebrewPacks(200),
  baseRuleset(300);

  final int rank;
  const LayerPriority(this.rank);
}

/// A discrete priority layer containing fully hydrated domain objects.
class PriorityLayer {
  final String layerId;
  final String name;
  final LayerPriority priority;
  bool isActive;
  final Map<String, DomainEntity> _entities = {};

  PriorityLayer({
    required this.layerId,
    required this.name,
    required this.priority,
    this.isActive = true,
  });

  static String buildKey(EntityType type, String slug) => '${type.name}:$slug';

  void registerEntity(DomainEntity entity) {
    _entities[buildKey(entity.entityType, entity.slug)] = entity;
  }

  void removeEntity(EntityType type, String slug) {
    _entities.remove(buildKey(type, slug));
  }

  DomainEntity? get(String slug, {EntityType? type}) {
    if (type != null) {
      return _entities[buildKey(type, slug)];
    }
    for (final key in _entities.keys) {
      if (key.endsWith(':$slug')) {
        return _entities[key];
      }
    }
    return null;
  }

  bool contains(String slug, {EntityType? type}) {
    if (type != null) {
      return _entities.containsKey(buildKey(type, slug));
    }
    return _entities.keys.any((k) => k.endsWith(':$slug'));
  }

  List<DomainEntity> getAll() => _entities.values.toList();
}

/// Repository managing the layered evaluation stack.
class LayeredPriorityRepository {
  final List<PriorityLayer> _layers = [];

  List<PriorityLayer> get layers => List.unmodifiable(_layers);

  void addLayer(PriorityLayer layer) {
    _layers.add(layer);
    _sortLayers();
  }

  void removeLayer(String layerId) {
    _layers.removeWhere((l) => l.layerId == layerId);
  }

  void setLayerActive(String layerId, bool isActive) {
    final idx = _layers.indexWhere((l) => l.layerId == layerId);
    if (idx != -1) {
      _layers[idx].isActive = isActive;
    }
  }

  void _sortLayers() {
    _layers.sort((a, b) => a.priority.rank.compareTo(b.priority.rank));
  }

  EntityType? _inferEntityType<T extends DomainEntity>() {
    if (T == Spell) return EntityType.spell;
    if (T == Monster) return EntityType.monster;
    if (T == EquipmentItem) return EntityType.equipment;
    return null;
  }

  /// Top-to-bottom lookup across active priority layers.
  T? lookup<T extends DomainEntity>(
    String slug, {
    EntityType? type,
    RulesetVersion? preferredRuleset,
  }) {
    final effectiveType = type ?? _inferEntityType<T>();
    for (final layer in _layers) {
      if (!layer.isActive) continue;

      final candidate = layer.get(slug, type: effectiveType);
      if (candidate != null && candidate is T) {
        if (preferredRuleset != null && layer.priority == LayerPriority.baseRuleset) {
          if (candidate.ruleset == preferredRuleset) {
            return candidate;
          }
          continue;
        }
        return candidate;
      }
    }
    return null;
  }

  /// Saves a complete domain record clone (Copy-on-Write) into a designated layer.
  void saveOverride(String layerId, DomainEntity entity) {
    final layer = _layers.firstWhere(
      (l) => l.layerId == layerId,
      orElse: () => throw ArgumentError('Layer $layerId not found in repository stack'),
    );
    layer.registerEntity(entity);
  }
}
