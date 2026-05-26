import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/analytics_models.dart';

class ExpensePieChart extends StatelessWidget {
  final List<CategoryData> data;

  const ExpensePieChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return const Center(child: Text('No expenses recorded'));
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              startDegreeOffset: -90,
              sections: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return PieChartSectionData(
                  color: item.color ?? _getColor(index, theme),
                  value: item.value,
                  title: item.value > 5 ? '${item.value.toStringAsFixed(0)}%' : '',
                  radius: 35,
                  titleStyle: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: item.color ?? _getColor(index, theme),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.category,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: theme.hintColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
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
