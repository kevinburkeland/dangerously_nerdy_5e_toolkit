# Cleanup slice 9 progress notes
Status: IN PROGRESS
Start heads: core 5ef3fb32b6d0aa2af31ab118ce1063ab1c7be9b4, ruleset caa0cab3b69badc57ed4b19516b7b2447a7a038c, app ee1e05ab487c1b6bceac24faf98bb4fc07f795df
Last pushed heads (CI green): core a393545a225852ca96b53313082b9b86694c72b5, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 62ac918c17218561a22d8b65df9ac4da96d6e7ad
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire script pushes archive tags: core 1f02c7377ee2a4f770fe69e3c694527f584802db run 42134295224, ruleset 8d189ee33a3548427db28fdb9fc629a8f55790d9 run 42134300449, app 3864a81925a45559f65105e6176d25a9971916c5 run 42134306700
- [x] Step 2 Retire cs8: core a393545a225852ca96b53313082b9b86694c72b5 run 42134904290, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e run 42134927923, app 4a5e6a597c257948a125a77eb18da96427d0b60e run 42134964810
- [x] Step 3 Notes check: run-id form and red runs: app b221274c6dab3f1403744e7c494027e7645f521c run 42136862863
- [x] Step 4 Characterization tests and DI graph law: app 015b148c86c016aab0ce6e0b8cae510e18494d34 run 42144578656
- [x] Step 5 Campaign services off the locator: app 211069cda4707a97ec23a43f6bfa192d185be914 run 42152706879
- [x] Step 6 Dice room off the locator, no isRegistered in party room service: app 00e594266b70e45a7990d41241d90387cfbe080a run 42158702300
- [x] Step 7 Screens without isRegistered, and the locator bars: app 62ac918c17218561a22d8b65df9ac4da96d6e7ad run 42162056743
- [ ] Step 8 Big-file ratchet
- [ ] Step 9 Mutations and report

## Red runs on main
629b575f93aca7f85263610be8cb2b2fa13d1865 red run 42146037357
6e05455e589c77a1e59421ff51e2cda37ec3d506 red run 42160028930

## Next
Step 8 Big-file ratchet.

## Open issues and deviations
The CI failure on 629b575f93aca7f85263610be8cb2b2fa13d1865 occurred because unit tests that manually register collaborators in the DI container without running full bootstrap lacked forwarding into CampaignProfileService, CampaignStorageMigration, and DmBackupService, and mutable static fields in CampaignStorageMigration triggered collaborator hygiene source bar inspection. Fixed by forwarding DI container singleton registrations and encapsulating migration instance state in 211069cda4707a97ec23a43f6bfa192d185be914.
The CI failure on 6e05455e589c77a1e59421ff51e2cda37ec3d506 occurred because removing isRegistered guards from LandingScreen, PartyRoomScreen, and RoomBannerWidget caused 12 existing screen and widget tests that mounted these components without running DI registration to fail with StateError. Fixed by supplying required collaborator fakes in test setups in 62ac918c17218561a22d8b65df9ac4da96d6e7ad.

