import 'package:vtt_engine_core/crdt/pn_counter.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import '../../models/party/party_purse.dart';
import '../../infrastructure/dtos/character_telemetry_dto.dart';
import '../../infrastructure/migration/party_ledger_legacy_import.dart';

/// Pure functional member-purse and ledger transforms over [CampaignProfile].
///
/// Implements Cold Iron Birdcage Pass 7.1 (Q2).
class PartyLedgerOperations {
  /// Checks whether a character is covered by a legacy room document.
  static bool isCoveredByLegacyDocument({
    required Map<String, dynamic> rawDoc,
    required String characterSlug,
    String? characterName,
  }) {
    if (!PartyLedgerLegacyImport.hasLegacyLedgerFields(rawDoc)) {
      return false;
    }

    final cleanSlug = characterSlug.trim().toLowerCase();
    final cleanName = characterName?.trim().toLowerCase();

    // Check partyTelemetry mappings
    if (rawDoc['partyTelemetry'] is Map) {
      final rawTele =
          Map<String, dynamic>.from(rawDoc['partyTelemetry'] as Map);
      for (final entry in rawTele.values) {
        if (entry is Map) {
          try {
            final dto = CharacterTelemetryDto.fromMap(
                Map<String, dynamic>.from(entry));
            final tSlug = dto.id.trim().toLowerCase();
            final tName = dto.name.trim().toLowerCase();
            if (tSlug == cleanSlug ||
                (cleanName != null && tName == cleanName)) {
              return true;
            }
          } catch (_) {}
        }
      }
    }

    // Check memberPurses keys
    if (rawDoc['memberPurses'] is Map) {
      final rawPurses =
          Map<String, dynamic>.from(rawDoc['memberPurses'] as Map);
      for (final key in rawPurses.keys) {
        final k = key.toString().trim().toLowerCase();
        if (k == cleanSlug || (cleanName != null && k == cleanName)) {
          return true;
        }
      }
    }

    // Check characterRoster
    if (rawDoc['characterRoster'] is List) {
      final roster = (rawDoc['characterRoster'] as List).whereType<String>();
      for (final item in roster) {
        final r = item.trim().toLowerCase();
        if (r == cleanSlug || (cleanName != null && r == cleanName)) {
          return true;
        }
      }
    }

    return false;
  }

  /// One-time seed for a character's opening purse when joining or linking.
  ///
  /// Invariants (Q2):
  /// - If the profile already has a memberPurses entry for [characterSlug], nothing is written.
  /// - If [rawDoc] has legacy ledger fields and covers this character, nothing is written.
  /// - Otherwise, writes opening balance under fixed key `character-seed:<characterSlug>`.
  static CampaignProfile seedCharacterPurse({
    required CampaignProfile profile,
    required String characterSlug,
    required PartyPurse openingPurse,
    Map<String, dynamic>? rawDoc,
    String? characterName,
  }) {
    final cleanSlug = characterSlug.trim();
    if (profile.memberPurses.containsKey(cleanSlug)) {
      return profile;
    }

    if (rawDoc != null &&
        isCoveredByLegacyDocument(
          rawDoc: rawDoc,
          characterSlug: cleanSlug,
          characterName: characterName,
        )) {
      return profile;
    }

    // character-seed:<slug> is the second allowed literal replica key, next to legacy-import:<ROOMCODE>
    final seedKey = 'character-seed:$cleanSlug';
    final seedCounters = <String, PnCounter>{};
    for (final denom in ['cp', 'sp', 'ep', 'gp', 'pp']) {
      final val = openingPurse.getBalance(denom);
      if (val != 0) {
        seedCounters[denom] = PnCounter(
          positive: val > 0 ? {seedKey: val} : const {},
          negative: val < 0 ? {seedKey: val.abs()} : const {},
        );
      }
    }

    final seededPurse = PartyPurse.fromCounters(seedCounters);
    final updatedMemberPurses =
        Map<String, PartyPurse>.from(profile.memberPurses);
    updatedMemberPurses[cleanSlug] = seededPurse;

    return profile.copyWith(memberPurses: updatedMemberPurses);
  }

