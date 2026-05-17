import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import 'permission.dart';

/// A service that determines if the current user has specific permissions.
class PermissionManager {
  final Set<Permission> _userPermissions;
  final bool _isLoggedIn;

  PermissionManager({
    required Set<Permission> permissions,
    required bool isLoggedIn,
  })  : _userPermissions = permissions,
        _isLoggedIn = isLoggedIn;

  /// Returns true if the user has the specified permission.
  bool hasPermission(Permission permission) {
    if (!_isLoggedIn) return false;
    return _userPermissions.contains(permission);
  }

  /// Returns true if the user has AT LEAST ONE of the specified permissions.
  bool hasAnyPermission(List<Permission> permissions) {
    return permissions.any(hasPermission);
  }

  /// Throws an error if the user lacks the permission.
  void requirePermission(Permission permission) {
    if (!hasPermission(permission)) {
      throw UnauthorizedException(permission);
    }
  }
}

class UnauthorizedException implements Exception {
  final Permission permission;
  UnauthorizedException(this.permission);
  @override
  String toString() => 'Access Denied: Missing ${permission.name}';
}

/// Provider that reacts to user profile changes and updates permissions.
final permissionManagerProvider = Provider<PermissionManager>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  
  return profileAsync.maybeWhen(
    data: (user) {
      if (user == null) return PermissionManager(permissions: {}, isLoggedIn: false);
      return PermissionManager(
        permissions: user.roleType.permissions,
        isLoggedIn: true,
      );
    },
    orElse: () => PermissionManager(permissions: {}, isLoggedIn: false),
  );
});
