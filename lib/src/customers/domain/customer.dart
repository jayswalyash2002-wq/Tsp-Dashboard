import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id; // normalized phone number or auto-id
  final String? name;
  final String phone;
  final int totalOrders;
  final int totalSpentPaise;
  final DateTime? lastVisit;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    this.name,
    required this.phone,
    this.totalOrders = 0,
    this.totalSpentPaise = 0,
    this.lastVisit,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'totalOrders': totalOrders,
      'totalSpentPaise': totalSpentPaise,
      'lastVisit': lastVisit != null ? Timestamp.fromDate(lastVisit!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    return Customer(
      id: id,
      name: map['name'] as String?,
      phone: map['phone'] as String,
      totalOrders: map['totalOrders'] as int? ?? 0,
      totalSpentPaise: map['totalSpentPaise'] as int? ?? 0,
      lastVisit: (map['lastVisit'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Customer copyWith({
    String? name,
    String? phone,
    int? totalOrders,
    int? totalSpentPaise,
    DateTime? lastVisit,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpentPaise: totalSpentPaise ?? this.totalSpentPaise,
      lastVisit: lastVisit ?? this.lastVisit,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
