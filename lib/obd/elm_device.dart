/// Abstract interface for ELM327 device communication.
///
/// Implementations:
/// - [BluetoothElmDevice] — real Bluetooth SPP connection
/// - [FakeElmDevice] — simulated device for development without hardware
abstract class ElmDevice {
  /// Whether the device is currently connected.
  bool get isConnected;

  /// Connect to the device at the given Bluetooth address.
  ///
  /// For fake implementations the [address] may be ignored.
  Future<void> connectToAddress(String address);

  /// Disconnect and release resources.
  Future<void> disconnect();

  /// Send an AT or OBD-II command and return the raw response string.
  ///
  /// The response includes everything up to (but not including) the '>' prompt.
  Future<String> sendCommand(String command, {Duration? timeout});
}
