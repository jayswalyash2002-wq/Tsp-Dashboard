import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'permission.dart';
import 'permission_manager.dart';

/// A widget that conditionally shows its [child] based on the user's permissions.
class PermissionGate extends ConsumerWidget {
  final Permission permission;
  final Widget child;
  final Widget fallback;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.watch(permissionManagerProvider).hasPermission(permission);
    
    return hasPermission ? child : fallback;
  }
}
