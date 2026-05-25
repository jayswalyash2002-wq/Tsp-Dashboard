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
  final Map<Permission, bool> permissionOverrides;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.roleType,
    this.businessId,
    this.isActive = true,
    this.permissionOverrides = const {},
  });

  /// Getter for backward compatibility with code expecting .role
  Role get role => Role(roleType);

  bool hasPermission(Permission permission) {
    // 1. Check overrides first
    if (permissionOverrides.containsKey(permission)) {
      return permissionOverrides[permission]!;
    }
    // 2. Fallback to role defaults
    return roleType.permissions.contains(permission);
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    // 1. Try to find the role string from various possible fields
    final roleStr = map['role'] as String? ?? 
                    map['roleType'] as String? ?? 
                    map['MembershipRole'] as String?;
    
    // 2. Parse permission overrides
    final Map<Permission, bool> overrides = {};
    final rawOverrides = map['permissions'] as Map<dynamic, dynamic>?;
    if (rawOverrides != null) {
      for (var entry in rawOverrides.entries) {
        try {
          final p = Permission.values.firstWhere((e) => e.name == entry.key.toString());
          if (entry.value is bool) {
            overrides[p] = entry.value as bool;
          } else if (entry.value is String) {
            overrides[p] = entry.value.toLowerCase() == 'true';
          }
        } catch (_) {}
      }
    }

    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? map['name'] ?? '',
      roleType: RoleType.fromString(roleStr ?? 'staff'),
      businessId: map['businessId'],
      isActive: map['isActive'] ?? true,
      permissionOverrides: overrides,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, bool> overridesMap = {};
    permissionOverrides.forEach((key, value) {
      overridesMap[key.name] = value;
    });

    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': roleType.name.toUpperCase(),
      'businessId': businessId,
      'isActive': isActive,
      'permissions': overridesMap,
    };
  }
}
