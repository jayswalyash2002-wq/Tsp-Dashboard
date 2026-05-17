import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/app_user.dart';
import '../../core/rbac/role.dart';

class StaffRepository {
  final FirebaseFirestore _db;

  StaffRepository(this._db);

  /// Fetches all staff members belonging to a specific business.
  Stream<List<AppUser>> watchStaff(String businessId) {
    return _db
        .collection('users')
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppUser.fromMap(doc.data()))
            .toList());
  }

  /// Updates a staff member's role.
  Future<void> updateStaffRole(String uid, RoleType newRole) async {
    await _db.collection('users').doc(uid).update({
      'role': newRole.name.toUpperCase(),
    });
  }

  /// Deactivates a staff member.
  Future<void> toggleStaffStatus(String uid, bool isActive) async {
    await _db.collection('users').doc(uid).update({
      'isActive': isActive,
    });
  }
  
  /// Adds a new staff member to the business.
  Future<void> addStaffMember({
    required String businessId,
    required String name,
    required String email,
    required RoleType role,
  }) async {
    final docRef = _db.collection('users').doc(); // Auto-generate ID or use email?
    // Using auto-ID for now. In production, this would be linked to a real Auth user.
    await docRef.set({
      'uid': docRef.id,
      'displayName': name,
      'email': email.toLowerCase().trim(),
      'role': role.name.toUpperCase(),
      'businessId': businessId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Note: Admin creates staff accounts by adding a record to the users collection.
}
