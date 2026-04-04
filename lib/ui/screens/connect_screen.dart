import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:provider/provider.dart';

import '../../obd/obd_collector.dart';

/// Screen for selecting and connecting to an ELM327 Bluetooth device.
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

  @override
  void initState() {
    super.initState();
    _loadPairedDevices();
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

  Future<void> _connectToDevice(BluetoothDevice device) async {
    final obd = context.read<ObdCollector>();

    setState(() => _error = null);

    try {
      await obd.connect(device);
      widget.onConnected();
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to ELM327')),
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
                  _loadPairedDevices();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

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
              onTap: () => _connectToDevice(device),
            );
          },
        );
      },
    );
  }
}
