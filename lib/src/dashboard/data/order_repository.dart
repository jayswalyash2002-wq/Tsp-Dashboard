import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../activity_log/data/models/activity_log_model.dart';
import '../../activity_log/domain/entities/activity_log_enums.dart';
import '../../activity_log/domain/repositories/activity_log_repository.dart';
import '../../activity_log/presentation/providers/activity_log_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../customers/domain/customer.dart';
import '../../core/sync/local_database_service.dart';
import '../../core/sync/sync_models.dart';
import '../domain/order_models.dart';

class OrderRepository {
  OrderRepository({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required AuthRepository authRepo,
    required ActivityLogRepository activityLogRepo,
    required LocalDatabaseService localDb,
    required String businessId,
  })  : _db = db,
        _auth = auth,
        _authRepo = authRepo,
        _activityLogRepo = activityLogRepo,
        _localDb = localDb,
        _businessId = businessId;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final AuthRepository _authRepo;
  final ActivityLogRepository _activityLogRepo;
  final LocalDatabaseService _localDb;
  final String _businessId;

  Stream<List<SavedOrder>> watchOrders() {
    if (kDebugMode) {
      debugPrint('ORDER_REPO: Watching orders for businessId: $_businessId');
    }
    
    final firestoreStream = _db
        .collection('orders')
        .where('businessId', isEqualTo: _businessId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SavedOrder.fromMap(doc.id, doc.data()))
            .toList());

