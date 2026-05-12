import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/menu_item.dart';
import '../domain/order_models.dart';

final orderControllerProvider =
    NotifierProvider<OrderController, OrderDraft>(OrderController.new);

class OrderController extends Notifier<OrderDraft> {
  @override
  OrderDraft build() {
    return OrderDraft(
      lines: const [],
      discountType: DiscountType.none,
      discountValue: 0,
      discountReason: null,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.paid,
      splitLines: const [],
    );
  }

  void add(MenuItem item) {
    final existing = state.lineFor(item.id);
    if (existing == null) {
      state = state.copyWith(lines: [...state.lines, OrderLine(item: item, qty: 1)]);
    } else {
      setQty(item.id, existing.qty + 1);
    }
  }

  void increment(String itemId) {
    final line = state.lineFor(itemId);
    if (line == null) return;
    setQty(itemId, line.qty + 1);
  }

  void decrement(String itemId) {
    final line = state.lineFor(itemId);
    if (line == null) return;
    setQty(itemId, line.qty - 1);
  }

  void setQty(String itemId, int qty) {
    final next = <OrderLine>[];
    for (final l in state.lines) {
      if (l.item.id != itemId) {
        next.add(l);
        continue;
      }
      if (qty <= 0) continue;
      next.add(OrderLine(item: l.item, qty: qty));
    }
    state = state.copyWith(lines: next);
  }

  void setDiscountType(DiscountType type) {
    state = state.copyWith(
      discountType: type,
      discountValue: type == DiscountType.none ? 0 : state.discountValue,
      discountReason: type == DiscountType.none ? null : state.discountReason,
    );
  }

  void setDiscountValue(int value) {
    state = state.copyWith(discountValue: value);
  }

  void setDiscountReason(DiscountReason? reason) {
    state = state.copyWith(discountReason: reason);
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(
      paymentMethod: method,
      splitLines: method == PaymentMethod.split ? state.splitLines : const [],
    );
  }

  void setPaymentStatus(PaymentStatus status) {
    state = state.copyWith(paymentStatus: status);
  }

  void setSplitLines(List<SplitLine> lines) {
    state = state.copyWith(splitLines: lines);
  }

  void clear() {
    state = build();
  }
}

