import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

import '../../obd/fake_elm_device.dart';
import '../../obd/obd_collector.dart';

/// Screen for selecting and connecting to an ELM327 Bluetooth device.
///
/// When the injected [ElmDevice] is a [FakeElmDevice], a single
/// "Fake ELM327" entry is shown instead of scanning for real hardware.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.onConnected});

  final VoidCallback onConnected;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  List<BluetoothDevice> _pairedDevices = [];
  bool _loading = true;
  String? _error;
  bool _isFakeMode = false;

  @override
  void initState() {
    super.initState();
    _detectMode();
  }

  void _detectMode() {
    final obd = context.read<ObdCollector>();
    _isFakeMode = obd.device is FakeElmDevice;
    if (_isFakeMode) {
      setState(() => _loading = false);
    } else {
      _loadPairedDevices();
    }
  }

  Future<void> _loadPairedDevices() async {
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _pairedDevices = devices;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _connectToDevice(String address) async {
    final obd = context.read<ObdCollector>();

    setState(() => _error = null);

    try {
      await obd.connect(address);
      widget.onConnected();
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFakeMode ? 'Connect (Fake Mode)' : 'Connect to ELM327'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  if (_isFakeMode) {
                    setState(() => _loading = false);
                  } else {
                    _loadPairedDevices();
                  }
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Fake mode: show a single simulated device
    if (_isFakeMode) {
      return _buildFakeDeviceList();
    }

    // Real mode: show paired BT devices
    return _buildBluetoothDeviceList();
  }

  Widget _buildFakeDeviceList() {
    return Consumer<ObdCollector>(
      builder: (context, obd, _) {
        final isConnecting = obd.state == ObdConnectionState.connecting;

        return ListView(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha(76)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fake mode: No real Bluetooth hardware required. '
                      'Simulated OBD-II data will be generated.',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.developer_board, color: Colors.orange),
              title: const Text('Fake ELM327'),
              subtitle: const Text('Simulated device (no Bluetooth)'),
              trailing: isConnecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              enabled: !isConnecting,
              onTap: () => _connectToDevice('FAKE'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBluetoothDeviceList() {
    if (_pairedDevices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No paired Bluetooth devices found.\n'
            'Please pair your ELM327 adapter in Android Bluetooth settings first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Consumer<ObdCollector>(
      builder: (context, obd, _) {
        final isConnecting = obd.state == ObdConnectionState.connecting;

        return ListView.builder(
          itemCount: _pairedDevices.length,
          itemBuilder: (context, index) {
            final device = _pairedDevices[index];
            return ListTile(
              leading: const Icon(Icons.bluetooth),
              title: Text(device.name ?? 'Unknown Device'),
              subtitle: Text(device.address),
              trailing: isConnecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              enabled: !isConnecting,
              onTap: () => _connectToDevice(device.address),
            );
          },
        );
      },
    );
  }
}
