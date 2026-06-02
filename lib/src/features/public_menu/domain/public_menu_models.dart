class PublicCategory {
  final String id;
  final String name;
  final int orderIndex;

  PublicCategory({
    required this.id,
    required this.name,
    required this.orderIndex,
  });

  factory PublicCategory.fromFirestore(String id, Map<String, dynamic> data) {
    return PublicCategory(
      id: id,
      name: data['name'] ?? '',
      orderIndex: data['orderIndex'] ?? 0,
    );
  }
}

class PublicProduct {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;

  PublicProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
  });

  factory PublicProduct.fromFirestore(String id, Map<String, dynamic> data) {
    return PublicProduct(
      id: id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      isAvailable: data['isAvailable'] ?? true,
    );
  }
}
