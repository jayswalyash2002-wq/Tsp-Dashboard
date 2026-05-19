import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_providers.dart';
import '../../core/rbac/role.dart';

class StaffManagementScreen extends ConsumerWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management')),
      body: staffAsync.when(
        data: (staffList) => ListView.builder(
          itemCount: staffList.length,
          itemBuilder: (context, index) {
            final staff = staffList[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(staff.displayName),
              subtitle: Text('${staff.email} • ${staff.roleType.name.toUpperCase()}'),
              trailing: PopupMenuButton<RoleType>(
                icon: const Icon(Icons.edit_outlined),
                onSelected: (newRole) {
                  final repo = ref.read(staffRepositoryProvider);
                  if (repo != null) {
                    repo.updateStaffRole(staff.uid, newRole);
                  }
                },
                itemBuilder: (context) => RoleType.values
                    .map((role) => PopupMenuItem(
                          value: role,
                          child: Text(role.name.toUpperCase()),
                        ))
                    .toList(),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffDialog(context, ref),
        label: const Text('Add Staff'),
        icon: const Icon(Icons.person_add_alt_1),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    RoleType selectedRole = RoleType.cashier;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Staff'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Staff Name'),
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RoleType>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: RoleType.values
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role.name.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedRole = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                
                if (name.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final repo = ref.read(staffRepositoryProvider);
                if (repo == null) return;

                try {
                  await repo.addStaffMember(
                    name: name,
                    email: email,
                    role: selectedRole,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Staff added successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding staff: $e')),
                    );
                  }
                }
              },
              child: const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }
}
