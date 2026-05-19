import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String uin;
  final String businessName;
  final String ownerName;
  final String officialEmail;
  final String phoneNumber;
  final String businessType;
  final String? city;
  final String? area;
  final String? gstNumber;
  final bool isFssaiRegistered;
  final String? fssaiNumber;
  final String? address;
  final String? logoUrl;
  final DateTime createdAt;
  final String? status;

  Business({
    required this.id,
    required this.uin,
    required this.businessName,
    required this.ownerName,
    required this.officialEmail,
    required this.phoneNumber,
    required this.businessType,
    this.city,
    this.area,
    this.gstNumber,
    this.isFssaiRegistered = false,
    this.fssaiNumber,
    this.address,
    this.logoUrl,
    required this.createdAt,
    this.status = 'active',
  });

  bool get isGstRegistered => gstNumber != null && gstNumber!.trim().isNotEmpty;

  factory Business.fromMap(Map<String, dynamic> map, String id) {
    return Business(
      id: id,
      uin: map['uin'] ?? '',
      businessName: map['businessName'] ?? '',
      ownerName: map['ownerName'] ?? '',
      officialEmail: map['officialEmail'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      businessType: map['businessType'] ?? '',
      city: map['city'],
      area: map['area'],
      gstNumber: map['gstNumber'],
      isFssaiRegistered: map['isFssaiRegistered'] ?? false,
      fssaiNumber: map['fssaiNumber'],
      address: map['address'],
      logoUrl: map['logoUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': id,
      'uin': uin,
      'businessName': businessName,
      'ownerName': ownerName,
      'officialEmail': officialEmail,
      'phoneNumber': phoneNumber,
      'businessType': businessType,
      'city': city,
      'area': area,
      'gstNumber': gstNumber,
      'isFssaiRegistered': isFssaiRegistered,
      'fssaiNumber': fssaiNumber,
      'address': address,
      'logoUrl': logoUrl,
      'createdAt': createdAt, 
      'status': status,
    };
  }

  Map<String, dynamic> toCreateMap() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }

  Business copyWith({
    String? id,
    String? uin,
    String? businessName,
    String? ownerName,
    String? officialEmail,
    String? phoneNumber,
    String? businessType,
    String? city,
    String? area,
    String? gstNumber,
    bool? isFssaiRegistered,
    String? fssaiNumber,
    String? address,
    String? logoUrl,
    DateTime? createdAt,
    String? status,
  }) {
    return Business(
      id: id ?? this.id,
      uin: uin ?? this.uin,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      officialEmail: officialEmail ?? this.officialEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      businessType: businessType ?? this.businessType,
      city: city ?? this.city,
      area: area ?? this.area,
      gstNumber: gstNumber ?? this.gstNumber,
      isFssaiRegistered: isFssaiRegistered ?? this.isFssaiRegistered,
      fssaiNumber: fssaiNumber ?? this.fssaiNumber,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
