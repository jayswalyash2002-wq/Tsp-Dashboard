import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/business_session.dart';

class SessionRepository {
  SessionRepository(this._db, this._businessId);
  final FirebaseFirestore _db;
  final String _businessId;

  Stream<BusinessSession?> watchCurrentSession() {
    return _db
        .collection('sessions')
        .doc(_businessId)
        .snapshots()
        .map((doc) => doc.exists ? BusinessSession.fromMap(doc.data()!) : null);
  }

  Future<void> openBusiness(String businessDate) async {
    await _db.collection('sessions').doc(_businessId).set({
      'businessId': _businessId,
      'isOpen': true,
      'openedAt': FieldValue.serverTimestamp(),
      'closedAt': null,
      'businessDate': businessDate,
    });
  }

  Future<void> closeBusiness() async {
    await _db.collection('sessions').doc(_businessId).update({
      'isOpen': false,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }
}
