import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceBalance {
  final int cash;
  final int bank;
  final DateTime lastUpdatedAt;

  FinanceBalance({
    required this.cash,
    required this.bank,
    required this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'cash': cash,
      'bank': bank,
      'last_updated_at': Timestamp.fromDate(lastUpdatedAt),
    };
  }

  factory FinanceBalance.fromMap(Map<String, dynamic> map) {
    return FinanceBalance(
      cash: map['cash'] ?? 0,
      bank: map['bank'] ?? 0,
      lastUpdatedAt: (map['last_updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  FinanceBalance copyWith({
    int? cash,
    int? bank,
    DateTime? lastUpdatedAt,
  }) {
    return FinanceBalance(
      cash: cash ?? this.cash,
      bank: bank ?? this.bank,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
