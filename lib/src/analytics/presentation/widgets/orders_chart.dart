import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/analytics_models.dart';

class OrdersChart extends StatelessWidget {
  final List<ChartDataPoint> data;

  const OrdersChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 40, color: theme.hintColor.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text('No order data yet', style: TextStyle(color: theme.hintColor)),
          ],
        ),
      );
    }

    final maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final limit = maxVal == 0 ? 10.0 : maxVal * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: limit,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => theme.colorScheme.surface,
            tooltipRoundedRadius: 8,
            tooltipBorder: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.round()} orders',
                theme.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                if (data.length > 12 && index % 3 != 0) return const SizedBox.shrink();
                
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    data[index].label ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 8,
                      color: theme.hintColor.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              reservedSize: 24,
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          final isPeak = e.value.value == maxVal && maxVal > 0;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: isPeak ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.3),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: limit,
                  color: theme.dividerColor.withOpacity(0.04),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
