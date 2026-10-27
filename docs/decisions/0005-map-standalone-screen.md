# 0005. Map as a Standalone Screen

Status: Accepted
Decided 2026-10-24 by Kevin

## Context
The battle map feature required integration into the existing party room and DM workflows.

## Decision
The tactical battle map is implemented as a dedicated, full-screen view (`MapScreen` in `lib/presentation/screens/map/map_screen.dart`), rather than an embedded tab or panel inside existing screens. The DM dashboard and party room view provide entry buttons to launch it:
- `lib/screens/dm_dashboard_screen.dart`: `_DmDashboardScreenState.build` (app bar actions)
- `lib/screens/party_room_screen.dart`: `_PartyRoomScreenState.build` (app bar actions)

Both DMs and players navigate to the same `MapScreen`; DM-only administrative toolbars (`MapGridControls`, intake pickers) are displayed conditionally based on role.

## Consequences
Both the DM dashboard and party room screens are already dense multi-tab interfaces. Decoupling the map into `MapScreen` aligns with planned organizational refactorings of toolkit tools.

## Rejected Options
- **A tab or sub-panel inside the DM dashboard and party room screen:** rejected because both screens are already very large and have tab bars.
