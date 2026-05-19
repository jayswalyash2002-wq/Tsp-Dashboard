import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/order_models.dart';

class OrderRepository {
  OrderRepository({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required AuthRepository authRepo,
    required String businessId,
  })  : _db = db,
        _auth = auth,
        _authRepo = authRepo,
        _businessId = businessId;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final AuthRepository _authRepo;
  final String _businessId;

  Stream<List<SavedOrder>> watchOrders() {
    debugPrint('ORDER_REPO: Watching orders for businessId: $_businessId');
    return _db
        .collection('orders')
        .where('businessId', isEqualTo: _businessId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SavedOrder.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<String> saveOrder(OrderDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final deviceName = _authRepo.getLocalDeviceName() ?? 'Unknown device';
    final now = DateTime.now();
    final orderId = const Uuid().v4();

    final orderRef = _db.collection('orders').doc(orderId);
    final balancesRef = _db.collection('balances').doc(_businessId);

    debugPrint('ORDER_REPO: Saving order $orderId for businessId: $_businessId');

    await _db.runTransaction((tx) async {
      // 1. PERFORM ALL READS FIRST
      final balancesSnap = await tx.get(balancesRef);
      
      // 2. PERFORM ALL WRITES
      if (draft.paymentStatus == PaymentStatus.paid) {
        final data = balancesSnap.data() ?? {};
        int cash = data['cashBalancePaise'] ?? 0;
        int bank = data['bankBalancePaise'] ?? 0;

        final newImpact = _calculateImpact(draft);
        cash += newImpact.cash;
        bank += newImpact.bank;

        tx.set(
          balancesRef,
          {
            'businessId': _businessId,
            'cashBalancePaise': cash,
            'bankBalancePaise': bank,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          },
          SetOptions(merge: true),
        );
      }

      tx.set(orderRef, {
        'orderId': orderId,
        'businessId': _businessId,
        'timestamp': Timestamp.fromDate(now),
        'timestampMs': now.millisecondsSinceEpoch,
        'loggedInUser': {
          'uid': user.uid,
          'email': user.email,
        },
        'deviceName': deviceName,
        'status': OrderStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'items': [
          for (final l in draft.lines)
            {
              'itemId': l.item.id,
              'name': l.item.name,
              'category': l.item.category,
              'pricePaise': l.item.pricePaise,
              'qty': l.qty,
              'lineTotalPaise': l.lineTotalPaise,
            }
        ],
        'subtotalPaise': draft.subtotalPaise,
        'discount': {
          'type': draft.discountType.name,
          'value': draft.discountValue,
          'reason': draft.discountReason?.name,
          'discountPaise': draft.discountPaise,
        },
        'totalPaise': draft.totalPaise,
        'payment': {
          'method': draft.paymentMethod.name,
          'status': draft.paymentStatus.name,
          'splitLines': [for (final s in draft.splitLines) s.toMap()],
        },
      });
    });

    return orderId;
  }

  Future<void> updateOrder(SavedOrder oldOrder, SavedOrder newOrder) async {
    final orderRef = _db.collection('orders').doc(oldOrder.id);
    final balancesRef = _db.collection('balances').doc(_businessId);

    debugPrint('ORDER_REPO: Updating order ${oldOrder.id} for businessId: $_businessId');

    await _db.runTransaction((tx) async {
      // 1. PERFORM ALL READS FIRST & VALIDATE
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw Exception('Order not found');
      }
      
      final orderData = orderSnap.data()!;
      final existingBusinessId = orderData['businessId']?.toString();
      
      if (existingBusinessId != _businessId) {
        debugPrint('CRITICAL: Blocked unauthorized order update attempt. '
            'Expected: $_businessId, Found: $existingBusinessId');
        throw Exception('Access Denied: Business ownership mismatch');
      }

      final balancesSnap = await tx.get(balancesRef);

      // 2. PERFORM ALL WRITES
      final data = balancesSnap.data() ?? {};
      int cash = data['cashBalancePaise'] ?? 0;
      int bank = data['bankBalancePaise'] ?? 0;

      // Remove old order impact if it was paid
      if (oldOrder.paymentStatus == PaymentStatus.paid) {
        final oldImpact = _calculateImpact(oldOrder);
        cash -= oldImpact.cash;
        bank -= oldImpact.bank;
      }

      // Add new order impact if it is paid
      if (newOrder.paymentStatus == PaymentStatus.paid) {
        final newImpact = _calculateImpact(newOrder);
        cash += newImpact.cash;
        bank += newImpact.bank;
      }

      tx.set(
        balancesRef,
        {
          'businessId': _businessId,
          'cashBalancePaise': cash,
          'bankBalancePaise': bank,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        },
        SetOptions(merge: true),
      );

      tx.update(orderRef, {
        'items': [
          for (final l in newOrder.lines)
            {
              'itemId': l.item.id,
              'name': l.item.name,
              'category': l.item.category,
              'pricePaise': l.item.pricePaise,
              'qty': l.qty,
              'lineTotalPaise': l.lineTotalPaise,
            }
        ],
        'subtotalPaise': newOrder.subtotalPaise,
        'discount': {
          'type': newOrder.discountType.name,
          'value': newOrder.discountValue,
          'reason': newOrder.discountReason?.name,
          'discountPaise': newOrder.discountPaise,
        },
        'totalPaise': newOrder.totalPaise,
        'payment': {
          'method': newOrder.paymentMethod.name,
          'status': newOrder.paymentStatus.name,
          'splitLines': [for (final s in newOrder.splitLines) s.toMap()],
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      });
    });
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final orderRef = _db.collection('orders').doc(orderId);
    
    debugPrint('ORDER_REPO: Updating order status to ${newStatus.name} for $orderId in $_businessId');

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');
      
      final existingBusinessId = snap.data()?['businessId']?.toString();
      if (existingBusinessId != _businessId) {
        debugPrint('CRITICAL: Blocked unauthorized order status update. '
            'Expected: $_businessId, Found: $existingBusinessId');
        throw Exception('Access Denied: Business ownership mismatch');
      }

      final Map<String, dynamic> updates = {
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      };

      switch (newStatus) {
        case OrderStatus.preparing:
          updates['preparingAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.completed:
          updates['completedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.served:
          updates['servedAt'] = FieldValue.serverTimestamp();
          break;
        case OrderStatus.pending:
          break;
      }

      tx.update(orderRef, updates);
    });
  }

  Stream<List<SavedOrder>> watchActiveKitchenOrders() {
    debugPrint('ORDER_REPO: Watching active kitchen orders for businessId: $_businessId');
    return _db
        .collection('orders')
        .where('businessId', isEqualTo: _businessId)
        .where('status', whereIn: [
          OrderStatus.pending.name,
          OrderStatus.preparing.name,
          OrderStatus.completed.name,
        ])
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SavedOrder.fromMap(doc.id, doc.data()))
            .toList());
  }

  _Impact _calculateImpact(OrderDraft draft) {
    int cash = 0;
    int bank = 0;

    switch (draft.paymentMethod) {
      case PaymentMethod.cash:
        cash = draft.totalPaise;
        break;
      case PaymentMethod.upi:
      case PaymentMethod.card:
        bank = draft.totalPaise;
        break;
      case PaymentMethod.split:
        for (final s in draft.splitLines) {
          if (s.method == PaymentMethod.cash) cash += s.amountPaise;
          if (s.method == PaymentMethod.upi || s.method == PaymentMethod.card) {
            bank += s.amountPaise;
          }
        }
        break;
    }
    return _Impact(cash, bank);
  }
}

class _Impact {
  _Impact(this.cash, this.bank);
  final int cash;
  final int bank;
}
