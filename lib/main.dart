import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'gps/gps_collector.dart';
import 'logging/csv_logger.dart';
import 'obd/obd_collector.dart';
import 'sensor/accel_collector.dart';
import 'ui/screens/connect_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TracxApp());
}

class TracxApp extends StatelessWidget {
  const TracxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ObdCollector()),
        ChangeNotifierProvider(create: (ctx) => GpsCollector()),
        ChangeNotifierProvider(create: (_) => AccelCollector()),
        ChangeNotifierProvider(create: (_) => CsvLogger()),
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
