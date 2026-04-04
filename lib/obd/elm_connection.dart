import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Manages the Bluetooth RFCOMM connection to an ELM327 adapter.
class ElmConnection {
  BluetoothConnection? _connection;

  bool get isConnected => _connection?.isConnected ?? false;

  final _responseBuffer = StringBuffer();
  final _responseCompleter = <Completer<String>>[];

  /// Connect to the given Bluetooth device.
  Future<void> connect(BluetoothDevice device) async {
    await disconnect();
    _connection = await BluetoothConnection.toAddress(device.address);

    // Listen for incoming data
    _connection!.input?.listen(
      (Uint8List data) {
        final chunk = ascii.decode(data);
        _responseBuffer.write(chunk);

        // Check if we received the prompt character
        if (chunk.contains('>')) {
          final response = _responseBuffer.toString();
          _responseBuffer.clear();
          if (_responseCompleter.isNotEmpty) {
            _responseCompleter.removeAt(0).complete(response);
          }
        }
      },
      onDone: () {
        _connection = null;
      },
    );
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
    _responseBuffer.clear();
    for (final c in _responseCompleter) {
      c.completeError(Exception('Disconnected'));
    }
    _responseCompleter.clear();
  }

  /// Send a command and wait for the response (until '>' prompt).
  Future<String> sendCommand(String command, {Duration? timeout}) async {
    if (!isConnected) throw Exception('Not connected');

    final completer = Completer<String>();
    _responseCompleter.add(completer);

    _connection!.output.add(Uint8List.fromList(ascii.encode(command)));
    await _connection!.output.allSent;

    final effectiveTimeout = timeout ?? const Duration(seconds: 3);
    return completer.future.timeout(
      effectiveTimeout,
      onTimeout: () {
        _responseCompleter.remove(completer);
        final partial = _responseBuffer.toString();
        _responseBuffer.clear();
        return partial;
      },
    );
  }
}
