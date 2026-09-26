import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:vtt_engine_core/homebrew/ports/i_github_ingestor_port.dart';
import 'package:vtt_engine_core/homebrew/value_objects/github_repo_source.dart';
import 'package:vtt_engine_core/homebrew/value_objects/ruleset_version.dart';
import '../../../services/acl/compendium_class_parser.dart';
import '../../../services/acl/generic_tag_scrubber.dart';
import '../../dtos/homebrew_entity_dto.dart';
import 'http_fetcher.dart';

/// Concrete adapter fulfilling [IGithubIngestorPort] for GitHub homebrew repositories.
///
/// Handles tree discovery, bounded concurrency downloads (default 1 sequential connection for memory stability),
/// platform-specific isolate/microtask offloading, and ACL schema enforcement.
class GithubIngestorAdapter implements IGithubIngestorPort {
  static const int defaultMaxConcurrentDownloads = 1;
  static const int maxConcurrentDownloads = 1; // Backwards compatibility

  /// Pure Dart detection of JavaScript/Web compilation without flutter/foundation.dart.
  static const bool _isWeb = identical(0, 0.0);

  /// Payloads smaller than this threshold (64 KB) are parsed directly on the event loop
  /// to avoid Isolate spawn, memory copy, and port transfer overhead.
  static const int isolateThresholdBytes = 64 * 1024;

  /// Default chunk size for yielding during payload streaming to prevent UI frame starvation.
  static const int defaultStreamChunkSize = 25;

  final HttpFetchClient _client;
  final bool _useIsolate;
  final int streamChunkSize;
  final int concurrentDownloads;

  GithubIngestorAdapter({
    HttpFetchClient? client,
    bool useIsolate = true,
    this.streamChunkSize = defaultStreamChunkSize,
    int maxConcurrentDownloads = defaultMaxConcurrentDownloads,
  })  : _client = client ?? HttpFetchClient(),
        _useIsolate = useIsolate,
        concurrentDownloads = maxConcurrentDownloads;

  @override
  Future<List<String>> discoverJsonManifest(GithubRepoSource source) async {
    String responseBody;
    var effectiveSource = source;

    try {
      responseBody = await _client.get(source.apiTreeUri);
    } on HttpFetchException catch (e) {
      // If default 'main' branch returned 404, automatically attempt fallback to 'master'
      if (source.branch == 'main' && e.statusCode == 404) {
        final masterSource = GithubRepoSource(
          owner: source.owner,
          repo: source.repo,
          branch: 'master',
        );
        try {
          responseBody = await _client.get(masterSource.apiTreeUri);
          effectiveSource = masterSource;
        } catch (_) {
          rethrow;
        }
      } else {
        rethrow;
      }
    } catch (_) {
      rethrow;
    }

    final Map<String, dynamic> treeData;
    try {
      treeData = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException(
          'Failed to decode GitHub Git Tree API response: $e');
    }

    final treeList = treeData['tree'];
    if (treeList is! List) {
      throw const FormatException(
          'GitHub Git Tree response missing "tree" array.');
    }

    final rawUrls = <String>[];
    for (final item in treeList) {
      if (item is Map) {
        final path = item['path']?.toString();
        if (path != null && path.toLowerCase().endsWith('.json')) {
          final lower = path.toLowerCase();
          // Filter out obvious package manifests, build tooling, VTT duplicates, index maps, and narrative book prose
          if (lower.endsWith('package.json') ||
              lower.endsWith('package-lock.json') ||
              lower.endsWith('tsconfig.json') ||
              lower.endsWith('.eslintrc.json') ||
              lower.contains('.github/') ||
              lower.contains('/.git/') ||
              lower.contains('foundry') ||
              lower.endsWith('index.json') ||
              lower.endsWith('fluff-index.json') ||
              lower.endsWith('sources.json') ||
              lower.endsWith('cr-index.json') ||
              lower.endsWith('template.json') ||
              lower.endsWith('changelog.json') ||
              lower.endsWith('converter.json') ||
              lower.endsWith('encounterbuilder.json') ||
              lower.endsWith('encounters.json') ||
              lower.contains('makebrew') ||
              lower.endsWith('makecards.json') ||
              lower.endsWith('renderdemo.json') ||
              lower.endsWith('msbcr.json') ||
              lower.contains('gendata-spell-source-lookup') ||
              lower.contains('gendata-subclass-lookup') ||
              lower.contains('gendata-nav-adventure-book-index') ||
              lower.contains('gendata-maps') ||
              lower.contains('bookref-') ||
              lower.contains('/book/book-') ||
              lower.contains('/adventure/adventure-') ||
              lower.endsWith('books.json') ||
              lower.endsWith('adventures.json') ||
              lower.endsWith('recipes.json') ||
              lower.endsWith('recipe.json') ||
              lower.contains('recipe')) {
            continue;
          }
          rawUrls.add(effectiveSource.rawFileUri(path).toString());
        }
      }
    }

    return rawUrls;
  }

