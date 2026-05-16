import 'package:cloud_firestore/cloud_firestore.dart';

class FundMovement {
  FundMovement({
    required this.id,
    required this.type,
    required this.amountPaise,
    required this.reason,
    required this.notes,
    required this.createdBy,
    required this.createdByUid,
    required this.timestamp,
    required this.timestampMs,
    required this.deviceName,
  });

  final String id;
  final String type; // 'cash' | 'bank'
  final int amountPaise;
  final String reason;
  final String? notes;
  final String createdBy;
  final String createdByUid;
  final DateTime timestamp;
  final int timestampMs;
  final String deviceName;

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amountPaise': amountPaise,
      'reason': reason,
      'notes': notes,
      'createdBy': createdBy,
      'createdByUid': createdByUid,
      'timestamp': Timestamp.fromDate(timestamp),
      'timestampMs': timestampMs,
      'deviceName': deviceName,
    };
  }

  factory FundMovement.fromMap(String id, Map<String, dynamic> map) {
    return FundMovement(
      id: id,
      type: map['type'] ?? 'cash',
      amountPaise: map['amountPaise'] ?? 0,
      reason: map['reason'] ?? 'Miscellaneous',
      notes: map['notes'],
      createdBy: map['createdBy'] ?? '',
      createdByUid: map['createdByUid'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      timestampMs: map['timestampMs'] ?? 0,
      deviceName: map['deviceName'] ?? '',
    );
  }
}
