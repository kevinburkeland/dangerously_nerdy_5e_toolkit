# Mutation Evidence Backfill (Cleanup slice 14)

Backfilled evidence for archived mutations from Bonus slice 1.1 (`bs11`), Cleanup slice 5 (`cs5`), and Cleanup slice 7 (`cs7`).

## Fix 2.1: Bonus slice 1.1 archived mutations

| Repo | Id | `base_sha` | Patch SHA-256 matches | Tree matches | Caught at base (quoted line) | Caught at today's head |
|---|---|---|---|---|---|---|
| vtt-engine-core | bs11-t1 | `ea7d2b668b9da27fefaf5afd9d68f58ff5d63cc4` | yes | yes | yes: `T2: ci.yml:69: setup-dart sdk '3.13.0' is behind target Dart '3.13.7' (shipped in Flutter 61 days ago)` | yes: `T2: ci.yml:28: setup-dart sdk '3.13.0' is behind target Dart '3.13.7' (shipped in Flutter 61 days ago)` |
| vtt-engine-core | bs11-t2 | `0beafdf804a10369ddd87bdc3eb8c01f94fdfe81` | yes | yes | yes: `T3: ci.yml:69: Minimum SDK job runs '3.12.0', expected exact floor '3.14.0'` | yes: `T3: ci.yml:77: Minimum SDK job runs '3.12.0', expected exact floor '3.14.0'` |
| vtt-engine-core | bs11-f1 | `0beafdf804a10369ddd87bdc3eb8c01f94fdfe81` | yes | yes | yes: `FAIL DC49: expected failure` | yes: `FAIL DC49: expected failure` |
| vtt-engine-core | bs11-f2 | `9ae174c8bf6957bb59e63c264143a6b9b4654dfe` | yes | yes | yes: `FAIL DC70: expected failure for empty flutter releases` | yes: `FAIL DC70: expected failure for empty flutter releases` |
| vtt-engine-core | bs11-g1 | `3273f19428d5baf1e82cbb6d590546562a5edf41` | yes | yes | yes: `FAIL DC51: expected failure for action behind older intermediate release` | yes: `FAIL DC51: expected failure for action behind older intermediate release` |
| vtt-engine-core | bs11-v1 | `3273f19428d5baf1e82cbb6d590546562a5edf41` | yes | yes | yes: `FAIL DC56: expected pass for current ahead of latest` | yes: `FAIL DC56: expected pass for current ahead of latest` |
| vtt-engine-core | bs11-d6 | `3273f19428d5baf1e82cbb6d590546562a5edf41` | yes | yes | yes: `D6: Package 'meta' declared floor '1.12.0' is behind current '1.19.0' (published 959 days ago)` | yes: `D6: Package 'meta' declared floor '1.12.0' is behind lockfile 1.19.0 (first newer release 1.14.0 published 2024-04-04, 959 days old)` |
| vtt-engine-core | bs11-s1 | `3273f19428d5baf1e82cbb6d590546562a5edf41` | yes | yes | yes: `FAIL: MB9 expected failure on wrong subject` | yes: `FAIL: MB9 expected failure on wrong subject` |
| vtt-engine-core | bs11-s2 | `3273f19428d5baf1e82cbb6d590546562a5edf41` | yes | yes | yes: `FAIL RM18: expected failure on different SHA` | yes: `FAIL RM18: expected failure on different SHA` |
| vtt-ruleset-dnd5e | bs11-p1 | `e7912d0012f3d224321193d6add918ee386b34e5` | yes | yes | yes: `D1: Package 'lints' current 3.0.0 is behind resolvable 6.1.0 (first newer release 4.0.0 published 2024-05-09, 924 days old)` | yes: `D6: Package 'lints' declared floor '3.0.0' is behind lockfile 6.1.0 (first newer release 4.0.0 published 2024-05-09, 924 days old)` |
| dangerously_nerdy_5e_toolkit | bs11-o1 | `4b45b7ef630ebbcfd3e06e2aa4791e8c5812895d` | yes | yes | yes: `N4: npm override 'ms' version '2.0.0' is undeclared in exceptions` | yes: `N4: npm override 'ms' version '2.0.0' lacks valid N4 exception entry in dependency_exceptions.tsv` |
| dangerously_nerdy_5e_toolkit | bs11-o2 | `4b45b7ef630ebbcfd3e06e2aa4791e8c5812895d` | yes | yes | yes: `E1: dependency_exceptions.tsv:10: Exception review_by date 2026-12-13 is more than 30 days in future` (with `--today 2026-11-12`) | yes: `E1: dependency_exceptions.tsv:9: Exception review_by date 2026-12-20 is more than 30 days in future` (with `--today 2026-11-19`) |
| dangerously_nerdy_5e_toolkit | bs11-n1 | `4b32b7569445779680c4c403ad3f5ed4626d2e76` | yes | yes | yes: `notes/bonus_slice_1_1_progress.md:51: mutation branch 'mutation/bs11-o2' commit 4b45b7ef630ebbcfd3e06e2aa4791e8c5812895d subject 'Bonus slice 1.1: set latest.json in DC51 three-release action self-test' does not start with 'MUTATION — do not merge: O2'` | yes: `notes/bonus_slice_1_1_progress.md:51: mutation branch 'mutation/bs11-o2' commit 4b45b7ef630ebbcfd3e06e2aa4791e8c5812895d subject 'Bonus slice 1.1: set latest.json in DC51 three-release action self-test' does not start with 'MUTATION — do not merge: O2'` |

