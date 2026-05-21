import 'package:cloud_firestore/cloud_firestore.dart';
import '../../rbac/domain/models/business_invite.dart';

class InviteService {
  final FirebaseFirestore _db;

  InviteService(this._db);

  Future<void> createInvite(InviteModel invite) async {
    final docRef = _db
        .collection('businesses')
        .doc(invite.businessId)
        .collection('invites')
        .doc();
    
    await docRef.set(invite.toMap());
  }

  Stream<List<InviteModel>> watchInvites(String businessId) {
    return _db
        .collection('businesses')
        .doc(businessId)
        .collection('invites')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InviteModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> revokeInvite(String businessId, String inviteId) async {
    await _db
        .collection('businesses')
        .doc(businessId)
        .collection('invites')
        .doc(inviteId)
        .delete();
  }

  Future<void> cleanupInvites(String businessId) async {
    final now = DateTime.now();
    final snapshot = await _db
        .collection('businesses')
        .doc(businessId)
        .collection('invites')
        .get();

    final batch = _db.batch();
    bool hasUpdates = false;

    for (var doc in snapshot.docs) {
      final invite = InviteModel.fromMap(doc.data(), doc.id);
      if (invite.isUsed || invite.expiresAt.isBefore(now)) {
        batch.delete(doc.reference);
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }
}
