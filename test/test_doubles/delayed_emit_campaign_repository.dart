import 'dart:async';
import 'package:vtt_engine_core/vtt_engine_core.dart';

class DelayedEmitCampaignRepository implements ICampaignRepository {
  final Map<String, CampaignProfile> profiles = {};
  CampaignProfile? _activeProfile;
  final _activeController = StreamController<CampaignProfile?>.broadcast();
  final _allController = StreamController<List<CampaignProfile>>.broadcast();

  Duration futureDelay;
  Duration emitDelay;
  Duration Function()? futureDelayProvider;
  Duration Function()? emitDelayProvider;
  Object? nextUpdateError;
  void Function(CampaignProfile current)? onBeforeTransform;

  int inFlightWrites = 0;
  int pendingEmits = 0;
  int serviceWritesCount = 0;

  bool get isIdle => inFlightWrites == 0 && pendingEmits == 0;

  DelayedEmitCampaignRepository([
    CampaignProfile? initialActive,
    this.futureDelay = Duration.zero,
    this.emitDelay = Duration.zero,
  ]) {
    if (initialActive != null) {
      profiles[initialActive.id] = initialActive;
      _activeProfile = initialActive;
    }
  }

  @override
  CampaignProfile? get activeProfile => _activeProfile;

  @override
  String? get activeProfileId => _activeProfile?.id;

  @override
  List<CampaignProfile> get allProfiles => profiles.values.toList();

  @override
  Future<List<CampaignProfile>> loadAllProfiles() async => allProfiles;

  @override
  Future<CampaignProfile?> getProfile(String id) async => profiles[id];

  @override
  Future<CampaignProfile?> getActiveProfile() async => _activeProfile;

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    profiles[profile.id] = profile;
    if (_activeProfile?.id == profile.id || _activeProfile == null) {
      _activeProfile = profile;
      _activeController.add(profile);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    if (nextUpdateError != null) {
      final err = nextUpdateError!;
      nextUpdateError = null;
      throw err;
    }

    final current = profiles[id];
    if (current == null) throw StateError('Profile not found: $id');
    if (onBeforeTransform != null) {
      final hook = onBeforeTransform!;
      onBeforeTransform = null;
      hook(profiles[id]!);
    }
    final updated = transform(profiles[id]!);
    if (!identical(updated, current) &&
        updated.mapGridRegister.timestamp != current.mapGridRegister.timestamp) {
      serviceWritesCount++;
    }
    profiles[id] = updated;
    if (_activeProfile?.id == id || _activeProfile == null) {
      _activeProfile = updated;
    }

    final fDelay = futureDelayProvider != null ? futureDelayProvider!() : futureDelay;
    final eDelay = emitDelayProvider != null ? emitDelayProvider!() : emitDelay;

    pendingEmits++;
    Timer(eDelay, () {
      pendingEmits--;
      if (!_activeController.isClosed) {
        _activeController.add(_activeProfile);
      }
    });

    inFlightWrites++;
    final completer = Completer<CampaignProfile>();
    Timer(fDelay, () {
      inFlightWrites--;
      completer.complete(updated);
    });

    return completer.future;
  }

  @override
  Future<void> deleteProfile(String id) async {
    profiles.remove(id);
    if (_activeProfile?.id == id) {
      _activeProfile = null;
      _activeController.add(null);
    }
    _allController.add(allProfiles);
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfile = profiles[id];
    _activeController.add(_activeProfile);
  }

  @override
  Stream<CampaignProfile?> watchActiveProfile() => _activeController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() => _allController.stream;
}
