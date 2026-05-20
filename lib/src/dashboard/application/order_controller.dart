import 'dart:async' show unawaited;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_providers.dart';
import '../domain/menu_item.dart';
import '../domain/order_models.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';

class OrderControllerState {
  OrderControllerState({
    required this.draft,
    this.originalOrder,
  });

  final OrderDraft draft;
  final SavedOrder? originalOrder;

  bool get isEditing => originalOrder != null;

  OrderControllerState copyWith({
    OrderDraft? draft,
    SavedOrder? originalOrder,
    bool clearOriginal = false,
  }) {
    return OrderControllerState(
      draft: draft ?? this.draft,
      originalOrder: clearOriginal ? null : (originalOrder ?? this.originalOrder),
    );
  }
}

final orderControllerProvider =
    NotifierProvider<OrderController, OrderControllerState>(OrderController.new);

class OrderController extends Notifier<OrderControllerState> {
  @override
  OrderControllerState build() {
    return OrderControllerState(
      draft: OrderDraft(
        lines: const [],
        discountType: DiscountType.none,
        discountValue: 0,
        discountReason: null,
        paymentMethod: PaymentMethod.cash,
        paymentStatus: PaymentStatus.paid,
        splitLines: const [],
      ),
    );
  }

  void editOrder(SavedOrder order) {
    state = OrderControllerState(
      draft: order, // Order is a subclass of OrderDraft
      originalOrder: order,
    );
  }

  void add(MenuItem item) {
    final existing = state.draft.lineFor(item.id);
    if (existing == null) {
      state = state.copyWith(
        draft: state.draft.copyWith(lines: [...state.draft.lines, OrderLine(item: item, qty: 1)]),
      );
    } else {
      setQty(item.id, existing.qty + 1);
    }
  }

  void increment(String itemId) {
    final line = state.draft.lineFor(itemId);
    if (line == null) return;
    setQty(itemId, line.qty + 1);
  }

  void decrement(String itemId) {
    final line = state.draft.lineFor(itemId);
    if (line == null) return;
    setQty(itemId, line.qty - 1);
  }

  void setQty(String itemId, int qty) {
    final next = <OrderLine>[];
    for (final l in state.draft.lines) {
      if (l.item.id != itemId) {
        next.add(l);
        continue;
      }
      if (qty <= 0) continue;
      next.add(OrderLine(item: l.item, qty: qty));
    }
    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  void setDiscountType(DiscountType type) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        discountType: type,
        discountValue: type == DiscountType.none ? 0 : state.draft.discountValue,
        discountReason: type == DiscountType.none ? null : state.draft.discountReason,
      ),
    );
  }

  void setDiscountValue(int value) {
    state = state.copyWith(draft: state.draft.copyWith(discountValue: value));
  }

  void setDiscountReason(DiscountReason? reason) {
    state = state.copyWith(draft: state.draft.copyWith(discountReason: reason));
  }

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(
      draft: state.draft.copyWith(
        paymentMethod: method,
        splitLines: method == PaymentMethod.split ? state.draft.splitLines : const [],
      ),
    );
  }

  void setPaymentStatus(PaymentStatus status) {
    state = state.copyWith(draft: state.draft.copyWith(paymentStatus: status));
  }

  void setSplitLines(List<SplitLine> lines) {
    state = state.copyWith(draft: state.draft.copyWith(splitLines: lines));
  }

  Future<void> submit() async {
    final repo = await ref.read(orderRepositoryProvider.future);
    if (repo == null) {
      throw StateError('Order repository not available. Please complete business setup.');
    }

    if (state.isEditing) {
      final updated = state.originalOrder!.copyWith(
        lines: state.draft.lines,
        discountType: state.draft.discountType,
        discountValue: state.draft.discountValue,
        discountReason: state.draft.discountReason,
        paymentMethod: state.draft.paymentMethod,
        paymentStatus: state.draft.paymentStatus,
        splitLines: state.draft.splitLines,
      );
      await repo.updateOrder(state.originalOrder!, updated);

      unawaited(
        ref.read(logActivityUseCaseProvider).execute(
          action: ActivityAction.orderModified,
          category: ActivityCategory.operational,
          targetType: 'order',
          targetId: updated.id,
          targetName: 'Order #${updated.id.substring(0, 4)}',
          metadata: {'total': updated.totalPaise / 100},
        ),
      );
    } else {
      final orderId = await repo.saveOrder(state.draft);

      unawaited(
        ref.read(logActivityUseCaseProvider).execute(
          action: ActivityAction.orderCreated,
          category: ActivityCategory.operational,
          targetType: 'order',
          targetId: orderId,
          targetName: 'Order #${orderId.substring(0, 4)}',
          metadata: {'total': state.draft.totalPaise / 100},
        ),
      );
    }
    clear();
  }

  Future<void> cancelOrder({
    required String orderId,
    CancellationReason? reason,
  }) async {
    final repo = await ref.read(orderRepositoryProvider.future);
    if (repo == null) throw StateError('Order repository not available');

    final logUseCase = ref.read(logActivityUseCaseProvider);

    await repo.cancelOrder(
      orderId: orderId,
      cancelledBy: logUseCase.performedBy,
      cancelledByName: logUseCase.performedByName,
      cancelledByRole: logUseCase.performedByRole,
      appVersion: logUseCase.appVersion,
      platform: logUseCase.platform,
      reason: reason,
    );
  }

  void clear() {
    state = build();
  }
}

