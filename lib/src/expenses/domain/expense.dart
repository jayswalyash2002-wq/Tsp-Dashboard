import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/domain/order_models.dart';

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
  });

  final String id;
  final int amountPaise;
  final String category;
  final PaymentMethod paymentMethod;
  final String notes;
  final String createdBy;
  final DateTime timestamp;
  final int timestampMs;

  Map<String, dynamic> toMap() {
    return {
      'amountPaise': amountPaise,
      'category': category,
      'paymentMethod': paymentMethod.name,
      'notes': notes,
      'createdBy': createdBy,
      'timestamp': Timestamp.fromDate(timestamp),
      'timestampMs': timestampMs,
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      amountPaise: map['amountPaise'] ?? 0,
      category: map['category'] ?? 'Miscellaneous',
      paymentMethod: PaymentMethod.fromString(map['paymentMethod']),
      notes: map['notes'] ?? '',
      createdBy: map['createdBy'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      timestampMs: map['timestampMs'] ?? 0,
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
    );
  }
}
