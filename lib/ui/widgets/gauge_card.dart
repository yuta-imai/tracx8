import 'package:flutter/material.dart';

/// A card displaying a single gauge value with label and unit.
class GaugeCard extends StatelessWidget {
  const GaugeCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.decimals = 1,
    this.valueColor,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimals;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final displayValue =
        value != null ? value!.toStringAsFixed(decimals) : '--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  displayValue,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: valueColor ?? Colors.tealAccent,
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
