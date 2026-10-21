import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../services/app_services.dart';
import '../../services/logging_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../dtos/campaign_profile_dto.dart';

/// Infrastructure-level cache holding raw unparsed JSON payloads
/// to preserve 100% data fidelity on round-trip without leaking into the Domain layer.
class UnparsedPayloadCache {
  final List<Map<String, dynamic>> unparsedPartyRoster;
  final List<Map<String, dynamic>> unparsedMinions;

  const UnparsedPayloadCache({
    this.unparsedPartyRoster = const [],
    this.unparsedMinions = const [],
  });

  bool get isEmpty => unparsedPartyRoster.isEmpty && unparsedMinions.isEmpty;
}

/// Concrete infrastructure adapter implementing [ICampaignRepository]
/// with in-memory caching, debounced persistence, Hive/IndexedDB ([AppDatabaseService]) storage,
/// and reactive broadcast Streams. Completely decoupled from UI frameworks (no ChangeNotifier).
class LocalCampaignRepository implements ICampaignRepository {
  static const String profileKeyPrefix = 'dn5e_campaign_profile_';
  static const String profileIndexKey = 'dn5e_campaign_profile_index';
  static const String activeProfileIdKey = 'dn5e_campaign_active_id';

  final AppDatabaseService _db;
  final Map<String, CampaignProfile> _memoryCache = {};
  final Map<String, UnparsedPayloadCache> _unparsedCache = {};
  final Set<String> _rejectedProfileIds = {};
  String? _activeProfileId;
  bool _initialized = false;

  final StreamController<CampaignProfile?> _activeProfileController =
      StreamController<CampaignProfile?>.broadcast();
  final StreamController<List<CampaignProfile>> _allProfilesController =
      StreamController<List<CampaignProfile>>.broadcast();

  final ReplicaId _replicaId;
  final StatefulHlcClock _clock;

  LocalCampaignRepository({
    AppDatabaseService? db,
    ICharacterRepository? characterRepo,
    required ReplicaId replicaId,
    required StatefulHlcClock clock,
  })  : _db = db ?? AppDatabaseService.instance,
        _replicaId = replicaId,
        _clock = clock {
    if (_clock.replicaId != replicaId) {
      throw ArgumentError(
        'LocalCampaignRepository writer identity mismatch: '
        'replicaId ($replicaId) does not match clock.replicaId (${_clock.replicaId}).',
      );
    }
  }

  ReplicaId get replicaId => _replicaId;
  StatefulHlcClock get clock => _clock;

  @override
  String? get activeProfileId => _activeProfileId;

  @override
  CampaignProfile? get activeProfile =>
      _activeProfileId != null ? _memoryCache[_activeProfileId] : null;

  @override
  List<CampaignProfile> get allProfiles => _memoryCache.values.toList();

  Future<void>? _writeQueue;
  Future<void>? _activeReload;
  Future<void>? _activeReloadChain;

  Future<T> _enqueueWrite<T>(Future<T> Function() operation) {
    final prev = _writeQueue;
    final reloadToAwait = _activeReload;
    final completer = Completer<T>();
    late final Future<void> currentFuture;

    currentFuture = () async {
      if (prev != null) {
        try {
          await prev;
        } catch (_) {}
      }

      if (reloadToAwait != null) {
        try {
          await reloadToAwait;
        } catch (_) {}
      }

      try {
        final result = await operation();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        if (identical(_writeQueue, currentFuture)) {
          _writeQueue = null;
        }
      }
    }();

    _writeQueue = currentFuture;
    return completer.future;
  }

  /// Loads all campaign profiles from persistent storage into memory.
  ///
  /// Throws a [StateError] if storage records could not be read.
  /// If storage is empty and successfully read, returns an empty list `[]`.
  @override
  Future<List<CampaignProfile>> loadAllProfiles() async {
    final prev = _activeReloadChain;
    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }

