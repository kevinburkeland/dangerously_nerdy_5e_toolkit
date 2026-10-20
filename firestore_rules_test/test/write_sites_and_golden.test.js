import test from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import crypto from 'node:crypto';
import firebase from 'firebase/compat/app';
import 'firebase/compat/firestore';
import { assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { createTestEnv } from '../test_helper.js';

const FieldValue = firebase.firestore.FieldValue;
const Timestamp = firebase.firestore.Timestamp;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const FIXTURES_DIR = path.resolve(__dirname, '..', '..', 'test', 'fixtures', 'firestore_payloads');

function sha256Hex(str) {
  return crypto.createHash('sha256').update(str).digest('hex');
}

function loadFixture(filename) {
  const raw = fs.readFileSync(path.join(FIXTURES_DIR, filename), 'utf8');
  return JSON.parse(raw);
}

function preparePayload(raw) {
  const data = JSON.parse(JSON.stringify(raw));
  for (const [key, val] of Object.entries(data)) {
    if (val && typeof val === 'object' && val.__timestamp__) {
      const dt = new Date(val.__timestamp__);
      if (key === 'expireAt' && dt <= new Date()) {
        data[key] = Timestamp.fromDate(new Date(Date.now() + 3600 * 1000));
      } else {
        data[key] = Timestamp.fromDate(dt);
      }
    }
  }
  if (typeof data.timestamp === 'number') {
    data.timestamp = Date.now();
  }
  return data;
}

test('Write Sites and Golden Payloads Test Suite (R6)', async (t) => {
  const testEnv = await createTestEnv();

  const validHostKey = 'e4a29c10-1234-5678-abcd-001122334455';
  const validHostKeyHash = sha256Hex(validHostKey);

  t.afterEach(async () => {
    await testEnv.clearFirestore();
  });

  t.after(async () => {
    await testEnv.cleanup();
  });

  // =========================================================================
  // 1. GOLDEN PAYLOADS TESTS
  // =========================================================================
  await t.test('Golden Payload: lobby_hosted.json is ALLOWED on create', async () => {
    const raw = loadFixture('lobby_hosted.json');
    const data = preparePayload(raw);
    const roomCode = data.roomCode;

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(unauthDb.collection('rooms').doc(roomCode).set(data));
  });

  await t.test('Golden Payload: lobby_hostless.json is ALLOWED on create', async () => {
    const raw = loadFixture('lobby_hostless.json');
    const data = preparePayload(raw);
    const roomCode = data.roomCode;

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(unauthDb.collection('rooms').doc(roomCode).set(data));
  });

  await t.test('Golden Payload: party_loot_item.json is ALLOWED on create in loot subcollection', async () => {
    const roomCode = 'ROOM_GLOOT';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Golden Loot Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const raw = loadFixture('party_loot_item.json');
    const data = preparePayload(raw);

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).collection('loot').doc(data.id).set(data)
    );
  });

  await t.test('Golden Payload: party_event.json is ALLOWED on create in events subcollection', async () => {
    const roomCode = 'ROOM_GEVT';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Golden Event Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const raw = loadFixture('party_event.json');
    const data = preparePayload(raw);
    data.roomCode = roomCode;

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).collection('events').doc('evt_golden_1').set(data)
    );
  });

  await t.test('Golden Payload: signaling_message.json is ALLOWED on create in nodes signals subcollection', async () => {
    const roomCode = 'ROOM_GSIG';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Golden Signal Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const raw = loadFixture('signaling_message.json');
    const data = preparePayload(raw);
    data.roomCode = roomCode;

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb
        .collection('rooms')
        .doc(roomCode)
        .collection('nodes')
        .doc(data.toNodeId)
        .collection('signals')
        .doc(data.id)
        .set(data)
    );
  });

  await t.test('Golden Payload: room_roll.json is ALLOWED on create in rolls subcollection', async () => {
    const roomCode = 'ROOM_GROLL';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Golden Roll Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const raw = loadFixture('room_roll.json');
    const data = preparePayload(raw);
    data.roomCode = roomCode;

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).collection('rolls').doc('roll_golden_1').set(data)
    );
  });

  await t.test('Golden Payload: relay_message.json is ALLOWED on create in relay_messages subcollection', async () => {
    const roomCode = 'ROOM_GRELAY';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Golden Relay Room',
        hostKeyHash: validHostKeyHash,
      });
    });

    const raw = loadFixture('relay_message.json');
    const data = preparePayload(raw);

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb
        .collection('rooms')
        .doc(roomCode)
        .collection('relay_messages')
        .doc(data.id)
        .set(data)
    );
  });

  // =========================================================================
  // 2. APP WRITE SITES (HAND-CRAFTED FROM DART CALL SITES)
  // =========================================================================

  // lib/services/party/party_room_service.dart: createCampaign
  await t.test('party_room_service.dart: createCampaign write is ALLOWED', async () => {
    const roomCode = 'ROOM_CREATE_1';
    const payload = {
      roomCode,
      campaignName: 'New Adventure',
      hostKeyHash: validHostKeyHash,
      activePlayers: ['DM'],
      version: 1,
      lastUpdated: '2026-10-19T12:00:00.000Z',
      expiresAt: '2026-11-19T12:00:00.000Z',
      campaignId: 'camp-created-1',
      rulesetId: 'dnd5e_2024',
    };

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(unauthDb.collection('rooms').doc(roomCode).set(payload));
  });

  // lib/services/party/party_room_service.dart: joinCampaign
  await t.test('party_room_service.dart: joinCampaign merge write is ALLOWED', async () => {
    const roomCode = 'ROOM_JOIN_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Existing Campaign',
        hostKeyHash: validHostKeyHash,
        activePlayers: ['DM'],
        version: 1,
        lastUpdated: '2026-10-19T12:00:00.000Z',
        expiresAt: '2026-11-19T12:00:00.000Z',
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    // In joinCampaign: updatedLobby.toMap() with SetOptions(merge: true)
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set(
        {
          activePlayers: ['DM', 'Alice'],
          sharedCharacters: { 'alice-slug': { name: 'Alice', hp: 30 } },
          partyTelemetry: { 'alice-slug': { hp: 30 } },
          version: 2,
          lastUpdated: '2026-10-19T12:10:00.000Z',
          expiresAt: '2026-11-19T12:10:00.000Z',
        },
        { merge: true }
      )
    );
  });

  // lib/services/party/party_room_service.dart: ensureRoomExists (lease touch)
  await t.test('party_room_service.dart: ensureRoomExists lease touch write is ALLOWED', async () => {
    const roomCode = 'ROOM_TOUCH_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: 'Lease Campaign',
        hostKeyHash: validHostKeyHash,
        lastUpdated: '2026-10-19T10:00:00.000Z',
        expiresAt: '2026-11-19T10:00:00.000Z',
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).update({
        lastUpdated: '2026-10-19T12:00:00.000Z',
        expiresAt: '2026-11-19T12:00:00.000Z',
        isStateless: false,
      })
    );
  });

  // lib/services/party/party_room_service.dart: linkCharacterToCampaign
  await t.test('party_room_service.dart: linkCharacterToCampaign merge write with FieldValue.increment is ALLOWED', async () => {
    const roomCode = 'ROOM_LINK_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: 'Link Campaign',
        hostKeyHash: validHostKeyHash,
        activePlayers: ['DM'],
        version: 1,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set(
        {
          roomCode,
          code: roomCode,
          campaignName: 'Link Campaign',
          activePlayers: ['DM', 'Thorin'],
          sharedCharacters: {
            'thorin-slug': { name: 'Thorin', hp: 45 },
          },
          partyTelemetry: {
            'thorin-slug': { hp: 45 },
          },
          version: FieldValue.increment(1),
          lastUpdated: '2026-10-19T12:15:00.000Z',
          expiresAt: '2026-11-19T12:15:00.000Z',
        },
        { merge: true }
      )
    );
  });

  // lib/services/party/party_room_service.dart: updateCharacterTelemetry
  await t.test('party_room_service.dart: updateCharacterTelemetry merge write is ALLOWED', async () => {
    const roomCode = 'ROOM_TELEM_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Telemetry Campaign',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set(
        {
          roomCode,
          partyTelemetry: {
            'thorin-slug': { currentHp: 38, maxHp: 45 },
          },
          sharedCharacters: {
            'thorin-slug': { currentHp: 38, maxHp: 45 },
          },
          lastUpdated: '2026-10-19T12:20:00.000Z',
        },
        { merge: true }
      )
    );
  });

  // lib/services/party/party_room_service.dart: rehydrateCampaign (lobby + loot batch)
  await t.test('party_room_service.dart: rehydrateCampaign batch write is ALLOWED', async () => {
    const roomCode = 'ROOM_REHYD_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Rehydrate Campaign',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const docRef = unauthDb.collection('rooms').doc(roomCode);
    const lootDoc = docRef.collection('loot').doc('loot-rehyd-1');

    const batch = unauthDb.batch();
    batch.set(
      docRef,
      {
        roomCode,
        campaignName: 'Rehydrate Campaign',
        hostKeyHash: validHostKeyHash,
        version: 2,
        lastUpdated: '2026-10-19T12:25:00.000Z',
      },
      { merge: true }
    );
    batch.set(lootDoc, {
      id: 'loot-rehyd-1',
      name: 'Sunblade',
      gpValue: 5000,
    });

    await assertSucceeds(batch.commit());
  });

  // lib/services/party/party_room_service.dart: leaveCampaign
  await t.test('party_room_service.dart: leaveCampaign write with FieldValue.arrayRemove is ALLOWED', async () => {
    const roomCode = 'ROOM_LEAVE_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: 'Leave Campaign',
        hostKeyHash: validHostKeyHash,
        activePlayers: ['DM', 'Bob'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set(
        {
          roomCode,
          code: roomCode,
          campaignName: 'Leave Campaign',
          activePlayers: FieldValue.arrayRemove('Bob'),
          lastUpdated: '2026-10-19T12:30:00.000Z',
        },
        { merge: true }
      )
    );
  });

  // lib/services/party/party_room_service.dart: setActiveCharacter
  await t.test('party_room_service.dart: setActiveCharacter write with FieldValue.arrayUnion is ALLOWED', async () => {
    const roomCode = 'ROOM_SETACT_1';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: 'Active Character Campaign',
        hostKeyHash: validHostKeyHash,
        activePlayers: ['DM'],
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set(
        {
          roomCode,
          code: roomCode,
          campaignName: 'Active Character Campaign',
          activePlayers: FieldValue.arrayUnion('Gimli'),
          lastUpdated: '2026-10-19T12:35:00.000Z',
        },
        { merge: true }
      )
    );
  });

  // lib/services/party/party_room_service.dart: deleteCampaign
  await t.test('party_room_service.dart: deleteCampaign with host proof batch is ALLOWED', async () => {
    const roomCode = 'ROOM_DEL_SEAM';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Delete Seam Campaign',
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
  });

  // lib/services/party/party_room_service.dart: flushOutbox (createRoom, addLoot, claimLoot)
  await t.test('party_room_service.dart: flushOutbox actions (createRoom, addLoot, claimLoot) are ALLOWED', async () => {
    const roomCode = 'ROOM_OUTBOX_1';
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    // 1. Replay createRoom
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Outbox Campaign',
        hostKeyHash: validHostKeyHash,
        activePlayers: ['DM'],
      })
    );

    // 2. Replay addLoot and claimLoot in a batch
    const docRef = unauthDb.collection('rooms').doc(roomCode);
    const lootDoc = docRef.collection('loot').doc('loot-outbox-1');

    const batch = unauthDb.batch();
    batch.set(lootDoc, {
      id: 'loot-outbox-1',
      name: 'Cloak of Elvenkind',
      gpValue: 250,
    });
    batch.set(
      lootDoc,
      {
        claimedByPlayer: 'Legolas',
      },
      { merge: true }
    );

    await assertSucceeds(batch.commit());
  });

  // lib/services/party/party_room_service.dart: addLootItem, claimLootItem, conflict resolution, toggleAttunement, archive, restore
  await t.test('party_room_service.dart: loot CRUD & conflict resolutions are ALLOWED', async () => {
    const roomCode = 'ROOM_LOOT_OPS';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Loot Ops Campaign',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    const lootRef = unauthDb.collection('rooms').doc(roomCode).collection('loot').doc('loot-op-1');

    // addLootItem
    await assertSucceeds(
      lootRef.set({
        id: 'loot-op-1',
        name: 'Boots of Speed',
        gpValue: 400,
        count: 1,
      })
    );

    // claimLootItem (transaction/update)
    await assertSucceeds(
      lootRef.update({
        claimedByPlayer: 'Flash',
      })
    );

    // toggleAttunement / archiveLootItem / restoreLootItem
    await assertSucceeds(
      lootRef.set(
        {
          id: 'loot-op-1',
          name: 'Boots of Speed',
          gpValue: 400,
          count: 1,
          claimedByPlayer: null, // released
        },
        { merge: true }
      )
    );
  });

  // lib/services/party/party_room_service.dart: logEvent
  await t.test('party_room_service.dart: logEvent write is ALLOWED', async () => {
    const roomCode = 'ROOM_LOG_EVT';
    await testEnv.withSecurityRulesDisabled(async (adminContext) => {
      await adminContext.firestore().collection('rooms').doc(roomCode).set({
        roomCode,
        campaignName: 'Event Log Campaign',
        hostKeyHash: validHostKeyHash,
      });
    });

    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).collection('events').doc('evt-100').set({
        roomCode,
        type: 'lootClaimed',
        playerName: 'Gimli',
        details: 'Gimli claimed Boots of Speed',
      })
    );
  });

  // lib/infrastructure/adapters/p2p/firebase_signaling_adapter.dart: initialize (stub), _sendSignal, _deletePath
  await t.test('firebase_signaling_adapter.dart: stub touch, _sendSignal and _deletePath are ALLOWED', async () => {
    const roomCode = 'ROOM_SIG_ADAPT';
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    // initialize stub
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: `Campaign ${roomCode}`,
        isStateless: true,
        lastUpdated: '2026-10-19T12:00:00.000Z',
        expiresAt: '2026-11-19T12:00:00.000Z',
      })
    );

    // _sendSignal
    const signalDoc = unauthDb
      .collection('rooms')
      .doc(roomCode)
      .collection('nodes')
      .doc('target-node-99')
      .collection('signals')
      .doc('sig-uuid-1');

    await assertSucceeds(
      signalDoc.set({
        id: 'sig-uuid-1',
        roomCode,
        fromNodeId: 'source-node-1',
        toNodeId: 'target-node-99',
        type: 'offer',
        sdp: 'v=0\r\ntest-sdp',
        timestamp: Date.now(),
      })
    );

    // _deletePath (delete signal)
    await assertSucceeds(signalDoc.delete());
  });

  // lib/infrastructure/adapters/p2p/firebase_fallback_adapter.dart: initializeRoom (stub), broadcastPayload
  await t.test('firebase_fallback_adapter.dart: stub touch and broadcastPayload are ALLOWED', async () => {
    const roomCode = 'ROOM_FALLBACK_1';
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    // initializeRoom stub
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: `Campaign ${roomCode}`,
        isStateless: true,
        lastUpdated: '2026-10-19T12:00:00.000Z',
        expiresAt: '2026-11-19T12:00:00.000Z',
      })
    );

    // broadcastPayload
    await assertSucceeds(
      unauthDb
        .collection('rooms')
        .doc(roomCode)
        .collection('relay_messages')
        .doc('relay-msg-1')
        .set({
          id: 'relay-msg-1',
          senderId: 'source-node-1',
          payload: '{"delta":123}',
          timestamp: Date.now(),
          expireAt: Timestamp.fromDate(new Date(Date.now() + 3600 * 1000)),
        })
    );
  });

  // lib/services/dice_room_service.dart: _touchRoomInFirestore, broadcastRoll
  await t.test('dice_room_service.dart: _touchRoomInFirestore and broadcastRoll are ALLOWED', async () => {
    const roomCode = 'ROOM_DICE_1';
    const unauthDb = testEnv.unauthenticatedContext().firestore();

    // 1. _touchRoomInFirestore when doc does not exist
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).set({
        roomCode,
        code: roomCode,
        campaignName: `Dice Room ${roomCode}`,
        activePlayers: ['PlayerDice'],
        createdAt: '2026-10-19T12:00:00.000Z',
        lastUpdated: '2026-10-19T12:00:00.000Z',
        expiresAt: '2026-11-19T12:00:00.000Z',
      })
    );

    // 2. _touchRoomInFirestore when doc exists (update activePlayers)
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).update({
        activePlayers: FieldValue.arrayUnion('Player2'),
        lastUpdated: '2026-10-19T12:05:00.000Z',
      })
    );

    // 3. broadcastRoll
    await assertSucceeds(
      unauthDb.collection('rooms').doc(roomCode).collection('rolls').doc('roll-dice-1').set({
        roomCode,
        playerName: 'PlayerDice',
        total: 19,
        formulaString: '1d20+2',
        details: ['d20: 17 + 2 = 19'],
      })
    );
  });
});
