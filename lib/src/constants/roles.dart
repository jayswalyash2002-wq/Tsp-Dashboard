enum Role {
  owner,
  admin,
  manager,
  cashier,
  staff,
  viewer,
}

/// A mapping of roles to their respective list of permissions.
const Map<Role, List<String>> rolePermissions = {
  Role.owner: [
    'manage_staff',
    'view_reports',
    'edit_menu',
    'process_sale',
    'manage_business',
  ],
  Role.admin: [
    'manage_staff',
    'view_reports',
    'edit_menu',
    'process_sale',
    'manage_business',
  ],
  Role.manager: [
    'manage_staff',
    'view_reports',
    'edit_menu',
    'process_sale',
  ],
  Role.cashier: [
    'process_sale',
  ],
  Role.staff: [],
  Role.viewer: [
    'view_reports',
  ],
};

/// Helper to check if a [Role] has a specific permission [action].
bool hasPermission(Role role, String action) {
  return rolePermissions[role]?.contains(action) ?? false;
}

/// Helper to safely parse a string into a [Role].
/// Defaults to [Role.staff] if unknown.
Role roleFromString(String value) {
  final lowercaseValue = value.toLowerCase().trim();
  return Role.values.firstWhere(
    (role) => role.name == lowercaseValue,
    orElse: () => Role.staff,
  );
}
