# 0003. Capability Security: Room Code and Host Key

Status: Accepted
In code since 2026-09-26 (fd74268)

## Context
Without user accounts or centralized authorization, multiplayer campaign rooms require a security model that protects administrative ownership while permitting frictionless party joining.

## Decision
Security is managed entirely via capabilities:
1. **Room Code:** The 6-character room code serves as the capability to read, discover, and join a room session.
2. **Host Key:** The hosting DM's device generates a random UUID v4 string via `CryptoUtils.generateHostKey()`. The room document in Firestore stores only the SHA-256 hash of this key (`hostKeyHash`).
3. **Host Proof:** To delete a room or alter identity fields (`campaignId`, `rulesetId`), Firestore security rules enforce verification via the temporary write-only `rooms/{roomCode}/hostProof/current` path.
4. **App Check:** reCAPTCHA-based App Check is enforced in the Firebase console (external infrastructure configuration not represented in the repository) to mitigate automated spam.

## Consequences
Anyone holding the room code can write player presence (`activePlayers`), character summary projections (`sharedCharacters`), and WebRTC signaling documents, on purpose, so joining works without requiring the host key. Peer-to-peer sync messages are not authorized per writer. Losing the host key means permanently losing host capabilities for that campaign room.

## Rejected Options
- **Account-based role-based access control (RBAC):** Rejected per ADR 0002 (no user accounts).
