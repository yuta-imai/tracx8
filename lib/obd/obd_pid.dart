import 'dart:typed_data';

/// Supported OBD-II Mode 01 PIDs with parsing logic.
/// Formulas follow SAE J1979 standard.
enum ObdPid {
  engineRpm(
    code: 0x0C,
    label: 'Engine RPM',
    unit: 'rpm',
    responseBytes: 2,
  ),
  vehicleSpeed(
    code: 0x0D,
    label: 'Vehicle Speed',
    unit: 'km/h',
    responseBytes: 1,
  ),
  throttlePosition(
    code: 0x11,
    label: 'Throttle Position',
    unit: '%',
    responseBytes: 1,
  ),
  coolantTemp(
    code: 0x05,
    label: 'Coolant Temp',
    unit: '\u00b0C',
    responseBytes: 1,
  ),
  mafFlow(
    code: 0x10,
    label: 'MAF Air Flow',
    unit: 'g/s',
    responseBytes: 2,
  );

  const ObdPid({
    required this.code,
    required this.label,
    required this.unit,
    required this.responseBytes,
  });

  final int code;
  final String label;
  final String unit;
  final int responseBytes;

  /// Format the OBD-II request command (e.g. "01 0C\r")
  String get requestCommand =>
      '01 ${code.toRadixString(16).padLeft(2, '0').toUpperCase()}\r';

  /// Expected response prefix (e.g. "410C")
  String get responsePrefix =>
      '41${code.toRadixString(16).padLeft(2, '0').toUpperCase()}';

  /// Parse response data bytes into a human-readable value.
  double parse(Uint8List bytes) {
    return switch (this) {
      ObdPid.engineRpm => (256.0 * bytes[0] + bytes[1]) / 4.0,
      ObdPid.vehicleSpeed => bytes[0].toDouble(),
      ObdPid.throttlePosition => 100.0 / 255.0 * bytes[0],
      ObdPid.coolantTemp => bytes[0] - 40.0,
      ObdPid.mafFlow => (256.0 * bytes[0] + bytes[1]) / 100.0,
    };
  }

  static ObdPid? fromCode(int code) {
    for (final pid in values) {
      if (pid.code == code) return pid;
    }
    return null;
  }
}
