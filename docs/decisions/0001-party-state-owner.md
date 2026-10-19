# 0001. Party State Owner

## Context
Today the app has two owners of the same party state, and they never talk to each other (no code path copies one into the other).

| State | Owner 1: campaign profile (CRDT, synced peer to peer) | Owner 2: Firestore `rooms/{code}` document |
|---|---|---|
| Party reserve purse | `CampaignProfile.partyPurse`, used by the DM dashboard | `partyPurse`, used by the party room screen, character sheet stash and party dialogs |
| Roster | `CampaignProfile.partyRoster` (character slugs) | `characterRoster` (names) and `activePlayers` |
| Member purses | none | `memberPurses` (keyed by both name and slug), mirrored into `Character.purse` |

## Decision
The campaign profile is the only owner of the party reserve, the roster and the member purses. The Firestore room document is a lobby record.

The lobby keeps `roomCode`/`code`, `campaignName`, `hostKeyHash`, `expiresAt`, `createdAt`, `lastUpdated`, `version`, `activePlayers` (presence), `partyTelemetry` and `sharedCharacters` (character projections). The `loot` and `events` subcollections stay in Firestore. They have one owner already.

## Rejected Options
- **Firestore room document as owner with transactions:** Rejected because it sacrifices offline capability and peer-to-peer transport resilience when disconnected from Firebase, while introducing distributed transaction contention.
- **Host-authoritative requests to the DM's device:** Rejected because party members would be blocked from ledger updates whenever the DM device is offline, sleeping, or backgrounded, introducing a brittle single point of failure.
