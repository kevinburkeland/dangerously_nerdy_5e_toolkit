import 'dart:async';
import 'package:meta/meta.dart';
import '../../domain/crdt/crdt_or_set.dart';
import '../../domain/crdt/hybrid_logical_clock.dart';
import '../../domain/homebrew/models/homebrew_entity.dart';
import '../../domain/homebrew/ports/i_github_ingestor_port.dart';
import '../../domain/homebrew/value_objects/github_repo_source.dart';
import '../../domain/homebrew/value_objects/ruleset_version.dart';

/// Reactive telemetry snapshot emitted during homebrew ingestion.
@immutable
class HomebrewImportTelemetry {
  final int filesDiscovered;
  final int filesImported;
  final int filesSkipped;
  final List<String> errors;
  final String? currentFileName;
  final bool isCompleted;
  final CrdtOrSet<HomebrewEntity> crdtLedger;

  const HomebrewImportTelemetry({
    this.filesDiscovered = 0,
    this.filesImported = 0,
    this.filesSkipped = 0,
    this.errors = const [],
    this.currentFileName,
    this.isCompleted = false,
    this.crdtLedger = const CrdtOrSet<HomebrewEntity>(),
  });

  HomebrewImportTelemetry copyWith({
    int? filesDiscovered,
    int? filesImported,
    int? filesSkipped,
    List<String>? errors,
    String? currentFileName,
    bool? isCompleted,
    CrdtOrSet<HomebrewEntity>? crdtLedger,
  }) {
    return HomebrewImportTelemetry(
      filesDiscovered: filesDiscovered ?? this.filesDiscovered,
      filesImported: filesImported ?? this.filesImported,
      filesSkipped: filesSkipped ?? this.filesSkipped,
      errors: errors ?? this.errors,
      currentFileName: currentFileName ?? this.currentFileName,
      isCompleted: isCompleted ?? this.isCompleted,
      crdtLedger: crdtLedger ?? this.crdtLedger,
    );
  }

  double get progressRatio {
    if (filesDiscovered <= 0) return 0.0;
    if (isCompleted) return 1.0;
    final total = filesImported + filesSkipped;
    final ratio = total / filesDiscovered;
    return ratio > 0.95 ? 0.95 : ratio;
  }
}

/// Type definition for entity persistence callbacks.
typedef EntityPersister = Future<void> Function(HomebrewEntity entity);

/// Type definition for batch entity persistence callbacks.
typedef EntityBatchPersister = Future<void> Function(List<HomebrewEntity> entities);

/// Application service orchestrating discovery, streaming ACL ingestion,
/// and CRDT ledger state reconciliation for GitHub homebrew repositories.
class HomebrewImportOrchestrator {
  static const int defaultBatchSize = 50;
  static const int telemetryThrottleIntervalMs = 100;

  final IGithubIngestorPort _ingestorPort;
  final String _nodeId;
  final EntityPersister? _persister;
  final EntityBatchPersister? _batchPersister;
  final int _batchSize;

  CrdtOrSet<HomebrewEntity> _ledger = const CrdtOrSet<HomebrewEntity>();
  HybridLogicalClock _hlc;

  HomebrewImportOrchestrator({
    required IGithubIngestorPort ingestorPort,
    String? nodeId,
    EntityPersister? persister,
    EntityBatchPersister? batchPersister,
    int batchSize = defaultBatchSize,
    CrdtOrSet<HomebrewEntity>? initialLedger,
  }) : this._internal(
          ingestorPort: ingestorPort,
          nodeId: nodeId ?? 'node_homebrew_${DateTime.now().millisecondsSinceEpoch}',
          persister: persister,
          batchPersister: batchPersister,
          batchSize: batchSize,
          initialLedger: initialLedger,
        );

  HomebrewImportOrchestrator._internal({
    required IGithubIngestorPort ingestorPort,
    required String nodeId,
    EntityPersister? persister,
    EntityBatchPersister? batchPersister,
    int batchSize = defaultBatchSize,
    CrdtOrSet<HomebrewEntity>? initialLedger,
  })  : _ingestorPort = ingestorPort,
        _nodeId = nodeId,
        _persister = persister,
        _batchPersister = batchPersister,
        _batchSize = batchSize,
        _ledger = initialLedger ?? const CrdtOrSet<HomebrewEntity>(),
        _hlc = HybridLogicalClock.now(nodeId);

