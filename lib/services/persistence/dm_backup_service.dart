import 'dart:convert';
import '../../models/campaign_profile.dart';
import '../../models/custom_preset.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/dm_backup_models.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/dpr/dpr_serialization.dart';
import '../../utils/campaign_file_downloader.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../fluff/entity_fluff_service.dart';
import '../logging_service.dart';
import '../preset_service.dart';
import 'campaign_profile_service.dart';
import 'character_persistence_service.dart';
import 'dpr_persistence_service.dart';
import 'homebrew_persistence_service.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../infrastructure/di/injection_container.dart';

/// Pure helper identifying all timestamp paths in [profile] that strictly exceed
/// [nowMs] + [maxFutureDrift]. Returns a list of offending property paths.
List<String> futureTimestampViolations(
  CampaignProfile profile,
  int nowMs,
  dynamic maxFutureDrift,
) {
  final int driftMs = maxFutureDrift is Duration
      ? maxFutureDrift.inMilliseconds
      : (maxFutureDrift as num).toInt();
  final limit = nowMs + driftMs;

  final allTimestamps = extractCampaignProfileTimestamps(profile);
  if (!allTimestamps.any((ts) => ts.physicalTime > limit)) {
    return const [];
  }

  final violations = <String>[];
  if (profile.nameRegister.timestamp.physicalTime > limit) {
    violations.add('nameRegister');
  }
  if (profile.notesRegister.timestamp.physicalTime > limit) {
    violations.add('notesRegister');
  }
  if (profile.pinnedRules.extractTimestamps().any((ts) => ts.physicalTime > limit)) {
    violations.add('pinnedRules');
  }
  if (profile.partyRoster.extractTimestamps().any((ts) => ts.physicalTime > limit)) {
    violations.add('partyRoster');
  }
  final room = profile.roomState;
  if (room.titleRegister.timestamp.physicalTime > limit) {
    violations.add('roomState.titleRegister');
  }
  if (room.descriptionRegister.timestamp.physicalTime > limit) {
    violations.add('roomState.descriptionRegister');
  }
  if (room.entityLinksCrdt.extractTimestamps().any((ts) => ts.physicalTime > limit)) {
    violations.add('roomState.entityLinksCrdt');
  }
  for (final inst in room.entityInstances) {
    if (inst.displayNameRegister.timestamp.physicalTime > limit) {
      violations.add('roomState.entityInstances[${inst.instanceId}].displayNameRegister');
    }
  }
  for (final cont in room.containers) {
    if (cont.nameRegister.timestamp.physicalTime > limit) {
      violations.add('roomState.containers[${cont.containerId}].nameRegister');
    }
  }
  if (room.activeMinions.extractTimestamps().any((ts) => ts.physicalTime > limit)) {
    violations.add('roomState.activeMinions');
  }
  if (room.activeEncounter.extractTimestamps().any((ts) => ts.physicalTime > limit)) {
    violations.add('roomState.activeEncounter');
  }

  if (violations.isEmpty) {
    violations.add('unknownFutureTimestamp');
  }

  return violations;
}

/// Service coordinating campaign profile JSON snapshots and system-wide backup bundles.
class DmBackupService {
  static const int currentSchemaVersion = 1;
  static const String currentAppVersion = '1.0.0';

  static final DmBackupService _instance = DmBackupService._internal();
  factory DmBackupService({StatefulHlcClock? clock}) {
    if (clock != null) {
      return DmBackupService._internal(clock: clock);
    }
    return _instance;
  }
  DmBackupService._internal({StatefulHlcClock? clock}) : _clock = clock;

  final StatefulHlcClock? _clock;

