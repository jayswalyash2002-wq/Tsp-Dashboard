import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/public_menu_providers.dart';
import '../../domain/public_menu_models.dart';
import 'public_product_card.dart';

class PublicCategorySection extends ConsumerWidget {
  final String businessId;
  final PublicCategory category;

  const PublicCategorySection({
    super.key,
    required this.businessId,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(publicProductsProvider(PublicProductsArgs(
      businessId: businessId,
      categoryId: category.id,
    )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            category.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        productsAsync.when(
          data: (products) {
            if (products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'No products available in this category.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (context, index) => PublicProductCard(product: products[index]),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Error loading products: $err'),
          ),
        ),
      ],
    );
  }
}