  @override
  Stream<IngestionResult> ingestPayloadStream({
    required List<String> rawUrls,
    required RulesetVersion ruleset,
  }) {
    final controller = StreamController<IngestionResult>();

    // Execute concurrently with a bounded worker pool
    scheduleMicrotask(() async {
      try {
        await _processBoundedPool(rawUrls, ruleset, controller);
      } catch (e, st) {
        controller.addError(e, st);
      } finally {
        await controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _processBoundedPool(
    List<String> urls,
    RulesetVersion ruleset,
    StreamController<IngestionResult> controller,
  ) async {
    if (urls.isEmpty) return;

    var index = 0;
    final total = urls.length;

    Future<void> worker() async {
      while (true) {
        final currentIndex = index++;
        if (currentIndex >= total) break;

        final url = urls[currentIndex];
        final results = await _fetchAndParse(url, ruleset);
        if (!controller.isClosed) {
          for (var i = 0; i < results.length; i++) {
            if (controller.isClosed) break;
            controller.add(results[i]);
            if ((i + 1) % streamChunkSize == 0 && (i + 1) < results.length) {
              await Future<void>.delayed(Duration.zero);
            }
          }
        }
        // Yield to event loop between files so garbage collection and frame rendering run
        await Future<void>.delayed(Duration.zero);
      }
    }

    final workersCount =
        urls.length < concurrentDownloads ? urls.length : concurrentDownloads;
    final workers = List.generate(workersCount, (_) => worker());
    await Future.wait(workers);
  }

  Future<List<IngestionResult>> _fetchAndParse(
    String url,
    RulesetVersion ruleset,
  ) async {
    String rawContent;
    try {
      rawContent = await _client.get(Uri.parse(url));
    } catch (e) {
      final reason =
          e is HttpFetchException ? e.message : 'HTTP download failure: $e';
      return [
        IngestionSkipResult(
          sourceUrl: url,
          reason: reason,
          errorDetails: e.toString(),
          ruleset: ruleset,
        )
      ];
    }

    try {
      return await _executeParsing(rawContent, ruleset, url);
    } catch (e) {
      return [
        IngestionSkipResult(
          sourceUrl: url,
          reason: 'Malformed or invalid JSON schema: $e',
          errorDetails: e.toString(),
          ruleset: ruleset,
        )
      ];
    }
  }

  Future<List<IngestionResult>> _executeParsing(
    String jsonString,
    RulesetVersion ruleset,
    String url,
  ) async {
    if (!_isWeb && _useIsolate && jsonString.length >= isolateThresholdBytes) {
      try {
        return await Isolate.run(
            () => _unpackAndParsePayload(jsonString, ruleset, url));
      } on UnsupportedError {
        return _parseInMicrotask(jsonString, ruleset, url);
      }
    } else {
      return _parseInMicrotask(jsonString, ruleset, url);
    }
  }

  Future<List<IngestionResult>> _parseInMicrotask(
    String jsonString,
    RulesetVersion ruleset,
    String url,
  ) async {
    final completer = Completer<List<IngestionResult>>();
    scheduleMicrotask(() {
      try {
        final results = _unpackAndParsePayload(jsonString, ruleset, url);
        completer.complete(results);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static const _genericWrapperKeys = {
    'data',
    'content',
    'items',
    'entries',
    'results',
    'entities',
    'values',
    'records',
    'objects',
    'payload',
    'list',
    'root',
    'collection',
  };

  static List<IngestionResult> _unpackAndParsePayload(
    String jsonString,
    RulesetVersion ruleset,
    String url,
  ) {
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      return [
        IngestionSkipResult(
          sourceUrl: url,
          reason: 'Malformed JSON syntax: $e',
          errorDetails: e.toString(),
          ruleset: ruleset,
        )
      ];
    }

    // 1. Root is a JSON Array of entities
    if (decoded is List) {
      final results = <IngestionResult>[];
      final localCache = <String, dynamic>{};
      final rawItems = <Map<String, dynamic>>[];

      // Pass 1: Collect items into localCache
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is Map) {
          final entityMap = Map<String, dynamic>.from(item);
          final entityName =
              (entityMap['name'] ?? entityMap['title'] ?? 'item_$i').toString();
          final itemUrl = '$url#item_${i}_$entityName';
          localCache[itemUrl] = entityMap;
          final id =
              entityMap['id']?.toString() ?? entityMap['slug']?.toString();
          if (id != null) localCache[id] = entityMap;
          localCache[entityName.toLowerCase()] = entityMap;
          rawItems.add(entityMap);
        }
      }

      // Pass 2: Resolve $ref pointers and parse
      for (var i = 0; i < rawItems.length; i++) {
        final entityMap = rawItems[i];
        final resolved =
            _resolveRefs(entityMap, localCache, <String, dynamic>{});
        final finalMap =
            resolved is Map<String, dynamic> ? resolved : entityMap;
        final entityName =
            (finalMap['name'] ?? finalMap['title'] ?? 'item_$i').toString();
        final itemUrl = '$url#item_${i}_$entityName';
        results.add(_parseEntityMap(finalMap, ruleset, itemUrl));
      }

      if (results.isEmpty) {
        return [
          IngestionSkipResult(
            sourceUrl: url,
            reason: 'JSON array contains no entity objects',
            ruleset: ruleset,
          )
        ];
      }
      return results;
    }

    // 2. Root is a JSON Map (Bundle, Container, or Single Entity)
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      // =====================================================================
      // Two-Pass Linker: Pass 1 - In-Memory Cache Population (Definitions)
      // =====================================================================
      final localCache = <String, dynamic>{};

      void indexDefinitions(dynamic defsNode, String prefix) {
        if (defsNode is Map) {
          for (final entry in defsNode.entries) {
            final key = entry.key.toString();
            final val = entry.value;
            localCache['$prefix/$key'] = val;
            localCache[key] = val;
            localCache['#$key'] = val;
            localCache['#/$prefix/$key'] = val;
          }
        }
      }

      if (map['definitions'] != null)
        indexDefinitions(map['definitions'], 'definitions');
      if (map[r'$defs'] != null) indexDefinitions(map[r'$defs'], r'$defs');
      if (map['components'] != null)
        indexDefinitions(map['components'], 'components');

      // Structural Anti-Corruption Layer (ACL): recursively collect features and entities
      final rawClassFeatures = <Map<String, dynamic>>[];
      final rawSubclassFeatures = <Map<String, dynamic>>[];
      final discoveredEntities = <_DiscoveredEntity>[];

      void collectFeaturesAndEntities(dynamic node, String path,
          {String? parentKey}) {
        if (node == null) return;

        if (node is List) {
          for (var i = 0; i < node.length; i++) {
            final item = node[i];
            if (item is Map) {
              final entityMap = Map<String, dynamic>.from(item);
              final itemName =
                  (entityMap['name'] ?? entityMap['title'] ?? 'item_$i')
                      .toString();
              final itemPath = '$path#$itemName';

              // Inspect if this item is a class/subclass feature
              final isFeature = _isFeatureDeclaration(entityMap);
              if (isFeature) {
                final isSubclass =
                    _isSubclassFeature(entityMap, parentKey: parentKey);
                if (isSubclass) {
                  rawSubclassFeatures.add(entityMap);
                } else {
                  rawClassFeatures.add(entityMap);
                }
              }

              // Evaluate if item is a tabletop entity
              if (_isTabletopEntity(entityMap,
                  parentKey: parentKey, rootDoc: map)) {
                final effectiveCategoryHint = (parentKey != null &&
                        !_genericWrapperKeys
                            .contains(parentKey.toLowerCase().trim()))
                    ? parentKey
                    : null;
                discoveredEntities.add(_DiscoveredEntity(
                  data: entityMap,
                  path: itemPath,
                  categoryHint: effectiveCategoryHint,
                ));
              } else {
                // If it's a wrapper object, traverse deeper
                collectFeaturesAndEntities(entityMap, itemPath,
                    parentKey: parentKey);
              }
            } else if (item is List) {
              collectFeaturesAndEntities(item, '$path/[$i]',
                  parentKey: parentKey);
            }
          }
        } else if (node is Map) {
          final m = Map<String, dynamic>.from(node);

          var hasChildCollections = false;
          for (final entry in m.entries) {
            final k = entry.key.toLowerCase().trim();
            if (k == '_meta' || k == r'$schema' || k == 'sources') continue;
            if (entry.value is List && (entry.value as List).isNotEmpty) {
              hasChildCollections = true;
              collectFeaturesAndEntities(entry.value, '$path/${entry.key}',
                  parentKey: entry.key);
            } else if (entry.value is Map && (entry.value as Map).isNotEmpty) {
              final subMap = entry.value as Map;
              if (subMap.values.any((v) => v is Map || v is List)) {
                hasChildCollections = true;
                collectFeaturesAndEntities(entry.value, '$path/${entry.key}',
                    parentKey: entry.key);
              }
            }
          }

          // Standalone entity check
          if (!hasChildCollections &&
              _isTabletopEntity(m, parentKey: parentKey, rootDoc: map)) {
            final entityName =
                (m['name'] ?? m['title'] ?? m['label'] ?? m['header'] ?? '')
                    .toString()
                    .trim();
            if (entityName.isNotEmpty) {
              final effectiveCategoryHint = (parentKey != null &&
                      !_genericWrapperKeys
                          .contains(parentKey.toLowerCase().trim()))
                  ? parentKey
                  : null;
              discoveredEntities.add(_DiscoveredEntity(
                data: m,
                path: path,
                categoryHint: effectiveCategoryHint,
              ));
            }
          }
        }
      }

      collectFeaturesAndEntities(map, url);

      if (discoveredEntities.isNotEmpty) {
        for (final entity in discoveredEntities) {
          localCache[entity.path] = entity.data;
          final id = entity.data['id']?.toString();
          if (id != null && id.isNotEmpty) {
            localCache[id] = entity.data;
            localCache['#$id'] = entity.data;
          }
          final slug = entity.data['slug']?.toString();
          if (slug != null && slug.isNotEmpty) {
            localCache[slug] = entity.data;
            localCache['#$slug'] = entity.data;
          }
          final name = entity.data['name']?.toString().toLowerCase().trim();
          if (name != null && name.isNotEmpty) {
            localCache[name] = entity.data;
            localCache['#$name'] = entity.data;
          }
        }

        for (final feat in rawClassFeatures) {
          final name = feat['name']?.toString().toLowerCase().trim();
          if (name != null && name.isNotEmpty) {
            localCache[name] = feat;
            localCache['#$name'] = feat;
          }
        }
        for (final feat in rawSubclassFeatures) {
          final name = feat['name']?.toString().toLowerCase().trim();
          if (name != null && name.isNotEmpty) {
            localCache[name] = feat;
            localCache['#$name'] = feat;
          }
        }

        // =====================================================================
        // Two-Pass Linker: Pass 2 - Resolve local $ref pointers across cache
        // =====================================================================
        if (localCache.isNotEmpty) {
          for (final entity in discoveredEntities) {
            final resolved = _resolveRefs(entity.data, localCache, map);
            if (resolved is Map<String, dynamic> &&
                !identical(resolved, entity.data)) {
              entity.data.clear();
              entity.data.addAll(resolved);
            }
          }

          for (var i = 0; i < rawClassFeatures.length; i++) {
            final resolved = _resolveRefs(rawClassFeatures[i], localCache, map);
            if (resolved is Map<String, dynamic> &&
                !identical(resolved, rawClassFeatures[i])) {
              rawClassFeatures[i] = resolved;
            }
          }
          for (var i = 0; i < rawSubclassFeatures.length; i++) {
            final resolved =
                _resolveRefs(rawSubclassFeatures[i], localCache, map);
            if (resolved is Map<String, dynamic> &&
                !identical(resolved, rawSubclassFeatures[i])) {
              rawSubclassFeatures[i] = resolved;
            }
          }
        }

        final classFeatureMap = _buildClassFeatureMap(rawClassFeatures);
        final subclassFeatureMap =
            _buildSubclassFeatureMap(rawSubclassFeatures);

        final results = <IngestionResult>[];
        for (final entity in discoveredEntities) {
          final entityMap = entity.data;

          // Robust dynamic category inference
          final inferredCategory = _inferEntityType(entityMap,
              categoryHint: entity.categoryHint, rootDoc: map);
          final category = (inferredCategory ??
                  entity.categoryHint ??
                  entityMap['entityType'] ??
                  '')
              .toString()
              .toLowerCase();

          if (!entityMap.containsKey('entityType') &&
              inferredCategory != null) {
            entityMap['entityType'] = inferredCategory;
          }

          // Pre-stitch subclass features and grants if available in current bundle
          if ((category == 'subclass' || category == 'subclasses') &&
              subclassFeatureMap != null) {
            final parsedSub = CompendiumClassParser().parseSubclass(
              entityMap,
              subclassFeatureMap: subclassFeatureMap,
            );
            if (parsedSub.featuresMarkdown.isNotEmpty &&
                !parsedSub.featuresMarkdown
                    .contains('Feature*\n\nGranted at level')) {
              entityMap['featuresMarkdown'] = parsedSub.featuresMarkdown;
            }
            if (parsedSub.grants.isNotEmpty) {
              entityMap['grants'] =
                  parsedSub.grants.map((g) => g.toMap()).toList();
            }
          } else if ((category == 'class' || category == 'classes') &&
              (classFeatureMap != null || subclassFeatureMap != null)) {
            final parsedCls = CompendiumClassParser().parseClass(
              entityMap,
              classFeatureMap: classFeatureMap,
              subclassFeatureMap: subclassFeatureMap,
            );
            if (parsedCls.featuresMarkdown.isNotEmpty) {
              entityMap['featuresMarkdown'] = parsedCls.featuresMarkdown;
            }
          }

          results.add(_parseEntityMap(entityMap, ruleset, entity.path));
        }
        return results;
      }

      // Single entity check (fallback)
      final rawName =
          (map['name'] ?? map['title'] ?? map['label'] ?? map['header'])
              ?.toString()
              .trim();
      if (rawName != null &&
          rawName.isNotEmpty &&
          _isTabletopEntity(map, rootDoc: map)) {
        final resolved = _resolveRefs(map, localCache, map);
        final finalMap = resolved is Map<String, dynamic> ? resolved : map;
        return [_parseEntityMap(finalMap, ruleset, url)];
      }

      // No entity arrays and no entity name -> repository metadata
      return [
        IngestionSkipResult(
          sourceUrl: url,
          reason:
              'Repository metadata or index file (no tabletop entities found)',
          ruleset: ruleset,
        )
      ];
    }

    return [
      IngestionSkipResult(
        sourceUrl: url,
        reason: 'Root payload must be a JSON object or array',
        ruleset: ruleset,
      )
    ];
  }

  static IngestionResult _parseEntityMap(
    Map<String, dynamic> entityMap,
    RulesetVersion ruleset,
    String itemUrl,
  ) {
    try {
      // Generic inline tag sanitization applied to all string values before DTO construction
      final scrubbedMap = GenericTagScrubber.scrubMap(entityMap);
      final dto = HomebrewEntityDto.fromJson(
        scrubbedMap,
        ruleset: ruleset,
        sourcePath: itemUrl,
      );
      return IngestionSuccessResult(
        entity: dto.toDomain(),
        sourceUrl: itemUrl,
        ruleset: ruleset,
      );
    } on HomebrewValidationException catch (e) {
      return IngestionSkipResult(
        sourceUrl: itemUrl,
        reason: e.message,
        errorDetails: e.toString(),
        ruleset: ruleset,
      );
    } catch (e) {
      return IngestionSkipResult(
        sourceUrl: itemUrl,
        reason: 'Malformed or invalid entity schema: $e',
        errorDetails: e.toString(),
        ruleset: ruleset,
      );
    }
  }

  /// Traverses a node and resolves all `$ref` / `ref` pointers against the in-memory cache and root document.
  ///
  /// Uses copy-on-write semantics: returns [node] unmodified if no pointers are present or changed.
  static dynamic _resolveRefs(
    dynamic node,
    Map<String, dynamic> localCache,
    Map<String, dynamic> rootDoc, {
    Set<String>? visiting,
  }) {
    if (localCache.isEmpty || node == null) return node;

    if (node is List) {
      List<dynamic>? resolvedList;
      for (var i = 0; i < node.length; i++) {
        final item = node[i];
        final resolved =
            _resolveRefs(item, localCache, rootDoc, visiting: visiting);
        if (!identical(resolved, item)) {
          resolvedList ??= List<dynamic>.from(node);
          resolvedList[i] = resolved;
        } else if (resolvedList != null) {
          resolvedList[i] = resolved;
        }
      }
      return resolvedList ?? node;
    }

    if (node is Map) {
      final refVal = node[r'$ref'] ?? node['ref'];

      if (refVal is String && refVal.isNotEmpty) {
        final refKey = refVal.trim();
        final visited =
            visiting != null ? Set<String>.from(visiting) : <String>{};

        if (!visited.contains(refKey)) {
          visited.add(refKey);

          dynamic target = localCache[refKey] ??
              localCache[refKey.toLowerCase()] ??
              localCache[
                  refKey.startsWith('#') ? refKey.substring(1) : '#$refKey'] ??
              _resolveJsonPointer(rootDoc, refKey);

          if (target is Map) {
            final resolvedTarget = _resolveRefs(
              Map<String, dynamic>.from(target),
              localCache,
              rootDoc,
              visiting: visited,
            );
            if (resolvedTarget is Map) {
              final merged = Map<String, dynamic>.from(resolvedTarget);
              node.forEach((k, v) {
                if (k != r'$ref' && k != 'ref') {
                  merged[k] =
                      _resolveRefs(v, localCache, rootDoc, visiting: visited);
                }
              });
              return merged;
            }
          }
        }
      }

      var changed = false;
      final resolvedMap = <String, dynamic>{};
      for (final entry in node.entries) {
        final k = entry.key.toString();
        final v = entry.value;
        final resolvedV =
            _resolveRefs(v, localCache, rootDoc, visiting: visiting);
        if (!identical(resolvedV, v)) {
          changed = true;
        }
        resolvedMap[k] = resolvedV;
      }
      return changed ? resolvedMap : node;
    }

    return node;
  }

  static dynamic _resolveJsonPointer(
      Map<String, dynamic> root, String pointer) {
    if (!pointer.startsWith('#/')) return null;
    final segments = pointer
        .substring(2)
        .split('/')
        .map((s) => s.replaceAll('~1', '/').replaceAll('~0', '~'))
        .toList();
    dynamic current = root;
    for (final seg in segments) {
      if (current is Map && current.containsKey(seg)) {
        current = current[seg];
      } else if (current is List) {
        final idx = int.tryParse(seg);
        if (idx != null && idx >= 0 && idx < current.length) {
          current = current[idx];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return current;
  }

  static Map<String, Map<String, dynamic>>? _buildClassFeatureMap(
      List<Map<String, dynamic>> rawClassFeatures) {
    if (rawClassFeatures.isEmpty) return null;
    final classFeatureMap = <String, Map<String, dynamic>>{};
    for (final feat in rawClassFeatures) {
      final name = feat['name']?.toString().toLowerCase().trim() ?? '';
      final className =
          (feat['className']?.toString() ?? feat['class']?.toString() ?? '')
              .toLowerCase()
              .trim();
      final source = (feat['source']?.toString() ?? '').toLowerCase().trim();
      final level = (feat['level']?.toString() ?? '').trim();

      if (name.isNotEmpty) {
        classFeatureMap[name] = feat;
        if (className.isNotEmpty) {
          classFeatureMap['$name|$className'] = feat;
          if (level.isNotEmpty) {
            classFeatureMap['$name|$className|$level'] = feat;
            if (source.isNotEmpty) {
              classFeatureMap['$name|$className|$source|$level'] = feat;
            }
          }
        }
      }
    }
    return classFeatureMap;
  }

  static Map<String, Map<String, dynamic>>? _buildSubclassFeatureMap(
      List<Map<String, dynamic>> rawSubclassFeatures) {
    if (rawSubclassFeatures.isEmpty) return null;
    final subclassFeatureMap = <String, Map<String, dynamic>>{};
    for (final feat in rawSubclassFeatures) {
      final name = feat['name']?.toString().toLowerCase().trim() ?? '';
      final className =
          (feat['className']?.toString() ?? feat['class']?.toString() ?? '')
              .toLowerCase()
              .trim();
      final subShort = (feat['subclassShortName']?.toString() ??
              feat['shortName']?.toString() ??
              '')
          .toLowerCase()
          .trim();
      final source = (feat['source']?.toString() ?? '').toLowerCase().trim();
      final classSource =
          (feat['classSource']?.toString() ?? '').toLowerCase().trim();
      final subSource =
          (feat['subclassSource']?.toString() ?? source).toLowerCase().trim();
      final level = (feat['level']?.toString() ?? '').trim();

      if (name.isNotEmpty) {
        subclassFeatureMap[name] = feat;
        final nameSlug = name.replaceAll(' ', '-');
        subclassFeatureMap[nameSlug] = feat;
        if (subShort.isNotEmpty) {
          final subSlug = subShort.replaceAll(' ', '-');
          subclassFeatureMap['$name|$subShort'] = feat;
          subclassFeatureMap['$name|$subSlug'] = feat;
          if (className.isNotEmpty) {
            subclassFeatureMap['$name|$className|$subShort'] = feat;
            subclassFeatureMap['$name|$className|$subSlug'] = feat;
          }
          if (level.isNotEmpty) {
            subclassFeatureMap['$name|$subShort|$level'] = feat;
            subclassFeatureMap['$name|$subSlug|$level'] = feat;
            if (className.isNotEmpty) {
              subclassFeatureMap['$name|$className|$subShort|$level'] = feat;
              subclassFeatureMap['$name|$className|$subSlug|$level'] = feat;
              if (classSource.isNotEmpty) {
                subclassFeatureMap[
                        '$name|$className|$classSource|$subShort|$subSource|$level'] =
                    feat;
                subclassFeatureMap[
                    '$name|$className|$classSource|$subShort||$level'] = feat;
              }
              if (source.isNotEmpty) {
                subclassFeatureMap[
                        '$name|$className|$source|$subShort|$subSource|$level'] =
                    feat;
              }
              subclassFeatureMap['$name|$className||$subShort||$level'] = feat;
            }
          }
        }
        if (className.isNotEmpty) {
          subclassFeatureMap['$name|$className'] = feat;
          if (level.isNotEmpty) {
            subclassFeatureMap['$name|$className|$level'] = feat;
          }
        }
        if (level.isNotEmpty) {
          subclassFeatureMap['$name|$level'] = feat;
        }
      }
    }
    return subclassFeatureMap;
  }

  /// Composite structural fingerprinting evaluating whether a map represents
  /// a tabletop entity rather than generic web/package JSON.
  static bool _isTabletopEntity(
    Map<String, dynamic> m, {
    String? parentKey,
    Map<String, dynamic>? rootDoc,
  }) {
    final rawName = m['name'] ?? m['title'] ?? m['label'] ?? m['header'];
    if (rawName == null || rawName.toString().trim().isEmpty) return false;

    // Reject metadata / index files / package manifests
    final keys = m.keys.map((k) => k.toLowerCase()).toSet();
    if (keys.contains('_meta') && keys.length <= 3) return false;
    if (keys.contains(r'$schema') && keys.length <= 2) return false;
    if (keys.contains('scripts') &&
        (keys.contains('dependencies') || keys.contains('version')))
      return false;

    return _inferEntityType(m, categoryHint: parentKey, rootDoc: rootDoc) !=
        null;
  }

  /// Dynamically infers the tabletop entity category using composite mechanical shape,
  /// non-generic parent key hints, and template definitions.
  static String? _inferEntityType(
    Map<String, dynamic> m, {
    String? categoryHint,
    Map<String, dynamic>? rootDoc,
  }) {
    // 1. Explicit entityType if present and non-generic
    final explicitEntityType = m['entityType']?.toString().toLowerCase().trim();
    if (explicitEntityType != null &&
        explicitEntityType.isNotEmpty &&
        !_genericWrapperKeys.contains(explicitEntityType)) {
      return explicitEntityType;
    }

    // 2. Direct Non-Generic Category Hint Priority
    final hintLower = categoryHint?.toLowerCase().trim();
    final isGenericHint = hintLower == null ||
        hintLower.isEmpty ||
        _genericWrapperKeys.contains(hintLower) ||
        hintLower.contains('meta') ||
        hintLower.contains('source') ||
        hintLower.contains('config');

    if (!isGenericHint) {
      if (hintLower == 'monster' ||
          hintLower == 'monsters' ||
          hintLower == 'creature' ||
          hintLower == 'creatures' ||
          hintLower == 'bestiary' ||
          hintLower == 'npc' ||
          hintLower == 'npcs') {
        return 'monster';
      }
      if (hintLower == 'spell' || hintLower == 'spells') return 'spell';
      if (hintLower == 'item' ||
          hintLower == 'items' ||
          hintLower == 'equipment' ||
          hintLower == 'magicitem' ||
          hintLower == 'magicitems' ||
          hintLower == 'weapon' ||
          hintLower == 'weapons' ||
          hintLower == 'armor' ||
          hintLower == 'baseitem' ||
          hintLower == 'itemgroup') {
        return 'equipment';
      }
      if (hintLower == 'class' || hintLower == 'classes') return 'class';
      if (hintLower == 'subclass' || hintLower == 'subclasses')
        return 'subclass';
      if (hintLower == 'classfeature' || hintLower == 'classfeatures')
        return 'classfeature';
      if (hintLower == 'subclassfeature' || hintLower == 'subclassfeatures')
        return 'subclassfeature';
      if (hintLower == 'feat' || hintLower == 'feats') return 'feat';
      if (hintLower == 'background' || hintLower == 'backgrounds')
        return 'background';
      if (hintLower == 'subrace' || hintLower == 'subraces') return 'subrace';
      if (hintLower == 'race' ||
          hintLower == 'races' ||
          hintLower == 'species') {
        // Ensure an NPC with raceName is not misclassified if it possesses monster attributes
        final hasMonsterKeys = m.containsKey('cr') ||
            m.containsKey('challengeRating') ||
            m.containsKey('hp') ||
            m.containsKey('ac') ||
            m.containsKey('actions') ||
            m.containsKey('action') ||
            m.containsKey('isNpc') ||
            m.containsKey('isNamedCreature') ||
            m.containsKey('_copy');
        if (!hasMonsterKeys) return 'race';
      }
      if (hintLower == 'table' || hintLower == 'tables') return 'table';
      if (hintLower == 'deck' || hintLower == 'decks') return 'deck';
      if (hintLower == 'optionalfeature' || hintLower == 'optionalfeatures')
        return 'optionalfeature';
    }

    // 3. If object contains a $ref pointer, inspect the referenced definition
    final refVal = m[r'$ref'] ?? m['ref'];
    if (refVal is String && refVal.isNotEmpty) {
      if (rootDoc != null) {
        final target = _resolveJsonPointer(rootDoc, refVal);
        if (target is Map) {
          final targetType = _inferEntityType(
            Map<String, dynamic>.from(target),
            categoryHint: categoryHint,
            rootDoc: rootDoc,
          );
          if (targetType != null) return targetType;
        }
      }
      return categoryHint ?? 'equipment';
    }

    // 4. Explicit type attribute inspection (creature types, equipment categories)
    final explicitType = m['type'];
    String? typeStr;
    if (explicitType is String) {
      typeStr = explicitType.toLowerCase().trim();
    } else if (explicitType is Map) {
      typeStr = explicitType['type']?.toString().toLowerCase().trim();
    }

    if (typeStr != null &&
        typeStr.isNotEmpty &&
        !_genericWrapperKeys.contains(typeStr)) {
      const creatureTypes = {
        'aberration',
        'beast',
        'celestial',
        'construct',
        'dragon',
        'elemental',
        'fey',
        'fiend',
        'giant',
        'humanoid',
        'monstrosity',
        'ooze',
        'plant',
        'undead',
        'monster',
        'creature',
        'npc',
        'bestiary',
      };

      // Extract primary type from compound expressions like "humanoid (strongheart halfling)" or "beast (cat)"
      final primaryType = typeStr.split(RegExp(r'[\s(,]')).first.trim();
      if (creatureTypes.contains(primaryType) ||
          creatureTypes.contains(typeStr)) {
        return 'monster';
      }

      if (typeStr == 'spell') return 'spell';
      if (typeStr == 'item' ||
          typeStr == 'equipment' ||
          typeStr == 'magicitem' ||
          typeStr == 'weapon' ||
          typeStr == 'armor') {
        return 'equipment';
      }
      if (typeStr == 'class') return 'class';
      if (typeStr == 'subclass') return 'subclass';
      if (typeStr == 'classfeature' || typeStr == 'classfeatures')
        return 'classfeature';
      if (typeStr == 'subclassfeature' || typeStr == 'subclassfeatures')
        return 'subclassfeature';
      if (typeStr == 'race' || typeStr == 'species' || typeStr == 'subrace')
        return 'race';
      if (typeStr == 'feat') return 'feat';
      if (typeStr == 'background') return 'background';
      if (typeStr == 'table') return 'table';
      if (typeStr == 'deck') return 'deck';
    }

    // 5. Composite Structural Criteria
    // Monster signature attributes (combat stats, action lists, NPC flags)
    final hasMonsterTraits = m.containsKey('actions') ||
        m.containsKey('action') ||
        m.containsKey('reactions') ||
        m.containsKey('reaction') ||
        m.containsKey('legendary') ||
        m.containsKey('trait') ||
        m.containsKey('isNpc') ||
        m.containsKey('isNamedCreature') ||
        m.containsKey('save') ||
        m.containsKey('passive');

    if (m.containsKey('hp') &&
        (m.containsKey('ac') ||
            m.containsKey('stats') ||
            m.containsKey('cr') ||
            m.containsKey('challengeRating') ||
            m.containsKey('hitDice') ||
            hasMonsterTraits)) {
      return 'monster';
    }
    if ((m.containsKey('cr') || m.containsKey('challengeRating')) &&
        (m.containsKey('ac') || m.containsKey('hp') || hasMonsterTraits)) {
      return 'monster';
    }

    // Creature templates using _copy (e.g. Onyx referencing Cat, Bepis Honeymaker referencing Commoner)
    if (m.containsKey('_copy') &&
        (hasMonsterTraits ||
            m.containsKey('speed') ||
            m.containsKey('size') ||
            m.containsKey('alignment') ||
            m.containsKey('race') ||
            m.containsKey('raceName') ||
            (typeStr != null && typeStr.isNotEmpty))) {
      return 'monster';
    }

    // Subclass Feature: has subclassFeature flag OR (subclassShortName AND NOT subclassFeatures)
    if (m.containsKey('subclassFeature') ||
        m.containsKey('gainSubclassFeature') ||
        (m.containsKey('subclassShortName') &&
            !m.containsKey('subclassFeatures'))) {
      return 'subclassfeature';
    }

    // Class Feature: has classFeature flag OR (className AND level AND NOT hitDie AND NOT subclassFeatures)
    if (m.containsKey('classFeature') ||
        (m.containsKey('className') &&
            m.containsKey('level') &&
            !m.containsKey('hitDie') &&
            !m.containsKey('hd') &&
            !m.containsKey('subclassFeatures') &&
            !m.containsKey('subclasses') &&
            !m.containsKey('shortName') &&
            !m.containsKey('subclassTitle'))) {
      return 'classfeature';
    }

    // Subclass: requires subclassFeatures OR (className AND (shortName OR subclassTitle))
    if (m.containsKey('subclassFeatures') ||
        (m.containsKey('className') &&
            (m.containsKey('shortName') || m.containsKey('subclassTitle')))) {
      return 'subclass';
    }

    // Class: requires hitDie OR hd OR (proficiency AND (classFeatures OR startingProficiencies))
    if (m.containsKey('hitDie') ||
        m.containsKey('hd') ||
        (m.containsKey('proficiency') &&
            (m.containsKey('classFeatures') ||
                m.containsKey('startingProficiencies')))) {
      return 'class';
    }

    // Spell: requires level AND (school OR time OR duration OR range)
    if (m.containsKey('level') &&
        (m.containsKey('school') ||
            m.containsKey('time') ||
            m.containsKey('duration') ||
            m.containsKey('range'))) {
      return 'spell';
    }

    // Item / Equipment: requires reqAttune OR rarity OR weaponCategory OR armorType OR itemType
    if (m.containsKey('reqAttune') ||
        m.containsKey('rarity') ||
        m.containsKey('weaponCategory') ||
        m.containsKey('armorType') ||
        m.containsKey('itemType')) {
      return 'equipment';
    }

    // Optional Feature / Invocation / Infusion (evaluated before Feat since invocations have prerequisites)
    if (m.containsKey('featureType') ||
        (categoryHint != null &&
            (categoryHint.toLowerCase() == 'optionalfeature' ||
                categoryHint.toLowerCase() == 'optionalfeatures'))) {
      return 'optionalfeature';
    }

    // Feat: requires prerequisite OR prereq OR (entries AND (originFeat OR repeatable OR category == 'feat'))
    if (m.containsKey('prerequisite') ||
        m.containsKey('prereq') ||
        (m.containsKey('entries') &&
            (m.containsKey('originFeat') ||
                m.containsKey('repeatable') ||
                m['category']?.toString().toLowerCase() == 'feat'))) {
      return 'feat';
    }

    // Playable Character Race / Species: Requires PC trait structures and MUST NOT possess monster attributes.
    // NOTE: speed and size alone NEVER classify an entity as a playable race!
    final hasMonsterExclusions = hasMonsterTraits ||
        m.containsKey('hp') ||
        m.containsKey('ac') ||
        m.containsKey('cr') ||
        m.containsKey('challengeRating') ||
        m.containsKey('hitDice') ||
        m.containsKey('_copy');

    if (!hasMonsterExclusions) {
      if (m.containsKey('subrace') ||
          (m.containsKey('raceName') &&
              (m.containsKey('ability') || m.containsKey('traits')))) {
        return 'subrace';
      }

      if (m.containsKey('subraces') ||
          m.containsKey('lineage') ||
          (m.containsKey('ability') &&
              (m.containsKey('speed') ||
                  m.containsKey('traits') ||
                  m.containsKey('size'))) ||
          (m.containsKey('traits') &&
              m.containsKey('speed') &&
              !m.containsKey('trait'))) {
        return 'race';
      }
    }

    // Background: startingEquipment OR (featureName AND entries) OR (startingProficiencies AND entries AND !hitDie)
    if (m.containsKey('startingEquipment') ||
        (m.containsKey('featureName') && m.containsKey('entries')) ||
        (m.containsKey('startingProficiencies') &&
            m.containsKey('entries') &&
            !m.containsKey('hitDie') &&
            !m.containsKey('hd'))) {
      return 'background';
    }

    // Feature Declaration: className / class / subclass / gainSubclassFeature with entries or level
    if (_isFeatureDeclaration(m)) {
      return _isSubclassFeature(m, parentKey: categoryHint)
          ? 'subclassfeature'
          : 'classfeature';
    }

    // Table / Deck
    if (m.containsKey('cards')) return 'deck';
    if (m.containsKey('table') &&
        (m.containsKey('rows') || m.containsKey('cols'))) return 'table';

    // Fluff / Lore
    if (m.containsKey('_copy') ||
        m.containsKey('images') ||
        (categoryHint != null &&
            categoryHint.toLowerCase().contains('fluff'))) {
      return categoryHint?.toLowerCase() ?? 'fluff';
    }

    // 6. Generic Hint Fallback
    if (!isGenericHint) {
      return hintLower;
    }

    return null;
  }

  static bool _isFeatureDeclaration(Map<String, dynamic> m) {
    if (m['name'] == null) return false;
    return m.containsKey('className') ||
        m.containsKey('class') ||
        m.containsKey('subclass') ||
        m.containsKey('subclassShortName') ||
        m.containsKey('gainSubclassFeature');
  }

  static bool _isSubclassFeature(Map<String, dynamic> m, {String? parentKey}) {
    if (parentKey != null && parentKey.toLowerCase().contains('subclass'))
      return true;
    return m['gainSubclassFeature'] == true ||
        m['subclassShortName'] != null ||
        m['subclass'] != null ||
        m['subclassName'] != null;
  }
}

class _DiscoveredEntity {
  final Map<String, dynamic> data;
  final String path;
  final String? categoryHint;

  _DiscoveredEntity({
    required this.data,
    required this.path,
    this.categoryHint,
  });
}
