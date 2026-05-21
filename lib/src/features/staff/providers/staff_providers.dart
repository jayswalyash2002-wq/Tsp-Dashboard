import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsp_dashboard/src/core/firebase/firebase_providers.dart';
import 'package:tsp_dashboard/src/constants/roles.dart';
import '../data/invite_service.dart';
import '../../rbac/domain/models/business_invite.dart';

final inviteServiceProvider = Provider<InviteService>((ref) {
  return InviteService(ref.watch(firestoreProvider));
});

final invitesStreamProvider = StreamProvider.family<List<InviteModel>, String>((ref, businessId) {
  final service = ref.watch(inviteServiceProvider);
  return service.watchInvites(businessId);
});

class CreateInviteNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> createInvite({
    required String staffName,
    required Role role,
    required String businessId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final code = _generateInviteCode();
      final now = DateTime.now();
      
      final invite = InviteModel(
        code: code,
        businessId: businessId,
        staffName: staffName,
        role: role,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 48)),
      );

      await ref.read(inviteServiceProvider).createInvite(invite);
      return code;
    });
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Excludes 0, O, 1, I
    final random = Random.secure();
    String gen() => List.generate(4, (index) => chars[random.nextInt(chars.length)]).join();
    return '${gen()}-${gen()}';
  }
}

final createInviteProvider = AsyncNotifierProvider<CreateInviteNotifier, String?>(() {
  return CreateInviteNotifier();
});
