import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyClosing {
  final String id;
  final String businessId;
  final int month;
  final int year;

  final int openingCash;
  final int openingBank;

  final int closingCash;
  final int closingBank;

  final int carryForwardCash;
  final int carryForwardBank;

  final int adjustmentCash;
  final int adjustmentBank;

  final String reason;
  final String notes;

  final String closedBy;
  final DateTime closedAt;

  final bool isLocked;
  final String? unlockedBy;
  final DateTime? unlockedAt;
  final String? unlockReason;

  MonthlyClosing({
    required this.id,
    required this.businessId,
    required this.month,
    required this.year,
    required this.openingCash,
    required this.openingBank,
    required this.closingCash,
    required this.closingBank,
    required this.carryForwardCash,
    required this.carryForwardBank,
    required this.adjustmentCash,
    required this.adjustmentBank,
    required this.reason,
    required this.notes,
    required this.closedBy,
    required this.closedAt,
    this.isLocked = true,
    this.unlockedBy,
    this.unlockedAt,
    this.unlockReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'businessId': businessId,
      'month': month,
      'year': year,
      'openingCash': openingCash,
      'openingBank': openingBank,
      'closingCash': closingCash,
      'closingBank': closingBank,
      'carryForwardCash': carryForwardCash,
      'carryForwardBank': carryForwardBank,
      'adjustmentCash': adjustmentCash,
      'adjustmentBank': adjustmentBank,
      'reason': reason,
      'notes': notes,
      'closedBy': closedBy,
      'closedAt': Timestamp.fromDate(closedAt),
      'isLocked': isLocked,
      'unlockedBy': unlockedBy,
      'unlockedAt': unlockedAt != null ? Timestamp.fromDate(unlockedAt!) : null,
      'unlockReason': unlockReason,
    };
  }

  factory MonthlyClosing.fromMap(Map<String, dynamic> map, String docId) {
    return MonthlyClosing(
      id: docId,
      businessId: map['businessId'] ?? '',
      month: map['month'] ?? 0,
      year: map['year'] ?? 0,
      openingCash: map['openingCash'] ?? 0,
      openingBank: map['openingBank'] ?? 0,
      closingCash: map['closingCash'] ?? 0,
      closingBank: map['closingBank'] ?? 0,
      carryForwardCash: map['carryForwardCash'] ?? 0,
      carryForwardBank: map['carryForwardBank'] ?? 0,
      adjustmentCash: map['adjustmentCash'] ?? 0,
      adjustmentBank: map['adjustmentBank'] ?? 0,
      reason: map['reason'] ?? '',
      notes: map['notes'] ?? '',
      closedBy: map['closedBy'] ?? '',
      closedAt: (map['closedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isLocked: map['isLocked'] ?? true,
      unlockedBy: map['unlockedBy'],
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate(),
      unlockReason: map['unlockReason'],
    );
  }
}
