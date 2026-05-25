import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'permission.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/app_user.dart';

/// A service that determines if the current user has specific permissions.
class PermissionManager {
  final AppUser? _user;

  PermissionManager({
    required AppUser? user,
  }) : _user = user;

  /// Returns true if the user has the specified permission.
  bool hasPermission(Permission permission) {
    if (_user == null) return false;
    return _user!.hasPermission(permission);
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

/// Provider that reacts to profile changes and updates permissions.
final permissionManagerProvider = Provider<PermissionManager>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  return PermissionManager(user: userProfile);
});
