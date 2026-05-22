import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItem {
  final String id;
  final String name;
  final int stock;
  final String unit;
  final int lowStockThreshold;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.stock,
    required this.unit,
    required this.lowStockThreshold,
    this.createdAt,
    this.updatedAt,
  });

  bool get isLowStock => stock <= lowStockThreshold;

  factory InventoryItem.fromMap(String id, Map<String, dynamic> map) {
    return InventoryItem(
      id: id,
      name: map['name'] ?? '',
      stock: map['stock'] ?? 0,
      unit: map['unit'] ?? 'pcs',
      lowStockThreshold: map['lowStockThreshold'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'stock': stock,
      'unit': unit,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  InventoryItem copyWith({
    String? name,
    int? stock,
    String? unit,
    int? lowStockThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
