import 'dart:math';

import 'elm_device.dart';

/// Simulated ELM327 device for development without real hardware.
///
/// Generates realistic OBD-II responses with slowly drifting values
/// that mimic a car driving in the city.
class FakeElmDevice implements ElmDevice {
  bool _connected = false;
  final _random = Random();

  // Simulated vehicle state
  double _rpm = 800.0;
  double _speedKmh = 0.0;
  double _throttlePct = 0.0;
  double _coolantC = 70.0;
  double _mafGs = 2.5;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connectToAddress(String address) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<String> sendCommand(String command, {Duration? timeout}) async {
    if (!_connected) throw Exception('Not connected');

    // Simulate ELM327 response delay
    await Future.delayed(
      Duration(milliseconds: 30 + _random.nextInt(50)),
    );

    final cmd = command.trim().toUpperCase();

    // AT commands
    if (cmd.startsWith('AT')) {
      return _handleAtCommand(cmd);
    }

    // OBD-II Mode 01 commands
    if (cmd.startsWith('01')) {
      return _handleMode01(cmd);
    }

    return 'NO DATA\r\r>';
  }

  String _handleAtCommand(String cmd) {
    return switch (cmd) {
      'ATZ' => 'ELM327 v1.5 (FAKE)\r\r>',
      'ATE0' => 'OK\r\r>',
      'ATL0' => 'OK\r\r>',
      'ATS0' => 'OK\r\r>',
      'ATH0' => 'OK\r\r>',
      'ATSP0' => 'OK\r\r>',
      _ => 'OK\r\r>',
    };
  }

  String _handleMode01(String cmd) {
    // Parse the PID hex from "01 XX" or "01XX"
    final cleaned = cmd.replaceAll(' ', '');
    if (cleaned.length < 4) return 'NO DATA\r\r>';

    final pidHex = cleaned.substring(2, 4);
    final pidCode = int.tryParse(pidHex, radix: 16);
    if (pidCode == null) return 'NO DATA\r\r>';

    _tickSimulation();

    return switch (pidCode) {
      0x0C => _encodeRpm(),
      0x0D => _encodeSpeed(),
      0x11 => _encodeThrottle(),
      0x05 => _encodeCoolant(),
      0x10 => _encodeMaf(),
      0x2F => _encodeFuelLevel(),
      _ => 'NO DATA\r\r>',
    };
  }

  /// Advance the simulated vehicle state by one tick.
  void _tickSimulation() {
    // Throttle wanders: city-driving style
    _throttlePct += (_random.nextDouble() - 0.45) * 8.0;
    _throttlePct = _throttlePct.clamp(0.0, 80.0);

    // RPM follows throttle
    final targetRpm = 800.0 + _throttlePct * 50.0;
    _rpm += (targetRpm - _rpm) * 0.3 + (_random.nextDouble() - 0.5) * 40.0;
    _rpm = _rpm.clamp(600.0, 6500.0);

    // Speed follows RPM/throttle
    final targetSpeed = _throttlePct * 1.5;
    _speedKmh += (targetSpeed - _speedKmh) * 0.15;
    _speedKmh = _speedKmh.clamp(0.0, 180.0);

    // Coolant slowly warms up to ~90 °C
    if (_coolantC < 90.0) {
      _coolantC += 0.05;
    }
    _coolantC += (_random.nextDouble() - 0.5) * 0.2;
    _coolantC = _coolantC.clamp(60.0, 105.0);

    // MAF correlates with RPM
    _mafGs = _rpm / 800.0 * 2.5 + (_random.nextDouble() - 0.5) * 0.5;
    _mafGs = _mafGs.clamp(0.5, 25.0);
  }

  // --- Encoders: produce ELM327-format response strings ---

  String _encodeRpm() {
    // RPM = (256*A + B) / 4  →  encoded = RPM * 4
    final encoded = (_rpm * 4.0).round().clamp(0, 0xFFFF);
    final a = (encoded >> 8) & 0xFF;
    final b = encoded & 0xFF;
    return '410C${_hex(a)}${_hex(b)}\r\r>';
  }

  String _encodeSpeed() {
    final a = _speedKmh.round().clamp(0, 255);
    return '410D${_hex(a)}\r\r>';
  }

  String _encodeThrottle() {
    // Throttle = A * 100 / 255  →  A = throttle * 255 / 100
    final a = (_throttlePct * 255.0 / 100.0).round().clamp(0, 255);
    return '4111${_hex(a)}\r\r>';
  }

  String _encodeCoolant() {
    // Coolant = A - 40  →  A = coolant + 40
    final a = (_coolantC + 40.0).round().clamp(0, 255);
    return '4105${_hex(a)}\r\r>';
  }

  String _encodeMaf() {
    // MAF = (256*A + B) / 100  →  encoded = MAF * 100
    final encoded = (_mafGs * 100.0).round().clamp(0, 0xFFFF);
    final a = (encoded >> 8) & 0xFF;
    final b = encoded & 0xFF;
    return '4110${_hex(a)}${_hex(b)}\r\r>';
  }

  String _encodeFuelLevel() {
    // Fuel level = A * 100 / 255 (percent)
    // Simulate ~65% fuel
    const fuelPct = 65.0;
    final a = (fuelPct * 255.0 / 100.0).round().clamp(0, 255);
    return '412F${_hex(a)}\r\r>';
  }

  static String _hex(int byte) =>
      byte.toRadixString(16).padLeft(2, '0').toUpperCase();
}
