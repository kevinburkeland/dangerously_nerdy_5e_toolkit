import 'dart:convert';

import '../../logging_service.dart';
import 'homebrew_raw_payload_store.dart';

/// Generic typed persistence store for one category of homebrew entities.
class HomebrewCategoryStore<T> {
  final HomebrewRawPayloadStore rawStore;
  final String parsedKey;
  final String rawKey;
  final T Function(Map<String, dynamic>) fromMap;
  final Map<String, dynamic> Function(T) toMap;
  final String Function(T) getEntityKey;
  final String Function(T) getEntitySlug;
  final String corruptedReason;
  final String loadFailedReason;
  final bool Function(T)? isValid;
  final T Function(T existing, T incoming)? mergeOnReplace;

  const HomebrewCategoryStore({
    required this.rawStore,
    required this.parsedKey,
    required this.rawKey,
    required this.fromMap,
    required this.toMap,
    required this.getEntityKey,
    required this.getEntitySlug,
    required this.corruptedReason,
    required this.loadFailedReason,
    this.isValid,
    this.mergeOnReplace,
  });

  /// Loads and decodes all valid entries in this category.
  Future<List<T>> loadAll() async {
    try {
      final rawList = await rawStore.loadStringList(parsedKey);
      final items = <T>[];
      for (final jsonStr in rawList) {
        try {
          final entity =
              fromMap(Map<String, dynamic>.from(json.decode(jsonStr) as Map));
          if (isValid == null || isValid!(entity)) {
            items.add(entity);
          }
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: corruptedReason);
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: loadFailedReason);
      return [];
    }
  }

  /// Saves a single entity using list load-merge-save semantics, optionally storing [rawPayload].
  Future<void> save(
    T entity, {
    Map<String, dynamic>? rawPayload,
    bool Function(T existing, T incoming)? matchExisting,
    void Function(T)? onAfterSave,
  }) async {
    if (isValid != null && !isValid!(entity)) return;
    final items = await loadAll();
    final idx = items.indexWhere((existing) => matchExisting != null
        ? matchExisting(existing, entity)
        : getEntityKey(existing) == getEntityKey(entity));
    if (idx != -1) {
      items[idx] = entity;
    } else {
      items.add(entity);
    }
    await rawStore.saveStringList(
      parsedKey,
      items.map((e) => json.encode(toMap(e))).toList(),
    );
    if (rawPayload != null) {
      await rawStore.saveRawPayload(rawKey, getEntitySlug(entity), rawPayload);
    }
    onAfterSave?.call(entity);
  }

