import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../domain/app_user.dart';
import '../../core/rbac/role.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../activity_log/domain/repositories/activity_log_repository.dart';
import '../../activity_log/domain/entities/activity_log_entry.dart';

class StaffRepository {
  StaffRepository(this._db, this._businessId, [this._activityLogRepo]);

  final FirebaseFirestore _db;
  final String _businessId;
  final ActivityLogRepository? _activityLogRepo;

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
  Future<void> updateStaffMember(AppUser staff, {required AppUser performer}) async {
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

    try {
      await _db.runTransaction((tx) async {
        debugPrint('STAFF_REPO: START_TRANSACTION [UpdateMember]');
        
        // 1. READS (Must be before writes)
        final userRef = _db.collection('users').doc(staff.uid);
        final userSnap = await tx.get(userRef);

        // 2. WRITES
        tx.update(memberRef, {
          'role': staff.roleType.name,
          'permissions': overridesMap,
          'updatedAt': FieldValue.serverTimestamp(),
        });

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

        // 3. ACTIVITY LOG
        if (_activityLogRepo != null) {
          final logEntry = ActivityLogEntry(
            activityLogId: '',
            businessId: _businessId,
            performedBy: performer.uid,
            performedByName: performer.displayName,
            performedByRole: performer.roleType.name,
            action: ActivityAction.memberRoleChanged,
            category: ActivityCategory.membership,
            targetType: 'staff',
            targetId: staff.uid,
            targetName: staff.displayName,
            metadata: {
              'newRole': staff.roleType.name,
              'overridesCount': staff.permissionOverrides.length,
            },
            appVersion: '1.0.0',
            platform: 'mobile',
          );
          final logData = _activityLogRepo!.buildActivityLogBatchData(logEntry);
          tx.set(logData.ref, logData.data);
        }
        
        debugPrint('STAFF_REPO: COMMIT_TRANSACTION [UpdateMember]');
      });
    } catch (e, s) {
      debugPrint('STAFF_REPO: Transaction failed for updateStaffMember: $e');
      debugPrint('Stacktrace: $s');
      rethrow;
    }
  }

  /// Removes a member from the business.
  Future<void> removeMember(String uid, {required AppUser performer}) async {
    debugPrint('STAFF_REPO: Removing member $uid from business $_businessId');

    // 1. Pre-check: Is this the last owner? 
    final membersRef = _db.collection('businesses').doc(_businessId).collection('members');
    
    // Fetch target member info before transaction for logging
    final targetMemberDoc = await membersRef.doc(uid).get();
    if (!targetMemberDoc.exists) {
      throw Exception('Staff member not found in business.');
    }
    final targetMemberName = targetMemberDoc.data()?['name'] ?? 'Unknown Member';

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
    
    try {
      await _db.runTransaction((tx) async {
        debugPrint('STAFF_REPO: START_TRANSACTION [RemoveMember]');

        // 3. READS (Must be before writes)
        final userRef = _db.collection('users').doc(uid);
        final userSnap = await tx.get(userRef);

        // 4. WRITES
        
        // Optional: Update staff count in business doc if denormalized count is maintained
        final businessRef = _db.collection('businesses').doc(_businessId);
        tx.update(businessRef, {
          'staffCount': FieldValue.increment(-1),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Delete member from business sub-collection
        tx.delete(membersRef.doc(uid));

        // Delete legacy membership document(s)
        for (var doc in legacySnap.docs) {
          tx.delete(doc.reference);
        }

        // Update user profile to clear active business if it matches
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

        // 5. ACTIVITY LOG
        if (_activityLogRepo != null) {
          final logEntry = ActivityLogEntry(
            activityLogId: '',
            businessId: _businessId,
            performedBy: performer.uid,
            performedByName: performer.displayName,
            performedByRole: performer.roleType.name,
            action: ActivityAction.memberRevoked,
            category: ActivityCategory.membership,
            targetType: 'staff',
            targetId: uid,
            targetName: targetMemberName,
            metadata: {
              'removedUid': uid,
              'reason': 'Manual removal by admin',
            },
            appVersion: '1.0.0',
            platform: 'mobile',
          );
          final logData = _activityLogRepo!.buildActivityLogBatchData(logEntry);
          tx.set(logData.ref, logData.data);
        }

        debugPrint('STAFF_REPO: COMMIT_TRANSACTION [RemoveMember]');
      });
    } catch (e, s) {
      debugPrint('STAFF_REPO: Transaction failed for removeMember: $e');
      debugPrint('Stacktrace: $s');
      rethrow;
    }
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
