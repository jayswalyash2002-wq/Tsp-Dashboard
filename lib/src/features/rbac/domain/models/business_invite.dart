import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tsp_dashboard/src/constants/roles.dart';

class InviteModel {
  final String? id;
  final String code;
  final String businessId;
  final String staffName;
  final String? notes;
  final Role role;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isUsed;

  InviteModel({
    this.id,
    required this.code,
    required this.businessId,
    required this.staffName,
    this.notes,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    this.isUsed = false,
  });

  factory InviteModel.fromMap(Map<String, dynamic> map, String id) {
    return InviteModel(
      id: id,
      code: map['code'] ?? '',
      businessId: map['businessId'] ?? '',
      staffName: map['staffName'] ?? '',
      notes: map['notes'],
      role: roleFromString(map['role'] ?? ''),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isUsed: map['isUsed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'businessId': businessId,
      'staffName': staffName,
      'notes': notes,
      'role': role.name,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isUsed': isUsed,
    };
  }
}