  /// Deposits coins to party reserve.
  static CampaignProfile depositToReserve({
    required CampaignProfile profile,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    required ReplicaId replicaId,
  }) {
    var updatedPurse = profile.partyPurse;
    if (cp > 0) updatedPurse = updatedPurse.modifyDenomination('cp', cp, replicaId: replicaId);
    if (sp > 0) updatedPurse = updatedPurse.modifyDenomination('sp', sp, replicaId: replicaId);
    if (ep > 0) updatedPurse = updatedPurse.modifyDenomination('ep', ep, replicaId: replicaId);
    if (gp > 0) updatedPurse = updatedPurse.modifyDenomination('gp', gp, replicaId: replicaId);
    if (pp > 0) updatedPurse = updatedPurse.modifyDenomination('pp', pp, replicaId: replicaId);
    return profile.copyWith(partyPurse: updatedPurse);
  }

  /// Withdraws coins from party reserve (supports overdrafts).
  static CampaignProfile withdrawFromReserve({
    required CampaignProfile profile,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    required ReplicaId replicaId,
  }) {
    var updatedPurse = profile.partyPurse;
    if (cp > 0) updatedPurse = updatedPurse.modifyDenomination('cp', -cp, replicaId: replicaId);
    if (sp > 0) updatedPurse = updatedPurse.modifyDenomination('sp', -sp, replicaId: replicaId);
    if (ep > 0) updatedPurse = updatedPurse.modifyDenomination('ep', -ep, replicaId: replicaId);
    if (gp > 0) updatedPurse = updatedPurse.modifyDenomination('gp', -gp, replicaId: replicaId);
    if (pp > 0) updatedPurse = updatedPurse.modifyDenomination('pp', -pp, replicaId: replicaId);
    return profile.copyWith(partyPurse: updatedPurse);
  }

  /// Deposits coins directly to a member purse.
  static CampaignProfile depositToMember({
    required CampaignProfile profile,
    required String characterSlug,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    required ReplicaId replicaId,
  }) {
    final cleanSlug = characterSlug.trim();
    var curPurse = profile.memberPurses[cleanSlug] ?? const PartyPurse.empty();
    if (cp > 0) curPurse = curPurse.modifyDenomination('cp', cp, replicaId: replicaId);
    if (sp > 0) curPurse = curPurse.modifyDenomination('sp', sp, replicaId: replicaId);
    if (ep > 0) curPurse = curPurse.modifyDenomination('ep', ep, replicaId: replicaId);
    if (gp > 0) curPurse = curPurse.modifyDenomination('gp', gp, replicaId: replicaId);
    if (pp > 0) curPurse = curPurse.modifyDenomination('pp', pp, replicaId: replicaId);
    final updatedPurses = Map<String, PartyPurse>.from(profile.memberPurses);
    updatedPurses[cleanSlug] = curPurse;
    return profile.copyWith(memberPurses: updatedPurses);
  }

  /// Withdraws coins directly from a member purse.
  static CampaignProfile withdrawFromMember({
    required CampaignProfile profile,
    required String characterSlug,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    required ReplicaId replicaId,
  }) {
    final cleanSlug = characterSlug.trim();
    var curPurse = profile.memberPurses[cleanSlug] ?? const PartyPurse.empty();
    if (cp > 0) curPurse = curPurse.modifyDenomination('cp', -cp, replicaId: replicaId);
    if (sp > 0) curPurse = curPurse.modifyDenomination('sp', -sp, replicaId: replicaId);
    if (ep > 0) curPurse = curPurse.modifyDenomination('ep', -ep, replicaId: replicaId);
    if (gp > 0) curPurse = curPurse.modifyDenomination('gp', -gp, replicaId: replicaId);
    if (pp > 0) curPurse = curPurse.modifyDenomination('pp', -pp, replicaId: replicaId);
    final updatedPurses = Map<String, PartyPurse>.from(profile.memberPurses);
    updatedPurses[cleanSlug] = curPurse;
    return profile.copyWith(memberPurses: updatedPurses);
  }

