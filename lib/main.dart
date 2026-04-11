import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/data_uploader.dart';
import 'gps/gps_collector.dart';
import 'logging/csv_logger.dart';
import 'obd/elm_connection.dart';
import 'obd/elm_device.dart';
import 'obd/fake_elm_device.dart';
import 'obd/obd_collector.dart';
import 'sensor/accel_collector.dart';
import 'ui/screens/connect_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/theme/app_theme.dart';

/// Set to `true` to use the simulated ELM327 device.
/// Flip to `false` when real Bluetooth hardware is available.
const bool useFakeDevice = true;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TracxApp());
}

class TracxApp extends StatelessWidget {
  const TracxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ElmDevice elmDevice =
        useFakeDevice ? FakeElmDevice() : BluetoothElmDevice();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ObdCollector(device: elmDevice),
        ),
        ChangeNotifierProvider(create: (_) => GpsCollector()),
        ChangeNotifierProvider(create: (_) => AccelCollector()),
        ChangeNotifierProvider(create: (_) => CsvLogger()),
        ChangeNotifierProvider(create: (_) => DataUploader()),
      ],
      child: MaterialApp(
        title: 'Tracx8',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const _AppShell(),
      ),
    );
  }
}

/// Simple shell that switches between Connect and Dashboard screens.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    if (_connected) {
      return DashboardScreen(
        onDisconnect: () => setState(() => _connected = false),
      );
    }
    return ConnectScreen(
      onConnected: () => setState(() => _connected = true),
    );
  }
}
