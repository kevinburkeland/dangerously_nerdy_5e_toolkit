# Bonus slice 3 progress notes
Status: COMPLETE
Start heads: app 642001203fcd3331b242fe885daf146014657ad4
Last pushed heads (CI green): app 03e1d383f30345e313107ed2b2469f27e4e793f5
Fix ids: 1.1 1.2 1.3 1.4

## Fix titles
Fix 1.1: Only a campaign room opens a campaign
Fix 1.2: The banner test runs the real campaign rules
Fix 1.3: Only campaign entry paths call openRoomProfile
Fix 1.4: The Join dialog lists your campaigns

## Steps
- [x] Step 1 Dice rooms stay dice rooms, and the campaign dropdown: app 03e1d383f30345e313107ed2b2469f27e4e793f5 run 43342862173
- [x] Step 2 Mutations and report

## Fix checklist
Fix 1.1 done: [Only a campaign room opens a campaign] Added SharedRoomCampaignOpener in lib/services/party/shared_room_campaign_opener.dart, wired RoomBannerWidget in lib/widgets/room_banner_widget.dart, and added examples and 500-case law in test/services/party/shared_room_campaign_opener_test.dart
Fix 1.2 done: [The banner test runs the real campaign rules] Added real PartyRoomService and opener widget tests in test/widgets/room_banner_campaign_rules_test.dart and updated test doubles in test/widgets/room_banner_widget_test.dart
Fix 1.3 done: [Only campaign entry paths call openRoomProfile] Added exact allowlist source bar test and in-memory controls in test/infrastructure/compliance/open_room_profile_source_bar_test.dart
Fix 1.4 done: [The Join dialog lists your campaigns] Added sorted "Your campaigns" dropdown to JoinCreateRoomDialog in lib/widgets/dialogs/join_create_room_dialog.dart, passed memberships from lib/widgets/room_banner_widget.dart, and added dialog and end-to-end tests in test/widgets/dialogs/join_create_room_dialog_test.dart

## Mutation branches
None

## Red runs on main
951b228e663f641194d67bfcb219787b553b73f9 red run 43341534683

## Next
None

## Open issues and deviations
Run 43341534683 cause: analyze job failed with avoid_print info on print calls in test/services/party/shared_room_campaign_opener_test.dart; fixed by a1c5636fe99eb272c0835821ef1c39669c2ced42
Updated test doubles in test/screens/dice_roller_screen_test.dart and test/screens/screens_characterization_test.dart so fake PartyRoomService instances used by screens mounting RoomBannerWidget expose roomDocPort and getCachedLobby. Regenerated .agents/rules/codebase_map.md via tool/generate_codebase_map.dart for the new file in lib/services/party/ to satisfy docs_truth_test DT4.
