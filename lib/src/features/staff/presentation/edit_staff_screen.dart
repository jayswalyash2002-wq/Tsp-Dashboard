import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/rbac/permission.dart';
import '../../../core/rbac/role.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/data/auth_providers.dart';

class EditStaffScreen extends ConsumerStatefulWidget {
  const EditStaffScreen({super.key, required this.staff});
  final AppUser staff;

  @override
  ConsumerState<EditStaffScreen> createState() => _EditStaffScreenState();
}

class _EditStaffScreenState extends ConsumerState<EditStaffScreen> {
  late RoleType _selectedRole;
  late Map<Permission, bool> _permissionOverrides;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.staff.roleType;
    _permissionOverrides = Map.from(widget.staff.permissionOverrides);
  }

  void _onRoleChanged(RoleType? newRole) {
    if (newRole == null) return;
    setState(() {
      _selectedRole = newRole;
      // When role changes, we can either clear overrides or keep them.
      // Resetting to role defaults is often expected.
      _permissionOverrides.clear();
    });
  }

  void _togglePermission(Permission p, bool? value) {
    setState(() {
      if (value == null) return;
      
      final roleDefault = _selectedRole.permissions.contains(p);
      if (value == roleDefault) {
        // If it matches the new role's default, we can remove the override
        _permissionOverrides.remove(p);
      } else {
        _permissionOverrides[p] = value;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(staffRepositoryProvider);
      if (repo == null) throw Exception('Staff repository not available');

      final updatedStaff = AppUser(
        uid: widget.staff.uid,
        email: widget.staff.email,
        displayName: widget.staff.displayName,
        roleType: _selectedRole,
        businessId: widget.staff.businessId,
        isActive: widget.staff.isActive,
        permissionOverrides: _permissionOverrides,
      );

      await repo.updateStaffMember(updatedStaff);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(userProfileProvider).value;
    final isOwner = currentUser?.roleType == RoleType.owner;
    
    // Safety: If somehow a non-owner gets here and tries to edit an owner
    final editingOwner = widget.staff.roleType == RoleType.owner;
    final canEdit = isOwner || !editingOwner;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Staff Permissions'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
          else if (canEdit)
            TextButton(
              onPressed: _save,
              child: const Text('SAVE'),
            ),
        ],
      ),
      body: canEdit ? ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.staff.displayName, style: Theme.of(context).textTheme.headlineSmall),
                  Text(widget.staff.email, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RoleType>(
                    value: _selectedRole,
                    decoration: const InputDecoration(labelText: 'Base Role'),
                    items: RoleType.values.map((role) {
                      // Only owners can promote others to owner
                      if (role == RoleType.owner && !isOwner) {
                        return const DropdownMenuItem(
                          value: RoleType.owner,
                          enabled: false,
                          child: Text('OWNER (Owner only)'),
                        );
                      }
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: _isSaving ? null : _onRoleChanged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CUSTOM PERMISSIONS',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _isSaving ? null : () => setState(() => _permissionOverrides.clear()),
                  child: const Text('Reset to Defaults'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...Permission.values.map((p) {
            final roleDefault = _selectedRole.permissions.contains(p);
            final hasOverride = _permissionOverrides.containsKey(p);
            final effectiveValue = hasOverride ? _permissionOverrides[p]! : roleDefault;

            return CheckboxListTile(
              title: Text(_formatPermissionName(p.name)),
              subtitle: hasOverride 
                ? Text('Override (Default: ${roleDefault ? "ON" : "OFF"})', 
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 12))
                : Text('Default from Role', style: const TextStyle(fontSize: 12)),
              value: effectiveValue,
              onChanged: _isSaving ? null : (val) => _togglePermission(p, val),
            );
          }),
        ],
      ) : const Center(child: Text('You do not have permission to edit this member.')),
    );
  }

  String _formatPermissionName(String name) {
    // Convert camelCase to Space Separated Title Case
    final result = name.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}');
    return result[0].toUpperCase() + result.substring(1);
  }
}
