import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/pn_counter.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/party_purse.dart';
import '../../infrastructure/dtos/character_telemetry_dto.dart';
import '../../models/party/party_event.dart';

/// Legacy Firestore ledger migration into the single-owner CRDT [CampaignProfile].
///
/// Implements Cold Iron Birdcage Pass 7 (P5):
/// 1. Reads raw scalars from Firestore room document, ignoring counter maps that shadow increments (F1).
/// 2. Idempotent across replicas: all writes use fixed key `legacy-import:<ROOMCODE>`.
/// 3. Resolves member keys (slug vs name) via partyTelemetry.
/// 4. Synchronizes roster, pruning unshared adoption entries.
/// 5. Appends audit entry to profile changeLog.
class PartyLedgerLegacyImport {
  /// Evaluates whether the raw room document holds legacy ledger fields.
  static bool hasLegacyLedgerFields(Map<String, dynamic> rawDoc) {
    return rawDoc.containsKey('partyPurse') ||
        rawDoc.containsKey('memberPurses') ||
        rawDoc.containsKey('characterRoster');
  }

  /// Executes the legacy ledger import transformation on [profile].
  ///
  /// Returns updated [CampaignProfile] or unchanged [profile] if no import needed.
  static CampaignProfile importLegacyLedger({
    required CampaignProfile profile,
    required Map<String, dynamic> rawDoc,
    required StatefulHlcClock clock,
  }) {
    final rawCode = (rawDoc['roomCode'] ?? rawDoc['code'] ?? profile.roomState.roomCode)
        .toString()
        .trim()
        .toUpperCase();
    final importKey = 'legacy-import:$rawCode';

    // 1. Resolve Telemetry mappings (id/slug <-> name)
    final telemetryByName = <String, String>{};
    final telemetryBySlug = <String, String>{};
    if (rawDoc['partyTelemetry'] is Map) {
      final rawTele = Map<String, dynamic>.from(rawDoc['partyTelemetry'] as Map);
      for (final entry in rawTele.entries) {
        if (entry.value is Map) {
          try {
            final dto = CharacterTelemetryDto.fromMap(
                Map<String, dynamic>.from(entry.value as Map));
            final slug = dto.id.trim().toLowerCase();
            final name = dto.name.trim().toLowerCase();
            if (slug.isNotEmpty) {
              telemetryBySlug[slug] = dto.id;
              if (name.isNotEmpty) {
                telemetryByName[name] = dto.id;
              }
            }
          } catch (_) {}
        }
      }
    }

    final auditNotes = <String>[];
    bool mutated = false;

    // 2. Resolve Roster Slugs
    final hasRoster = rawDoc['characterRoster'] is List;
    final resolvedRoomSlugs = <String>{};
    if (hasRoster) {
      final rawRoster =
          (rawDoc['characterRoster'] as List).whereType<String>().toList();
      for (final rawName in rawRoster) {
        final lower = rawName.trim().toLowerCase();
        final resolved =
            telemetryBySlug[lower] ?? telemetryByName[lower] ?? rawName.trim();
        resolvedRoomSlugs.add(resolved);
      }
    }

    // 3. Import Reserve PartyPurse from scalars
    PartyPurse updatedReserve = profile.partyPurse;
    if (rawDoc['partyPurse'] is Map) {
      final rawPurse = Map<String, dynamic>.from(rawDoc['partyPurse'] as Map);
      final reserveScalars = _extractScalars(rawPurse);

      final newReserveCounters = Map<String, PnCounter>.from(updatedReserve.denominationCounters);
      final reserveAuditParts = <String>[];

      for (final entry in reserveScalars.entries) {
        final denom = entry.key;
        final val = entry.value;
        final existing = newReserveCounters[denom];

        // Skip if already imported under fixed key
        if (existing != null &&
            (existing.positive.containsKey(importKey) ||
                existing.negative.containsKey(importKey))) {
          continue;
        }

        final importedCounter = PnCounter(
          positive: val >= 0 ? {importKey: val} : const {},
          negative: val < 0 ? {importKey: val.abs()} : const {},
        );

        final mergedCounter = (existing != null)
            ? existing.merge(importedCounter)
            : importedCounter;

        newReserveCounters[denom] = mergedCounter;
        reserveAuditParts.add('$denom: $val');
        mutated = true;
      }

      if (reserveAuditParts.isNotEmpty) {
        updatedReserve = PartyPurse.fromCounters(newReserveCounters);
        auditNotes.add('Reserve: [${reserveAuditParts.join(', ')}]');
      }
    }

    // 4. Import Member Purses from scalars
    final updatedMemberPurses = Map<String, PartyPurse>.from(profile.memberPurses);
    if (rawDoc['memberPurses'] is Map) {
      final rawMembers = Map<String, dynamic>.from(rawDoc['memberPurses'] as Map);

      // Group keys by resolved slug
      final memberGroups = <String, Map<String, dynamic>>{};
      for (final entry in rawMembers.entries) {
        final keyStr = entry.key.toString().trim();
        final lower = keyStr.toLowerCase();

        String resolvedSlug;
        if (telemetryBySlug.containsKey(lower)) {
          resolvedSlug = telemetryBySlug[lower]!;
        } else if (telemetryByName.containsKey(lower)) {
          resolvedSlug = telemetryByName[lower]!;
        } else {
          resolvedSlug = 'legacy-name:$keyStr';
        }

        final group = memberGroups.putIfAbsent(resolvedSlug, () => {});
        group[keyStr] = entry.value;
      }

      for (final groupEntry in memberGroups.entries) {
        final resolvedSlug = groupEntry.key;
        final rawKeysMap = groupEntry.value;

        // Determine which scalar map to import
        Map<String, int> chosenScalars;
        String chosenSourceKey;

        // Check if slug key exists directly in the keys
        final slugKey = rawKeysMap.keys.firstWhere(
          (k) => k.trim().toLowerCase() == resolvedSlug.toLowerCase(),
          orElse: () => '',
        );

        if (slugKey.isNotEmpty) {
          chosenSourceKey = slugKey;
          chosenScalars = _extractScalars(rawKeysMap[slugKey]);

          // Check if name key also existed and differed
          for (final otherKey in rawKeysMap.keys) {
            if (otherKey != slugKey) {
              final otherScalars = _extractScalars(rawKeysMap[otherKey]);
              if (!_mapsEqual(chosenScalars, otherScalars)) {
                auditNotes.add(
                  'Conflict for "$resolvedSlug": slug "$slugKey"=$chosenScalars differed from name "$otherKey"=$otherScalars; imported slug value.',
                );
              }
            }
          }
        } else {
          chosenSourceKey = rawKeysMap.keys.first;
          chosenScalars = _extractScalars(rawKeysMap[chosenSourceKey]);
        }

        // If the document has a characterRoster, skip member purses for characters not on it.
        // In legacy Firestore, removeCharacterFromRoster moved coins to reserve but merge:true retained the key.
        if (hasRoster &&
            !resolvedRoomSlugs.any((s) => s.toLowerCase() == resolvedSlug.toLowerCase()) &&
            !resolvedRoomSlugs.any((s) => s.toLowerCase() == chosenSourceKey.trim().toLowerCase())) {
          auditNotes.add(
            'Skipped member purse for "$resolvedSlug" ($chosenSourceKey) as character is not on room roster',
          );
          continue;
        }

        if (chosenScalars.isEmpty) continue;

        final currentPurse = updatedMemberPurses[resolvedSlug] ?? const PartyPurse.empty();
        final newMemberCounters = Map<String, PnCounter>.from(currentPurse.denominationCounters);
        final memberAuditParts = <String>[];

        for (final entry in chosenScalars.entries) {
          final denom = entry.key;
          final val = entry.value;
          final existing = newMemberCounters[denom];

          if (existing != null &&
              (existing.positive.containsKey(importKey) ||
                  existing.negative.containsKey(importKey))) {
            continue;
          }

          final importedCounter = PnCounter(
            positive: val >= 0 ? {importKey: val} : const {},
            negative: val < 0 ? {importKey: val.abs()} : const {},
          );

          final mergedCounter = (existing != null)
              ? existing.merge(importedCounter)
              : importedCounter;

          newMemberCounters[denom] = mergedCounter;
          memberAuditParts.add('$denom: $val');
          mutated = true;
        }

        if (memberAuditParts.isNotEmpty) {
          updatedMemberPurses[resolvedSlug] = PartyPurse.fromCounters(newMemberCounters);
          auditNotes.add('Member $resolvedSlug ($chosenSourceKey): [${memberAuditParts.join(', ')}]');
        }
      }
    }

    // 5. Import & Reconcile Roster
    CrdtOrSet<String> updatedRoster = profile.partyRoster;
    if (hasRoster) {
      // Add each resolved roster entry to partyRoster
      for (final slug in resolvedRoomSlugs) {
        if (!updatedRoster.activeValues.contains(slug)) {
          updatedRoster = updatedRoster.add(slug, slug, clock.nextTimestamp());
          mutated = true;
          auditNotes.add('Roster add: $slug');
        }
      }

      // Remove entries that this replica added during adoption that are not on room roster
      final currentRosterItems = List<String>.from(updatedRoster.activeValues);
      for (final item in currentRosterItems) {
        if (!resolvedRoomSlugs.contains(item)) {
          updatedRoster = updatedRoster.remove(item, clock.nextTimestamp());
          mutated = true;
          auditNotes.add('Roster prune adopted unshared: $item');
        }
      }
    }

    if (!mutated) {
      return profile;
    }

    // 5. Append Audit Event to ChangeLog
    final ts = clock.nextTimestamp();
    final eventTime = DateTime.fromMillisecondsSinceEpoch(ts.physicalTime, isUtc: true);
    final auditEvent = PartyEvent(
      id: 'import_${clock.replicaId.value}_${ts.physicalTime}_${ts.logicalCounter}',
      roomCode: rawCode,
      timestamp: eventTime,
      type: 'legacyImport',
      playerName: 'System (Legacy Import)',
      details: 'Imported legacy Firestore room ledger: ${auditNotes.join('; ')}',
    );

    final updatedChangeLog = List<PartyEvent>.from(profile.changeLog)..add(auditEvent);

    return profile.copyWith(
      partyPurse: updatedReserve,
      memberPurses: updatedMemberPurses,
      partyRoster: updatedRoster,
      changeLog: updatedChangeLog,
    );
  }

  static Map<String, int> _extractScalars(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      // Skip known nested counter maps or metadata
      if (key == 'crdt' || key == 'counters' || key == 'version' || key == 'lastUpdated') {
        continue;
      }
      final val = entry.value;
      if (val is num) {
        result[key] = val.toInt();
      }
    }
    return result;
  }

  static bool _mapsEqual(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
