# Bonus slice 1.1 progress notes
Status: IN PROGRESS
Start heads: core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf, ruleset 1ea8a09339690bb21a4c9e2b454aeb3dea9e94b5, app 0062df46a6c092a09762110642226f01727f9a73
Last pushed heads (CI green): core 44c718b2b93e4122b182e4a77e6232d8ae052f16, ruleset d2e8cb79c851643d86f6aa6e6091e6ab4a7a4b4e, app 0e6e26776b43d26af942fa1d17c70b130d6599bd
Pins now: ruleset -> core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf; app -> core a2b85747cd5b3d0157a41a7a48a1833fa9e01fcf, ruleset 1ea8a09339690bb21a4c9e2b454aeb3dea9e94b5

Fix ids: 1.1 1.2 1.3 2.1 2.2 2.3 2.4 3.1 3.2 3.3 3.4 3.5 4.1 4.2 4.3 5.1 5.2 5.3 5.4 5.5

## Steps
- [x] Step 1 Remove the 2026-11-12 time bomb (Fixes 1.1, 1.2, 1.3): core 44c718b2b93e4122b182e4a77e6232d8ae052f16 run 42935575456, ruleset d2e8cb79c851643d86f6aa6e6091e6ab4a7a4b4e run 42935607817, app 0e6e26776b43d26af942fa1d17c70b130d6599bd run 42935618124
- [ ] Step 2 Every input fails closed (Fixes 2.1, 2.2, 2.3, 2.4)
- [ ] Step 3 Wait counts from first newer release; version floors current; re-pin (Fixes 3.1, 3.2, 3.3, 3.4, 3.5)
- [ ] Step 4 npm overrides and advisories declared (Fixes 4.1, 4.2, 4.3)
- [ ] Step 5 Mutation subjects and branch limit (Fixes 5.1, 5.2, 5.3, 5.4, 5.5)
- [ ] Step 6 Thirteen mutation tests and report

## Fix checklist
Fix 1.1 done: Line-based workflow parser ignores step names, matches job id min-sdk, validates setup-dart sdk format
Fix 1.2 done: Strict min-sdk job requirement enforced in pure Dart repos (rejected in Flutter repos)
Fix 1.3 done: Setup-dart step summary line printed per setup-dart step found
Fix 2.1 not done: Every input file fails closed when missing or unreadable
Fix 2.2 not done: JSON input shapes validated strictly
Fix 2.3 not done: Non-zero exit code or error payload in npm checks fails closed
Fix 2.4 not done: Clear error messages for unreadable inputs
Fix 3.1 not done: Wait counts computed from first newer release
Fix 3.2 not done: Multi-release lag measured correctly
Fix 3.3 not done: Version floors updated in core and ruleset
Fix 3.4 not done: pub outdated checked against updated floors
Fix 3.5 not done: Re-pin core in ruleset, and core+ruleset in app
Fix 4.1 not done: Undeclared npm overrides rejected
Fix 4.2 not done: npm audit advisories verified against declarations
Fix 4.3 not done: npm exceptions properly validated
Fix 5.1 not done: Mutation branch naming enforced (bs11 prefix)
Fix 5.2 not done: Mutation commit subject enforced (MUTATION — do not merge: <id>)
Fix 5.3 not done: Active mutation branch limit enforced (<= 20)
Fix 5.4 not done: Retire mutation branches script ignores non-prefixed branches
Fix 5.5 not done: Retirement self-tests updated

## Mutation branches
None

## Red runs on main
f651bb6a38f78e09066dc5e7f741da52d3a87dad red run 42933658992

## Next
Step 2: Every input fails closed (Fixes 2.1, 2.2, 2.3, 2.4)

## Open issues and deviations
None
