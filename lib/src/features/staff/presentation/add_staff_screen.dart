import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tsp_dashboard/src/constants/roles.dart';
import 'package:tsp_dashboard/src/auth/data/auth_providers.dart';
import '../../../memberships/data/membership_providers.dart';
import '../../../memberships/domain/membership.dart';
import '../providers/staff_providers.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  Role _selectedRole = Role.staff;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final businessId = ref.read(userBusinessIdProvider);
    if (businessId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No active business found')),
      );
      return;
    }

    await ref.read(createInviteProvider.notifier).createInvite(
          staffName: _nameController.text.trim(),
          role: _selectedRole,
          businessId: businessId,
        );

    final state = ref.read(createInviteProvider);
    if (state.hasValue && state.value != null && mounted) {
      context.push(
        '/staff/invite-code',
        extra: {
          'code': state.value,
          'role': _selectedRole,
          'name': _nameController.text.trim(),
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final createInviteState = ref.watch(createInviteProvider);
    final isLoading = createInviteState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Staff'),
        actions: [
          TextButton(
            onPressed: () => context.push('/staff/pending'),
            child: const Text('Pending Invites'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create an Invite',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generate a secure invite code for your new team member.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nameController,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'Staff Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<Role>(
                isExpanded: true,
                value: _selectedRole,
                onChanged: isLoading ? null : (v) => setState(() => _selectedRole = v!),
                decoration: InputDecoration(
                  labelText: 'Role',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: Role.values.map((role) {
                  // Only owners can invite other owners
                  final currentSession = ref.watch(sessionProvider);
                  final isOwner = currentSession.role == MembershipRole.owner;
                  
                  if (role == Role.owner && !isOwner) {
                    return const DropdownMenuItem<Role>(
                      value: null,
                      enabled: false,
                      child: Text('OWNER (Owner only)', overflow: TextOverflow.ellipsis),
                    );
                  }

                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase(), overflow: TextOverflow.ellipsis),
                  );
                }).where((item) => item.value != null).toList(),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _notesController,
                enabled: !isLoading,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Optional Notes',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),
              if (createInviteState.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Error: ${createInviteState.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton(
                onPressed: isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Generate Invite Code',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
