import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import 'elm_connection.dart';
import 'elm_protocol.dart';
import 'obd_pid.dart';

/// Connection state of the OBD collector.
enum ObdConnectionState { disconnected, connecting, connected, polling }

/// A snapshot of all OBD-II values at a point in time.
class ObdSnapshot {
  ObdSnapshot({
    required this.timestampMs,
    this.rpm,
    this.speedKmh,
    this.throttlePct,
    this.coolantTempC,
    this.mafGs,
  });

  final int timestampMs;
  final double? rpm;
  final double? speedKmh;
  final double? throttlePct;
  final double? coolantTempC;
  final double? mafGs;
}

/// Orchestrates OBD-II data collection by polling PIDs in a loop.
class ObdCollector extends ChangeNotifier {
  static const _pollPids = [
    ObdPid.engineRpm,
    ObdPid.vehicleSpeed,
    ObdPid.throttlePosition,
    ObdPid.coolantTemp,
    ObdPid.mafFlow,
  ];

  final ElmConnection _connection = ElmConnection();

  ObdConnectionState _state = ObdConnectionState.disconnected;
  ObdConnectionState get state => _state;

  ObdSnapshot? _latestSnapshot;
  ObdSnapshot? get latestSnapshot => _latestSnapshot;

  final _dataController = StreamController<ObdSnapshot>.broadcast();
  Stream<ObdSnapshot> get dataStream => _dataController.stream;

  bool _polling = false;

  /// Connect to an ELM327 device and initialize.
  Future<void> connect(BluetoothDevice device) async {
    _state = ObdConnectionState.connecting;
    notifyListeners();

    try {
      await _connection.connect(device);

      // Send initialization commands
      for (final cmd in ElmProtocol.initCommands) {
        await _connection.sendCommand(cmd, timeout: const Duration(seconds: 5));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _state = ObdConnectionState.connected;
      notifyListeners();
    } catch (e) {
      _state = ObdConnectionState.disconnected;
      notifyListeners();
      rethrow;
    }
  }

  /// Disconnect from the ELM327.
  Future<void> disconnect() async {
    _polling = false;
    await _connection.disconnect();
    _state = ObdConnectionState.disconnected;
    notifyListeners();
  }

  /// Start the polling loop. Returns when polling is stopped or connection lost.
  Future<void> startPolling() async {
    _polling = true;
    _state = ObdConnectionState.polling;
    notifyListeners();

    final values = <ObdPid, double>{};

    while (_polling && _connection.isConnected) {
      for (final pid in _pollPids) {
        if (!_polling || !_connection.isConnected) break;

        try {
          final raw = await _connection.sendCommand(pid.requestCommand);
          final cleaned = ElmProtocol.stripPrompt(raw);
          final value = ElmProtocol.parseResponse(pid, cleaned);
          if (value != null) {
            values[pid] = value;
          }
        } catch (e) {
          debugPrint('OBD query failed for ${pid.label}: $e');
        }
      }

      // Emit snapshot after each full cycle
      final snapshot = ObdSnapshot(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        rpm: values[ObdPid.engineRpm],
        speedKmh: values[ObdPid.vehicleSpeed],
        throttlePct: values[ObdPid.throttlePosition],
        coolantTempC: values[ObdPid.coolantTemp],
        mafGs: values[ObdPid.mafFlow],
      );
      _latestSnapshot = snapshot;
      _dataController.add(snapshot);
      notifyListeners();
    }

    _state = _connection.isConnected
        ? ObdConnectionState.connected
        : ObdConnectionState.disconnected;
    notifyListeners();
  }

  /// Stop polling.
  void stopPolling() {
    _polling = false;
  }

  @override
  void dispose() {
    _polling = false;
    _connection.disconnect();
    _dataController.close();
    super.dispose();
  }
}