    final completer = Completer<List<CampaignProfile>>();
    completer.future.ignore();
    _activeReloadChain = completer.future;

    try {
      final result = await _executeLoadAllProfiles();
      completer.complete(result);
      return result;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      if (identical(_activeReloadChain, completer.future)) {
        _activeReloadChain = null;
      }
    }
  }

  Future<List<CampaignProfile>> _executeLoadAllProfiles() async {
    // 1. Set active reload future first so new writes wait for this reload
    final reloadCompleter = Completer<void>();
    _activeReload = reloadCompleter.future;

    // 2. Snapshot the write queued before this reload started.
    // The reload's own index rewrite (_executeLoadAllProfiles -> _persistIndex)
    // already runs while no write is in flight. Keep it that way.
    final pendingWrite = _writeQueue;

    try {
      if (pendingWrite != null) {
        try {
          await pendingWrite;
        } catch (_) {}
      }

      final success = await _loadSavedRecords();
      if (!success) {
        throw StateError('Failed to read campaign records from storage');
      }

      if (_memoryCache.isNotEmpty) {
        // If the reload's index rewrite fails, log it and still return the profiles.
        // The read succeeded and the cache is right; the rewrite only copies the index
        // (for example from the old SharedPreferences index), and the next reload repeats it.
        try {
          await _persistIndex();
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Non-fatal failure to rewrite campaign index during reload: $e',
          );
        }
      }
      _emitState();

      return _memoryCache.values.toList();
    } finally {
      _activeReload = null;
      reloadCompleter.complete();
    }
  }

  Future<bool> _loadSavedRecords() async {
    try {
      List<String> indexList = [];
      final dbIndex =
          _db.get(AppDatabaseService.boxCampaignProfiles, profileIndexKey);
      if (dbIndex is List) {
        indexList = dbIndex.map((e) => e.toString()).toList();
      }

      if (indexList.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        indexList = prefs.getStringList(profileIndexKey) ?? <String>[];
      }

      final newProfiles = <CampaignProfile>[];
      final newMemoryCache = <String, CampaignProfile>{};
      final newUnparsedCache = <String, UnparsedPayloadCache>{};
      final newRejectedProfileIds = <String>{};

      for (final id in indexList) {
        String? rawJson = _db
            .get(AppDatabaseService.boxCampaignProfiles, '$profileKeyPrefix$id')
            ?.toString();
        if (rawJson == null || rawJson.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          rawJson = prefs.getString('$profileKeyPrefix$id');
          if (rawJson != null && rawJson.isNotEmpty) {
            await _db.put(AppDatabaseService.boxCampaignProfiles,
                '$profileKeyPrefix$id', rawJson);
          }
        }

        if (rawJson != null && rawJson.isNotEmpty) {
          try {
            final dto = CampaignProfileDto.fromJson(rawJson);
            if (dto.unparsedPartyRoster.isNotEmpty ||
                dto.unparsedMinions.isNotEmpty) {
              newUnparsedCache[id] = UnparsedPayloadCache(
                unparsedPartyRoster: dto.unparsedPartyRoster,
                unparsedMinions: dto.unparsedMinions,
              );
            }
            final profile = dto.toDomain();
            newMemoryCache[id] = profile;
            newProfiles.add(profile);
          } catch (e, st) {
            newRejectedProfileIds.add(id);
            final String reason;
            if (e is FormatException && e.message.contains('recordVersion')) {
              reason = 'Unsupported campaign recordVersion skipped and preserved for campaign $id: $e';
            } else {
              reason = 'Corrupted campaign profile skipped and preserved: $id';
            }
            LoggingService().logNonFatal(
              e,
              st,
              reason: reason,
            );
          }
        }
      }

      // Load active profile ID
      String? activeId = _db
          .get(AppDatabaseService.boxCampaignProfiles, activeProfileIdKey)
          ?.toString();
      if (activeId == null || activeId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        activeId = prefs.getString(activeProfileIdKey);
      }

      String? newActiveProfileId;
      if (activeId != null && newMemoryCache.containsKey(activeId)) {
        newActiveProfileId = activeId;
      } else if (newProfiles.isNotEmpty) {
        newActiveProfileId = newProfiles.first.id;
      } else {
        newActiveProfileId = null;
      }

      for (final profile in newProfiles) {
        _observeTrustedProfileTimestamps(profile);
      }

      // Commit state only after complete successful reading
      _memoryCache.clear();
      _memoryCache.addAll(newMemoryCache);
      _unparsedCache.clear();
      _unparsedCache.addAll(newUnparsedCache);
      _rejectedProfileIds.clear();
      _rejectedProfileIds.addAll(newRejectedProfileIds);
      _activeProfileId = newActiveProfileId;
      _initialized = true;

      return true;
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to load campaign profiles.',
      );
      // On failure it does not touch _memoryCache, _activeProfileId, _initialized or the index.
      return false;
    }
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() =>
      _activeProfileController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() =>
      _allProfilesController.stream;

  void _emitState() {
    if (!_activeProfileController.isClosed) {
      _activeProfileController.add(activeProfile);
    }
    if (!_allProfilesController.isClosed) {
      _allProfilesController.add(allProfiles);
    }
  }

  /// Closes the underlying broadcast stream controllers.
  void dispose() {
    _activeProfileController.close();
    _allProfilesController.close();
  }

  @override
  Future<CampaignProfile?> getProfile(String id) async {
    if (!_initialized) await loadAllProfiles();
    return _memoryCache[id];
  }

  @override
  Future<CampaignProfile?> getActiveProfile() async {
    if (!_initialized) await loadAllProfiles();
    return activeProfile;
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) {
    return _enqueueWrite(() async {
      if (!_initialized) {
        final ok = await _loadSavedRecords();
        if (!ok) {
          throw StateError(
            'Cannot update campaign profile "$id": failed to read campaign records from storage',
          );
        }
      }

      final current = _memoryCache[id];
      if (current == null) {
        throw StateError('Campaign profile with id "$id" not found');
      }

      final next = transform(current);
      _memoryCache[id] = next;
      AppServices.instance.debouncedStorage
          .cancelTask('save_campaign_profile_$id');

      try {
        await _persistProfileToDisk(next);
      } catch (e) {
        _memoryCache[id] = current;
        rethrow;
      }

      _emitState();
      return next;
    });
  }

  @override
  Future<void> putProfile(CampaignProfile profile) {
    return _enqueueWrite(() async {
      if (!_initialized) {
        final ok = await _loadSavedRecords();
        if (!ok) {
          throw StateError(
            'Cannot put campaign profile "${profile.id}": failed to read campaign records from storage',
          );
        }
      }

      final hadPrevious = _memoryCache.containsKey(profile.id);
      final previousProfile = _memoryCache[profile.id];
      final previousActiveProfileId = _activeProfileId;

      _memoryCache[profile.id] = profile;
      _activeProfileId ??= profile.id;
      AppServices.instance.debouncedStorage
          .cancelTask('save_campaign_profile_${profile.id}');

      try {
        await _persistProfileToDisk(profile);
      } catch (e) {
        if (hadPrevious) {
          _memoryCache[profile.id] = previousProfile!;
        } else {
          _memoryCache.remove(profile.id);
        }
        if (_activeProfileId == profile.id && previousActiveProfileId != profile.id) {
          _activeProfileId = previousActiveProfileId;
        }
        rethrow;
      }

      _emitState();
    });
  }

  /// Backward-compatible immediate save delegating to serialized [putProfile].
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    await putProfile(profile);
  }

  @override
  Future<void> deleteProfile(String id) {
    return _enqueueWrite(() async {
      if (!_initialized) {
        final ok = await _loadSavedRecords();
        if (!ok) {
          throw StateError(
            'Cannot delete campaign profile "$id": failed to read campaign records from storage',
          );
        }
      }

      final previousProfile = _memoryCache[id];
      final previousUnparsed = _unparsedCache[id];
      final wasRejected = _rejectedProfileIds.contains(id);

      _memoryCache.remove(id);
      _unparsedCache.remove(id);
      _rejectedProfileIds.remove(id);

      // 1. Write the index without the id FIRST.
      // If that fails, restore the cache, _unparsedCache, and _rejectedProfileIds, and throw;
      // nothing changed on disk.
      try {
        await _persistIndex();
      } catch (e) {
        if (previousProfile != null) {
          _memoryCache[id] = previousProfile;
        }
        if (previousUnparsed != null) {
          _unparsedCache[id] = previousUnparsed;
        }
        if (wasRejected) {
          _rejectedProfileIds.add(id);
        }
        rethrow;
      }

      // 2. Then delete the record (Hive and SharedPreferences copy).
      // If only the record delete fails, log it and return normally:
      // The record is no longer in the index, so no subsequent load can reach it.
      try {
        await _db.delete(
            AppDatabaseService.boxCampaignProfiles, '$profileKeyPrefix$id');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$profileKeyPrefix$id');
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Non-fatal record deletion failure for campaign $id after index update',
        );
      }

      if (_activeProfileId == id) {
        _activeProfileId =
            _memoryCache.keys.isNotEmpty ? _memoryCache.keys.first : null;
        if (_activeProfileId != null) {
          await setActiveProfileId(_activeProfileId!);
        }
      }
      _emitState();
    });
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfileId = id;
    try {
      await _db.put(
          AppDatabaseService.boxCampaignProfiles, activeProfileIdKey, id);
    } catch (_) {}
    _emitState();
  }

  List<String> get _currentIndexList {
    final list = <String>[..._memoryCache.keys];
    for (final rejectedId in _rejectedProfileIds) {
      if (!list.contains(rejectedId)) {
        list.add(rejectedId);
      }
    }
    return list;
  }

  void _observeTrustedProfileTimestamps(CampaignProfile profile) {
    final timestamps = extractCampaignProfileTimestamps(profile);
    if (timestamps.isNotEmpty) {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      for (final ts in timestamps) {
        if (ts.physicalTime > now + _clock.maxFutureDrift.inMilliseconds) {
          final diff = Duration(milliseconds: ts.physicalTime - now);
          LoggingService().logNonFatal(
            'Persisted profile clock is ${diff.inHours}h ahead of local physical time',
            StackTrace.current,
            reason: 'Persisted profile clock diagnostic warning for campaign ${profile.id}',
          );
          break;
        }
      }
      _clock.observeAllTrustedHistory(timestamps);
    }
  }

  Future<void> _persistProfileToDisk(CampaignProfile profile) async {
    try {
      final cachedUnparsed = _unparsedCache[profile.id];
      final dto = CampaignProfileDto.fromDomain(
        profile,
        unparsedPartyRoster: cachedUnparsed?.unparsedPartyRoster ?? const [],
        unparsedMinions: cachedUnparsed?.unparsedMinions ?? const [],
      );
      final jsonStr = dto.toJson();
      final idList = _currentIndexList;
      await _db.putAll(
        AppDatabaseService.boxCampaignProfiles,
        {
          '$profileKeyPrefix${profile.id}': jsonStr,
          profileIndexKey: idList,
        },
      );
    } catch (e) {
      LoggingService().logWarning('Failed to persist campaign profile: $e', e);
      rethrow;
    }
  }

  Future<void> _persistIndex() async {
    try {
      final idList = _currentIndexList;
      await _db.put(
        AppDatabaseService.boxCampaignProfiles,
        profileIndexKey,
        idList,
      );
    } catch (e) {
      LoggingService().logWarning('Failed to persist campaign index: $e', e);
      rethrow;
    }
  }
}
