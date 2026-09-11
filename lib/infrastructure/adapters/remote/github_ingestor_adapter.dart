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
/// Handles tree discovery, bounded concurrency downloads (max 4 parallel connections),
/// platform-specific isolate/microtask offloading, and ACL schema enforcement.
class GithubIngestorAdapter implements IGithubIngestorPort {
  static const int maxConcurrentDownloads = 4;

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
        final result = await _fetchAndParse(url, ruleset);
        if (!controller.isClosed) {
          controller.add(result);
        }
      }
    }

    final workersCount = urls.length < maxConcurrentDownloads ? urls.length : maxConcurrentDownloads;
    final workers = List.generate(workersCount, (_) => worker());
    await Future.wait(workers);
  }

  Future<IngestionResult> _fetchAndParse(
    String url,
    RulesetVersion ruleset,
  ) async {
    String rawContent;
    try {
      rawContent = await _client.get(Uri.parse(url));
    } catch (e) {
      final reason = e is HttpFetchException ? e.message : 'HTTP download failure: $e';
      return IngestionSkipResult(
        sourceUrl: url,
        reason: reason,
        errorDetails: e.toString(),
        ruleset: ruleset,
      );
    }

    try {
      final dto = await _executeParsing(rawContent, ruleset, url);
      return IngestionSuccessResult(
        entity: dto.toDomain(),
        sourceUrl: url,
        ruleset: ruleset,
      );
    } on HomebrewValidationException catch (e) {
      return IngestionSkipResult(
        sourceUrl: url,
        reason: e.message,
        errorDetails: e.toString(),
        ruleset: ruleset,
      );
    } catch (e) {
      return IngestionSkipResult(
        sourceUrl: url,
        reason: 'Malformed or invalid JSON schema: $e',
        errorDetails: e.toString(),
        ruleset: ruleset,
      );
    }
  }

  Future<HomebrewEntityDto> _executeParsing(
    String jsonString,
    RulesetVersion ruleset,
    String url,
  ) async {
    if (!_isWeb && _useIsolate) {
      try {
        return await Isolate.run(() {
          final decoded = jsonDecode(jsonString);
          if (decoded is! Map<String, dynamic> && decoded is! Map) {
            throw const FormatException('Payload root must be a JSON object.');
          }
          final map = Map<String, dynamic>.from(decoded as Map);
          return HomebrewEntityDto.fromJson(map, ruleset: ruleset, sourcePath: url);
        });
      } on UnsupportedError {
        // Fallback when isolates are not supported (e.g. Flutter Web)
        return _parseInMicrotask(jsonString, ruleset, url);
      }
    } else {
      return _parseInMicrotask(jsonString, ruleset, url);
    }
  }

  Future<HomebrewEntityDto> _parseInMicrotask(
    String jsonString,
    RulesetVersion ruleset,
    String url,
  ) async {
    final completer = Completer<HomebrewEntityDto>();
    scheduleMicrotask(() {
      try {
        final decoded = jsonDecode(jsonString);
        if (decoded is! Map<String, dynamic> && decoded is! Map) {
          throw const FormatException('Payload root must be a JSON object.');
        }
        final map = Map<String, dynamic>.from(decoded as Map);
        final dto = HomebrewEntityDto.fromJson(map, ruleset: ruleset, sourcePath: url);
        completer.complete(dto);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}
