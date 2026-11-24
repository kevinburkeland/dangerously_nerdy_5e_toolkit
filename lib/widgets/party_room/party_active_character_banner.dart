import 'package:material_ui/material_ui.dart';

import '../../infrastructure/dtos/character_telemetry_dto.dart';
import '../../models/party/campaign_membership.dart';
import '../../models/party/party_purse.dart';
import '../../models/party/party_session_state.dart';
import '../../screens/character_sheet_view.dart';
import '../../services/logging_service.dart';
import '../../services/persistence/character_persistence_service.dart';
import '../../services/dice_room_service.dart';
import '../../services/party/party_room_service.dart';
import '../../theme/app_theme.dart';
import '../party/campaign_dialogs.dart';
import '../party/party_vitality_hud.dart';

/// Active character banner and quick party controls in the Party Room Vault tab.
class PartyActiveCharacterBanner extends StatelessWidget {
  final PartySessionState? session;
  final TabletopColors tabletop;
  final bool isDark;
  final String roomCode;
  final String playerName;
  final bool isDmOrCoDm;
  final CampaignMembership? currentMembership;
  final PartyRoomService partyService;
  final DiceRoomService diceService;
  final ValueChanged<String> onPlayerNameChanged;
  final VoidCallback onRefresh;

  const PartyActiveCharacterBanner({
    super.key,
    required this.session,
    required this.tabletop,
    required this.isDark,
    required this.roomCode,
    required this.playerName,
    required this.isDmOrCoDm,
    required this.currentMembership,
    required this.partyService,
    required this.diceService,
    required this.onPlayerNameChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roster = session?.characterRoster ?? const [];
    final myPurse = session?.getMemberPurse(playerName) ?? const PartyPurse.empty();
    final isLinked =
        session?.sharedCharacters.containsKey(playerName) == true ||
            (currentMembership?.characterId != null &&
                currentMembership!.characterId!.isNotEmpty &&
                currentMembership!.characterId != 'Adventurer' &&
                currentMembership!.characterId != 'DM');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222738) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          Widget buildIdentityHeader() {
            return Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                  child:
                      Icon(Icons.person, size: 18, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACTIVE CHARACTER / SESSION IDENTITY',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            playerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (isLinked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.green.shade800
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: Colors.green.shade600, width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 10, color: Colors.green),
                                  SizedBox(width: 3),
                                  Text(
                                    'Linked',
                                    style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          final actionButtons = <Widget>[
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Colors.teal,
              ),
              icon: const Icon(Icons.link, size: 15),
              label: const Text('Link', style: TextStyle(fontSize: 12)),
              onPressed: () => LinkCampaignCharacterDialog.show(
                context,
                roomCode: roomCode,
                onLinked: onRefresh,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Switch', style: TextStyle(fontSize: 12)),
              onPressed: () => SwitchActiveCharacterDialog.show(
                context,
                roomCode: roomCode,
                currentName: playerName,
                roster: roster,
                onCharacterSelected: (name) {
                  diceService.joinRoom(roomCode, name);
                  onPlayerNameChanged(name);
                },
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: Colors.blueAccent,
              ),
              icon: const Icon(Icons.badge_outlined, size: 15),
              label: const Text('Sheet', style: TextStyle(fontSize: 12)),
              onPressed: () => _openActiveCharacterSheet(context, session),
            ),
            if (!isDmOrCoDm)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Colors.amber.shade800,
                ),
                icon: const Icon(Icons.vpn_key_outlined, size: 14),
                label: const Text('Claim DM', style: TextStyle(fontSize: 12)),
                onPressed: () => ClaimDmPasskeyDialog.show(
                  context,
                  initialRoomCode: roomCode,
                  initialPlayerName: playerName,
                ),
              ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.groups_outlined, size: 16),
              label: const Text('Roster', style: TextStyle(fontSize: 12)),
              onPressed: () => ManagePartyRosterDialog.show(
                context,
                roomCode: roomCode,
                currentName: playerName,
                initialRoster: roster,
                onActiveCharacterChanged: (name) {
                  diceService.joinRoom(roomCode, name);
                  onPlayerNameChanged(name);
                },
              ),
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                buildIdentityHeader(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: actionButtons,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: buildIdentityHeader()),
                    ...actionButtons.map(
                      (btn) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: btn,
                      ),
                    ),
                  ],
                ),
              ],

              // Personal Pouch summary for active character
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary
                      .withValues(alpha: isDark ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Your Store: ~${myPurse.totalGpEquivalent.toStringAsFixed(1)} GP (${myPurse.pp} PP, ${myPurse.gp} GP, ${myPurse.ep} EP, ${myPurse.sp} SP, ${myPurse.cp} CP)',
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => MemberCoinTransactionDialog.show(
                        context,
                        roomCode: roomCode,
                        characterName: playerName,
                        performedBy: playerName,
                        isDeposit: true,
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('+Add',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => MemberCoinTransactionDialog.show(
                        context,
                        roomCode: roomCode,
                        characterName: playerName,
                        performedBy: playerName,
                        isDeposit: false,
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text('-Spend',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ),
                    ),
                  ],
                ),
              ),

              // Live combat vitality telemetry if linked
              if (session != null) ...[
                Builder(
                  builder: (context) {
                    CharacterTelemetryDto? activeTelemetry = session!
                            .partyTelemetry[playerName] ??
                        (currentMembership?.characterId != null
                            ? session!
                                .partyTelemetry[currentMembership!.characterId]
                            : null);
                    if (activeTelemetry == null &&
                        session!.sharedCharacters.isNotEmpty) {
                      final rawMap = session!.sharedCharacters[playerName] ??
                          (currentMembership?.characterId != null
                              ? session!.sharedCharacters[
                                  currentMembership!.characterId]
                              : null);
                      if (rawMap != null) {
                        if (rawMap.containsKey('hp') ||
                            rawMap.containsKey('id')) {
                          try {
                            activeTelemetry =
                                CharacterTelemetryDto.fromMap(rawMap);
                          } catch (_) {
                            activeTelemetry =
                                CharacterTelemetryDto.fromLegacyCharacterMap(
                                    rawMap);
                          }
                        }
                      }
                    }
                    if (activeTelemetry == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: PartyVitalityHud.fromDto(
                        dto: activeTelemetry,
                        isCompact: true,
                        onTap: () => _openActiveCharacterSheet(context, session),
                      ),
                    );
                  },
                ),
              ],

              if (roster.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Quick Roster Select (${roster.length}):',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...roster.map((rName) {
                        final isCurrent = rName == playerName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            avatar: Icon(
                              isCurrent
                                  ? Icons.check_circle
                                  : Icons.person_outline,
                              size: 14,
                              color: isCurrent
                                  ? Colors.white
                                  : colorScheme.primary,
                            ),
                            label: Text(rName,
                                style: const TextStyle(fontSize: 11.5)),
                            selected: isCurrent,
                            selectedColor: colorScheme.primary,
                            onSelected: (selected) {
                              if (!isCurrent) {
                                partyService.setActiveCharacter(
                                  roomCode: roomCode,
                                  characterName: rName,
                                );
                                diceService.joinRoom(roomCode, rName);
                                onPlayerNameChanged(rName);
                              }
                            },
                          ),
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14),
                        label: const Text('Add Member',
                            style: TextStyle(fontSize: 11.5)),
                        onPressed: () => ManagePartyRosterDialog.show(
                          context,
                          roomCode: roomCode,
                          currentName: playerName,
                          initialRoster: roster,
                          onActiveCharacterChanged: (name) {
                            diceService.joinRoom(roomCode, name);
                            onPlayerNameChanged(name);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }



  Future<void> _openActiveCharacterSheet(BuildContext context, PartySessionState? session) async {
    // 1. Always prioritize authoritative local storage for this player's character
    final localChars = await CharacterPersistenceService().loadCharacters();
    Character? targetChar = localChars
        .where((c) =>
            c.id.slug == currentMembership?.characterId ||
            c.name.toLowerCase() == playerName.toLowerCase())
        .firstOrNull;

    // 2. Fall back to sharedCharacters only if not found locally (e.g. DM viewing remote player)
    if (targetChar == null &&
        session != null &&
        session.sharedCharacters.isNotEmpty) {
      final rawMap = session.sharedCharacters[playerName] ??
          (currentMembership?.characterId != null
              ? session.sharedCharacters[currentMembership!.characterId]
              : null);
      if (rawMap != null) {
        try {
          targetChar = Character.fromMap(rawMap);
        } catch (e, st) {
          LoggingService().logNonFatal(e, st,
              reason: 'Failed to deserialize character from sharedCharacters map in party room');
        }
      }
    }

    if (!context.mounted) return;

    final updated = await Navigator.push<Character?>(
      context,
      MaterialPageRoute(
        builder: (_) => CharacterSheetView(
          character: targetChar,
          isDmMode: isDmOrCoDm,
        ),
      ),
    );

    // 3. Regardless of whether updated is null (e.g. popped via swipe/system gesture),
    // reload latest state from persistence and sync to room
    final localCharsAfter =
        await CharacterPersistenceService().loadCharacters();
    final latestChar = localCharsAfter
            .where((c) =>
                c.id.slug ==
                    (targetChar?.id.slug ?? currentMembership?.characterId) ||
                c.name.toLowerCase() == playerName.toLowerCase())
            .firstOrNull ??
        updated ??
        targetChar;

    if (latestChar != null) {
      await partyService.linkCharacterToCampaign(
        roomCode: roomCode,
        character: latestChar,
        existingRosterName: playerName,
        isNewImport: false,
      );
      await partyService.updateCharacterTelemetry(
        roomCode: roomCode,
        character: latestChar,
        existingRosterName: playerName,
      );
      onRefresh();
    }
  }

}
