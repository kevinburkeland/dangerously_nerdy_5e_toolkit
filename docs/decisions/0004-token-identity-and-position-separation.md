# 0004. Token Identity and Position Separation

Status: Accepted
Decided 2026-10-26 (Map slice 1.5)

## Context
In a local-first collaborative battle map, concurrent operations frequently collide: for instance, a player moves their token at the exact moment the DM removes that token from the map.

## Decision
A map token's static identity and its dynamic cell position are decoupled into distinct CRDT sets in `vtt-engine-core/lib/models/campaign_profile.dart`:
```dart
final CrdtOrSet<MapToken> mapTokens;
final CrdtOrSet<MapTokenCell> mapTokenCells;
```
- `mapTokens` holds token identity (`id`, `mapId`, `kind`, `linkId`, `label`) and is placed once upon creation.
- `mapTokenCells` holds token grid coordinates keyed by `tokenId`.
Moving a token updates only its `MapTokenCell` in `mapTokenCells`. Removing a token removes its identity from `mapTokens`.

## Consequences
Because token identity is removed upon deletion, a concurrent player move that writes a position update cannot revive a token that the DM deleted, regardless of causal clock timestamps.

## Rejected Options
- **Unified token record holding identity and position together:** Rejected because a subsequent position move by a peer re-adds the entire token record, resurrecting deleted tokens over concurrent network splits (an invariant failure caught by the token law suite).
