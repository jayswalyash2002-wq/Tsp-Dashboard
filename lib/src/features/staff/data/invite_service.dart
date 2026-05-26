import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    required String email,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      debugPrint('FIRESTORE: CLAIM_INVITE_START for $normalizedEmail (UID: $uid) in Business: $businessId');
      
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
        debugPrint('FIRESTORE: CLAIM_INVITE_FAILED - Code $inviteCode not found or already used.');
        throw Exception('Invalid or expired invite code.');
      }

      final inviteDoc = inviteSnap.docs.first;
      final inviteData = inviteDoc.data();
      final expiresAt = (inviteData['expiresAt'] as Timestamp).toDate();

      if (expiresAt.isBefore(DateTime.now())) {
        debugPrint('FIRESTORE: CLAIM_INVITE_FAILED - Code $inviteCode expired at $expiresAt');
        throw Exception('Invite code has expired.');
      }

      final roleStr = inviteData['role'] as String;
      debugPrint('FIRESTORE: CLAIM_INVITE_VALIDATED - Role: $roleStr');

      await _db.runTransaction((transaction) async {
        debugPrint('FIRESTORE: Starting Transaction...');
        
        // 0. Verify user document exists (created during sign up)
        final userRef = _db.collection('users').doc(uid);
        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          debugPrint('FIRESTORE: ERROR - User profile $uid does not exist in transaction.');
          throw Exception('User profile not found. Please try again.');
        }

        // 1. Mark invite as used
        transaction.update(inviteDoc.reference, {'isUsed': true});

        // 2. Create membership in businesses/{businessId}/members/{userId}
        final memberRef = _db
            .collection('businesses')
            .doc(businessId)
            .collection('members')
            .doc(uid);
        
        transaction.set(memberRef, {
          'uid': uid,
          'businessId': businessId,
          'name': displayName,
          'email': normalizedEmail,
          'role': roleStr.toLowerCase(),
          'status': 'accepted',
          'isActive': true,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // 2.1 Create Legacy membership document
        final legacyMembershipId = 'invite_${businessId}_$uid';
        final membershipRef = _db.collection('memberships').doc(legacyMembershipId);
        transaction.set(membershipRef, {
          'uid': uid,
          'businessId': businessId,
          'branchId': null,
          'role': roleStr.toLowerCase(),
          'status': 'accepted',
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': 'invite_system',
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': 'invite_system',
        });

        // 3. Update user profile with businessId and role (Legacy support)
        transaction.update(userRef, {
          'businessId': businessId,
          'role': roleStr.toUpperCase(),
        });
        debugPrint('FIRESTORE: Transaction operations added.');
      });
      debugPrint('FIRESTORE: TRANSACTION_COMMITTED successfully for UID: $uid');
    } catch (e, s) {
      debugPrint('FIRESTORE_ERROR: claimInvite failed for business $businessId, code $inviteCode');
      debugPrint('Error: $e');
      debugPrint('Stacktrace: $s');
      rethrow;
    }
  }

  Future<InviteModel?> findInviteByCode(String code) async {
    try {
      print('DEBUG: Searching for invite code: $code');
      // Collection Group query to find the invite across all businesses
      // We simplify the query to use only one where clause to potentially 
      // reduce index requirements, and handle 'isUsed' check in memory.
      final snapshot = await _db
          .collectionGroup('invites')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('DEBUG: No invite found with code: $code');
        return null;
      }
      
      final doc = snapshot.docs.first;
      final invite = InviteModel.fromMap(doc.data(), doc.id);
      
      if (invite.isUsed) {
        print('DEBUG: Invite code $code found but already used.');
        return null;
      }
      
      print('DEBUG: Invite found for business: ${invite.businessId}');
      return invite;
    } catch (e, s) {
      print('FIRESTORE_ERROR: findInviteByCode failed for code $code');
      print('Error: $e');
      if (e.toString().contains('failed-precondition')) {
        print('INSTRUCTION: This query requires a Collection Group index for "invites".');
        print('Go to the Firebase Console -> Firestore -> Indexes -> Composite.');
        print('Create an index for Collection ID: invites, Field: code (Ascending), Query Scope: Collection Group.');
      }
      print('Stacktrace: $s');
      rethrow;
    }
  }
}
