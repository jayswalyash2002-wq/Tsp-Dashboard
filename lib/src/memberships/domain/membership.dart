import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/rbac/permission.dart';

enum MembershipRole {
  owner,
  admin,
  manager,
  cashier,
  staff,
  viewer;

  static MembershipRole fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final role in MembershipRole.values) {
      if (role.name == normalized) return role;
    }
    // Fallback for legacy or special cases
    if (normalized == 'partner') return MembershipRole.owner;
    
    debugPrint('MEMBERSHIP_ERROR: Role "$value" is invalid. Defaulting to staff.');
    return MembershipRole.staff;
  }

  Set<Permission> get permissions {
    switch (this) {
      case MembershipRole.owner:
      case MembershipRole.admin:
        return Permission.values.toSet();
      case MembershipRole.manager:
        return {
          Permission.createOrder,
          Permission.editOrder,
          Permission.viewReports,
          Permission.manageExpenses,
          Permission.manageBusiness,
          Permission.accessSettings,
          Permission.manageStaff,
          Permission.manageInventory,
          Permission.managePurchases,
          Permission.manageMenu,
          Permission.manageDiscounts,
          Permission.viewActivityLog,
        };
      case MembershipRole.cashier:
        return {
          Permission.createOrder,
          Permission.editOrder,
        };
      case MembershipRole.staff:
        return {};
      case MembershipRole.viewer:
        return {
          Permission.viewReports,
        };
    }
  }
}

enum MembershipStatus {
  active,
  suspended,
  invited,
  revoked;

  static MembershipStatus fromString(String value) {
    return MembershipStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => MembershipStatus.revoked,
    );
  }
}

class Membership {
  final String membershipId;
  final String uid;
  final String businessId;
  final String? branchId;
  final MembershipRole role;
  final MembershipStatus status;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;

  Membership({
    required this.membershipId,
    required this.uid,
    required this.businessId,
    this.branchId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory Membership.fromMap(Map<String, dynamic> map, String id) {
    return Membership(
      membershipId: id,
      uid: map['uid'] ?? '',
      businessId: map['businessId'] ?? '',
      branchId: map['branchId'],
      role: MembershipRole.fromString(map['role'] ?? ''),
      status: MembershipStatus.fromString(map['status'] ?? ''),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: map['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'businessId': businessId,
      'branchId': branchId,
      'role': role.name,
      'status': status.name,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
      'updatedBy': updatedBy,
    };
  }
}
