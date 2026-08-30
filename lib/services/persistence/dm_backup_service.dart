import 'dart:convert';
import '../../models/campaign_profile.dart';
import '../../models/custom_preset.dart';
import '../../models/domain/dm_backup_models.dart';
import '../../models/domain/spell_monster_equipment.dart';
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

  /// Validates a raw JSON payload before attempting hydration.
  ImportValidationReport validatePayload(String rawJson) {
    final clean = rawJson.trim();
    if (clean.isEmpty) {
      return const ImportValidationReport(
        status: ImportValidationStatus.corrupt,
        errors: ['Import payload is empty.'],
      );
    }

    if (clean.length > 10000000) {
      return const ImportValidationReport(
        status: ImportValidationStatus.corrupt,
        errors: ['Import payload exceeds 10MB limit.'],
      );
    }

    try {
      final decoded = json.decode(clean);
      if (decoded is! Map<String, dynamic>) {
        return const ImportValidationReport(
          status: ImportValidationStatus.corrupt,
          errors: ['Root JSON structure must be a JSON object.'],
        );
      }

      final schemaVer = (decoded['schemaVersion'] as num?)?.toInt() ?? 1;
      final appVer = decoded['appVersion']?.toString() ?? '1.0.0';
      final type = decoded['type']?.toString() ??
          (decoded.containsKey('campaignProfiles')
              ? 'full_system_snapshot'
              : (decoded.containsKey('campaign') || decoded.containsKey('roomState')
                  ? 'campaign_profile'
                  : 'unknown'));

      final warnings = <String>[];
      final errors = <String>[];

      if (schemaVer > currentSchemaVersion) {
        warnings.add('Payload schema version ($schemaVer) is newer than current ($currentSchemaVersion).');
      }

      if (type == 'campaign_profile') {
        if (!decoded.containsKey('campaign') && (!decoded.containsKey('id') || !decoded.containsKey('name'))) {
          errors.add('Missing campaign payload fields.');
        }
      } else if (type == 'full_system_snapshot') {
        if (!decoded.containsKey('campaignProfiles')) {
          errors.add('Missing campaignProfiles array in system snapshot.');
        }
      } else {
        warnings.add('Unrecognized payload type "$type". Attempting fallback parsing.');
      }

      final status = errors.isNotEmpty
          ? ImportValidationStatus.corrupt
          : (warnings.isNotEmpty
              ? ImportValidationStatus.validWithWarnings
              : ImportValidationStatus.valid);

      return ImportValidationReport(
        status: status,
        schemaVersion: schemaVer,
        appVersion: appVer,
        payloadType: type,
        warnings: warnings,
        errors: errors,
      );
    } catch (e) {
      return ImportValidationReport(
        status: ImportValidationStatus.corrupt,
        errors: ['JSON parse error: $e'],
      );
    }
  }

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

  /// Triggers a 1-click full system master backup download.
  Future<bool> downloadFullSystemBackup() async {
    final jsonContent = await exportFullSystemSnapshot();
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final filename = 'dn5e_master_backup_$dateStr.json';

    return await CampaignFileDownloader.downloadJsonFile(jsonContent, filename);
  }

  /// Safely hydrates, validates, and persists an imported campaign profile from raw JSON string.
  /// Returns the imported [CampaignProfile] on success, or `null` if invalid.
  Future<CampaignProfile?> validateAndImportProfile(String rawJson) async {
    try {
      final report = validatePayload(rawJson);
      if (!report.isValid) {
        LoggingService().logWarning('Validation failed for imported campaign snapshot: ${report.errors}');
        return null;
      }

      final decoded = json.decode(rawJson.trim()) as Map<String, dynamic>;
      Map<String, dynamic> campaignMap;

      if (decoded.containsKey('campaign') && decoded['campaign'] is Map) {
        campaignMap = Map<String, dynamic>.from(decoded['campaign'] as Map);
      } else if (decoded.containsKey('id') && decoded.containsKey('name')) {
        campaignMap = decoded;
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

  /// Restores a full system master snapshot bundle into local persistent storage.
  Future<bool> restoreFullSystemSnapshot(String rawJson) async {
    try {
      final report = validatePayload(rawJson);
      if (!report.isValid || !report.isFullSystemSnapshot) {
        LoggingService().logWarning('Snapshot validation failed: ${report.errors}');
        return false;
      }

      final decoded = json.decode(rawJson.trim()) as Map<String, dynamic>;

      // 1. Restore Campaigns
      final campaignService = CampaignProfileService();
      final profilesArr = decoded['campaignProfiles'] as List? ?? [];
      for (final p in profilesArr) {
        if (p is Map<String, dynamic>) {
          try {
            final profile = CampaignProfile.fromMap(p);
            await campaignService.saveProfileImmediate(profile);
          } catch (_) {}
        }
      }

      // 2. Restore Custom Presets
      final presetService = PresetService();
      final presetsArr = decoded['dicePresets'] as List? ?? [];
      for (final pr in presetsArr) {
        if (pr is Map<String, dynamic>) {
          try {
            final preset = CustomPreset.fromMap(pr);
            await presetService.savePreset(preset);
          } catch (_) {}
        }
      }

      // 3. Restore DPR Builds
      final dprService = DprPersistenceService();
      final dprArr = decoded['dprProfiles'] as List? ?? [];
      for (final d in dprArr) {
        if (d is Map<String, dynamic>) {
          try {
            final dprProfile = DprCombatantProfileSerialization.fromMap(d);
            await dprService.saveProfileToLibrary(dprProfile);
          } catch (_) {}
        }
      }

      // 4. Restore Homebrew Entities
      final homebrewService = HomebrewPersistenceService();
      if (decoded['customSpells'] is List) {
        final spells = (decoded['customSpells'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => Spell.fromMap(m))
            .toList();
        await homebrewService.saveCustomSpellsBatch(spells);
      }

      if (decoded['customMonsters'] is List) {
        final monsters = (decoded['customMonsters'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => Monster.fromMap(m))
            .toList();
        await homebrewService.saveCustomMonstersBatch(monsters);
      }

      if (decoded['customItems'] is List) {
        final items = (decoded['customItems'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => EquipmentItem.fromMap(m))
            .toList();
        await homebrewService.saveCustomItemsBatch(items);
      }

      await homebrewService.syncToLibraries();
      return true;
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to restore full system backup',
      );
      return false;
    }
  }
}