  StatefulHlcClock get _effectiveClock {
    if (_clock != null) return _clock!;
    if (sl.isRegistered<StatefulHlcClock>()) {
      return sl<StatefulHlcClock>();
    }
    throw StateError(
      'Authoritative StatefulHlcClock is required for DmBackupService. '
      'Register StatefulHlcClock in DI or pass clock explicitly.',
    );
  }

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
              : (decoded.containsKey('campaign') ||
                      decoded.containsKey('roomState')
                  ? 'campaign_profile'
                  : 'unknown'));

      final warnings = <String>[];
      final errors = <String>[];

      if (schemaVer > currentSchemaVersion) {
        errors.add(
            'Payload schema version ($schemaVer) is newer than current ($currentSchemaVersion).');
      }

      if (type == 'campaign_profile') {
        if (!decoded.containsKey('campaign') &&
            (!decoded.containsKey('id') || !decoded.containsKey('name'))) {
          errors.add('Missing campaign payload fields.');
        }
      } else if (type == 'full_system_snapshot') {
        if (!decoded.containsKey('campaignProfiles')) {
          errors.add('Missing campaignProfiles array in system snapshot.');
        }
      } else {
        warnings.add(
            'Unrecognized payload type "$type". Attempting fallback parsing.');
      }

      final status = schemaVer > currentSchemaVersion
          ? ImportValidationStatus.incompatibleVersion
          : (errors.isNotEmpty
              ? ImportValidationStatus.corrupt
              : (warnings.isNotEmpty
                  ? ImportValidationStatus.validWithWarnings
                  : ImportValidationStatus.valid));

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
      'campaign': CampaignProfileDto.fromDomain(profile).toMap(),
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
    final filename =
        'dn5e_campaign_${slug.isNotEmpty ? slug : "profile"}_$dateStr.json';

    return await CampaignFileDownloader.downloadJsonFile(jsonContent, filename);
  }

  /// Packages all saved campaigns, dice presets, DPR builds, and homebrew compendium entities into a master bundle.
  Future<String> exportFullSystemSnapshot() async {
    final campaignService = CampaignProfileService();
    final List<CampaignProfile> allProfiles;
    try {
      allProfiles = await campaignService.loadAllProfiles();
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to read campaigns during system backup export',
      );
      rethrow;
    }
    final customPresets = await PresetService().loadCustomPresets();
    final dprProfiles = await DprPersistenceService().loadSavedProfiles();
    final customSpells = await HomebrewPersistenceService().loadCustomSpells();
    final customMonsters =
        await HomebrewPersistenceService().loadCustomMonsters();
    final customItems = await HomebrewPersistenceService().loadCustomItems();
    final loadedClasses =
        await HomebrewPersistenceService().loadCustomClasses();
    final classesMap = <String, CharacterClass>{
      for (final c in SrdClassesLibrary.customClasses) c.id.slug: c,
      for (final c in loadedClasses) c.id.slug: c,
    };
    final customClasses = classesMap.values.toList();

    final loadedSubclasses =
        await HomebrewPersistenceService().loadCustomSubclasses();
    final subclassesMap = <String, Subclass>{
      for (final s in SrdClassesLibrary.customSubclasses) s.id.slug: s,
      for (final s in loadedSubclasses) s.id.slug: s,
      for (final c in customClasses)
        for (final s in c.subclasses) s.id.slug: s,
    };
    final customSubclasses = subclassesMap.values.toList();

    final loadedRaces = await HomebrewPersistenceService().loadCustomRaces();
    final racesMap = <String, Race>{
      for (final r in SrdSpeciesLibrary.customSpecies) r.id.slug: r,
      for (final r in loadedRaces) r.id.slug: r,
    };
    final customRaces = racesMap.values.toList();

    final standaloneSubs =
        await HomebrewPersistenceService().loadCustomSubraces();
    final subracesMap = <String, Subrace>{
      for (final s in SrdSpeciesLibrary.customSubraces) s.id.slug: s,
      for (final s in standaloneSubs) s.id.slug: s,
      for (final r in customRaces)
        for (final s in r.subraces) s.id.slug: s,
    };
    final customSubraces = subracesMap.values.toList();

    final loadedFeats = await HomebrewPersistenceService().loadCustomFeats();
    final featsMap = <String, Feat>{
      for (final f in SrdFeatsLibrary.customFeats) f.id.slug: f,
      for (final f in loadedFeats) f.id.slug: f,
    };
    final customFeats = featsMap.values.toList();

    final loadedBackgrounds =
        await HomebrewPersistenceService().loadCustomBackgrounds();
    final backgroundsMap = <String, Background>{
      for (final b in SrdBackgroundsLibrary.customBackgrounds) b.id.slug: b,
      for (final b in loadedBackgrounds) b.id.slug: b,
    };
    final customBackgrounds = backgroundsMap.values.toList();

    final customOthers =
        await HomebrewPersistenceService().loadCustomOtherEntries();

    final storedFluff = await HomebrewPersistenceService().loadCustomFluff();
    final memoryFluff = EntityFluffService().getAllFluff();
    final fluffMap = <String, EntityFluff>{
      for (final f in storedFluff) '${f.entityType}_${f.slug}': f,
      for (final f in memoryFluff) '${f.entityType}_${f.slug}': f,
    };
    final customFluff = fluffMap.values.toList();

    final payload = {
      'schemaVersion': currentSchemaVersion,
      'appVersion': currentAppVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'type': 'full_system_snapshot',
      'campaignProfiles': allProfiles
          .map((p) => CampaignProfileDto.fromDomain(p).toMap())
          .toList(),
      'dicePresets': customPresets.map((p) => p.toMap()).toList(),
      'dprProfiles': dprProfiles.map((p) => p.toMap()).toList(),
      'customSpells': customSpells.map((s) => s.toMap()).toList(),
      'customMonsters': customMonsters.map((m) => m.toMap()).toList(),
      'customItems': customItems.map((i) => i.toMap()).toList(),
      'customClasses': customClasses.map((c) => c.toMap()).toList(),
      'customSubclasses': customSubclasses.map((s) => s.toMap()).toList(),
      'customRaces': customRaces.map((r) => r.toMap()).toList(),
      'customSubraces': customSubraces.map((s) => s.toMap()).toList(),
      'customFeats': customFeats.map((f) => f.toMap()).toList(),
      'customBackgrounds': customBackgrounds.map((b) => b.toMap()).toList(),
      'customOtherEntries': customOthers.map((o) => o.toMap()).toList(),
      if (customFluff.isNotEmpty)
        'customFluff': customFluff.map((f) => f.toMap()).toList(),
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
  Future<CampaignProfile?> validateAndImportProfile(
    String rawJson, {
    StatefulHlcClock? clock,
    int? nowMs,
  }) async {
    try {
      final report = validatePayload(rawJson);
      if (!report.isValid) {
        LoggingService().logWarning(
            'Validation failed for imported campaign snapshot: ${report.errors}');
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

      final profile = CampaignProfileDto.fromMap(campaignMap).toDomain();
      final effectiveClock = clock ?? _effectiveClock;
      final currentNow = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
      final violations = futureTimestampViolations(
        profile,
        currentNow,
        effectiveClock.maxFutureDrift,
      );
      if (violations.isNotEmpty) {
        LoggingService().logWarning(
          'Validation failed for imported campaign snapshot: future timestamp violations at ${violations.join(', ')}',
        );
        return null;
      }

      final legacyChars =
          CampaignProfileDto.extractLegacyCharacters(campaignMap);
      if (legacyChars.isNotEmpty) {
        await CharacterPersistenceService().saveCharacters(legacyChars);
      }
      // Ensure unique ID on import to prevent accidental key collisions with active games
      final now = DateTime.now();
      final bool needsDefaultName = profile.name.isEmpty;
      final targetName = needsDefaultName ? 'Imported Campaign' : profile.name;
      final timestamp = needsDefaultName
          ? effectiveClock.nextTimestamp()
          : profile.nameRegister.timestamp;
      final sanitizedProfile = profile.copyWith(
        id: 'campaign_imported_${now.millisecondsSinceEpoch}',
        name: targetName,
        nameTimestamp: timestamp,
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
        reason:
            'Safe hydration error while importing campaign profile snapshot',
      );
      return null;
    }
  }

  /// Restores a full system master snapshot bundle into local persistent storage.
  Future<bool> restoreFullSystemSnapshot(
    String rawJson, {
    StatefulHlcClock? clock,
    int? nowMs,
  }) async {
    try {
      final report = validatePayload(rawJson);
      if (!report.isValid || !report.isFullSystemSnapshot) {
        LoggingService()
            .logWarning('Snapshot validation failed: ${report.errors}');
        return false;
      }

      final decoded = json.decode(rawJson.trim()) as Map<String, dynamic>;
      final effectiveClock = clock ?? _effectiveClock;
      final currentNow = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;

      // 1. Restore Campaigns
      final campaignService = CampaignProfileService();
      final profilesArr = decoded['campaignProfiles'] as List? ?? [];
      bool anyCampaignFailed = false;
      for (final p in profilesArr) {
        if (p is Map<String, dynamic>) {
          final campaignId = p['id']?.toString() ?? 'unknown';
          try {
            final profile = CampaignProfileDto.fromMap(p).toDomain();
            final violations = futureTimestampViolations(
              profile,
              currentNow,
              effectiveClock.maxFutureDrift,
            );
            if (violations.isNotEmpty) {
              anyCampaignFailed = true;
              LoggingService().logWarning(
                'Skipping campaign profile $campaignId with future timestamps: ${violations.join(', ')}',
              );
              continue;
            }
            await campaignService.saveProfileImmediate(profile);
          } catch (e, st) {
            anyCampaignFailed = true;
            LoggingService().logNonFatal(
              e,
              st,
              reason:
                  'Failed to restore campaign profile $campaignId in full system snapshot',
            );
          }
        }
      }

      // 2. Restore Custom Presets
      final presetService = PresetService();
      final presetsArr = decoded['dicePresets'] as List? ?? [];
      for (int i = 0; i < presetsArr.length; i++) {
        final pr = presetsArr[i];
        if (pr is Map<String, dynamic>) {
          try {
            final preset = CustomPreset.fromMap(pr);
            await presetService.savePreset(preset);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason:
                  'Failed to restore dice preset at index $i in system snapshot',
            );
          }
        }
      }

      // 3. Restore DPR Builds
      final dprService = DprPersistenceService();
      final dprArr = decoded['dprProfiles'] as List? ?? [];
      for (int i = 0; i < dprArr.length; i++) {
        final d = dprArr[i];
        if (d is Map<String, dynamic>) {
          try {
            final dprProfile = DprCombatantProfileSerialization.fromMap(d);
            await dprService.saveProfileToLibrary(dprProfile);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason:
                  'Failed to restore DPR profile at index $i in system snapshot',
            );
          }
        }
      }

      // 4. Restore Homebrew Entities
      final homebrewService = HomebrewPersistenceService();
      if (decoded['customSpells'] is List) {
        final spells = (decoded['customSpells'] as List)
            .whereType<Map>()
            .map((m) => Spell.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomSpellsBatch(spells);
      }

      if (decoded['customMonsters'] is List) {
        final monsters = (decoded['customMonsters'] as List)
            .whereType<Map>()
            .map((m) => Monster.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomMonstersBatch(monsters);
      }

      if (decoded['customItems'] is List) {
        final items = (decoded['customItems'] as List)
            .whereType<Map>()
            .map((m) => EquipmentItem.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomItemsBatch(items);
      }

      if (decoded['customClasses'] is List) {
        final classes = (decoded['customClasses'] as List)
            .whereType<Map>()
            .map((m) => CharacterClass.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomClassesBatch(classes);
      }

      if (decoded['customSubclasses'] is List) {
        final subclasses = (decoded['customSubclasses'] as List)
            .whereType<Map>()
            .map((m) => Subclass.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomSubclassesBatch(subclasses);
      }

      if (decoded['customRaces'] is List) {
        final races = (decoded['customRaces'] as List)
            .whereType<Map>()
            .map((m) => Race.fromMap(Map<String, dynamic>.from(m)))
            .toList();

        if (decoded['customSubraces'] is List) {
          final subraces = (decoded['customSubraces'] as List)
              .whereType<Map>()
              .map((m) => Subrace.fromMap(Map<String, dynamic>.from(m)))
              .toList();
          if (subraces.isNotEmpty) {
            final knownSlugs =
                races.map((r) => r.id.slug.toLowerCase()).toSet();
            for (int i = 0; i < races.length; i++) {
              final race = races[i];
              final existingSubSlugs =
                  race.subraces.map((s) => s.id.slug.toLowerCase()).toSet();
              final matchingSubs = subraces.where(
                (s) =>
                    s.raceSlug.toLowerCase() == race.id.slug.toLowerCase() &&
                    !existingSubSlugs.contains(s.id.slug.toLowerCase()),
              );
              if (matchingSubs.isNotEmpty) {
                races[i] = race
                    .copyWith(subraces: [...race.subraces, ...matchingSubs]);
              }
            }
            final orphanSubsByRace = <String, List<Subrace>>{};
            for (final sub in subraces) {
              final slug = sub.raceSlug.toLowerCase();
              if (!knownSlugs.contains(slug)) {
                orphanSubsByRace.putIfAbsent(slug, () => []).add(sub);
              }
            }
            for (final entry in orphanSubsByRace.entries) {
              final raceName =
                  entry.value.first.customProperties['raceName']?.toString() ??
                      entry.value.first.customProperties['race']?.toString() ??
                      entry.key
                          .split('-')
                          .map((w) => w.isNotEmpty
                              ? '${w[0].toUpperCase()}${w.substring(1)}'
                              : '')
                          .join(' ');
              races.add(
                Race(
                  id: EntityId(
                      slug: entry.key, ruleset: entry.value.first.id.ruleset),
                  name: raceName.isNotEmpty ? raceName : 'Base Race',
                  traitsMarkdown: '',
                  subraces: entry.value,
                  customProperties: const {'isShellForSubrace': true},
                ),
              );
            }
            await homebrewService.saveCustomSubracesBatch(subraces);
          }
        }
        await homebrewService.saveCustomRacesBatch(races);
      }

      if (decoded['customFeats'] is List) {
        final feats = (decoded['customFeats'] as List)
            .whereType<Map>()
            .map((m) => Feat.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomFeatsBatch(feats);
      }

      if (decoded['customBackgrounds'] is List) {
        final backgrounds = (decoded['customBackgrounds'] as List)
            .whereType<Map>()
            .map((m) => Background.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomBackgroundsBatch(backgrounds);
      }

      if (decoded['customOtherEntries'] is List) {
        final otherEntries = (decoded['customOtherEntries'] as List)
            .whereType<Map>()
            .map((m) =>
                HomebrewCompendiumEntry.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        await homebrewService.saveCustomOtherEntriesBatch(otherEntries);
      }

      if (decoded['customFluff'] is List) {
        final fluffItems = (decoded['customFluff'] as List)
            .whereType<Map>()
            .map((m) => EntityFluff.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        if (fluffItems.isNotEmpty) {
          await homebrewService.saveCustomFluffBatch(fluffItems);
          EntityFluffService().batchRegisterFluff(fluffItems);
        }
      }

      await homebrewService.syncToLibraries();
      return !anyCampaignFailed;
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
