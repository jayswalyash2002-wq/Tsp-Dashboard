import 'package:flutter/foundation.dart';
import 'permission.dart';

enum RoleType {
  owner,
  admin,
  manager,
  cashier,
  staff,
  viewer,
  kitchen,
  accountant;

  Set<Permission> get permissions {
    switch (this) {
      case RoleType.owner:
      case RoleType.admin:
        return Permission.values.toSet();
      case RoleType.manager:
        return {
          Permission.createOrder,
          Permission.editOrder,
          Permission.viewReports,
          Permission.manageExpenses,
          Permission.manageBusiness,
          Permission.accessSettings,
        };
      case RoleType.cashier:
        return {
          Permission.createOrder,
          Permission.editOrder,
        };
      case RoleType.staff:
        return {};
      case RoleType.viewer:
        return {
          Permission.viewReports,
        };
      case RoleType.kitchen:
        return {
          // View only
        };
      case RoleType.accountant:
        return {
          Permission.viewReports,
          Permission.manageExpenses,
        };
    }
  }

  static RoleType fromString(String role) {
    final normalized = role.trim().toLowerCase();
    for (final r in RoleType.values) {
      if (r.name == normalized) return r;
    }
    debugPrint('ROLE_TYPE_ERROR: Role "$role" is invalid. Defaulting to staff for compatibility.');
    return RoleType.staff;
  }
}

/// Helper class to maintain backward compatibility with previous Role implementation 
class Role {
  final RoleType type;
  
  const Role(this.type);
  
  String get name => type.name.toUpperCase();
  bool hasPermission(Permission p) => type.permissions.contains(p);

  static final Map<String, Role> defaultRoles = {
    'ADMIN': Role(RoleType.admin),
    'MANAGER': Role(RoleType.manager),
    'CASHIER': Role(RoleType.cashier),
    'KITCHEN': Role(RoleType.kitchen),
    'ACCOUNTANT': Role(RoleType.accountant),
  };
}
