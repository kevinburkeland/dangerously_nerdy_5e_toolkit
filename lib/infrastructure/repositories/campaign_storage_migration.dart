import 'dart:convert';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/rules/ruleset_edition.dart';

import '../../models/domain/character_models.dart';
import '../../services/logging_service.dart';
import '../../models/party/campaign_membership.dart';
import '../../services/party/campaign_registry_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../../services/persistence/character_persistence_service.dart';
import '../di/injection_container.dart';
import '../dtos/campaign_profile_dto.dart';
import 'local_campaign_repository.dart';

/// Centralized migration engine for legacy campaign storage schemas and registry adoption.
///
/// Ensures:
/// 1. Legacy embedded character records are extracted into [CharacterPersistenceService]
///    and rewritten via [ICampaignRepository.updateProfile] prior to any application writes.
/// 2. Campaign registry memberships missing corresponding DM profiles are adopted into
///    the repository via [ICampaignRepository.putProfile].
/// 3. Idempotent execution: multiple runs leave valid profiles untouched.
/// 4. Failure resilience (F1): exceptions leave stored records unchanged without synthesizing defaults.
class CampaignStorageMigration {
  /// Runs the full startup migration sequence: legacy character extraction followed by registry adoption.
  static Future<void> runStartupMigration({
    ICampaignRepository? repository,
    AppDatabaseService? databaseService,
    CharacterPersistenceService? characterPersistenceService,
    CampaignRegistryService? registryService,
    StatefulHlcClock? clock,
    String? nodeId,
  }) async {
    final repo = repository ?? (sl.isRegistered<ICampaignRepository>() ? sl<ICampaignRepository>() : null);
    if (repo == null) return;

    final db = databaseService ?? AppDatabaseService.instance;
    final charService = characterPersistenceService ?? CharacterPersistenceService();
    final regService = registryService ?? CampaignRegistryService();

    // Ensure storage records are loaded and prefs->hive copy completes
    try {
      await repo.loadAllProfiles();
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason:
            'Failed to read campaign records during startup migration; skipping write steps',
      );
      return;
    }

    // Step 2: Migrate legacy embedded characters before any repository writes
    await migrateLegacyCharacters(
      repo: repo,
      db: db,
      characterPersistenceService: charService,
    );

    // Step 3: Adopt registry memberships
    final clk = clock ?? (sl.isRegistered<StatefulHlcClock>() ? sl<StatefulHlcClock>() : null);
    final nid = nodeId ??
        (clk?.replicaId.value ??
            (sl.isRegistered<ReplicaId>() ? sl<ReplicaId>().value : null));

