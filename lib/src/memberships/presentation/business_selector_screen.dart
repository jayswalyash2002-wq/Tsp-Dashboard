import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/membership.dart';
import '../data/membership_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../activity_log/domain/entities/activity_log_entry.dart';
import '../../core/device/device_providers.dart';
import '../../auth/data/auth_providers.dart';

class BusinessSelectorScreen extends ConsumerWidget {
  final List<Membership> memberships;

  const BusinessSelectorScreen({super.key, required this.memberships});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Business'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: memberships.length,
        itemBuilder: (context, index) {
          final membership = memberships[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.business)),
              title: Text('Business ID: ${membership.businessId}'),
              subtitle: Text('Role: ${membership.role.name.toUpperCase()}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (user != null) {
                  ref.read(sessionProvider.notifier).setSession(
                    businessId: membership.businessId,
                    userUid: user.uid,
                    role: membership.role,
                    membershipId: membership.membershipId,
                    branchId: membership.branchId,
                  );

                  // Log Login event
                  final logRepo = ref.read(activityLogRepositoryProvider);
                  final profile = ref.read(userProfileProvider).value;
                  final deviceIdentity = await ref.read(deviceIdentityProvider.future);
                  
                  final logEntry = ActivityLogEntry(
                    activityLogId: '',
                    businessId: membership.businessId,
                    performedBy: user.uid,
                    performedByName: profile?.displayName ?? 'User',
                    performedByRole: membership.role.name,
                    action: ActivityAction.userLoggedIn,
                    category: ActivityCategory.authentication,
                    metadata: {},
                    appVersion: deviceIdentity.appVersion,
                    platform: deviceIdentity.platform,
                  );
                  
                  logRepo.logActivity(logEntry);
                }
              },
            ),
          );
        },
      ),
    );
  }
}
