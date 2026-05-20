import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../../domain/entities/activity_log_enums.dart';
import '../../domain/repositories/activity_log_repository.dart';
import '../models/activity_log_model.dart';

class ActivityLogRepositoryImpl implements ActivityLogRepository {
  final FirebaseFirestore _db;

  ActivityLogRepositoryImpl(this._db);

  @override
  Future<void> logActivity(ActivityLogEntry entry) async {
    try {
      final docRef = _db.collection('activityLogs').doc();
      final model = _toModel(entry, docRef.id);
      
      await docRef.set(model.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Activity log write failed: $e');
      }
    }
  }

  @override
  ({DocumentReference ref, Map<String, dynamic> data}) 
    buildActivityLogBatchData(ActivityLogEntry entry) {
    
    final docRef = _db.collection('activityLogs').doc();
    final model = _toModel(entry, docRef.id);
    
    return (ref: docRef, data: model.toFirestore());
  }

  @override
  Future<({List<ActivityLogEntry> entries, DocumentSnapshot? lastDoc})> getActivityLog({
    required String businessId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
    ActivityCategory? filterCategory,
    String? filterPerformedBy,
    DateTimeRange? filterDateRange,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 100);
      Query query = _db.collection('activityLogs')
          .where('businessId', isEqualTo: businessId)
          .orderBy('timestamp', descending: true);

      if (filterCategory != null) {
        query = query.where('category', isEqualTo: filterCategory.name);
      }

      if (filterPerformedBy != null) {
        query = query.where('performedBy', isEqualTo: filterPerformedBy);
      }

      if (filterDateRange != null) {
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(filterDateRange.start))
            .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(filterDateRange.end));
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(safeLimit);

      final snapshot = await query.get();
      final entries = snapshot.docs.map((doc) => ActivityLogModel.fromFirestore(doc)).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      
      return (entries: entries, lastDoc: lastDoc);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ACTIVITY_LOG_REPO: Error getting activity log: $e');
      }
      return (entries: <ActivityLogEntry>[], lastDoc: null);
    }
  }

  @override
  Stream<List<ActivityLogEntry>> watchActivityLog({
    required String businessId,
    int limit = 20,
  }) {
    final safeLimit = limit.clamp(1, 50);
    return _db.collection('activityLogs')
        .where('businessId', isEqualTo: businessId)
        .orderBy('timestamp', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityLogModel.fromFirestore(doc))
            .toList())
        .handleError((e) {
          if (kDebugMode) {
            debugPrint('ACTIVITY_LOG_REPO: Error watching activity log: $e');
          }
          return <ActivityLogEntry>[];
        });
  }

  ActivityLogModel _toModel(ActivityLogEntry entry, String id) {
    return ActivityLogModel(
      activityLogId: id,
      businessId: entry.businessId,
      branchId: entry.branchId,
      performedBy: entry.performedBy,
      performedByName: entry.performedByName,
      performedByRole: entry.performedByRole,
      action: entry.action,
      category: entry.category,
      targetType: entry.targetType,
      targetId: entry.targetId,
      targetName: entry.targetName,
      metadata: entry.metadata,
      timestamp: null, // Forces server timestamp in toFirestore
      appVersion: entry.appVersion,
      platform: entry.platform,
    );
  }
}
