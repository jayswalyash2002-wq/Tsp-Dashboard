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
    this.consumableMappings = const {},
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
  final Map<String, int> consumableMappings;

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
      consumableMappings: Map<String, int>.from(data['consumableMappings'] ?? {}),
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
    Map<String, int>? consumableMappings,
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
      consumableMappings: consumableMappings ?? this.consumableMappings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pricePaise': pricePaise,
      'category': category,
      'available': available,
      'sortOrder': sortOrder,
      'categorySortOrder': categorySortOrder,
      'businessId': businessId,
      'isDeleted': isDeleted,
      'consumableMappings': consumableMappings,
    };
  }
}

