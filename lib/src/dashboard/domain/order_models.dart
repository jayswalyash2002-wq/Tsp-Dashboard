import 'package:collection/collection.dart';

import 'menu_item.dart';

enum PaymentStatus { paid, pending }

enum PaymentMethod { cash, upi, card, split }

enum DiscountType { none, flat, percent, complimentary }

enum DiscountReason { friendsFamily, offer, promo, testing, wastage }

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
  });

  final List<OrderLine> lines;
  final DiscountType discountType;
  /// Flat: paise, Percent: 0-100
  final int discountValue;
  final DiscountReason? discountReason;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final List<SplitLine> splitLines;

  int get subtotalPaise => lines.fold(0, (sum, l) => sum + l.lineTotalPaise);

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
  }) {
    return OrderDraft(
      lines: lines ?? this.lines,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      discountReason: discountReason ?? this.discountReason,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      splitLines: splitLines ?? this.splitLines,
    );
  }

  OrderLine? lineFor(String itemId) => lines.firstWhereOrNull((l) => l.item.id == itemId);
}

