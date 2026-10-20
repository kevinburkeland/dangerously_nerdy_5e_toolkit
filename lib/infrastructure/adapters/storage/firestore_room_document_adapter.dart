import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../application/services/room_document_port.dart';
import '../../../services/party/party_room_service.dart';
import '../../../utils/crypto_utils.dart';

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
  Future<void> deleteRoomWithHostProof({
    required String roomCode,
    String? hostKey,
  }) async {
    final clean = roomCode.trim().toUpperCase();
    final roomRef = _effectiveFirestore.collection('rooms').doc(clean);
    final proofRef = roomRef.collection('hostProof').doc('current');

    final batch = _effectiveFirestore.batch();
    if (hostKey != null && hostKey.isNotEmpty) {
      final cleanKey = CryptoUtils.extractHostKey(hostKey);
      batch.set(proofRef, {'hostKey': cleanKey});
    }
    batch.delete(roomRef);

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw UnauthorizedHostActionException(
            'Server denied room deletion: invalid host proof or insufficient capability.');
      }
      rethrow;
    } catch (e) {
      throw UnauthorizedHostActionException(
          'Server denied room deletion: $e');
    }

    try {
      await proofRef.delete();
    } catch (_) {}
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
}
