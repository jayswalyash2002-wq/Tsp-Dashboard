import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import '../../core/sync/sync_models.dart';

import 'menu_item.dart';

enum PaymentStatus {
  paid,
  pending;

  static PaymentStatus fromString(String? val) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => PaymentStatus.pending,
    );
  }
}

enum PaymentMethod {
  cash,
  upi,
  card,
  split;

  static PaymentMethod fromString(String? val) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == val,
      orElse: () => PaymentMethod.cash,
    );
  }
}

enum DiscountType {
  none,
  flat,
  percent,
  complimentary;

  static DiscountType fromString(String? val) {
    return DiscountType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => DiscountType.none,
    );
  }
}

enum DiscountReason {
  friendsFamily,
  offer,
  promo,
  testing,
  wastage;

  static DiscountReason? fromString(String? val) {
    if (val == null) return null;
    return DiscountReason.values.firstWhereOrNull((e) => e.name == val);
  }
}

enum OrderStatus {
  pending,
  preparing,
  completed,
  served,
  paid,
  cancelled,
  refunded;

  static OrderStatus fromString(String? val) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => OrderStatus.pending,
    );
  }
}

enum CancellationReason {
  customerCancelled,
  duplicateOrder,
  wrongOrder,
  staffMistake,
  outOfStock,
  other;

  String get displayName {
    switch (this) {
      case CancellationReason.customerCancelled:
        return 'Customer Cancelled';
      case CancellationReason.duplicateOrder:
        return 'Duplicate Order';
      case CancellationReason.wrongOrder:
        return 'Wrong Order';
      case CancellationReason.staffMistake:
        return 'Staff Mistake';
      case CancellationReason.outOfStock:
        return 'Out of Stock';
      case CancellationReason.other:
        return 'Other';
    }
  }

  static CancellationReason? fromString(String? val) {
    if (val == null) return null;
    return CancellationReason.values.firstWhereOrNull((e) => e.name == val);
  }
}

class SplitLine {
  SplitLine({required this.method, required this.amountPaise});

  final PaymentMethod method;
  final int amountPaise;

  Map<String, dynamic> toMap() => {
        'method': method.name,
        'amountPaise': amountPaise,
      };
}

class OrderLine {
  OrderLine({required this.item, required this.qty});

  final MenuItem item;
  final int qty;

  int get lineTotalPaise => item.pricePaise * qty;
}

class OrderDraft {
  OrderDraft({
    required this.lines,
    required this.discountType,
    required this.discountValue,
    required this.discountReason,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.splitLines,
    this.customerName,
    this.customerPhone,
    this.customerId,
  });

  final List<OrderLine> lines;
  final DiscountType discountType;
  final int discountValue;
  final DiscountReason? discountReason;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final List<SplitLine> splitLines;
  final String? customerName;
  final String? customerPhone;
  final String? customerId;

  int get subtotalPaise => lines.fold(0, (total, l) => total + l.lineTotalPaise);

  int get discountPaise {
    if (discountType == DiscountType.none) return 0;
    if (discountType == DiscountType.complimentary) return subtotalPaise;
    if (discountType == DiscountType.flat) return discountValue.clamp(0, subtotalPaise);
    if (discountType == DiscountType.percent) {
      final pct = discountValue.clamp(0, 100);
      return ((subtotalPaise * pct) / 100.0).round().clamp(0, subtotalPaise);
    }
    return 0;
  }

  int get totalPaise => (subtotalPaise - discountPaise).clamp(0, subtotalPaise);

  bool get hasItems => lines.isNotEmpty;

  bool get splitValid {
    if (paymentMethod != PaymentMethod.split) return true;
    final sum = splitLines.fold(0, (s, l) => s + l.amountPaise);
    return sum == totalPaise && sum > 0;
  }

  OrderDraft copyWith({
    List<OrderLine>? lines,
    DiscountType? discountType,
    int? discountValue,
    DiscountReason? discountReason,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    List<SplitLine>? splitLines,
    String? customerName,
    String? customerPhone,
    String? customerId,
  }) {
    return OrderDraft(
      lines: lines ?? this.lines,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountReason: discountReason ?? this.discountReason,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      splitLines: splitLines ?? this.splitLines,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerId: customerId ?? this.customerId,
    );
  }

  OrderLine? lineFor(String itemId) => lines.firstWhereOrNull((l) => l.item.id == itemId);

  SavedOrder toOrder({
    required String id,
    required String businessId,
    required DateTime timestamp,
    required String deviceName,
    required String userEmail,
    required String userId,
  }) {
    return SavedOrder(
      id: id,
      businessId: businessId,
      timestamp: timestamp,
      deviceName: deviceName,
      userEmail: userEmail,
      userId: userId,
      lines: lines,
      discountType: discountType,
      discountValue: discountValue,
      discountReason: discountReason,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      splitLines: splitLines,
      customerName: customerName,
      customerPhone: customerPhone,
      customerId: customerId,
    );
  }
}

