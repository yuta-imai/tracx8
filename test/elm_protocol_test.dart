import 'package:flutter_test/flutter_test.dart';
import 'package:tracx8/obd/elm_protocol.dart';
import 'package:tracx8/obd/obd_pid.dart';

void main() {
  group('ElmProtocol.parseResponse', () {
    test('parses RPM response correctly', () {
      // 0x1AF8 → (256*0x1A + 0xF8) / 4 = (256*26 + 248) / 4 = 6904/4 = 1726
      final result = ElmProtocol.parseResponse(ObdPid.engineRpm, '410C1AF8');
      expect(result, closeTo(1726.0, 0.1));
    });

    test('parses RPM with spaces', () {
      final result =
          ElmProtocol.parseResponse(ObdPid.engineRpm, '41 0C 1A F8');
      expect(result, closeTo(1726.0, 0.1));
    });

    test('parses vehicle speed', () {
      // 0x3C = 60 km/h
      final result =
          ElmProtocol.parseResponse(ObdPid.vehicleSpeed, '410D3C');
      expect(result, 60.0);
    });

    test('parses throttle position', () {
      // 0x80 = 128 → 100/255*128 ≈ 50.2%
      final result =
          ElmProtocol.parseResponse(ObdPid.throttlePosition, '411180');
      expect(result, closeTo(50.2, 0.1));
    });

    test('parses coolant temp', () {
      // 0x6E = 110 → 110-40 = 70°C
      final result =
          ElmProtocol.parseResponse(ObdPid.coolantTemp, '41056E');
      expect(result, 70.0);
    });

    test('parses MAF flow', () {
      // 0x0190 = 400 → 400/100 = 4.0 g/s
      final result =
          ElmProtocol.parseResponse(ObdPid.mafFlow, '41100190');
      expect(result, 4.0);
    });

    test('returns null for NO DATA', () {
      final result =
          ElmProtocol.parseResponse(ObdPid.engineRpm, 'NO DATA');
      expect(result, isNull);
    });

    test('returns null for invalid response', () {
      final result =
          ElmProtocol.parseResponse(ObdPid.engineRpm, 'GARBAGE');
      expect(result, isNull);
    });
  });

  group('ElmProtocol.hexStringToBytes', () {
    test('parses valid hex', () {
      final bytes = ElmProtocol.hexStringToBytes('1AF8');
      expect(bytes, isNotNull);
      expect(bytes!.length, 2);
      expect(bytes[0], 0x1A);
      expect(bytes[1], 0xF8);
    });

    test('returns null for odd-length hex', () {
      expect(ElmProtocol.hexStringToBytes('1AF'), isNull);
    });
  });
}
