import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../entities/activity_log_entry.dart';
import '../entities/activity_log_enums.dart';
import '../repositories/activity_log_repository.dart';

class GetActivityLogUseCase {
  final ActivityLogRepository _repository;

  GetActivityLogUseCase(this._repository);

  Future<({List<ActivityLogEntry> entries, DocumentSnapshot? lastDoc})> call({
    required String businessId,
    int limit = 50,
    DocumentSnapshot? lastDocument,
    ActivityCategory? filterCategory,
    String? filterPerformedBy,
    DateTimeRange? filterDateRange,
  }) {
    return _repository.getActivityLog(
      businessId: businessId,
      limit: limit,
      lastDocument: lastDocument,
      filterCategory: filterCategory,
      filterPerformedBy: filterPerformedBy,
      filterDateRange: filterDateRange,
    );
  }
}
