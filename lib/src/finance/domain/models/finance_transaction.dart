import 'package:cloud_firestore/cloud_firestore.dart';
import 'finance_enums.dart';

class FinanceTransaction {
  final String id;
  final String businessId;
  final FinanceTransactionType type;
  final int amount; // In Paise
  final FinanceAccount? account; // For fund and expense
  final FinanceAccount? fromAccount; // For transfer
  final FinanceAccount? toAccount; // For transfer
  
  // Historical context (Optional, for tracking previous state in some systems)
  final int? originalAmount;
  final FinanceAccount? originalAccount;

  final String notes;
  final DateTime date;
  final int month;
  final int year;

  final String createdBy;
  final DateTime createdAt;
  final String? updatedBy;
  final DateTime? updatedAt;

  final bool isDeleted;
  final String? deletedBy;
  final DateTime? deletedAt;

  FinanceTransaction({
    required this.id,
    required this.businessId,
    required this.type,
    required this.amount,
    this.account,
    this.fromAccount,
    this.toAccount,
    this.originalAmount,
    this.originalAccount,
    required this.notes,
    required this.date,
    required this.month,
    required this.year,
    required this.createdBy,
    required this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedBy,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'type': type.name,
      'amount': amount,
      'account': account?.name,
      'from_account': fromAccount?.name,
      'to_account': toAccount?.name,
      'original_amount': originalAmount,
      'original_account': originalAccount?.name,
      'notes': notes,
      'date': Timestamp.fromDate(date),
      'month': month,
      'year': year,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_by': updatedBy,
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'is_deleted': isDeleted,
      'deleted_by': deletedBy,
      'deleted_at': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  factory FinanceTransaction.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return FinanceTransaction(
      id: docId,
      businessId: map['businessId'] ?? '',
      type: FinanceTransactionType.fromString(map['type']),
      amount: map['amount'] ?? 0,
      account: map['account'] != null ? FinanceAccount.fromString(map['account']) : null,
      fromAccount: map['from_account'] != null ? FinanceAccount.fromString(map['from_account']) : null,
      toAccount: map['to_account'] != null ? FinanceAccount.fromString(map['to_account']) : null,
      originalAmount: map['original_amount'],
      originalAccount: map['original_account'] != null ? FinanceAccount.fromString(map['original_account']) : null,
      notes: map['notes'] ?? '',
      date: parseDate(map['date']),
      month: map['month'] ?? 0,
      year: map['year'] ?? 0,
      createdBy: map['created_by'] ?? '',
      createdAt: parseDate(map['created_at']),
      updatedBy: map['updated_by'],
      updatedAt: parseDateNullable(map['updated_at']),
      isDeleted: map['is_deleted'] ?? false,
      deletedBy: map['deleted_by'],
      deletedAt: parseDateNullable(map['deleted_at']),
    );
  }

  FinanceTransaction copyWith({
    String? id,
    String? businessId,
    FinanceTransactionType? type,
    int? amount,
    FinanceAccount? account,
    FinanceAccount? fromAccount,
    FinanceAccount? toAccount,
    int? originalAmount,
    FinanceAccount? originalAccount,
    String? notes,
    DateTime? date,
    int? month,
    int? year,
    String? createdBy,
    DateTime? createdAt,
    String? updatedBy,
    DateTime? updatedAt,
    bool? isDeleted,
    String? deletedBy,
    DateTime? deletedAt,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      fromAccount: fromAccount ?? this.fromAccount,
      toAccount: toAccount ?? this.toAccount,
      originalAmount: originalAmount ?? this.originalAmount,
      originalAccount: originalAccount ?? this.originalAccount,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      month: month ?? this.month,
      year: year ?? this.year,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: deletedBy ?? this.deletedBy,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

}
