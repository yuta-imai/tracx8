import 'package:flutter/material.dart';

import '../../logging/csv_logger.dart';
import '../../obd/obd_collector.dart';

/// Status indicators for OBD connection and logging state.
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.obdState,
    required this.gpsActive,
    required this.logger,
  });

  final ObdConnectionState obdState;
  final bool gpsActive;
  final CsvLogger logger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _indicator(
            label: 'OBD',
            color: switch (obdState) {
              ObdConnectionState.disconnected => Colors.red,
              ObdConnectionState.connecting => Colors.orange,
              ObdConnectionState.connected => Colors.yellow,
              ObdConnectionState.polling => Colors.green,
            },
          ),
          const SizedBox(width: 16),
          _indicator(
            label: 'GPS',
            color: gpsActive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
          _indicator(
            label: 'LOG',
            color: logger.isLogging ? Colors.green : Colors.grey,
          ),
          if (logger.isLogging) ...[
            const SizedBox(width: 8),
            Text(
              '${logger.rowCount} rows',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _indicator({required String label, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
