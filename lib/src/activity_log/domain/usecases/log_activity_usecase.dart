import '../entities/activity_log_entry.dart';
import '../entities/activity_log_enums.dart';
import '../repositories/activity_log_repository.dart';

class LogActivityUseCase {
  final ActivityLogRepository? _repository;
  final String businessId;
  final String? branchId;
  final String performedBy;
  final String performedByName;
  final String performedByRole;
  final String appVersion;
  final String platform;

  LogActivityUseCase({
    required ActivityLogRepository repository,
    required this.businessId,
    this.branchId,
    required this.performedBy,
    required this.performedByName,
    required this.performedByRole,
    required this.appVersion,
    required this.platform,
  }) : _repository = repository;

  /// Creates a no-op version of the use case.
  LogActivityUseCase.stub()
      : _repository = null,
        businessId = '',
        branchId = null,
        performedBy = '',
        performedByName = '',
        performedByRole = '',
        appVersion = '',
        platform = '';

  Future<void> execute({
    required ActivityAction action,
    required ActivityCategory category,
    String? targetType,
    String? targetId,
    String? targetName,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_repository == null) return;

    final entry = ActivityLogEntry(
      activityLogId: '',
      businessId: businessId,
      branchId: branchId,
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      action: action,
      category: category,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      metadata: metadata,
      appVersion: appVersion,
      platform: platform,
    );

    await _repository.logActivity(entry);
  }
}
