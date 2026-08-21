import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dpr/dpr_models.dart';
import '../../models/dpr/dpr_serialization.dart';
import '../logging_service.dart';
import 'debounced_storage_service.dart';

class DprActiveDraftState {
  final DprCombatantProfile profile;
  final int selectedAc;
  final DprChartMode chartMode;
  final bool anythingGoesMode;

  const DprActiveDraftState({
    required this.profile,
    this.selectedAc = 15,
    this.chartMode = DprChartMode.dpr,
    this.anythingGoesMode = false,
  });

  Map<String, dynamic> toMap() => {
        'profile': profile.toMap(),
        'selectedAc': selectedAc,
        'chartMode': chartMode.name,
        'anythingGoesMode': anythingGoesMode,
      };

  factory DprActiveDraftState.fromMap(Map<String, dynamic> map) {
    final profileMap = Map<String, dynamic>.from(map['profile'] as Map? ?? {});
    final chartModeName = map['chartMode']?.toString() ?? 'dpr';
    return DprActiveDraftState(
      profile: DprCombatantProfileSerialization.fromMap(profileMap),
      selectedAc: (map['selectedAc'] as num?)?.toInt() ?? 15,
      chartMode: DprChartMode.values.firstWhere(
        (e) => e.name == chartModeName,
        orElse: () => DprChartMode.dpr,
      ),
      anythingGoesMode: map['anythingGoesMode'] as bool? ?? false,
    );
  }
}

class DprPersistenceService {
  static const String _kSavedProfilesKey = 'dpr_saved_custom_profiles_v1';
  static const String _kActiveDraftKey = 'dpr_active_draft_state_v1';

  static final DprPersistenceService _instance = DprPersistenceService._internal();
  factory DprPersistenceService() => _instance;
  DprPersistenceService._internal();

  /// Loads the active transient draft state if one was saved before app exit
  Future<DprActiveDraftState?> loadActiveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString(_kActiveDraftKey);
      if (draftJson != null && draftJson.isNotEmpty) {
        final decoded = json.decode(draftJson) as Map<String, dynamic>;
        return DprActiveDraftState.fromMap(decoded);
      }
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to hydrate active DPR draft state',
      );
    }
    return null;
  }

  /// Debounces saving the active draft profile and calculator settings
  void saveActiveDraftDebounced(DprActiveDraftState state) {
    DebouncedStorageService().scheduleWrite('dpr_active_draft', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveDraftKey, json.encode(state.toMap()));
    });
  }

  /// Clears the active draft
  Future<void> clearActiveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveDraftKey);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to clear active DPR draft',
      );
    }
  }

  /// Loads all saved custom character profiles
  Future<List<DprCombatantProfile>> loadSavedProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kSavedProfilesKey) ?? [];
      return list
          .map((item) => DprCombatantProfileSerialization.fromJson(item))
          .toList();
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to load saved DPR profiles library',
      );
      return [];
    }
  }

  /// Saves a profile to the library
  Future<List<DprCombatantProfile>> saveProfileToLibrary(DprCombatantProfile profile) async {
    final current = await loadSavedProfiles();
    current.removeWhere((p) => p.id == profile.id);
    current.insert(0, profile);

    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = current.map((p) => p.toJson()).toList();
      await prefs.setStringList(_kSavedProfilesKey, stringList);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to save DPR profile to library',
      );
    }
    return current;
  }

  /// Deletes a profile from the library
  Future<List<DprCombatantProfile>> deleteProfileFromLibrary(String id) async {
    final current = await loadSavedProfiles();
    current.removeWhere((p) => p.id == id);

    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = current.map((p) => p.toJson()).toList();
      await prefs.setStringList(_kSavedProfilesKey, stringList);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to delete DPR profile from library',
      );
    }
    return current;
  }
}