  /// Transfers coins from personal member store into the shared Party Reserve.
  static CampaignProfile transferMemberToReserve({
    required CampaignProfile profile,
    required String characterSlug,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    required ReplicaId replicaId,
    required StatefulHlcClock clock,
  }) {
    final cleanSlug = characterSlug.trim();
    var currentMemberPurse =
        profile.memberPurses[cleanSlug] ?? const PartyPurse.empty();
    var updatedPartyPurse = profile.partyPurse;

    if (cp > 0) {
      currentMemberPurse = currentMemberPurse.modifyDenomination('cp', -cp, replicaId: replicaId);
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('cp', cp, replicaId: replicaId);
    }
    if (sp > 0) {
      currentMemberPurse = currentMemberPurse.modifyDenomination('sp', -sp, replicaId: replicaId);
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('sp', sp, replicaId: replicaId);
    }
    if (ep > 0) {
      currentMemberPurse = currentMemberPurse.modifyDenomination('ep', -ep, replicaId: replicaId);
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('ep', ep, replicaId: replicaId);
    }
    if (gp > 0) {
      currentMemberPurse = currentMemberPurse.modifyDenomination('gp', -gp, replicaId: replicaId);
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('gp', gp, replicaId: replicaId);
    }
    if (pp > 0) {
      currentMemberPurse = currentMemberPurse.modifyDenomination('pp', -pp, replicaId: replicaId);
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('pp', pp, replicaId: replicaId);
    }

    final updatedPurses = Map<String, PartyPurse>.from(profile.memberPurses);
    updatedPurses[cleanSlug] = currentMemberPurse;

    var updatedRoster = profile.partyRoster;
    if (!updatedRoster.activeValues.contains(cleanSlug)) {
      updatedRoster =
          updatedRoster.add(cleanSlug, cleanSlug, clock.nextTimestamp());
    }

    return profile.copyWith(
      partyPurse: updatedPartyPurse,
      memberPurses: updatedPurses,
      partyRoster: updatedRoster,
    );
  }

  /// Transfers coins from the shared Party Reserve into a personal member store.
  static CampaignProfile transferReserveToMember({
    required CampaignProfile profile,
    required String characterSlug,
    int cp = 0,
    int sp = 0,
    int ep = 0,
    int gp = 0,
    int pp = 0,
    required ReplicaId replicaId,
    required StatefulHlcClock clock,
  }) {
    final cleanSlug = characterSlug.trim();
    var updatedPartyPurse = profile.partyPurse;
    var currentMemberPurse =
        profile.memberPurses[cleanSlug] ?? const PartyPurse.empty();

    if (cp > 0) {
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('cp', -cp, replicaId: replicaId);
      currentMemberPurse = currentMemberPurse.modifyDenomination('cp', cp, replicaId: replicaId);
    }
    if (sp > 0) {
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('sp', -sp, replicaId: replicaId);
      currentMemberPurse = currentMemberPurse.modifyDenomination('sp', sp, replicaId: replicaId);
    }
    if (ep > 0) {
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('ep', -ep, replicaId: replicaId);
      currentMemberPurse = currentMemberPurse.modifyDenomination('ep', ep, replicaId: replicaId);
    }
    if (gp > 0) {
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('gp', -gp, replicaId: replicaId);
      currentMemberPurse = currentMemberPurse.modifyDenomination('gp', gp, replicaId: replicaId);
    }
    if (pp > 0) {
      updatedPartyPurse = updatedPartyPurse.modifyDenomination('pp', -pp, replicaId: replicaId);
      currentMemberPurse = currentMemberPurse.modifyDenomination('pp', pp, replicaId: replicaId);
    }

    final updatedPurses = Map<String, PartyPurse>.from(profile.memberPurses);
    updatedPurses[cleanSlug] = currentMemberPurse;

    var updatedRoster = profile.partyRoster;
    if (!updatedRoster.activeValues.contains(cleanSlug)) {
      updatedRoster =
          updatedRoster.add(cleanSlug, cleanSlug, clock.nextTimestamp());
    }

    return profile.copyWith(
      partyPurse: updatedPartyPurse,
      memberPurses: updatedPurses,
      partyRoster: updatedRoster,
    );
  }

