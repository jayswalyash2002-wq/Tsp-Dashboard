import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../../domain/entities/activity_log_enums.dart';

class ActivityLogModel extends ActivityLogEntry {
  const ActivityLogModel({
    required super.activityLogId,
    required super.businessId,
    super.branchId,
    required super.performedBy,
    required super.performedByName,
    required super.performedByRole,
    required super.action,
    required super.category,
    super.targetType,
    super.targetId,
    super.targetName,
    required super.metadata,
    super.timestamp,
    required super.appVersion,
    required super.platform,
  });

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLogModel(
      activityLogId: doc.id,
      businessId: data['businessId'] ?? '',
      branchId: data['branchId'],
      performedBy: data['performedBy'] ?? '',
      performedByName: data['performedByName'] ?? '',
      performedByRole: data['performedByRole'] ?? '',
      action: ActivityAction.values.firstWhere(
        (e) => e.name == data['action'],
        orElse: () => ActivityAction.orderCreated, // Fallback
      ),
      category: ActivityCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ActivityCategory.operational, // Fallback
      ),
      targetType: data['targetType'],
      targetId: data['targetId'],
      targetName: data['targetName'],
      metadata: data['metadata'] ?? {},
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      appVersion: data['appVersion'] ?? 'unknown',
      platform: data['platform'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'activityLogId': activityLogId,
      'businessId': businessId,
      'branchId': branchId,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'performedByRole': performedByRole,
      'action': action.name,
      'category': category.name,
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'metadata': metadata,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
      'appVersion': appVersion,
      'platform': platform,
    };
  }
}
