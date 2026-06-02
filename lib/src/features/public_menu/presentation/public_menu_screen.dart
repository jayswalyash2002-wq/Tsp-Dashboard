import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/public_menu_providers.dart';
import 'widgets/public_category_section.dart';

class PublicMenuScreen extends ConsumerWidget {
  final String businessId;
  final String? table;

  const PublicMenuScreen({
    super.key,
    required this.businessId,
    this.table,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessAsync = ref.watch(publicBusinessProvider(businessId));
    final categoriesAsync = ref.watch(publicCategoriesProvider(businessId));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: businessAsync.when(
          data: (biz) => Text(
            biz?.businessName ?? 'Menu',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Menu'),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'This business has no menu categories.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) => PublicCategorySection(
              businessId: businessId,
              category: categories[index],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Failed to load menu: $err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
