# Cleanup slice 10 progress notes
Status: IN PROGRESS
Start heads: core a393545a225852ca96b53313082b9b86694c72b5, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app b663b438f920d282d4702069df62cd9f2784c46a
Last pushed heads (CI green): core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a, ruleset 08d7d7c0cf860055a8c387a3ca61829d200f253e, app 16d603cf65cfcbbe5cac6274f1b2a9f52dc155e6
Pins now: ruleset -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a; app -> core 59d7178dea6527a18a2cac3b7fe0f110fb93717a, ruleset 8174dfcd51706f7998dd4907b19cb3ce950581a4

## Steps
- [x] Step 1 Retire cs9: core 02e38f27a25042bf34a7359893d84e3f8c006a7e run 42169627679, core b82634e38ae7fc57c9d8a57e0b4bcb96c724a21a run 42170055398, app 16d603cf65cfcbbe5cac6274f1b2a9f52dc155e6 run 42169663727
- [ ] Step 2 The container knows no services
- [ ] Step 3 Required bindings and the unbound law
- [ ] Step 4 Startup migration takes its collaborators
- [ ] Step 5 The layer import table
- [ ] Step 6 Models stop reaching up
- [ ] Step 7 Mutations and report

## Fix checklist

## Red runs on main
None

## Next
Execute Step 2: move InjectionContainer to service_container.dart with zero service imports, remove static bind methods, rename test reset and cache methods, add shared test helper, and add rules 4 and 5 to service_locator_bars_test.dart.

## Open issues and deviations
None.