Notes on Fix 2.1:
- For `bs11-t2` at today's head, `3.13.0` is within the 14-day grace window of `3.14.0`, so the hand-applied mutant set `sdk: 3.12.0` to trigger `T3`.
- For `bs11-o1` and `bs11-o2` at `base_sha`, both control and mutant were run with `--today` set to the patch date (`2026-11-11` for `bs11-o1`, `2026-11-12` for `bs11-o2`).

## Fix 2.2: Cleanup slice 5 archives end-to-end verification

Every `cs5` archive was verified end to end (patch SHA-256, `git fetch origin <head_sha>`, single `MUTATION` commit, tree match, no remaining `mutation/cs5*` branches) and tagged with a lightweight `archive/cs5-<leaf>` tag pointing at `head_sha`.

For `cs5-g2`, the two original commits from Cleanup slice 5 can no longer be found; the archive and `archive/cs5-g2` hold the squashed single-commit version `9d8e528ba899586b7ba5f23933e7c021d75236f6`.

| Repo | Id | `base_sha` | Patch SHA-256 matches | Tree matches | Caught at base (quoted line) | Caught at today's head |
|---|---|---|---|---|---|---|
| vtt-ruleset-dnd5e | cs5-e1 | `8174dfcd51706f7998dd4907b19cb3ce950581a4` | yes | yes | archive verified (`archive/cs5-e1` -> `7d4288134a40f876981f20332762c665e46a9504`) | n/a (archive verification) |
| vtt-ruleset-dnd5e | cs5-e2 | `8174dfcd51706f7998dd4907b19cb3ce950581a4` | yes | yes | archive verified (`archive/cs5-e2` -> `57589e4f0b0a5d0c3f39990d2bc26bc1993aa5df`) | n/a (archive verification) |
| vtt-ruleset-dnd5e | cs5-e3 | `8174dfcd51706f7998dd4907b19cb3ce950581a4` | yes | yes | archive verified (`archive/cs5-e3` -> `1f13e629fbd3b7039bfe01e5d715816bfd4d7287`) | n/a (archive verification) |
| vtt-ruleset-dnd5e | cs5-e4 | `8174dfcd51706f7998dd4907b19cb3ce950581a4` | yes | yes | archive verified (`archive/cs5-e4` -> `4f3dc651a9c7df30b8988d0157bd907f8efa2f28`) | n/a (archive verification) |
| vtt-ruleset-dnd5e | cs5-g1 | `8174dfcd51706f7998dd4907b19cb3ce950581a4` | yes | yes | archive verified (`archive/cs5-g1` -> `105c1f484a92d354ca351e624d33abc0732b3746`) | n/a (archive verification) |
| vtt-ruleset-dnd5e | cs5-g2 | `8174dfcd51706f7998dd4907b19cb3ce950581a4` | yes | yes | archive verified, squashed (`archive/cs5-g2` -> `9d8e528ba899586b7ba5f23933e7c021d75236f6`) | n/a (archive verification) |
| vtt-ruleset-dnd5e | cs5-v1 | `8174dfcd51706f7998dd4907b19cb3ce950581a4` | yes | yes | archive verified (`archive/cs5-v1` -> `5efdf8294c85f6e70fbce021ff5ddd3fa821ff73`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-e5 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-e5` -> `c91eac9560f0651c1493f11e427e79a5785789d3`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-k1 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-k1` -> `bfca33c29d617df4d467fbe3b8208c9710fa0a7b`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-k2 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-k2` -> `a5a88a66c9cc3b5e4b4c8c07a0a8ce0cd5497687`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-k3 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-k3` -> `d79c83a366bfa2ae4b34b6c5d145a6e8d074035c`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-t1 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-t1` -> `a4c8c1d486ab33e451d40f68a66d78b4573ccb7f`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-t2 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-t2` -> `90a81d7edc5fcfe8df9f68b30d1dd09a1a0b3b93`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-v2 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-v2` -> `6495f22134e6969a9c183b7f4ba4272e4f181a31`) | n/a (archive verification) |
| dangerously_nerdy_5e_toolkit | cs5-v3 | `f7079d614e227be2d2df7843e32692e30acccb2f` | yes | yes | archive verified (`archive/cs5-v3` -> `7cdbef6df875103946b22b31590823d89f310d3b`) | n/a (archive verification) |

## Fix 2.3: Cleanup slice 7 S1 to S4 archived mutations

| Repo | Id | `base_sha` | Patch SHA-256 matches | Tree matches | Caught at base (quoted line) | Caught at today's head |
|---|---|---|---|---|---|---|
| dangerously_nerdy_5e_toolkit | cs7-s1 | `a2f452551e87a90575b07c3af9efaf8d3d72efc9` | yes | yes | control failed on Flutter 3.50.0 with `deprecated_member_use` infos; mutant added `argument_type_not_assignable` (proven cleanly at today's head) | yes: `error • The argument type 'dynamic' can't be assigned to the parameter type 'String'. • lib/infrastructure/adapters/remote/github_ingestor_adapter.dart:727:26 • argument_type_not_assignable` |
| dangerously_nerdy_5e_toolkit | cs7-s2 | `a2f452551e87a90575b07c3af9efaf8d3d72efc9` | yes | yes | yes: `FAIL: analysis_options.yaml has no strict-casts: true under analyzer: language:` | yes: `FAIL: analysis_options.yaml has no strict-casts: true under analyzer: language:` |
| dangerously_nerdy_5e_toolkit | cs7-s3 | `a2f452551e87a90575b07c3af9efaf8d3d72efc9` | yes | yes | yes: `FAIL: forbidden ignore code 'argument_type_not_assignable' in lib/infrastructure/adapters/remote/github_ingestor_adapter.dart:728` | yes: `FAIL: forbidden ignore code 'argument_type_not_assignable' in lib/infrastructure/adapters/remote/github_ingestor_adapter.dart:727` |
| dangerously_nerdy_5e_toolkit | cs7-s4 | `a2f452551e87a90575b07c3af9efaf8d3d72efc9` | yes | yes | yes: `FAIL: analyzer: exclude: list changed (got ['build/**', 'android/**', 'web/**', 'linux/**', 'firestore_rules_test/**', 'lib/services/importers/**'], expected ['build/**', 'android/**', 'web/**', 'linux/**', 'firestore_rules_test/**'])` | yes: `FAIL: analyzer: exclude: list changed (got ['build/**', 'android/**', 'web/**', 'linux/**', 'firestore_rules_test/**', 'lib/services/importers/**'], expected ['build/**', 'android/**', 'web/**', 'linux/**', 'firestore_rules_test/**'])` |
