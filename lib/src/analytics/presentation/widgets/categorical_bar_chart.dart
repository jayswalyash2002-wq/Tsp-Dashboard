import 'package:flutter/material.dart';
import '../../domain/analytics_models.dart';

class CategoricalBarChart extends StatelessWidget {
  final List<CategoryData> data;
  final String suffix;
  final bool isCurrency;

  const CategoricalBarChart({
    super.key,
    required this.data,
    this.suffix = '',
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final total = data.fold<double>(0, (sum, item) => sum + item.value);

    return Column(
      children: data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.category,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    isCurrency 
                      ? '₹${(item.count! / 100).toStringAsFixed(0)}' 
                      : '${item.count}$suffix',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(
                      height: 5,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.05),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (item.value / 100).clamp(0.0, 1.0),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: item.color ?? _getColor(index, theme),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getColor(int index, ThemeData theme) {
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.orange,
      Colors.teal,
      Colors.purple,
    ];
    return colors[index % colors.length];
  }
}
