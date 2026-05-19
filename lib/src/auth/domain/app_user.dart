import 'package:flutter/foundation.dart';
import '../../core/rbac/role.dart';
import '../../core/rbac/permission.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final RoleType roleType;
  final String? businessId;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.roleType,
    this.businessId,
    this.isActive = true,
  });

  /// Getter for backward compatibility with code expecting .role
  Role get role => Role(roleType);

  bool hasPermission(Permission permission) => roleType.permissions.contains(permission);

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final roleStr = map['role'] as String?;
    if (roleStr == null) {
      debugPrint('APP_USER: Missing role in Firestore document for UID ${map['uid']}. Relying on Membership-based session role.');
    } else {
      debugPrint('APP_USER: Legacy role found in Firestore: $roleStr');
    }
    
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      roleType: roleStr != null ? RoleType.fromString(roleStr) : RoleType.cashier,
      businessId: map['businessId'],
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': roleType.name.toUpperCase(),
      'businessId': businessId,
      'isActive': isActive,
    };
  }
}
