import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BusinessSession {
  BusinessSession({
    required this.isOpen,
    this.openedAt,
    this.closedAt,
    required this.businessDate,
  });

  final bool isOpen;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String businessDate;

  DateTime get parsedBusinessDate {
    try {
      return DateFormat('d MMMM yyyy').parse(businessDate);
    } catch (_) {
      return DateTime.now();
    }
  }

  factory BusinessSession.fromMap(Map<String, dynamic> map) {
    return BusinessSession(
      isOpen: map['isOpen'] ?? false,
      openedAt: (map['openedAt'] as Timestamp?)?.toDate(),
      closedAt: (map['closedAt'] as Timestamp?)?.toDate(),
      businessDate: map['businessDate'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'isOpen': isOpen,
        'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
        'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
        'businessDate': businessDate,
      };
}
