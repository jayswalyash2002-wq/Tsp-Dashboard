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

  Future<void> claimInvite({
    required String businessId,
    required String inviteCode,
    required String uid,
    required String displayName,
  }) async {
    final invitesRef = _db
        .collection('businesses')
        .doc(businessId)
        .collection('invites');

    final inviteSnap = await invitesRef
        .where('code', isEqualTo: inviteCode)
        .where('isUsed', isEqualTo: false)
        .limit(1)
        .get();

    if (inviteSnap.docs.isEmpty) {
      throw Exception('Invalid or expired invite code.');
    }

    final inviteDoc = inviteSnap.docs.first;
    final inviteData = inviteDoc.data();
    final expiresAt = (inviteData['expiresAt'] as Timestamp).toDate();

    if (expiresAt.isBefore(DateTime.now())) {
      throw Exception('Invite code has expired.');
    }

    final roleStr = inviteData['role'] as String;

    await _db.runTransaction((transaction) async {
      // 1. Mark invite as used
      transaction.update(inviteDoc.reference, {'isUsed': true});

      // 2. Create membership
      final membershipRef = _db.collection('memberships').doc();
      transaction.set(membershipRef, {
        'uid': uid,
        'businessId': businessId,
        'role': roleStr.toLowerCase(),
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'system_invite',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': 'system_invite',
      });

      // 3. Update user profile with businessId and role
      final userRef = _db.collection('users').doc(uid);
      transaction.update(userRef, {
        'businessId': businessId,
        'role': roleStr.toUpperCase(),
      });
    });
  }
}
