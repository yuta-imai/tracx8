import 'dart:typed_data';

import 'obd_pid.dart';

/// Handles encoding/decoding of ELM327 AT commands and OBD-II PID requests.
/// Pure functions — no platform dependencies, fully unit-testable.
class ElmProtocol {
  ElmProtocol._();

  /// Initialization commands sent after connecting to the ELM327.
  static const List<String> initCommands = [
    'ATZ\r', // Reset
    'ATE0\r', // Echo off
    'ATL0\r', // Linefeeds off
    'ATS0\r', // Spaces off
    'ATH0\r', // Headers off
    'ATSP0\r', // Auto-detect protocol
  ];

  /// Parse a raw ELM327 response string for a given PID.
  /// Returns the parsed value, or null if the response is invalid.
  ///
  /// Example (spaces-off): "410C1AF8" → RPM
  static double? parseResponse(ObdPid pid, String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase().trim();

    // Check for error / no-data responses
    if (cleaned.contains('NODATA') ||
        cleaned.contains('ERROR') ||
        cleaned.contains('UNABLE') ||
        cleaned.contains('STOPPED') ||
        cleaned.contains('?')) {
      return null;
    }

    final prefix = pid.responsePrefix;
    final prefixIndex = cleaned.indexOf(prefix);
    if (prefixIndex < 0) return null;

    final dataStart = prefixIndex + prefix.length;
    final expectedHexChars = pid.responseBytes * 2;
    if (cleaned.length < dataStart + expectedHexChars) return null;

    final hexData = cleaned.substring(dataStart, dataStart + expectedHexChars);
    final bytes = hexStringToBytes(hexData);
    if (bytes == null) return null;

    return pid.parse(bytes);
  }

  /// Parse a hex string like "1AF8" into a Uint8List.
  static Uint8List? hexStringToBytes(String hex) {
    if (hex.length % 2 != 0) return null;
    try {
      final bytes = Uint8List(hex.length ~/ 2);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Strip the ELM327 prompt character from a response.
  static String stripPrompt(String response) {
    return response.replaceAll('>', '').trim();
  }
}
