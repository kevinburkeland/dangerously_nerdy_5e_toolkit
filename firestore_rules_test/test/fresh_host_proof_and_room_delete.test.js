import test from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { createTestEnv } from '../test_helper.js';

const FieldValue = firebase.firestore.FieldValue;
const Timestamp = firebase.firestore.Timestamp;

function sha256Hex(str) {
  return crypto.createHash('sha256').update(str).digest('hex');
}

test('Pass 8.1: Fresh Host Proof and Room Delete Invariants (R1 & R2)', async (t) => {
  const testEnv = await createTestEnv();

  const validHostKey = 'c7a202d0-9f5b-4e6f-8d2a-112233445566';
  const validHostKeyHash = sha256Hex(validHostKey);

  t.afterEach(async () => {
    await testEnv.clearFirestore();
  });

  t.after(async () => {
    await testEnv.cleanup();
  });

  // --- R1 (fixes S1, S2, S3) ---

  await t.test('S1 & S2: Leftover proof with right key and old at: no-proof delete DENIED, campaignId update DENIED, rulesetId update DENIED, room still exists', async () => {
    const roomCode = 'ROOM_LEFTOVER_OLD';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const roomRef = adminContext.firestore().collection('rooms').doc(roomCode);
      await roomRef.set({
        roomCode,
        campaignName: 'Leftover Proof Room',
        hostKeyHash: validHostKeyHash,
        campaignId: 'camp-original',
        rulesetId: 'ruleset-original',
      });
      await roomRef.collection('hostProof').doc('current').set({
        hostKey: validHostKey,
        at: Timestamp.fromDate(new Date(Date.now() - 60000)),
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);

    // Delete with no proof in the batch is DENIED (S1)
    await assertFails(roomRef.delete());

    // campaignId change with no proof in the batch is DENIED (S2)
    await assertFails(roomRef.update({ campaignId: 'camp-attacker' }));

    // rulesetId change with no proof in the batch is DENIED
    await assertFails(roomRef.update({ rulesetId: 'ruleset-attacker' }));

    // Verify room still exists with original identity
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
      assert.strictEqual(snap.data().campaignId, 'camp-original');
      assert.strictEqual(snap.data().rulesetId, 'ruleset-original');
    });
  });

  await t.test('Leftover proof with right key and no at (Pass 8 shape): delete is DENIED', async () => {
    const roomCode = 'ROOM_LEFTOVER_NO_AT';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const roomRef = adminContext.firestore().collection('rooms').doc(roomCode);
      await roomRef.set({
        roomCode,
        campaignName: 'Pass 8 Shape Room',
        hostKeyHash: validHostKeyHash,
      });
      await roomRef.collection('hostProof').doc('current').set({
        hostKey: validHostKey,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);

    await assertFails(roomRef.delete());

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
    });
  });

  await t.test('S3 sequence: delete room with fresh proof, cleanup fails, recreate room with same hash -> delete with no proof is DENIED', async () => {
    const roomCode = 'ROOM_S3_RECREATE';
    // 1. DM initially creates room
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Original DM Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    // 2. DM deletes room with fresh proof
    const batch = unauthDb.batch();
    batch.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
    batch.delete(roomRef);
    await assertSucceeds(batch.commit());

    // 3. Proof cleanup fails (leftover proof remains with older timestamp)
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext
        .firestore()
        .collection('rooms')
        .doc(roomCode)
        .collection('hostProof')
        .doc('current')
        .set({
          hostKey: validHostKey,
          at: Timestamp.fromDate(new Date(Date.now() - 30000)),
        });
    });

    // 4. DM recreates the room with the same hash
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Recreated DM Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    // 5. Attacker tries to delete with no proof -> DENIED!
    await assertFails(roomRef.delete());

    // Verify room still exists
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
      assert.strictEqual(snap.data().campaignName, 'Recreated DM Room');
    });
  });

  await t.test('Control: Fresh proof (serverTimestamp) with right key: delete ALLOWED; campaignId change ALLOWED', async () => {
    const roomCode = 'ROOM_FRESH_CONTROL';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Fresh Control Room',
        hostKeyHash: validHostKeyHash,
        campaignId: 'camp-init',
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    // Control 1: campaignId update with fresh proof is ALLOWED
    const updateBatch = unauthDb.batch();
    updateBatch.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
    updateBatch.update(roomRef, { campaignId: 'camp-updated' });
    await assertSucceeds(updateBatch.commit());

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.data().campaignId, 'camp-updated');
    });

    // Control 2: delete with fresh proof is ALLOWED
    const delBatch = unauthDb.batch();
    delBatch.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
    delBatch.delete(roomRef);
    await assertSucceeds(delBatch.commit());

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, false);
    });
  });

  await t.test('Proof with client-chosen Timestamp of current time is DENIED', async () => {
    const roomCode = 'ROOM_CLIENT_TS';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Client TS Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    const batch = unauthDb.batch();
    batch.set(proofRef, { hostKey: validHostKey, at: Timestamp.now() });
    batch.delete(roomRef);

    await assertFails(batch.commit());
  });

  await t.test('Proof with extra key is DENIED', async () => {
    const roomCode = 'ROOM_EXTRA_KEY';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Extra Key Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    const batch = unauthDb.batch();
    batch.set(proofRef, {
      hostKey: validHostKey,
      at: FieldValue.serverTimestamp(),
      extra: 'forbidden',
    });
    batch.delete(roomRef);

    await assertFails(batch.commit());
  });

  // --- R2 Plan Mirroring Tests (fixes K1, G1) ---

  await t.test('R2 Plan Mirror: Hostless room, plain delete: ALLOWED (RoomDeletePlan.plainDelete)', async () => {
    const roomCode = 'ROOM_HOSTLESS_PLAIN';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Hostless Room',
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(unauthDb.collection('rooms').doc(roomCode).delete());

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, false);
    });
  });

  await t.test('R2 Plan Mirror (K1): Hostless room, proof + delete in batch: DENIED', async () => {
    const roomCode = 'ROOM_HOSTLESS_PROOF';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Hostless Room Proof Attack',
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    const batch = unauthDb.batch();
    batch.set(proofRef, { hostKey: 'any-key', at: FieldValue.serverTimestamp() });
    batch.delete(roomRef);

    // DENIED: because effectiveHash on hostless room is '', proof creation cannot match
    await assertFails(batch.commit());

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
    });
  });

  await t.test('R2 Plan Mirror: Hosted room, transaction that reads room, writes fresh proof, and deletes: ALLOWED (RoomDeletePlan.proofAndDelete)', async () => {
    const roomCode = 'ROOM_HOSTED_TX';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Hosted Transaction Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    await assertSucceeds(
      unauthDb.runTransaction(async (tx) => {
        const snap = await tx.get(roomRef);
        assert.strictEqual(snap.exists, true);
        tx.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
        tx.delete(roomRef);
      })
    );

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, false);
    });
  });

  await t.test('R2 Plan Mirror: Hosted room, plain delete: DENIED', async () => {
    const roomCode = 'ROOM_HOSTED_PLAIN';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Hosted Room Plain Delete',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthDb.collection('rooms').doc(roomCode).delete());

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
    });
  });
});
