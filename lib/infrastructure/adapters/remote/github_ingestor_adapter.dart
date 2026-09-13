import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../../domain/homebrew/ports/i_github_ingestor_port.dart';
import '../../../domain/homebrew/value_objects/github_repo_source.dart';
import '../../../domain/homebrew/value_objects/ruleset_version.dart';
import '../../dtos/homebrew_entity_dto.dart';
import 'http_fetcher.dart';

// Pure Dart compile-time constant for web detection (all JS numbers are double IEEE 754)
const bool _isWeb = identical(0, 0.0);

/// Concrete adapter fulfilling [IGithubIngestorPort] for GitHub homebrew repositories.
///
/// Handles tree discovery, bounded concurrency downloads (max 6 parallel connections),
/// platform-specific isolate/microtask offloading, and ACL schema enforcement.
class GithubIngestorAdapter implements IGithubIngestorPort {
  static const int maxConcurrentDownloads = 6;

  /// Payloads smaller than this threshold (64 KB) are parsed directly on the event loop
  /// to avoid Isolate spawn, memory copy, and port transfer overhead.
  static const int isolateThresholdBytes = 64 * 1024;

  final HttpFetchClient _client;
  final bool _useIsolate;

  GithubIngestorAdapter({
    HttpFetchClient? client,
    bool useIsolate = true,
  })  : _client = client ?? HttpFetchClient(),
        _useIsolate = useIsolate;

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
      throw FormatException('Failed to decode GitHub Git Tree API response: $e');
    }

    final treeList = treeData['tree'];
    if (treeList is! List) {
      throw const FormatException('GitHub Git Tree response missing "tree" array.');
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
          for (final result in results) {
            controller.add(result);
          }
        }
      }
    }

    final workersCount = urls.length < maxConcurrentDownloads ? urls.length : maxConcurrentDownloads;
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
      final reason = e is HttpFetchException ? e.message : 'HTTP download failure: $e';
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
        return await Isolate.run(() => _unpackAndParsePayload(jsonString, ruleset, url));
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
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is Map) {
          final entityMap = Map<String, dynamic>.from(item);
          final entityName = (entityMap['name'] ?? entityMap['title'] ?? 'item_$i').toString();
          final itemUrl = '$url#item_${i}_$entityName';
          results.add(_parseEntityMap(entityMap, ruleset, itemUrl));
        }
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

    // 2. Root is a JSON Map (Bundle or Single Entity)
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);

      const bundleKeys = [
        'monster',
        'monsters',
        'spell',
        'spells',
        'item',
        'items',
        'baseitem',
        'baseitems',
        'magicvariant',
        'magicvariants',
        'class',
        'classes',
        'subclass',
        'subclasses',
        'race',
        'races',
        'subrace',
        'subraces',
        'feat',
        'feats',
        'background',
        'backgrounds',
        'action',
        'actions',
        'condition',
        'conditions',
        'disease',
        'diseases',
        'status',
        'statuses',
        'cult',
        'cults',
        'boon',
        'boons',
        'deity',
        'deities',
        'hazard',
        'hazards',
        'object',
        'objects',
        'trap',
        'traps',
        'vehicle',
        'vehicles',
        'vehicleupgrade',
        'vehicleupgrades',
        'table',
        'tables',
        'tablegroup',
        'tablegroups',
        'reward',
        'rewards',
        'charoption',
        'charoptions',
        'optionalfeature',
        'optionalfeatures',
        'optfeature',
        'optfeatures',
        'psionic',
        'psionics',
        'language',
        'languages',
        'languagescript',
        'languagescripts',
        'sense',
        'senses',
        'skill',
        'skills',
        'deck',
        'decks',
        'card',
        'cards',
        'variantrule',
        'variantrules',
        'rule',
        'rules',
        'monsterfeature',
        'monsterfeatures',
        'name',
        'names',
        // Fluff keys
        'monsterfluff',
        'spellfluff',
        'itemfluff',
        'racefluff',
        'classfluff',
        'subclassfluff',
        'featfluff',
        'backgroundfluff',
        'optionalfeaturefluff',
        'conditionfluff',
        'rewardfluff',
        'objectfluff',
        'vehiclefluff',
        'trapfluff',
        'languagefluff',
        'charoptionfluff',
        'racefluffmeta',
        'fluff',
      ];

      final foundBundleKeys = map.keys
          .where((k) {
            final lower = k.toLowerCase().trim();
            final isKnownBundle = bundleKeys.contains(lower) || lower.endsWith('fluff');
            return isKnownBundle && map[k] is List && (map[k] as List).isNotEmpty;
          })
          .toList();

      if (foundBundleKeys.isNotEmpty) {
        final results = <IngestionResult>[];
        for (final key in foundBundleKeys) {
          final list = map[key] as List;
          for (var i = 0; i < list.length; i++) {
            final item = list[i];
            if (item is Map) {
              final entityMap = Map<String, dynamic>.from(item);
              if (!entityMap.containsKey('entityType')) {
                entityMap['entityType'] = key;
              }
              final entityName = (entityMap['name'] ?? entityMap['title'] ?? 'item_$i').toString();
              final itemUrl = '$url#$key/$entityName';
              results.add(_parseEntityMap(entityMap, ruleset, itemUrl));
            }
          }
        }
        return results;
      }

      // Single entity check
      final rawName = (map['name'] ?? map['title'] ?? map['label'] ?? map['header'])
          ?.toString()
          .trim();
      if (rawName != null && rawName.isNotEmpty) {
        return [_parseEntityMap(map, ruleset, url)];
      }

      // No entity arrays and no entity name -> repository metadata
      return [
        IngestionSkipResult(
          sourceUrl: url,
          reason: 'Repository metadata or index file (no tabletop entities found)',
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
      final dto = HomebrewEntityDto.fromJson(
        entityMap,
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
}
