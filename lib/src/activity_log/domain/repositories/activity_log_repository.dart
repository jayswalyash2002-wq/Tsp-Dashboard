import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../entities/activity_log_entry.dart';
import '../entities/activity_log_enums.dart';

abstract class ActivityLogRepository {
  // Write a single activity log entry
  Future<void> logActivity(ActivityLogEntry entry);

  // Expose batch data builder for atomic operations
  ({DocumentReference ref, Map<String, dynamic> data}) 
    buildActivityLogBatchData(ActivityLogEntry entry);

  // Read paginated activity log for a business
  Future<({List<ActivityLogEntry> entries, DocumentSnapshot? lastDoc})> getActivityLog({
    required String businessId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
    ActivityCategory? filterCategory,
    String? filterPerformedBy,
    DateTimeRange? filterDateRange,
  });

  // Stream for real-time activity feed
  Stream<List<ActivityLogEntry>> watchActivityLog({
    required String businessId,
    int limit = 20,
  });
}
