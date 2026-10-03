import 'package:uuid/uuid.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import '../../services/persistence/app_database_service.dart';

/// Manages the durable, authoritative CRDT replica identity for this local application/storage instance.
///
/// Invariant: Generated exactly once when none exists, persisted locally to survive restarts,
/// and reused across all subsystems originating replicated state mutations.
class LocalReplicaIdentityStore {
  final AppDatabaseService _db;

  LocalReplicaIdentityStore({AppDatabaseService? db})
      : _db = db ?? AppDatabaseService.instance;

  /// Retrieves the persisted [ReplicaId], or generates, persists, and returns a new authoritative one.
  Future<ReplicaId> getOrCreateReplicaId() async {
    final existing = _db.get(
      AppDatabaseService.boxMetadata,
      AppDatabaseService.keyReplicaId,
    );
    if (existing != null) {
      final str = existing.toString().trim();
      if (str.isNotEmpty && str.toLowerCase() != 'local') {
        return ReplicaId(str);
      }
    }

    final newId = ReplicaId(const Uuid().v4());
    await _db.put(
      AppDatabaseService.boxMetadata,
      AppDatabaseService.keyReplicaId,
      newId.value,
    );
    return newId;
  }
}
