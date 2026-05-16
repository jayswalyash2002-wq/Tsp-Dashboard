
enum AppRole {
  admin,
  manager,
  cashier;

  static AppRole fromString(String? role) {
    if (role == null) return AppRole.cashier;
    final lowerRole = role.toLowerCase().trim();
    switch (lowerRole) {
      case 'admin':
      case 'owner': // Legacy compatibility
        return AppRole.admin;
      case 'manager':
        return AppRole.manager;
      case 'cashier':
        return AppRole.cashier;
      default:
        return AppRole.cashier;
    }
  }

  AppPermissions get permissions {
    switch (this) {
      case AppRole.admin:
        return AppPermissions.admin();
      case AppRole.manager:
        return AppPermissions.manager();
      case AppRole.cashier:
        return AppPermissions.cashier();
    }
  }
}

class AppPermissions {
  final bool canManageBusiness;
  final bool canViewReports;
  final bool canManageInventory;
  final bool canCreateOrders;
  final bool canEditOrders;
  final bool canProcessPayments;
  final bool canManageExpenses;
  final bool canManageStaff;

  const AppPermissions({
    required this.canManageBusiness,
    required this.canViewReports,
    required this.canManageInventory,
    required this.canCreateOrders,
    required this.canEditOrders,
    required this.canProcessPayments,
    required this.canManageExpenses,
    required this.canManageStaff,
  });

  factory AppPermissions.admin() => const AppPermissions(
        canManageBusiness: true,
        canViewReports: true,
        canManageInventory: true,
        canCreateOrders: true,
        canEditOrders: true,
        canProcessPayments: true,
        canManageExpenses: true,
        canManageStaff: true,
      );

  factory AppPermissions.manager() => const AppPermissions(
        canManageBusiness: false,
        canViewReports: true,
        canManageInventory: true,
        canCreateOrders: true,
        canEditOrders: true,
        canProcessPayments: true,
        canManageExpenses: true,
        canManageStaff: false,
      );

  factory AppPermissions.cashier() => const AppPermissions(
        canManageBusiness: false,
        canViewReports: false,
        canManageInventory: false,
        canCreateOrders: true,
        canEditOrders: true,
        canProcessPayments: true,
        canManageExpenses: false,
        canManageStaff: false,
      );

  Map<String, dynamic> toMap() => {
        'canManageBusiness': canManageBusiness,
        'canViewReports': canViewReports,
        'canManageInventory': canManageInventory,
        'canCreateOrders': canCreateOrders,
        'canEditOrders': canEditOrders,
        'canProcessPayments': canProcessPayments,
        'canManageExpenses': canManageExpenses,
        'canManageStaff': canManageStaff,
      };
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final AppRole role;
  final String? businessId;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.businessId,
  });

  AppPermissions get permissions => role.permissions;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: AppRole.fromString(map['role']),
      businessId: map['businessId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'businessId': businessId,
    };
  }
}
