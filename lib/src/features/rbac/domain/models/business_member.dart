import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tsp_dashboard/src/constants/roles.dart';

class MemberModel {
  final String uid;
  final String businessId;
  final String displayName;
  final Role role;
  final DateTime joinedAt;

  MemberModel({
    required this.uid,
    required this.businessId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel(
      uid: map['uid'] ?? '',
      businessId: map['businessId'] ?? '',
      displayName: map['displayName'] ?? '',
      role: roleFromString(map['role'] ?? ''),
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'businessId': businessId,
      'displayName': displayName,
      'role': role.name,
      'joinedAt': FieldValue.serverTimestamp(),
    };
  }
}
