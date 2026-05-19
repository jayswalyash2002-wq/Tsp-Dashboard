import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/app_user.dart';
import '../../core/rbac/role.dart';

class StaffRepository {
  StaffRepository(this._db, this._businessId);

  final FirebaseFirestore _db;
  final String _businessId;

  /// Fetches all staff members belonging to a specific business.
  Stream<List<AppUser>> watchStaff() {
    debugPrint('STAFF_REPO: Watching staff for businessId: $_businessId');
    return _db
        .collection('users')
        .where('businessId', isEqualTo: _businessId)
        .snapshots()
        .map((snapshot) {
      final staff = snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
          .toList();
      
      // Strict isolation filter
      return staff.where((u) => u.businessId == _businessId).toList();
    });
  }

  /// Updates a staff member's role.
  Future<void> updateStaffRole(String uid, RoleType newRole) async {
    debugPrint('STAFF_REPO: Updating role for user $uid in business $_businessId');
    
    final docRef = _db.collection('users').doc(uid);
    
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('User not found');
      
      final existingBusinessId = snap.data()?['businessId']?.toString();
      if (existingBusinessId != _businessId) {
        debugPrint('CRITICAL: Blocked unauthorized staff role update. '
            'Expected: $_businessId, Found: $existingBusinessId');
        throw Exception('Access Denied: Business ownership mismatch');
      }

      tx.update(docRef, {
        'role': newRole.name.toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Deactivates a staff member.
  Future<void> toggleStaffStatus(String uid, bool isActive) async {
    debugPrint('STAFF_REPO: Toggling status for user $uid in business $_businessId');
    
    final docRef = _db.collection('users').doc(uid);
    
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) throw Exception('User not found');
      
      final existingBusinessId = snap.data()?['businessId']?.toString();
      if (existingBusinessId != _businessId) {
        debugPrint('CRITICAL: Blocked unauthorized staff status toggle. '
            'Expected: $_businessId, Found: $existingBusinessId');
        throw Exception('Access Denied: Business ownership mismatch');
      }

      tx.update(docRef, {
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
  
  /// Adds a new staff member to the business.
  Future<void> addStaffMember({
    required String name,
    required String email,
    required RoleType role,
  }) async {
    debugPrint('STAFF_REPO: Adding new staff member for businessId: $_businessId');
    
    final docRef = _db.collection('users').doc(); 
    await docRef.set({
      'uid': docRef.id,
      'displayName': name,
      'email': email.toLowerCase().trim(),
      'role': role.name.toUpperCase(),
      'businessId': _businessId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
