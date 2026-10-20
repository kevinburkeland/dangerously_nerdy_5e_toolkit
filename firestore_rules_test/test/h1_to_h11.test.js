import test from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { createTestEnv } from '../test_helper.js';

function sha256Hex(str) {
  return crypto.createHash('sha256').update(str).digest('hex');
}

test('H1 to H11 and Control - Vulnerability Exploit Regression Suite', async (t) => {
  const testEnv = await createTestEnv();

  const validHostKey = 'd28d0bb5-f129-43c2-bf72-a1b7396c21e4';
  const validHostKeyHash = sha256Hex(validHostKey);
  const attackerHostKey = '00000000-0000-0000-0000-000000000000';
  const attackerHostKeyHash = sha256Hex(attackerHostKey);

  t.afterEach(async () => {
    await testEnv.clearFirestore();
  });

  t.after(async () => {
    await testEnv.cleanup();
  });

  await t.test('H1: Delete a hosted room document is DENIED to unauthenticated client without proof', async () => {
    const roomCode = 'ROOM_H1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: "DM's Campaign",
        hostKeyHash: validHostKeyHash,
        campaignId: 'camp-123',
        activePlayers: ['DM'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthDb.collection('rooms').doc(roomCode).delete());
  });

  await t.test('H2: Room takeover (delete then recreate with attacker hash) is DENIED at delete step', async () => {
    const roomCode = 'ROOM_H2';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: "DM's Campaign",
        hostKeyHash: validHostKeyHash,
        campaignId: 'camp-h2',
        activePlayers: ['DM'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    // Step 1: Attacker tries to delete the room
    await assertFails(unauthDb.collection('rooms').doc(roomCode).delete());

    // Verify room still exists and has original hostKeyHash
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const snap = await adminContext.firestore().collection('rooms').doc(roomCode).get();
      assert.strictEqual(snap.exists, true);
      assert.strictEqual(snap.data().hostKeyHash, validHostKeyHash);
    });
  });

  await t.test('H3: Overwrite lobby with set (no merge) without hostKeyHash is DENIED', async () => {
    const roomCode = 'ROOM_H3';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: "DM's Campaign",
        hostKeyHash: validHostKeyHash,
        campaignId: 'camp-h3',
        activePlayers: ['DM'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    // Overwrite without hostKeyHash removes the hash
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Overwritten Campaign',
        activePlayers: ['Attacker'],
      })
    );
  });

  await t.test('H4: On a room whose hostKeyHash is empty string, update hostKeyHash is DENIED', async () => {
    const roomCode = 'ROOM_H4';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Hostless Dice Room',
        hostKeyHash: '',
        activePlayers: ['Player1'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).update({
        hostKeyHash: attackerHostKeyHash,
      })
    );
  });

  await t.test('H5: Update campaignId to another value is DENIED without host proof', async () => {
    const roomCode = 'ROOM_H5';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Legitimate Campaign',
        hostKeyHash: validHostKeyHash,
        campaignId: 'camp-original',
        activePlayers: ['DM'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).update({
        campaignId: 'camp-hijacked',
      })
    );
  });

  await t.test('H6: Update legacy ledger fields (partyPurse, memberPurses, characterRoster) is DENIED', async () => {
    const roomCode = 'ROOM_H6';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Legacy Campaign',
        hostKeyHash: validHostKeyHash,
        partyPurse: { gp: 50 },
        memberPurses: { thorin: { gp: 10 } },
        characterRoster: ['thorin'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    // 1. Update partyPurse
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).update({
        'partyPurse': { gp: 9999 },
      })
    );

    // 2. Update memberPurses
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).update({
        'memberPurses': { thorin: { gp: -5, junk: 'x' } },
      })
    );

    // 3. Update characterRoster
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).update({
        'characterRoster': ['a'],
      })
    );
  });

  await t.test('H8: Delete a loot, events or rolls document is DENIED', async () => {
    const roomCode = 'ROOM_H8';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      const roomRef = adminContext.firestore().collection('rooms').doc(roomCode);
      await roomRef.set({
        roomCode,
        campaignName: 'Subcollections Room',
        hostKeyHash: validHostKeyHash,
      });
      await roomRef.collection('loot').doc('loot-1').set({
        id: 'loot-1',
        name: 'Ruby of the War Mage',
        gpValue: 100,
      });
      await roomRef.collection('events').doc('evt-1').set({
        roomCode,
        type: 'combatStart',
        playerName: 'DM',
        details: 'Encounter started',
      });
      await roomRef.collection('rolls').doc('roll-1').set({
        roomCode,
        playerName: 'Thorin',
        total: 18,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const roomRef = unauthDb.collection('rooms').doc(roomCode);

    await assertFails(roomRef.collection('loot').doc('loot-1').delete());
    await assertFails(roomRef.collection('events').doc('evt-1').delete());
    await assertFails(roomRef.collection('rolls').doc('roll-1').delete());
  });

  await t.test('H9: Create any document in legacy rooms/{code}/signaling subcollection is DENIED', async () => {
    const roomCode = 'ROOM_H9';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Signaling Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).collection('signaling').doc('sig-1').set({
        type: 'offer',
        sdp: 'dummy-sdp',
      })
    );
  });

  await t.test('H10: Update lobby with unknown key (e.g. junk) is DENIED', async () => {
    const roomCode = 'ROOM_H10';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Known Keys Room',
        hostKeyHash: validHostKeyHash,
        activePlayers: ['DM'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).update({
        junk: 'x'.repeat(100000),
      })
    );
  });

  await t.test('H11: Stranger adding hostKeyHash to a hostless dice room is DENIED', async () => {
    const roomCode = 'ROOM_H11';
    // Dice-room style create: roomCode, code, campaignName, activePlayers
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: 'Dice Room 11',
        activePlayers: ['Player1'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    // Stranger tries to claim host ownership
    await assertFails(
      unauthDb.collection('rooms').doc(roomCode).update({
        hostKeyHash: attackerHostKeyHash,
      })
    );
  });

  await t.test('Control: Player join merge write on legacy lobby with partyPurse: {gp: 50} is ALLOWED and purse unchanged', async () => {
    const roomCode = 'ROOM_CTRL';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Old Campaign with Ledger',
        hostKeyHash: validHostKeyHash,
        partyPurse: { gp: 50 },
        memberPurses: { thorin: { gp: 10 } },
        characterRoster: ['thorin'],
        activePlayers: ['DM'],
        version: 1,
        lastUpdated: '2026-10-19T12:00:00.000Z',
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    // Merge write simulating player join
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set(
        {
          activePlayers: ['DM', 'NewPlayer'],
          version: 2,
          lastUpdated: '2026-10-19T12:05:00.000Z',
        },
        { merge: true }
      )
    );

    // Read afterwards shows partyPurse.gp == 50 unchanged
    const snap = await unauthDb.collection('rooms').doc(roomCode).get();
    assert.strictEqual(snap.exists, true);
    assert.strictEqual(snap.data().partyPurse.gp, 50);
    assert.deepStrictEqual(snap.data().activePlayers, ['DM', 'NewPlayer']);
  });
});
