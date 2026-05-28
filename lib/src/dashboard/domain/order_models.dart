import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

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
  /// Flat: paise, Percent: 0-100
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
    required DateTime timestamp,
    required String deviceName,
    required String userEmail,
    required String userId,
  }) {
    return SavedOrder(
      id: id,
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
    required super.lines,
    required super.discountType,
    required super.discountValue,
    required super.discountReason,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.splitLines,
    super.customerName,
    super.customerPhone,
    super.customerId,
  });

  final String id;
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

  bool get isCancelled => status == OrderStatus.cancelled;
  bool get isRefunded => status == OrderStatus.refunded;
  bool get shouldIncludeInSales =>
      status != OrderStatus.cancelled && status != OrderStatus.refunded;
  bool get isPaid => paymentStatus == PaymentStatus.paid || status == OrderStatus.paid;
  bool get isEditable =>
      status != OrderStatus.cancelled && status != OrderStatus.refunded;

  factory SavedOrder.fromMap(String id, Map<String, dynamic> map) {
    final discount = map['discount'] as Map<String, dynamic>;
    final payment = map['payment'] as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>;
    final user = map['loggedInUser'] as Map<String, dynamic>;

    return SavedOrder(
      id: id,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      deviceName: map['deviceName'] as String,
      userEmail: user['email'] as String,
      userId: user['uid'] as String,
      status: OrderStatus.fromString(map['status']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      preparingAt: (map['preparingAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      servedAt: (map['servedAt'] as Timestamp?)?.toDate(),
      cancellationReason: map['cancellationReason'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
      cancelledAt: (map['cancelledAt'] as Timestamp?)?.toDate(),
      refundRequired: map['refundRequired'] ?? false,
      inventoryDeducted: map['inventoryDeducted'] ?? false,
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      customerId: map['customerId'] as String?,
      lines: items
          .map((i) => OrderLine(
                  item: MenuItem(
                    id: i['itemId'],
                    name: i['name'],
                    category: i['category'],
                    pricePaise: i['pricePaise'],
                    available: true, // Not relevant for past orders
                    consumableMappings: (i['consumableMappings'] as Map<dynamic, dynamic>?)?.map(
                          (key, value) => MapEntry(
                            key.toString(),
                            value is int ? value : (int.tryParse(value.toString()) ?? 0),
                          ),
                        ) ??
                        {},
                  ),
                qty: i['qty'],
              ))
          .toList(),
      discountType: DiscountType.fromString(discount['type']),
      discountValue: discount['value'],
      discountReason: DiscountReason.fromString(discount['reason']),
      paymentMethod: PaymentMethod.fromString(payment['method']),
      paymentStatus: PaymentStatus.fromString(payment['status']),
      splitLines: (payment['splitLines'] as List<dynamic>?)
              ?.map((s) => SplitLine(
                    method: PaymentMethod.fromString(s['method']),
                    amountPaise: s['amountPaise'],
                  ))
              .toList() ??
          [],
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
  }) {
    return SavedOrder(
      id: id ?? this.id,
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
    );
  }
}

