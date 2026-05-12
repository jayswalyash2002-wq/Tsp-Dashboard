import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/order_models.dart';

class OrderRepository {
  OrderRepository({
    required FirebaseFirestore db,
    required FirebaseAuth auth,
    required AuthRepository authRepo,
  })  : _db = db,
        _auth = auth,
        _authRepo = authRepo;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final AuthRepository _authRepo;

  Future<String> saveOrder(OrderDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final deviceName = _authRepo.getLocalDeviceName() ?? 'Unknown device';
    final now = DateTime.now();
    final orderId = const Uuid().v4();

    final orderRef = _db.collection('orders').doc(orderId);
    final balancesRef = _db.collection('balances').doc('current');

    await _db.runTransaction((tx) async {
      tx.set(orderRef, {
        'orderId': orderId,
        'timestamp': Timestamp.fromDate(now),
        'timestampMs': now.millisecondsSinceEpoch,
        'loggedInUser': {
          'uid': user.uid,
          'email': user.email,
        },
        'deviceName': deviceName,
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

      // Only affect balances when paid (operational accounting).
      if (draft.paymentStatus == PaymentStatus.paid) {
        final balancesSnap = await tx.get(balancesRef);
        final data = balancesSnap.data() ?? <String, dynamic>{};
        final cash = (data['cashBalancePaise'] ?? 0) is int
            ? (data['cashBalancePaise'] as int)
            : int.tryParse('${data['cashBalancePaise']}') ?? 0;
        final bank = (data['bankBalancePaise'] ?? 0) is int
            ? (data['bankBalancePaise'] as int)
            : int.tryParse('${data['bankBalancePaise']}') ?? 0;

        int cashDelta = 0;
        int bankDelta = 0;

        switch (draft.paymentMethod) {
          case PaymentMethod.cash:
            cashDelta = draft.totalPaise;
            break;
          case PaymentMethod.upi:
          case PaymentMethod.card:
            bankDelta = draft.totalPaise;
            break;
          case PaymentMethod.split:
            for (final s in draft.splitLines) {
              if (s.method == PaymentMethod.cash) cashDelta += s.amountPaise;
              if (s.method == PaymentMethod.upi || s.method == PaymentMethod.card) {
                bankDelta += s.amountPaise;
              }
            }
            break;
        }

        tx.set(
          balancesRef,
          {
            'cashBalancePaise': cash + cashDelta,
            'bankBalancePaise': bank + bankDelta,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
          },
          SetOptions(merge: true),
        );
      }
    });

    return orderId;
  }
}

