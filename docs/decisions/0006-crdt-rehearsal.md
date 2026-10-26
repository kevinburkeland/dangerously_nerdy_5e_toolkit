# 0006. CRDTs as a Rehearsal

Status: Accepted
In code since 2026-09-26 (fd74268)

## Context
Conflict-free Replicated Data Types (CvRDTs) introduce substantial mathematical and structural complexity into state management, data modeling, and testing.

## Decision
The CRDT synchronization layer in `vtt_engine_core` (`HybridLogicalClock`, `CrdtOrSet`, `PnCounter`, `CrdtLwwRegister`) is developed deliberately as a rehearsal for decentralized, local-first synchronization architectures intended for future emergency-reporting and field tools.

## Consequences
The inherent algorithmic complexity of CvRDT join-semilattices, causal tombstone retention, and mathematical law testing suites is accepted intentionally as a primary project goal rather than incidental overhead.

## Rejected Options
- **Host-authoritative client-server synchronization:** While a host-authoritative model (with the DM device as the single source of truth) would satisfy ordinary tabletop gaming requirements, it was rejected because it would not exercise or validate decentralized local-first replication patterns (and ADR 0001 establishes why the Firestore document is not the owner of party state).
