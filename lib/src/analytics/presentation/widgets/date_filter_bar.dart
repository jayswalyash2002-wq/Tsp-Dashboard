import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/analytics_providers.dart';
import '../../domain/analytics_models.dart';

class DateFilterBar extends ConsumerWidget {
  const DateFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(analyticsDateRangeProvider);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AnalyticsDateRange.values.map((range) {
          final isSelected = selectedRange == range;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(range.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(analyticsDateRangeProvider.notifier).state = range;
                  if (range == AnalyticsDateRange.custom) {
                    _selectCustomRange(context, ref);
                  }
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectCustomRange(BuildContext context, WidgetRef ref) async {
    final initialRange = ref.read(analyticsCustomDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialRange,
    );
    
    if (picked != null) {
      ref.read(analyticsCustomDateRangeProvider.notifier).state = picked;
    }
  }
}
