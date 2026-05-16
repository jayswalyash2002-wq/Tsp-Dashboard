import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/business_session.dart';

class SessionRepository {
  SessionRepository(this._db);
  final FirebaseFirestore _db;

  Stream<BusinessSession?> watchCurrentSession() {
    return _db
        .collection('sessions')
        .doc('current')
        .snapshots()
        .map((doc) => doc.exists ? BusinessSession.fromMap(doc.data()!) : null);
  }

  Future<void> openBusiness(String businessDate) async {
    await _db.collection('sessions').doc('current').set({
      'isOpen': true,
      'openedAt': FieldValue.serverTimestamp(),
      'closedAt': null,
      'businessDate': businessDate,
    });
  }

  Future<void> closeBusiness() async {
    await _db.collection('sessions').doc('current').update({
      'isOpen': false,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }
}
