import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../application/services/room_document_port.dart';
import '../../../services/logging_service.dart';
import '../../../services/party/party_room_service.dart';
import '../../../utils/crypto_utils.dart';

/// Builds the fresh host proof payload containing [hostKey] and the server timestamp sentinel.
Map<String, dynamic> buildHostProofPayload(String hostKey) {
  final cleanKey = CryptoUtils.extractHostKey(hostKey);
  return <String, dynamic>{
    'hostKey': cleanKey,
    'at': FieldValue.serverTimestamp(),
  };
}

/// Concrete Firestore implementation of [IRoomDocumentPort].
class FirestoreRoomDocumentAdapter implements IRoomDocumentPort {
  final FirebaseFirestore? _firestore;

  const FirestoreRoomDocumentAdapter({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore get _effectiveFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createRoom({
    required String roomCode,
    required Map<String, dynamic> data,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final docRef = _effectiveFirestore.collection('rooms').doc(clean);

    await _effectiveFirestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) {
        throw RoomAlreadyExistsException('room code already in use: $clean');
      }
      tx.set(docRef, data);
    });
  }

  @override
  Future<RoomDeleteOutcome> deleteRoomWithHostProof({
    required String roomCode,
    String? hostKey,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final roomRef = _effectiveFirestore.collection('rooms').doc(clean);
    final proofRef = roomRef.collection('hostProof').doc('current');

    RoomDeletePlan? executedPlan;

    try {
      final outcome = await _effectiveFirestore.runTransaction<RoomDeleteOutcome>((tx) async {
        final snap = await tx.get(roomRef);
        final existingData = snap.exists ? snap.data() : null;
        final plan = planRoomDelete(existingData, hostKey);
        executedPlan = plan;

        switch (plan) {
          case RoomDeletePlan.none:
            return RoomDeleteOutcome.alreadyGone;
          case RoomDeletePlan.plainDelete:
            tx.delete(roomRef);
            return RoomDeleteOutcome.deleted;
          case RoomDeletePlan.proofAndDelete:
            tx.set(proofRef, buildHostProofPayload(hostKey!));
            tx.delete(roomRef);
            return RoomDeleteOutcome.deleted;
          case RoomDeletePlan.unauthorized:
            throw UnauthorizedHostActionException(
              'DM passkey is required to delete hosted room $clean.',
            );
        }
      });

      if (executedPlan == RoomDeletePlan.proofAndDelete) {
        try {
          await proofRef.delete();
        } catch (e, st) {
          LoggingService().logNonFatal(
            e,
            st,
            reason: 'Failed to clean up host proof document after room delete for $clean',
          );
        }
      }

      return outcome;
    } on UnauthorizedHostActionException {
      rethrow;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw UnauthorizedHostActionException(
            'Server denied room deletion: invalid host proof or insufficient capability.');
      }
      rethrow;
    }
  }

  @override
  Future<void> touchRoomLease({
    required String roomCode,
    required Map<String, dynamic> data,
    bool createIfAbsent = false,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final docRef = _effectiveFirestore.collection('rooms').doc(clean);

    final snap = await docRef.get();
    if (!snap.exists) {
      if (createIfAbsent) {
        await docRef.set(data);
      }
      return;
    }

    final existing = snap.data();
    final updateData = Map<String, dynamic>.from(data);

    // Invariant: Never add hostKeyHash to an existing document that has none
    // and never alter hostKeyHash on an existing document.
    updateData.remove('hostKeyHash');

    // Invariant (H7): Never overwrite campaignName on an existing document.
    updateData.remove('campaignName');

    // Invariant: Identity fields can only be set from absent to present once;
    // do not touch them if already set.
    if (existing?['campaignId'] != null &&
        (existing!['campaignId'] as String).isNotEmpty) {
      updateData.remove('campaignId');
    }
    if (existing?['rulesetId'] != null &&
        (existing!['rulesetId'] as String).isNotEmpty) {
      updateData.remove('rulesetId');
    }

    if (updateData.isNotEmpty) {
      await docRef.update(updateData);
    }
  }

  @override
  Future<Map<String, dynamic>?> getRoomDocument({
    required String roomCode,
  }) async {
    if (_firestore == null && Firebase.apps.isEmpty) {
      return null;
    }
    final clean = roomCode.trim().toUpperCase();
    final docRef = _effectiveFirestore.collection('rooms').doc(clean);
    final snap = await docRef.get();
    if (!snap.exists) return null;
    return snap.data();
  }
}
