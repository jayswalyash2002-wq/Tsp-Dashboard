class MenuItem {
  MenuItem({
    required this.id,
    required this.name,
    required this.pricePaise,
    required this.category,
    required this.available,
    this.sortOrder = 0,
    this.categorySortOrder = 0,
    this.businessId,
    this.isDeleted = false,
  });

  final String id;
  final String name;
  final int pricePaise;
  final String category;
  final bool available;
  final int sortOrder;
  final int categorySortOrder;
  final String? businessId;
  final bool isDeleted;

  double get price => pricePaise / 100.0;

  static MenuItem fromDoc(String id, Map<String, dynamic> data) {
    return MenuItem(
      id: id,
      name: (data['name'] ?? '').toString(),
      pricePaise: (data['pricePaise'] ?? 0) is int
          ? (data['pricePaise'] as int)
          : int.tryParse('${data['pricePaise']}') ?? 0,
      category: (data['category'] ?? '').toString(),
      available: (data['available'] ?? true) == true,
      sortOrder: data['sortOrder'] ?? 0,
      categorySortOrder: data['categorySortOrder'] ?? 0,
      businessId: data['businessId']?.toString(),
      isDeleted: data['isDeleted'] == true,
    );
  }

  MenuItem copyWith({
    String? name,
    int? pricePaise,
    String? category,
    bool? available,
    int? sortOrder,
    int? categorySortOrder,
    bool? isDeleted,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      pricePaise: pricePaise ?? this.pricePaise,
      category: category ?? this.category,
      available: available ?? this.available,
      sortOrder: sortOrder ?? this.sortOrder,
      categorySortOrder: categorySortOrder ?? this.categorySortOrder,
      businessId: businessId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