class SavedOrder extends OrderDraft {
  SavedOrder({
    required this.id,
    required this.businessId,
    required this.timestamp,
    required this.deviceName,
    required this.userEmail,
    required this.userId,
    this.status = OrderStatus.pending,
    this.createdAt,
    this.preparingAt,
    this.completedAt,
    this.servedAt,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.refundRequired = false,
    this.inventoryDeducted = false,
    required List<OrderLine> lines,
    required DiscountType discountType,
    required int discountValue,
    required DiscountReason? discountReason,
    required PaymentMethod paymentMethod,
    required PaymentStatus paymentStatus,
    required List<SplitLine> splitLines,
    String? customerName,
    String? customerPhone,
    String? customerId,
    this.syncMetadata,
  }) : super(
          lines: lines,
          discountType: discountType,
          discountValue: discountValue,
          discountReason: discountReason,
          paymentMethod: paymentMethod,
          paymentStatus: paymentStatus,
          splitLines: splitLines,
          customerName: customerName,
          customerPhone: customerPhone,
          customerId: customerId,
        );

  final String id;
  final String businessId;
  final DateTime timestamp;
  final String deviceName;
  final String userEmail;
  final String userId;
  final OrderStatus status;
  final DateTime? createdAt;
  final DateTime? preparingAt;
  final DateTime? completedAt;
  final DateTime? servedAt;

  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final bool refundRequired;
  final bool inventoryDeducted;
  final SyncMetadata? syncMetadata;

  bool get isSynced => syncMetadata?.synced ?? true;
  bool get isCancelled => status == OrderStatus.cancelled;
  bool get isRefunded => status == OrderStatus.refunded;
  bool get shouldIncludeInSales =>
      status != OrderStatus.cancelled && status != OrderStatus.refunded;
  bool get isPaid => paymentStatus == PaymentStatus.paid || status == OrderStatus.paid;
  bool get isEditable =>
      status != OrderStatus.cancelled && status != OrderStatus.refunded;

  factory SavedOrder.fromMap(String id, Map<String, dynamic> map) {
    Map<String, dynamic> getMap(dynamic val) {
      if (val == null) return {};
      if (val is Map) return Map<String, dynamic>.from(val);
      return {};
    }

    final discount = getMap(map['discount']);
    final payment = getMap(map['payment']);
    final items = (map['items'] as List<dynamic>?) ?? [];
    final user = getMap(map['loggedInUser']);

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    final orderId = map['orderId']?.toString() ?? id;

    return SavedOrder(
      id: orderId,
      businessId: map['businessId']?.toString() ?? '',
      timestamp: parseDate(map['timestamp']) ?? DateTime.now(),
      deviceName: map['deviceName']?.toString() ?? 'Unknown',
      userEmail: user['email']?.toString() ?? 'unknown',
      userId: user['uid']?.toString() ?? 'unknown',
      status: OrderStatus.fromString(map['status']?.toString()),
      createdAt: parseDate(map['createdAt']),
      preparingAt: parseDate(map['preparingAt']),
      completedAt: parseDate(map['completedAt']),
      servedAt: parseDate(map['servedAt']),
      cancellationReason: map['cancellationReason']?.toString(),
      cancelledBy: map['cancelledBy']?.toString(),
      cancelledAt: parseDate(map['cancelledAt']),
      refundRequired: map['refundRequired'] ?? false,
      inventoryDeducted: map['inventoryDeducted'] ?? false,
      customerName: map['customerName']?.toString(),
      customerPhone: map['customerPhone']?.toString(),
      customerId: map['customerId']?.toString(),
      lines: items
          .map((i) {
            final itemMap = getMap(i);
            return OrderLine(
              item: MenuItem(
                id: itemMap['itemId']?.toString() ?? '',
                name: itemMap['name']?.toString() ?? 'Unknown',
                category: itemMap['category']?.toString() ?? 'General',
                pricePaise: itemMap['pricePaise'] ?? 0,
                available: true,
                consumableMappings: getMap(itemMap['consumableMappings']).map(
                  (key, value) => MapEntry(
                    key.toString(),
                    value is int ? value : (int.tryParse(value.toString()) ?? 0),
                  ),
                ),
              ),
              qty: itemMap['qty'] ?? 0,
            );
          })
          .toList(),
      discountType: DiscountType.fromString(discount['type']?.toString()),
      discountValue: discount['value'] ?? 0,
      discountReason: DiscountReason.fromString(discount['reason']?.toString()),
      paymentMethod: PaymentMethod.fromString(payment['method']?.toString()),
      paymentStatus: PaymentStatus.fromString(payment['status']?.toString()),
      splitLines: (payment['splitLines'] as List<dynamic>?)
              ?.map((s) {
                final sMap = getMap(s);
                return SplitLine(
                    method: PaymentMethod.fromString(sMap['method']?.toString()),
                    amountPaise: sMap['amountPaise'] ?? 0,
                  );
              })
              .toList() ??
          [],
      syncMetadata: map['syncMetadata'] != null 
          ? SyncMetadata.fromMap(getMap(map['syncMetadata']))
          : null,
    );
  }

