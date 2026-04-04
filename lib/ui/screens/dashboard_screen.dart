import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../gps/gps_collector.dart';
import '../../logging/csv_logger.dart';
import '../../logging/log_row.dart';
import '../../obd/obd_collector.dart';
import '../../sensor/accel_collector.dart';
import '../widgets/gauge_card.dart';
import '../widgets/status_bar.dart';

/// Main dashboard showing real-time OBD/GPS/accel values and logging controls.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onDisconnect});

  final VoidCallback onDisconnect;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _logTimer;

  @override
  void initState() {
    super.initState();
    _startCollectors();
  }

  Future<void> _startCollectors() async {
    final obd = context.read<ObdCollector>();
    final gps = context.read<GpsCollector>();
    final accel = context.read<AccelCollector>();

    // Start OBD polling
    obd.startPolling();

    // Start GPS
    try {
      await gps.start();
    } catch (e) {
      debugPrint('GPS start failed: $e');
    }

    // Start accelerometer
    accel.start();
  }

  void _toggleLogging() async {
    final logger = context.read<CsvLogger>();

    if (logger.isLogging) {
      _logTimer?.cancel();
      _logTimer = null;
      await logger.stopSession();
    } else {
      await logger.startSession();
      // Log at ~1 Hz by merging latest data from all sources
      _logTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final obd = context.read<ObdCollector>();
        final gps = context.read<GpsCollector>();
        final accel = context.read<AccelCollector>();

        final row = LogRow.merge(
          obd: obd.latestSnapshot,
          gps: gps.latest,
          accel: accel.latest,
        );
        logger.log(row);
      });
    }
    setState(() {});
  }

  Future<void> _disconnect() async {
    _logTimer?.cancel();
    final obd = context.read<ObdCollector>();
    final gps = context.read<GpsCollector>();
    final accel = context.read<AccelCollector>();
    final logger = context.read<CsvLogger>();

    obd.stopPolling();
    gps.stop();
    accel.stop();
    await logger.stopSession();
    await obd.disconnect();
    widget.onDisconnect();
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracx8'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Disconnect',
            onPressed: _disconnect,
          ),
        ],
      ),
      body: Consumer4<ObdCollector, GpsCollector, AccelCollector, CsvLogger>(
        builder: (context, obd, gps, accel, logger, _) {
          final snap = obd.latestSnapshot;
          final gpsData = gps.latest;
          final accelData = accel.latest;

          return Column(
            children: [
              StatusBar(
                obdState: obd.state,
                gpsActive: gps.isActive,
                logger: logger,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // OBD gauges
                      _sectionLabel('OBD-II'),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          GaugeCard(
                            label: 'RPM',
                            value: snap?.rpm,
                            unit: 'rpm',
                            decimals: 0,
                          ),
                          GaugeCard(
                            label: 'Speed',
                            value: snap?.speedKmh,
                            unit: 'km/h',
                            decimals: 0,
                          ),
                          GaugeCard(
                            label: 'Throttle',
                            value: snap?.throttlePct,
                            unit: '%',
                          ),
                          GaugeCard(
                            label: 'Coolant',
                            value: snap?.coolantTempC,
                            unit: '\u00b0C',
                            decimals: 0,
                          ),
                          GaugeCard(
                            label: 'MAF',
                            value: snap?.mafGs,
                            unit: 'g/s',
                          ),
                          GaugeCard(
                            label: 'Fuel',
                            value: _estimateFuelConsumption(snap),
                            unit: 'km/L',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // GPS
                      _sectionLabel('GPS'),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          GaugeCard(
                            label: 'Latitude',
                            value: gpsData?.latitude,
                            unit: '\u00b0',
                            decimals: 6,
                            valueColor: Colors.lightBlueAccent,
                          ),
                          GaugeCard(
                            label: 'Longitude',
                            value: gpsData?.longitude,
                            unit: '\u00b0',
                            decimals: 6,
                            valueColor: Colors.lightBlueAccent,
                          ),
                          GaugeCard(
                            label: 'Altitude',
                            value: gpsData?.altitudeM,
                            unit: 'm',
                            decimals: 1,
                            valueColor: Colors.lightBlueAccent,
                          ),
                          GaugeCard(
                            label: 'GPS Speed',
                            value: gpsData?.speedMs != null
                                ? gpsData!.speedMs! * 3.6
                                : null,
                            unit: 'km/h',
                            decimals: 1,
                            valueColor: Colors.lightBlueAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Accelerometer
                      _sectionLabel('Accelerometer'),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          GaugeCard(
                            label: 'X',
                            value: accelData?.x,
                            unit: 'm/s\u00b2',
                            decimals: 2,
                            valueColor: Colors.amberAccent,
                          ),
                          GaugeCard(
                            label: 'Y',
                            value: accelData?.y,
                            unit: 'm/s\u00b2',
                            decimals: 2,
                            valueColor: Colors.amberAccent,
                          ),
                          GaugeCard(
                            label: 'Z',
                            value: accelData?.z,
                            unit: 'm/s\u00b2',
                            decimals: 2,
                            valueColor: Colors.amberAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<CsvLogger>(
        builder: (context, logger, _) {
          return FloatingActionButton.extended(
            onPressed: _toggleLogging,
            icon: Icon(logger.isLogging ? Icons.stop : Icons.fiber_manual_record),
            label: Text(logger.isLogging ? 'Stop Logging' : 'Start Logging'),
            backgroundColor: logger.isLogging ? Colors.red : Colors.teal,
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey[500],
            ),
      ),
    );
  }

  /// Estimate fuel consumption in km/L from MAF and speed.
  /// Formula: km/L = (speed * 1000) / (MAF * 3600 / airFuelRatio / fuelDensity)
  /// Simplified: km/L = speed / (MAF * 0.3348) for gasoline
  double? _estimateFuelConsumption(ObdSnapshot? snap) {
    if (snap == null) return null;
    final speed = snap.speedKmh;
    final maf = snap.mafGs;
    if (speed == null || maf == null || maf <= 0 || speed <= 0) return null;

    // Gasoline: AFR ~14.7, density ~0.755 kg/L
    // Fuel flow (L/h) = MAF(g/s) * 3600 / (14.7 * 755) ≈ MAF * 0.3244
    // km/L = speed(km/h) / fuelFlow(L/h)
    final fuelFlowLph = maf * 3600.0 / (14.7 * 755.0);
    return speed / fuelFlowLph;
  }
}
