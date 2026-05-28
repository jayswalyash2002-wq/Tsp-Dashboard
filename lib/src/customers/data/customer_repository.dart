import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/customer.dart';

class CustomerRepository {
  final FirebaseFirestore _db;
  final String _businessId;

  CustomerRepository({
    required FirebaseFirestore db,
    required String businessId,
  })  : _db = db,
        _businessId = businessId;

  Future<Customer?> getCustomerByPhone(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) return null;

    final doc = await _db
        .collection('businesses')
        .doc(_businessId)
        .collection('customers')
        .doc(normalized)
        .get();

    if (!doc.exists) return null;
    return Customer.fromMap(doc.id, doc.data()!);
  }

  Future<List<Customer>> searchCustomers(String query, {int limit = 5}) async {
    final normalized = query.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.length < 3) return [];

    final snap = await _db
        .collection('businesses')
        .doc(_businessId)
        .collection('customers')
        .where('phone', isGreaterThanOrEqualTo: normalized)
        .where('phone', isLessThanOrEqualTo: '$normalized\uf8ff')
        .limit(limit)
        .get();

    return snap.docs.map((doc) => Customer.fromMap(doc.id, doc.data())).toList();
  }
}