  @override
  SavedOrder copyWith({
    List<OrderLine>? lines,
    DiscountType? discountType,
    int? discountValue,
    DiscountReason? discountReason,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    List<SplitLine>? splitLines,
    String? id,
    String? businessId,
    DateTime? timestamp,
    String? deviceName,
    String? userEmail,
    String? userId,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? preparingAt,
    DateTime? completedAt,
    DateTime? servedAt,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? cancelledAt,
    bool? refundRequired,
    bool? inventoryDeducted,
    String? customerName,
    String? customerPhone,
    String? customerId,
    SyncMetadata? syncMetadata,
  }) {
    return SavedOrder(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      timestamp: timestamp ?? this.timestamp,
      deviceName: deviceName ?? this.deviceName,
      userEmail: userEmail ?? this.userEmail,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      preparingAt: preparingAt ?? this.preparingAt,
      completedAt: completedAt ?? this.completedAt,
      servedAt: servedAt ?? this.servedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      refundRequired: refundRequired ?? this.refundRequired,
      inventoryDeducted: inventoryDeducted ?? this.inventoryDeducted,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerId: customerId ?? this.customerId,
      lines: lines ?? this.lines,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountReason: discountReason ?? this.discountReason,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      splitLines: splitLines ?? this.splitLines,
      syncMetadata: syncMetadata ?? this.syncMetadata,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['orderId'] = id;
    data['businessId'] = businessId;
    data['timestamp'] = Timestamp.fromDate(timestamp);
    data['deviceName'] = deviceName;
    data['loggedInUser'] = {'uid': userId, 'email': userEmail};
    data['status'] = status.name;
    data['createdAt'] = createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final List<Map<String, dynamic>> itemsList = [];
    for (final OrderLine ol in lines) {
      final Map<String, dynamic> itemMap = <String, dynamic>{};
      itemMap['itemId'] = ol.item.id;
      itemMap['name'] = ol.item.name;
      itemMap['category'] = ol.item.category;
      itemMap['pricePaise'] = ol.item.pricePaise;
      itemMap['qty'] = ol.qty;
      itemMap['lineTotalPaise'] = ol.lineTotalPaise;
      itemMap['consumableMappings'] = ol.item.consumableMappings;
      itemsList.add(itemMap);
    }
    data['items'] = itemsList;

    data['subtotalPaise'] = subtotalPaise;
    data['discount'] = {
      'type': discountType.name,
      'value': discountValue,
      'reason': discountReason?.name,
      'discountPaise': discountPaise,
    };
    data['totalPaise'] = totalPaise;
    data['payment'] = {
      'method': paymentMethod.name,
      'status': paymentStatus.name,
      'splitLines': splitLines.map((s) => s.toMap()).toList(),
    };
    data['customerName'] = customerName;
    data['customerPhone'] = customerPhone;
    data['customerId'] = customerId;
    data['inventoryDeducted'] = inventoryDeducted;
    return data;
  }

  Map<String, dynamic> toLocalMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['orderId'] = id;
    data['businessId'] = businessId;
    data['timestamp'] = timestamp.toIso8601String();
    data['deviceName'] = deviceName;
    data['loggedInUser'] = {'uid': userId, 'email': userEmail};
    data['status'] = status.name;
    data['createdAt'] = (createdAt ?? timestamp).toIso8601String();
    data['updatedAt'] = DateTime.now().toIso8601String();

    final List<Map<String, dynamic>> itemsList = [];
    for (final OrderLine ol in lines) {
      final Map<String, dynamic> itemMap = <String, dynamic>{};
      itemMap['itemId'] = ol.item.id;
      itemMap['name'] = ol.item.name;
      itemMap['category'] = ol.item.category;
      itemMap['pricePaise'] = ol.item.pricePaise;
      itemMap['qty'] = ol.qty;
      itemMap['lineTotalPaise'] = ol.lineTotalPaise;
      itemMap['consumableMappings'] = ol.item.consumableMappings;
      itemsList.add(itemMap);
    }
    data['items'] = itemsList;

    data['subtotalPaise'] = subtotalPaise;
    data['discount'] = {
      'type': discountType.name,
      'value': discountValue,
      'reason': discountReason?.name,
      'discountPaise': discountPaise,
    };
    data['totalPaise'] = totalPaise;
    data['payment'] = {
      'method': paymentMethod.name,
      'status': paymentStatus.name,
      'splitLines': splitLines.map((s) => s.toMap()).toList(),
    };
    data['customerName'] = customerName;
    data['customerPhone'] = customerPhone;
    data['customerId'] = customerId;
    data['inventoryDeducted'] = inventoryDeducted;

    if (preparingAt != null) data['preparingAt'] = preparingAt!.toIso8601String();
    if (completedAt != null) data['completedAt'] = completedAt!.toIso8601String();
    if (servedAt != null) data['servedAt'] = servedAt!.toIso8601String();
    if (cancelledAt != null) data['cancelledAt'] = cancelledAt!.toIso8601String();
    
    final s = syncMetadata;
    if (s != null) {
      data['syncMetadata'] = s.toMap();
    }
    return data;
  }
}
