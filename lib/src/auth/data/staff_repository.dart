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
    
    // Primary source of truth: businesses/{id}/members
    return _db
        .collection('businesses')
        .doc(_businessId)
        .collection('members')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AppUser.fromMap({
          ...data,
          'uid': data['uid'] ?? doc.id,
          'displayName': data['name'] ?? '',
          'role': data['role'] ?? 'staff',
          'isActive': data['status'] == 'active' || data['status'] == 'accepted',
          'businessId': _businessId,
        });
      }).toList();
    });
  }

  /// Updates a staff member's role and permissions.
  Future<void> updateStaffMember(AppUser staff) async {
    debugPrint('STAFF_REPO: Updating member ${staff.uid} in business $_businessId');
    
    final memberRef = _db
        .collection('businesses')
        .doc(_businessId)
        .collection('members')
        .doc(staff.uid);
    
    final Map<String, bool> overridesMap = {};
    staff.permissionOverrides.forEach((key, value) {
      overridesMap[key.name] = value;
    });

    await _db.runTransaction((tx) async {
      // 1. Update business member document
      tx.update(memberRef, {
        'role': staff.roleType.name,
        'permissions': overridesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Sync to legacy user profile if necessary
      final userRef = _db.collection('users').doc(staff.uid);
      final userSnap = await tx.get(userRef);
      if (userSnap.exists) {
        final userData = userSnap.data();
        if (userData?['businessId'] == _businessId) {
          tx.update(userRef, {
            'role': staff.roleType.name.toUpperCase(),
            'permissions': overridesMap,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  /// Removes a member from the business.
  Future<void> removeMember(String uid) async {
    debugPrint('STAFF_REPO: Removing member $uid from business $_businessId');

    // 1. Pre-check: Is this the last owner? 
    final membersRef = _db.collection('businesses').doc(_businessId).collection('members');
    final ownersSnap = await membersRef.where('role', isEqualTo: 'owner').get();
    
    final isTargetOwner = ownersSnap.docs.any((doc) => doc.id == uid);
    if (isTargetOwner && ownersSnap.docs.length <= 1) {
      throw Exception('Cannot remove the last owner of the business.');
    }

    // 2. Fetch legacy membership document(s) before transaction
    final legacyMembershipsRef = _db.collection('memberships');
    final legacySnap = await legacyMembershipsRef
        .where('uid', isEqualTo: uid)
        .where('businessId', isEqualTo: _businessId)
        .get();
    
    await _db.runTransaction((tx) async {
      // 3. Delete member from business sub-collection
      tx.delete(membersRef.doc(uid));

      // 4. Delete legacy membership document(s)
      for (var doc in legacySnap.docs) {
        tx.delete(doc.reference);
      }

      // 5. Update user profile to clear active business if it matches
      final userRef = _db.collection('users').doc(uid);
      final userSnap = await tx.get(userRef);
      if (userSnap.exists) {
        final userData = userSnap.data();
        final currentActiveBiz = userData?['businessId'] as String?;
        if (currentActiveBiz == _businessId) {
          tx.update(userRef, {
            'businessId': null,
            'role': 'CASHIER', // Reset to a safe default
          });
        }
      }
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
