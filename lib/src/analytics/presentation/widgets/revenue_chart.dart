import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/analytics_models.dart';

class RevenueChart extends StatelessWidget {
  final List<ChartDataPoint> data;

  const RevenueChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.query_stats_rounded, size: 40, color: theme.hintColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No sales data yet', style: TextStyle(color: theme.hintColor)),
          ],
        ),
      );
    }

    final List<Color> gradientColors = [
      theme.colorScheme.primary,
      theme.colorScheme.primary.withValues(alpha: 0.0),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateYInterval(data),
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.05),
            strokeWidth: 1,
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
              reservedSize: 30,
              interval: _calculateInterval(data.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    DateFormat('d MMM').format(data[index].date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor.withValues(alpha: 0.7),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: _calculateMaxY(data),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.colorScheme.surface,
            tooltipRoundedRadius: 12,
            tooltipBorder: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '₹${(spot.y / 100).toStringAsFixed(0)}',
                  theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length < 15,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: theme.colorScheme.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors.map((color) => color.withValues(alpha: 0.15)).toList(),
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateInterval(int length) {
    if (length <= 7) return 1;
    if (length <= 14) return 2;
    return (length / 5).floorToDouble();
  }

  double _calculateMaxY(List<ChartDataPoint> data) {
    if (data.isEmpty) return 1000;
    final max = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return max == 0 ? 1000 : max * 1.2;
  }

  double _calculateYInterval(List<ChartDataPoint> data) {
    final max = _calculateMaxY(data);
    return max / 4;
  }
}
