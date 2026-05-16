import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String businessName;
  final String ownerName;
  final String officialEmail;
  final String phoneNumber;
  final String businessType;
  final String? gstNumber;
  final bool isFssaiRegistered;
  final String? fssaiNumber;
  final String? address;
  final String? logoUrl;
  final DateTime createdAt;

  Business({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.officialEmail,
    required this.phoneNumber,
    required this.businessType,
    this.gstNumber,
    this.isFssaiRegistered = false,
    this.fssaiNumber,
    this.address,
    this.logoUrl,
    required this.createdAt,
  });

  bool get isGstRegistered => gstNumber != null && gstNumber!.trim().isNotEmpty;

  factory Business.fromMap(Map<String, dynamic> map, String id) {
    return Business(
      id: id,
      businessName: map['businessName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      officialEmail: map['officialEmail'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      businessType: map['businessType'] ?? '',
      gstNumber: map['gstNumber'],
      isFssaiRegistered: map['isFssaiRegistered'] ?? false,
      fssaiNumber: map['fssaiNumber'],
      address: map['address'],
      logoUrl: map['logoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': id,
      'businessName': businessName,
      'ownerName': ownerName,
      'officialEmail': officialEmail,
      'phoneNumber': phoneNumber,
      'businessType': businessType,
      'gstNumber': gstNumber,
      'isFssaiRegistered': isFssaiRegistered,
      'fssaiNumber': fssaiNumber,
      'address': address,
      'logoUrl': logoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
