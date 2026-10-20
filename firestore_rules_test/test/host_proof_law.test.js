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

// Simple seeded pseudo-random generator for reproducible test runs
function seededRandom(seed) {
  let s = seed % 2147483647;
  if (s <= 0) s += 2147483646;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

function generateRandomString(rand, length) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_!@#$%^&*()+= ';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(rand() * chars.length));
  }
  return result;
}

test('R2 Host Proof Semantics and Invariants', async (t) => {
  const testEnv = await createTestEnv();
  const validHostKey = 'c7a202d0-9f5b-4e6f-8d2a-112233445566';
  const validHostKeyHash = sha256Hex(validHostKey);

  t.afterEach(async () => {
    await testEnv.clearFirestore();
  });

  t.after(async () => {
    await testEnv.cleanup();
  });

  await t.test('Batch with wrong hostKey is DENIED and room still exists', async () => {
    const roomCode = 'ROOM_PROOF_WRONG';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Proof Test Campaign',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    const batch = unauthDb.batch();
    batch.set(proofRef, { hostKey: 'wrong-key-12345', at: FieldValue.serverTimestamp() });
    batch.delete(roomRef);

    await assertFails(batch.commit());

    // Verify room still exists
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
    });
  });

  await t.test('Delete without host proof is DENIED on hosted room', async () => {
    const roomCode = 'ROOM_NO_PROOF';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Hosted Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthDb.collection('rooms').doc(roomCode).delete());
  });

  await t.test('Batch with correct hostKey is ALLOWED and room is deleted', async () => {
    const roomCode = 'ROOM_PROOF_OK';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Proof Test Campaign',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    const batch = unauthDb.batch();
    batch.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
    batch.delete(roomRef);

    await assertSucceeds(batch.commit());

    // Room is gone
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, false);
    });
  });

  await t.test('Reading host proof document (get and list) is NEVER allowed', async () => {
    const roomCode = 'ROOM_PROOF_READ';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const roomRef = adminContext.firestore().collection('rooms').doc(roomCode);
      await roomRef.set({
        roomCode,
        campaignName: 'Read Denied Test',
        hostKeyHash: validHostKeyHash,
      });
      await roomRef.collection('hostProof').doc('current').set({
        hostKey: validHostKey,
        at: Timestamp.now(),
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const proofRef = unauthDb.collection('rooms').doc(roomCode).collection('hostProof').doc('current');

    // Direct get
    await assertFails(proofRef.get());

    // Subcollection list / query
    await assertFails(unauthDb.collection('rooms').doc(roomCode).collection('hostProof').get());
  });

  await t.test('Deleting host proof after room is gone is ALLOWED', async () => {
    const roomCode = 'ROOM_PROOF_CLEANUP';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      // Room does NOT exist, only proof exists
      const proofRef = adminContext
        .firestore()
        .collection('rooms')
        .doc(roomCode)
        .collection('hostProof')
        .doc('current');
      await proofRef.set({
        hostKey: validHostKey,
        at: Timestamp.now(),
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const proofRef = unauthDb.collection('rooms').doc(roomCode).collection('hostProof').doc('current');

    await assertSucceeds(proofRef.delete());
  });

  await t.test('Stored hash in uppercase still accepts the right key', async () => {
    const roomCode = 'ROOM_UPPER_HASH';
    const upperHash = validHostKeyHash.toUpperCase();

    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Upper Hash Campaign',
        hostKeyHash: upperHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    const batch = unauthDb.batch();
    batch.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
    batch.delete(roomRef);

    await assertSucceeds(batch.commit());
  });

  await t.test('Host proof law property test: over 300 seeded inputs, only exact key is accepted', async () => {
    const roomCode = 'ROOM_PROOF_LAW';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Host Proof Law Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    // Build at least 320 varied invalid candidate keys
    const rand = seededRandom(42);
    const candidates = [];

    // Specific boundary cases
    candidates.push('');
    candidates.push('   ');
    candidates.push(validHostKey.toUpperCase());
    candidates.push(` ${validHostKey} `);
    candidates.push(`\t${validHostKey}`);
    candidates.push(`${validHostKey}\n`);
    candidates.push(validHostKeyHash); // The hash itself used as key!
    candidates.push(validHostKeyHash.toUpperCase());
    candidates.push(validHostKey.slice(0, -1));
    candidates.push(validHostKey + 'a');
    candidates.push(validHostKey.replace(/a/g, 'b'));
    candidates.push(validHostKey.replace(/-/g, ''));

    // Generate random strings to exceed 320 candidates
    while (candidates.length < 320) {
      const len = Math.floor(rand() * 50) + 1;
      const candidate = generateRandomString(rand, len);
      if (candidate !== validHostKey) {
        candidates.push(candidate);
      }
    }

    let deniedCount = 0;
    for (let i = 0; i < candidates.length; i++) {
      const wrongKey = candidates[i];
      const batch = unauthDb.batch();
      batch.set(proofRef, { hostKey: wrongKey, at: FieldValue.serverTimestamp() });
      batch.delete(roomRef);

      try {
        await assertFails(batch.commit());
        deniedCount++;
      } catch (err) {
        assert.fail(`Seed/candidate index ${i} ('${wrongKey}') was unexpectedly ALLOWED!`);
      }
    }

    assert.strictEqual(deniedCount, candidates.length);

    // Verify room still exists after all denied attempts
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
    });

    // Control: the exact key is accepted in the same run!
    const controlBatch = unauthDb.batch();
    controlBatch.set(proofRef, { hostKey: validHostKey, at: FieldValue.serverTimestamp() });
    controlBatch.delete(roomRef);

    await assertSucceeds(controlBatch.commit());

    // Verify room is now deleted
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, false);
    });
  });

  await t.test('Host proof law second arm: leftover proofs for all 300+ strings (including exact key) DENY no-proof deletes', async () => {
    const roomCode = 'ROOM_LEFTOVER_LAW';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Leftover Proof Law Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);
    const proofRef = roomRef.collection('hostProof').doc('current');

    const rand = seededRandom(42);
    const stringsToTest = [validHostKey];

    // Boundary cases
    stringsToTest.push('');
    stringsToTest.push('   ');
    stringsToTest.push(validHostKey.toUpperCase());
    stringsToTest.push(` ${validHostKey} `);
    stringsToTest.push(`\t${validHostKey}`);
    stringsToTest.push(`${validHostKey}\n`);
    stringsToTest.push(validHostKeyHash);
    stringsToTest.push(validHostKeyHash.toUpperCase());
    stringsToTest.push(validHostKey.slice(0, -1));
    stringsToTest.push(validHostKey + 'a');
    stringsToTest.push(validHostKey.replace(/a/g, 'b'));
    stringsToTest.push(validHostKey.replace(/-/g, ''));

    while (stringsToTest.length < 321) {
      const len = Math.floor(rand() * 50) + 1;
      stringsToTest.push(generateRandomString(rand, len));
    }

    let deniedCount = 0;
    for (let i = 0; i < stringsToTest.length; i++) {
      const keyStr = stringsToTest[i];
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        await adminContext
          .firestore()
          .collection('rooms')
          .doc(roomCode)
          .collection('hostProof')
          .doc('current')
          .set({
            hostKey: keyStr,
            at: Timestamp.fromDate(new Date(Date.now() - 60000)),
          });
      });

      try {
        await assertFails(roomRef.delete());
        deniedCount++;
      } catch (err) {
        assert.fail(`Leftover arm seed index ${i} ('${keyStr}') was unexpectedly ALLOWED!`);
      }
    }

    assert.strictEqual(deniedCount, stringsToTest.length);

    // Verify room still exists after all denied attempts
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
    });
  });
});

