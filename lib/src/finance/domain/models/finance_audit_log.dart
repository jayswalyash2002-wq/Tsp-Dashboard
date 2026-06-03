import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_enums.dart';

class FinanceAuditLog {
  final String id;
  final String transactionId;
  final FinanceAuditAction action;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final String changedBy;
  final DateTime changedAt;

  FinanceAuditLog({
    required this.id,
    required this.transactionId,
    required this.action,
    this.oldValues,
    this.newValues,
    required this.changedBy,
    required this.changedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'action': action.name,
      'old_values': oldValues,
      'new_values': newValues,
      'changed_by': changedBy,
      'changed_at': Timestamp.fromDate(changedAt),
    };
  }

  factory FinanceAuditLog.fromMap(Map<String, dynamic> map, String id) {
    return FinanceAuditLog(
      id: id,
      transactionId: map['transaction_id'] ?? '',
      action: FinanceAuditAction.fromString(map['action']),
      oldValues: map['old_values'],
      newValues: map['new_values'],
      changedBy: map['changed_by'] ?? '',
      changedAt: (map['changed_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
