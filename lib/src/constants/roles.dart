enum Role {
  owner,
  manager,
  cashier,
  staff,
}

/// A mapping of roles to their respective list of permissions.
/// 
/// owner → all permissions
/// manager → manage_staff, view_reports, edit_menu, process_sale
/// cashier → process_sale
/// staff → empty list
const Map<Role, List<String>> rolePermissions = {
  Role.owner: [
    'manage_staff',
    'view_reports',
    'edit_menu',
    'process_sale',
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
