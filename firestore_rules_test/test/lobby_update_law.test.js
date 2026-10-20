import test from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import { createTestEnv } from '../test_helper.js';

const FieldValue = firebase.firestore.FieldValue;
const Timestamp = firebase.firestore.Timestamp;

function sha256Hex(str) {
  return crypto.createHash('sha256').update(str).digest('hex');
}

function seededRandom(seed) {
  let s = seed % 2147483647;
  if (s <= 0) s += 2147483646;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

const ALLOWED_LOBBY_KEYS = new Set([
  'roomCode',
  'code',
  'campaignId',
  'rulesetId',
  'campaignName',
  'hostKeyHash',
  'activePlayers',
  'partyTelemetry',
  'sharedCharacters',
  'version',
  'createdAt',
  'lastUpdated',
  'expiresAt',
  'isStateless',
]);

const LEDGER_KEYS = new Set(['partyPurse', 'memberPurses', 'characterRoster']);
const JUNK_KEYS = new Set(['junk1', 'junk2']);

test('Lobby Update Law Property Test (500 seeds)', async (t) => {
  const testEnv = await createTestEnv();

  t.after(async () => {
    await testEnv.cleanup();
  });

  let totalAllowed = 0;
  let totalDenied = 0;

  // Run 500 seeds in chunks of 25 for fast execution
  const CHUNK_SIZE = 25;
  const TOTAL_SEEDS = 500;

  for (let chunkStart = 1; chunkStart <= TOTAL_SEEDS; chunkStart += CHUNK_SIZE) {
    const chunkPromises = [];

    for (let seed = chunkStart; seed < chunkStart + CHUNK_SIZE && seed <= TOTAL_SEEDS; seed++) {
      chunkPromises.push(runSeed(seed));
    }

    await Promise.all(chunkPromises);
  }

  // Controls check: at least one ALLOWED and at least one DENIED
  console.log(`Lobby Update Law: ${TOTAL_SEEDS} seeds executed. Allowed: ${totalAllowed}, Denied: ${totalDenied}`);
  assert(
    totalAllowed > 0,
    `Control failed: expected at least one ALLOWED outcome, got ${totalAllowed}`
  );
  assert(
    totalDenied > 0,
    `Control failed: expected at least one DENIED outcome, got ${totalDenied}`
  );

  async function runSeed(seed) {
    const rand = seededRandom(seed);
    const roomCode = `ROOM_L${seed}`;

    // 1. Generate existing lobby
    const isHosted = rand() > 0.5;
    const hostKey = `host-key-${seed}`;
    const hostKeyHash = isHosted ? sha256Hex(hostKey) : (rand() > 0.5 ? '' : null);
    const hasCampaignId = rand() > 0.4;
    const campaignId = hasCampaignId ? `camp-${seed}` : null;
    const hasRulesetId = rand() > 0.4;
    const rulesetId = hasRulesetId ? 'dnd5e_2024' : null;
    const hasLedger = rand() > 0.5;

    const existingDoc = {
      roomCode,
      code: roomCode,
      campaignName: `Campaign ${seed}`,
      activePlayers: ['DM'],
      version: 1,
      lastUpdated: '2026-10-19T12:00:00.000Z',
      createdAt: '2026-10-19T12:00:00.000Z',
      expiresAt: '2026-11-19T12:00:00.000Z',
    };

    if (hostKeyHash !== null) {
      existingDoc.hostKeyHash = hostKeyHash;
    }
    if (campaignId !== null) {
      existingDoc.campaignId = campaignId;
    }
    if (rulesetId !== null) {
      existingDoc.rulesetId = rulesetId;
    }
    if (hasLedger) {
      existingDoc.partyPurse = { gp: 50 };
      existingDoc.memberPurses = { thorin: { gp: 10 } };
      existingDoc.characterRoster = ['thorin'];
    }

    // Seed existing document via admin
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set(existingDoc);
    });

    // 2. Decide if this seed intends to test clean update or random mutated update
    const isCleanCandidate = rand() > 0.5;
    const updateData = {};
    let proofChoice = 'none';

    if (isCleanCandidate) {
      // Build a clean update touching only allowed keys with valid values
      if (rand() > 0.5) updateData.activePlayers = ['DM', `Player_${seed}`];
      if (rand() > 0.5) updateData.version = 2;
      if (rand() > 0.5) updateData.lastUpdated = '2026-10-19T13:00:00.000Z';
      if (rand() > 0.5) updateData.partyTelemetry = { 'hero-1': { hp: 25 } };
      if (!hasCampaignId && rand() > 0.5) updateData.campaignId = `camp-new-${seed}`;
      if (!hasRulesetId && rand() > 0.5) updateData.rulesetId = 'dnd5e_2024';
      if (Object.keys(updateData).length === 0) {
        updateData.version = 2;
      }
    } else {
      // Mutated update: draw from allowed, ledger, and junk keys
      const allPossibleKeys = [
        ...ALLOWED_LOBBY_KEYS,
        'partyPurse',
        'memberPurses',
        'characterRoster',
        'junk1',
        'junk2',
      ];

      // Pick 1 to 4 keys
      const numKeys = Math.floor(rand() * 4) + 1;
      for (let k = 0; k < numKeys; k++) {
        const key = allPossibleKeys[Math.floor(rand() * allPossibleKeys.length)];
        if (LEDGER_KEYS.has(key)) {
          updateData[key] = { gp: 999 };
        } else if (JUNK_KEYS.has(key)) {
          updateData[key] = 'junk_value';
        } else if (key === 'hostKeyHash') {
          updateData.hostKeyHash = rand() > 0.5 ? sha256Hex('attacker-key') : 'invalid-hash';
        } else if (key === 'campaignId') {
          updateData.campaignId = `camp-mutated-${seed}`;
        } else if (key === 'rulesetId') {
          updateData.rulesetId = 'dnd5e_mutated';
        } else if (key === 'campaignName') {
          updateData.campaignName = rand() > 0.5 ? 'Valid New Name' : ''; // empty string is invalid
        } else if (key === 'version') {
          updateData.version = rand() > 0.5 ? 99 : 'not_a_number';
        } else if (key === 'activePlayers') {
          updateData.activePlayers = rand() > 0.5 ? ['ValidPlayer'] : 'not_a_list';
        } else {
          updateData[key] = 'some_val';
        }
      }

      // Draw proof choice from: none, fresh-right-key, fresh-wrong-key, leftover-right-key
      const proofRoll = rand();
      if (proofRoll < 0.25) {
        proofChoice = 'none';
      } else if (proofRoll < 0.50) {
        proofChoice = 'fresh-right-key';
      } else if (proofRoll < 0.75) {
        proofChoice = 'fresh-wrong-key';
      } else {
        proofChoice = 'leftover-right-key';
      }
    }

    // If leftover proof chosen, seed it in advance with an old timestamp
    if (proofChoice === 'leftover-right-key') {
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        await adminContext
          .firestore()
          .collection('rooms')
          .doc(roomCode)
          .collection('hostProof')
          .doc('current')
          .set({
            hostKey: hostKey,
            at: Timestamp.fromDate(new Date(Date.now() - 60000)),
          });
      });
    }

    // 3. Attempt update as unauthenticated user
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    let allowed = false;

    try {
      if (proofChoice === 'fresh-right-key') {
        const batch = unauthDb.batch();
        const proofRef = roomRef.collection('hostProof').doc('current');
        batch.set(proofRef, { hostKey: hostKey, at: FieldValue.serverTimestamp() });
        batch.set(roomRef, updateData, { merge: true });
        await batch.commit();
      } else if (proofChoice === 'fresh-wrong-key') {
        const batch = unauthDb.batch();
        const proofRef = roomRef.collection('hostProof').doc('current');
        batch.set(proofRef, { hostKey: 'wrong-host-key', at: FieldValue.serverTimestamp() });
        batch.set(roomRef, updateData, { merge: true });
        await batch.commit();
      } else {
        // none or leftover-right-key (no proof written in request batch)
        await roomRef.set(updateData, { merge: true });
      }
      allowed = true;
    } catch (_) {
      allowed = false;
    }

    if (allowed) {
      totalAllowed++;
    } else {
      totalDenied++;
    }

    // 4. Invariant: ALLOWED implies
    // - no ledger key affected
    // - no junk key affected
    // - hostKeyHash unchanged (absent = '')
    // - campaignId / rulesetId unchanged, or first set, or changed with a fresh valid proof
    if (allowed) {
      for (const k of Object.keys(updateData)) {
        assert(
          !LEDGER_KEYS.has(k),
          `Seed ${seed}: Update with ledger key '${k}' was ALLOWED!`
        );
        assert(
          !JUNK_KEYS.has(k),
          `Seed ${seed}: Update with junk key '${k}' was ALLOWED!`
        );
      }

      if ('hostKeyHash' in updateData) {
        const beforeEffective = (existingDoc.hostKeyHash || '').toLowerCase();
        const afterEffective = (updateData.hostKeyHash || '').toLowerCase();
        assert.strictEqual(
          afterEffective,
          beforeEffective,
          `Seed ${seed}: hostKeyHash change was ALLOWED without matching!`
        );
      }

      const hasFreshValidProof =
        isHosted && proofChoice === 'fresh-right-key';

      if (hasCampaignId && 'campaignId' in updateData && updateData.campaignId !== existingDoc.campaignId) {
        assert(
          hasFreshValidProof,
          `Seed ${seed}: campaignId change on existing lobby was ALLOWED without fresh valid host proof!`
        );
      }

      if (hasRulesetId && 'rulesetId' in updateData && updateData.rulesetId !== existingDoc.rulesetId) {
        assert(
          hasFreshValidProof,
          `Seed ${seed}: rulesetId change on existing lobby was ALLOWED without fresh valid host proof!`
        );
      }
    }

    // 5. Invariant: Clean case MUST be ALLOWED
    if (isCleanCandidate) {
      // Check if this was genuinely clean
      const touchedKeys = Object.keys(updateData);
      const allAllowed = touchedKeys.every((k) => ALLOWED_LOBBY_KEYS.has(k));
      const noIdentityConflict =
        (!('campaignId' in updateData) || !hasCampaignId || updateData.campaignId === campaignId) &&
        (!('rulesetId' in updateData) || !hasRulesetId || updateData.rulesetId === rulesetId);

      if (allAllowed && noIdentityConflict) {
        assert(
          allowed,
          `Seed ${seed}: Clean update was unexpectedly DENIED! UpdateData: ${JSON.stringify(
            updateData
          )}`
        );
      }
    }
  }
});
