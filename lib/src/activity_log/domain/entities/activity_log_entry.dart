import 'activity_log_enums.dart';

class ActivityLogEntry {
  final String activityLogId;
  final String businessId;
  final String? branchId;
  final String performedBy;
  final String performedByName;
  final String performedByRole;
  final ActivityAction action;
  final ActivityCategory category;
  final String? targetType;
  final String? targetId;
  final String? targetName;
  final Map<String, dynamic> metadata;
  final DateTime? timestamp;
  final String appVersion;
  final String platform;

  const ActivityLogEntry({
    required this.activityLogId,
    required this.businessId,
    this.branchId,
    required this.performedBy,
    required this.performedByName,
    required this.performedByRole,
    required this.action,
    required this.category,
    this.targetType,
    this.targetId,
    this.targetName,
    required this.metadata,
    this.timestamp,
    required this.appVersion,
    required this.platform,
  });
}
