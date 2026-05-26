import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/domain/order_models.dart';
import '../../expenses/domain/expense.dart';
import '../../inventory/domain/inventory_item.dart';

class AnalyticsRepository {
  final FirebaseFirestore _db;
  final String _businessId;

  AnalyticsRepository(this._db, this._businessId);

  Future<List<SavedOrder>> getOrders(DateTime start, DateTime end) async {
    final snap = await _db
        .collection('orders')
        .where('businessId', isEqualTo: _businessId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return snap.docs
        .map((doc) => SavedOrder.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<Expense>> getExpenses(DateTime start, DateTime end) async {
    final snap = await _db
        .collection('expenses')
        .where('businessId', isEqualTo: _businessId)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return snap.docs
        .map((doc) => Expense.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<InventoryItem>> getAllInventoryItems() async {
    final snap = await _db
        .collection('businesses')
        .doc(_businessId)
        .collection('inventoryItems')
        .get();

    return snap.docs
        .map((d) => InventoryItem.fromMap(d.id, d.data()))
        .toList();
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    final items = await getAllInventoryItems();
    return items.where((item) => item.isLowStock).toList();
  }

  // Precomputed analytics support
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPrecomputedAnalytics(String dateKey) {
    return _db
        .collection('businesses')
        .doc(_businessId)
        .collection('analytics')
        .doc(dateKey)
        .snapshots();
  }

  /// Saves a snapshot of current metrics for historical tracking
  Future<void> saveHistoricalSnapshot(String dateKey, Map<String, dynamic> data) async {
    await _db
        .collection('businesses')
        .doc(_businessId)
        .collection('analytics')
        .doc(dateKey)
        .set({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  /// Fetches a time-series of specific metrics for trend analysis
  Future<List<Map<String, dynamic>>> getMetricHistory(String metricKey, int limit) async {
    final snap = await _db
        .collection('businesses')
        .doc(_businessId)
        .collection('analytics')
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
        
    return snap.docs.map((d) => d.data()).toList();
  }
}
