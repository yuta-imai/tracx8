import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'accel_data.dart';

/// Collects accelerometer data via sensors_plus.
/// Raw sensor events arrive at ~50 Hz; we downsample to ~10 Hz for logging.
class AccelCollector extends ChangeNotifier {
  StreamSubscription<AccelerometerEvent>? _subscription;

  AccelData? _latest;
  AccelData? get latest => _latest;

  final _dataController = StreamController<AccelData>.broadcast();
  Stream<AccelData> get dataStream => _dataController.stream;

  bool get isActive => _subscription != null;

  int _lastEmitMs = 0;
  static const _minIntervalMs = 100; // ~10 Hz

  /// Start collecting accelerometer data.
  void start() {
    _subscription = accelerometerEventStream().listen((event) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastEmitMs < _minIntervalMs) return;
      _lastEmitMs = now;

      final data = AccelData(
        timestampMs: now,
        x: event.x,
        y: event.y,
        z: event.z,
      );
      _latest = data;
      _dataController.add(data);
      notifyListeners();
    });
  }

  /// Stop collecting.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    stop();
    _dataController.close();
    super.dispose();
  }
}