  /// Disperses coins among recipient member stores and optionally the reserve.
  static CampaignProfile disperseCoins({
    required CampaignProfile profile,
    required PartyPurse purseToDisperse,
    required List<String> recipientSlugs,
    required ReplicaId replicaId,
    bool includePartyReserve = true,
    double liquidatedGemsAndArtGp = 0.0,
    bool includeLiquidatedInSplit = false,
    bool isVaultDispersal = false,
  }) {
    final recipients = recipientSlugs
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (recipients.isEmpty && !includePartyReserve) return profile;

    final shareCount = recipients.length + (includePartyReserve ? 1 : 0);
    if (shareCount <= 0) return profile;

    final updatedMemberPurses =
        Map<String, PartyPurse>.from(profile.memberPurses);
    PartyPurse updatedPartyPurse = profile.partyPurse;

    if (includeLiquidatedInSplit && liquidatedGemsAndArtGp > 0) {
      final totalGp =
          purseToDisperse.totalGpEquivalent + liquidatedGemsAndArtGp;
      final perShareGp = (totalGp / shareCount).floor();
      final remainderGp = (totalGp - (perShareGp * shareCount)).round();

      for (final slug in recipients) {
        final prev = updatedMemberPurses[slug] ?? const PartyPurse.empty();
        updatedMemberPurses[slug] =
            prev.modifyDenomination('gp', perShareGp, replicaId: replicaId);
      }

      if (isVaultDispersal) {
        final totalGpWithdrawn = perShareGp * recipients.length;
        updatedPartyPurse = updatedPartyPurse.modifyDenomination(
          'gp',
          -totalGpWithdrawn,
          replicaId: replicaId,
        );
      } else {
        if (includePartyReserve) {
          updatedPartyPurse = updatedPartyPurse.modifyDenomination(
            'gp',
            perShareGp + remainderGp,
            replicaId: replicaId,
          );
        } else if (remainderGp > 0) {
          updatedPartyPurse = updatedPartyPurse.modifyDenomination(
            'gp',
            remainderGp,
            replicaId: replicaId,
          );
        }
      }
    } else {
      for (final denom in ['cp', 'sp', 'ep', 'gp', 'pp']) {
        final totalInPurse = purseToDisperse.getBalance(denom);
        if (totalInPurse <= 0) continue;
        final perShare = totalInPurse ~/ shareCount;
        final remainder = totalInPurse % shareCount;

        for (final slug in recipients) {
          final prev = updatedMemberPurses[slug] ?? const PartyPurse.empty();
          updatedMemberPurses[slug] =
              prev.modifyDenomination(denom, perShare, replicaId: replicaId);
        }

        if (isVaultDispersal) {
          final totalWithdrawn = perShare * recipients.length;
          updatedPartyPurse = updatedPartyPurse.modifyDenomination(
            denom,
            -totalWithdrawn,
            replicaId: replicaId,
          );
        } else {
          if (includePartyReserve) {
            updatedPartyPurse = updatedPartyPurse.modifyDenomination(
              denom,
              perShare + remainder,
              replicaId: replicaId,
            );
          } else if (remainder > 0) {
            updatedPartyPurse = updatedPartyPurse.modifyDenomination(
              denom,
              remainder,
              replicaId: replicaId,
            );
          }
        }
      }
    }

    return profile.copyWith(
      partyPurse: updatedPartyPurse,
      memberPurses: updatedMemberPurses,
    );
  }