    if (clk != null && nid != null) {
      await adoptRegistryMemberships(
        repo,
        clock: clk,
        nodeId: nid,
        registryService: regService,
        characterPersistenceService: charService,
      );
    }
  }

  /// Extracts legacy embedded character records from raw stored JSON into [CharacterPersistenceService]
  /// and updates the campaign profile through [ICampaignRepository.updateProfile] to persist the sanitized DTO.
  static Future<void> migrateLegacyCharacters({
    required ICampaignRepository repo,
    required AppDatabaseService db,
    CharacterPersistenceService? characterPersistenceService,
  }) async {
    try {
      final indexRaw = db.get(
        AppDatabaseService.boxCampaignProfiles,
        LocalCampaignRepository.profileIndexKey,
      );
      if (indexRaw is! List) return;

      final charService = characterPersistenceService ?? CharacterPersistenceService();

      for (final rawId in indexRaw) {
        final id = rawId.toString();
        final rawJson = db.get(
          AppDatabaseService.boxCampaignProfiles,
          '${LocalCampaignRepository.profileKeyPrefix}$id',
        )?.toString();

        if (rawJson == null || rawJson.isEmpty) continue;

        try {
          final rawMap = json.decode(rawJson) as Map<String, dynamic>;
          final legacyChars = CampaignProfileDto.extractLegacyCharacters(rawMap);
          if (legacyChars.isNotEmpty) {
            await charService.saveCharacters(legacyChars);
            // Re-write the profile through the repository port to strip embedded characters
            await repo.updateProfile(id, (current) => current);
          }
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Failed to inspect legacy characters in campaign profile: $id',
          );
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to run legacy character extraction migration',
      );
    }
  }

  /// Adopts [CampaignRegistryService] memberships that do not have matching campaign profiles.
  ///
  /// Matching is performed by comparing uppercase room codes or matching id `campaign_<roomCode>`.
  /// Existing profiles are NEVER overwritten.
  static Future<void> adoptRegistryMemberships(
    ICampaignRepository repo, {
    required StatefulHlcClock clock,
    required String nodeId,
    CampaignRegistryService? registryService,
    CharacterPersistenceService? characterPersistenceService,
  }) async {
    try {
      final registry = registryService ??
          (sl.isRegistered<CampaignRegistryService>()
              ? sl<CampaignRegistryService>()
              : null) ??
          CampaignRegistryService();
      final memberships = await registry.loadMemberships();
      if (memberships.isEmpty) return;

      final List<CampaignProfile> existingProfiles;
      try {
        existingProfiles = await repo.loadAllProfiles();
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason:
              'Failed to read campaign records during registry adoption; skipping write steps',
        );
        return;
      }

      final charService = characterPersistenceService ?? CharacterPersistenceService();
      final savedCharacters = await charService.loadCharacters();

      for (final m in memberships) {
        final alreadyExists = existingProfiles.any(
          (p) =>
              p.roomState.roomCode.toUpperCase() == m.roomCode.toUpperCase() ||
              p.id == 'campaign_${m.roomCode}',
        );
        if (!alreadyExists) {
          final entries = <({String id, String item, HybridLogicalClock timestamp})>[];
          if (m.characterId != null && m.characterId!.trim().isNotEmpty) {
            final match = savedCharacters.cast<Character?>().firstWhere(
                  (c) =>
                      c != null &&
                      (c.id.slug.toLowerCase() ==
                              m.characterId!.trim().toLowerCase() ||
                          c.name.trim().toLowerCase() ==
                              m.characterId!.trim().toLowerCase()),
                  orElse: () => null,
                );
            if (match != null) {
              entries.add((
                id: match.id.slug,
                item: match.id.slug,
                timestamp: clock.nextTimestamp(),
              ));
            }
          }
          final partyRoster = entries.isNotEmpty
              ? const CrdtOrSet<String>.empty().addBatch(entries)
              : const CrdtOrSet<String>.empty();

          final isAuthor = m.role == CampaignRole.host;
          final CampaignProfile prof;
          if (isAuthor) {
            final regTs = clock.nextTimestamp();
            prof = CampaignProfile.raw(
              id: 'campaign_${m.roomCode}',
              nameRegister: CrdtLwwRegister<String>(
                value: m.campaignName.trim().isNotEmpty
                    ? m.campaignName.trim()
                    : 'Campaign ${m.roomCode}',
                timestamp: regTs,
              ),
              edition: const RulesetIdentifier('generic_tabletop'),
              createdAt: DateTime.now().toUtc(),
              lastPlayedAt: DateTime.now().toUtc(),
              partyRoster: partyRoster,
              roomState: RoomNodeState(
                roomId: 'room_${m.roomCode}',
                roomCode: m.roomCode,
                title: m.campaignName.trim().isNotEmpty
                    ? '${m.campaignName} Staging Area'
                    : 'Campaign ${m.roomCode} Staging',
                titleTimestamp: regTs,
                description: '',
                descriptionTimestamp: regTs,
              ),
              partyPurse: const PartyPurse.empty(),
              memberPurses: const {},
              pinnedRules: const CrdtOrSet<String>.empty(),
              notesRegister: CrdtLwwRegister<String>(
                value: '',
                timestamp: regTs,
              ),
              changeLog: const [],
            );
          } else {
            prof = CampaignProfile.placeholder(
              id: 'campaign_${m.roomCode}',
              roomCode: m.roomCode,
              name: m.campaignName.trim().isNotEmpty
                  ? m.campaignName.trim()
                  : 'Campaign ${m.roomCode}',
              stagingTitle: m.campaignName.trim().isNotEmpty
                  ? '${m.campaignName} Staging Area'
                  : 'Campaign ${m.roomCode} Staging',
              edition: const RulesetIdentifier('generic_tabletop'),
              createdAt: DateTime.now().toUtc(),
              lastPlayedAt: DateTime.now().toUtc(),
              partyRoster: partyRoster,
            );
          }
          try {
            await repo.putProfile(prof);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason:
                  'Failed to adopt registry membership for campaign_${m.roomCode}',
            );
          }
        }
      }
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to adopt registry memberships into campaign profiles',
      );
    }
  }
}
