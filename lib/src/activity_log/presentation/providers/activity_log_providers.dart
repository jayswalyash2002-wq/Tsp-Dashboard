import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../core/device/device_providers.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../memberships/data/membership_providers.dart';
import '../../data/repositories/activity_log_repository_impl.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../../domain/entities/activity_log_enums.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../../domain/usecases/get_activity_log_usecase.dart';
import '../../domain/usecases/log_activity_usecase.dart';

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepositoryImpl(ref.watch(firestoreProvider));
});

final getActivityLogUseCaseProvider = Provider<GetActivityLogUseCase>((ref) {
  return GetActivityLogUseCase(ref.watch(activityLogRepositoryProvider));
});

final logActivityUseCaseProvider = Provider<LogActivityUseCase>((ref) {
  final session = ref.watch(sessionProvider);
  final profile = ref.watch(userProfileProvider).value;
  final deviceIdentity = ref.watch(deviceIdentityProvider).value;

  if (!session.isLoaded ||
      session.businessId == null ||
      profile == null ||
      deviceIdentity == null) {
    return LogActivityUseCase.stub();
  }

  return LogActivityUseCase(
    repository: ref.watch(activityLogRepositoryProvider),
    businessId: session.businessId!,
    branchId: session.branchId,
    performedBy: session.userUid!,
    performedByName: profile.displayName,
    performedByRole: session.role?.name ?? 'unknown',
    appVersion: deviceIdentity.appVersion,
    platform: deviceIdentity.platform,
  );
});

class ActivityLogState {
  final List<ActivityLogEntry> entries;
  final DocumentSnapshot? lastDoc;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final ActivityCategory? activeCategory;

  ActivityLogState({
    required this.entries,
    this.lastDoc,
    required this.isLoading,
    required this.hasMore,
    this.error,
    this.activeCategory,
  });

  ActivityLogState copyWith({
    List<ActivityLogEntry>? entries,
    DocumentSnapshot? lastDoc,
    bool? isLoading,
    bool? hasMore,
    String? error,
    ActivityCategory? activeCategory,
  }) {
    return ActivityLogState(
      entries: entries ?? this.entries,
      lastDoc: lastDoc ?? this.lastDoc,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      activeCategory: activeCategory ?? this.activeCategory,
    );
  }
}

class ActivityLogNotifier extends AutoDisposeAsyncNotifier<ActivityLogState> {
  @override
  Future<ActivityLogState> build() async {
    final businessId = ref.watch(userBusinessIdProvider);
    if (businessId == null) {
      return ActivityLogState(entries: [], isLoading: false, hasMore: false);
    }

    final useCase = ref.watch(getActivityLogUseCaseProvider);
    final result = await useCase(businessId: businessId);

    return ActivityLogState(
      entries: result.entries,
      lastDoc: result.lastDoc,
      isLoading: false,
      hasMore: result.entries.length >= 50,
    );
  }

  Future<void> loadMore() async {
    final currentState = state.value;
    if (currentState == null || currentState.isLoading || !currentState.hasMore) {
      return;
    }

    state = AsyncData(currentState.copyWith(isLoading: true));

    final businessId = ref.read(userBusinessIdProvider);
    if (businessId == null) return;

    final useCase = ref.read(getActivityLogUseCaseProvider);
    final result = await useCase(
      businessId: businessId,
      lastDocument: currentState.lastDoc,
      filterCategory: currentState.activeCategory,
    );

    state = AsyncData(currentState.copyWith(
      entries: [...currentState.entries, ...result.entries],
      lastDoc: result.lastDoc,
      isLoading: false,
      hasMore: result.entries.length >= 50,
    ));
  }

  Future<void> filterByCategory(ActivityCategory? category) async {
    state = const AsyncLoading();
    final businessId = ref.read(userBusinessIdProvider);
    if (businessId == null) return;

    final useCase = ref.read(getActivityLogUseCaseProvider);
    final result =
        await useCase(businessId: businessId, filterCategory: category);

    state = AsyncData(ActivityLogState(
      entries: result.entries,
      lastDoc: result.lastDoc,
      isLoading: false,
      hasMore: result.entries.length >= 50,
      activeCategory: category,
    ));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final activityLogNotifierProvider =
    AsyncNotifierProvider.autoDispose<ActivityLogNotifier, ActivityLogState>(
        () {
  return ActivityLogNotifier();
});