    // Merge with local unsynced orders to ensure optimistic updates are visible
    return firestoreStream.map((remoteOrders) {
      final localUnsynced = _localDb.getUnsyncedOrders();
      
      // Filter out remote orders that are actually the same as local unsynced ones
      // (though they shouldn't be remote yet if they are unsynced)
      final localIds = localUnsynced.map((o) => o.id).toSet();
      final filteredRemote = remoteOrders.where((o) => !localIds.contains(o.id)).toList();
      
      final merged = [...localUnsynced, ...filteredRemote];
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return merged;
    });
  }

  Future<String> saveOrder(OrderDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final deviceName = _authRepo.getLocalDeviceName() ?? 'Unknown device';
    final now = DateTime.now();
    final orderId = const Uuid().v4();

    // 1. Create the model with SyncMetadata
    final order = draft.toOrder(
      id: orderId,
      timestamp: now,
      deviceName: deviceName,
      userEmail: user.email ?? 'unknown',
      userId: user.uid,
    ).copyWith(
      syncMetadata: SyncMetadata(
        localId: orderId,
        createdAt: now,
        updatedAt: now,
        synced: false,
      ),
      status: OrderStatus.pending,
    );

    // 2. Save locally first (Optimistic Update)
    await _localDb.saveOrder(order);
    
    // 3. Trigger background sync (don't await)
    syncOrder(order);

    return orderId;
  }

  Future<void> syncOrder(SavedOrder order) async {
    if (order.isSynced) return;

    final orderRef = _db.collection('orders').doc(order.id);
    final balancesRef = _db.collection('balances').doc(_businessId);
    
    try {
      await _db.runTransaction((tx) async {
        final balancesSnap = await tx.get(balancesRef);
        final now = DateTime.now();
        
        String? customerId;
        if (order.paymentStatus == PaymentStatus.paid) {
          customerId = await _handleCustomerUpdate(
            tx,
            order.customerPhone,
            order.customerName,
            order.totalPaise,
            now,
          );
        }

        if (order.paymentStatus == PaymentStatus.paid) {
          final data = balancesSnap.data() ?? {};
          int cash = data['cashBalancePaise'] ?? 0;
          int bank = data['bankBalancePaise'] ?? 0;

          final newImpact = _calculateImpact(order);
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

        final firestoreMap = order.toFirestoreMap();
        if (customerId != null) {
          firestoreMap['customerId'] = customerId;
        }
        tx.set(orderRef, firestoreMap);
      });

      // Mark as synced locally
      final syncedOrder = order.copyWith(
        syncMetadata: order.syncMetadata?.copyWith(synced: true, updatedAt: DateTime.now()),
      );
      await _localDb.saveOrder(syncedOrder);
      debugPrint('ORDER_REPO: Sync successful for ${order.id}');
    } catch (e) {
      debugPrint('ORDER_REPO: Sync failed for ${order.id}: $e');
      // Metadata remains unsynced, background SyncService will retry later
    }
  }

  Future<void> updateOrder(SavedOrder oldOrder, SavedOrder newOrder) async {
    final orderRef = _db.collection('orders').doc(oldOrder.id);
    final balancesRef = _db.collection('balances').doc(_businessId);

    if (kDebugMode) {
      debugPrint('ORDER_REPO: Updating order ${oldOrder.id} for businessId: $_businessId');
    }

    await _db.runTransaction((tx) async {
      // 1. PERFORM ALL READS FIRST & VALIDATE
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) {
        throw Exception('Order not found');
      }
      
      final orderData = orderSnap.data()!;
      final existingBusinessId = orderData['businessId']?.toString();
      
      if (existingBusinessId != _businessId) {
        if (kDebugMode) {
          debugPrint('CRITICAL: Blocked unauthorized order update attempt. '
              'Expected: $_businessId, Found: $existingBusinessId');
        }
        throw Exception('Access Denied: Business ownership mismatch');
      }

      final balancesSnap = await tx.get(balancesRef);

      final now = DateTime.now();
      String? customerId = newOrder.customerId;

      // Handle customer stat updates if payment status changed or amount changed
      if (newOrder.paymentStatus == PaymentStatus.paid) {
        // If it was already paid, we adjust the spent amount if it changed
        // If it was not paid, we add it as a new order for the customer
        int spentAdjustment = newOrder.totalPaise;
        int orderCountAdjustment = 1;

        if (oldOrder.paymentStatus == PaymentStatus.paid) {
          spentAdjustment = newOrder.totalPaise - oldOrder.totalPaise;
          orderCountAdjustment = 0; // Already counted
        }

        // Check if customer changed
        final oldNormalized = oldOrder.customerPhone?.trim().replaceAll(RegExp(r'[^0-9]'), '');
        final newNormalized = newOrder.customerPhone?.trim().replaceAll(RegExp(r'[^0-9]'), '');

        if (oldOrder.paymentStatus == PaymentStatus.paid && oldNormalized != newNormalized && oldNormalized != null) {
          // Revert old customer stats
          await _handleCustomerUpdate(tx, oldOrder.customerPhone, oldOrder.customerName, -oldOrder.totalPaise, now, countAdjustment: -1);
          // Re-apply to new customer as a full new order
          spentAdjustment = newOrder.totalPaise;
          orderCountAdjustment = 1;
        }

        customerId = await _handleCustomerUpdate(
          tx,
          newOrder.customerPhone,
          newOrder.customerName,
          spentAdjustment,
          now,
          countAdjustment: orderCountAdjustment,
        );
      } else if (oldOrder.paymentStatus == PaymentStatus.paid) {
        // Payment was reverted from Paid to Pending - revert customer stats
        await _handleCustomerUpdate(tx, oldOrder.customerPhone, oldOrder.customerName, -oldOrder.totalPaise, now, countAdjustment: -1);
        customerId = null;
      }

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
              'consumableMappings': l.item.consumableMappings,
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
        'customerName': newOrder.customerName,
        'customerPhone': newOrder.customerPhone,
        'customerId': customerId,
        'inventoryDeducted': newOrder.inventoryDeducted,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _auth.currentUser?.uid,
      });
    });
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final orderRef = _db.collection('orders').doc(orderId);
    
    if (kDebugMode) {
      debugPrint('ORDER_REPO: Updating order status to ${newStatus.name} for $orderId in $_businessId');
    }

    await _db.runTransaction((tx) async {
      final snap = await tx.get(orderRef);
      if (!snap.exists) throw Exception('Order not found');
      
      final existingBusinessId = snap.data()?['businessId']?.toString();
      if (existingBusinessId != _businessId) {
        if (kDebugMode) {
          debugPrint('CRITICAL: Blocked unauthorized order status update. '
              'Expected: $_businessId, Found: $existingBusinessId');
        }
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
        case OrderStatus.paid:
          throw UnimplementedError();
        case OrderStatus.cancelled:
          throw UnimplementedError();
        case OrderStatus.refunded:
          throw UnimplementedError();
      }

      tx.update(orderRef, updates);
    });
  }

  Future<void> cancelOrder({
    required String orderId,
    required String cancelledBy,
    required String cancelledByName,
    required String cancelledByRole,
    required String appVersion,
    required String platform,
    CancellationReason? reason,
    String? activityLogBusinessId,
  }) async {
    final orderRef = _db.collection('orders').doc(orderId);

    await _db.runTransaction((tx) async {
      // 1. READ current order document
      final snap = await tx.get(orderRef);
      if (!snap.exists) {
        throw StateError('Order not found');
      }

      final orderData = snap.data()!;
      final existingBusinessId = orderData['businessId']?.toString();

      // Verify business ownership
      if (existingBusinessId != _businessId) {
        throw Exception('Access Denied: Business ownership mismatch');
      }

      final currentStatus = OrderStatus.fromString(orderData['status']);

      // 2. Verify order is not already cancelled or refunded
      if (currentStatus == OrderStatus.cancelled ||
          currentStatus == OrderStatus.refunded) {
        throw StateError('Order is already in a terminal state (${currentStatus.name})');
      }

      // 3. Determine if refundRequired
      // Check both OrderStatus and PaymentStatus for safety
      final paymentData = orderData['payment'] as Map<String, dynamic>?;
      final paymentStatus = PaymentStatus.fromString(paymentData?['status']);
      final bool refundRequired =
          currentStatus == OrderStatus.paid || paymentStatus == PaymentStatus.paid;

      // 4. WRITE updated order
      tx.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'cancellationReason': reason?.name,
        'cancelledBy': cancelledBy,
        'cancelledByName': cancelledByName, // Storing name for history display
        'cancelledAt': FieldValue.serverTimestamp(),
        'refundRequired': refundRequired,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': cancelledBy,
      });

      // 5. WRITE activity log entry atomically
      final items = (orderData['items'] as List<dynamic>? ?? []);
      final firstItemName =
          items.isNotEmpty ? items.first['name'] : 'Unknown Order';

      final logEntry = ActivityLogModel(
        activityLogId: '',
        businessId: activityLogBusinessId ?? _businessId,
        performedBy: cancelledBy,
        performedByName: cancelledByName,
        performedByRole: cancelledByRole,
        action: ActivityAction.orderCancelled,
        category: ActivityCategory.operational,
        targetType: 'order',
        targetId: orderId,
        targetName: firstItemName,
        metadata: {
          'cancellationReason': reason?.name ?? 'none',
          'refundRequired': refundRequired,
          'orderStatus': 'cancelled',
          'itemCount': items.length,
        },
        appVersion: appVersion,
        platform: platform,
      );

      final logData = _activityLogRepo.buildActivityLogBatchData(logEntry);
      tx.set(logData.ref, logData.data);
    });
  }

  Stream<List<SavedOrder>> watchActiveKitchenOrders() {
    if (kDebugMode) {
      debugPrint('ORDER_REPO: Watching active kitchen orders for businessId: $_businessId');
    }
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

  Future<String?> _handleCustomerUpdate(
    Transaction tx,
    String? phone,
    String? name,
    int spentAdjustment,
    DateTime now, {
    int countAdjustment = 0,
  }) async {
    if (phone == null || phone.trim().isEmpty) return null;

    final normalizedPhone = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (normalizedPhone.isEmpty) return null;

    final customerRef = _db
        .collection('businesses')
        .doc(_businessId)
        .collection('customers')
        .doc(normalizedPhone);

    final customerSnap = await tx.get(customerRef);

    if (customerSnap.exists) {
      final customer = Customer.fromMap(customerSnap.id, customerSnap.data()!);
      final updatedCustomer = customer.copyWith(
        name: name?.trim().isNotEmpty == true ? name : customer.name,
        totalOrders: (customer.totalOrders + countAdjustment).clamp(0, 9999999),
        totalSpentPaise: (customer.totalSpentPaise + spentAdjustment).clamp(0, 999999999),
        lastVisit: countAdjustment > 0 ? now : customer.lastVisit,
        updatedAt: now,
      );
      tx.set(customerRef, updatedCustomer.toMap());
    } else if (countAdjustment >= 0) {
      final newCustomer = Customer(
        id: normalizedPhone,
        name: name?.trim().isNotEmpty == true ? name : null,
        phone: normalizedPhone,
        totalOrders: countAdjustment.clamp(0, 1),
        totalSpentPaise: spentAdjustment.clamp(0, 999999999),
        lastVisit: now,
        createdAt: now,
        updatedAt: now,
      );
      tx.set(customerRef, newCustomer.toMap());
    }

    return normalizedPhone;
  }
}

class _Impact {
  _Impact(this.cash, this.bank);
  final int cash;
  final int bank;
}
