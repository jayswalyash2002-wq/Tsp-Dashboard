import 'package:flutter/material.dart';
import '../../domain/analytics_models.dart';

class StaffPerformanceTable extends StatelessWidget {
  final List<StaffPerformanceMetric> metrics;

  const StaffPerformanceTable({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (metrics.isEmpty) {
      return const Center(child: Text('No staff activity data available'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        headingTextStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.hintColor),
        columns: const [
          DataColumn(label: Text('Staff Member')),
          DataColumn(label: Text('Orders')),
          DataColumn(label: Text('Revenue')),
          DataColumn(label: Text('Cancellations')),
          DataColumn(label: Text('Efficiency')),
        ],
        rows: metrics.map((m) => DataRow(
          cells: [
            DataCell(
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(m.staffEmail, style: TextStyle(fontSize: 10, color: theme.hintColor)),
                ],
              ),
            ),
            DataCell(Text(m.ordersHandled.toString())),
            DataCell(Text('₹${(m.revenueGeneratedPaise / 100).toStringAsFixed(0)}')),
            DataCell(Text(m.cancellations.toString(), style: TextStyle(color: m.cancellations > 2 ? Colors.red : null))),
            DataCell(
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: Colors.orange.shade400),
                  const SizedBox(width: 4),
                  Text(m.efficiencyRating.toStringAsFixed(1)),
                ],
              ),
            ),
          ],
        )).toList(),
      ),
    );
  }
}