  /// Saves multiple entities using list load-merge-save (preserving custom merge rules).
  Future<void> saveBatchList(
    List<T> newEntities, {
    List<Map<String, dynamic>>? rawPayloads,
    void Function(T)? onEachInLoop,
  }) async {
    if (newEntities.isEmpty) return;
    final items = await loadAll();
    final slugIndex = <String, int>{
      for (int i = 0; i < items.length; i++) getEntityKey(items[i]): i,
    };
    for (int i = 0; i < newEntities.length; i++) {
      final entity = newEntities[i];
      final key = getEntityKey(entity);
      final idx = slugIndex[key];
      if (idx != null) {
        items[idx] = mergeOnReplace != null
            ? mergeOnReplace!(items[idx], entity)
            : entity;
      } else {
        slugIndex[key] = items.length;
        items.add(entity);
      }
      onEachInLoop?.call(entity);
    }
    await rawStore.saveStringList(
      parsedKey,
      items.map((e) => json.encode(toMap(e))).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newEntities.length && i < rawPayloads.length; i++) {
        payloadMap[getEntitySlug(newEntities[i])] = rawPayloads[i];
      }
      await rawStore.saveRawPayloadsBatch(rawKey, payloadMap);
    }
  }

  /// High-throughput batch persister that bypasses full entity deserialization.
  ///
  /// Reuses cached JSON strings and slug indexes to merge incoming entities into storage
  /// in O(N) time without decoding thousands of already-persisted entities into heap domain models.
  Future<void> saveBatchFast(
    List<T> newEntities, {
    List<Map<String, dynamic>>? rawPayloads,
    void Function(T)? onEntityAddedOrUpdated,
  }) async {
    final validEntities = isValid != null
        ? newEntities.where(isValid!).toList()
        : newEntities;
    if (validEntities.isEmpty) return;

    final rawList = await rawStore.loadStringList(parsedKey);
    Map<String, int> slugIndex;

    final cachedIndex = rawStore.categorySlugIndex[parsedKey];
    if (cachedIndex != null && cachedIndex.length == rawList.length) {
      slugIndex = cachedIndex;
    } else {
      slugIndex = <String, int>{};
      for (int i = 0; i < rawList.length; i++) {
        try {
          final decoded = json.decode(rawList[i]) as Map<String, dynamic>;
          final idObj = decoded['id'];
          final slug = idObj is Map
              ? (idObj['slug']?.toString() ?? '')
              : (decoded['slug']?.toString() ?? '');
          final ruleset = idObj is Map
              ? (idObj['ruleset']?.toString() ?? '')
              : (decoded['ruleset']?.toString() ?? '');
          if (slug.isNotEmpty) {
            slugIndex['${slug}_$ruleset'] = i;
          }
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Failed to index slug for item $i in category $parsedKey',
          );
        }
      }
      rawStore.categorySlugIndex[parsedKey] = slugIndex;
    }

    for (int i = 0; i < validEntities.length; i++) {
      final entity = validEntities[i];
      final key = getEntityKey(entity);
      final encoded = json.encode(toMap(entity));
      final idx = slugIndex[key];
      if (idx != null && idx < rawList.length) {
        rawList[idx] = encoded;
      } else {
        slugIndex[key] = rawList.length;
        rawList.add(encoded);
      }
      onEntityAddedOrUpdated?.call(entity);
    }

    await rawStore.saveStringList(parsedKey, rawList);
    rawStore.categorySlugIndex[parsedKey] = slugIndex;

    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < validEntities.length && i < rawPayloads.length; i++) {
        payloadMap[getEntitySlug(validEntities[i])] = rawPayloads[i];
      }
      await rawStore.saveRawPayloadsBatch(rawKey, payloadMap);
    }
  }

  /// Deletes entries matching [slug] (or custom [match]) and removes their raw payloads.
  Future<List<T>> delete(
    String slug, {
    bool invalidateCache = true,
    bool Function(T entity)? match,
    Future<void> Function(List<T> removed)? onRemoved,
  }) async {
    final items = await loadAll();
    final removed = <T>[];
    items.removeWhere((e) {
      final hits = match != null ? match(e) : getEntitySlug(e) == slug;
      if (hits) removed.add(e);
      return hits;
    });
    if (invalidateCache) {
      rawStore.invalidateCategoryCache(parsedKey, rawKey);
    }
    if (onRemoved != null) {
      await onRemoved(removed);
    }
    await rawStore.saveStringList(
      parsedKey,
      items.map((e) => json.encode(toMap(e))).toList(),
    );
    await rawStore.deleteRawPayload(rawKey, slug);
    return items;
  }

  /// Batch deletes multiple entities whose slug is in [slugSet].
  Future<int> deleteBatch(
    Set<String> slugSet, {
    void Function(String slug)? onSlugDeleted,
  }) async {
    final items = await loadAll();
    final initialLen = items.length;
    items.removeWhere((e) => slugSet.contains(getEntitySlug(e)));
    final count = initialLen - items.length;
    rawStore.invalidateCategoryCache(parsedKey, rawKey);
    await rawStore.saveStringList(
      parsedKey,
      items.map((e) => json.encode(toMap(e))).toList(),
    );
    for (final slug in slugSet) {
      await rawStore.deleteRawPayload(rawKey, slug);
      onSlugDeleted?.call(slug);
    }
    return count;
  }
}
