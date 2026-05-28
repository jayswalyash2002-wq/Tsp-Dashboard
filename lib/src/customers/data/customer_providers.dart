import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../business/data/business_providers.dart';
import '../../core/firebase/firebase_providers.dart';
import 'customer_repository.dart';
import '../domain/customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository?>((ref) {
  final db = ref.watch(firestoreProvider);
  final businessId = ref.watch(currentBusinessProvider).value?.id;
  if (businessId == null) return null;
  return CustomerRepository(db: db, businessId: businessId);
});

final customerSearchProvider = FutureProvider.family<Customer?, String>((ref, phone) async {
  if (phone.length < 10) return null; // Basic optimization
  
  final repo = ref.watch(customerRepositoryProvider);
  if (repo == null) return null;

  // Debounce logic inside the provider isn't ideal for UI feedback,
  // but we can use it to avoid duplicate calls.
  return repo.getCustomerByPhone(phone);
});

final customerSuggestionsProvider = FutureProvider.family<List<Customer>, String>((ref, query) async {
  if (query.length < 3) return [];
  
  final repo = ref.watch(customerRepositoryProvider);
  if (repo == null) return [];

  return repo.searchCustomers(query);
});
