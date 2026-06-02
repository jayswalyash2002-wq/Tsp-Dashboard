import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../business/domain/business.dart';
import '../domain/public_menu_models.dart';

/// Fetches the business document for the public menu.
/// Uses [keepAlive: true] (default for non-autoDispose providers).
final publicBusinessProvider = FutureProvider.family<Business?, String>((ref, businessId) async {
  final firestore = ref.watch(firestoreProvider);
  final doc = await firestore.collection('businesses').doc(businessId).get();
  if (!doc.exists) return null;
  return Business.fromMap(doc.data()!, doc.id);
});

/// Fetches all categories for a business.
final publicCategoriesProvider = FutureProvider.family<List<PublicCategory>, String>((ref, businessId) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection('businesses')
      .doc(businessId)
      .collection('categories')
      .orderBy('orderIndex')
      .get();
  return snapshot.docs.map((doc) => PublicCategory.fromFirestore(doc.id, doc.data())).toList();
});

/// Arguments for [publicProductsProvider].
class PublicProductsArgs {
  final String businessId;
  final String categoryId;
  PublicProductsArgs({required this.businessId, required this.categoryId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicProductsArgs &&
          runtimeType == other.runtimeType &&
          businessId == other.businessId &&
          categoryId == other.categoryId;

  @override
  int get hashCode => businessId.hashCode ^ categoryId.hashCode;
}

/// Fetches all products under a category.
final publicProductsProvider = FutureProvider.family<List<PublicProduct>, PublicProductsArgs>((ref, args) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection('businesses')
      .doc(args.businessId)
      .collection('categories')
      .doc(args.categoryId)
      .collection('products')
      .get();
  return snapshot.docs.map((doc) => PublicProduct.fromFirestore(doc.id, doc.data())).toList();
});
