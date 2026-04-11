import 'package:flutter_test/flutter_test.dart';
import 'package:tracx8/obd/elm_protocol.dart';
import 'package:tracx8/obd/fake_elm_device.dart';
import 'package:tracx8/obd/obd_pid.dart';

void main() {
  late FakeElmDevice device;

  setUp(() {
    device = FakeElmDevice();
  });

  group('FakeElmDevice connection', () {
    test('starts disconnected', () {
      expect(device.isConnected, isFalse);
    });

    test('connects and disconnects', () async {
      await device.connectToAddress('FAKE');
      expect(device.isConnected, isTrue);

      await device.disconnect();
      expect(device.isConnected, isFalse);
    });

    test('sendCommand throws when not connected', () {
      expect(() => device.sendCommand('ATZ\r'), throwsException);
    });
  });

  group('FakeElmDevice AT commands', () {
    setUp(() async {
      await device.connectToAddress('FAKE');
    });

    test('responds to ATZ with version', () async {
      final resp = await device.sendCommand('ATZ\r');
      expect(resp, contains('ELM327'));
      expect(resp, contains('>'));
    });

    test('responds OK to ATE0', () async {
      final resp = await device.sendCommand('ATE0\r');
      expect(resp, contains('OK'));
    });

    test('responds OK to ATSP0', () async {
      final resp = await device.sendCommand('ATSP0\r');
      expect(resp, contains('OK'));
    });
  });

  group('FakeElmDevice OBD-II responses', () {
    setUp(() async {
      await device.connectToAddress('FAKE');
    });

    test('RPM response is parseable and in range', () async {
      final raw = await device.sendCommand('01 0C\r');
      final cleaned = ElmProtocol.stripPrompt(raw);
      final value = ElmProtocol.parseResponse(ObdPid.engineRpm, cleaned);
      expect(value, isNotNull);
      expect(value!, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(7000));
    });

    test('speed response is parseable and in range', () async {
      final raw = await device.sendCommand('01 0D\r');
      final cleaned = ElmProtocol.stripPrompt(raw);
      final value = ElmProtocol.parseResponse(ObdPid.vehicleSpeed, cleaned);
      expect(value, isNotNull);
      expect(value!, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(255));
    });

    test('throttle response is parseable and in range', () async {
      final raw = await device.sendCommand('01 11\r');
      final cleaned = ElmProtocol.stripPrompt(raw);
      final value =
          ElmProtocol.parseResponse(ObdPid.throttlePosition, cleaned);
      expect(value, isNotNull);
      expect(value!, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(100));
    });

    test('coolant temp response is parseable and in range', () async {
      final raw = await device.sendCommand('01 05\r');
      final cleaned = ElmProtocol.stripPrompt(raw);
      final value = ElmProtocol.parseResponse(ObdPid.coolantTemp, cleaned);
      expect(value, isNotNull);
      expect(value!, greaterThanOrEqualTo(-40));
      expect(value, lessThanOrEqualTo(215));
    });

    test('MAF response is parseable and in range', () async {
      final raw = await device.sendCommand('01 10\r');
      final cleaned = ElmProtocol.stripPrompt(raw);
      final value = ElmProtocol.parseResponse(ObdPid.mafFlow, cleaned);
      expect(value, isNotNull);
      expect(value!, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(655));
    });

    test('unknown PID returns NO DATA', () async {
      final raw = await device.sendCommand('01 FF\r');
      expect(raw, contains('NO DATA'));
    });

    test('full init + poll cycle works end-to-end', () async {
      // Run through the same init sequence as ObdCollector
      for (final cmd in ElmProtocol.initCommands) {
        final resp = await device.sendCommand(cmd);
        expect(resp, contains('>'));
      }

      // Poll each PID
      for (final pid in [
        ObdPid.engineRpm,
        ObdPid.vehicleSpeed,
        ObdPid.throttlePosition,
        ObdPid.coolantTemp,
        ObdPid.mafFlow,
      ]) {
        final raw = await device.sendCommand(pid.requestCommand);
        final cleaned = ElmProtocol.stripPrompt(raw);
        final value = ElmProtocol.parseResponse(pid, cleaned);
        expect(value, isNotNull, reason: '${pid.label} should return a value');
      }
    });
  });
}