  /// Node identifier used for stamping CRDT clock ticks.
  String get nodeId => _nodeId;

  /// Current state of the CRDT ledger.
  CrdtOrSet<HomebrewEntity> get ledger => _ledger;

  /// Executes the ingestion pipeline and returns a reactive broadcast stream.
  ///
  /// Adheres strictly to Directive 2: StreamController is configured with `sync: false`
  /// to prevent re-entrant deadlocks during UI state notification.
  Stream<HomebrewImportTelemetry> runImport({
    required GithubRepoSource source,
    required RulesetVersion ruleset,
  }) {
    final controller = StreamController<HomebrewImportTelemetry>.broadcast(sync: false);

    scheduleMicrotask(() async {
      var telemetry = const HomebrewImportTelemetry();

      try {
        // Step 1: Discover JSON manifest from GitHub tree API
        final rawUrls = await _ingestorPort.discoverJsonManifest(source);
        telemetry = telemetry.copyWith(
          filesDiscovered: rawUrls.length,
          crdtLedger: _ledger,
        );
        controller.add(telemetry);

        if (rawUrls.isEmpty) {
          telemetry = telemetry.copyWith(isCompleted: true);
          controller.add(telemetry);
          await controller.close();
          return;
        }

        // Step 2: Stream ingestion payloads through bounded ACL worker pool
        final stream = _ingestorPort.ingestPayloadStream(
          rawUrls: rawUrls,
          ruleset: ruleset,
        );

        final accumulatedErrors = <String>[];
        final pendingBatch = <HomebrewEntity>[];
        var importedCount = 0;
        var skippedCount = 0;
        var lastTelemetryEmission = DateTime.fromMillisecondsSinceEpoch(0);

        await for (final result in stream) {
          final fileName = result.sourceUrl.split('/').last;

          if (result is IngestionSuccessResult) {
            final entity = result.entity;
            _hlc = _hlc.tick();
            _ledger = _ledger.add(entity.id, entity, _hlc);

            if (_persister != null) {
              try {
                await _persister!(entity);
              } catch (_) {
                // Non-fatal if secondary cache storage fails; CRDT ledger remains authoritative
              }
            }

            if (_batchPersister != null) {
              pendingBatch.add(entity);
              if (pendingBatch.length >= _batchSize) {
                try {
                  await _batchPersister!(List.unmodifiable(pendingBatch));
                } catch (_) {}
                pendingBatch.clear();
              }
            }

            importedCount++;
          } else if (result is IngestionSkipResult) {
            skippedCount++;
            final errText = '$fileName: ${result.reason}';
            accumulatedErrors.add(errText);
          }

          final now = DateTime.now();
          if (now.difference(lastTelemetryEmission).inMilliseconds >= telemetryThrottleIntervalMs) {
            lastTelemetryEmission = now;
            telemetry = telemetry.copyWith(
              filesImported: importedCount,
              filesSkipped: skippedCount,
              errors: List.unmodifiable(accumulatedErrors),
              currentFileName: fileName,
              crdtLedger: _ledger,
            );
            controller.add(telemetry);
          }
        }

        // Flush remaining buffered batch
        if (pendingBatch.isNotEmpty && _batchPersister != null) {
          try {
            await _batchPersister!(List.unmodifiable(pendingBatch));
          } catch (_) {}
          pendingBatch.clear();
        }

        // Step 3: Complete ingestion cycle
        telemetry = telemetry.copyWith(
          filesImported: importedCount,
          filesSkipped: skippedCount,
          errors: List.unmodifiable(accumulatedErrors),
          isCompleted: true,
          crdtLedger: _ledger,
        );
        controller.add(telemetry);
      } catch (e, st) {
        final rawMsg = e.toString();
        final friendlyMsg = (rawMsg.contains('minified:') || rawMsg.contains('ProgressEvent') || rawMsg.contains('Instance of'))
            ? 'Network / Security Error: Unable to access GitHub repository. Please verify repository URL and internet connection.'
            : rawMsg;
        final errList = List<String>.from(telemetry.errors)
          ..add('Fatal discovery failure: $friendlyMsg');
        telemetry = telemetry.copyWith(
          errors: List.unmodifiable(errList),
          isCompleted: true,
          crdtLedger: _ledger,
        );
        controller.add(telemetry);
        controller.addError(e, st);
      } finally {
        await controller.close();
      }
    });

    return controller.stream;
  }
}
