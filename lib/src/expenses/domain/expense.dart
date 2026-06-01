import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/domain/order_models.dart';
import '../../core/sync/sync_models.dart';

class Expense {
  Expense({
    required this.id,
    required this.amountPaise,
    required this.category,
    required this.paymentMethod,
    required this.notes,
    required this.createdBy,
    required this.timestamp,
    required this.timestampMs,
    this.businessId,
    this.payableTo,
    this.expenseStatus = 'unsettled',
    this.settledAt,
    this.settledBy,
    this.syncMetadata,
  });

  final String id;
  final int amountPaise;
  final String category;
  final PaymentMethod paymentMethod;
  final String notes;
  final String createdBy;
  final DateTime timestamp;
  final int timestampMs;
  final String? businessId;
  final String? payableTo;
  final String expenseStatus; // 'unsettled' | 'settled'
  final DateTime? settledAt;
  final String? settledBy;
  final SyncMetadata? syncMetadata;

  bool get isSynced => syncMetadata?.synced ?? true;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'amountPaise': amountPaise,
      'category': category,
      'paymentMethod': paymentMethod.name,
      'notes': notes,
      'createdBy': createdBy,
      'timestamp': Timestamp.fromDate(timestamp),
      'timestampMs': timestampMs,
      'expenseStatus': expenseStatus,
    };
    if (businessId != null) map['businessId'] = businessId;
    if (payableTo != null) map['payableTo'] = payableTo;
    if (settledAt != null) map['settledAt'] = Timestamp.fromDate(settledAt!);
    if (settledBy != null) map['settledBy'] = settledBy;
    return map;
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return null;
    }

    return Expense(
      id: id,
      amountPaise: map['amountPaise'] ?? 0,
      category: map['category'] ?? 'Miscellaneous',
      paymentMethod: PaymentMethod.fromString(map['paymentMethod']),
      notes: map['notes'] ?? '',
      createdBy: map['createdBy'] ?? '',
      timestamp: parseDate(map['timestamp']) ?? DateTime.now(),
      timestampMs: map['timestampMs'] ?? 0,
      businessId: map['businessId']?.toString(),
      payableTo: map['payableTo']?.toString(),
      expenseStatus: map['expenseStatus'] ?? 'settled',
      settledAt: parseDate(map['settledAt']),
      settledBy: map['settledBy']?.toString(),
      syncMetadata: map['syncMetadata'] != null 
          ? SyncMetadata.fromMap(Map<String, dynamic>.from(map['syncMetadata'])) 
          : null,
    );
  }

  Expense copyWith({
    String? id,
    int? amountPaise,
    String? category,
    PaymentMethod? paymentMethod,
    String? notes,
    String? createdBy,
    DateTime? timestamp,
    int? timestampMs,
    String? payableTo,
    String? expenseStatus,
    DateTime? settledAt,
    String? settledBy,
    SyncMetadata? syncMetadata,
  }) {
    return Expense(
      id: id ?? this.id,
      amountPaise: amountPaise ?? this.amountPaise,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      timestamp: timestamp ?? this.timestamp,
      timestampMs: timestampMs ?? this.timestampMs,
      payableTo: payableTo ?? this.payableTo,
      expenseStatus: expenseStatus ?? this.expenseStatus,
      settledAt: settledAt ?? this.settledAt,
      settledBy: settledBy ?? this.settledBy,
      syncMetadata: syncMetadata ?? this.syncMetadata,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return toMap();
  }

  Map<String, dynamic> toLocalMap() {
    final map = toFirestoreMap();
    map['timestamp'] = timestamp.toIso8601String();
    if (settledAt != null) map['settledAt'] = settledAt!.toIso8601String();
    final s = syncMetadata;
    if (s != null) {
      map['syncMetadata'] = s.toMap();
    }
    return map;
  }
}
