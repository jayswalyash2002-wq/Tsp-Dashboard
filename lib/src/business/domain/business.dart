import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String uin;
  final String businessName;
  final String ownerName;
  final String officialEmail;
  final String phoneNumber;
  final String? secondaryPhoneNumber;
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
  
  // Auto Business Hours
  final bool autoOpenEnabled;
  final bool autoCloseEnabled;
  final String openingTime;
  final String closingTime;
  final String businessStatus; // 'open' or 'closed'
  final bool manualOverride;
  final DateTime? lastStatusUpdate;
  final int businessDayStartHour;
  final String timezone;

  Business({
    required this.id,
    required this.uin,
    required this.businessName,
    required this.ownerName,
    required this.officialEmail,
    required this.phoneNumber,
    this.secondaryPhoneNumber,
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
    this.autoOpenEnabled = false,
    this.autoCloseEnabled = false,
    this.openingTime = '09:00',
    this.closingTime = '22:00',
    this.businessStatus = 'open',
    this.manualOverride = false,
    this.lastStatusUpdate,
    this.businessDayStartHour = 0,
    this.timezone = 'UTC',
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
      secondaryPhoneNumber: map['secondaryPhoneNumber'],
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
      autoOpenEnabled: map['autoOpenEnabled'] ?? false,
      autoCloseEnabled: map['autoCloseEnabled'] ?? false,
      openingTime: map['openingTime'] ?? '09:00',
      closingTime: map['closingTime'] ?? '22:00',
      businessStatus: map['businessStatus'] ?? 'open',
      manualOverride: map['manualOverride'] ?? false,
      lastStatusUpdate: (map['lastStatusUpdate'] as Timestamp?)?.toDate(),
      businessDayStartHour: map['businessDayStartHour'] ?? 0,
      timezone: map['timezone'] ?? 'UTC',
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
      'secondaryPhoneNumber': secondaryPhoneNumber,
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
      'autoOpenEnabled': autoOpenEnabled,
      'autoCloseEnabled': autoCloseEnabled,
      'openingTime': openingTime,
      'closingTime': closingTime,
      'businessStatus': businessStatus,
      'manualOverride': manualOverride,
      'lastStatusUpdate': lastStatusUpdate != null ? Timestamp.fromDate(lastStatusUpdate!) : null,
      'businessDayStartHour': businessDayStartHour,
      'timezone': timezone,
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
    String? secondaryPhoneNumber,
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
    bool? autoOpenEnabled,
    bool? autoCloseEnabled,
    String? openingTime,
    String? closingTime,
    String? businessStatus,
    bool? manualOverride,
    DateTime? lastStatusUpdate,
    int? businessDayStartHour,
    String? timezone,
  }) {
    return Business(
      id: id ?? this.id,
      uin: uin ?? this.uin,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      officialEmail: officialEmail ?? this.officialEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      secondaryPhoneNumber: secondaryPhoneNumber ?? this.secondaryPhoneNumber,
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
      autoOpenEnabled: autoOpenEnabled ?? this.autoOpenEnabled,
      autoCloseEnabled: autoCloseEnabled ?? this.autoCloseEnabled,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      businessStatus: businessStatus ?? this.businessStatus,
      manualOverride: manualOverride ?? this.manualOverride,
      lastStatusUpdate: lastStatusUpdate ?? this.lastStatusUpdate,
      businessDayStartHour: businessDayStartHour ?? this.businessDayStartHour,
      timezone: timezone ?? this.timezone,
    );
  }
}
