# 0002. No User Accounts

Status: Accepted
In code since 2026-09-26 (fd74268)

## Context
The toolkit is designed with a local-first privacy stance: user data is considered toxic waste that should not be centralized, indexed, or stored on servers.

## Decision
There is no sign-in, no Firebase Auth, and no user account of any kind in the application. All campaigns, characters, and settings persist locally on the user's device (`AppDatabaseService`, `CharacterPersistenceService`).

## Consequences
Nothing identifies a person, so there is no per-user permission model in the database. Whoever holds a 6-character room code can read and join that room. Administrative capabilities such as the Dungeon Master role are enforced purely within the client UI.

## Rejected Options
- **Email or social authentication accounts:** Rejected because collecting personal identities creates credentials and data privacy liabilities to secure.
- **Firebase Anonymous Auth:** acceptable only if the privacy stance allowed a pseudonymous id; not adopted.
