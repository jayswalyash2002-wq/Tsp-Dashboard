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
  });

  final String id;
  final String name;
  final int pricePaise;
  final String category;
  final bool available;
  final int sortOrder;
  final int categorySortOrder;
  final String? businessId;

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
    );
  }
}

