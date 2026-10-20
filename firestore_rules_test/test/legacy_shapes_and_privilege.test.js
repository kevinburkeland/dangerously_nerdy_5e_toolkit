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

test('Legacy Shapes and Least Privilege Suite (R4, R5, R6)', async (t) => {
  const testEnv = await createTestEnv();

  const validHostKey = 'f1a2b3c4-d5e6-7890-abcd-ef1234567890';
  const validHostKeyHash = sha256Hex(validHostKey);

  t.afterEach(async () => {
    await testEnv.clearFirestore();
  });

  t.after(async () => {
    await testEnv.cleanup();
  });

  // =========================================================================
  // 1. LEGACY SHAPES TESTS (Hosted and Hostless)
  // =========================================================================
  const legacyConfigs = [
    { type: 'hosted', roomCode: 'ROOM_LEGACY_HOSTED', hostKeyHash: validHostKeyHash },
    { type: 'hostless', roomCode: 'ROOM_LEGACY_HOSTLESS', hostKeyHash: '' },
  ];

  for (const config of legacyConfigs) {
    const { type, roomCode, hostKeyHash } = config;

    await t.test(`Legacy lobby (${type}): join, telemetry, link, set-active, leave, and lease-touch preserve ledger`, async () => {
      // 1. Seed legacy lobby with ledger fields and no campaignId
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        await adminContext.firestore().collection('rooms').doc(roomCode).set({
          roomCode,
          code: roomCode,
          campaignName: `Legacy ${type} Campaign`,
          hostKeyHash,
          partyPurse: { gp: 100, sp: 50 },
          memberPurses: { thorin: { gp: 25 }, bilbo: { sp: 10 } },
          characterRoster: ['thorin', 'bilbo'],
          activePlayers: ['DM'],
          version: 1,
          createdAt: '2026-10-19T10:00:00.000Z',
          lastUpdated: '2026-10-19T10:00:00.000Z',
          expiresAt: '2026-11-19T10:00:00.000Z',
        });
      });

      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const docRef = unauthDb.collection('rooms').doc(roomCode);

      // (a) Join write
      await assertSucceeds(
        docRef.set(
          {
            activePlayers: ['DM', 'Player1'],
            version: 2,
            lastUpdated: '2026-10-19T10:05:00.000Z',
          },
          { merge: true }
        )
      );

      // (b) Telemetry write
      await assertSucceeds(
        docRef.set(
          {
            roomCode,
            partyTelemetry: {
              thorin: { currentHp: 40, maxHp: 45 },
            },
            sharedCharacters: {
              thorin: { currentHp: 40, maxHp: 45 },
            },
            lastUpdated: '2026-10-19T10:10:00.000Z',
          },
          { merge: true }
        )
      );

      // (c) Character link write
      await assertSucceeds(
        docRef.set(
          {
            roomCode,
            code: roomCode,
            campaignName: `Legacy ${type} Campaign`,
            activePlayers: ['DM', 'Player1', 'Thorin'],
            sharedCharacters: {
              thorin: { name: 'Thorin', hp: 45 },
            },
            partyTelemetry: {
              thorin: { hp: 45 },
            },
            version: FieldValue.increment(1),
            lastUpdated: '2026-10-19T10:15:00.000Z',
          },
          { merge: true }
        )
      );

      // (d) Set active character write
      await assertSucceeds(
        docRef.set(
          {
            roomCode,
            code: roomCode,
            activePlayers: FieldValue.arrayUnion('Gandalf'),
            lastUpdated: '2026-10-19T10:20:00.000Z',
          },
          { merge: true }
        )
      );

      // (e) Leave write
      await assertSucceeds(
        docRef.set(
          {
            roomCode,
            code: roomCode,
            activePlayers: FieldValue.arrayRemove('Gandalf'),
            lastUpdated: '2026-10-19T10:25:00.000Z',
          },
          { merge: true }
        )
      );

      // (f) Lease touch write
      await assertSucceeds(
        docRef.update({
          lastUpdated: '2026-10-19T10:30:00.000Z',
          expiresAt: '2026-11-19T10:30:00.000Z',
          isStateless: false,
        })
      );

      // Verify read returns original ledger values unchanged
      const snap = await docRef.get();
      assert.strictEqual(snap.exists, true);
      assert.deepStrictEqual(snap.data().partyPurse, { gp: 100, sp: 50 });
      assert.deepStrictEqual(snap.data().memberPurses, { thorin: { gp: 25 }, bilbo: { sp: 10 } });
      assert.deepStrictEqual(snap.data().characterRoster, ['thorin', 'bilbo']);

      // (g) First write of campaignId is ALLOWED
      await assertSucceeds(
        docRef.update({
          campaignId: `camp-first-${type}`,
        })
      );

      // Verify campaignId was set
      const snapAfterFirst = await docRef.get();
      assert.strictEqual(snapAfterFirst.data().campaignId, `camp-first-${type}`);

      // (h) Second, different campaignId is DENIED without host proof
      await assertFails(
        docRef.update({
          campaignId: `camp-different-${type}`,
        })
      );

      // If hosted, verify second different campaignId with valid host proof is ALLOWED
      if (type === 'hosted') {
        const batch = unauthDb.batch();
        const proofRef = docRef.collection('hostProof').doc('current');
        batch.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
        batch.update(docRef, { campaignId: `camp-proven-${type}` });

        await assertSucceeds(batch.commit());

        const snapAfterProof = await docRef.get();
        assert.strictEqual(snapAfterProof.data().campaignId, `camp-proven-${type}`);
      }
    });
  }

  // =========================================================================
  // 2. LEAST PRIVILEGE ON SUBCOLLECTIONS AND COLLECTIONS (R5)
  // =========================================================================
  await t.test('Writes to unknown subcollection (e.g. rooms/{code}/anything/x) are DENIED', async () => {
    const roomCode = 'ROOM_PRIV_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Privilege Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb
        .collection('rooms')
        .doc(roomCode)
        .collection('anything')
        .doc('x')
        .set({ field: 'malicious' })
    );
  });

  await t.test('Writes to unknown top-level collection are DENIED', async () => {
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('unknown_collection').doc('doc_1').set({ field: 'malicious' })
    );
    await assertFails(
      unauthDb.collection('users').doc('user_1').set({ name: 'Admin' })
    );
  });

  await t.test('Relay messages delete is DENIED', async () => {
    const roomCode = 'ROOM_PRIV_RELAY';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const roomRef = adminContext.firestore().collection('rooms').doc(roomCode);
      await roomRef.set({
        roomCode,
        campaignName: 'Relay Priv Room',
        hostKeyHash: validHostKeyHash,
      });
      await roomRef.collection('relay_messages').doc('msg-1').set({
        id: 'msg-1',
        senderId: 'node-1',
        payload: 'test',
        timestamp: Date.now(),
        expireAt: Timestamp.fromDate(new Date(Date.now() + 3600 * 1000)),
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).collection('relay_messages').doc('msg-1').delete()
    );
  });
});
