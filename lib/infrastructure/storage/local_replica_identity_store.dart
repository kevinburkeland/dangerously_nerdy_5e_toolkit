import 'package:uuid/uuid.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import '../../services/persistence/app_database_service.dart';

/// Provider for active runtime CRDT replica identity.
///
/// ### Cold Iron Birdcage Pass 1.3 Invariant: Active Runtime Writer Identity
/// Each independently executing process/tab/runtime that originates CRDT mutations
/// MUST have a unique in-memory [ReplicaId] generated for that runtime.
///
/// A [ReplicaId] MUST NOT be persisted to durable storage and reused across application
/// launches or concurrent tabs, because state-based PN-counters require single-writer
/// monotonic components. Reusing writer IDs across concurrent browser tabs causes updates
/// to collide under lattice joins (`max`).
///
/// Historical persisted component IDs (such as legacy UUIDs or 'local'/'init') remain
/// valid immutable data and deserialize unchanged, but are NOT active writers.
class LocalReplicaIdentityStore {
  final AppDatabaseService _db;

  LocalReplicaIdentityStore({AppDatabaseService? db})
      : _db = db ?? AppDatabaseService.instance;

  /// Generates a fresh, unique, in-memory [ReplicaId] for the current executing runtime.
  ///
  /// In accordance with Pass 1.3, this identity is NEVER read from or persisted to
  /// durable storage for reuse as an active writer identity.
  Future<ReplicaId> getOrCreateReplicaId() async {
    return createRuntimeReplicaId();
  }

  /// Creates a fresh in-memory runtime [ReplicaId] backed by UUIDv4.
  static ReplicaId createRuntimeReplicaId() {
    return ReplicaId(const Uuid().v4());
  }

  /// Optional reader for legacy/deprecated persisted device identifier in metadata box,
  /// strictly for diagnostics or durable device-tracking, NEVER as an active writer identity.
  String? get deprecatedPersistedDeviceId {
    final existing = _db.get(
      AppDatabaseService.boxMetadata,
      AppDatabaseService.keyReplicaId,
    );
    return existing?.toString();
  }
}

