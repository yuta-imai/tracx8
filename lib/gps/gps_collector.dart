import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_data.dart';

/// Collects GPS data using the Geolocator package.
/// Emits GpsData at ~1 Hz.
class GpsCollector extends ChangeNotifier {
  StreamSubscription<Position>? _subscription;

  GpsData? _latest;
  GpsData? get latest => _latest;

  final _dataController = StreamController<GpsData>.broadcast();
  Stream<GpsData> get dataStream => _dataController.stream;

  bool get isActive => _subscription != null;

  /// Check and request location permissions, then start listening.
  Future<void> start() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied');
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0, // Emit on every update
    );

    _subscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      final data = GpsData(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        latitude: position.latitude,
        longitude: position.longitude,
        altitudeM: position.altitude,
        speedMs: position.speed,
        bearing: position.heading,
        accuracy: position.accuracy,
      );
      _latest = data;
      _dataController.add(data);
      notifyListeners();
    });
  }

  /// Stop listening for GPS updates.
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