  /// Sets member purse using CRDT setDenomination differential math.
  static CampaignProfile overrideMemberPurse({
    required CampaignProfile profile,
    required String characterSlug,
    required PartyPurse newPurse,
    required ReplicaId replicaId,
    required StatefulHlcClock clock,
  }) {
    final cleanSlug = characterSlug.trim();
    final curPurse =
        profile.memberPurses[cleanSlug] ?? const PartyPurse.empty();

    PartyPurse updatedPurse = curPurse;
    for (final denom in ['cp', 'sp', 'ep', 'gp', 'pp']) {
      final target = newPurse.getBalance(denom);
      updatedPurse = updatedPurse.setDenomination(
        denom,
        target,
        replicaId: replicaId,
      );
    }

    final updatedMap = Map<String, PartyPurse>.from(profile.memberPurses);
    updatedMap[cleanSlug] = updatedPurse;

    var updatedRoster = profile.partyRoster;
    if (!updatedRoster.activeValues.contains(cleanSlug)) {
      updatedRoster =
          updatedRoster.add(cleanSlug, cleanSlug, clock.nextTimestamp());
    }

    return profile.copyWith(
      memberPurses: updatedMap,
      partyRoster: updatedRoster,
    );
  }

  /// Removes a character from the roster and moves their coins to reserve.
  static CampaignProfile removeMemberFromRoster({
    required CampaignProfile profile,
    required String characterSlug,
    required ReplicaId replicaId,
    required StatefulHlcClock clock,
  }) {
    final cleanSlug = characterSlug.trim();
    final updatedRoster =
        profile.partyRoster.remove(cleanSlug, clock.nextTimestamp());
    final memberPurse = profile.memberPurses[cleanSlug];
    var updatedReserve = profile.partyPurse;
    final updatedPurses = Map<String, PartyPurse>.from(profile.memberPurses);

    if (memberPurse != null && !memberPurse.isEmpty) {
      for (final denom in ['cp', 'sp', 'ep', 'gp', 'pp']) {
        final bal = memberPurse.getBalance(denom);
        if (bal > 0) {
          updatedReserve = updatedReserve.modifyDenomination(denom, bal, replicaId: replicaId);
          final curM = updatedPurses[cleanSlug] ?? memberPurse;
          updatedPurses[cleanSlug] = curM.modifyDenomination(denom, -bal, replicaId: replicaId);
        }
      }
    }

    return profile.copyWith(
      partyRoster: updatedRoster,
      partyPurse: updatedReserve,
      memberPurses: updatedPurses,
    );
  }

  /// Restores target members to roster and removes any missing members, moving their coins to reserve.
  static CampaignProfile restoreMembersToRoster({
    required CampaignProfile profile,
    required Set<String> targetSlugs,
    required ReplicaId replicaId,
    required StatefulHlcClock clock,
  }) {
    var updatedRoster = profile.partyRoster;
    var updatedReserve = profile.partyPurse;
    final updatedPurses = Map<String, PartyPurse>.from(profile.memberPurses);

    for (final slug in targetSlugs) {
      if (!updatedRoster.activeValues.contains(slug)) {
        updatedRoster = updatedRoster.add(slug, slug, clock.nextTimestamp());
      }
    }

    for (final slug in List<String>.from(updatedRoster.activeValues)) {
      if (!targetSlugs.contains(slug)) {
        updatedRoster = updatedRoster.remove(slug, clock.nextTimestamp());
        final memberPurse = updatedPurses[slug];
        if (memberPurse != null && !memberPurse.isEmpty) {
          for (final denom in ['cp', 'sp', 'ep', 'gp', 'pp']) {
            final bal = memberPurse.getBalance(denom);
            if (bal > 0) {
              updatedReserve = updatedReserve.modifyDenomination(denom, bal, replicaId: replicaId);
              final curM = updatedPurses[slug] ?? memberPurse;
              updatedPurses[slug] = curM.modifyDenomination(denom, -bal, replicaId: replicaId);
            }
          }
        }
      }
    }

    return profile.copyWith(
      partyRoster: updatedRoster,
      partyPurse: updatedReserve,
      memberPurses: updatedPurses,
    );
  }
}
