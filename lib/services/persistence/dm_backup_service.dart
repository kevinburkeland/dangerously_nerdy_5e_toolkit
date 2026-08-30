import 'dart:convert';
import '../../models/campaign_profile.dart';
import '../../models/dpr/dpr_serialization.dart';
import '../../utils/campaign_file_downloader.dart';
import '../logging_service.dart';
import '../preset_service.dart';
import 'campaign_profile_service.dart';
import 'dpr_persistence_service.dart';
import 'homebrew_persistence_service.dart';

/// Service coordinating campaign profile JSON snapshots and system-wide backup bundles.
class DmBackupService {
  static const int currentSchemaVersion = 1;
  static const String currentAppVersion = '1.0.0';

  static final DmBackupService _instance = DmBackupService._internal();
  factory DmBackupService() => _instance;
  DmBackupService._internal();

  /// Packages a single [CampaignProfile] into a validated envelope format.
  String exportProfileJson(CampaignProfile profile) {
    final payload = {
      'schemaVersion': currentSchemaVersion,
      'appVersion': currentAppVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'type': 'campaign_profile',
      'campaign': profile.toMap(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Triggers a 1-click snapshot download with automated slugified naming.
  Future<bool> downloadProfileSnapshot(CampaignProfile profile) async {
    final jsonContent = exportProfileJson(profile);
    final slug = profile.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final filename = 'dn5e_campaign_${slug.isNotEmpty ? slug : "profile"}_$dateStr.json';

    return await CampaignFileDownloader.downloadJsonFile(jsonContent, filename);
  }

  /// Packages all saved campaigns, dice presets, DPR builds, and homebrew compendium entities into a master bundle.
  Future<String> exportFullSystemSnapshot() async {
    final campaignService = CampaignProfileService();
    final allProfiles = await campaignService.loadAllProfiles();
    final customPresets = await PresetService().loadCustomPresets();
    final dprProfiles = await DprPersistenceService().loadSavedProfiles();
    final customSpells = await HomebrewPersistenceService().loadCustomSpells();
    final customMonsters = await HomebrewPersistenceService().loadCustomMonsters();
    final customItems = await HomebrewPersistenceService().loadCustomItems();

    final payload = {
      'schemaVersion': currentSchemaVersion,
      'appVersion': currentAppVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'type': 'full_system_snapshot',
      'campaignProfiles': allProfiles.map((p) => p.toMap()).toList(),
      'dicePresets': customPresets.map((p) => p.toMap()).toList(),
      'dprProfiles': dprProfiles.map((p) => p.toMap()).toList(),
      'customSpells': customSpells.map((s) => s.toMap()).toList(),
      'customMonsters': customMonsters.map((m) => m.toMap()).toList(),
      'customItems': customItems.map((i) => i.toMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Safely hydrates, validates, and persists an imported campaign profile from raw JSON string.
  /// Returns the imported [CampaignProfile] on success, or `null` if invalid.
  Future<CampaignProfile?> validateAndImportProfile(String rawJson) async {
    try {
      final clean = rawJson.trim();
      if (clean.isEmpty || clean.length > 5000000) {
        LoggingService().logWarning('Import payload empty or exceeds 5MB size limit');
        return null;
      }

      final decoded = json.decode(clean);
      if (decoded is! Map) {
        LoggingService().logWarning('Invalid JSON root format: Expected object map');
        return null;
      }

      final rootMap = Map<String, dynamic>.from(decoded);
      Map<String, dynamic> campaignMap;

      if (rootMap.containsKey('campaign') && rootMap['campaign'] is Map) {
        campaignMap = Map<String, dynamic>.from(rootMap['campaign'] as Map);
      } else if (rootMap.containsKey('id') && rootMap.containsKey('name')) {
        campaignMap = rootMap;
      } else {
        LoggingService().logWarning('Missing valid campaign schema in payload');
        return null;
      }

      final profile = CampaignProfile.fromMap(campaignMap);
      // Ensure unique ID on import to prevent accidental key collisions with active games
      final now = DateTime.now();
      final sanitizedProfile = profile.copyWith(
        id: 'campaign_imported_${now.millisecondsSinceEpoch}',
        name: profile.name.isNotEmpty ? profile.name : 'Imported Campaign',
        lastPlayedAt: now,
      );

      final campaignService = CampaignProfileService();
      await campaignService.saveProfileImmediate(sanitizedProfile);
      await campaignService.switchProfile(sanitizedProfile.id);

      return sanitizedProfile;
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Safe hydration error while importing campaign profile snapshot',
      );
      return null;
    }
  }
}
