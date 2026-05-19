import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/membership.dart';

class MembershipRepository {
  final FirebaseFirestore _db;

  MembershipRepository(this._db);

  Future<List<Membership>> getUserMemberships(String uid) async {
    final snapshot = await _db
        .collection('memberships')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    return snapshot.docs
        .map((doc) => Membership.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> createOwnerMembership({
    required String uid,
    required String businessId,
    required String createdBy,
  }) async {
    final ref = _db.collection('memberships').doc();
    final now = DateTime.now();
    
    await ref.set({
      'uid': uid,
      'businessId': businessId,
      'role': MembershipRole.owner.name,
      'status': MembershipStatus.active.name,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': createdBy,
    });
  }

  Future<void> createStaffMembership({
    required String uid,
    required String businessId,
    String? branchId,
    required MembershipRole role,
    required String createdBy,
  }) async {
    final ref = _db.collection('memberships').doc();
    
    await ref.set({
      'uid': uid,
      'businessId': businessId,
      'branchId': branchId,
      'role': role.name,
      'status': MembershipStatus.active.name,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': createdBy,
    });
  }

  Future<void> suspendMembership(String membershipId, String updatedBy) async {
    await _db.collection('memberships').doc(membershipId).update({
      'status': MembershipStatus.suspended.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  Future<void> revokeMembership(String membershipId, String updatedBy) async {
    await _db.collection('memberships').doc(membershipId).update({
      'status': MembershipStatus.revoked.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }
}
