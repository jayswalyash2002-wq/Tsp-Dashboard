import 'package:flutter/material.dart';

class HourlyHeatmap extends StatelessWidget {
  final Map<int, double> heatmap;
  final int startHour;

  const HourlyHeatmap({super.key, required this.heatmap, required this.startHour});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Sort hours starting from business start hour
    final sortedHours = List.generate(24, (i) => (i + startHour) % 24);

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            childAspectRatio: 1.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 24,
          itemBuilder: (context, index) {
            final hour = sortedHours[index];
            final intensity = heatmap[hour] ?? 0.0;
            
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05 + (intensity * 0.85)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: intensity > 0.5 ? theme.colorScheme.primary.withOpacity(0.3) : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${hour}h',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: intensity > 0.5 ? Colors.white : theme.hintColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (intensity > 0)
                    Text(
                      '${(intensity * 100).toInt()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: intensity > 0.5 ? Colors.white.withOpacity(0.9) : theme.hintColor.withOpacity(0.7),
                        fontSize: 7,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Low activity', style: theme.textTheme.labelSmall?.copyWith(fontSize: 8)),
            const SizedBox(width: 8),
            ...List.generate(5, (i) => Container(
              width: 12,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1 + (i * 0.2)),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(width: 8),
            Text('High activity', style: theme.textTheme.labelSmall?.copyWith(fontSize: 8)),
          ],
        ),
      ],
    );
  }
}
